# frozen_string_literal: true

module AsciiChem
  module Model
    # A computational chemistry calculation result.
    #
    # Syntax:
    #   calc(b3lyp/6-31G*){
    #     energy: -234.5 Hartree
    #     dipole: [0.1, 0.2, 0.3] Debye
    #   }
    class Calculation < Node
      # A single computed property: e.g. energy, dipole moment, charge.
      Property = Struct.new(:title, :value, :units, :dict_ref,
                            :convention, keyword_init: true)

      attr_accessor :method, :basis, :properties

      def initialize(method: nil, basis: nil, properties: [])
        @method = method
        @basis = basis
        @properties = properties
      end

      def value_attributes
        { method: method, basis: basis, properties: properties }
      end

      def children
        []
      end

      def diagnostic_label
        "Calculation(#{method}/#{basis})"
      end
    end
  end
end
