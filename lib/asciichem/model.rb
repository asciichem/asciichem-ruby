# frozen_string_literal: true

module AsciiChem
  # Semantic model. Every parse produces a tree of Model instances, and
  # every formatter consumes the same tree. Formatters visit via
  # double-dispatch (`node.accept(formatter)` -> `formatter.visit_<class>`),
  # keeping both sides open for extension.
  module Model
    autoload :Atom, "asciichem/model/atom"
    autoload :Bond, "asciichem/model/bond"
    autoload :Calculation, "asciichem/model/calculation"
    autoload :Crystal, "asciichem/model/crystal"
    autoload :ElectronConfiguration, "asciichem/model/electron_configuration"
    autoload :EmbeddedMath, "asciichem/model/embedded_math"
    autoload :Formula, "asciichem/model/formula"
    autoload :Group, "asciichem/model/group"
    autoload :Identifier, "asciichem/model/identifier"
    autoload :Mechanism, "asciichem/model/mechanism"
    autoload :Molecule, "asciichem/model/molecule"
    autoload :Name, "asciichem/model/name"
    autoload :Node, "asciichem/model/node"
    autoload :Reaction, "asciichem/model/reaction"
    autoload :ReactionCascade, "asciichem/model/reaction_cascade"
    autoload :Spectrum, "asciichem/model/spectrum"
    autoload :Text, "asciichem/model/text"
    autoload :ZMatrix, "asciichem/model/zmatrix"
  end
end
