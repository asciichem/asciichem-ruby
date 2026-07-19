# frozen_string_literal: true

module AsciiChem
  module Linter
    # Validates unit-cell parameters on a Crystal node:
    #   - lengths (a, b, c) must be positive
    #   - angles (alpha, beta, gamma) must be in (0, 180] degrees
    #   - fractional coordinates on atoms must be in [0, 1)
    #
    # Each cell parameter is optional in the model (a partial crystal
    # description is allowed), so missing values are skipped, not flagged.
    class CrystalSanityCheck < Base
      register :crystal_sanity

      ANGLE_RANGE = (0.0..180.0)

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::Crystal)

          check_lengths(node, diagnostics)
          check_angles(node, diagnostics)
          check_fractional_coords(node, diagnostics)
        end
        diagnostics
      end

      private

      def check_lengths(crystal, diagnostics)
        AsciiChem::Model::Crystal::LENGTH_FIELDS.each do |dim|
          value = crystal.public_send(dim)
          next if value.nil?

          num = Float(value, exception: false)
          next unless num

          next if num.positive?

          diagnostics << error(
            "Crystal #{dim} must be positive, got #{value}",
            node: crystal
          )
        end
      end

      def check_angles(crystal, diagnostics)
        AsciiChem::Model::Crystal::ANGLE_FIELDS.each do |dim|
          value = crystal.public_send(dim)
          next if value.nil?

          num = Float(value, exception: false)
          next unless num

          next if ANGLE_RANGE.cover?(num) && !num.zero?

          diagnostics << error(
            "Crystal #{dim} must be in (0, 180], got #{value}",
            node: crystal
          )
        end
      end

      def check_fractional_coords(crystal, diagnostics)
        crystal.atoms.each do |atom|
          check_one_axis(atom, :x_fract, crystal, diagnostics)
          check_one_axis(atom, :y_fract, crystal, diagnostics)
          check_one_axis(atom, :z_fract, crystal, diagnostics)
        end
      end

      def check_one_axis(atom, attr, crystal, diagnostics)
        value = atom.public_send(attr)
        return if value.nil?

        num = Float(value, exception: false)
        return unless num

        return if num >= 0 && num < 1

        diagnostics << warning(
          "Fractional coordinate #{attr}=#{value} on #{atom.element} " \
          "is outside [0, 1)",
          node: crystal
        )
      end
    end
  end
end
