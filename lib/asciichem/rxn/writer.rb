# frozen_string_literal: true

module AsciiChem
  module Rxn
    # Model reaction → MDL RXN V2000. Layout: `$RXN`, name, program,
    # comment, counts (`%3d%3d` = reactant count, product count), then
    # `$MOL` + one V2000 molfile per species (reactants first, then
    # products).
    class Writer
      def initialize(reaction, name: nil)
        @reaction = reaction
        @name = name
      end

      def write
        reactants = @reaction.reactants
        products = @reaction.products
        lines = ['$RXN', @name.to_s, '  AsciiChem', '',
                 format('%<reactants>3d%<products>3d',
                        reactants: reactants.length, products: products.length)]
        (reactants + products).each do |molecule|
          lines << '$MOL'
          lines << AsciiChem::Molfile.write(molecule).chomp
        end
        lines.join("\n") << "\n"
      end
    end
  end
end
