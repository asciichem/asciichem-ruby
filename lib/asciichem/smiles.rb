# frozen_string_literal: true

require "parslet"

module AsciiChem
  # SMILES ingestion and emission for the semantic model
  # (TODO.v2 09; TODO.impl 57). SMILES is an input syntax for the one
  # semantic model — parsed molecules are ordinary `Model::Molecule`s
  # with explicit bonds and ring closures, renderable by every
  # formatter.
  #
  # v1 subset (each deferral has a rejecting spec with an actionable
  # message): chirality `@`/`@@` and E/Z bond directions `/` `\` are
  # not parsed; reaction atom maps, queries, and S-groups are out of
  # scope.
  module Smiles
    autoload :Parser, "asciichem/smiles/parser"
    autoload :Writer, "asciichem/smiles/writer"

    class << self
      # Parses a SMILES string into a Model::Formula with one
      # Molecule per dot-disconnected component.
      def parse(smiles)
        Parser.new(smiles).parse
      end

      # Emits deterministic SMILES (DFS from the first atom,
      # neighbours in creation order, ring digits assigned in
      # encounter order). Not a canonical-rank algorithm; the
      # stability property `write(parse(write(x))) == write(x)`
      # holds and is spec'd.
      def write(node)
        case node
        when AsciiChem::Model::Formula
          node.nodes.map { |m| Writer.new(m).write }.join(".")
        when AsciiChem::Model::Molecule
          Writer.new(node).write
        else
          raise AsciiChem::ParseError,
                "#{node.class} has no SMILES form (molecules and formulas of molecules only)"
        end
      end
    end
  end
end
