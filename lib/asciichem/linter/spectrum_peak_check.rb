# frozen_string_literal: true

module AsciiChem
  module Linter
    # Validates spectrum peak data:
    #   - peak positions must be parseable numbers (warn on non-numeric)
    #   - intensities, when numeric, must be non-negative
    #
    # Does NOT enforce domain-specific ranges (e.g. 0-12 ppm for 1H NMR,
    # 0-220 ppm for 13C NMR) — those depend on instrument and solvent
    # and would over-fit. The structural sanity check is enough.
    class SpectrumPeakCheck < Base
      register :spectrum_peaks

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Spectrum)

          node.peaks.each { |peak| check_peak(peak, node, diagnostics) }
        end
        diagnostics
      end

      private

      def check_peak(peak, spectrum, diagnostics)
        check_position(peak, spectrum, diagnostics)
        check_intensity(peak, spectrum, diagnostics)
      end

      def check_position(peak, spectrum, diagnostics)
        position = leading_number(peak.position)
        return unless peak.position

        if position.nil?
          diagnostics << warning(
            "Spectrum peak position #{peak.position.inspect} is not numeric",
            node: spectrum
          )
          return
        end
        return unless position.negative?

        diagnostics << warning(
          "Spectrum peak position #{position} is negative",
          node: spectrum
        )
      end

      def check_intensity(peak, spectrum, diagnostics)
        intensity = leading_number(peak.intensity)
        return unless intensity&.negative?

        diagnostics << warning(
          "Spectrum peak intensity #{intensity} is negative",
          node: spectrum
        )
      end

      # Extract a leading signed number from a string like "-3H" → -3.0,
      # "100%" → 100.0, "abc" → nil. Tolerant of unit suffixes which are
      # common in peak data (H, %, coulombs, etc.).
      def leading_number(raw)
        return nil if raw.nil?

        match = raw.to_s.match(/\A\s*(?<n>-?\d+(?:\.\d+)?)/)
        match ? Float(match[:n]) : nil
      end
    end
  end
end
