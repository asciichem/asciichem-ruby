# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe "Native CML wire for Crystal (chemicalml 0.3.0+)" do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  let(:source) do
    "crystal[NaCl](a=5.64,b=5.64,c=5.64,alpha=90,beta=90,gamma=90,sg=Fm-3m)" \
      "{Na@f(0,0,0) Cl@f(0.5,0.5,0.5)}"
  end

  def cml_of(src)
    AsciiChem.parse(src).to_cml
  end

  def parsed_formula(xml)
    AsciiChem::Cml.parse(xml)
  end

  describe "emit" do
    it "produces native <crystal> inside <molecule> instead of aci: text carrier" do
      xml = cml_of(source)
      expect(xml).to include("<crystal")
      expect(xml).to include("<molecule")
      expect(xml).not_to include("aci:crystal")
    end

    it "serializes spacegroup via <symmetry spaceGroup=...>" do
      xml = cml_of(source)
      expect(xml).to include('spaceGroup="Fm-3m"')
      expect(xml).to include("<symmetry")
    end

    it "emits each cell parameter as a <scalar title=...>" do
      xml = cml_of("crystal[x](a=5.64,b=5.64,c=5.64){}")
      expect(xml).to include('<scalar title="a">5.64</scalar>')
      expect(xml).to include('<scalar title="b">5.64</scalar>')
      expect(xml).to include('<scalar title="c">5.64</scalar>')
    end

    it "places atoms in <atomArray> with xFract/yFract/zFract" do
      xml = cml_of(source)
      expect(xml).to include("xFract")
      expect(xml).to include("yFract")
      expect(xml).to include("zFract")
      expect(xml).to include('elementType="Na"')
      expect(xml).to include('elementType="Cl"')
    end
  end

  describe "round-trip" do
    it "preserves Crystal identity on full CML round-trip" do
      xml = cml_of(source)
      formula = parsed_formula(xml)
      expect(formula.nodes.first).to be_an(AsciiChem::Model::Crystal)
    end

    it "preserves spacegroup" do
      formula = parsed_formula(cml_of(source))
      expect(formula.nodes.first.spacegroup).to eq("Fm-3m")
    end

    it "preserves cell parameters" do
      formula = parsed_formula(cml_of(source))
      crystal = formula.nodes.first
      expect(crystal.a).to eq("5.64")
      expect(crystal.b).to eq("5.64")
      expect(crystal.c).to eq("5.64")
    end

    it "preserves atoms with fractional coords" do
      formula = parsed_formula(cml_of(source))
      crystal = formula.nodes.first
      expect(crystal.atoms.length).to eq(2)
      expect(crystal.atoms.map(&:element)).to contain_exactly("Na", "Cl")
    end
  end

  describe "backwards compat" do
    it "still parses legacy aci: text-carrier Crystal XML" do
      # An older AsciiChem (< 0.9) would emit Crystal as
      # <aci:crystal position="0">crystal[...]{...}</aci:crystal>
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <aci:crystal position="0">crystal[Legacy](a=1.0){Na@f(0,0,0)}</aci:crystal>
        </cml>
      CML
      formula = parsed_formula(xml)
      expect(formula.nodes.first).to be_an(AsciiChem::Model::Crystal)
      expect(formula.nodes.first.name).to eq("Legacy")
    end
  end
end
