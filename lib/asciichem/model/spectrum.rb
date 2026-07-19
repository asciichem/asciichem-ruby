# frozen_string_literal: true

module AsciiChem
  module Model
    # A spectroscopy result: NMR, IR, MS, UV-Vis peaks.
    #
    # Syntax:
    #   spectrum[nmr](type=1H,solvent=CDCl3){
    #     1.2: 3H s "CH3"
    #     7.2: 5H m "C6H5"
    #   }
    #
    #   spectrum[ir]{
    #     3300: broad "O-H stretch"
    #   }
    #
    #   spectrum[ms]{
    #     18: 100% "M+"
    #   }
    class Spectrum < Node
      # A single spectroscopic peak. Fields are optional (e.g. MS peaks
      # have no multiplicity; IR peaks may have no assignment).
      Peak = Struct.new(:position, :intensity, :multiplicity,
                        :assignment, keyword_init: true)

      attr_accessor :type, :params, :peaks

      def initialize(type: nil, params: {}, peaks: [])
        @type = type
        @params = params
        @peaks = peaks
      end

      def value_attributes
        { type: type, params: params, peaks: peaks }
      end

      def children
        []
      end

      def diagnostic_label
        "Spectrum(#{type || 'unknown'})"
      end

      def to_s
        "spectrum[#{type}](#{params.map { |k, v| "#{k}=#{v}" }.join(',')})"
      end
    end
  end
end
