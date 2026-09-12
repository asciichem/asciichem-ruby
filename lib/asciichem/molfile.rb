# frozen_string_literal: true

module AsciiChem
  # Molfile (CTfile V2000) ingestion and emission (TODO.v2 09;
  # TODO.impl 57). Molfile is the highest-fidelity structure path:
  # atom coordinates are preserved on the model (x2/y2/z2), charges
  # via the CHG property block, isotopes via mass difference or the
  # ISO block, bond stereo codes 1/6 map to wedge/hash bonds.
  module Molfile
    autoload :Parser, "asciichem/molfile/parser"
    autoload :Writer, "asciichem/molfile/writer"

    class << self
      # Parses a V2000 molfile into a Model::Molecule.
      def parse(text)
        Parser.new(text).parse
      end

      # Emits a V2000 molfile. Uses authored x2/y2 coordinates;
      # computes a 2D layout otherwise.
      def write(molecule, name: nil)
        Writer.new(molecule, name: name).write
      end
    end
  end
end
