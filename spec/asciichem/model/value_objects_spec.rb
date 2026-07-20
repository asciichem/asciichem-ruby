# frozen_string_literal: true

require "spec_helper"

# Verifies the typed value objects (Structs) on model classes. These
# carry fields that previously lived as Hashes with magic symbol keys.
RSpec.describe "Value objects on Model classes" do
  describe AsciiChem::Model::Spectrum::Peak do
    it "supports keyword-init construction" do
      peak = described_class.new(position: "1.2", intensity: "3H",
                                 multiplicity: "s", assignment: "CH3")
      expect(peak.position).to eq("1.2")
      expect(peak.intensity).to eq("3H")
      expect(peak.multiplicity).to eq("s")
      expect(peak.assignment).to eq("CH3")
    end

    it "compares by value" do
      a = described_class.new(position: "1.2", intensity: "3H")
      b = described_class.new(position: "1.2", intensity: "3H")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "omits unset fields (nil by default)" do
      peak = described_class.new(position: "1.2")
      expect(peak.intensity).to be_nil
      expect(peak.multiplicity).to be_nil
      expect(peak.assignment).to be_nil
    end
  end

  describe AsciiChem::Model::Calculation::Property do
    it "supports title/value/units" do
      prop = described_class.new(title: "energy", value: "-234.5",
                                 units: "Hartree")
      expect(prop.title).to eq("energy")
      expect(prop.value).to eq("-234.5")
      expect(prop.units).to eq("Hartree")
    end
  end

  describe AsciiChem::Model::Mechanism::Step do
    it "supports label/reaction" do
      step = described_class.new(label: "step1", reaction: "A -> B")
      expect(step.label).to eq("step1")
      expect(step.reaction).to eq("A -> B")
    end
  end

  describe AsciiChem::Model::Molecule::Meta do
    it "supports name/content" do
      meta = described_class.new(name: "inchi", content: "InChI=...")
      expect(meta.name).to eq("inchi")
      expect(meta.content).to eq("InChI=...")
    end
  end

  describe AsciiChem::Model::Molecule::Property do
    it "supports title/value/units/dict_ref/convention" do
      prop = described_class.new(title: "mw", value: "18.015",
                                 units: "g/mol", dict_ref: "ci:mw",
                                 convention: "ci")
      expect(prop.title).to eq("mw")
      expect(prop.dict_ref).to eq("ci:mw")
    end
  end

  describe AsciiChem::Model::Molecule::Label do
    it "supports value/dict_ref/convention" do
      label = described_class.new(value: "solvent", convention: "aci:role")
      expect(label.value).to eq("solvent")
      expect(label.convention).to eq("aci:role")
    end
  end

  describe AsciiChem::Model::Molecule::Formula do
    it "supports concise/inline/count" do
      formula = described_class.new(concise: "H 2 O 1", count: "1")
      expect(formula.concise).to eq("H 2 O 1")
      expect(formula.count).to eq("1")
    end
  end

  describe AsciiChem::Model::OpaqueCml do
    it "supports element_name/raw_xml" do
      node = described_class.new(element_name: "table",
                                 raw_xml: "<table/>")
      expect(node.element_name).to eq("table")
      expect(node.raw_xml).to eq("<table/>")
    end

    it "compares by value" do
      a = described_class.new(element_name: "x", raw_xml: "<x/>")
      b = described_class.new(element_name: "x", raw_xml: "<x/>")
      expect(a).to eq(b)
    end
  end

  describe AsciiChem::Model::Crystal do
    describe ".CELL_LABELS" do
      it "is frozen (single source of truth, not runtime-mutable)" do
        expect(described_class::CELL_LABELS).to be_frozen
      end

      it "covers all four output formats" do
        expect(described_class::CELL_LABELS.keys)
          .to contain_exactly(:text, :mathml, :html, :latex)
      end

      it "uses Greek letters for angles in MathML" do
        labels = described_class::CELL_LABELS[:mathml]
        expect(labels[:alpha]).to eq("α")
        expect(labels[:beta]).to eq("β")
        expect(labels[:gamma]).to eq("γ")
      end

      it "uses \\alpha style for LaTeX" do
        labels = described_class::CELL_LABELS[:latex]
        expect(labels[:alpha]).to eq("\\alpha")
      end
    end

    describe "#each_cell_param" do
      it "yields set parameters in canonical order" do
        crystal = described_class.new(a: 1, gamma: 90, b: 2)
        result = []
        crystal.each_cell_param(:text) { |label, value| result << [label, value] }
        expect(result).to eq([["a", 1], ["b", 2], ["gamma", 90]])
      end

      it "uses the format-specific labels" do
        crystal = described_class.new(alpha: 90)
        result = []
        crystal.each_cell_param(:mathml) { |label, _value| result << label }
        expect(result).to eq(["α"])
      end

      it "yields nothing when no cell params are set" do
        crystal = described_class.new(spacegroup: "Fm-3m")
        result = []
        crystal.each_cell_param(:text) { |label, value| result << [label, value] }
        expect(result).to be_empty
      end
    end
  end

  describe AsciiChem::Model::Bond do
    describe ".CML_ORDER_CODES" do
      it "is frozen" do
        expect(described_class::CML_ORDER_CODES).to be_frozen
      end

      it "covers all 8 bond kinds" do
        expect(described_class::CML_ORDER_CODES.keys)
          .to contain_exactly(:single, :double, :triple, :quadruple,
                              :wedge, :hash, :dative, :wavy)
      end

      it "uses standard CML single-letter codes" do
        codes = described_class::CML_ORDER_CODES
        expect(codes[:single]).to eq("S")
        expect(codes[:double]).to eq("D")
        expect(codes[:triple]).to eq("T")
        expect(codes[:wedge]).to eq("W")
      end
    end

    describe ".KIND_BY_CML_ORDER" do
      it "is the inverse of CML_ORDER_CODES" do
        expect(described_class::KIND_BY_CML_ORDER)
          .to eq(described_class::CML_ORDER_CODES.invert)
      end
    end

    describe ".CML_STEREO_CODES" do
      it "covers only wedge and hash (only stereo bonds)" do
        expect(described_class::CML_STEREO_CODES.keys)
          .to contain_exactly(:wedge, :hash)
      end
    end

    describe "#cml_order_code" do
      it "returns the CML code for the bond kind" do
        expect(AsciiChem::Model::Bond.new(kind: :double).cml_order_code).to eq("D")
        expect(AsciiChem::Model::Bond.new(kind: :wedge).cml_order_code).to eq("W")
      end

      it "defaults to S for unknown kinds" do
        bond = AsciiChem::Model::Bond.new(kind: :custom)
        expect(bond.cml_order_code).to eq("S")
      end
    end

    describe "#cml_stereo_code" do
      it "returns the stereo code for wedge/hash" do
        expect(AsciiChem::Model::Bond.new(kind: :wedge).cml_stereo_code).to eq("W")
        expect(AsciiChem::Model::Bond.new(kind: :hash).cml_stereo_code).to eq("H")
      end

      it "raises KeyError for non-stereo bonds" do
        expect { AsciiChem::Model::Bond.new(kind: :single).cml_stereo_code }
          .to raise_error(KeyError)
      end
    end
  end

  describe AsciiChem::Model::Group do
    describe ".BRACKETS" do
      it "is frozen" do
        expect(described_class::BRACKETS).to be_frozen
      end

      it "covers paren, square, brace with open/close/wire attrs" do
        expect(described_class::BRACKETS.keys).to contain_exactly(:paren, :square, :brace)
        expect(described_class::BRACKETS[:paren]).to eq(open: "(", close: ")", wire: "paren")
      end
    end

    describe ".BRACKET_BY_WIRE" do
      it "maps wire names back to bracket kinds" do
        expect(described_class::BRACKET_BY_WIRE["paren"]).to eq(:paren)
        expect(described_class::BRACKET_BY_WIRE["brace"]).to eq(:brace)
      end
    end

    describe "#wire_bracket" do
      it "returns the wire name for the bracket kind" do
        group = AsciiChem::Model::Group.new(nodes: [], bracket: :brace)
        expect(group.wire_bracket).to eq("brace")
      end
    end
  end

  describe AsciiChem::Model::Molecule do
    describe "#atom_count" do
      it "counts a single atom" do
        mol = AsciiChem.parse("H").nodes.first
        expect(mol.atom_count).to eq(1)
      end

      it "counts atoms with subscripts" do
        mol = AsciiChem.parse("H_2O").nodes.first
        expect(mol.atom_count).to eq(3)
      end

      it "counts atoms in groups" do
        mol = AsciiChem.parse("(OH)_2").nodes.first
        expect(mol.atom_count).to eq(4)
      end

      it "counts atoms in groups with leading molecule" do
        mol = AsciiChem.parse("Ca(OH)_2").nodes.first
        expect(mol.atom_count).to eq(5)
      end

      it "counts atoms in nested groups" do
        mol = AsciiChem.parse("((H)_2O)_3").nodes.first
        expect(mol.atom_count).to eq(9)
      end

      it "returns 0 for an empty molecule" do
        mol = AsciiChem::Model::Molecule.new(nodes: [])
        expect(mol.atom_count).to eq(0)
      end
    end
  end

  describe AsciiChem::Model::Reaction do
    describe ".ARROW_BY_WIRE" do
      it "maps each wire name back to its arrow kind" do
        expect(described_class::ARROW_BY_WIRE["forward"]).to eq(:forward)
        expect(described_class::ARROW_BY_WIRE["reverse"]).to eq(:reverse)
        expect(described_class::ARROW_BY_WIRE["equilibrium"]).to eq(:equilibrium)
        expect(described_class::ARROW_BY_WIRE["resonance"]).to eq(:resonance)
      end

      it "is the inverse of the ARROWS hash's wire field" do
        inverse = described_class::ARROWS.to_h { |k, v| [v[:wire], k] }
        expect(described_class::ARROW_BY_WIRE).to eq(inverse)
      end
    end

    describe "#arrow_wire" do
      it "returns the wire name for forward reactions" do
        reaction = AsciiChem.parse("A -> B").nodes.first
        expect(reaction.arrow_wire).to eq("forward")
      end

      it "returns the wire name for equilibrium" do
        reaction = AsciiChem.parse("A <=> B").nodes.first
        expect(reaction.arrow_wire).to eq("equilibrium")
      end

      it "returns the wire name for resonance" do
        reaction = AsciiChem.parse("A <-> B").nodes.first
        expect(reaction.arrow_wire).to eq("resonance")
      end
    end

    describe ".arrow_from_wire" do
      it "returns the matching arrow kind for known wires" do
        expect(described_class.arrow_from_wire("forward")).to eq(:forward)
        expect(described_class.arrow_from_wire("reverse")).to eq(:reverse)
      end

      it "defaults to :forward for unknown wires" do
        expect(described_class.arrow_from_wire("custom")).to eq(:forward)
      end

      it "handles nil wire gracefully" do
        expect(described_class.arrow_from_wire(nil)).to eq(:forward)
      end
    end
  end
end
