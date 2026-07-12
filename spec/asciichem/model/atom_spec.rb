# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Atom do
  describe "#initialize" do
    it "sets the element" do
      atom = described_class.new(element: "C")
      expect(atom.element).to eq("C")
    end

    it "defaults optional fields to nil" do
      atom = described_class.new(element: "C")
      expect(atom.isotope).to be_nil
      expect(atom.subscript).to be_nil
      expect(atom.superscript).to be_nil
      expect(atom.charge).to be_nil
      expect(atom.oxidation_state).to be_nil
    end
  end

  describe "#==" do
    it "is equal when all fields match" do
      a = described_class.new(element: "C", isotope: "14")
      b = described_class.new(element: "C", isotope: "14")
      expect(a).to eq(b)
    end

    it "is unequal when any field differs" do
      a = described_class.new(element: "C", isotope: "14")
      b = described_class.new(element: "C", isotope: "12")
      expect(a).not_to eq(b)
    end

    it "is unequal to other classes" do
      atom = described_class.new(element: "C")
      other = AsciiChem::Model::Text.new(content: "C")
      expect(atom).not_to eq(other)
    end
  end

  describe "visitor dispatch" do
    let(:visitor) do
      Struct.new(:visited, keyword_init: true).new(visited: nil).tap do |s|
        s.define_singleton_method(:visit_atom) { |a| self.visited = a }
      end
    end

    it "calls visit_atom" do
      atom = described_class.new(element: "C")
      atom.accept(visitor)
      expect(visitor.visited).to be(atom)
    end
  end
end
