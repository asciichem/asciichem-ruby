# frozen_string_literal: true

module AsciiChem
  # Semantic model. Every parse produces a tree of Model instances, and
  # every formatter consumes the same tree. Formatters visit via
  # double-dispatch (`node.accept(formatter)` -> `formatter.visit_<class>`),
  # keeping both sides open for extension.
  module Model
    autoload :Atom, "asciichem/model/atom"
    autoload :Bond, "asciichem/model/bond"
    autoload :ElectronConfiguration, "asciichem/model/electron_configuration"
    autoload :EmbeddedMath, "asciichem/model/embedded_math"
    autoload :Formula, "asciichem/model/formula"
    autoload :Group, "asciichem/model/group"
    autoload :Identifier, "asciichem/model/identifier"
    autoload :Molecule, "asciichem/model/molecule"
    autoload :Name, "asciichem/model/name"
    autoload :Node, "asciichem/model/node"
    autoload :Reaction, "asciichem/model/reaction"
    autoload :ReactionCascade, "asciichem/model/reaction_cascade"
    autoload :Text, "asciichem/model/text"
  end
end
