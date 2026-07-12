# frozen_string_literal: true

module AsciiChem
  # Public parser entry point. Wires Grammar + Transform and normalises
  # the result into a single Model::Formula.
  class Parser
    attr_reader :text

    def initialize(text)
      @text = text.to_s
    end

    def parse
      tree = AsciiChem::Grammar.new.parse(text)
      AsciiChem::Transform.new.apply(tree)
    rescue Parslet::ParseFailed => e
      raise AsciiChem::ParseError, e.message
    end
  end
end
