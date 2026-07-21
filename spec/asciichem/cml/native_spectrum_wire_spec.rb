# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe "Native CML wire for Spectrum (chemicalml 0.3.0+)" do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  let(:source) { %(spectrum[nmr](type=1H,solvent=CDCl3){1.2: 3H s "CH3"}) }

  def cml_of(src)
    AsciiChem.parse(src).to_cml
  end

  def parsed_formula(xml)
    AsciiChem::Cml.parse(xml)
  end

  describe "emit" do
    it "produces native <spectrum> inside <molecule>" do
      xml = cml_of(source)
      expect(xml).to include("<spectrum")
      expect(xml).to include("<molecule")
      expect(xml).not_to include("aci:spectrum")
    end

    it "serializes peak via <peak> with xValue/yValue/yMultiplicity" do
      xml = cml_of(source)
      expect(xml).to include("<peak")
      expect(xml).to include('xValue="1.2"')
      expect(xml).to include('yValue="3H"')
      expect(xml).to include('yMultiplicity="s"')
      expect(xml).to include('title="CH3"')
    end

    it "emits format (spectrum type) and condition (solvent)" do
      xml = cml_of(source)
      expect(xml).to include('format="1H"')
      expect(xml).to include('condition="CDCl3"')
    end
  end

  describe "round-trip" do
    it "preserves Spectrum identity on full CML round-trip" do
      formula = parsed_formula(cml_of(source))
      expect(formula.nodes.first).to be_an(AsciiChem::Model::Spectrum)
    end

    it "preserves spectrum type" do
      formula = parsed_formula(cml_of(source))
      expect(formula.nodes.first.type).to eq("nmr")
    end

    it "preserves params (type, solvent)" do
      formula = parsed_formula(cml_of(source))
      expect(formula.nodes.first.params[:type]).to eq("1H")
      expect(formula.nodes.first.params[:solvent]).to eq("CDCl3")
    end

    it "preserves peak data" do
      formula = parsed_formula(cml_of(source))
      peak = formula.nodes.first.peaks.first
      expect(peak.position).to eq("1.2")
      expect(peak.intensity).to eq("3H")
      expect(peak.multiplicity).to eq("s")
      expect(peak.assignment).to eq("CH3")
    end
  end

  describe "backwards compat" do
    it "still parses legacy aci: text-carrier Spectrum XML" do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <aci:spectrum position="0">spectrum[legacy](type=x){1: 1H s "a"}</aci:spectrum>
        </cml>
      CML
      formula = parsed_formula(xml)
      expect(formula.nodes.first).to be_an(AsciiChem::Model::Spectrum)
      expect(formula.nodes.first.type).to eq("legacy")
    end
  end
end
