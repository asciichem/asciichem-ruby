# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Linter::IdentifierConsistencyCheck do
  def consistency_diagnostics(source)
    AsciiChem::Linter.run(AsciiChem.parse(source))
                     .select { |d| d.message.match?(/match molecule/) }
  end

  let(:aspirin_inchi) do
    "InChI=1S/C9H8O4/c1-6(10)13-8-5-3-2-4-7(8)9(11)12/h2-5H,1H3,(H,11,12)"
  end

  it "auto-registers as :identifier_consistency" do
    expect(AsciiChem::Linter::Registry.names).to include(:identifier_consistency)
  end

  it "passes when the InChI formula matches the molecule" do
    source = "C_9H_8O_4 @inchi(\"#{aspirin_inchi}\")"
    expect(consistency_diagnostics(source)).to be_empty
  end

  it "flags an InChI formula that contradicts the molecule" do
    source = "H_2O @inchi(\"#{aspirin_inchi}\")"
    diags = consistency_diagnostics(source)
    expect(diags.length).to eq(1)
    expect(diags.first.severity).to eq(:error)
    expect(diags.first.message).to include("C9H8O4")
    expect(diags.first.message).to match(/H: 2 vs 8/)
  end

  it "ignores the stoichiometric coefficient (identifiers describe the substance)" do
    source = '2H_2O @inchi("InChI=1S/H2O/h1H2")'
    expect(consistency_diagnostics(source)).to be_empty
  end

  it "skips unanalysable InChI values (the format check reports those)" do
    expect(consistency_diagnostics('H_2O @inchi("garbage")')).to be_empty
  end

  it "warns when SMILES carries an element absent from the molecule" do
    diags = consistency_diagnostics('H_2O @smiles("CCO")')
    expect(diags.length).to eq(1)
    expect(diags.first.severity).to eq(:warning)
    expect(diags.first.message).to match(/unexpected \["C"\]/)
  end

  it "warns when the molecule has a non-hydrogen element absent from SMILES" do
    diags = consistency_diagnostics('C_2H_6O @smiles("CC")')
    expect(diags.length).to eq(1)
    expect(diags.first.message).to match(/missing \["O"\]/)
  end

  it "tolerates implicit hydrogens in SMILES" do
    expect(consistency_diagnostics('C_2H_6O @smiles("CCO")')).to be_empty
  end

  it "tolerates aromatic SMILES on the matching molecule" do
    expect(consistency_diagnostics('C_9H_8O_4 @smiles("CC(=O)Oc1ccccc1C(=O)O")')).to be_empty
  end
end
