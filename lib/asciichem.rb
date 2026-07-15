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
  autoload :Layout, "asciichem/layout"
  autoload :Linter, "asciichem/linter"
  autoload :Model, "asciichem/model"
  autoload :ModelAdapter, "asciichem/model_adapter"
  autoload :Parser, "asciichem/parser"
  autoload :PeriodicTable, "asciichem/periodic_table"
  autoload :RingBonds, "asciichem/ring_bonds"
  autoload :Transform, "asciichem/transform"
  autoload :VERSION, "asciichem/version"
  autoload :XmlBuilder, "asciichem/xml_builder"

  def self.parse(text)
    Parser.new(text).parse
  end
end
