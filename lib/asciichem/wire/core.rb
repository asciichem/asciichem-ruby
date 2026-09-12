# frozen_string_literal: true

module AsciiChem
  module Wire
    # Core node wire classes: atom, identifier, name, molecule,
    # group, bond. Field-for-field with schemas/v1. Order matters:
    # referenced classes are declared before their referrers.
    class Atom < Base
      wire_type "atom"

      attribute :element, :string
      attribute :isotope, :string
      attribute :charge, :string
      attribute :subscript, :string
      attribute :oxidation_state, :string
      attribute :lone_pairs, :integer
      attribute :radical_electrons, :integer
      attribute :ring_closures, :string
      attribute :aromatic, :boolean
      attribute :hydrogens, :integer
      json do
        map "element", to: :element
        map "isotope", to: :isotope
        map "charge", to: :charge
        map "subscript", to: :subscript
        map "oxidationState", to: :oxidation_state
        map "lonePairs", to: :lone_pairs
        map "radicalElectrons", to: :radical_electrons
        map "ringClosures", to: :ring_closures
        map "aromatic", to: :aromatic
        map "hydrogens", to: :hydrogens
      end
    end

    class Identifier < Base
      wire_type "identifier"

      attribute :value, :string
      attribute :convention, :string
      attribute :dict_ref, :string
      json do
        map "value", to: :value
        map "convention", to: :convention
        map "dictRef", to: :dict_ref
      end
    end

    class Name < Base
      wire_type "name"

      attribute :content, :string
      attribute :convention, :string
      attribute :dict_ref, :string
      json do
        map "content", to: :content
        map "convention", to: :convention
        map "dictRef", to: :dict_ref
      end
    end

    class Molecule < Base
      wire_type "molecule"

      attribute :nodes, Base, collection: true
      attribute :coefficient, :string
      attribute :identifiers, Identifier, collection: true
      json do
        map "nodes", to: :nodes
        map "coefficient", to: :coefficient
        map "identifiers", to: :identifiers
      end
    end

    class Group < Base
      wire_type "group"

      attribute :nodes, Base, collection: true
      attribute :multiplicity, :string
      attribute :bracket, :string
      json do
        map "nodes", to: :nodes
        map "multiplicity", to: :multiplicity
        map "bracket", to: :bracket
      end
    end

    class Bond < Base
      wire_type "bond"

      attribute :kind, :string
      json do
        map "kind", to: :kind
      end
    end
  end
end
