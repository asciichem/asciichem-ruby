# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Linter::ChargeBalanceCheck do
  def errors_for(source)
    AsciiChem::Linter.run(AsciiChem.parse(source))
      .select { |d| d.severity == :error }
      .select { |d| d.message.include?("charge") }
  end

  it "passes for a charge-balanced reaction" do
    expect(errors_for("H^+ + OH^- -> H_2O")).to be_empty
  end

  it "passes for a reaction with no charges" do
    expect(errors_for("H_2 + O_2 -> H_2O")).to be_empty
  end

  it "flags a charge-imbalanced reaction" do
    diags = errors_for("H^+ + OH^- -> H_2O^+")
    expect(diags.length).to eq(1)
    expect(diags.first.message).to match(/reactants 0 vs products \+1/)
  end

  it "flags a charge-imbalanced reaction with negative imbalance" do
    diags = errors_for("Na^+ + Cl^- -> NaCl^-")
    expect(diags.length).to eq(1)
    expect(diags.first.message).to match(/reactants 0 vs products -1/)
  end

  it "handles divalent charges (Ca^2+ + 2Cl^- -> CaCl_2)" do
    expect(errors_for("Ca^2+ + 2Cl^- -> CaCl_2")).to be_empty
  end

  it "handles coefficients on both sides" do
    expect(errors_for("2Na^+ + SO_4^2- -> Na_2SO_4")).to be_empty
  end

  it "flags imbalanced divalent charges" do
    diags = errors_for("Ca^2+ + Cl^- -> CaCl")
    expect(diags.length).to eq(1)
    expect(diags.first.message).to match(/reactants \+1 vs products 0/)
  end

  it "auto-registers as :charge_balance" do
    expect(AsciiChem::Linter::Registry.names).to include(:charge_balance)
  end

  it "ignores groups with no atoms (graceful)" do
    expect(errors_for("H^+ -> H^+")).to be_empty
  end
end
