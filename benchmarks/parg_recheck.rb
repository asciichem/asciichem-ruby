# frozen_string_literal: true

# PARG gate + benchmark: AsciiChem::Engine.use(:parg) parses through
# the compiled PARG artifact vendored from asciichem-parg, adapted to
# the shared TransformRules. (1) gates on the shared corpus, forked
# per case so a native crash aborts the child — reported, not fatal;
# (2) gates on capture completeness (a grammar edit leaving a
# trailing literal uncaptured must fail loudly — the runtime itself
# is parslet-strict about end of input); (3) measures against the
# parslet path. The model-equality gate against the reference engine lives in
# spec/asciichem/engine/parg_engine_spec.rb and the full suite green
# under ASCIICHEM_ENGINE=parg is the L2 contract.
#
#   bundle exec ruby benchmarks/parg_recheck.rb
require "benchmark/ips"
require "asciichem"
require "asciichem/engine/parg_engine"

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

# -- 1. Capture-completeness gate --------------------------------------
# Tails the grammar cannot capture must reject, as in the reference.
EOS_CASES = { "A(oh)GARBAGE" => false, "H_2O extra" => false,
              "Ca(OH)_2 junk" => false, "H_2O" => true }.freeze

AsciiChem::Engine.use(:parg)
puts "parg engine | artifact #{AsciiChem::Engine::PargEngine.artifact.version} " \
     "(parsanol #{Parsanol::VERSION})"

eos_fail = 0
EOS_CASES.each do |input, should_parse|
  payload, status = run_in_child do
    begin
      { text: AsciiChem.parse(input).to_text }
    rescue AsciiChem::ParseError => e
      { error: e.message }
    end
  end
  accepted = status.success? && payload.key?(:text)
  next if accepted == should_parse

  eos_fail += 1
  puts "  EOS FAIL: #{input.inspect} accepted=#{accepted} expected=#{should_parse}"
end
puts format("capture-completeness gate: %d/%d ok", EOS_CASES.length - eos_fail, EOS_CASES.length)

# -- 2. Shared-corpus gate ---------------------------------------------
corpus_dir = File.expand_path("../../asciichem-tests/corpus/fixtures", __dir__)
unless File.directory?(corpus_dir)
  warn "corpus not found at #{corpus_dir} — clone asciichem-tests alongside"
  exit 1
end
cases = Dir[File.join(corpus_dir, "*.json")].sort.flat_map { |p| JSON.parse(File.read(p)) }
parser_cases = cases.select { |c| c.key?("input") && !c.key?("lint") && !c.key?("convention") }

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
  "A ->[heat] B ->[cool] C"
].freeze

Benchmark.ips do |x|
  x.report("parg parse x10") { WORKLOAD.each { |s| AsciiChem.parse(s) } }
  x.compare!
end
