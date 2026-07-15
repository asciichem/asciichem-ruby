# frozen_string_literal: true

module AsciiChem
  class Parser
    attr_reader :text

    def initialize(text)
      @text = text.to_s
    end

    def parse
      tree = AsciiChem::Grammar.new.parse(text)
      AsciiChem::Transform.new.apply(tree)
    rescue Parslet::ParseFailed => e
      raise AsciiChem::ParseError, format_error(e)
    end

    private

    def format_error(error)
      pos = error.message.match(/char (\d+)/)
      char = pos ? pos[1].to_i : 0
      snippet = text[[char - 10, 0].max, 20] || text
      pointer = " " * (char - [char - 10, 0].max) + "^"
      expected = extract_expected(error.message)
      "Parse error at char #{char}: expected #{expected}\n" \
        "  ...#{snippet}...\n" \
        "  #{pointer}"
    end

    def extract_expected(message)
      match = message.match(/Expected:? (.+?)(?:\s+at|\s*$)/)
      match ? match[1].strip : "valid AsciiChem syntax"
    end
  end
end
