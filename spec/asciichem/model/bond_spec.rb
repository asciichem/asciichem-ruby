# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Bond do
  describe "#initialize" do
    it "defaults to single bond" do
      expect(described_class.new.kind).to eq(:single)
    end
  end

  describe "#ascii" do
    it "maps kinds to ASCII spellings" do
      expect(described_class.new(kind: :single).ascii).to eq("-")
      expect(described_class.new(kind: :double).ascii).to eq("=")
      expect(described_class.new(kind: :triple).ascii).to eq("#")
      expect(described_class.new(kind: :dative).ascii).to eq("->")
    end
  end

  describe "#entity" do
    it "maps kinds to MathML entities" do
      expect(described_class.new(kind: :triple).entity).to eq("≡")
      expect(described_class.new(kind: :dative).entity).to eq("→")
    end
  end
end
