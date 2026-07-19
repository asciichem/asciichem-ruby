#!/usr/bin/env ruby
# frozen_string_literal: true

# Performance benchmarks for AsciiChem. Uses benchmark-ips if available;
# falls back to stdlib Benchmark otherwise.
#
# Run manually:
#   bundle exec ruby benchmarks/benchmark.rb
#
# CI does not run benchmarks. They are a manual check for regressions
# during development.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "asciichem"
require "benchmark"

begin
  require "benchmark/ips"
  HAVE_IPS = true
rescue LoadError
  HAVE_IPS = false
end

CASES = {
  "simple atom (H)" => "H",
  "simple molecule (H_2O)" => "H_2O",
  "isotope (^14C)" => "^14C",
  "charged atom (Ca^2+)" => "Ca^2+",
  "group (Ca(OH)_2)" => "Ca(OH)_2",
  "reaction (2H_2 + O_2 -> 2H_2O)" => "2H_2 + O_2 -> 2H_2O",
  "equilibrium (Haber)" => "N_2 + 3H_2 <=>[Fe][400°C] 2NH_3",
  "cascade (A -> B -> C -> D)" => "A -> B -> C -> D",
  "electron config" => "1s^2 2s^2 2p^6 3s^2 3p^6 4s^2 3d^10",
  "bonds (H-O-H=O#H)" => "H-O-H=O#H",
  "crystal (NaCl)" => "crystal[NaCl](a=5.64,b=5.64,c=5.64,alpha=90,beta=90,gamma=90,sg=Fm-3m){Na@f(0,0,0) Cl@f(0.5,0.5,0.5)}",
  "spectrum (NMR)" => %(spectrum[nmr](type=1H,solvent=CDCl3){1.2: 3H s "CH3"}),
  "calculation (DFT)" => "calc(b3lyp/6-31G*){energy: -234.5 Hartree}",
  "zmatrix (methane)" => "zmatrix{\n  C1\n  H2 C1 1.09\n  H3 C1 1.09 H2 109.5\n  H4 C1 1.09 H2 109.5 H3 120.0\n}",
  "mechanism (2-step)" => "mechanism{\n  step1: A + B -> C\n  step2: C -> D + E\n  spectator: Na+\n}"
}.freeze

def parse_bench(label, source)
  if HAVE_IPS
    Benchmark.ips do |x|
      x.config(time: 2, warmup: 1)
      x.report("#{label} parse") { AsciiChem.parse(source) }
    end
  else
    Benchmark.realtime { 100.times { AsciiChem.parse(source) } }
      .then { |t| printf "  %-40s parse: %6.2f ms/call\n", label, t * 10 }
  end
end

def roundtrip_bench(label, source)
  if HAVE_IPS
    Benchmark.ips do |x|
      x.config(time: 2, warmup: 1)
      x.report("#{label} round-trip") do
        AsciiChem.parse(source).to_text
      end
    end
  else
    Benchmark.realtime { 100.times { AsciiChem.parse(source).to_text } }
      .then { |t| printf "  %-40s round-trip: %6.2f ms/call\n", label, t * 10 }
  end
end

def mathml_bench(label, source)
  formula = AsciiChem.parse(source)
  if HAVE_IPS
    Benchmark.ips do |x|
      x.config(time: 2, warmup: 1)
      x.report("#{label} to_mathml") { formula.to_mathml }
    end
  else
    Benchmark.realtime { 100.times { formula.to_mathml } }
      .then { |t| printf "  %-40s to_mathml: %6.2f ms/call\n", label, t * 10 }
  end
end

def cml_bench(label, source)
  formula = AsciiChem.parse(source)
  if HAVE_IPS
    Benchmark.ips do |x|
      x.config(time: 2, warmup: 1)
      x.report("#{label} to_cml") { formula.to_cml }
      x.report("#{label} cml parse") { AsciiChem::Cml.parse(formula.to_cml) }
    end
  else
    Benchmark.realtime { 100.times { formula.to_cml } }
      .then { |t| printf "  %-40s to_cml: %6.2f ms/call\n", label, t * 10 }
  end
end

puts "AsciiChem #{AsciiChem::VERSION}  (benchmark-ips: #{HAVE_IPS})"
puts

puts "== parse =="
CASES.each { |label, src| parse_bench(label, src) }
puts

puts "== round-trip (parse + to_text) =="
CASES.each { |label, src| roundtrip_bench(label, src) }
puts

puts "== to_mathml =="
CASES.each { |label, src| mathml_bench(label, src) }
puts

puts "== CML (to_cml + parse) =="
CASES.first(5).each { |label, src| cml_bench(label, src) }
