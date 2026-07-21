# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "asciichem/cli"

RSpec.describe AsciiChem::Cli do
  def run(*argv)
    original = $stdout
    $stdout = StringIO.new
    described_class.start(argv)
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
end

