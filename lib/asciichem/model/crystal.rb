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
        params << "a=#{a}" if a
        params << "b=#{b}" if b
        params << "c=#{c}" if c
        params << "alpha=#{alpha}" if alpha
        params << "beta=#{beta}" if beta
        params << "gamma=#{gamma}" if gamma
        params << "sg=#{spacegroup}" if spacegroup
        "crystal[#{name}](#{params.join(',')}){#{atoms.map(&:to_s).join(' ')}}"
      end
    end
  end
end
