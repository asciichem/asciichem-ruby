# frozen_string_literal: true

require "chemicalml"

# Eagerly reference the CML classes so lutaml-model registers them
# before any serialisation attempt. Without this, autoload-deferred
# classes aren't in lutaml-model's type registry and serialisation
# fails with "Unknown type 'atom'".
Chemicalml::Cml::Atom
Chemicalml::Cml::AtomArray
Chemicalml::Cml::Bond
Chemicalml::Cml::BondArray
Chemicalml::Cml::Molecule
Chemicalml::Cml::Name
Chemicalml::Cml::Identifier
Chemicalml::Cml::Substance
Chemicalml::Cml::Reactant
Chemicalml::Cml::ReactantList
Chemicalml::Cml::Product
Chemicalml::Cml::ProductList
Chemicalml::Cml::Reaction
Chemicalml::Cml::ReactionList
Chemicalml::Cml::Document

module AsciiChem
  # CML support for AsciiChem. The translator converts between the
  # chemistry-semantic AsciiChem::Model and the CML wire format
  # (modelled by Chemicalml::Cml).
  #
  # Two directions:
  #   AsciiChem::Model -> Chemicalml::Cml::Document -> XML
  #   XML -> Chemicalml::Cml::Document -> AsciiChem::Model
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
      document = Chemicalml::Cml::Document.from_xml(xml)
      Translator.to_asciichem(document)
    end

    # Serialise an AsciiChem::Model::Formula to CML XML.
    def self.from_asciichem(formula)
      document = Translator.from_asciichem(formula)
      document.to_xml
    end
  end
end
