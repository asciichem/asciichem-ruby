# frozen_string_literal: true

require 'nokogiri'

module AsciiChem
  module Cml
    # Carries per-molecule key/value metadata through CML round-trip
    # via `aci:meta-<name>` attributes on `<molecule>` elements.
    #
    # CML's standard `<metadata>` element exists but the chemicalml
    # Molecule wire doesn't expose it as a first-class attribute, so
    # AsciiChem carries metadata via the aci: namespace. CML tools
    # that don't recognise the namespace ignore the attributes —
    # schema validity is preserved.
    #
    # This is the fifth extension channel, parallel to:
    #   - Extensions (atom attributes + top-level constructs)
    #   - GroupExtensions (group structure inside molecules)
    #   - OpaqueExtensions (unknown top-level elements)
    #   - ConditionsExtensions (per-reaction conditions)
    module MetadataExtensions
      META_PREFIX = 'meta-'

      # Inject aci:meta-* attributes into the CML XML for each
      # molecule that carries metadata. No-op if the formula has no
      # metadata anywhere.
      def self.inject(xml, formula)
        metadata_map = build_metadata_map(formula)
        return xml if metadata_map.empty?

        doc = Nokogiri::XML(xml)
        root = doc.root
        Extensions.ensure_namespace(root)
        apply_metadata(root, metadata_map)
        doc.to_xml
      end

      # Extract aci:meta-* attributes from each <molecule> in the XML.
      # Returns a map `{ molecule_id => { name => content } }`.
      def self.extract(xml)
        doc = Nokogiri::XML(xml)
        result = {}
        doc.xpath('//cml:molecule', cml: Extensions::CML_NS).each do |el|
          id = el['id']
          next unless id

          meta = read_meta_attrs(el)
          result[id] = meta unless meta.empty?
        end
        result
      end

      # Restore extracted metadata onto matching molecules in a
      # freshly-parsed formula. Molecules are walked in canonical
      # order to match the IDs assigned during emit.
      def self.restore(formula, metadata_map)
        return formula if metadata_map.empty?

        prefix = AsciiChem::Cml::ID_PREFIXES.fetch(:molecule)
        index = 0
        each_molecule_in_canonical_order(formula) do |mol|
          index += 1
          data = metadata_map["#{prefix}#{index}"]
          next unless data

          data.each do |name, content|
            mol.metadata << AsciiChem::Model::Molecule::Meta.new(name: name, content: content)
          end
        end
        formula
      end

      class << self
        private

        def build_metadata_map(formula)
          prefix = AsciiChem::Cml::ID_PREFIXES.fetch(:molecule)
          index = 0
          map = {}
          each_molecule_in_canonical_order(formula) do |mol|
            index += 1
            next if mol.metadata.empty?

            map["#{prefix}#{index}"] = data_for(mol)
          end
          map
        end

        def data_for(molecule)
          molecule.metadata.each_with_object({}) do |m, memo|
            memo[m.name] = m.content if m.name && m.content
          end
        end

        # Walk a formula's molecules in canonical order. Top-level
        # molecules first, then reactions' reactants+products, then
        # reaction cascades. Matches ToCanonical's MoleculeWalker.
        def each_molecule_in_canonical_order(formula, &block)
          formula.nodes.each do |node|
            walk_node_for_molecules(node, &block)
          end
        end

        def walk_node_for_molecules(node, &block)
          case node
          when AsciiChem::Model::Molecule
            yield node
          when AsciiChem::Model::Reaction
            yield_reaction_molecules(node, &block)
          when AsciiChem::Model::ReactionCascade
            node.steps.each { |step| yield_reaction_molecules(step, &block) }
          end
        end

        def yield_reaction_molecules(reaction, &)
          reaction.reactants.each(&)
          reaction.products.each(&)
        end

        def apply_metadata(root, metadata_map)
          metadata_map.each do |mol_id, meta|
            mol_el = root.at_xpath(
              "//cml:molecule[@id='#{mol_id}']",
              cml: Extensions::CML_NS
            )
            next unless mol_el

            meta.each do |name, content|
              mol_el["#{Extensions::PREFIX}:#{META_PREFIX}#{name}"] = content
            end
          end
        end

        def read_meta_attrs(element)
          element.attributes.each_with_object({}) do |(name, attr), memo|
            next unless name.start_with?(META_PREFIX)
            next unless attr.namespace&.prefix == Extensions::PREFIX

            memo[name.sub(META_PREFIX, '')] = attr.value
          end
        end
      end
    end
  end
end
