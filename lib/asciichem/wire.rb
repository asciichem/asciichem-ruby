# frozen_string_literal: true

require "lutaml/model"

module AsciiChem
  # Canonical wire form of the semantic model (the JSON interchange
  # format defined by asciichem-model v1). Wire classes are
  # lutaml-model Serializables: every (de)serialization goes through
  # the framework's `json do map ... end` declarations — never
  # hand-rolled key manipulation. AsciiChem::WireAdapter converts
  # between the domain Model::* tree and this wire tree, exactly as
  # ModelAdapter bridges AsciiChem::Model and Chemicalml::Model.
  module Wire
    # Discriminator ("atom", "molecule", ...) => wire class. Filled
    # by Base.wire_type at class-definition time.
    REGISTRY = {}

    autoload :Base, "asciichem/wire/base"
    autoload :Atom, "asciichem/wire/core"
    autoload :Molecule, "asciichem/wire/core"
    autoload :Group, "asciichem/wire/core"
    autoload :Bond, "asciichem/wire/core"
    autoload :Identifier, "asciichem/wire/core"
    autoload :Name, "asciichem/wire/core"
    autoload :Formula, "asciichem/wire/chemistry"
    autoload :Reaction, "asciichem/wire/chemistry"
    autoload :ReactionConditions, "asciichem/wire/chemistry"
    autoload :ReactionCascade, "asciichem/wire/chemistry"
    autoload :ElectronConfiguration, "asciichem/wire/chemistry"
    autoload :OrbitalOccupancy, "asciichem/wire/chemistry"
    autoload :TermSymbol, "asciichem/wire/chemistry"
    autoload :EmbeddedMath, "asciichem/wire/chemistry"
    autoload :Text, "asciichem/wire/chemistry"
    autoload :Mechanism, "asciichem/wire/extended"
    autoload :MechanismStep, "asciichem/wire/extended"
    autoload :Spectrum, "asciichem/wire/extended"
    autoload :SpectrumPeak, "asciichem/wire/extended"
    autoload :Crystal, "asciichem/wire/extended"
    autoload :ZMatrix, "asciichem/wire/extended"
    autoload :ZRow, "asciichem/wire/extended"
    autoload :Calculation, "asciichem/wire/extended"
    autoload :CalculatedProperty, "asciichem/wire/extended"
    autoload :Provenance, "asciichem/wire/identity"
    autoload :SubstanceRecord, "asciichem/wire/identity"
    autoload :ProvenancedIdentifier, "asciichem/wire/identity"
    autoload :ProvenancedProperty, "asciichem/wire/identity"

    # Eagerly trigger every autoload so wire classes register their
    # discriminators before any lookup (same pattern as Linter).
    constants.each { |name| const_get(name) unless name == :REGISTRY }
  end
end
