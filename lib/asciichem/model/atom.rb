# frozen_string_literal: true

module AsciiChem
  module Model
    # A chemical atom: element symbol plus optional isotope, charge,
    # oxidation state, and Lewis markers (lone pairs, radicals).
    #
    # The semantic fix over AsciiMath: the prefix isotope (e.g. `^14` in
    # `^14C`) binds to THIS atom as the `isotope` field, not to a phantom
    # preceding element. The transform enforces the binding.
    class Atom < Node
      attr_accessor :element, :isotope, :subscript, :superscript,
                    :charge, :oxidation_state,
                    :lone_pairs, :radical_electrons

      def initialize(element:, isotope: nil, subscript: nil,
                     superscript: nil, charge: nil, oxidation_state: nil,
                     lone_pairs: nil, radical_electrons: nil)
        @element = element
        @isotope = isotope
        @subscript = subscript
        @superscript = superscript
        @charge = charge
        @oxidation_state = oxidation_state
        @lone_pairs = lone_pairs
        @radical_electrons = radical_electrons
      end

      def value_attributes
        { element: element, isotope: isotope, subscript: subscript,
          superscript: superscript, charge: charge,
          oxidation_state: oxidation_state,
          lone_pairs: lone_pairs, radical_electrons: radical_electrons }
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
        "Atom(#{parts.join})"
      end
    end
  end
end
