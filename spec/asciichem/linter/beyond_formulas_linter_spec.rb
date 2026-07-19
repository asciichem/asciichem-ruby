# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Linter do
  def lint(source)
    described_class.run(AsciiChem.parse(source))
  end

  def errors_for(source)
    lint(source).select { |d| d.severity == :error }
  end

  def warnings_for(source)
    lint(source).select { |d| d.severity == :warning }
  end

  describe "CrystalSanityCheck" do
    it "passes for a well-formed crystal" do
      expect(errors_for("crystal[NaCl](a=5.64,b=5.64,c=5.64,sg=Fm-3m){Na@f(0,0,0)}")).to be_empty
    end

    it "flags non-positive cell length a" do
      expect(errors_for("crystal[x](a=0,b=1,c=1){Na@f(0,0,0)}"))
        .to include(an_object_having_attributes(message: /Crystal a must be positive/))
    end

    it "flags negative cell length" do
      expect(errors_for("crystal[x](a=-1,b=1,c=1){Na@f(0,0,0)}"))
        .to include(an_object_having_attributes(message: /Crystal a must be positive/))
    end

    it "flags out-of-range angle" do
      expect(errors_for("crystal[x](a=1,alpha=200){Na@f(0,0,0)}"))
        .to include(an_object_having_attributes(message: /Crystal alpha must be in \(0, 180\]/))
    end

    it "warns on fractional coordinate outside [0, 1)" do
      expect(warnings_for("crystal[x](a=1){Na@f(1.5,0,0)}"))
        .to include(an_object_having_attributes(message: /outside \[0, 1\)/))
    end

    it "skips missing values (partial crystal description)" do
      expect(errors_for("crystal[x](a=1){Na@f(0,0,0)}")).to be_empty
    end
  end

  describe "ZMatrixReferenceCheck" do
    it "passes when all references appear in earlier rows" do
      src = "zmatrix{\n  C1\n  H2 C1 1.09\n  H3 C1 1.09 H2 109.5\n}"
      expect(errors_for(src)).to be_empty
    end

    it "flags forward references" do
      src = "zmatrix{\n  H1 C2 1.09\n  C2\n}"
      expect(errors_for(src))
        .to include(an_object_having_attributes(message: /references "C2" before it is defined/))
    end

    it "flags non-positive distance" do
      src = "zmatrix{\n  C1\n  H2 C1 0\n}"
      expect(errors_for(src))
        .to include(an_object_having_attributes(message: /distance must be positive/))
    end

    it "flags out-of-range angle" do
      src = "zmatrix{\n  C1\n  H2 C1 1.0\n  H3 C1 1.0 H2 200\n}"
      expect(errors_for(src))
        .to include(an_object_having_attributes(message: /angle must be in \(0, 180\]/))
    end

    it "flags out-of-range dihedral" do
      src = "zmatrix{\n  C1\n  H2 C1 1.0\n  H3 C1 1.0 H2 90\n  H4 C1 1.0 H2 90 H3 270\n}"
      expect(errors_for(src))
        .to include(an_object_having_attributes(message: /dihedral must be in \[-180, 180\]/))
    end
  end

  describe "SpectrumPeakCheck" do
    it "passes for a well-formed spectrum" do
      expect(warnings_for(%(spectrum[nmr](type=1H){1.2: 3H s "CH3"}))).to be_empty
    end

    it "warns on negative peak position" do
      expect(warnings_for(%(spectrum[x](){-1.2: 3H})))
        .to include(an_object_having_attributes(message: /peak position .* is negative/))
    end

    it "warns on non-numeric peak position" do
      expect(warnings_for(%(spectrum[x](){abc: 3H})))
        .to include(an_object_having_attributes(message: /not numeric/))
    end

    it "warns on negative intensity" do
      expect(warnings_for(%(spectrum[x](){1.2: -3H})))
        .to include(an_object_having_attributes(message: /intensity .* is negative/))
    end
  end

  describe "registry integration" do
    it "auto-registers CrystalSanityCheck on load" do
      expect(AsciiChem::Linter::Registry.names).to include(:crystal_sanity)
    end

    it "auto-registers ZMatrixReferenceCheck on load" do
      expect(AsciiChem::Linter::Registry.names).to include(:zmatrix_references)
    end

    it "auto-registers SpectrumPeakCheck on load" do
      expect(AsciiChem::Linter::Registry.names).to include(:spectrum_peaks)
    end
  end
end
