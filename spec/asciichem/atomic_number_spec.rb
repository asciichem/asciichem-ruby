# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the atomic-number isotope prefix" do
  # Grammar v0.8.0 (asciichem-ruby#201): mhchem's left-subscript
  # isotope component. `^227_90Th` carries isotope 227 AND atomic
  # number 90. The atomic number only arrives attached to a
  # `^`-mass prefix — the standalone `_90Th` keeps its legacy isotope
  # reading, and after the element the `_digits` suffix stays a
  # subscript.

  describe "parsing" do
    it "binds the combined form" do
      atom = AsciiChem.parse("^227_90Th").nodes.first.nodes.first
      expect(atom.element).to eq("Th")
      expect(atom.isotope).to eq("227")
      expect(atom.atomic_number).to eq("90")
    end

    it "keeps the legacy underscore-isotope reading" do
      atom = AsciiChem.parse("_14C").nodes.first.nodes.first
      expect(atom.isotope).to eq("14")
      expect(atom.atomic_number).to be_nil
    end

    it "keeps the post-element underscore a subscript" do
      molecule = AsciiChem.parse("^14C_6").nodes.first
      atom = molecule.nodes.first
      expect(atom.isotope).to eq("14")
      expect(atom.atomic_number).to be_nil
      expect(atom.subscript).to eq("6")
    end
  end

  describe "text round-trip" do
    it "round-trips the combined form" do
      expect(AsciiChem.parse("^227_90Th").to_text).to eq("^227_90Th")
    end

    it "canonicalises the legacy underscore-isotope to the caret form" do
      expect(AsciiChem.parse("_14C").to_text).to eq("^14C")
    end
  end

  describe "renderers" do
    let(:thorium) { AsciiChem.parse("^227_90Th") }
    let(:atom) { thorium.nodes.first.nodes.first }

    it "emits the prescript pair in MathML (Z under A)" do
      mathml = thorium.to_mathml
      expect(mathml).to include("<mprescripts/>")
      # The prescripts order is (left-subscript, left-superscript):
      # the atomic number 90 under the mass number 227.
      expect(mathml).to match(%r{<mprescripts/>\s*<mn>90</mn>\s*<mn>227</mn>})
    end

    it "emits mhchem's combined form in LaTeX" do
      expect(thorium.to_latex).to include("^227_90Th")
    end

    it "emits the subscript entity in HTML" do
      expect(thorium.to_html).to include("<sub>90</sub>")
    end

    it "leaves plain isotopes untouched" do
      plain = AsciiChem.parse("^14C")
      expect(plain.to_text).to eq("^14C")
      expect(plain.to_mathml).not_to include("<mn>90</mn>")
    end
  end

  describe "linter" do
    it "accepts a stated atomic number matching the element" do
      expect(AsciiChem::Linter.run(AsciiChem.parse("^14_6C"))).to be_empty
    end

    it "errors when the stated atomic number contradicts the element" do
      diagnostics = AsciiChem::Linter.run(AsciiChem.parse("^14_7C"))
      expect(diagnostics.map(&:severity)).to include(:error)
      expect(diagnostics.last.message).to include("does not match")
    end

    it "stays silent without the atomic number" do
      expect(AsciiChem::Linter.run(AsciiChem.parse("^14C"))).to be_empty
    end
  end

  describe "equality" do
    it "treats atoms differing only in atomic_number as distinct" do
      plain = AsciiChem.parse("^14C").nodes.first.nodes.first
      stated = AsciiChem.parse("^14_6C").nodes.first.nodes.first
      expect(plain).not_to eq(stated)
      expect(AsciiChem.parse("^14_6C").nodes.first.nodes.first)
        .to eq(AsciiChem.parse("^14_6C").nodes.first.nodes.first)
    end
  end

  describe "the wire form" do
    # The model schema grew atomicNumber in the same train (the #199
    # lesson): the field rides the model JSON and round-trips
    # losslessly.
    it "preserves the atomic number through the wire round-trip" do
      formula = AsciiChem.parse("^227_90Th")
      back = AsciiChem.from_model_json(formula.to_model_json)
      atom = back.nodes.first.nodes.first
      expect(atom.isotope).to eq("227")
      expect(atom.atomic_number).to eq("90")
      expect(back.to_text).to eq("^227_90Th")
    end
  end

  describe "CML round-trip" do
    it "carries the atomic number through the aci: channel" do
      cml = AsciiChem.parse("^227_90Th").to_cml
      expect(cml).to include('aci:atomicNumber="90"')

      back = AsciiChem::Cml.parse(cml)
      atom = back.nodes.first.nodes.first
      expect(atom.isotope).to eq("227")
      expect(atom.atomic_number).to eq("90")
      expect(back.to_text).to eq("^227_90Th")
    end

    it "keeps plain atoms' CML clean" do
      expect(AsciiChem.parse("^14C").to_cml).not_to include("aci:atomicNumber")
    end
  end
end
