# frozen_string_literal: true

module AsciiChem
  module Rinchi
    # One decoded component's identity: the standard InChI string, its
    # AuxInfo companion (empty on a bare decode), and the InChIKey.
    Component = Struct.new(:inchi, :aux, :inchikey, keyword_init: true)

    # The decoded reaction — the decode direction's output: the
    # components carry their identities straight from the identifier
    # string (no structures are rebuilt), the direction flag
    # (`:directional` / `:equilibrium`) recovering which group held
    # which role.
    Reaction = Struct.new(:directionality, :reactants, :products, :agents,
                          keyword_init: true)
  end
end
