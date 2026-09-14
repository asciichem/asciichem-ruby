# frozen_string_literal: true

module AsciiChem
  module Inchi
    # Abstract identity engine. Subclasses wrap an InChI
    # implementation (IUPAC software, RDKit, WASM build) behind one
    # contract. Registering an engine is how a user opts in to local
    # identity derivation — the core gem stays dependency-free.
    class Engine
      # The single engine obligation: return the Identity of a
      # Model::Molecule.
      def identity(_molecule)
        raise NotImplementedError, "#{self.class} must implement #identity"
      end

      # Standard InChI string of the molecule (TODO.v2 10 interface).
      def to_inchi(molecule, standard: true)
        identity = identity(molecule)
        return identity.inchi if standard

        raise ArgumentError, "#{self.class} derives standard InChI only"
      end

      # InChIKey of the molecule.
      def to_inchikey(molecule)
        identity(molecule).inchikey
      end
    end
  end
end
