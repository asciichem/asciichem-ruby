# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Linter::IdentifierFormatCheck do
  def identifier_diagnostics(source)
    AsciiChem::Linter.run(AsciiChem.parse(source))
                     .select { |d| d.message.match?(/CAS|InChI|SMILES|identifier/) }
                     # IdentityCrossCheck also fires on @inchi-annotated
                     # molecules (its no-engine guidance); isolate the
                     # format check's own diagnostics.
                     .reject { |d| d.message.include?("identity cross-check") }
  end

  it "auto-registers as :identifier_format" do
    expect(AsciiChem::Linter::Registry.names).to include(:identifier_format)
  end

  it "passes a valid CAS RN" do
    expect(identifier_diagnostics('H_2O @cas("7732-18-5")')).to be_empty
  end

  it "flags a malformed CAS RN" do
    diags = identifier_diagnostics('H_2O @cas("50782")')
    expect(diags.length).to eq(1)
    expect(diags.first.severity).to eq(:error)
    expect(diags.first.message).to match(/not in DDDDDDD-DD-D form/)
    expect(diags.first.message).to include("cas identifier on H2O")
  end

  it "flags a CAS RN with a wrong check digit" do
    diags = identifier_diagnostics('C @cas("74-82-9")')
    expect(diags.length).to eq(1)
    expect(diags.first.message).to match(/check digit 9 does not match weighted sum \(8\)/)
  end

  it "flags a malformed InChI" do
    diags = identifier_diagnostics('C @inchi("InChI=1S/Cx4")')
    expect(diags.length).to eq(1)
    expect(diags.first.message).to match(/unknown element symbol "Cx"/)
  end

  it "flags structurally broken SMILES" do
    diags = identifier_diagnostics('C @smiles("C(C")')
    expect(diags.length).to eq(1)
    expect(diags.first.message).to match(/parentheses are not balanced/)
  end

  it "skips conventions without an offline validator" do
    expect(identifier_diagnostics('C @iupac("methane")')).to be_empty
  end

  it "checks every identifier on a molecule with chained annotations" do
    diags = identifier_diagnostics('C @cas("74-82-9")@inchi("InChI=1S/Cx4")')
    expect(diags.length).to eq(2)
    expect(diags.map(&:message).join).to match(/check digit/).and match(/unknown element/)
  end
end
