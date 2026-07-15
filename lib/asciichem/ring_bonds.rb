# frozen_string_literal: true

module AsciiChem
  # Derives ring bonds from atoms with matching `ring_closures` digits.
  # Single source of truth for the "find ring bond pairs" algorithm —
  # used by the Layout walker (to emit additional edges), the
  # ModelAdapter walker (to emit additional canonical bonds), and the
  # UnclosedRingCheck linter (to flag unmatched digits).
  #
  # Algorithm: walk atoms in source order. For each digit on each atom,
  # if we've seen it before (open ring), the current atom closes the
  # ring — yield a RingBond pairing them, and clear the open record.
  # Otherwise, record the current atom as the ring's opener.
  #
  # Multiple digits on one atom (`C12`) open/close multiple rings in
  # parallel. Digit "0" through "9" are supported in any order.
  module RingBonds
    RingBond = Struct.new(:digit, :from_atom, :to_atom, keyword_init: true)

    # Yields each RingBond to the block. Walks the molecule in source
    # order so `from_atom` always precedes `to_atom`.
    def self.each_in(molecule)
      open_rings = {}
      walk_atoms(molecule) do |atom|
        next unless atom.ring_closures

        atom.ring_closures.to_s.each_char do |digit|
          if open_rings.key?(digit)
            yield RingBond.new(digit: digit, from_atom: open_rings[digit], to_atom: atom)
            open_rings.delete(digit)
          else
            open_rings[digit] = atom
          end
        end
      end
    end

    # Returns atoms whose ring_closures digits have no matching partner.
    # Used by the UnclosedRingCheck linter.
    def self.unclosed_atoms(molecule)
      open_rings = {}
      unclosed = []
      walk_atoms(molecule) do |atom|
        next unless atom.ring_closures

        atom.ring_closures.to_s.each_char do |digit|
          if open_rings.key?(digit)
            open_rings.delete(digit)
          else
            open_rings[digit] = atom
          end
        end
      end
      open_rings.each_value { |atom| unclosed << atom }
      unclosed
    end

    def self.walk_atoms(node, &block)
      case node
      when AsciiChem::Model::Atom
        block.call(node)
      when AsciiChem::Model::Molecule, AsciiChem::Model::Group
        node.nodes.each { |child| walk_atoms(child, &block) }
      end
    end
    private_class_method :walk_atoms
  end
end
