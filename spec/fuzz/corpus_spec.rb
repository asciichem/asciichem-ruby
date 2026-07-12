# frozen_string_literal: true

require "spec_helper"

# Fuzzing corpus: every .asciichem file in spec/fuzz/corpus/ is parsed
# line-by-line. Each line must either parse successfully or raise
# AsciiChem::ParseError. Any other exception class is a bug — the
# grammar should fail loudly, not crash with a NameError or similar.
#
# To extend the corpus, drop a new file in spec/fuzz/corpus/. No test
# code changes needed.
RSpec.describe "parser fuzzing corpus" do
  corpus_dir = File.expand_path("corpus", __dir__)
  files = Dir.glob(File.join(corpus_dir, "*.asciichem")).sort

  (files.size > 0 ? files : []).each do |file|
    name = File.basename(file)

    it "#{name}: every line parses or raises ParseError cleanly" do
      lines = File.read(file).split("\n").reject { |l| l.strip.empty? }
      aggregate_failures do
        lines.each_with_index do |line, idx|
          begin
            AsciiChem.parse(line)
          rescue AsciiChem::ParseError
            # Acceptable: grammar rejected the input cleanly.
          rescue => e
            raise "line #{idx + 1} #{line.inspect} raised #{e.class}: #{e.message[0..200]}"
          end
        end
      end
    end
  end
end
