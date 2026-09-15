# frozen_string_literal: true

require 'parslet'

module AsciiChem
  # Converts a parse tree (from AsciiChem::Grammar) into a tree of
  # AsciiChem::Model instances.
  #
  # The transform contains minimal logic — it maps hash shapes to
  # constructor calls. Anything semantically tricky (e.g. distinguishing
  # isotope prefix from suffix charge) is encoded in the grammar, not
  # here.
  class Transform < Parslet::Transform
    include TransformRules
  end
end
