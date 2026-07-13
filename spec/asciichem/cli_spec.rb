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
      expect(out.strip).to eq("H<sub>2</sub>O")
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
end

