# frozen_string_literal: true

module AsciiChem
  # MDL RXN (reaction file) emission (TODO.v2/13 item 4, RInChI): a
  # reaction as one $RXN container holding each reactant and product
  # as a V2000 mol block. RXN carries species, not stoichiometry —
  # the coefficient is model data with no place in the file, so it is
  # not invented there.
  module Rxn
    autoload :Writer, 'asciichem/rxn/writer'

    class << self
      def write(reaction, name: nil)
        Writer.new(reaction, name: name).write
      end
    end
  end
end
