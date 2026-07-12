# frozen_string_literal: true

module AsciiChem
  # AsciiMath-style Greek word → Unicode symbol table. Used by the
  # grammar and transform to accept typed Greek words (`alpha`, `Delta`,
  # etc.) alongside Unicode characters (`α`, `Δ`).
  #
  # Single source of truth — the stereo grammar, the conditions
  # translator, and any future site that needs Greek letters all read
  # from this hash. Adding a new word is one entry here, not edits
  # scattered across the grammar.
  module Greek
    LOWERCASE = {
      "alpha"   => "α",
      "beta"    => "β",
      "gamma"   => "γ",
      "delta"   => "δ",
      "epsilon" => "ε",
      "zeta"    => "ζ",
      "eta"     => "η",
      "theta"   => "θ",
      "iota"    => "ι",
      "kappa"   => "κ",
      "lambda"  => "λ",
      "mu"      => "μ",
      "nu"      => "ν",
      "xi"      => "ξ",
      "omicron" => "ο",
      "pi"      => "π",
      "rho"     => "ρ",
      "sigma"   => "σ",
      "tau"     => "τ",
      "upsilon" => "υ",
      "phi"     => "φ",
      "chi"     => "χ",
      "psi"     => "ψ",
      "omega"   => "ω"
    }.freeze

    UPPERCASE = {
      "Alpha"   => "Α",
      "Beta"    => "Β",
      "Gamma"   => "Γ",
      "Delta"   => "Δ",
      "Epsilon" => "Ε",
      "Zeta"    => "Ζ",
      "Eta"     => "Η",
      "Theta"   => "Θ",
      "Iota"    => "Ι",
      "Kappa"   => "Κ",
      "Lambda"  => "Λ",
      "Mu"      => "Μ",
      "Nu"      => "Ν",
      "Xi"      => "Ξ",
      "Omicron" => "Ο",
      "Pi"      => "Π",
      "Rho"     => "Ρ",
      "Sigma"   => "Σ",
      "Tau"     => "Τ",
      "Upsilon" => "Υ",
      "Phi"     => "Φ",
      "Chi"     => "Χ",
      "Psi"     => "Ψ",
      "Omega"   => "Ω"
    }.freeze

    ALL = LOWERCASE.merge(UPPERCASE).freeze

    # Translate every Greek word in `text` to its Unicode symbol.
    # Non-word substrings pass through unchanged. Longest-word-first
    # so "eta" doesn't shadow "beta" (which contains "eta" as a suffix).
    def self.translate(text)
      return text if text.nil? || text.empty?

      sorted_words = ALL.keys.sort_by(&:length).reverse
      pattern = /#{sorted_words.map { |w| Regexp.escape(w) }.join("|")}/
      text.gsub(pattern) { |match| ALL.fetch(match) }
    end
  end
end
