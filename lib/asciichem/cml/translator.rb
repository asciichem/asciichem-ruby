# frozen_string_literal: true

module AsciiChem
  module Cml
    # Adapter between AsciiChem::Model and Chemicalml::Cml. Two class
    # methods, one per direction. No I/O — pure transformation.
    #
    # The translator uses a per-build ID counter so atom IDs are
    # deterministic across runs of the same input. CML doesn't
    # require IDs to be a1/a2/a3 specifically, but stable IDs make
    # the round-trip conformance suite byte-equal modulo whitespace.
    class Translator
      # AsciiChem::Model -> Chemicalml::Cml::Document
      def self.from_asciichem(formula)
        builder = FromBuilder.new
        molecules = []
        reactions = []
        formula.nodes.each do |node|
          case node
          when AsciiChem::Model::Molecule
            molecules << builder.molecule(node)
          when AsciiChem::Model::Reaction
            reactions << builder.reaction(node)
          when AsciiChem::Model::ReactionCascade
            node.steps.each { |step| reactions << builder.reaction(step) }
          when AsciiChem::Model::Text
            # CML has no place for stray text; ignore silently.
            # A future linter check could warn on this.
          end
        end
        Chemicalml::Cml::Document.new(molecules: molecules, reactions: reactions)
      end

      # Chemicalml::Cml::Document -> AsciiChem::Model::Formula
      def self.to_asciichem(document)
        nodes = []
        document.molecules.each { |mol| nodes << molecule_to_asciichem(mol) }
        document.reactions.each { |rxn| nodes << reaction_to_asciichem(rxn) }
        AsciiChem::Model::Formula.new(nodes: nodes)
      end

      # -- AsciiChem -> CML helpers ------------------------------------

      class FromBuilder
        def initialize
          @atom_counter = IdCounter.new("a")
          @bond_counter = IdCounter.new("b")
          @molecule_counter = IdCounter.new("m")
          @reaction_counter = IdCounter.new("r")
        end

        def molecule(node)
          atoms, bonds = collect_atoms_and_bonds(node)
          Chemicalml::Cml::Molecule.new(
            id: @molecule_counter.next,
            atom_array: Chemicalml::Cml::AtomArray.new(atoms: atoms),
            bond_array: bonds.empty? ? nil : Chemicalml::Cml::BondArray.new(bonds: bonds)
          )
        end

        def reaction(reaction)
          Chemicalml::Cml::Reaction.new(
            id: @reaction_counter.next,
            title: reaction.arrow.to_s,
            type: reaction.arrow.to_s,
            reactant_list: Chemicalml::Cml::ReactantList.new(
              reactants: reaction.reactants.map { |m| substance_for(m) }
            ),
            product_list: Chemicalml::Cml::ProductList.new(
              products: reaction.products.map { |m| substance_for(m) }
            )
          )
        end

        private

        def substance_for(molecule)
          Chemicalml::Cml::Reactant.new(
            substance: Chemicalml::Cml::Substance.new(
              molecule: molecule(molecule)
            )
          )
        end

        # Walks the AsciiChem::Model molecule tree and collects atoms
        # (with multiplicity applied to `count`) and bonds.
        def collect_atoms_and_bonds(node, multiplicity = "1")
          atoms = []
          bonds = []
          case node
          when AsciiChem::Model::Molecule
            prev_id = nil
            node.nodes.each do |child|
              child_atoms, child_bonds, last_id = collect_unit(child, multiplicity)
              bonds << make_bond(prev_id, last_id, "S") if prev_id && last_id && connection_between?(child)
              atoms.concat(child_atoms)
              bonds.concat(child_bonds)
              prev_id = last_id
            end
          else
            atoms_collected, bonds_collected, last_id = collect_unit(node, multiplicity)
            atoms.concat(atoms_collected)
            bonds.concat(bonds_collected)
          end
          [atoms, bonds]
        end

        def collect_unit(node, multiplicity)
          atoms = []
          bonds = []
          last_id = nil
          case node
          when AsciiChem::Model::Atom
            last_id = @atom_counter.next
            atoms << atom_for(node, last_id, multiplicity)
          when AsciiChem::Model::Group
            sub_atoms, sub_bonds = collect_atoms_and_bonds(
              AsciiChem::Model::Molecule.new(nodes: node.nodes),
              node.multiplicity || multiplicity
            )
            atoms.concat(sub_atoms)
            bonds.concat(sub_bonds)
          when AsciiChem::Model::Bond
            bonds << bond_for(node)
          end
          [atoms, bonds, last_id]
        end

        def atom_for(atom, id, multiplicity)
          Chemicalml::Cml::Atom.new(
            id: id,
            element_type: atom.element,
            count: multiplicity_for(atom, multiplicity),
            formal_charge: atom.charge,
            isotope: atom.isotope,
            hydrogen_count: atom.subscript,
            spin_multiplicity: spin_for(atom)
          )
        end

        def multiplicity_for(atom, multiplicity)
          return atom.subscript if atom.subscript
          return multiplicity if multiplicity && multiplicity != "1"

          nil
        end

        def spin_for(atom)
          nil
        end

        def bond_for(bond)
          Chemicalml::Cml::Bond.new(
            id: @bond_counter.next,
            order: bond_order(bond.kind),
            atom_refs2: ""
          )
        end

        def make_bond(from, to, order)
          Chemicalml::Cml::Bond.new(
            id: @bond_counter.next,
            atom_refs2: "#{from} #{to}",
            order: order
          )
        end

        def connection_between?(_node)
          false
        end

        def bond_order(kind)
          {
            single: "S",
            double: "D",
            triple: "T",
            quadruple: "Q",
            wedge: "W",
            hash: "H",
            dative: "DG",
            wavy: "A"
          }.fetch(kind, "S")
        end
      end

      # -- CML -> AsciiChem helpers ------------------------------------

      def self.molecule_to_asciichem(cml_mol)
        nodes = []
        if cml_mol.atom_array&.atoms
          cml_mol.atom_array.atoms.each do |cml_atom|
            nodes << atom_to_asciichem(cml_atom)
          end
        end
        AsciiChem::Model::Molecule.new(nodes: nodes)
      end

      def self.atom_to_asciichem(cml_atom)
        AsciiChem::Model::Atom.new(
          element: cml_atom.element_type,
          isotope: cml_atom.isotope,
          subscript: cml_atom.count || cml_atom.hydrogen_count,
          charge: cml_atom.formal_charge
        )
      end

      def self.reaction_to_asciichem(cml_rxn)
        AsciiChem::Model::Reaction.new(
          reactants: cml_rxn.reactant_list&.reactants&.map { |r| molecule_to_asciichem(r.substance.molecule) } || [],
          products: cml_rxn.product_list&.products&.map { |p| molecule_to_asciichem(p.substance.molecule) } || [],
          arrow: arrow_kind(cml_rxn.type || cml_rxn.title)
        )
      end

      def self.arrow_kind(value)
        {
          "forward" => :forward,
          "reverse" => :reverse,
          "equilibrium" => :equilibrium,
          "resonance" => :resonance
        }.fetch(value.to_s, :forward)
      end

      # Deterministic ID generator: a1, a2, ... b1, b2, ... m1, ...
      class IdCounter
        def initialize(prefix)
          @prefix = prefix
          @counter = 0
        end

        def next
          @counter += 1
          "#{@prefix}#{@counter}"
        end
      end

      private_constant :IdCounter, :FromBuilder
    end
  end
end
