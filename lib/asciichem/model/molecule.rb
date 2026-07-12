# frozen_string_literal: true

module AsciiChem
  module Model
    # A molecule: an ordered sequence of atoms/groups with optional
    # leading stoichiometric coefficient.
    class Molecule < Node
      attr_accessor :coefficient, :nodes

      def initialize(nodes:, coefficient: nil)
        @nodes = nodes
        @coefficient = coefficient
      end

      def value_attributes
        { nodes: nodes, coefficient: coefficient }
      end

      def to_s
        prefix = coefficient ? "#{coefficient}" : ""
        "#{prefix}Molecule[#{nodes.map(&:to_s).join(', ')}]"
      end
    end
  end
end
