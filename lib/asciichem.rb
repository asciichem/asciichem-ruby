# frozen_string_literal: true

require "parslet"
require "plurimath"

# AsciiChem is an ASCII syntax for representing chemistry.
#
# Top-level entry points:
#   AsciiChem.parse(text)   # => AsciiChem::Model::Formula
#   AsciiChem::Cli.start    # CLI dispatch
module AsciiChem
  autoload :Cli, "asciichem/cli"
  autoload :Cml, "asciichem/cml"
  autoload :Error, "asciichem/errors"
  autoload :ParseError, "asciichem/errors"
  autoload :FormatError, "asciichem/errors"
  autoload :Formatter, "asciichem/formatter"
  autoload :Grammar, "asciichem/grammar"
  autoload :Greek, "asciichem/greek"
  autoload :Identifiers, "asciichem/identifiers"
  autoload :Layout, "asciichem/layout"
  autoload :Linter, "asciichem/linter"
  autoload :Model, "asciichem/model"
  autoload :ModelAdapter, "asciichem/model_adapter"
  autoload :Molfile, "asciichem/molfile"
  autoload :Parser, "asciichem/parser"
  autoload :PeriodicTable, "asciichem/periodic_table"
  autoload :RingBonds, "asciichem/ring_bonds"
  autoload :Smiles, "asciichem/smiles"
  autoload :Structure, "asciichem/structure"
  autoload :Transform, "asciichem/transform"
  autoload :VERSION, "asciichem/version"
  autoload :Wire, "asciichem/wire"
  autoload :WireAdapter, "asciichem/wire_adapter"
  autoload :XmlBuilder, "asciichem/xml_builder"

  def self.parse(text)
    Parser.new(text).parse
  end

  # Rebuilds the semantic model from the canonical JSON wire form
  # (asciichem-model v1) — the interchange format every
  # implementation emits.
  def self.from_model_json(json)
    WireAdapter.from_model_json(json)
  end

  # Ingests a SMILES string into the semantic model (TODO.v2 09):
  # one Model::Molecule per dot-disconnected component, explicit
  # bonds and ring closures, renderable by every formatter.
  def self.parse_smiles(smiles)
    Smiles.parse(smiles)
  end

  # Ingests a molfile (CTfile V2000) into a Model::Molecule,
  # preserving atom coordinates.
  def self.parse_molfile(text)
    Molfile.parse(text)
  end
end
