# frozen_string_literal: true

require "thor"

module AsciiChem
  # Thor-based command line interface.
  class Cli < Thor
    package_name "AsciiChem"

    desc "convert -i INPUT -t FORMAT", "Convert AsciiChem INPUT to FORMAT (mathml|text|html|latex|svg|cml)"
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

    desc "parse-cml -i INPUT", "Parse CML XML and emit AsciiChem text"
    method_option :input, aliases: "-i", type: :string, required: true,
                           desc: "CML XML source"
    def parse_cml
      formula = AsciiChem::Cml.parse(options[:input])
      puts formula.to_text
    rescue AsciiChem::Error => e
      warn "CML parse error: #{e.message}"
      exit 1
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

    desc "lint -i INPUT", "Run chemistry checks; exit 1 on error, 0 if clean"
    method_option :input, aliases: "-i", type: :string, required: true,
                           desc: "AsciiChem source text"
    def lint
      formula = AsciiChem.parse(options[:input])
      diagnostics = AsciiChem::Linter.run(formula)
      diagnostics.each { |d| puts d }
      exit diagnostics.any? { |d| d.severity == :error } ? 1 : 0
    rescue AsciiChem::ParseError => e
      warn "Parse error: #{e.message}"
      exit 1
    end

    desc "version", "Print the AsciiChem gem version"
    def version
      puts AsciiChem::VERSION
    end

    private

    def render(formula, format)
      return formula.to_cml if format.to_sym == :cml

      AsciiChem::Formatter.render(format.to_sym, formula)
    end
  end
end
