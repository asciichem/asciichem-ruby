# frozen_string_literal: true

module AsciiChem
  module Identifiers
    # SMILES sanity validation. This is deliberately *not* a SMILES
    # parser (that arrives with structure interchange, TODO.v2 09) —
    # it catches corruption: whitespace, unbalanced brackets and
    # parentheses, unpaired ring-bond digits, and element tokens that
    # are not in the periodic table.
    #
    # Lowercase aromatic atoms (c1ccccc1) are valid SMILES and pass;
    # aromaticity only constrains future *ingestion* (Kekulé-first),
    # not identifier validity.
    class Smiles < Base
      register "smiles"

      ORGANIC_SUBSET = %w[B C N O P S F I Cl Br H].freeze
      AROMATIC_SUBSET = %w[b c n o p s f cl br].freeze
      BRACKET_SYMBOL = /\A\d*([A-Z][a-z]{0,2}|\*)/

      class << self
        def diagnostic(value)
          return type_message(value) unless value.is_a?(String)
          return "SMILES must not be empty" if value.empty?
          return "SMILES #{value.inspect} must not contain whitespace" if value.match?(/\s/)

          structural_reasons(value) || element_reasons(value)
        end

        # Sorted unique element symbols appearing in the SMILES
        # (bracket atoms and the organic/aromatic subsets, aromatic
        # normalised to element symbols), or nil when the value is
        # not analysable. Single source of truth for offline
        # SMILES/molecule element-set checks.
        def element_set(value)
          return nil unless value.is_a?(String)
          return nil unless structural_reasons(value).nil?

          symbols = []
          index = 0
          while index < value.length
            index, analysable = advance(value, index, symbols)
            return nil unless analysable
          end
          symbols.uniq.sort
        end

        private

        def type_message(value)
          "SMILES must be a String, got #{value.class}"
        end

        # nil when structurally plausible; a reason otherwise.
        def structural_reasons(value)
          return "SMILES #{value.inspect}: square brackets are not balanced" unless balanced?(value, "[", "]")
          return "SMILES #{value.inspect}: parentheses are not balanced" unless balanced?(value, "(", ")")

          # Ring digits only exist outside brackets — bracket interiors
          # hold isotope/H-count digits, which must not pair up.
          bare = value.gsub(/\[[^\]]*\]/, "")
          unpaired = bare.scan(/\d/).tally.find { |_digit, count| count.odd? }
          if unpaired
            return "SMILES #{value.inspect}: ring-bond digit #{unpaired[0]} appears an odd " \
                   "number of times (ring closures must pair)"
          end

          nil
        end

        def balanced?(value, opener, closer)
          depth = 0
          value.each_char do |char|
            depth += 1 if char == opener
            depth -= 1 if char == closer
            return false if depth.negative?
          end
          depth.zero?
        end

        # Returns a reason for the first unknown element token, or nil.
        def element_reasons(value)
          return nil if element_set(value)

          "SMILES #{value.inspect}: contains a malformed or unknown element token"
        end

        # Advances past the token at `index`, appending its element
        # symbol to `symbols`. Returns [new_index, analysable].
        def advance(value, index, symbols)
          char = value[index]
          if char == "["
            consume_bracket_atom(value, index, symbols)
          elsif char.match?(/[A-Za-z]/)
            consume_organic_atom(value, index, symbols)
          else
            [index + 1, true]
          end
        end

        def consume_bracket_atom(value, index, symbols)
          close = value.index("]", index)
          return [0, false] unless close

          symbol = bracket_atom_symbol(value[(index + 1)...close])
          return [0, false] if symbol.nil?

          symbols << symbol
          [close + 1, true]
        end

        def consume_organic_atom(value, index, symbols)
          token = two_letter_token(value, index, value[index])
          return [0, false] if token.nil?

          symbols << token[0]
          [index + token[1], true]
        end

        # Two-letter element first (Cl/Br, aromatic cl/br), then the
        # single-letter organic/aromatic subsets. Returns [symbol,
        # consumed_length] or nil.
        def two_letter_token(value, index, char)
          two = value[index, 2]
          return [two, 2] if ORGANIC_SUBSET.include?(two)
          return [two.capitalize, 2] if AROMATIC_SUBSET.include?(two)
          return [char, 1] if ORGANIC_SUBSET.include?(char)
          return [char.upcase, 1] if AROMATIC_SUBSET.include?(char)

          nil
        end

        # Bracket atom content: optional isotope digits, then the
        # symbol. Wildcards make composition unknown → nil.
        def bracket_atom_symbol(content)
          match = BRACKET_SYMBOL.match(content)
          return nil if match.nil?

          symbol = match[1]
          return nil if symbol == "*"

          AsciiChem::PeriodicTable.known?(symbol) ? symbol : nil
        end
      end
    end
  end
end
