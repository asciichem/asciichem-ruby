# frozen_string_literal: true

require "chemicalml"

module AsciiChem
  # CML support for AsciiChem. The translator converts between the
  # chemistry-semantic AsciiChem::Model and the CML wire format
  # (modelled by ChemicalML::Cml).
  #
  # Two directions:
  #   AsciiChem::Model -> ChemicalML::Cml::Document -> XML
  #   XML -> ChemicalML::Cml::Document -> AsciiChem::Model
  #
  # The translator is the only place where the two model layers
  # touch. Each model stays independent; adding a new AsciiChem
  # model field means updating the translator's mapping rules and
  # (where CML doesn't natively cover the field) the extension
  # namespace.
  module Cml
    autoload :Translator, "asciichem/cml/translator"

    DEFAULT_NAMESPACE = "https://asciichem.org/cml-ext".freeze

    # Parse CML XML into an AsciiChem::Model::Formula.
    def self.parse(xml)
      document = ChemicalML::Cml::Document.from_xml(xml)
      Translator.to_asciichem(document)
    end

    # Serialise an AsciiChem::Model::Formula to CML XML.
    def self.from_asciichem(formula)
      document = Translator.from_asciichem(formula)
      document.to_xml
    end
  end
end
