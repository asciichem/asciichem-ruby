# frozen_string_literal: true

module AsciiChem
  module Model
    # A chemical atom: element symbol plus optional isotope, charge, and
    # oxidation state markers.
    #
    # The semantic fix over AsciiMath: the prefix isotope (e.g. `^14` in
    # `^14C`) binds to THIS atom as the `isotope` field, not to a phantom
    # preceding element. The transform enforces the binding.
    class Atom < Node
      attr_accessor :element, :isotope, :subscript, :superscript,
                    :charge, :oxidation_state

      def initialize(element:, isotope: nil, subscript: nil,
                     superscript: nil, charge: nil, oxidation_state: nil)
        @element = element
        @isotope = isotope
        @subscript = subscript
        @superscript = superscript
        @charge = charge
        @oxidation_state = oxidation_state
      end

      def value_attributes
        { element: element, isotope: isotope, subscript: subscript,
          superscript: superscript, charge: charge,
          oxidation_state: oxidation_state }
      end

      def to_s
        parts = [element.to_s]
        parts << "^#{isotope}" if isotope
        parts << "_#{subscript}" if subscript
        parts << "^#{superscript}" if superscript
        parts << "^#{charge}" if charge
        parts << "^(#{oxidation_state})" if oxidation_state
        "Atom(#{parts.join})"
      end
    end
  end
end
