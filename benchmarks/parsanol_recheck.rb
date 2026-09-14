# frozen_string_literal: true

# Parsanol re-check (parsanol-ruby 1.3.13, post-issue-25): runs the
# UNMODIFIED AsciiChem grammar over the Parsanol engine via the
# Parslet compat shim, then (1) gates on the shared corpus, (2) gates
# on the issue-25 EOF repro, (3) measures against the parslet path.
#
# Native mode cannot serialize this grammar today (two upstream bugs:
# native.rb never loads native/dynamic; Dynamic.register never
# increments @next_id so the second callback panics the Rust core —
# parsanol-ruby#25). The measurement therefore forces :ruby, the
# only working mode for full parslet grammars via the shim.
#
# Run from asciichem-ruby/:
#   ruby -I /tmp/parsanol_spike -I ../parsanol/parsanol-ruby/lib benchmarks/parsanol_recheck.rb
require "benchmark/ips"
require "asciichem"
require "json"

Parsanol::Native.singleton_class.define_method(:available?) { false } # spike: force :ruby

puts "parsanol #{Parsanol::VERSION} | parslet-compat Parser=#{Parsanol::Parslet::Parser}"
puts "AsciiChem::Grammar superclass: #{AsciiChem::Grammar.superclass}"

# -- 1. Issue-25 repro: repeat-of-maybe at end of input --------------
begin
  formula = AsciiChem.parse("SO_4^2-")
  puts "issue-25 repro SO_4^2-: PARSES -> #{formula.to_text.inspect}"
rescue AsciiChem::ParseError => e
  puts "issue-25 repro SO_4^2-: FAILS -> #{e.message[0, 100]}"
end

# -- 2. Shared-corpus gate --------------------------------------------
corpus_dir = File.expand_path("../../asciichem-tests/corpus/fixtures", __dir__)
cases = Dir[File.join(corpus_dir, "*.json")].sort.flat_map { |p| JSON.parse(File.read(p)) }
parser_cases = cases.select { |c| c.key?("input") && !c.key?("lint") && !c.key?("convention") }

pass = fail_parse = fail_reject = fail_roundtrip = 0
parser_cases.each do |fixture|
  input = fixture.fetch("input")
  if fixture.fetch("parses")
    begin
      formula = AsciiChem.parse(input)
      if fixture["roundTrip"] && formula.to_text != input
        fail_roundtrip += 1
        puts "  ROUNDTRIP DIFF: #{input.inspect} -> #{formula.to_text.inspect}" if fail_roundtrip <= 5
      end
      pass += 1
    rescue AsciiChem::ParseError, Parslet::ParseFailed => e
      fail_parse += 1
      puts "  PARSE FAIL: #{input.inspect} -> #{e.message[0, 90]}" if fail_parse <= 8
    end
  else
    begin
      AsciiChem.parse(input)
      fail_reject += 1
      puts "  SHOULD REJECT: #{input.inspect}" if fail_reject <= 8
    rescue AsciiChem::ParseError, Parslet::ParseFailed
      pass += 1
    end
  end
end
total = parser_cases.length
puts format("corpus gate: %d/%d ok (parse-fails %d, should-reject %d, roundtrip-diffs %d)",
            pass, total, fail_parse, fail_reject, fail_roundtrip)

# -- 3. Performance ----------------------------------------------------
WORKLOAD = [
  "H_2O", "Ca^2+", "SO_4^2-", "(R)-CH_3CH(OH)COOH",
  "2H_2 + O_2 -> 2H_2O", "N_2 + 3H_2 <=>[Fe][400C] 2NH_3",
  "C1-C-C-C-C-C1", "CH_3-CH_2-OH",
  '^14C @name("carbon-14") @cas("14104-86-4")',
  "A ->[heat] B ->[cool] C",
].freeze

Benchmark.ips do |x|
  x.report("parsanol parse x10") { WORKLOAD.each { |s| AsciiChem.parse(s) } }
  x.compare!
end
