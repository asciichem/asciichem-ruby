# frozen_string_literal: true

require "thor"

module AsciiChem
  # Thor-based command line interface. Invoked via the `asciichem`
  # executable (exe/asciichem).
  class Cli < Thor
    # Use lowercase 'asciichem' as the program name in help output
    # and command banners, matching the executable name.
    package_name "asciichem"

    desc "convert -i INPUT -t FORMAT", "Convert INPUT to FORMAT (mathml|text|html|latex|svg|structural-svg|model-json|cml|smiles|molfile)"
    method_option :input, aliases: "-i", type: :string,
                           desc: "Source text (or '-' for stdin)"
    method_option :file, aliases: "-f", type: :string,
                          desc: "Read source from a file"
    method_option :from, type: :string, default: "asciichem",
                        desc: "Input grammar: asciichem|smiles|molfile"
    method_option :format, aliases: "-t", type: :string, default: "mathml",
                            desc: "Output format"
    def convert
      unless options["input"] || options["file"]
        raise AsciiChem::ParseError, "provide -i INPUT or -f FILE"
      end

      source = read_source
      formula = ingest(source, options[:from])
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
    method_option :format, aliases: "-f", type: :string, default: "text",
                            desc: "Output format: text or json"
    def lint
      formula = AsciiChem.parse(options[:input])
      diagnostics = AsciiChem::Linter.run(formula)
      output_lint(diagnostics, options[:format])
      exit diagnostics.any? { |d| d.severity == :error } ? 1 : 0
    rescue AsciiChem::ParseError => e
      warn "Parse error: #{e.message}"
      exit 1
    end

    map %w[--version -v] => :version
    desc "version", "Print the asciichem version"
    def version
      puts "asciichem #{AsciiChem::VERSION}"
    end

    # Override banner to use lowercase program name consistently.
    def self.banner(command, _namespace = nil, _subcommand = false)
      "asciichem #{command.usage}"
    end

    desc "resolve --cas X | --name X | ...", "Resolve a substance from a source (network; cached)"
    method_option :cas, type: :string, desc: "CAS registry number"
    method_option :name, type: :string, desc: "Substance name"
    method_option :cid, type: :string, desc: "PubChem CID"
    method_option :inchikey, type: :string, desc: "InChIKey"
    method_option :smiles, type: :string, desc: "SMILES"
    method_option :source, type: :string, default: "pubchem", desc: "Resolver source"
    method_option :refresh, type: :boolean, default: false, desc: "Bypass the cache"
    method_option :format, aliases: "-t", type: :string, default: "model-json",
                            desc: "Output: model-json | text | smiles"
    def resolve
      convention, value = %i[cas name cid inchikey smiles]
                          .filter_map { |k| [k, options[k.to_s]] if options[k.to_s] }
                          .first
      raise AsciiChem::Error, "give one of --cas/--name/--cid/--inchikey/--smiles" unless value

      convention = { cas: "cas", name: "name", cid: "pubchem-cid",
                     inchikey: "inchikey", smiles: "smiles" }.fetch(convention)
      substance = AsciiChem::Resolver[options[:source]].new.resolve(
        value: value, convention: convention, refresh: options[:refresh]
      )
      raise AsciiChem::Error, "#{options[:source]} does not know #{value.inspect}" unless substance

      puts case options[:format].to_s
           when "text" then substance.preferred_name.to_s
           when "smiles" then substance.identifier_value("canonical-smiles").to_s
           else substance.to_model_json
           end
    rescue AsciiChem::Error => e
      warn "Resolve error: #{e.message}"
      exit 3
    end

    desc "cite --cas X | --name X | ...", "Resolve a substance and emit a dataset-type Relaton bibitem (XML)"
    method_option :cas, type: :string, desc: "CAS registry number"
    method_option :name, type: :string, desc: "Substance name"
    method_option :cid, type: :string, desc: "PubChem CID"
    method_option :inchikey, type: :string, desc: "InChIKey"
    method_option :smiles, type: :string, desc: "SMILES"
    method_option :source, type: :string, default: "pubchem", desc: "Resolver source"
    method_option :refresh, type: :boolean, default: false, desc: "Bypass the cache"
    def cite
      convention, value = %i[cas name cid inchikey smiles]
                          .filter_map { |k| [k, options[k.to_s]] if options[k.to_s] }
                          .first
      raise AsciiChem::Error, "give one of --cas/--name/--cid/--inchikey/--smiles" unless value

      convention = { cas: "cas", name: "name", cid: "pubchem-cid",
                     inchikey: "inchikey", smiles: "smiles" }.fetch(convention)
      substance = AsciiChem::Resolver[options[:source]].new.resolve(
        value: value, convention: convention, refresh: options[:refresh]
      )
      raise AsciiChem::Error, "#{options[:source]} does not know #{value.inspect}" unless substance

      puts AsciiChem::Citation.to_xml(substance)
    rescue AsciiChem::Error => e
      warn "Cite error: #{e.message}"
      exit 4
    end

    desc "validate -i INPUT", "Offline identifier validation"
    method_option :input, aliases: "-i", type: :string, required: true
    def validate
      formula = AsciiChem.parse(options[:input])
      annotations = formula.nodes.grep(AsciiChem::Model::Molecule).flat_map(&:identifiers)
      if annotations.empty?
        puts "no identifier annotations found"
        return
      end
      annotations.each do |identifier|
        known = AsciiChem::Identifiers.known?(identifier.convention)
        valid = known && AsciiChem::Identifiers.valid?(identifier.convention, identifier.value)
        status = known ? (valid ? "ok" : "INVALID") : "unknown convention"
        puts format("%-12s %-40s %s", identifier.convention, identifier.value, status)
      end
      exit 1 if annotations.any? { |i| AsciiChem::Identifiers.known?(i.convention) &&
                                      !AsciiChem::Identifiers.valid?(i.convention, i.value) }
    rescue AsciiChem::ParseError => e
      warn "Parse error: #{e.message}"
      exit 1
    end

    private

    def read_source
      return File.read(options[:file]) if options[:file]
      return $stdin.read if options[:input] == "-"

      options[:input]
    end

    # One ingestion point per input grammar (TODO.v2 09): every
    # grammar funnels into the same semantic model, so every output
    # format works regardless of the input language.
    def ingest(source, from)
      case from.to_s
      when "asciichem" then AsciiChem.parse(source)
      when "smiles" then AsciiChem.parse_smiles(source)
      when "molfile" then molfile_formula(source)
      else
        raise AsciiChem::ParseError, "unknown --from grammar: #{from}"
      end
    end

    # parse_molfile returns a single Molecule; wrap it so every
    # formatter's Formula contract holds.
    def molfile_formula(source)
      text = File.file?(source) ? File.read(source) : source
      AsciiChem::Model::Formula.new(nodes: [AsciiChem.parse_molfile(text)])
    end

    def render(formula, format)
      return formula.to_cml if format.to_sym == :cml
      return formula.to_model_json if format.to_sym == :"model-json"
      return formula.to_smiles if format.to_sym == :smiles
      return formula.nodes.first.to_molfile if format.to_sym == :molfile

      AsciiChem::Formatter.render(format.to_sym, formula)
    end

    def output_lint(diagnostics, format)
      case format.to_s
      when "json" then output_lint_json(diagnostics)
      else
        diagnostics.each { |d| puts d }
      end
    end

    def output_lint_json(diagnostics)
      require "json"
      payload = diagnostics.map do |d|
        {
          severity: d.severity.to_s,
          message: d.message,
          node: d.node&.diagnostic_label
        }
      end
      puts JSON.pretty_generate(payload)
    end
  end
end
