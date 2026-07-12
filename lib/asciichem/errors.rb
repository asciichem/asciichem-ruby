# frozen_string_literal: true

module AsciiChem
  class Error < StandardError; end

  class ParseError < Error; end

  class FormatError < Error; end
end
