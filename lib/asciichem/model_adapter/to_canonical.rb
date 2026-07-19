# frozen_string_literal: true

require "chemicalml"

module AsciiChem
  module ModelAdapter
    # AsciiChem::Model -> Chemicalml::Model. Walks the AsciiChem tree
    # and builds a canonical document. Pure transformation; no I/O.
    #
    # Mapping rules:
    #
    # - `Formula`           -> `Chemicalml::Cml::Document`.
    # - `Molecule`          -> `Chemicalml::Cml::Molecule`. Inner atoms
    #                         collect IDs; bonds reference consecutive
    #                         IDs. Groups flatten with their multiplicity
    #                         applied to each contained atom's count.
    # - `Atom`              -> `Chemicalml::Cml::Atom` (element,
    #                         isotope, charge, count, lone pairs,
    #                         radical electrons).
    # - `Bond`              -> `Chemicalml::Cml::Bond` (kind, refs).
    # - `Reaction`          -> `Chemicalml::Cml::Reaction`.
    # - `ReactionCascade`   -> `Chemicalml::Cml::ReactionList`.
    # - `ElectronConfiguration`, `EmbeddedMath`, `Text` -> skipped
    #   (no canonical representation yet; a future extension can carry
    #   them as namespaced metadata).
    class ToCanonical
      attr_reader :atom_mapping, :groups

      def initialize(formula)
        @formula = formula
        @ids = IdRegistry.new
        @atom_mapping = {}
        # Map of canonical molecule ID -> array of GroupRecord.
        # Keyed by molecule ID because aci:group elements live inside
        # their parent <molecule>, and multiple molecules can exist
        # (top-level + reactants + products).
        @groups = Hash.new { |hash, key| hash[key] = [] }
        @molecule_id_stack = []
      end

      def build
        molecules = []
        reactions = []
        reaction_lists = []
        @formula.nodes.each do |node|
          case node
          when AsciiChem::Model::Molecule
            molecules << molecule_to_canonical(node)
          when AsciiChem::Model::Reaction
            reactions << reaction_to_canonical(node)
          when AsciiChem::Model::ReactionCascade
            reaction_lists << reaction_cascade_to_canonical(node)
          end
        end
        Chemicalml::Cml::Document.new(
          molecules: molecules,
          reactions: reactions,
          reaction_lists: reaction_lists
        )
      end

      private

      # -- Molecules --------------------------------------------------

      def molecule_to_canonical(molecule)
        walker = MoleculeWalker.new(@ids)
        atoms, bonds = walker.walk(molecule)
        @atom_mapping.merge!(walker.atom_mapping)
        canonical_molecule = Chemicalml::Cml::Molecule.new(
          id: @ids.next(:molecule),
          atom_array: atoms.empty? ? nil : Chemicalml::Cml::AtomArray.new(atoms: atoms),
          bond_array: bonds.empty? ? nil : Chemicalml::Cml::BondArray.new(bonds: bonds),
          count: molecule.coefficient,
          formal_charge: total_formal_charge(atoms),
          names: map_names(molecule.names),
          identifiers: map_identifiers(molecule.identifiers),
          title: molecule.title,
          formulas: map_formulas(molecule.formulas),
          properties: map_properties(molecule.properties),
          labels: map_labels(molecule.labels)
        )
        @groups[canonical_molecule.id].concat(walker.groups) unless walker.groups.empty?
        canonical_molecule
      end

      def map_names(names)
        return [] if names.nil? || names.empty?

        names.map do |n|
          Chemicalml::Cml::Name.new(
            content: n.content,
            convention: n.convention,
            dict_ref: n.dict_ref
          )
        end
      end

      def map_identifiers(identifiers)
        return [] if identifiers.nil? || identifiers.empty?

        identifiers.map do |i|
          Chemicalml::Cml::Identifier.new(
            value: i.value,
            convention: i.convention,
            dict_ref: i.dict_ref
          )
        end
      end

      def map_formulas(formulas)
        return [] if formulas.nil? || formulas.empty?

        formulas.map do |f|
          Chemicalml::Cml::Formula.new(
            concise: f.concise,
            inline: f.inline,
            formal_charge: f.formal_charge,
            count: f.count,
            title: f.title,
            convention: f.convention,
            dict_ref: f.dict_ref
          )
        end
      end

      def map_properties(properties)
        return [] if properties.nil? || properties.empty?

        properties.map do |p|
          Chemicalml::Cml::Property.new(
            title: p.title,
            scalar: build_scalar(p.value),
            dict_ref: p.dict_ref,
            convention: p.convention
          )
        end
      end

      def build_scalar(value)
        return nil if value.nil?

        Chemicalml::Cml::Scalar.new(
          content: value.to_s,
          dict_ref: nil
        )
      end

      def map_labels(labels)
        return [] if labels.nil? || labels.empty?

        labels.map do |l|
          Chemicalml::Cml::Label.new(
            value: l.value,
            dict_ref: l.dict_ref,
            convention: l.convention
          )
        end
      end

      def total_formal_charge(canonical_atoms)
        charges = canonical_atoms.map { |a| parse_charge(a.formal_charge) }.compact
        return nil if charges.empty?

        sum = charges.sum
        sum.positive? ? "+#{sum}" : sum.to_s
      end

      def parse_charge(value)
        return nil if value.nil? || value.to_s.empty?

        match = value.to_s.match(/\A(?<n>\d*)(?<sign>[+-])\z/) ||
                value.to_s.match(/\A(?<sign>[+-])(?<n>\d*)\z/)
        return nil unless match

        n = match[:n].empty? ? 1 : match[:n].to_i
        match[:sign] == "+" ? n : -n
      end

      # -- Reactions --------------------------------------------------

      def reaction_to_canonical(reaction)
        Chemicalml::Cml::Reaction.new(
          id: @ids.next(:reaction),
          reactant_list: reactant_list_to_canonical(reaction.reactants),
          product_list: product_list_to_canonical(reaction.products),
          arrow: reaction.arrow,
          conditions_above: conditions_above(reaction),
          conditions_below: conditions_below(reaction),
          title: reaction.arrow.to_s,
          type: reaction.arrow.to_s
        )
      end

      def reaction_cascade_to_canonical(cascade)
        Chemicalml::Cml::ReactionList.new(
          reactions: cascade.steps.map { |s| reaction_to_canonical(s) }
        )
      end

      def reactant_list_to_canonical(reactants)
        Chemicalml::Cml::ReactantList.new(
          reactants: reactants.map { |m| participant_to_canonical(m, :reactant) }
        )
      end

      def product_list_to_canonical(products)
        Chemicalml::Cml::ProductList.new(
          products: products.map { |m| participant_to_canonical(m, :product) }
        )
      end

      def participant_to_canonical(molecule, role)
        Chemicalml::Cml::Reactant.new(
          substance: Chemicalml::Cml::Substance.new(
            molecule: molecule_to_canonical(molecule),
            role: role
          )
        )
      end

      def conditions_above(reaction)
        reaction.conditions&.above
      end

      def conditions_below(reaction)
        reaction.conditions&.below
      end

      # Walks an AsciiChem::Model::Molecule and produces an ordered
      # atom list + a bond list with proper atomRefs. The walker is
      # the single source of truth for atom ID assignment — bonds,
      # reactants, and products all reference the IDs it produces.
      # Also exposes `atom_mapping` (canonical_id => source Atom) so
      # downstream consumers (CML extension serializer, debug tools)
      # can match canonical atoms back to their AsciiChem source, and
      # `groups` (per-molecule list of group structure records) so the
      # aci: extension can preserve grouping through CML round-trip.
      class MoleculeWalker
        attr_reader :atom_mapping, :groups

        def initialize(ids)
          @ids = ids
          @atoms = []
          @bonds = []
          @atom_mapping = {}
          @atom_id_by_object_id = {}
          @groups = []
          @group_stack = []
          @pending_bond_kind = nil
          @last_atom_id = nil
        end

        def walk(molecule)
          walk_nodes(molecule.nodes, multiplier: nil)
          emit_ring_bonds(molecule)
          [@atoms, @bonds]
        end

        # Emit canonical bonds for each ring-closure pair on atoms
        # in this molecule. The walker has already assigned IDs to
        # every atom; RingBonds.each_in yields pairs which we look up
        # in @atom_id_by_object_id to translate Ruby object identity
        # into canonical atom IDs. Skips pairs that already have a
        # positional bond between them (degenerate case like `C1-C1`).
        def emit_ring_bonds(molecule)
          existing_pair_keys = @bonds.map { |b| pair_key(b.atom_refs2.to_s.split) }.to_set
          AsciiChem::RingBonds.each_in(molecule) do |ring_bond|
            from_id = @atom_id_by_object_id[ring_bond.from_atom.object_id]
            to_id = @atom_id_by_object_id[ring_bond.to_atom.object_id]
            next unless from_id && to_id

            key = pair_key([from_id, to_id])
            next if existing_pair_keys.include?(key)

            @bonds << Chemicalml::Cml::Bond.new(
              id: @ids.next(:bond),
              atom_refs2: "#{from_id} #{to_id}",
              order: "S"
            )
            existing_pair_keys << key
          end
        end

        # Order-independent key for a pair of atom IDs, so a-b and b-a
        # compare equal.
        def pair_key(refs)
          refs.sort.join(":")
        end

        private

        def walk_nodes(nodes, multiplier:)
          nodes.each do |node|
            case node
            when AsciiChem::Model::Atom
              emit_atom(node, multiplier)
            when AsciiChem::Model::Bond
              @pending_bond_kind = node.kind
            when AsciiChem::Model::Group
              enter_group(node, multiplier)
            when AsciiChem::Model::Molecule
              walk_nodes(node.nodes, multiplier: combine(multiplier, node.coefficient))
            end
          end
        end

        def enter_group(group, multiplier)
          record = GroupRecord.new(
            id: @ids.next(:group),
            multiplicity: group.multiplicity,
            bracket: group.bracket,
            atom_ids: []
          )
          @groups << record
          @group_stack.push(record)
          walk_nodes(group.nodes, multiplier: combine(multiplier, group.multiplicity))
          @group_stack.pop
        end

        def emit_atom(atom, multiplier)
          id = @ids.next(:atom)
          @atom_mapping[id] = atom
          @atom_id_by_object_id[atom.object_id] = id
          @group_stack.each { |record| record.atom_ids << id }
          attrs = {
            id: id,
            element_type: atom.element,
            isotope: atom.isotope,
            formal_charge: atom.charge,
            count: effective_count(atom, multiplier),
            lone_pairs: atom.lone_pairs,
            radical_electrons: atom.radical_electrons,
            spin_multiplicity: atom.spin_multiplicity,
            title: atom.atom_title
          }
          merge_coordinates(attrs, atom)
          merge_fractional_coords(attrs, atom)
          @atoms << Chemicalml::Cml::Atom.new(**attrs)
          emit_pending_bond(id) if @pending_bond_kind && @last_atom_id
          @last_atom_id = id
          @pending_bond_kind = nil
        end

        def emit_pending_bond(next_atom_id)
          @bonds << Chemicalml::Cml::Bond.new(
            id: @ids.next(:bond),
            atom_refs2: "#{@last_atom_id} #{next_atom_id}",
            order: AsciiChem::Model::Bond::CML_ORDER_CODES.fetch(@pending_bond_kind, "S"),
            bond_stereo: bond_stereo_for(@pending_bond_kind)
          )
        end

        def bond_stereo_for(kind)
          code = AsciiChem::Model::Bond::CML_STEREO_CODES[kind]
          return nil unless code

          Chemicalml::Cml::BondStereo.new(value: code)
        end

        def effective_count(atom, multiplier)
          sub = atom.subscript
          return combine(multiplier, sub) if multiplier
          return sub if sub

          nil
        end

        # Map AsciiChem 2D/3D coordinates onto canonical atom attrs.
        # If z2 is present, it's 3D → x3/y3/z3. Otherwise 2D → x2/y2.
        def merge_coordinates(attrs, atom)
          return unless atom.x2 && atom.y2

          if atom.z2
            attrs[:x3] = atom.x2
            attrs[:y3] = atom.y2
            attrs[:z3] = atom.z2
          else
            attrs[:x2] = atom.x2
            attrs[:y2] = atom.y2
          end
        end

        def merge_fractional_coords(attrs, atom)
          return unless atom.x_fract && atom.y_fract && atom.z_fract

          attrs[:xFract] = atom.x_fract
          attrs[:yFract] = atom.y_fract
          attrs[:zFract] = atom.z_fract
        end

        def combine(left, right)
          lv = integer_or_nil(left)
          rv = integer_or_nil(right)
          return nil unless lv || rv

          (lv || 1) * (rv || 1)
        end

        def integer_or_nil(value)
          return nil if value.nil? || value.to_s.empty?

          Integer(value, exception: false)
        end
      end
      private_constant :MoleculeWalker

      # Captures the structure of an AsciiChem::Model::Group during
      # the canonical walk. The walker assigns IDs to atoms in source
      # order; the GroupRecord lists which atoms were inside the group
      # (transitively, for nested groups). Used by `Cml::GroupExtensions`
      # to preserve grouping through the canonical model.
      GroupRecord = Struct.new(:id, :multiplicity, :bracket, :atom_ids, keyword_init: true)
      private_constant :GroupRecord

      # Per-build ID registry. Issues stable IDs within a single
      # translation pass (a1, a2, b1, m1, r1, ...) so re-running the
      # adapter on equivalent input yields byte-equal output.
      class IdRegistry
        PREFIXES = AsciiChem::Cml::ID_PREFIXES

        def initialize
          @counters = Hash.new(0)
        end

        def next(kind)
          @counters[kind] += 1
          "#{PREFIXES.fetch(kind)}#{@counters[kind]}"
        end
      end
      private_constant :IdRegistry
    end
  end
end
