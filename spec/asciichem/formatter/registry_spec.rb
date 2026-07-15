# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Formatter do
  describe ".[]" do
    it "resolves single-word names" do
      expect(described_class[:mathml]).to eq(AsciiChem::Formatter::Mathml)
      expect(described_class[:text]).to eq(AsciiChem::Formatter::Text)
      expect(described_class[:html]).to eq(AsciiChem::Formatter::Html)
      expect(described_class[:latex]).to eq(AsciiChem::Formatter::Latex)
      expect(described_class[:svg]).to eq(AsciiChem::Formatter::Svg)
    end

    it "resolves snake_cased names by camelising" do
      expect(described_class[:structural_svg]).to eq(AsciiChem::Formatter::StructuralSvg)
    end

    it "accepts strings" do
      expect(described_class["mathml"]).to eq(AsciiChem::Formatter::Mathml)
      expect(described_class["structural_svg"]).to eq(AsciiChem::Formatter::StructuralSvg)
    end

    it "raises FormatError for unknown formatters" do
      expect { described_class[:nonsense] }
        .to raise_error(AsciiChem::FormatError, /unknown formatter :nonsense/)
    end
  end

  describe ".render" do
    it "instantiates the formatter and renders" do
      formula = AsciiChem.parse("H_2O")
      out = described_class.render(:mathml, formula)
      expect(out).to include("<math")
      expect(out).to include("H")
    end

    it "delegates to structural_svg for snake_cased names" do
      formula = AsciiChem.parse("H-O-H")
      out = described_class.render(:structural_svg, formula)
      expect(out).to include("<svg")
    end
  end
end
