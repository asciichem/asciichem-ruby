# frozen_string_literal: true

require "chemicalml"

module AsciiChem
  module ModelAdapter
    # Chemicalml::Model -> AsciiChem::Model. Walks the canonical tree
    # and rebuilds an AsciiChem::Model::Formula. Pure transformation;
    # no I/O.
    #
    # Mapping rules:
    #
    # - `Chemicalml::Cml::Document`     -> `Formula`.
    # - `Chemicalml::Cml::Molecule`     -> `Molecule`. Atoms become
    #                                        AsciiChem atoms with
    #                                        subscript=count. Bonds
    #                                        re-insert between their
    #                                        endpoint positions.
    # - `Chemicalml::Cml::Atom`         -> `Atom` (element, isotope,
    #                                        charge, lone pairs,
    #                                        radical electrons).
    # - `Chemicalml::Cml::Bond`         -> `Bond` (kind enum).
    # - `Chemicalml::Cml::Reaction`     -> `Reaction`.
    # - `Chemicalml::Cml::ReactionList` -> `ReactionCascade`.
    #
    # Round-trip note: the canonical model is richer than AsciiChem's
    # (3D coordinates, metadata, etc.). Those fields are dropped on the
    # way back. AsciiChem-specific constructs (Lewis markers, embedded
    # math) round-trip when they ride in the canonical Atom's
    # lone_pairs / radical_electrons fields.
    class FromCanonical
      def initialize(document)
        @document = document
      end

      def build
        molecules = @document.molecules.map { |m| molecule_from_canonical(m) }
        reactions = @document.reactions.map { |r| reaction_from_canonical(r) }
        cascades = @document.reaction_lists.map { |l| reaction_list_from_canonical(l) }
        AsciiChem::Model::Formula.new(nodes: molecules + reactions + cascades)
      end

      private

      # -- Molecules --------------------------------------------------

      def molecule_from_canonical(molecule)
        builder = MoleculeRebuilder.new(molecule)
        AsciiChem::Model::Molecule.new(
          nodes: builder.nodes,
          coefficient: molecule.count,
          names: extract_names(molecule.names),
          identifiers: extract_identifiers(molecule.identifiers),
          title: molecule.title,
          formulas: extract_formulas(molecule.formulas),
          properties: extract_properties(molecule.properties),
          labels: extract_labels(molecule.labels)
        )
      end

      def extract_names(canonical_names)
        return [] if canonical_names.nil? || canonical_names.empty?

        canonical_names.map do |n|
          AsciiChem::Model::Name.new(
            content: n.content,
            convention: n.convention,
            dict_ref: n.dict_ref
          )
        end
      end

      def extract_identifiers(canonical_identifiers)
        return [] if canonical_identifiers.nil? || canonical_identifiers.empty?

        canonical_identifiers.map do |i|
          AsciiChem::Model::Identifier.new(
            value: i.value,
            convention: i.convention,
            dict_ref: i.dict_ref
          )
        end
      end

      def extract_formulas(canonical_formulas)
        return [] if canonical_formulas.nil? || canonical_formulas.empty?

        canonical_formulas.map do |f|
          {
            concise: f.concise,
            inline: f.inline,
            formal_charge: f.formal_charge,
            count: f.count,
            title: f.title,
            convention: f.convention,
            dict_ref: f.dict_ref
          }
        end
      end

      def extract_properties(canonical_properties)
        return [] if canonical_properties.nil? || canonical_properties.empty?

        canonical_properties.map do |p|
          {
            title: p.title,
            value: extract_scalar_value(p.value),
            dict_ref: p.dict_ref,
            convention: p.convention
          }
        end
      end

      def extract_scalar_value(value)
        return nil if value.nil?
        return value.value if value.is_a?(Chemicalml::Cml::Scalar)

        value.to_s
      end

      def extract_labels(canonical_labels)
        return [] if canonical_labels.nil? || canonical_labels.empty?

        canonical_labels.map do |l|
          {
            value: l.value,
            dict_ref: l.dict_ref,
            convention: l.convention
          }
        end
      end

      # -- Reactions --------------------------------------------------

      def reaction_from_canonical(reaction)
        AsciiChem::Model::Reaction.new(
          reactants: reactants_from_canonical(reaction.reactant_list),
          products: products_from_canonical(reaction.product_list),
          arrow: arrow_from_wire(reaction),
          conditions: conditions_from_canonical(reaction)
        )
      end

      def arrow_from_wire(reaction)
        type = reaction.type || reaction.title
        case type.to_s
        when 'reverse' then :reverse
        when 'equilibrium' then :equilibrium
        when 'resonance' then :resonance
        else :forward
        end
      end

      def reaction_list_from_canonical(list)
        AsciiChem::Model::ReactionCascade.new(
          steps: list.reactions.map { |r| reaction_from_canonical(r) }
        )
      end

      def reactants_from_canonical(list)
        return [] unless list

        list.reactants.map { |r| molecule_from_canonical(r.substance.molecule) }
      end

      def products_from_canonical(list)
        return [] unless list

        list.products.map { |p| molecule_from_canonical(p.substance.molecule) }
      end

      def conditions_from_canonical(_reaction)
        nil
      end

      # Rebuilds an AsciiChem::Model::Molecule's node list from a
      # canonical molecule. Bonds in the canonical model reference
      # atom IDs; AsciiChem bonds are positional, sitting between two
      # adjacent atoms. The rebuilder builds an ID-to-position map and
      # inserts each bond just before its later endpoint, in
      # descending later-position order so earlier insertions don't
      # shift pending positions.
      class MoleculeRebuilder
        attr_reader :nodes

        def initialize(molecule)
          @molecule = molecule
          @position_by_atom_id = {}
          wire_atoms(molecule).each_with_index do |atom, idx|
            @position_by_atom_id[atom.id] = idx
          end
          @nodes = build_nodes
        end

        private

        def build_nodes
          atoms = wire_atoms(@molecule).map { |a| atom_from_canonical(a) }
          return atoms if wire_bonds(@molecule).empty?

          insert_bonds(atoms)
        end

        def wire_atoms(molecule)
          molecule.atom_array&.atoms || []
        end

        def wire_bonds(molecule)
          molecule.bond_array&.bonds || []
        end

        def atom_from_canonical(atom)
          AsciiChem::Model::Atom.new(
            element: atom.element_type,
            isotope: atom.isotope,
            subscript: subscript_from_count(atom.count),
            charge: atom.formal_charge,
            **extract_coordinates(atom)
          )
        end

        # Read 2D or 3D coordinates from canonical atom. Prefer 3D
        # (x3/y3/z3) if present; fall back to 2D (x2/y2).
        def extract_coordinates(atom)
          if atom.x3 && atom.y3
            { x2: atom.x3.to_f, y2: atom.y3.to_f,
              z2: atom.z3&.to_f }
          elsif atom.x2 && atom.y2
            { x2: atom.x2.to_f, y2: atom.y2.to_f }
          else
            {}
          end
        end

        def subscript_from_count(count)
          return nil if count.nil? || count.to_s == "1"

          count.to_s
        end

        def insert_bonds(atoms)
          result = atoms.dup
          # Insert in descending position order so earlier insertions
          # don't shift the indices of pending ones.
          bonds_with_pos = wire_bonds(@molecule).map { |b| [b, later_position(b)] }
          bonds_with_pos.sort_by { |(_, pos)| -pos }.each do |bond, pos|
            # Ring bonds connect non-adjacent atoms. They're represented
            # by the ring_closures digit carried via aci: extension on
            # the atoms, not as a positional bond in the node list.
            next if ring_bond?(bond)

            result.insert(pos, AsciiChem::Model::Bond.new(kind: bond_kind_from_order(bond.order)))
          end
          result
        end

        # Position of the later endpoint of the bond — i.e. where the
        # bond marker should sit in the rebuilt linear sequence.
        def later_position(bond)
          positions = bond.atom_refs2.to_s.split.map { |id| @position_by_atom_id[id] }.compact
          return 0 if positions.empty?

          positions.max
        end

        # A ring bond connects atoms that are not positionally
        # adjacent — its endpoints span a gap. Such bonds are
        # represented by ring_closures digits, not positional markers.
        def ring_bond?(bond)
          positions = bond.atom_refs2.to_s.split.map { |id| @position_by_atom_id[id] }.compact
          return false if positions.length < 2

          positions.max - positions.min > 1
        end

        def first_position(bond)
          positions = bond.atom_refs2.to_s.split.map { |id| @position_by_atom_id[id] }.compact
          positions.min || 0
        end

        ORDER_TO_KIND = {
          'S' => :single, 'D' => :double, 'T' => :triple,
          'Q' => :quadruple, 'W' => :wedge, 'H' => :hash,
          'A' => :dative, 'V' => :wavy
        }.freeze

        def bond_kind_from_order(order)
          ORDER_TO_KIND.fetch(order.to_s, :single)
        end
      end
      private_constant :MoleculeRebuilder
    end
  end
end
