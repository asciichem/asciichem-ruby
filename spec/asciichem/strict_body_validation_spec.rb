# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Strict body validation for beyond-formulas constructs" do
  [
    ["mechanism", "mechanism{\nstep1: A -> B\n}", "valid multi-entry"],
    ["mechanism", "mechanism{step1: A}", "valid single entry"],
    ["mechanism", "mechanism{\nbad_entry_no_colon\n}", "entry without colon"],
    ["spectrum", "spectrum[x](){1.2: 3H}", "valid peak"],
    ["spectrum", "spectrum[x](){bad_peak}", "peak without colon"],
    ["calculation", "calc(m){energy: -1}", "valid property"],
    ["calculation", "calc(m){no_colon_here}", "property without colon"],
  ].each do |construct, src, desc|
    it "#{construct}: #{desc}" do
      if desc.include?("without colon")
        expect { AsciiChem.parse(src) }.to raise_error(AsciiChem::ParseError, /missing ':' separator/)
      else
        expect { AsciiChem.parse(src) }.not_to raise_error
      end
    end
  end
end
