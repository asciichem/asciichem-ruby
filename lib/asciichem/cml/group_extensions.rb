# frozen_string_literal: true

require 'nokogiri'

module AsciiChem
  module Cml
    # Preserves AsciiChem::Model::Group structure through CML round-trip.
    #
    # CML has no native group concept — the canonical model flattens
    # `(OH)_2` to `<atom elementType="O" count="2"/><atom elementType="H" count="2"/>`.
    # The aci: namespace records the original grouping so AsciiChem
    # can rebuild it on parse:
    #
    #   <molecule id="m1">
    #     <atomArray>
    #       <atom id="a1" elementType="O" count="2"/>
    #       <atom id="a2" elementType="H" count="2"/>
    #     </atomArray>
    #     <aci:group multiplicity="2" bracket="paren" atomRefs="a1 a2"/>
    #   </molecule>
    #
    # The mechanism parallels `Extensions` (atom attributes) and the
    # top-level handlers, but operates at molecule scope: each
    # `<aci:group>` lives inside its parent `<molecule>` and references
    # atoms by ID. Nested groups in AsciiChem produce multiple
    # `<aci:group>` elements with overlapping `atomRefs` — the parent
    # group's refs include the inner group's atoms.
    #
    # On restore, the canonical adapter has already applied the
    # multiplicity to atom counts. GroupExtensions reverses this:
    # divides each referenced atom's count by the group's multiplicity
    # (rounding to nil when the result is 1) and wraps the atoms in an
    # AsciiChem::Model::Group.
    module GroupExtensions
      # -- AsciiChem -> CML ------------------------------------------

      # Build the group extensions map: `{ molecule_id => [group_record, ...] }`.
      # Molecules without groups are omitted (keeps the CML clean for
      # ungrouped molecules).
      def self.collect(groups_by_molecule)
        groups_by_molecule.reject { |_, groups| groups.empty? }
      end

      # Inject `<aci:group>` elements into each referenced molecule.
      # No-op when the map is empty.
      def self.inject(xml, groups_by_molecule)
        return xml if groups_by_molecule.empty?

        doc = Nokogiri::XML(xml)
        root = doc.root
        Extensions.ensure_namespace(root)

        groups_by_molecule.each do |molecule_id, groups|
          molecule_el = root.at_xpath("//cml:molecule[@id='#{molecule_id}']",
                                      cml: Extensions::CML_NS)
          next unless molecule_el

          groups.each { |record| molecule_el.add_child(build_group_element(doc, record)) }
        end

        doc.to_xml
      end

      def self.build_group_element(doc, record)
        el = doc.create_element("#{Extensions::PREFIX}:group")
        el['multiplicity'] = record.multiplicity.to_s if record.multiplicity
        el['bracket'] = AsciiChem::Model::Group::BRACKETS
          .fetch(record.bracket, AsciiChem::Model::Group::BRACKETS[:paren])[:wire]
        el['atomRefs'] = record.atom_ids.join(' ')
        el
      end
      private_class_method :build_group_element

      # -- CML -> AsciiChem ------------------------------------------

      # Extract `<aci:group>` elements, keyed by their parent
      # molecule's ID. Each value is an array of record hashes:
      # `{ multiplicity:, bracket:, atom_ids: }`.
      def self.extract(xml)
        doc = Nokogiri::XML(xml)
        result = Hash.new { |h, k| h[k] = [] }
        doc.xpath('//cml:molecule', cml: Extensions::CML_NS).each do |mol_el|
          group_els = mol_el.xpath("./#{Extensions::PREFIX}:group",
                                   Extensions::PREFIX => Extensions::NAMESPACE)
          next if group_els.empty?

          mol_el['id']&.then do |molecule_id|
            group_els.each { |g| result[molecule_id] << read_group(g) }
          end
        end
        result
      end

      def self.read_group(el)
        atom_ids = (el['atomRefs'] || '').split
        {
          multiplicity: el['multiplicity'],
          bracket: AsciiChem::Model::Group::BRACKET_BY_WIRE.fetch(el['bracket'], :paren),
          atom_ids: atom_ids
        }
      end
      private_class_method :read_group

      # -- Round-trip restore ----------------------------------------
      #
      # Walks the rebuilt AsciiChem::Model::Formula's molecules. For
      # each molecule that has group records, rebuilds the Group nodes
      # from the flattened atom list. Atom positions in the rebuilt
      # molecule match the canonical order (a1, a2, ...), so the
      # atom_ids in each record map directly to indices.

      def self.restore(formula, canonical_doc, groups_by_molecule)
        return formula if groups_by_molecule.empty?

        canonical_molecules = flatten_canonical_molecules(canonical_doc)
        formula_molecules = flatten_formula_molecules(formula)

        canonical_molecules.each_with_index do |canon_mol, idx|
          groups = groups_by_molecule[canon_mol.id]
          next unless groups

          target = formula_molecules[idx]
          next unless target

          rebuild_groups_in_molecule(target, groups)
        end
        formula
      end

      # Rebuilds groups inside a single molecule. Processes records in
      # reverse-entry order so inner groups rebuild before their outer
      # parents — the walker adds outer groups to its @groups array
      # before entering inner groups, so reverse gives innermost-first.
      # For sibling groups (no nesting), reverse order is equivalent.
      def self.rebuild_groups_in_molecule(molecule, groups)
        groups.reverse_each { |record| rebuild_one_group(molecule, record) }
      end
      private_class_method :rebuild_groups_in_molecule

      def self.rebuild_one_group(molecule, record)
        target_nodes = find_target_nodes(molecule.nodes, record[:atom_ids])
        return if target_nodes.empty?

        apply_multiplicity_to_atoms(target_nodes, record[:multiplicity])
        splice_group_into(molecule.nodes, target_nodes, record)
      end
      private_class_method :rebuild_one_group

      # Walks `nodes` in canonical-walk order, tracking which canonical
      # atom ID each position covers. Returns ALL nodes (Atoms, Bonds,
      # AND Groups) between the first and last target atom inclusive.
      # Including Bonds preserves the chain inside the Group.
      def self.find_target_nodes(nodes, atom_ids)
        target_array = atom_ids.to_a
        return [] if target_array.empty?

        first_pos = nil
        last_pos = nil
        canonical_idx = 0
        nodes.each_with_index do |node, idx|
          atom_count = count_atoms_recursively(node)
          covered_ids = (1..atom_count).map { |i| "a#{canonical_idx + i}" }
          if covered_ids.intersect?(target_array)
            first_pos ||= idx
            last_pos = idx
          end
          canonical_idx += atom_count
        end
        return [] unless first_pos && last_pos

        nodes[first_pos..last_pos]
      end
      private_class_method :find_target_nodes

      # Counts the atoms transitively contained in a node. Atoms count
      # as 1; Groups/Molecules recurse and sum.
      def self.count_atoms_recursively(node)
        case node
        when AsciiChem::Model::Atom
          1
        when AsciiChem::Model::Group, AsciiChem::Model::Molecule
          node.nodes.sum { |n| count_atoms_recursively(n) }
        else
          0
        end
      end
      private_class_method :count_atoms_recursively

      # Divide each Atom's subscript by the multiplicity. Atoms inside
      # an inner Group have already been divided when the inner Group
      # was processed — leave them alone. Subscripts of 1 (after
      # division) become nil (the default).
      def self.apply_multiplicity_to_atoms(target_nodes, multiplicity)
        return unless multiplicity

        divisor = multiplicity.to_i
        return unless divisor.positive?

        target_nodes.each do |node|
          next unless node.is_a?(AsciiChem::Model::Atom)
          next unless node.subscript

          new_sub = node.subscript.to_i / divisor
          node.subscript = (new_sub == 1 ? nil : new_sub.to_s)
        end
      end
      private_class_method :apply_multiplicity_to_atoms

      # Replaces the collected target nodes (which must be contiguous
      # in `nodes`) with a single new Group containing them. Uses
      # identity (`equal?`) for position lookup so duplicate Bonds
      # (same kind → `==` equal) aren't confused.
      def self.splice_group_into(nodes, target_nodes, record)
        return if target_nodes.empty?

        positions = target_nodes.map do |target|
          found = nodes.each_with_index.find { |node, _| node.equal?(target) }
          found&.last
        end.compact
        return if positions.empty?

        group = AsciiChem::Model::Group.new(
          nodes: target_nodes,
          multiplicity: record[:multiplicity],
          bracket: record[:bracket]
        )

        first_pos = positions.min
        nodes[first_pos] = group
        # Remove remaining positions in descending order so earlier
        # positions don't shift before deletion.
        positions.reject { |p| p == first_pos }.sort.reverse.each do |pos|
          nodes.delete_at(pos)
        end
      end
      private_class_method :splice_group_into

      # Flatten the canonical document's molecules (top-level +
      # reaction reactants/products + cascade reactions) into a list,
      # in the same order ToCanonical walked them.
      def self.flatten_canonical_molecules(canonical_doc)
        mols = canonical_doc.molecules.dup
        canonical_doc.reactions.each { |r| mols.concat(flatten_reaction_molecules(r)) }
        canonical_doc.reaction_lists.each do |list|
          list.reactions.each { |r| mols.concat(flatten_reaction_molecules(r)) }
        end
        mols
      end
      private_class_method :flatten_canonical_molecules

      def self.flatten_reaction_molecules(reaction)
        mols = []
        reaction.reactant_list&.reactants&.each { |r| mols << r.substance.molecule }
        reaction.product_list&.products&.each { |p| mols << p.substance.molecule }
        mols
      end
      private_class_method :flatten_reaction_molecules

      def self.flatten_formula_molecules(formula)
        mols = []
        formula.nodes.each do |node|
          case node
          when AsciiChem::Model::Molecule
            mols << node
          when AsciiChem::Model::Reaction
            mols.concat(node.reactants)
            mols.concat(node.products)
          when AsciiChem::Model::ReactionCascade
            node.steps.each do |step|
              mols.concat(step.reactants)
              mols.concat(step.products)
            end
          end
        end
        mols
      end
      private_class_method :flatten_formula_molecules
    end
  end
end
