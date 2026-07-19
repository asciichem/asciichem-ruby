# frozen_string_literal: true

module AsciiChem
  module Model
    # A molecule: an ordered sequence of atoms/groups with optional
    # leading stoichiometric coefficient, optional stereochemistry
    # marker (R/S/E/Z/α/β), and optional names/identifiers for CML
    # metadata round-trip.
    class Molecule < Node
      # A computed or measured property on a molecule (e.g. mw, bp).
      Property = Struct.new(:title, :value, :units, :dict_ref,
                            :convention, keyword_init: true)
      # A key-value metadata pair (provenance, instrument, etc.).
      Meta = Struct.new(:name, :content, keyword_init: true)
      # A display label attached to the molecule.
      Label = Struct.new(:value, :dict_ref, :convention, keyword_init: true)
      # A CML concise formula on the molecule.
      Formula = Struct.new(:concise, :inline, :formal_charge, :count,
                           :title, :convention, :dict_ref, keyword_init: true)

      STEREO_LETTERS = {
        "R" => :R,
        "S" => :S,
        "E" => :E,
        "Z" => :Z,
        "a" => :alpha,
        "alpha" => :alpha,
        "α" => :alpha,
        "b" => :beta,
        "beta" => :beta,
        "β" => :beta
      }.freeze

      STEREO_TO_LETTER = {
        R: "R", S: "S", E: "E", Z: "Z",
        alpha: "alpha", beta: "beta"
      }.freeze

      attr_accessor :coefficient, :nodes, :stereo, :names, :identifiers,
                    :title, :formulas, :properties, :labels, :metadata

      def initialize(nodes:, coefficient: nil, stereo: nil,
                     names: [], identifiers: [], title: nil,
                     formulas: [], properties: [], labels: [], metadata: [])
        @nodes = nodes
        @coefficient = coefficient
        @stereo = stereo
        @names = names
        @identifiers = identifiers
        @title = title
        @formulas = formulas
        @properties = properties
        @labels = labels
        @metadata = metadata
      end

      def value_attributes
        { nodes: nodes, coefficient: coefficient, stereo: stereo,
          names: names, identifiers: identifiers, title: title,
          formulas: formulas, properties: properties, labels: labels,
          metadata: metadata }
      end

      def children
        nodes
      end

      # Total atom count, recursing through groups and nested molecules
      # with subscripts and multiplicities applied. `H_2O` returns 3;
      # `(OH)_2` returns 4; `2H_2O` returns 6 (coefficient multiplies).
      #
      # Single source of truth for "how many atoms in this molecule".
      # Used by linter checks (charge balance) and any caller that
      # needs an atom count without reimplementing the recursion.
      def atom_count
        nodes.sum { |node| atom_count_of(node) }
      end

      def stereo_letter
        STEREO_TO_LETTER.fetch(stereo) if stereo
      end

      private

      def atom_count_of(node)
        case node
        when AsciiChem::Model::Atom
          subscript_count(node)
        when AsciiChem::Model::Group
          group_count(node)
        when AsciiChem::Model::Molecule
          nested_molecule_count(node)
        else
          0
        end
      end

      def subscript_count(atom)
        sub = atom.subscript&.to_i
        sub && sub.positive? ? sub : 1
      end

      def group_count(group)
        inner = group.nodes.sum { |n| atom_count_of(n) }
        mult = group.multiplicity&.to_i
        mult && mult.positive? ? inner * mult : inner
      end

      def nested_molecule_count(mol)
        coefficient = mol.coefficient&.to_i
        coeff = coefficient && coefficient.positive? ? coefficient : 1
        mol.atom_count * coeff
      end

      def to_s
        prefix = coefficient ? "#{coefficient}" : ""
        stereo_str = stereo ? "(#{stereo_letter})-" : ""
        name_str = names.empty? ? "" : " #{names.map(&:to_s).join(', ')}"
        id_str = identifiers.empty? ? "" : " #{identifiers.map(&:to_s).join(', ')}"
        "#{stereo_str}#{prefix}Molecule[#{nodes.map(&:to_s).join(', ')}]#{name_str}#{id_str}"
      end
    end
  end
end
