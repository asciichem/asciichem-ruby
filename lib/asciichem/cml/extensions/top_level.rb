# frozen_string_literal: true

require 'nokogiri'
require 'set'

module AsciiChem
  module Cml
    module Extensions
      # Top-level construct extension channel: carries AsciiChem model
      # classes that have no CML wire equivalent (ElectronConfiguration,
      # EmbeddedMath, Text, Crystal, Spectrum, Calculation, ZMatrix,
      # Mechanism) as `aci:<element_name>` children of `<cml>`.
      #
      # Position in the original formula's node list is preserved via a
      # `position` attribute so restore can re-insert at the right index.
      # The wire format for each handler is the AsciiChem text rendering
      # — round-trip-safe by construction (Text formatter is the
      # canonicaliser).
      module TopLevel
        # Registry of handlers. Each is a Struct with `node_class`,
        # `element_name`, `serialize`, `deserialize`. Adding a new
        # top-level extension is one factory call.
        #
        # Factory methods on the struct eliminate the duplicated
        # serialize/deserialize lambdas. A construct needing bespoke
        # logic calls `.new(...)` directly with custom lambdas.
        # Registry entry mapping a model class to its aci: wire element.
        # Construct via the factory methods (.text_round_trip,
        # .source_with_wrapper) instead of .new where possible.
        Handler = Struct.new(:node_class, :element_name,
                             :serialize, :deserialize, keyword_init: true)

        class Handler
          # Default pattern: serialize via Text formatter, deserialize
          # by re-parsing. Round-trip-safe by construction.
          def self.text_round_trip(node_class:, element_name:)
            new(
              node_class: node_class,
              element_name: element_name,
              serialize: ->(node) { AsciiChem::Formatter.render(:text, node) },
              deserialize: ->(content) { AsciiChem.parse(content).nodes.first }
            )
          end

          # Pattern for constructs whose text format wraps content in
          # delimiter chars (e.g. EmbeddedMath wraps in backticks) and
          # whose model carries the unwrapped form in `source`.
          def self.source_with_wrapper(node_class:, element_name:, wrapper:)
            new(
              node_class: node_class,
              element_name: element_name,
              serialize: ->(node) { node.source.to_s },
              deserialize: ->(content) { AsciiChem.parse("#{wrapper}#{content}#{wrapper}").nodes.first }
            )
          end
        end

        HANDLERS = [
          Handler.text_round_trip(
            node_class: AsciiChem::Model::ElectronConfiguration,
            element_name: 'electronConfiguration'
          ),
          Handler.source_with_wrapper(
            node_class: AsciiChem::Model::EmbeddedMath,
            element_name: 'embeddedMath',
            wrapper: '`'
          ),
          Handler.text_round_trip(
            node_class: AsciiChem::Model::Text,
            element_name: 'text'
          ),
          # Beyond-formulas constructs — each carries its text rendering
          # inside an aci: element. On parse, the text is re-parsed.
          Handler.text_round_trip(
            node_class: AsciiChem::Model::Crystal,
            element_name: 'crystal'
          ),
          Handler.text_round_trip(
            node_class: AsciiChem::Model::Spectrum,
            element_name: 'spectrum'
          ),
          Handler.text_round_trip(
            node_class: AsciiChem::Model::Calculation,
            element_name: 'calculation'
          ),
          Handler.text_round_trip(
            node_class: AsciiChem::Model::ZMatrix,
            element_name: 'zmatrix'
          ),
          Handler.text_round_trip(
            node_class: AsciiChem::Model::Mechanism,
            element_name: 'mechanism'
          )
        ].freeze

        # Build the top-level extensions list from a formula. Returns
        # an array of `{ position:, element_name:, content: }` hashes.
        # Pass `skip_classes:` to suppress the aci: text carrier for
        # constructs that have native wire representation elsewhere
        # in the pipeline (e.g. Crystal via chemicalml 0.3.0).
        def self.collect(formula, skip_classes: [])
          handlers_by_class = HANDLERS.to_h { |h| [h.node_class, h] }
          skip_set = skip_classes.to_set
          formula.nodes.each_with_index.with_object([]) do |(node, idx), memo|
            next if skip_set.include?(node.class)

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
        def self.inject(xml, top_level)
          return xml if top_level.empty?

          doc = Nokogiri::XML(xml)
          root = doc.root
          unless root.namespaces.value?(Extensions::NAMESPACE)
            root.add_namespace(Extensions::PREFIX, Extensions::NAMESPACE)
          end
          top_level.each { |entry| insert_element(doc, root, entry) }
          doc.to_xml
        end

        # Extract `aci:` top-level elements from CML XML. Returns an
        # array of `{ position:, element_name:, content: }` hashes in
        # ascending position order.
        def self.extract(xml)
          doc = Nokogiri::XML(xml)
          result = []
          element_names = HANDLERS.map(&:element_name)
          element_names.each do |name|
            doc.xpath("//#{Extensions::PREFIX}:#{name}",
                      Extensions::PREFIX => Extensions::NAMESPACE).each do |el|
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
        def self.restore(formula, top_level)
          handlers_by_element = HANDLERS.to_h { |h| [h.element_name, h] }
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

        class << self
          private

          def insert_element(doc, root, entry)
            element = doc.create_element("#{Extensions::PREFIX}:#{entry[:element_name]}")
            element['position'] = entry[:position].to_s
            element.content = entry[:content]
            # Insert before existing children so extensions appear at
            # the top of <cml>, which reads more naturally than appended.
            root.children.first&.add_previous_sibling(element) || root.add_child(element)
          end
        end
      end
    end
  end
end
