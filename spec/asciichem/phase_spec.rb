# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the molecule-level phase" do
  # mhchem's tight parenthesised form (grammar v0.11.0). Lowercase-only
  # in the grammar so the group reading — element symbols are
  # capitalised — can never collide: `Fe(s)` is solid iron, `Fe(S)` a
  # sulfur group (asciichem-ruby#214).

  {
    "NaCl(aq)" => :aqueous,
    "H_2O(l)" => :liquid,
    "Fe(s)" => :solid,
    "CO_2(g)" => :gas
  }.each do |source, phase|
    it "parses #{source.inspect} as #{phase.inspect} and round-trips verbatim" do
      molecule = AsciiChem.parse(source).nodes.first
      expect(molecule.phase).to eq(phase)
      expect(AsciiChem.parse(source).to_text).to eq(source)
    end
  end

  it "carries groups and subscripts before the phase" do
    molecule = AsciiChem.parse("Ca(OH)_2(aq)").nodes.first
    expect(molecule.phase).to eq(:aqueous)
    expect(AsciiChem.parse("Ca(OH)_2(aq)").to_text).to eq("Ca(OH)_2(aq)")
  end

  it "composes with the state mark — the phase precedes it" do
    formula = AsciiChem.parse("AgCl(s) v")
    expect(formula.nodes.first.phase).to eq(:solid)
    expect(formula.nodes.first.state).to eq(:precipitate)
    expect(formula.to_text).to eq("AgCl(s) v")
  end

  it "keeps the capitalised group reading (`Fe(S)` stays a sulfur group)" do
    molecule = AsciiChem.parse("Fe(S)").nodes.first
    expect(molecule.phase).to be_nil
    expect(molecule.nodes.last).to be_a(AsciiChem::Model::Group)
  end

  it "rejects a spaced phase — the mark vocabulary owns the spaced tail" do
    expect { AsciiChem.parse("AgCl (aq)") }.to raise_error(AsciiChem::ParseError)
  end

  it "typesets MathML as upright mtext" do
    expect(AsciiChem.parse("NaCl(aq)").to_mathml).to include("<mtext>(aq)</mtext>")
  end

  it "round-trips through CML (the aci:phase extension)" do
    back = AsciiChem::Cml.parse(AsciiChem.parse("NaCl(aq)").to_cml)
    expect(back.nodes.first.phase).to eq(:aqueous)
    expect(back.to_text).to eq("NaCl(aq)")
  end

  it "carries the phase through the wire form" do
    wire = AsciiChem.parse("NaCl(aq)").to_model_json
    expect(wire).to include('"phase":"aqueous"')
  end
end
