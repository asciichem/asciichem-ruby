# frozen_string_literal: true

require "spec_helper"

RSpec.describe "empty body braces for beyond-formulas constructs" do
  %w[
    crystal[x](a=1){}
    crystal[x]{}
    spectrum[nmr](){}
    spectrum[x]{}
    calc(m){}
    zmatrix{}
    mechanism{}
  ].each do |src|
    it "parses #{src.inspect} to an empty-children construct" do
      formula = AsciiChem.parse(src)
      node = formula.nodes.first
      expect(node).not_to be_nil
      # The construct's children (atoms / peaks / rows / steps) should be empty
      case node
      when AsciiChem::Model::Crystal    then expect(node.atoms).to eq([])
      when AsciiChem::Model::Spectrum   then expect(node.peaks).to eq([])
      when AsciiChem::Model::ZMatrix    then expect(node.rows).to eq([])
      when AsciiChem::Model::Mechanism  then expect(node.steps).to eq([])
      when AsciiChem::Model::Calculation then expect(node.properties).to eq([])
      end
    end
  end
end
