# frozen_string_literal: true

require "thor"

module AsciiChem
  # Thor-based command line interface.
  class Cli < Thor
    package_name "AsciiChem"

    desc "convert -i INPUT -t FORMAT", "Convert AsciiChem INPUT to FORMAT (mathml|text|html|latex)"
    method_option :input, aliases: "-i", type: :string, required: true,
                           desc: "AsciiChem source text"
    method_option :format, aliases: "-t", type: :string, default: "mathml",
                            desc: "Output format"
    def convert
      formula = AsciiChem.parse(options[:input])
      puts render(formula, options[:format])
    rescue AsciiChem::ParseError => e
      warn "Parse error: #{e.message}"
      exit 1
    rescue AsciiChem::FormatError => e
      warn "Format error: #{e.message}"
      exit 2
    end

    desc "roundtrip -i INPUT", "Parse and re-emit; exit non-zero if not equal"
    method_option :input, aliases: "-i", type: :string, required: true
    def roundtrip
      original = options[:input]
      rendered = AsciiChem.parse(original).to_text
      if rendered == original
        puts rendered
        exit 0
      else
        warn "round-trip mismatch:\n  input:    #{original.inspect}\n  rendered: #{rendered.inspect}"
        exit 1
      end
    end

    desc "version", "Print the AsciiChem gem version"
    def version
      puts AsciiChem::VERSION
    end

    private

    def render(formula, format)
      case format.to_sym
      when :mathml then formula.to_mathml
      when :text   then formula.to_text
      when :html   then formula.to_html
      when :latex  then formula.to_latex
      else
        raise AsciiChem::FormatError, "unknown format: #{format}"
      end
    end
  end
end
