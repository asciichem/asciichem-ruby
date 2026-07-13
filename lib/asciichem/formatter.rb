# frozen_string_literal: true

module AsciiChem
  # Format registry. Each output (MathML, Text, HTML, LaTeX, SVG) is a
  # class under this module. The model's `to_<name>` shortcuts route
  # through `Formatter[<name>].new.render(node)`.
  #
  # To add a new formatter:
  #   1. Create `lib/asciichem/formatter/<name>.rb` with a class
  #      `AsciiChem::Formatter::<ClassCamel> < Base`.
  #   2. Add `autoload :<ClassCamel>, "asciichem/formatter/<name>"` to
  #      this file.
  #   3. Add `def to_<name>` to `Model::Node` if a shortcut is desired.
  #
  # No edits to existing formatters — OCP.
  module Formatter
    autoload :Base, "asciichem/formatter/base"
    autoload :Html, "asciichem/formatter/html"
    autoload :Latex, "asciichem/formatter/latex"
    autoload :Mathml, "asciichem/formatter/mathml"
    autoload :StructuralSvg, "asciichem/formatter/structural_svg"
    autoload :Svg, "asciichem/formatter/svg"
    autoload :Text, "asciichem/formatter/text"

    # Lookup by format name. Triggers autoload; raises FormatError if
    # the name is not registered.
    def self.[](name)
      const_get(name.to_s.capitalize)
    rescue NameError => e
      raise AsciiChem::FormatError, "unknown formatter #{name.inspect}: #{e.message}"
    end

    def self.render(name, node)
      self[name].new.render(node)
    end
  end
end
