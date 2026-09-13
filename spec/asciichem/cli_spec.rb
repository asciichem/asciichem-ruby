# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "asciichem/cli"

RSpec.describe AsciiChem::Cli do
  # Runs the CLI in-process. CLI commands call Kernel#exit even on
  # success (lint exits 0 when clean); an uncaught SystemExit aborts
  # the whole RSpec run mid-suite (RSpec's at_exit then reports only
  # the examples executed so far — the TODO.impl/52 truncation bug).
  # Swallow it here; specs that assert on exit status call
  # described_class.start directly with raise_error(SystemExit).
  def run(*argv)
    original = $stdout
    $stdout = StringIO.new
    described_class.start(argv)
    $stdout.string
  rescue SystemExit
    $stdout.string
  ensure
    $stdout = original
  end

  describe "convert" do
    it "emits MathML by default" do
      out = run("convert", "-i", "H_2O")
      expect(out).to include("<math")
      expect(out).to include('mathvariant="normal">H<')
    end

    it "honours -t text" do
      out = run("convert", "-i", "H_2O", "-t", "text")
      expect(out.strip).to eq("H_2O")
    end

    it "honours -t html" do
      out = run("convert", "-i", "H_2O", "-t", "html")
      expect(out.strip).to include("H<sub>2</sub>O")
    end

    it "honours -t latex" do
      out = run("convert", "-i", "H_2O", "-t", "latex")
      expect(out.strip).to eq("\\ce{H2O}")
    end

    it "honours -t svg" do
      out = run("convert", "-i", "H_2O", "-t", "svg")
      expect(out).to include("<svg")
    end

    it "exits 1 on parse error" do
      expect { described_class.start(["convert", "-i", "   "]) }
        .to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
    end

    it "exits 2 on unknown format" do
      expect { described_class.start(["convert", "-i", "H", "-t", "wav"]) }
        .to raise_error(SystemExit) do |e|
          expect(e.status).to eq(2)
        end
    end
  end

  describe "roundtrip" do
    it "exits 0 when the input round-trips exactly" do
      expect { described_class.start(["roundtrip", "-i", "H_2O"]) }
        .to raise_error(SystemExit) do |e|
          expect(e.status).to eq(0)
        end
    end
  end

  describe "version" do
    it "prints the version" do
      out = run("version")
      expect(out.strip).to eq("asciichem #{AsciiChem::VERSION}")
    end
  end

  describe "beyond-formulas constructs through CLI" do
    it "converts a Crystal to MathML" do
      out = run("convert", "-i", "crystal[NaCl](a=5.64,sg=Fm-3m){Na@f(0,0,0)}", "-t", "mathml")
      expect(out).to include("<math")
      expect(out).to include("crystal")
    end

    it "converts a Spectrum to HTML" do
      out = run("convert", "-i", %(spectrum[nmr](type=1H){1.2: 3H s "CH3"}), "-t", "html")
      expect(out).to include("asciichem-spectrum")
    end

    it "converts a Calculation to LaTeX" do
      out = run("convert", "-i", "calc(b3lyp){energy: -234.5}", "-t", "latex")
      expect(out).to include("\\text{calc}")
    end

    it "converts a ZMatrix to text" do
      out = run("convert", "-i", "zmatrix{\n  C1\n  H2 C1 1.09\n}", "-t", "text")
      expect(out).to include("zmatrix")
    end

    it "converts a Mechanism to text" do
      out = run("convert", "-i", "mechanism{\n  step1: A -> B\n}", "-t", "text")
      expect(out).to include("mechanism")
    end

    it "lints CrystalSanityCheck errors via CLI" do
      expect { described_class.start(["lint", "-i", "crystal[x](a=-1){Na@f(0,0,0)}"]) }
        .to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
    end

    it "lints ZMatrixReferenceCheck errors via CLI" do
      expect { described_class.start(["lint", "-i", "zmatrix{\n  H1 C2 1.0\n  C2\n}"]) }
        .to raise_error(SystemExit) do |e|
          expect(e.status).to eq(1)
        end
    end

    it "round-trips a Crystal through CML via the CLI" do
      out = run("convert", "-i", "crystal[NaCl](a=5.64,sg=Fm-3m){Na@f(0,0,0)}", "-t", "cml")
      expect(out).to include("<cml")
      # chemicalml 0.3.0+: Crystal uses native <crystal> wire inside
      # a <molecule>, not the aci: text carrier.
      expect(out).to include("<crystal")
      expect(out).to include("spaceGroup=\"Fm-3m\"")
    end
  end

  describe "lint -f json" do
    it "emits diagnostics as a JSON array" do
      out = run("lint", "-i", "crystal[x](a=-1){Na@f(0,0,0)}", "-f", "json")
      require "json"
      payload = JSON.parse(out)
      expect(payload).to be_an(Array)
      expect(payload.first["severity"]).to eq("error")
      expect(payload.first["message"]).to match(/Crystal a must be positive/)
    end

    it "emits an empty array when no diagnostics" do
      out = run("lint", "-i", "H_2O", "-f", "json")
      require "json"
      payload = JSON.parse(out)
      expect(payload).to eq([])
    end
  end

describe "convert --from structure grammars" do
  it "ingests SMILES and renders text" do
    expect(run("convert", "-i", "CCO", "--from", "smiles", "-t", "text")).to eq("C-C-O\n")
  end

  it "ingests SMILES and emits the wire form" do
    out = run("convert", "-i", "c1ccccc1", "--from", "smiles", "-t", "model-json")
    expect(JSON.parse(out)["nodes"][0]["nodes"][0]["aromatic"]).to be(true)
  end

  it "ingests SMILES and re-emits canonical SMILES" do
    expect(run("convert", "-i", "CC(=O)OC1=CC=CC=C1C(=O)O", "--from", "smiles", "-t", "smiles"))
      .to eq("CC(=O)OC1=CC=CC=C1C(=O)O\n")
  end

  it "ingests a molfile from a file" do
    require "tempfile"
    atom = ->(x, y, sym) do
      format("%10.4f%10.4f%10.4f %-3s 0  0  0  0  0  0  0  0  0  0  0  0", x, y, 0.0, sym)
    end
    bond = ->(a, b) { format("%3d%3d%3d%3d  0  0  0  0  0  0  0", a, b, 1, 0) }
    file = Tempfile.new(["ethanol", ".mol"])
    file.write(
      ["ethanol", "  AsciiChem", "",
       format("%3d%3d  0  0  0  0  0  0  0  0999 V2000", 3, 2),
       atom.call(-0.25, 0.375, "C"), atom.call(0.4645, -0.0375, "C"),
       atom.call(1.179, 0.375, "O"),
       bond.call(1, 2), bond.call(2, 3), "M  END"].join("\n") << "\n"
    )
    file.close
    out = run("convert", "-f", file.path, "--from", "molfile", "-t", "model-json")
    elements = JSON.parse(out)["nodes"].flat_map do |m|
      m["nodes"].select { |n| n.is_a?(Hash) && n["type"] == "atom" }.map { |n| n["element"] }
    end
    expect(elements).to eq(%w[C C O])
  ensure
    file&.unlink
  end

  it "rejects an unknown --from grammar" do
    expect { described_class.start(["convert", "-i", "CCO", "--from", "inchi"]) }
      .to raise_error(SystemExit)
  end
end

  describe "resolve and validate" do
    it "validates identifier annotations offline" do
      out = run("validate", "-i", %q{H_2O @cas("7732-18-5") @cas("50-7-8")})
      expect(out).to include("cas")
      expect(out).to include("ok")
      expect(out).to include("INVALID")
    end

    it "reports when there are no annotations" do
      expect(run("validate", "-i", "H_2O")).to match(/no identifier annotations/)
    end

    it "resolves offline from a seeded cache entry" do
      require "asciichem/resolver"
      require "tmpdir"
      cache = AsciiChem::Resolver::Cache.new(dir: File.join(Dir.tmpdir, "asciichem-cli-#{rand(1e9)}"))
      fixture = File.read(File.expand_path("fixtures/resolver/pubchem/aspirin.json", File.dirname(__dir__)))
      fetcher = Struct.new(:body) do
        def get(_url) = body
      end.new(fixture)
      AsciiChem::Resolver[:pubchem].new.resolve(value: "aspirin", convention: "name",
                                                fetch: fetcher, cache: cache)
      allow(AsciiChem::Resolver::Cache).to receive(:default).and_return(cache)
      out = run("resolve", "--name", "aspirin", "-t", "text")
      expect(out).to eq("2-acetyloxybenzoic acid\n")
    end

    it "exits with an actionable error for unknown sources" do
      expect { described_class.start(["resolve", "--name", "x", "--source", "nope"]) }
        .to raise_error(SystemExit)
    end
  end

  describe "cite" do
    it "emits a dataset bibitem from a seeded cache entry" do
      require "asciichem/resolver"
      require "tmpdir"
      cache = AsciiChem::Resolver::Cache.new(dir: File.join(Dir.tmpdir, "asciichem-cite-cli-#{rand(1e9)}"))
      fixture = File.read(File.expand_path("fixtures/resolver/pubchem/aspirin.json",
                                           File.dirname(__dir__)))
      fetcher = Struct.new(:body) do
        def get(_url) = body
      end.new(fixture)
      AsciiChem::Resolver[:pubchem].new.resolve(value: "aspirin", convention: "name",
                                                fetch: fetcher, cache: cache)
      allow(AsciiChem::Resolver::Cache).to receive(:default).and_return(cache)
      out = run("cite", "--name", "aspirin")
      expect(out).to include('type="dataset"')
      expect(out).to include("PubChem CID 2244")
    end
  end
end
