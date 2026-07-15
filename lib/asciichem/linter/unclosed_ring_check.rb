# frozen_string_literal: true

module AsciiChem
  module Linter
    # Flags ring closure digits that have no matching partner. Catches
    # typos like `C1-C-C` (digit 1 opened but never closed). Uses
    # `AsciiChem::RingBonds.unclosed_atoms` as the source of truth.
    class UnclosedRingCheck < Base
      register :unclosed_ring

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Molecule)

          AsciiChem::RingBonds.unclosed_atoms(node).each do |atom|
            diagnostics << error(
              "Atom has unmatched ring closure digit(s) #{atom.ring_closures.inspect}",
              node: atom
            )
          end
        end
        diagnostics
      end
    end
  end
end
