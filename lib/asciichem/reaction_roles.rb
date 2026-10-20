# frozen_string_literal: true

module AsciiChem
  # Reaction-role derivation (TODO.v2/13 item 4): explicit typed
  # entries (`[cat: Pd]`, `[solv: THF]`, `[reag: NaH]`) win; free-text
  # entries fall back to the writing convention — catalysts and light
  # reagents ABOVE the arrow, solvents BELOW — classified by hint
  # matching. Pure functions, nothing mutates.
  module ReactionRoles
    CATALYST_HINTS = %w[pd pt ni fe catalyst cat].freeze
    SOLVENT_HINTS = %w[h2o thf dmso dmf etoh meoh toluene solvent sol water].freeze

    module_function

    # Returns { catalysts: [strings], solvents: [strings],
    # reagents: [strings], other_below: [strings] }. Explicit roles
    # route to their bucket regardless of side; free-text entries are
    # split and classified by the above/below convention.
    def roles_for(reaction)
      roles = { catalysts: [], reagents: [], solvents: [], other_below: [] }
      entries = reaction.conditions ? reaction.conditions.entries : []
      entries.each { |entry| assign(entry, roles) }
      roles
    end

    def assign(entry, roles)
      case entry.role
      when :catalyst then roles[:catalysts] << entry.value
      when :solvent then roles[:solvents] << entry.value
      when :reagent then roles[:reagents] << entry.value
      else classify_free(entry, roles)
      end
    end

    def classify_free(entry, roles)
      split_entries(entry.value).each do |value|
        roles[bucket(value, entry.side)] << value
      end
    end

    def bucket(value, side)
      if matches?(value, CATALYST_HINTS) then :catalysts
      elsif matches?(value, SOLVENT_HINTS) then :solvents
      elsif side == :above then :reagents
      else :other_below
      end
    end

    def split_entries(text)
      return [] if text.nil? || text.strip.empty?

      text.strip.split(/[;,\s]+/).reject(&:empty?)
    end

    def matches?(entry, hints)
      hints.any? { |hint| entry.to_s.downcase.include?(hint) }
    end
  end
end
