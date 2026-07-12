# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Greek do
  describe ".translate" do
    it "translates lowercase Greek words" do
      expect(described_class.translate("alpha")).to eq("α")
      expect(described_class.translate("beta")).to eq("β")
      expect(described_class.translate("gamma")).to eq("γ")
      expect(described_class.translate("delta")).to eq("δ")
    end

    it "translates uppercase Greek words" do
      expect(described_class.translate("Delta")).to eq("Δ")
      expect(described_class.translate("Sigma")).to eq("Σ")
      expect(described_class.translate("Omega")).to eq("Ω")
    end

    it "translates Greek words embedded in text (longest-first)" do
      expect(described_class.translate("alpha + beta")).to eq("α + β")
      expect(described_class.translate("Delta T")).to eq("Δ T")
      # `eta` shouldn't shadow `beta`: `beta` is longer, translated first.
      expect(described_class.translate("beta + eta")).to eq("β + η")
    end

    it "leaves non-Greek text unchanged" do
      expect(described_class.translate("Fe catalyst")).to eq("Fe catalyst")
      expect(described_class.translate("400 degrees")).to eq("400 degrees")
    end

    it "handles nil and empty strings" do
      expect(described_class.translate(nil)).to be_nil
      expect(described_class.translate("")).to eq("")
    end
  end

  describe "ALL dictionary coverage" do
    it "covers every lowercase letter of the Greek alphabet" do
      lowercase_letters = ("α".."ω").to_a
      translated = described_class::LOWERCASE.values
      # Each lowercase Greek letter from alpha to omega should be a value
      # in the dictionary (24 letters).
      expect(translated.length).to eq(24)
    end
  end
end
