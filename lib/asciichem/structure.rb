# frozen_string_literal: true

module AsciiChem
  # Shared structure plumbing for the interchange formats (SMILES,
  # molfile). Two MECE concerns:
  #
  # - `Structure::Graph.build(molecule)` — model molecule → neutral
  #   atom list + bond list (adjacency), using the same pending-bond
  #   walk semantics as the Layout walker plus `RingBonds` closure
  #   edges.
  # - `Structure::Linearizer` — adjacency → linear model nodes (atoms
  #   in creation order, `Bond` tokens for consecutive edges, ring
  #   closure digits for non-consecutive edges). This is what lets an
  #   arbitrary graph from a database live inside the existing model
  #   and render through every existing formatter.
  module Structure
    autoload :Graph, "asciichem/structure/graph"
    autoload :Linearizer, "asciichem/structure/linearizer"
  end
end
