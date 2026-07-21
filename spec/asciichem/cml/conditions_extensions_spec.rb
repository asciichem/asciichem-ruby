# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe AsciiChem::Cml::ConditionsExtensions do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  describe ".inject and .extract" do
    it "round-trips reaction conditions through native <conditionList>" do
      formula = AsciiChem.parse("N_2 + 3H_2 <=>[Fe][400C] 2NH_3")
      xml = AsciiChem::Cml.from_asciichem(formula)
      # v0.11.0+: native <conditionList> replaces aci: attributes
      expect(xml).to include("<conditionList>")
      expect(xml).to include('title="above">Fe')
      expect(xml).to include('title="below">400C')

      parsed = AsciiChem::Cml.parse(xml)
      reaction = parsed.nodes.first
      expect(reaction).to be_an(AsciiChem::Model::Reaction)
      expect(reaction.conditions.above).to eq("Fe")
      expect(reaction.conditions.below).to eq("400C")
    end

    it "is a no-op for reactions without conditions" do
      formula = AsciiChem.parse("2H_2 + O_2 -> 2H_2O")
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).not_to include("aci:conditions")
      expect(xml).not_to include("<conditionList>")
    end

    it "handles only-above conditions" do
      formula = AsciiChem.parse("A ->[cat] B")
      xml = AsciiChem::Cml.from_asciichem(formula)
      expect(xml).to include('title="above">cat')
      expect(xml).not_to include('title="below')
    end

    it "extracts conditions produced by another aci: producer" do
      xml = <<~CML
        <?xml version="1.0"?>
        <cml xmlns="http://www.xml-cml.org/schema" xmlns:aci="https://asciichem.org/cml-ext">
          <reaction id="r1" aci:conditionsAbove="Pt" aci:conditionsBelow="80C">
            <reactantList/>
            <productList/>
          </reaction>
        </cml>
      CML
      conditions = described_class.extract(xml)
      expect(conditions["r1"][:above]).to eq("Pt")
      expect(conditions["r1"][:below]).to eq("80C")
    end

    it "preserves conditions through reaction cascade" do
      formula = AsciiChem.parse("A ->[c1] B ->[c2] C")
      xml = AsciiChem::Cml.from_asciichem(formula)
      parsed = AsciiChem::Cml.parse(xml)
      cascade = parsed.nodes.first
      expect(cascade).to be_an(AsciiChem::Model::ReactionCascade)
      expect(cascade.steps.length).to eq(2)
      expect(cascade.steps[0].conditions.above).to eq("c1")
      expect(cascade.steps[1].conditions.above).to eq("c2")
    end
  end

  describe ".restore" do
    it "is a no-op when conditions is empty" do
      formula = AsciiChem.parse("A -> B")
      original_conditions = formula.nodes.first.conditions
      described_class.restore(formula, {})
      expect(formula.nodes.first.conditions).to eq(original_conditions)
    end
  end
end
