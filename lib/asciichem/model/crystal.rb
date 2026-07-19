# frozen_string_literal: true

module AsciiChem
  module Model
    # A crystal structure: unit cell parameters + space group +
    # asymmetric-unit atoms with fractional coordinates.
    #
    # Syntax:
    #   crystal[NaCl](a=5.64,b=5.64,c=5.64,alpha=90,beta=90,gamma=90,sg=Fm-3m){
    #     Na@f(0,0,0)
    #     Cl@f(0.5,0.5,0.5)
    #   }
    class Crystal < Node
      # The six unit-cell parameters in canonical iteration order.
      # Single source of truth for "what fields count as cell params".
      CELL_PARAMS = %i[a b c alpha beta gamma].freeze
      # Lengths vs angles — both subsets of CELL_PARAMS. Naming the
      # split lets the linter iterate without re-deriving subsets.
      LENGTH_FIELDS = %i[a b c].freeze
      ANGLE_FIELDS = %i[alpha beta gamma].freeze

      # Per-format labels for cell parameters. Single source of truth
      # for "what's the label for :alpha in MathML" — every formatter
      # consults this hash instead of inlining its own.
      CELL_LABELS = {
        text:   { a: 'a', b: 'b', c: 'c',
                  alpha: 'alpha', beta: 'beta', gamma: 'gamma' },
        mathml: { a: 'a', b: 'b', c: 'c',
                  alpha: 'α', beta: 'β', gamma: 'γ' },
        html:   { a: 'a', b: 'b', c: 'c',
                  alpha: 'α', beta: 'β', gamma: 'γ' },
        latex:  { a: 'a', b: 'b', c: 'c',
                  alpha: '\\alpha', beta: '\\beta', gamma: '\\gamma' }
      }.freeze

      attr_accessor :name, :a, :b, :c, :alpha, :beta, :gamma,
                    :spacegroup, :atoms

      def initialize(name: nil, a: nil, b: nil, c: nil,
                     alpha: nil, beta: nil, gamma: nil,
                     spacegroup: nil, atoms: [])
        @name = name
        @a = a
        @b = b
        @c = c
        @alpha = alpha
        @beta = beta
        @gamma = gamma
        @spacegroup = spacegroup
        @atoms = atoms
      end

      # Yield `[label, value]` pairs for every set cell parameter,
      # in canonical order (a, b, c, alpha, beta, gamma), using the
      # label set for the given format. Formatters use this instead
      # of inlining their own label hashes.
      def each_cell_param(format)
        labels = CELL_LABELS.fetch(format)
        CELL_PARAMS.each do |attr|
          value = public_send(attr)
          yield labels[attr], value if value
        end
      end

      def value_attributes
        { name: name, a: a, b: b, c: c, alpha: alpha,
          beta: beta, gamma: gamma, spacegroup: spacegroup,
          atoms: atoms }
      end

      def children
        atoms
      end

      def diagnostic_label
        "Crystal(#{name || 'unnamed'})"
      end

      def to_s
        params = []
        each_cell_param(:text) { |label, value| params << "#{label}=#{value}" }
        params << "sg=#{spacegroup}" if spacegroup
        "crystal[#{name}](#{params.join(',')}){#{atoms.map(&:to_s).join(' ')}}"
      end
    end
  end
end
