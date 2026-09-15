# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Transform::CascadeBuilder do
  # The grammar wraps each cascade leg in a single :segment capture
  # (arrow + products) so every engine arrays the repeat — parsanol
  # merges and OVERWRITES bare repeated sibling captures, silently
  # dropping legs. The canonicaliser consumes the segment shape:
  # { first: <Reaction>, segments: <hash | array-of-hashes> }.

  let(:first) { AsciiChem.parse("A -> B").nodes.first }
  let(:product) { AsciiChem.parse("C").nodes.first }

  def build_with(segment)
    described_class.new({ first: first, segments: segment }).build
  end

  it "builds from a scalar segments value (single subsequent leg)" do
    cascade = build_with({ arrow: { kind: "->", above: nil, below: nil }, products: product })
    expect(cascade.steps.length).to eq(2)
    expect(cascade.to_text).to eq("A -> B -> C")
  end

  it "builds from an array of legs" do
    legs = [
      { arrow: { kind: "->", above: nil, below: nil }, products: AsciiChem.parse("C").nodes.first },
      { arrow: { kind: "->", above: nil, below: nil }, products: AsciiChem.parse("D").nodes.first },
    ]
    cascade = build_with(legs)
    expect(cascade.steps.length).to eq(3)
    expect(cascade.to_text).to eq("A -> B -> C -> D")
  end

  it "carries conditions through leg arrows" do
    cascade = build_with(
      { arrow: { kind: "<=>", above: nil, below: "400C" }, products: product }
    )
    expect(cascade.steps.last.conditions.below).to eq("400C")
    expect(cascade.to_text).to eq("A -> B <=>[400C] C")
  end

  it "parses multi-leg cascades end-to-end under the active engine" do
    expect(AsciiChem.parse("A -> B -> C -> D").to_text).to eq("A -> B -> C -> D")
  end
end
