# frozen_string_literal: true

module AsciiChem
  module Wire
    # Chemistry document wire classes: formula (root), reactions,
    # electron configurations, embedded math, text.
    class Formula < Base
      wire_type "formula"

      attribute :nodes, Base, collection: true
      json do
        map "nodes", to: :nodes
      end
    end

    class ReactionConditions < Lutaml::Model::Serializable
      attribute :above, :string
      attribute :below, :string
      json do
        map "above", to: :above
        map "below", to: :below
      end
    end

    class Reaction < Base
      wire_type "reaction"

      attribute :reactants, "AsciiChem::Wire::Molecule", collection: true
      attribute :products, "AsciiChem::Wire::Molecule", collection: true
      attribute :arrow, :string
      attribute :conditions, ReactionConditions
      json do
        map "reactants", to: :reactants
        map "products", to: :products
        map "arrow", to: :arrow
        map "conditions", to: :conditions
      end
    end

    class ReactionCascade < Base
      wire_type "reaction-cascade"

      attribute :steps, "AsciiChem::Wire::Reaction", collection: true
      json do
        map "steps", to: :steps
      end
    end

    class OrbitalOccupancy < Lutaml::Model::Serializable
      attribute :orbital, :string
      attribute :occupancy, :string
      json do
        map "orbital", to: :orbital
        map "occupancy", to: :occupancy
      end
    end

    class TermSymbol < Lutaml::Model::Serializable
      attribute :multiplicity, :string
      attribute :letter, :string
      attribute :j_value, :string
      json do
        map "multiplicity", to: :multiplicity
        map "letter", to: :letter
        map "jValue", to: :j_value
      end
    end

    class ElectronConfiguration < Base
      wire_type "electron-configuration"

      attribute :orbitals, OrbitalOccupancy, collection: true
      attribute :term_symbol, TermSymbol
      json do
        map "orbitals", to: :orbitals
        map "termSymbol", to: :term_symbol
      end
    end

    class EmbeddedMath < Base
      wire_type "embedded-math"

      attribute :source, :string
      json do
        map "source", to: :source
      end
    end

    class Text < Base
      wire_type "text"

      attribute :content, :string
      json do
        map "content", to: :content
      end
    end
  end
end
