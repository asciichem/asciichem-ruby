# frozen_string_literal: true

require "spec_helper"
require "chemicalml"
require "asciichem/cml"

RSpec.describe "atom coordinates and stereo syntax" do
  before(:all) { Chemicalml::Cml::Schema3.ensure_registered! }

  describe "atom parity (@R / @S)" do
    it "parses @R" do
      atom = AsciiChem.parse("C@R").nodes.first.nodes.first
      expect(atom.atom_parity).to eq("R")
    end

    it "parses @S" do
      atom = AsciiChem.parse("C@S").nodes.first.nodes.first
      expect(atom.atom_parity).to eq("S")
    end

    it "round-trips through Text" do
      expect(AsciiChem.parse("C@R").to_text).to eq("C@R")
      expect(AsciiChem.parse("C@S").to_text).to eq("C@S")
    end

    it "carries via aci:atomParity through CML" do
      xml = AsciiChem.parse("C@R").to_cml
      expect(xml).to include('aci:atomParity="R"')
    end

    it "round-trips through CML" do
      expect(AsciiChem::Cml.parse(AsciiChem.parse("C@S").to_cml).to_text).to eq("C@S")
    end
  end

  describe "2D coordinates @(x,y)" do
    it "parses coordinates" do
      atom = AsciiChem.parse("C@(10.5,20.3)").nodes.first.nodes.first
      expect(atom.x2).to eq(10.5)
      expect(atom.y2).to eq(20.3)
      expect(atom.z2).to be_nil
    end

    it "round-trips through Text" do
      expect(AsciiChem.parse("C@(10,20)").to_text).to eq("C@(10,20)")
    end

    it "emits x2/y2 attributes in CML" do
      xml = AsciiChem.parse("C@(10.5,20.3)").to_cml
      expect(xml).to include('x2="10.5"')
      expect(xml).to include('y2="20.3"')
    end

    it "round-trips through CML" do
      expect(AsciiChem::Cml.parse(AsciiChem.parse("C@(10,20)").to_cml).to_text).to eq("C@(10,20)")
    end
  end

  describe "3D coordinates @(x,y,z)" do
    it "parses 3D coordinates" do
      atom = AsciiChem.parse("C@(1,2,3)").nodes.first.nodes.first
      expect(atom.x2).to eq(1.0)
      expect(atom.y2).to eq(2.0)
      expect(atom.z2).to eq(3.0)
    end

    it "round-trips through Text" do
      expect(AsciiChem.parse("C@(1,2,3)").to_text).to eq("C@(1,2,3)")
    end

    it "emits x3/y3/z3 attributes in CML" do
      xml = AsciiChem.parse("C@(1,2,3)").to_cml
      expect(xml).to include('x3=')
      expect(xml).to include('y3=')
      expect(xml).to include('z3=')
    end

    it "round-trips through CML" do
      expect(AsciiChem::Cml.parse(AsciiChem.parse("C@(1,2,3)").to_cml).to_text).to eq("C@(1,2,3)")
    end
  end

  describe "coordinates with molecule structure" do
    it "works in a larger molecule" do
      src = "C@(0,0)-O@(10,0)-H@(10,5)"
      formula = AsciiChem.parse(src)
      atoms = formula.nodes.first.nodes.select { |n| n.is_a?(AsciiChem::Model::Atom) }
      expect(atoms[0].x2).to eq(0)
      expect(atoms[1].x2).to eq(10)
      expect(atoms[2].y2).to eq(5)
    end

    it "round-trips a positioned water molecule" do
      src = "H@(0,5)-O@(0,0)-H@(0,-5)"
      expect(AsciiChem.parse(src).to_text).to eq(src)
    end
  end
end
