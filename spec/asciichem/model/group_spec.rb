# frozen_string_literal: true

require "spec_helper"

RSpec.describe AsciiChem::Model::Group do
  describe "#initialize" do
    it "defaults bracket to :paren" do
      group = described_class.new(nodes: [])
      expect(group.bracket).to eq(:paren)
    end

    it "exposes open/close characters" do
      square = described_class.new(nodes: [], bracket: :square)
      expect(square.open_char).to eq("[")
      expect(square.close_char).to eq("]")
    end
  end

  describe "bracket variants" do
    it "supports :paren, :square, :brace" do
      paren = described_class.new(nodes: [], bracket: :paren)
      square = described_class.new(nodes: [], bracket: :square)
      brace = described_class.new(nodes: [], bracket: :brace)
      expect(paren.open_char).to eq("(")
      expect(square.open_char).to eq("[")
      expect(brace.open_char).to eq("{")
    end
  end
end
