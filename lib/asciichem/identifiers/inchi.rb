# frozen_string_literal: true

module AsciiChem
  module Identifiers
    # IUPAC International Chemical Identifier (InChI) lexical
    # validation: versioned prefix plus a well-formed formula layer
    # whose element symbols exist in the periodic table. Layers after
    # the formula layer are not validated — full InChI semantics is
    # the InChI software's job (TODO.v2 10), not a linter's.
    class Inchi < Base
      register "inchi"

      PREFIX = %r{\AInChI=1S?/}
      ELEMENT_TOKEN = /([A-Z][a-z]?)(\d*)/

      class << self
        def diagnostic(value)
          return type_message(value) unless value.is_a?(String)

          layer = formula_layer(value)
          return prefix_message(value) if layer.nil?

          counts, reason = parse_formula_layer(layer)
          return nil if counts

          "InChI #{value.inspect}: #{reason}"
        end

        # Hash of element symbol => atom count from the formula layer,
        # or nil when the value is not analysable. Single source of
        # truth for offline InChI/molecule composition checks.
        def formula_counts(value)
          return nil unless value.is_a?(String)

          layer = formula_layer(value)
          return nil if layer.nil?

          counts, = parse_formula_layer(layer)
          counts
        end

        private

        def type_message(value)
          "InChI must be a String, got #{value.class}"
        end

        def prefix_message(value)
          "InChI #{value.inspect} must start with \"InChI=1/\" or \"InChI=1S/\""
        end

        # The formula layer: the segment between the prefix and the
        # first subsequent "/" (e.g. "C9H8O4" in
        # "InChI=1S/C9H8O4/c1-6(10)...").
        def formula_layer(value)
          match = PREFIX.match(value)
          return nil if match.nil?

          rest = match.post_match
          rest.empty? ? "" : rest.split("/").first
        end

        # Returns [counts_hash, nil] on success or [nil, reason].
        def parse_formula_layer(layer)
          return [nil, "formula layer is empty"] if layer.empty?

          counts = Hash.new(0)
          rest = layer
          until rest.empty?
            symbol, count, remainder, reason = next_element_token(rest)
            return [nil, reason] if reason

            counts[symbol] += count
            rest = remainder
          end
          [counts, nil]
        end

        # Consumes the element token at the head of `rest`. Returns
        # [symbol, count, remainder, nil] on success, or
        # [nil, nil, nil, reason] when the token is malformed or
        # unknown.
        def next_element_token(rest)
          token = ELEMENT_TOKEN.match(rest)
          return malformed(rest) if token.nil? || !token.begin(0).zero?

          symbol = token[1]
          return unknown(symbol) unless AsciiChem::PeriodicTable.known?(symbol)

          count = token[2].empty? ? 1 : token[2].to_i
          [symbol, count, token.post_match, nil]
        end

        def malformed(rest)
          [nil, nil, nil, "malformed formula layer near #{rest.inspect}"]
        end

        def unknown(symbol)
          [nil, nil, nil, "unknown element symbol #{symbol.inspect} in formula layer"]
        end
      end
    end
  end
end
