# frozen_string_literal: true

module AsciiChem
  module Linter
    # Validates Z-Matrix references: each ref1/ref2/ref3 must name an
    # atom that appears in an earlier row. Catches ordering mistakes
    # that would otherwise produce dangling references downstream.
    #
    # Also checks geometric sanity: distances must be positive, angles
    # in (0, 180], dihedrals in [-180, 180].
    class ZMatrixReferenceCheck < Base
      register :zmatrix_references

      ANGLE_RANGE = (0.0..180.0)
      DIHEDRAL_RANGE = (-180.0..180.0)

      def run(formula)
        diagnostics = []
        walk(formula) do |node|
          next unless node.is_a?(AsciiChem::Model::ZMatrix)

          check_references(node, diagnostics)
          check_geometry(node, diagnostics)
        end
        diagnostics
      end

      private

      def check_references(zmatrix, diagnostics)
        seen = Set.new
        zmatrix.rows.each do |row|
          seen << row.atom
          %i[ref1 ref2 ref3].each do |ref_attr|
            ref = row.public_send(ref_attr)
            next unless ref
            next if seen.include?(ref)

            diagnostics << error(
              "ZMatrix row references #{ref.inspect} before it is defined",
              node: zmatrix
            )
          end
        end
      end

      def check_geometry(zmatrix, diagnostics)
        zmatrix.rows.each do |row|
          check_distance(row, zmatrix, diagnostics) if row.distance
          check_angle(row, zmatrix, diagnostics) if row.angle
          check_dihedral(row, zmatrix, diagnostics) if row.dihedral
        end
      end

      def check_distance(row, zmatrix, diagnostics)
        value = Float(row.distance, exception: false)
        return unless value
        return if value.positive?

        diagnostics << error(
          "ZMatrix distance must be positive, got #{row.distance}",
          node: zmatrix
        )
      end

      def check_angle(row, zmatrix, diagnostics)
        value = Float(row.angle, exception: false)
        return unless value
        return if ANGLE_RANGE.cover?(value) && !value.zero?

        diagnostics << error(
          "ZMatrix angle must be in (0, 180], got #{row.angle}",
          node: zmatrix
        )
      end

      def check_dihedral(row, zmatrix, diagnostics)
        value = Float(row.dihedral, exception: false)
        return unless value
        return if DIHEDRAL_RANGE.cover?(value)

        diagnostics << error(
          "ZMatrix dihedral must be in [-180, 180], got #{row.dihedral}",
          node: zmatrix
        )
      end
    end
  end
end
