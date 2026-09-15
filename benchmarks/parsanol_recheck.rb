# frozen_string_literal: true

# Parsanol re-check (parsanol-ruby 1.3.15, issue-25 thread): runs the
# UNMODIFIED AsciiChem grammar over the Parsanol engine via the
# Parslet compat shim, then (1) gates on the shared corpus, (2) gates
# on the issue-25 EOF repro, (3) measures against the parslet path.
#
# Mode: native by default (PARSOLAN_MODE=native — default routing);
# PARSANOL_MODE=ruby forces the pure-Ruby engine. As of 1.3.15 the
# native backend parses 169/170 corpus accepts + all 51 rejects at
# ~2.3x parslet speed; the single fatal case is embedded-math input,
# which panics the Rust core on the known @next_id collision
# (parsanol-ruby#25) — run that one in :ruby until upstream fixes it.
#
# Run from asciichem-ruby/ with the shim dir prepended:
#   ruby -I /tmp/parsanol_spike -I ../parsanol/parsanol-ruby/lib benchmarks/parsanol_recheck.rb
require "benchmark/ips"
require "asciichem"
require "json"

puts "parsanol #{Parsanol::VERSION} | parslet-compat Parser=#{Parsanol::Parslet::Parser}"
puts "AsciiChem::Grammar superclass: #{AsciiChem::Grammar.superclass}"
puts "mode: #{ENV.fetch("PARSANOL_MODE", "native")}"

if ENV.fetch("PARSANOL_MODE", "native") == "ruby"
  Parsanol::Native.singleton_class.define_method(:available?) { false }
end

# -- 1. Issue-25 repro: repeat-of-maybe at end of input --------------
begin
  formula = AsciiChem.parse("SO_4^2-")
  puts "issue-25 repro SO_4^2-: PARSES -> #{formula.to_text.inspect}"
rescue AsciiChem::ParseError => e
  puts "issue-25 repro SO_4^2-: FAILS -> #{e.message[0, 100]}"
end

# -- 2. Shared-corpus gate --------------------------------------------
# Each case runs in a forked child: a Rust panic aborts the child
# process (unrescuable in Ruby), and the parent reports it by name
# instead of dying.
corpus_dir = File.expand_path("../../asciichem-tests/corpus/fixtures", __dir__)
cases = Dir[File.join(corpus_dir, "*.json")].sort.flat_map { |p| JSON.parse(File.read(p)) }
parser_cases = cases.select { |c| c.key?("input") && !c.key?("lint") && !c.key?("convention") }

def run_in_child
  reader, writer = IO.pipe
  pid = fork do
    reader.close
    Marshal.dump(yield, writer)
  rescue StandardError => e
    Marshal.dump({ exception: e.class.name, message: e.message }, writer)
  ensure
    writer.close
  end
  writer.close
  payload = Marshal.load(reader)
  reader.close
  _, status = Process.waitpid2(pid)
  [payload, status]
end

pass = fail_parse = fail_reject = fail_roundtrip = fatal = 0
parser_cases.each do |fixture|
  input = fixture.fetch("input")
  payload, status = run_in_child do
    formula = AsciiChem.parse(input)
    { text: (formula.to_text if fixture["roundTrip"]) }
  end
  if status.signaled? || !status.success?
    fatal += 1
    puts "  FATAL (child #{status.exitstatus ? "exit #{status.exitstatus}" : "aborted"}): #{fixture["id"]} #{input.inspect}" if fatal <= 8
    next
  end
  if payload.key?(:exception)
    if fixture.fetch("parses")
      fail_parse += 1
      puts "  PARSE FAIL: #{input.inspect} -> #{payload[:message][0, 90]}" if fail_parse <= 8
    else
      pass += 1
    end
    next
  end
  unless fixture.fetch("parses")
    fail_reject += 1
    puts "  SHOULD REJECT: #{input.inspect}" if fail_reject <= 8
    next
  end
  if fixture["roundTrip"] && payload[:text] != input
    fail_roundtrip += 1
    puts "  ROUNDTRIP DIFF: #{input.inspect} -> #{payload[:text].inspect}" if fail_roundtrip <= 5
    next
  end
  pass += 1
end
total = parser_cases.length
puts format("corpus gate: %d/%d ok (parse-fails %d, should-reject %d, roundtrip-diffs %d, fatal %d)",
            pass, total, fail_parse, fail_reject, fail_roundtrip, fatal)

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
