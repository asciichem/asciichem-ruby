# frozen_string_literal: true

module AsciiChem
  module Model
    # A chemical atom: element symbol plus optional isotope, charge,
    # oxidation state, Lewis markers (lone pairs, radicals), and ring
    # closure digits.
    #
    # The semantic fix over AsciiMath: the prefix isotope (e.g. `^14` in
    # `^14C`) binds to THIS atom as the `isotope` field, not to a phantom
    # preceding element. The transform enforces the binding.
    #
    # Ring closures (SMILES-style): a digit suffix on an atom opens or
    # closes a ring. Two atoms with the same digit become bonded.
    # `C1-C-C-C-C-C1` is cyclohexane. The `ring_closures` field carries
    # the digit string (e.g. `"1"`); multiple digits mean multiple
    # open/close points (e.g. `"12"` opens/closes rings 1 and 2).
    class Atom < Node
      attr_accessor :element, :isotope, :subscript, :superscript,
                    :charge, :oxidation_state,
                    :lone_pairs, :radical_electrons,
                    :ring_closures,
                    :x2, :y2, :z2, :atom_parity,
                    :spin_multiplicity, :atom_title,
                    :x_fract, :y_fract, :z_fract

      def initialize(element:, isotope: nil, subscript: nil,
                     superscript: nil, charge: nil, oxidation_state: nil,
                     lone_pairs: nil, radical_electrons: nil,
                     ring_closures: nil,
                     x2: nil, y2: nil, z2: nil, atom_parity: nil,
                     spin_multiplicity: nil, atom_title: nil,
                     x_fract: nil, y_fract: nil, z_fract: nil)
        @element = element
        @isotope = isotope
        @subscript = subscript
        @superscript = superscript
        @charge = charge
        @oxidation_state = oxidation_state
        @lone_pairs = lone_pairs
        @radical_electrons = radical_electrons
        @ring_closures = ring_closures
        @x2 = x2
        @y2 = y2
        @z2 = z2
        @atom_parity = atom_parity
        @spin_multiplicity = spin_multiplicity
        @atom_title = atom_title
        @x_fract = x_fract
        @y_fract = y_fract
        @z_fract = z_fract
      end

      def value_attributes
        { element: element, isotope: isotope, subscript: subscript,
          superscript: superscript, charge: charge,
          oxidation_state: oxidation_state,
          lone_pairs: lone_pairs, radical_electrons: radical_electrons,
          ring_closures: ring_closures,
          x2: x2, y2: y2, z2: z2, atom_parity: atom_parity,
          spin_multiplicity: spin_multiplicity, atom_title: atom_title,
          x_fract: x_fract, y_fract: y_fract, z_fract: z_fract }
      end

      def diagnostic_label
        "Atom(#{element})"
      end

      def to_s
        parts = []
        parts << ":#{lone_pairs}" if lone_pairs
        parts << element.to_s
        parts << "_#{subscript}" if subscript
        parts << "^#{isotope}" if isotope
        parts << "^#{superscript}" if superscript
        parts << "^#{charge}" if charge
        parts << "^(#{oxidation_state})" if oxidation_state
        parts << ".#{radical_electrons}" if radical_electrons
        parts << ring_closures.to_s if ring_closures
        "Atom(#{parts.join})"
      end
    end
  end
end
