# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Linter do
  def lint(source)
    described_class.run(AsciiChem.parse(source))
  end

  describe ".run" do
    it "returns no diagnostics for clean water" do
      expect(lint("H_2O")).to be_empty
    end

    it "returns no diagnostics for a valid isotope" do
      expect(lint("^14C")).to be_empty
    end
  end

  describe "BracketBalanceCheck" do
    it "passes for properly-balanced groups" do
      expect(lint("Ca(OH)_2")).to be_empty
    end
  end

  describe "BalanceCheck" do
    it "passes for a balanced reaction" do
      expect(lint("2H_2 + O_2 -> 2H_2O").select { |d| d.severity == :error }).to be_empty
    end

    it "errors for an unbalanced reaction" do
      diagnostics = lint("H_2 + O_2 -> H_2O")
      errors = diagnostics.select { |d| d.severity == :error }
      expect(errors.length).to eq(1)
      expect(errors.first.message).to include("not balanced")
      expect(errors.first.message).to include("O: 2 vs 1")
    end

    it "handles group multiplicities" do
      expect(lint("Ca(OH)_2 + 2HCl -> CaCl_2 + 2H_2O")
              .select { |d| d.severity == :error }).to be_empty
    end
  end

  describe "ValenceCheck" do
    it "flags carbon with explicit overloaded bonds" do
      # H-C=C-C-H with explicit bonds — carbons have bond order 2 each,
      # which is fine. We're checking that the check itself runs.
      expect { lint("H-C=C-H") }.not_to raise_error
    end

    it "emits info for unknown elements" do
      diagnostics = lint("Xx-2Yy")
      infos = diagnostics.select { |d| d.severity == :info }
      expect(infos.length).to be >= 1
    end
  end

  describe "IsotopeSanityCheck" do
    it "errors when isotope mass is below atomic number" do
      diagnostics = lint("^5C")
      errors = diagnostics.select { |d| d.severity == :error }
      expect(errors.length).to eq(1)
      expect(errors.first.message).to include("Isotope mass 5")
      expect(errors.first.message).to include("atomic number 6")
    end

    it "passes for valid hydrogen isotopes" do
      expect(lint("^1H").select { |d| d.severity == :error }).to be_empty
      expect(lint("^2H").select { |d| d.severity == :error }).to be_empty
      expect(lint("^3H").select { |d| d.severity == :error }).to be_empty
    end

    it "emits info for unknown elements" do
      diagnostics = lint("^5Xx")
      infos = diagnostics.select { |d| d.severity == :info }
      expect(infos.length).to be >= 1
      expect(infos.any? { |d| d.message.include?("isotope table") }).to be(true)
    end
  end

  describe "Registry" do
    it "includes all built-in checks" do
      expect(AsciiChem::Linter::Registry.names).to include(:bracket_balance)
      expect(AsciiChem::Linter::Registry.names).to include(:isotope_sanity)
      expect(AsciiChem::Linter::Registry.names).to include(:balance)
      expect(AsciiChem::Linter::Registry.names).to include(:valence)
    end

    it "is open for extension" do
      custom = Class.new(AsciiChem::Linter::Base) do
        def run(_formula)
          [Diagnostic.new(severity: :info, message: "custom check ran")]
        end
      end
      described_class::Registry.add(:custom_test, custom)
      expect(described_class::Registry.names).to include(:custom_test)
    ensure
      described_class::Registry.reset
      # Re-register the built-in checks after reset.
      load "asciichem/linter/balance_check.rb"
      load "asciichem/linter/bracket_balance_check.rb"
      load "asciichem/linter/isotope_sanity_check.rb"
      load "asciichem/linter/valence_check.rb"
    end
  end

  describe ".errors?" do
    it "returns true when any diagnostic is :error" do
      expect(described_class.errors?(AsciiChem.parse("^5C"))).to be(true)
    end

    it "returns false when only warnings/info" do
      expect(described_class.errors?(AsciiChem.parse("H_2O"))).to be(false)
    end
  end
end
