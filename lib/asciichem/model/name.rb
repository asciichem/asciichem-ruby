# frozen_string_literal: true

module AsciiChem
  module Model
    # A molecule name. Maps to CML `<name>` element. Carries the
    # name content plus optional `convention` and `dict_ref`
    # attributes for names sourced from dictionaries (IUPAC, CAS,
    # trivial, etc.).
    Name = Struct.new(:content, :convention, :dict_ref, keyword_init: true) do
      def to_s
        content.to_s
      end
    end
  end
end
