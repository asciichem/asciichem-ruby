# frozen_string_literal: true

require 'nokogiri'

module AsciiChem
  module Cml
    # Carries AsciiChem-specific fields through CML round-trip via an
    # `aci:` (AsciiChem extension) namespace. CML's standard wire
    # format covers element, isotope, charge, count, hydrogen count,
    # and spin multiplicity — but not oxidation state, lone pairs,
    # radical electrons, or anything else AsciiChem might add. Without
    # this side channel, those fields are silently dropped on
    # AsciiChem → CML → AsciiChem round-trip.
    #
    # The mechanism: post-process the CML XML emitted by chemicalml
    # to add `aci:` attributes for atoms that carry extension data.
    # On parse, read the `aci:` attributes back. CML tools that don't
    # recognise the namespace simply ignore the attributes — schema
    # validity is preserved.
    #
    # Adding a new extension field is one entry in `FIELDS` and one
    # writer/reader pair. No other code changes. This is the OCP
    # extension point for "fields CML doesn't natively carry".
    module Extensions
      NAMESPACE = 'https://asciichem.org/cml-ext'
      PREFIX = 'aci'
      CML_NS = 'http://www.xml-cml.org/schema'

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

      # -- AsciiChem -> CML ------------------------------------------

      # Build the extensions map: `{ atom_id => { field: value } }`.
      # Values are Ruby-native (Integer for counts, String for
      # oxidation state). Atoms without extension data are omitted
      # from the map (so the CML output stays clean for plain atoms).
      def self.collect(atom_mapping)
        atom_mapping.each_with_object({}) do |(atom_id, source_atom), memo|
          data = build_entry(source_atom)
          memo[atom_id] = data unless data.empty?
        end
      end

      def self.build_entry(atom)
        FIELDS.each_with_object({}) do |(attr_name, _wire_name), entry|
          value = atom.public_send(attr_name)
          entry[attr_name] = value if value
        end
      end
      private_class_method :build_entry

      # Inject aci: attributes into a CML XML string. Returns the
      # modified XML. No-op if the extensions map is empty.
      def self.inject(xml, extensions)
        return xml if extensions.empty?

        doc = Nokogiri::XML(xml)
        root = doc.root
        root.add_namespace(PREFIX, NAMESPACE) unless namespace_declared?(root)

        extensions.each do |atom_id, entry|
          atom_el = root.at_xpath("//cml:atom[@id='#{atom_id}']", cml: CML_NS)
          next unless atom_el

          entry.each do |attr_name, value|
            wire_name = FIELDS.fetch(attr_name)
            atom_el["#{PREFIX}:#{wire_name}"] = value.to_s
          end
        end

        doc.to_xml
      end

      def self.namespace_declared?(root)
        root.namespaces.value?(NAMESPACE)
      end
      private_class_method :namespace_declared?

      # -- CML -> AsciiChem ------------------------------------------

      # Extract aci: attributes from a CML XML string. Returns a map
      # `{ atom_id => { field: value } }` with Ruby-native types
      # (Integer for counts, String for oxidation state). Empty if no
      # aci: attributes are present.
      def self.extract(xml)
        doc = Nokogiri::XML(xml)
        result = {}
        doc.xpath('//cml:atom', cml: CML_NS).each do |atom_el|
          atom_id = atom_el['id']
          next unless atom_id

          entry = read_entry(atom_el)
          result[atom_id] = entry unless entry.empty?
        end
        result
      end

      def self.read_entry(atom_el)
        FIELDS.each_with_object({}) do |(attr_name, wire_name), entry|
          value = atom_el["#{PREFIX}:#{wire_name}"]
          entry[attr_name] = cast_from_xml(attr_name, value) if value
        end
      end
      private_class_method :read_entry

      # Cast an XML string back to its Ruby form. Integer counts
      # become Integers; everything else stays a string.
      def self.cast_from_xml(attr_name, value)
        case attr_name
        when :lone_pairs, :radical_electrons then value.to_i
        else value
        end
      end
      private_class_method :cast_from_xml

      # -- Round-trip restore ----------------------------------------

      # Apply extracted extension data to a freshly-parsed
      # AsciiChem::Model::Formula. The `canonical_doc` is the
      # canonical document that produced the formula; it provides
      # the atom-id ordering. Atoms are walked in parallel.
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

      def self.apply_entry(atom, entry)
        entry.each do |attr_name, value|
          atom.public_send(:"#{attr_name}=", value)
        end
      end
      private_class_method :apply_entry

      # Flatten the canonical document's atoms into a single list,
      # in the same order ToCanonical walked them: top-level molecules,
      # then reaction reactants+products, then cascade reactions.
      def self.flatten_canonical_atoms(canonical_doc)
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

      def self.flatten_reaction_atoms(reaction)
        atoms = []
        reactants = reaction.reactant_list
        products = reaction.product_list
        reactants&.reactants&.each { |r| atoms.concat(r.substance.molecule.atom_array&.atoms || []) }
        products&.products&.each { |p| atoms.concat(p.substance.molecule.atom_array&.atoms || []) }
        atoms
      end
      private_class_method :flatten_reaction_atoms

      # Flatten the AsciiChem::Model::Formula's atoms in the same
      # order ToCanonical walks them. Matches `flatten_canonical_atoms`
      # one-for-one so parallel iteration by index works.
      def self.flatten_formula_atoms(formula)
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

      def self.reaction_atoms(reaction)
        atoms = []
        reaction.reactants.each { |m| atoms.concat(flatten_molecule_atoms(m)) }
        reaction.products.each { |m| atoms.concat(flatten_molecule_atoms(m)) }
        atoms
      end
      private_class_method :reaction_atoms

      def self.flatten_molecule_atoms(molecule)
        molecule.nodes.each_with_object([]) do |node, memo|
          case node
          when AsciiChem::Model::Atom
            memo << node
          when AsciiChem::Model::Group, AsciiChem::Model::Molecule
            memo.concat(flatten_molecule_atoms(node))
          end
        end
      end
      private_class_method :flatten_molecule_atoms

      # -- Top-level extensions --------------------------------------
      #
      # AsciiChem::Model node classes that have no canonical equivalent
      # (ElectronConfiguration, EmbeddedMath) ride as `aci:` elements
      # inside `<cml>`. Position in the original formula's node list is
      # preserved via a `position` attribute so restore can re-insert
      # at the right index. The wire format for each handler is the
      # AsciiChem text rendering — round-trip-safe by construction.

      # Registry of top-level handlers. Each handler is a Struct with
      # `node_class`, `element_name`, `serialize`, `deserialize`.
      # Adding a new top-level extension is one handler entry.
      TopLevelHandler = Struct.new(:node_class, :element_name,
                                   :serialize, :deserialize, keyword_init: true)

      TOP_LEVEL_HANDLERS = [
        TopLevelHandler.new(
          node_class: AsciiChem::Model::ElectronConfiguration,
          element_name: 'electronConfiguration',
          serialize: ->(node) { text_render(node) },
          deserialize: ->(content) { AsciiChem.parse(content).nodes.first }
        ),
        TopLevelHandler.new(
          node_class: AsciiChem::Model::EmbeddedMath,
          element_name: 'embeddedMath',
          serialize: ->(node) { node.source.to_s },
          deserialize: ->(content) { AsciiChem.parse("`#{content}`").nodes.first }
        ),
        TopLevelHandler.new(
          node_class: AsciiChem::Model::Text,
          element_name: 'text',
          # Text formatter emits `"content"` (with quotes). Re-parsing
          # that yields the original Text node — round-trip-safe by
          # construction.
          serialize: ->(node) { text_render(node) },
          deserialize: ->(content) { AsciiChem.parse(content).nodes.first }
        )
      ].freeze

      # Build the top-level extensions list from a formula. Returns an
      # array of `{ position:, element_name:, content: }` hashes. The
      # position is the index in the original formula's node list.
      def self.collect_top_level(formula)
        handlers_by_class = top_level_handlers_by_class
        formula.nodes.each_with_index.with_object([]) do |(node, idx), memo|
          handler = handlers_by_class[node.class]
          next unless handler

          memo << {
            position: idx,
            element_name: handler.element_name,
            content: handler.serialize.call(node)
          }
        end
      end

      # Inject top-level extensions into CML XML as `aci:` elements
      # inside `<cml>`. No-op if the list is empty.
      def self.inject_top_level(xml, top_level)
        return xml if top_level.empty?

        doc = Nokogiri::XML(xml)
        root = doc.root
        ensure_namespace(root)
        top_level.each { |entry| insert_top_level_element(doc, root, entry) }
        doc.to_xml
      end

      def self.ensure_namespace(root)
        root.add_namespace(PREFIX, NAMESPACE) unless namespace_declared?(root)
      end
      private_class_method :ensure_namespace

      def self.insert_top_level_element(doc, root, entry)
        element = doc.create_element("#{PREFIX}:#{entry[:element_name]}")
        element['position'] = entry[:position].to_s
        element.content = entry[:content]
        # Insert before existing children so extensions appear at the
        # top of <cml>, which reads more naturally than appended.
        root.children.first&.add_previous_sibling(element) || root.add_child(element)
      end
      private_class_method :insert_top_level_element

      # Extract `aci:` top-level elements from CML XML. Returns an
      # array of `{ position:, element_name:, content: }` hashes in
      # ascending position order.
      def self.extract_top_level(xml)
        doc = Nokogiri::XML(xml)
        result = []
        element_names = TOP_LEVEL_HANDLERS.map(&:element_name)
        element_names.each do |name|
          doc.xpath("//#{PREFIX}:#{name}", PREFIX => NAMESPACE).each do |el|
            result << {
              position: (el['position'] || 0).to_i,
              element_name: name,
              content: el.content
            }
          end
        end
        result.sort_by { |entry| entry[:position] }
      end

      # Restore top-level extension nodes into a freshly-parsed
      # formula. Inserts each node at its original position; nodes
      # are inserted in ascending position order so earlier inserts
      # don't shift later positions.
      def self.restore_top_level(formula, top_level)
        handlers_by_element = top_level_handlers_by_element
        top_level.sort_by { |entry| entry[:position] }.each do |entry|
          handler = handlers_by_element[entry[:element_name]]
          next unless handler

          node = handler.deserialize.call(entry[:content])
          next unless node

          pos = [entry[:position], formula.nodes.length].min
          formula.nodes.insert(pos, node)
        end
        formula
      end

      def self.top_level_handlers_by_class
        TOP_LEVEL_HANDLERS.to_h do |h|
          [h.node_class, h]
        end
      end
      private_class_method :top_level_handlers_by_class

      def self.top_level_handlers_by_element
        TOP_LEVEL_HANDLERS.to_h do |h|
          [h.element_name, h]
        end
      end
      private_class_method :top_level_handlers_by_element

      # Render a node using the AsciiChem Text formatter. The output
      # is round-trip-safe by construction (Text is the canonicaliser).
      def self.text_render(node)
        AsciiChem::Formatter.render(:text, node)
      end
      private_class_method :text_render
    end
  end
end
