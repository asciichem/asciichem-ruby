# frozen_string_literal: true

module AsciiChem
  module Linter
    # Verifies that group brackets are matched. The grammar already
    # enforces this at parse time, but the linter adds defence in depth
    # in case future grammar changes or direct model construction
    # produce malformed trees.
    class BracketBalanceCheck < Base
      register :bracket_balance

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Group)

          case node.bracket
          when :paren  then check_pair(node, "(", ")", diagnostics)
          when :square then check_pair(node, "[", "]", diagnostics)
          when :brace  then check_pair(node, "{", "}", diagnostics)
          end
        end
        diagnostics
      end

      private

      def check_pair(group, open_char, close_char, diagnostics)
        if group.open_char != open_char
          diagnostics << error(
            "Group bracket kind #{group.bracket.inspect} expected opening #{open_char.inspect}, got #{group.open_char.inspect}",
            node: group
          )
        end
        return if group.close_char == close_char

        diagnostics << error(
          "Group bracket kind #{group.bracket.inspect} expected closing #{close_char.inspect}, got #{group.close_char.inspect}",
          node: group
        )
      end
    end
  end
end
