# frozen_string_literal: true

module AsciiChem
  module Identifiers
    # CAS Registry Number format and check-digit validation.
    #
    # A CAS RN is DDDDDDD-DD-D: 2–7 digits, hyphen, 2 digits, hyphen,
    # one check digit. The check digit equals the weighted sum of the
    # preceding digits (weights 1..n counted from the right) modulo 10.
    # Reference for the published algorithm:
    # github.com/simonengelke/CAS_Validation (MIT) — reimplemented,
    # not copied.
    class Cas < Base
      register "cas"

      FORMAT = /\A\d{2,7}-\d{2}-\d\z/

      class << self
        def diagnostic(value)
          return type_message(value) unless value.is_a?(String)
          unless FORMAT.match?(value)
            return "CAS RN #{value.inspect} is not in DDDDDDD-DD-D form " \
                   "(2–7 digits, 2 digits, 1 check digit)"
          end

          expected = weighted_sum(value) % 10
          return nil if check_digit(value) == expected

          "CAS RN #{value.inspect}: check digit #{check_digit(value)} does not " \
            "match weighted sum (#{expected})"
        end

        private

        def type_message(value)
          "CAS RN must be a String, got #{value.class}"
        end

        def digits(value)
          value.delete("-").chars.map(&:to_i)
        end

        def check_digit(value)
          digits(value).last
        end

        # Sum of each digit before the check digit, weighted by its
        # position counted from the right (the neighbour of the check
        # digit has weight 1).
        def weighted_sum(value)
          digits(value)[0..-2].reverse.each_with_index.sum { |d, i| d * (i + 1) }
        end
      end
    end
  end
end
