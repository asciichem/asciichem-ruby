# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Transform::CascadeBuilder do
  # The canonicaliser accepts every tree shape parsing engines
  # deliver: array-of-segment-hashes, hash-with-array-values (parslet),
  # and hash-with-scalar-values (parsanol's transform — the shape that
  # motivated the explicit wrap; `Array(hash)` would enumerate the
  # arrow hash into key/value pairs instead of wrapping it).

  let(:first) { AsciiChem.parse("A -> B").nodes.first }
  let(:product) { AsciiChem.parse("C").nodes.first }

  def build_with(arrow:, products:)
    described_class.new(
      { first: first, arrow: arrow, products: products }
    ).build
  end

  it "builds from scalar tail values (parsanol transform shape)" do
    cascade = build_with(arrow: { kind: "->", above: nil, below: nil }, products: product)
    expect(cascade.steps.length).to eq(2)
    expect(cascade.to_text).to eq("A -> B -> C")
  end

  it "builds from array tail values (parslet transform shape)" do
    cascade = build_with(
      arrow: [{ kind: "->", above: nil, below: nil }],
      products: [product]
    )
    expect(cascade.steps.length).to eq(2)
    expect(cascade.to_text).to eq("A -> B -> C")
  end

  it "carries conditions through scalar tail arrows" do
    cascade = build_with(
      arrow: { kind: "<=>", above: nil, below: "400C" },
      products: product
    )
    expect(cascade.steps.last.conditions.below).to eq("400C")
    expect(cascade.to_text).to eq("A -> B <=>[400C] C")
  end
end
