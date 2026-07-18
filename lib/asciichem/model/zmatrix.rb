# frozen_string_literal: true

module AsciiChem
  module Model
    # A Z-Matrix: internal coordinates (bond lengths, angles, torsions).
    #
    # Syntax:
    #   zmatrix{
    #     C1
    #     H2  C1  1.09
    #     H3  C1  1.09  H2  109.5
    #     H4  C1  1.09  H2  109.5  H3  120.0
    #   }
    class ZMatrix < Node
      ZRow = Struct.new(:atom, :ref1, :distance, :ref2, :angle, :ref3, :dihedral, keyword_init: true)

      attr_accessor :rows

      def initialize(rows: [])
        @rows = rows
      end

      def value_attributes
        { rows: rows }
      end

      def children
        []
      end

      def diagnostic_label
        "ZMatrix(#{rows.length} rows)"
      end
    end
  end
end
