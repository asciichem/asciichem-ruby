# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::PeriodicTable do
  describe ".known?" do
    it "returns true for common elements" do
      expect(described_class.known?("H")).to be(true)
      expect(described_class.known?("C")).to be(true)
      expect(described_class.known?("Fe")).to be(true)
    end

    it "returns false for typos" do
      expect(described_class.known?("Hx")).to be(false)
      expect(described_class.known?("Cy")).to be(false)
      expect(described_class.known?("X")).to be(false)
    end

    it "accepts symbol argument" do
      expect(described_class.known?(:H)).to be(true)
    end
  end

  describe ".atomic_number" do
    it "returns the atomic number for known elements" do
      expect(described_class.atomic_number("H")).to eq(1)
      expect(described_class.atomic_number("He")).to eq(2)
      expect(described_class.atomic_number("C")).to eq(6)
      expect(described_class.atomic_number("Fe")).to eq(26)
      expect(described_class.atomic_number("U")).to eq(92)
    end

    it "returns nil for unknown elements" do
      expect(described_class.atomic_number("Hx")).to be_nil
    end
  end

  describe ".max_valence" do
    it "returns the max valence for common elements" do
      expect(described_class.max_valence("H")).to eq(1)
      expect(described_class.max_valence("C")).to eq(4)
      expect(described_class.max_valence("O")).to eq(2)
      expect(described_class.max_valence("S")).to eq(6)
    end

    it "returns 0 for noble gases" do
      expect(described_class.max_valence("He")).to eq(0)
      expect(described_class.max_valence("Ne")).to eq(0)
      expect(described_class.max_valence("Ar")).to eq(0)
    end

    it "returns nil for unknown elements" do
      expect(described_class.max_valence("Hx")).to be_nil
    end
  end

  describe ".symbols" do
    it "includes all expected common elements" do
      symbols = described_class.symbols
      %w[H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Fe Cu Zn Br I Au Hg Pb U].each do |s|
        expect(symbols).to include(s)
      end
    end
  end

  describe "ELEMENTS registry" do
    it "is frozen (single source of truth, runtime-immutable)" do
      expect(described_class::ELEMENTS).to be_frozen
    end
  end
end
