# frozen_string_literal: true

module AsciiChem
  module Wire
    # Beyond-formulas wire classes: mechanism, spectrum, crystal,
    # zmatrix, calculation. Emission covers the full v1 schemas;
    # ingestion (from_wire) is currently implemented for the core
    # chemistry set only — see WireAdapter.
    class MechanismStep < Lutaml::Model::Serializable
      attribute :label, :string
      attribute :reaction, "AsciiChem::Wire::Reaction"
      json do
        map "label", to: :label
        map "reaction", to: :reaction
      end
    end

    class Mechanism < Base
      wire_type "mechanism"

      attribute :steps, MechanismStep, collection: true
      attribute :spectators, "AsciiChem::Wire::Molecule", collection: true
      json do
        map "steps", to: :steps
        map "spectators", to: :spectators
      end
    end

    class SpectrumPeak < Lutaml::Model::Serializable
      attribute :position, :string
      attribute :intensity, :string
      attribute :multiplicity, :string
      attribute :assignment, :string
      json do
        map "position", to: :position
        map "intensity", to: :intensity
        map "multiplicity", to: :multiplicity
        map "assignment", to: :assignment
      end
    end

    class Spectrum < Base
      wire_type "spectrum"

      attribute :technique, :string
      attribute :params, Lutaml::Model::Type::Hash
      attribute :peaks, SpectrumPeak, collection: true
      json do
        map "technique", to: :technique
        map "params", to: :params
        map "peaks", to: :peaks
      end
    end

    class Crystal < Base
      wire_type "crystal"

      attribute :name, :string
      attribute :a, :float
      attribute :b, :float
      attribute :c, :float
      attribute :alpha, :float
      attribute :beta, :float
      attribute :gamma, :float
      attribute :spacegroup, :string
      attribute :atoms, Atom, collection: true
      json do
        map "name", to: :name
        map "a", to: :a
        map "b", to: :b
        map "c", to: :c
        map "alpha", to: :alpha
        map "beta", to: :beta
        map "gamma", to: :gamma
        map "spacegroup", to: :spacegroup
        map "atoms", to: :atoms
      end
    end

    class ZRow < Lutaml::Model::Serializable
      attribute :atom, :string
      attribute :ref1, :string
      attribute :distance, :string
      attribute :ref2, :string
      attribute :angle, :string
      attribute :ref3, :string
      attribute :dihedral, :string
      json do
        map "atom", to: :atom
        map "ref1", to: :ref1
        map "distance", to: :distance
        map "ref2", to: :ref2
        map "angle", to: :angle
        map "ref3", to: :ref3
        map "dihedral", to: :dihedral
      end
    end

    class ZMatrix < Base
      wire_type "zmatrix"

      attribute :rows, ZRow, collection: true
      json do
        map "rows", to: :rows
      end
    end

    class CalculatedProperty < Lutaml::Model::Serializable
      attribute :title, :string
      attribute :value, :string
      attribute :units, :string
      attribute :dict_ref, :string
      attribute :convention, :string
      json do
        map "title", to: :title
        map "value", to: :value
        map "units", to: :units
        map "dictRef", to: :dict_ref
        map "convention", to: :convention
      end
    end

    class Calculation < Base
      wire_type "calculation"

      attribute :method, :string
      attribute :basis, :string
      attribute :properties, CalculatedProperty, collection: true
      json do
        map "method", to: :method
        map "basis", to: :basis
        map "properties", to: :properties
      end
    end
  end
end
