# frozen_string_literal: true

module AsciiChem
  module Model
    # A molecule: an ordered sequence of atoms/groups with optional
    # leading stoichiometric coefficient and optional stereochemistry
    # marker (R/S/E/Z/α/β).
    class Molecule < Node
      STEREO_LETTERS = {
        "R" => :R,
        "S" => :S,
        "E" => :E,
        "Z" => :Z,
        "a" => :alpha,
        "alpha" => :alpha,
        "α" => :alpha,
        "b" => :beta,
        "beta" => :beta,
        "β" => :beta
      }.freeze

      STEREO_TO_LETTER = {
        R: "R", S: "S", E: "E", Z: "Z",
        alpha: "alpha", beta: "beta"
      }.freeze

      attr_accessor :coefficient, :nodes, :stereo

      def initialize(nodes:, coefficient: nil, stereo: nil)
        @nodes = nodes
        @coefficient = coefficient
        @stereo = stereo
      end

      def value_attributes
        { nodes: nodes, coefficient: coefficient, stereo: stereo }
      end

      def children
        nodes
      end

      def stereo_letter
        STEREO_TO_LETTER.fetch(stereo) if stereo
      end

      def to_s
        prefix = coefficient ? "#{coefficient}" : ""
        stereo_str = stereo ? "(#{stereo_letter})-" : ""
        "#{stereo_str}#{prefix}Molecule[#{nodes.map(&:to_s).join(', ')}]"
      end
    end
  end
end
