# frozen_string_literal: true

require "nokogiri"

module AsciiChem
  module Cml
    # Carries unknown CML elements through round-trip as opaque blobs.
    #
    # CML documents may contain elements that AsciiChem has no model
    # class for: `<table>`, `<potential>`, `<band>`, anything from a
    # domain-specific convention. Without this module, chemicalml's
    # Document parser silently drops them on read.
    #
    # The mechanism: pre-process the input XML to extract non-CML
    # top-level elements as OpaqueCml nodes; post-process the output
    # XML to re-inject them. Position is preserved so the round-trip
    # stays structurally faithful.
    #
    # This is the fourth extension channel, parallel to:
    #   - Extensions (atom attributes + top-level constructs)
    #   - GroupExtensions (group structure)
    #   - Metadata (via Extensions inject_metadata)
    module OpaqueExtensions
      CML_NS = "http://www.xml-cml.org/schema"
      ACI_NS = "https://asciichem.org/cml-ext"

      # Walk a formula and collect OpaqueCml nodes with their positions
      # in the formula.nodes array. Non-OpaqueCml nodes are skipped.
      def self.collect(formula)
        formula.nodes.each_with_index.with_object([]) do |(node, idx), memo|
          next unless node.is_a?(AsciiChem::Model::OpaqueCml)

          memo << { position: idx, element_name: node.element_name, raw_xml: node.raw_xml }
        end
      end

      # Inject OpaqueCml nodes as raw XML into the CML output, positioned
      # to match their index in formula.nodes. Each insertion happens at
      # the right place among the molecule/reaction children of <cml>.
      #
      # Strategy: walk formula.nodes in order. For each non-OpaqueCml
      # node, advance a "wire cursor" that counts how many wire
      # children have been emitted before this position. For each
      # OpaqueCml node, insert its raw XML before the wire cursor.
      def self.inject(xml, formula)
        return xml if formula.nodes.empty?

        doc = Nokogiri::XML(xml)
        root = doc.root
        wire_children = root.element_children
        inserts = build_inserts(formula, wire_children.length)
        return xml if inserts.empty?

        apply_inserts(root, wire_children, inserts)
        doc.to_xml
      end

      def self.apply_inserts(root, wire_children, inserts)
        inserts.reverse_each do |wire_index, raw_xml|
          fragment = Nokogiri::XML::DocumentFragment.parse(raw_xml)
          if wire_index >= wire_children.length
            root.add_child(fragment)
          else
            wire_children[wire_index].add_previous_sibling(fragment)
          end
        end
      end
      private_class_method :apply_inserts

      # Build the list of (wire_index, raw_xml) insertions, mapping
      # formula node positions to wire child positions by walking both
      # in parallel. Non-OpaqueCml nodes consume a wire slot; OpaqueCml
      # nodes produce an insertion at the current wire cursor.
      def self.build_inserts(formula, wire_count)
        wire_cursor = 0
        inserts = []
        formula.nodes.each do |node|
          if node.is_a?(AsciiChem::Model::OpaqueCml)
            clamped = [wire_cursor, wire_count].min
            inserts << [clamped, node.raw_xml]
          else
            wire_cursor += 1
          end
        end
        inserts
      end
      private_class_method :build_inserts

      # Extract non-CML top-level elements from input XML. Returns a
      # list of `{ position:, element_name:, raw_xml: }` hashes in
      # document order. Also returns the cleaned XML with the unknown
      # elements removed (so chemicalml's parser doesn't trip).
      def self.extract(xml)
        doc = Nokogiri::XML(xml)
        root = doc.root
        result = []
        children = root.element_children
        children.each_with_index do |child, idx|
          next if cml_namespace?(child)
          next if aci_namespace?(child)

          result << {
            position: idx,
            element_name: child.name,
            raw_xml: child.to_xml(indent: 0).strip
          }
          child.remove
        end
        [result, doc.to_xml]
      end

      def self.cml_namespace?(element)
        ns = element.namespace
        ns && ns.href == CML_NS
      end
      private_class_method :cml_namespace?

      def self.aci_namespace?(element)
        ns = element.namespace
        ns && ns.href == ACI_NS
      end
      private_class_method :aci_namespace?

      # Restore OpaqueCml nodes into a freshly-parsed formula at the
      # recorded positions. Positions are clamped to formula.nodes.length.
      def self.restore(formula, opaque_list)
        return formula if opaque_list.empty?

        # Sort descending so insertions at later positions don't shift
        # earlier insertions. Insert via index = [pos, current_length].min.
        opaque_list.sort_by { |entry| -entry[:position] }.each do |entry|
          pos = [entry[:position], formula.nodes.length].min
          formula.nodes.insert(pos, build_node(entry))
        end
        formula
      end

      def self.build_node(entry)
        AsciiChem::Model::OpaqueCml.new(
          element_name: entry[:element_name],
          raw_xml: entry[:raw_xml]
        )
      end
      private_class_method :build_node
    end
  end
end
