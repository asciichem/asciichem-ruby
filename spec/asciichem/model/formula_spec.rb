# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Formula do
  describe "#initialize" do
    it "defaults to an empty node list" do
      expect(described_class.new.nodes).to eq([])
    end
  end

  describe "#<<" do
    it "appends a node and returns self" do
      formula = described_class.new
      atom = AsciiChem::Model::Atom.new(element: "H")
      result = formula << atom
      expect(result).to be(formula)
      expect(formula.nodes).to eq([atom])
    end
  end
end
