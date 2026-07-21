# frozen_string_literal: true

module AsciiChem
  class Parser
    attr_reader :text

    # Grammar and Transform instances are stateless and expensive to
    # construct. Cache them at the class level so repeated parses
    # avoid the overhead (benchmark: ~15% throughput improvement).
    GRAMMAR_INSTANCE = Grammar.new
    TRANSFORM_INSTANCE = Transform.new
    private_constant :GRAMMAR_INSTANCE, :TRANSFORM_INSTANCE

    def initialize(text)
      @text = text.to_s
    end

    def parse
      tree = GRAMMAR_INSTANCE.parse(text)
      TRANSFORM_INSTANCE.apply(tree)
    rescue Parslet::ParseFailed => e
      raise AsciiChem::ParseError, format_error(e)
    end

    private

    def format_error(error)
      pos = error.message.match(/char (\d+)/)
      char = pos ? pos[1].to_i : 0
      line_no, col_no, line_text = locate(text, char)
      snippet = line_text || text[[char - 10, 0].max, 20] || text
      pointer_offset = char - (line_text ? char_for_line(text, line_no) : [char - 10, 0].max)
      pointer = " " * pointer_offset + "^"
      expected = extract_expected(error.message)
      location = line_no ? "line #{line_no}, col #{col_no}" : "char #{char}"
      "Parse error at #{location}: expected #{expected}\n" \
        "  ...#{snippet}...\n" \
        "  #{pointer}"
    end

    # Find the line number (1-indexed) and column (1-indexed) for a
    # given character offset in the source. Returns [nil, nil, nil]
    # when the source has no newlines (single-line case).
    def locate(text, char)
      return [nil, nil, nil] unless text.include?("\n")

      line_no = 1
      col_no = 1
      char_count = 0
      current_line_start = 0
      text.each_char.with_index do |c, i|
        if i == char
          return [line_no, col_no, text[current_line_start..(text.index("\n", current_line_start) || text.length) - 1]]
        end

        col_no += 1
        if c == "\n"
          line_no += 1
          col_no = 1
          current_line_start = i + 1
        end
      end
      [line_no, col_no, text[current_line_start..]]
    end

    # Offset of the first char on `line_no` (for caret positioning).
    def char_for_line(text, line_no)
      return 0 if line_no <= 1

      offset = 0
      current_line = 1
      text.each_char.with_index do |c, i|
        return offset if current_line == line_no

        if c == "\n"
          current_line += 1
          offset = i + 1
        end
      end
      offset
    end

    def extract_expected(message)
      match = message.match(/Expected:? (.+?)(?:\s+at|\s*$)/)
      match ? match[1].strip : "valid AsciiChem syntax"
    end
  end
end
