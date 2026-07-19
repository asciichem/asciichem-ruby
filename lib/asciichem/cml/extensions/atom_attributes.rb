# frozen_string_literal: true

require 'nokogiri'

module AsciiChem
  module Cml
    module Extensions
      # Atom-attribute extension channel: carries per-atom fields that
      # CML's standard wire format doesn't cover (oxidation state, lone
      # pairs, radical electrons, ring closures, atom parity) via
      # `aci:<wire_name>` attributes on `<atom>` elements.
      #
      # CML tools that don't recognise the aci: namespace ignore these
      # attributes — schema validity is preserved.
      module AtomAttributes
        # Map of AsciiChem::Model::Atom attribute name (Symbol) to the
        # wire attribute name (without prefix). Each entry produces a
        # corresponding `aci:<wire_name>` attribute in the CML output.
        FIELDS = {
          oxidation_state: 'oxidationState',
          lone_pairs: 'lonePairs',
          radical_electrons: 'radicalElectrons',
          ring_closures: 'ringClosures',
          atom_parity: 'atomParity'
        }.freeze

        # Build the extensions map: `{ atom_id => { field: value } }`.
        # Values are Ruby-native (Integer for counts, String for
        # oxidation state). Atoms without extension data are omitted.
        def self.collect(atom_mapping)
          atom_mapping.each_with_object({}) do |(atom_id, source_atom), memo|
            data = build_entry(source_atom)
            memo[atom_id] = data unless data.empty?
          end
        end

        # Inject aci: attributes into a CML XML string. Returns the
        # modified XML. No-op if the extensions map is empty.
        def self.inject(xml, extensions)
          return xml if extensions.empty?

          doc = Nokogiri::XML(xml)
          root = doc.root
          unless root.namespaces.value?(Extensions::NAMESPACE)
            root.add_namespace(Extensions::PREFIX, Extensions::NAMESPACE)
          end

          extensions.each do |atom_id, entry|
            atom_el = root.at_xpath("//cml:atom[@id='#{atom_id}']",
                                    cml: Extensions::CML_NS)
            next unless atom_el

            entry.each do |attr_name, value|
              wire_name = FIELDS.fetch(attr_name)
              atom_el["#{Extensions::PREFIX}:#{wire_name}"] = value.to_s
            end
          end

          doc.to_xml
        end

        # Extract aci: attributes from a CML XML string. Returns a map
        # `{ atom_id => { field: value } }` with Ruby-native types.
        def self.extract(xml)
          doc = Nokogiri::XML(xml)
          result = {}
          doc.xpath('//cml:atom', cml: Extensions::CML_NS).each do |atom_el|
            atom_id = atom_el['id']
            next unless atom_id

            entry = read_entry(atom_el)
            result[atom_id] = entry unless entry.empty?
          end
          result
        end

        # Apply extracted extension data to a freshly-parsed formula.
        # Atoms are walked in parallel between the canonical document
        # (which has IDs) and the formula (which has model objects).
        def self.restore(formula, canonical_doc, extensions)
          return formula if extensions.empty?

          canonical_atoms = flatten_canonical_atoms(canonical_doc)
          formula_atoms = flatten_formula_atoms(formula)

          canonical_atoms.each_with_index do |canon_atom, idx|
            entry = extensions[canon_atom.id]
            next unless entry

            target = formula_atoms[idx]
            next unless target

            apply_entry(target, entry)
          end
          formula
        end

        class << self
          private

          def build_entry(atom)
            FIELDS.each_with_object({}) do |(attr_name, _wire_name), entry|
              value = atom.public_send(attr_name)
              entry[attr_name] = value if value
            end
          end

          def read_entry(atom_el)
            FIELDS.each_with_object({}) do |(attr_name, wire_name), entry|
              value = atom_el["#{Extensions::PREFIX}:#{wire_name}"]
              entry[attr_name] = cast_from_xml(attr_name, value) if value
            end
          end

          # Cast an XML string back to its Ruby form. Integer counts
          # become Integers; everything else stays a string.
          def cast_from_xml(attr_name, value)
            case attr_name
            when :lone_pairs, :radical_electrons then value.to_i
            else value
            end
          end

          def apply_entry(atom, entry)
            entry.each do |attr_name, value|
              atom.public_send(:"#{attr_name}=", value)
            end
          end

          # Flatten the canonical document's atoms in the order
          # ToCanonical walked them: top-level molecules, then reaction
          # reactants+products, then cascade reactions.
          def flatten_canonical_atoms(canonical_doc)
            atoms = []
            canonical_doc.molecules.each { |m| atoms.concat((m.atom_array&.atoms || [])) }
            canonical_doc.reactions.each do |reaction|
              atoms.concat(flatten_reaction_atoms(reaction))
            end
            canonical_doc.reaction_lists.each do |list|
              list.reactions.each { |r| atoms.concat(flatten_reaction_atoms(r)) }
            end
            atoms
          end

          def flatten_reaction_atoms(reaction)
            atoms = []
            reactants = reaction.reactant_list
            products = reaction.product_list
            reactants&.reactants&.each { |r| atoms.concat(r.substance.molecule.atom_array&.atoms || []) }
            products&.products&.each { |p| atoms.concat(p.substance.molecule.atom_array&.atoms || []) }
            atoms
          end

          # Flatten the AsciiChem::Model::Formula's atoms in the same
          # order ToCanonical walks them. Matches
          # flatten_canonical_atoms one-for-one so parallel iteration
          # by index works.
          def flatten_formula_atoms(formula)
            formula.nodes.each_with_object([]) do |node, memo|
              case node
              when AsciiChem::Model::Molecule
                memo.concat(flatten_molecule_atoms(node))
              when AsciiChem::Model::Reaction
                memo.concat(reaction_atoms(node))
              when AsciiChem::Model::ReactionCascade
                node.steps.each { |step| memo.concat(reaction_atoms(step)) }
              end
            end
          end

          def reaction_atoms(reaction)
            atoms = []
            reaction.reactants.each { |m| atoms.concat(flatten_molecule_atoms(m)) }
            reaction.products.each { |m| atoms.concat(flatten_molecule_atoms(m)) }
            atoms
          end

          def flatten_molecule_atoms(molecule)
            molecule.nodes.each_with_object([]) do |node, memo|
              case node
              when AsciiChem::Model::Atom
                memo << node
              when AsciiChem::Model::Group, AsciiChem::Model::Molecule
                memo.concat(flatten_molecule_atoms(node))
              end
            end
          end
        end
      end
    end
  end
end
