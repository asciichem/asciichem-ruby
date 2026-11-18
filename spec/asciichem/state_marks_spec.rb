# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the molecule-level state mark" do
  # Grammar v0.7.0 (asciichem-ruby#199): the mhchem phase glyph.
  # `AgCl v` precipitates (typeset ↓), `AgCl ^` is gas (↑). The mark
  # is whitespace-separated and lowercase-only; the tight `^` forms
  # keep their existing binding.

  describe "parsing" do
    it "binds v as the precipitate state" do
      formula = AsciiChem.parse("AgCl v")
      molecule = formula.nodes.first
      expect(molecule).to be_a(AsciiChem::Model::Molecule)
      expect(molecule.state).to eq(:precipitate)
    end

    it "binds ^ as the gas state" do
      expect(AsciiChem.parse("AgCl ^").nodes.first.state).to eq(:gas)
    end

    it "parses inside a reaction's products" do
      formula = AsciiChem.parse("Ag^+ + Cl^- -> AgCl v")
      reaction = formula.nodes.first
      expect(reaction.products.last.state).to eq(:precipitate)
      expect(reaction.reactants.first.state).to be_nil
    end

    it "parses with a coefficient and a group" do
      formula = AsciiChem.parse("2Ca(OH)_2 ^")
      molecule = formula.nodes.first
      expect(molecule.coefficient).to eq("2")
      expect(molecule.state).to eq(:gas)
    end

    it "does not steal the vanadium atom: uppercase V is an atom" do
      formula = AsciiChem.parse("AgCl V")
      expect(formula.nodes.map(&:class)).to eq([AsciiChem::Model::Molecule,
                                                AsciiChem::Model::Molecule])
      expect(formula.nodes.first.state).to be_nil
      expect(formula.nodes.last.nodes.first.element).to eq("V")
    end

    it "keeps the tight ^14C form state-free and round-tripping" do
      formula = AsciiChem.parse("AgCl^14C")
      molecule = formula.nodes.first
      expect(molecule.state).to be_nil
      expect(formula.to_text).to eq("AgCl^14C")
    end

    it "keeps the tight charge superscript binding" do
      formula = AsciiChem.parse("Ca^2+")
      expect(formula.nodes.first.state).to be_nil
      expect(formula.nodes.first.nodes.first.charge).to eq("2+")
    end

    it "rejects a tight ^2+ after whitespace (ambiguous with gas)" do
      expect { AsciiChem.parse("Ca ^2+") }.to raise_error(AsciiChem::ParseError)
    end
  end

  describe "text round-trip" do
    it "round-trips the precipitate mark" do
      expect(AsciiChem.parse("AgCl v").to_text).to eq("AgCl v")
    end

    it "round-trips the gas mark" do
      expect(AsciiChem.parse("AgCl ^").to_text).to eq("AgCl ^")
    end

    it "round-trips inside a reaction" do
      s = "CaCO_3 ->[heat] CaO + CO_2 ^"
      expect(AsciiChem.parse(s).to_text).to eq(s)
    end

    it "orders the mark before molecule annotations" do
      expect(AsciiChem.parse('AgCl v @name("silver chloride")').to_text)
        .to eq('AgCl v @name("silver chloride")')
    end
  end

  describe "renderers" do
    let(:precipitate) { AsciiChem.parse("AgCl v") }
    let(:gas) { AsciiChem.parse("AgCl ^") }

    it "typesets the down arrow in MathML" do
      expect(precipitate.to_mathml).to include("↓")
    end

    it "typesets the up arrow in MathML" do
      expect(gas.to_mathml).to include("↑")
    end

    it "emits mhchem's own output form in LaTeX" do
      expect(precipitate.to_latex).to eq("\\ce{AgCl\\downarrow}")
      expect(gas.to_latex).to eq("\\ce{AgCl\\uparrow}")
    end

    it "emits the HTML entities" do
      expect(precipitate.to_html).to include("&darr;")
      expect(gas.to_html).to include("&uarr;")
    end

    it "emits the unicode arrow in linear SVG" do
      expect(precipitate.to_svg).to include("↓")
      expect(gas.to_svg).to include("↑")
    end

    it "leaves stateless molecules untouched" do
      expect(AsciiChem.parse("AgCl").to_text).to eq("AgCl")
      expect(AsciiChem.parse("AgCl").to_mathml).not_to include("↓")
      expect(AsciiChem.parse("AgCl").to_html).not_to include("&darr;")
    end
  end

  describe "equality" do
    it "treats molecules differing only in state as distinct" do
      plain = AsciiChem.parse("AgCl").nodes.first
      marked = AsciiChem.parse("AgCl v").nodes.first
      expect(plain).not_to eq(marked)
      expect(AsciiChem.parse("AgCl v").nodes.first)
        .to eq(AsciiChem.parse("AgCl v").nodes.first)
    end
  end

  describe "CML round-trip" do
    it "carries the state through the aci: side-channel" do
      cml = AsciiChem.parse("AgCl v").to_cml
      expect(cml).to include('aci:state="precipitate"')

      back = AsciiChem::Cml.parse(cml)
      expect(back.to_text).to eq("AgCl v")
      expect(back.nodes.first.state).to eq(:precipitate)
    end

    it "carries the gas state through a reaction" do
      source = "CaCO_3 ->[heat] CaO + CO_2 ^"
      back = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml)
      expect(back.to_text).to eq(source)
      reaction = back.nodes.find { |n| n.is_a?(AsciiChem::Model::Reaction) }
      expect(reaction.products.last.state).to eq(:gas)
    end

    it "keeps plain molecules' CML clean (no aci: namespace)" do
      cml = AsciiChem.parse("H_2O").to_cml
      expect(cml).not_to include("aci:")
    end
  end

  describe "the wire form (documented loss)" do
    # The v1 wire schema has no molecule-state field yet — the state
    # rides the aci: side-channel for CML and is DROPPED from the
    # model JSON until the schema grows the field (the deliberate
    # scope of #199). This spec pins the loss so it is never silent:
    # when the schema grows, this expectation flips.
    it "drops the state through the wire round-trip" do
      formula = AsciiChem.parse("AgCl v")
      back = AsciiChem.from_model_json(formula.to_model_json)
      expect(back.nodes.first.state).to be_nil
      expect(back.to_text).to eq("AgCl")
    end
  end
end
