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

      # Hill-system canonical formula: C first, then H, then others
      # alphabetically. Single source of truth for "what is the
      # canonical formula string of this molecule".
      #
      # Examples:
      #   H_2O  -> "H2O"
      #   CH_4  -> "CH4"
      #   C_2H_6O -> "C2H6O"
      #   H_2SO_4 -> "H2O4S" (no carbon, alpha sort)
      def hill_formula
        counts = count_atoms_by_element
        return '' if counts.empty?

        parts = hill_sort(counts).map do |element, count|
          count == 1 ? element : "#{element}#{count}"
        end
        parts.join
      end

      def stereo_letter
        STEREO_TO_LETTER.fetch(stereo) if stereo
      end

      private

      # Hash of element symbol -> total count, recursing through
      # groups and nested molecules with subscripts and multiplicities.
      def count_atoms_by_element
        tally = Hash.new(0)
        own_coefficient = coefficient&.to_i
        multiplier = own_coefficient && own_coefficient.positive? ? own_coefficient : 1
        nodes.each { |node| tally_element(node, tally, multiplier) }
        tally
      end

      def tally_element(node, tally, multiplier)
        case node
        when AsciiChem::Model::Atom
          sub = node.subscript&.to_i
          count = (sub && sub.positive? ? sub : 1) * multiplier
          tally[node.element] += count
        when AsciiChem::Model::Group
          group_mult = node.multiplicity&.to_i
          inner_mult = group_mult && group_mult.positive? ? group_mult : 1
          node.nodes.each { |n| tally_element(n, tally, multiplier * inner_mult) }
        when AsciiChem::Model::Molecule
          coeff = node.coefficient&.to_i
          inner_mult = coeff && coeff.positive? ? coeff : 1
          node.nodes.each { |n| tally_element(n, tally, multiplier * inner_mult) }
        end
      end

      def hill_sort(counts)
        present = counts.reject { |_, count| count.zero? }
        carbon = present.key?('C') ? [['C', present['C']]] : []
        hydrogen = present.key?('H') ? [['H', present['H']]] : []
        others = present.reject { |el, _| %w[C H].include?(el) }.sort
        carbon + hydrogen + others
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
