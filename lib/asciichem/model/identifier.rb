# frozen_string_literal: true

module AsciiChem
  module Model
    # A molecule identifier. Maps to CML `<identifier>` element.
    # Carries the identifier value plus `convention` (e.g. "inchi",
    # "smiles", "cas") and optional `dict_ref`.
    Identifier = Struct.new(:value, :convention, :dict_ref, keyword_init: true) do
      def to_s
        "#{convention}:#{value}"
      end
    end
  end
end
