# frozen_string_literal: true

# Cross-engine parsing benchmark (shared inputs across Ruby/TS/Python
# so numbers are comparable). Measures full parse (+ Text round-trip
# where cheap) over the canonical workload, reporting ops/sec and
# µs/op. Run: bundle exec ruby benchmarks/engines.rb
require "benchmark/ips"
require "asciichem"

WORKLOAD = [
  "H_2O",
  "Ca^2+",
  "SO_4^2-",
  "(R)-CH_3CH(OH)COOH",
  "2H_2 + O_2 -> 2H_2O",
  "N_2 + 3H_2 <=>[Fe][400C] 2NH_3",
  "C1-C-C-C-C-C1",
  "CH_3-CH_2-OH",
  "^14C @name(\"carbon-14\") @cas(\"14104-86-4\")",
  "A ->[heat] B ->[cool] C",
].freeze

Benchmark.ips do |x|
  x.report("parse x10 (parslet)") do
    WORKLOAD.each { |s| AsciiChem.parse(s) }
  end
  x.report("parse+text x10") do
    WORKLOAD.each { |s| AsciiChem.parse(s).to_text }
  end
  x.compare!
end
