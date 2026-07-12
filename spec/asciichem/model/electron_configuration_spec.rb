# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::ElectronConfiguration do
  describe "#initialize" do
    it "holds orbital/occupancy pairs" do
      ec = described_class.new(orbitals: [["1s", "2"], ["2s", "2"]])
      expect(ec.orbitals).to eq([["1s", "2"], ["2s", "2"]])
    end
  end

  describe "TermSymbol" do
    it "formats as ^{mult}L_{J}" do
      ts = AsciiChem::Model::ElectronConfiguration::TermSymbol.new(
        multiplicity: "3", letter: "P", j_value: "2"
      )
      expect(ts.to_s).to eq("^3P_2")
    end
  end
end
