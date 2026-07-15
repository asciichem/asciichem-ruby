# frozen_string_literal: true

require "spec_helper"
require "asciichem/cml"

RSpec.describe AsciiChem::Cml do
  describe ".from_asciichem (AsciiChem -> CML)" do
    it "emits well-formed CML for a simple molecule" do
      formula = AsciiChem.parse("H_2O")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include("<molecule")
      expect(xml).to include('elementType="H"')
      expect(xml).to include('count="2"')
      expect(xml).to include('elementType="O"')
    end

    it "binds the prefix isotope to the atom (semantic fix)" do
      formula = AsciiChem.parse("^14C")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include('isotope="14"')
      expect(xml).to include('elementType="C"')
    end

    it "emits formalCharge for an ion" do
      formula = AsciiChem.parse("Ca^2+")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include('elementType="Ca"')
      expect(xml).to include('formalCharge="2+"')
    end

    it "serialises a reaction with reactants and products" do
      formula = AsciiChem.parse("2H_2 + O_2 -> 2H_2O")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include("<reaction")
      expect(xml).to include("<reactantList")
      expect(xml).to include("<productList")
      expect(xml).to include('count="2"')
    end

    it "emits a bondArray for a structural molecule" do
      formula = AsciiChem.parse("H-O-H")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include("<bondArray")
      expect(xml).to include('atomRefs2="a1 a2"')
      expect(xml).to include('atomRefs2="a2 a3"')
      expect(xml).to include('order="S"')
    end

    it "produces stable, deterministic IDs" do
      xml_a = AsciiChem.parse("H_2O").to_cml
      xml_b = AsciiChem.parse("H_2O").to_cml
      expect(xml_a).to eq(xml_b)
    end

    it "places every molecule under a single <cml> root" do
      formula = AsciiChem.parse("H_2O")
      xml = described_class.from_asciichem(formula)
      expect(xml).to include("<cml")
      expect(xml.scan(/<cml\b/).length).to eq(1)
    end
  end

  describe ".parse (CML -> AsciiChem)" do
    it "rebuilds a Molecule from minimal CML" do
      cml = <<~CML
        <cml xmlns="http://www.xml-cml.org/schema">
          <molecule id="m1">
            <atomArray>
              <atom id="a1" elementType="H" count="2"/>
              <atom id="a2" elementType="O"/>
            </atomArray>
          </molecule>
        </cml>
      CML
      formula = described_class.parse(cml)
      molecule = formula.nodes.first
      expect(molecule).to be_a(AsciiChem::Model::Molecule)
      expect(molecule.nodes.map(&:element)).to eq(%w[H O])
      expect(molecule.nodes.first.subscript).to eq("2")
    end

    it "preserves isotope information" do
      cml = <<~CML
        <cml xmlns="http://www.xml-cml.org/schema">
          <molecule id="m1">
            <atomArray>
              <atom id="a1" elementType="C" isotope="14"/>
            </atomArray>
          </molecule>
        </cml>
      CML
      atom = described_class.parse(cml).nodes.first.nodes.first
      expect(atom.element).to eq("C")
      expect(atom.isotope).to eq("14")
    end

    it "preserves formal charge" do
      cml = <<~CML
        <cml xmlns="http://www.xml-cml.org/schema">
          <molecule id="m1">
            <atomArray>
              <atom id="a1" elementType="Ca" formalCharge="2+"/>
            </atomArray>
          </molecule>
        </cml>
      CML
      atom = described_class.parse(cml).nodes.first.nodes.first
      expect(atom.element).to eq("Ca")
      expect(atom.charge).to eq("2+")
    end

    it "rebuilds a Reaction" do
      cml = AsciiChem.parse("H_2 + O_2 -> H_2O").to_cml
      formula = described_class.parse(cml)
      reaction = formula.nodes.find { |n| n.is_a?(AsciiChem::Model::Reaction) }
      expect(reaction).not_to be_nil
      expect(reaction.reactants.length).to eq(2)
      expect(reaction.products.length).to eq(1)
      expect(reaction.arrow).to eq(:forward)
    end

    it "rebuilds bonds between adjacent atoms" do
      cml = AsciiChem.parse("H-O-H").to_cml
      formula = described_class.parse(cml)
      nodes = formula.nodes.first.nodes
      expect(nodes.map(&:class)).to eq(
        [
          AsciiChem::Model::Atom,
          AsciiChem::Model::Bond,
          AsciiChem::Model::Atom,
          AsciiChem::Model::Bond,
          AsciiChem::Model::Atom
        ]
      )
    end
  end

  describe "three-way round-trip" do
    # AsciiChem -> Model -> Canonical -> CML -> Canonical -> Model ->
    # AsciiChem. Every construct we promote to the canonical model
    # must survive a full round-trip.
    cases = {
      "water" => "H_2O",
      "carbon-14" => "^14C",
      "calcium ion" => "Ca^2+",
      "ethanol linear bonds" => "H-O-H",
      "single reaction" => "2H_2 + O_2 -> 2H_2O",
      "equilibrium" => "H_2 + I_2 <=> 2HI",
      "structural chain" => "CH_3-CH_2-OH"
    }

    cases.each do |name, source|
      it "round-trips #{name} (#{source.inspect})" do
        round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
        expect(round_trip).to eq(source)
      end
    end
  end

  describe "Formula#to_cml convenience method" do
    it "delegates to AsciiChem::Cml" do
      formula = AsciiChem.parse("H_2O")
      expect(formula.to_cml).to include("<cml")
      expect(formula.to_cml).to eq(AsciiChem::Cml.from_asciichem(formula))
    end
  end

  describe "AsciiChem-specific extensions (aci: namespace)" do
    # AsciiChem-specific fields that CML doesn't natively carry
    # (oxidation state, Lewis markers) survive round-trip via an
    # `aci:` namespace side-channel. See `AsciiChem::Cml::Extensions`.

    it "declares the aci: namespace on the root when extensions are present" do
      xml = AsciiChem.parse("::O").to_cml
      expect(xml).to include('xmlns:aci="https://asciichem.org/cml-ext"')
    end

    it "does not declare the aci: namespace when no extensions are needed" do
      xml = AsciiChem.parse("H_2O").to_cml
      expect(xml).not_to include("aci:")
    end

    it "carries oxidation state via aci:oxidationState" do
      xml = AsciiChem.parse("Fe^(II)").to_cml
      expect(xml).to include('aci:oxidationState="II"')
    end

    it "carries lone pairs via aci:lonePairs" do
      xml = AsciiChem.parse("::O").to_cml
      expect(xml).to include('aci:lonePairs="2"')
    end

    it "carries radical electrons via aci:radicalElectrons" do
      xml = AsciiChem.parse("N.").to_cml
      expect(xml).to include('aci:radicalElectrons="1"')
    end

    it "preserves oxidation state through full CML round-trip" do
      source = "Fe^(II)"
      round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
      expect(round_trip).to eq(source)
    end

    it "preserves Lewis markers through full CML round-trip" do
      source = "::O"
      round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
      expect(round_trip).to eq(source)
    end

    it "carries electron configuration via aci:electronConfiguration element" do
      xml = AsciiChem.parse("1s^2 2s^2").to_cml
      expect(xml).to include("<aci:electronConfiguration")
      expect(xml).to include(">1s^2 2s^2<")
    end

    it "carries embedded math via aci:embeddedMath element" do
      xml = AsciiChem.parse("`K_c = 1`").to_cml
      expect(xml).to include("<aci:embeddedMath")
      expect(xml).to include(">K_c = 1<")
    end

    it "preserves position of top-level extensions" do
      # EC at position 0, Molecule at position 1.
      xml = AsciiChem.parse("1s^2 2s^2 H_2O").to_cml
      formula = AsciiChem::Cml.parse(xml)
      expect(formula.nodes.first).to be_a(AsciiChem::Model::ElectronConfiguration)
      expect(formula.nodes.last).to be_a(AsciiChem::Model::Molecule)
    end

    it "preserves standalone electron configuration through full CML round-trip" do
      source = "1s^2 2s^2"
      round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
      expect(round_trip).to eq(source)
    end

    it "preserves multi-orbital electron configuration" do
      source = "1s^2 2s^2 2p^6 3d^10 4s^2"
      round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
      expect(round_trip).to eq(source)
    end

    it "preserves standalone embedded math through full CML round-trip" do
      source = "`K_c = [P]/[R]`"
      round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
      expect(round_trip).to eq(source)
    end

    it "preserves molecule + electron configuration order" do
      source = "H_2O 1s^2 2s^2"
      round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
      expect(round_trip).to eq(source)
    end

    it "preserves electron configuration + molecule order" do
      source = "1s^2 2s^2 H_2O"
      round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
      expect(round_trip).to eq(source)
    end

    it "combines atom-level and top-level extensions" do
      source = "Fe^(II) 1s^2 2s^2"
      round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
      expect(round_trip).to eq(source)
    end

    it "preserves combined Lewis markers (lone pairs + radical)" do
      source = "::N."
      round_trip = AsciiChem::Cml.parse(AsciiChem.parse(source).to_cml).to_text
      expect(round_trip).to eq(source)
    end
  end

  describe "known model-level limitations (documented)" do
    # These limitations exist because the canonical Chemicalml::Model
    # is currently narrower than AsciiChem::Model. They will close as
    # the canonical model grows. Specs guard the documented behaviour
    # so silent regressions surface.

    it "group multiplicity flattens to atom counts (no group concept)" do
      # AsciiChem::Model::Group has no canonical equivalent; the
      # multiplicity multiplies through to the contained atoms.
      xml = AsciiChem.parse("(OH)_2").to_cml
      expect(xml).to include('elementType="O" count="2"')
      expect(xml).to include('elementType="H" count="2"')
    end
  end
end
