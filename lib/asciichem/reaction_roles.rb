# frozen_string_literal: true

module AsciiChem
  # Reaction-roles perception (TODO.v2/13 item 4, slice A): the
  # chemistry-writing convention puts catalysts and light reagents
  # ABOVE the arrow and solvents/conditions BELOW; the conditions
  # text carries them free-form. This derives structured role hints
  # from that convention — pure functions, nothing mutates. A full
  # roles syntax (structured entries in the grammar) is the later
  # slice.
  module ReactionRoles
    CATALYST_HINTS = %w[pd pt ni fe catalyst cat].freeze
    SOLVENT_HINTS = %w[h2o thf dmso dmf etoh meoh toluene solvent sol water].freeze

    module_function

    # Returns { catalysts: [strings], solvents: [strings],
    # reagents: [strings], other_above: [strings], other_below: [] }
    # — entries split from the conditions text by whitespace, each
    # classified by hint matching against the role vocabularies.
    def roles_for(reaction)
      conditions = reaction.conditions
      above = split_entries(conditions&.above)
      below = split_entries(conditions&.below)
      {
        catalysts: above.select { |e| matches?(e, CATALYST_HINTS) },
        reagents: above.reject { |e| matches?(e, CATALYST_HINTS) },
        solvents: below.select { |e| matches?(e, SOLVENT_HINTS) },
        other_below: below.reject { |e| matches?(e, SOLVENT_HINTS) }
      }
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
