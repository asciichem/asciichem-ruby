# frozen_string_literal: true

require "spec_helper"

RSpec.describe "MathML emission relies on the mml contract model" do
  # The mml gem (plurimath/mml) is the typed lutaml-model object graph
  # for MathML. Two reliance contracts are spec'd here:
  #
  # 1. Everything we emit parses back through Mml.parse — our output
  #    is valid MathML per the contract model, not just valid XML.
  # 2. Embedded math crosses through the Mml graph in both directions
  #    (typed parse + framework serialization), replacing the old
  #    xpath surgery on the Plurimath string.

  def parses_under_mml?(xml)
    Mml.parse(xml, version: 3)
    true
  rescue Mml::Error
    false
  end

  it "emits MathML the mml model accepts" do
    expect(parses_under_mml?(AsciiChem.parse("H_2O").to_mathml)).to be(true)
  end

  it "emits reaction MathML the mml model accepts" do
    xml = AsciiChem.parse("H_2 + I_2 <=>[400^o C][Pt] 2HI").to_mathml
    expect(parses_under_mml?(xml)).to be(true)
  end

  it "emits isotope-prefix MathML the mml model accepts" do
    expect(parses_under_mml?(AsciiChem.parse("^14C").to_mathml)).to be(true)
  end

  it "grafts embedded math through the Mml graph" do
    xml = AsciiChem.parse("`x^2 + 1` H_2O").to_mathml
    expect(parses_under_mml?(xml)).to be(true)
    expect(xml).to include("<mstyle")
    expect(xml).to include("<msup>")
    expect(xml).to include("<mi>x</mi>")
    expect(xml).to include("<mn>2</mn>")
  end

  it "round-trips embedded math through Mml with the superscript intact" do
    xml = AsciiChem.parse("`x^2 + 1`").to_mathml
    math = Mml.parse(xml, version: 3)
    # <math><mrow><mrow><mstyle>…: formula wrapper, embedded-math
    # wrapper, then the grafted fragment.
    mstyle = math.mrow_value.first.mrow_value.first.mstyle_value.first
    expect(mstyle.msup_value.first.mi_value.map(&:value)).to eq([["x"]])
    expect(mstyle.msup_value.first.mn_value.map(&:value)).to eq([["2"]])
    expect(mstyle.mo_value.map(&:value).flatten).to eq(["+"])
  end

  it "keeps the fallback row when the fragment cannot be parsed" do
    broken = Struct.new(:source, :formula).new(
      "x^2 + 1",
      Struct.new(:xml) { def to_mathml = xml }.new("not mathml at all <")
    )
    mrow = AsciiChem::Formatter::Mathml.new.visit_embedded_math(broken)
    expect(mrow.name).to eq("mrow")
  end

  describe "shared corpus goldens" do
    gem_root = File.expand_path("../../..", __dir__)
    corpus = File.join(gem_root, "..", "asciichem-tests", "corpus", "fixtures", "mathml.json")
    next unless File.file?(corpus)

    JSON.parse(File.read(corpus)).each do |fixture|
      it "#{fixture.fetch('id')} is valid MathML per the mml model" do
        expect(parses_under_mml?(fixture.fetch("mathml"))).to be(true)
      end
    end
  end
end
