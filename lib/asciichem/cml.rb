# frozen_string_literal: true

module AsciiChem
  # CML (Chemical Markup Language) support for AsciiChem.
  #
  # Bidirectional conversion between the AsciiChem text world and the
  # CML XML world. The pipeline is:
  #
  #   AsciiChem::Model <-> AsciiChem::ModelAdapter <-> Chemicalml::Model
  #                                                        ^
  #                                                        |
  #                                              Chemicalml::Cml::Translator
  #                                                        |
  #                                                        v
  #                                              Chemicalml::Cml::* (wire)
  #
  # The canonical model (Chemicalml::Model) is the format-agnostic
  # hub. AsciiChem and CML each have their own adapter; the adapters
  # never talk to each other directly. Adding a new format (SMILES,
  # InChI, MOL) is a new adapter — none of the existing code changes.
  #
  # Public API:
  #   AsciiChem::Cml.from_asciichem(formula)  # => CML XML string
  #   AsciiChem::Cml.parse(xml)               # => AsciiChem::Model::Formula
  module Cml
    autoload :Extensions, "asciichem/cml/extensions"
    autoload :GroupExtensions, "asciichem/cml/group_extensions"
    autoload :Translator, "asciichem/cml/translator"

    # Serialise an AsciiChem::Model::Formula to CML XML.
    def self.from_asciichem(formula)
      Translator.from_asciichem(formula)
    end

    # Parse CML XML into an AsciiChem::Model::Formula.
    def self.parse(xml)
      Translator.to_asciichem(xml)
    end
  end
end
