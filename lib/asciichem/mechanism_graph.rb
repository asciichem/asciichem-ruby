# frozen_string_literal: true

module AsciiChem
  # The mechanism step graph (TODO.v2/13 item 4): `mechanism{}` entries
  # stay verbatim (label + reaction text) in the model; this service
  # derives the graph the text implies — each step's reaction parsed
  # with the same grammar, species that appear on both sides of a step
  # recognised as catalysts, and steps linked where a product species
  # of an earlier step is a reactant of a later one.
  #
  # Everything is computed; nothing mutates. A step whose value is not
  # a reaction (prose, "proton transfer") keeps a nil reaction and
  # takes part in no links — never an error.
  module MechanismGraph
    Step = Struct.new(:label, :reaction, :catalysts, keyword_init: true)
    Link = Struct.new(:from, :to, :species, keyword_init: true)
    Graph = Struct.new(:steps, :links, keyword_init: true)

    module_function

    def for(mechanism)
      steps = mechanism.steps.map { |step| graph_step(step) }
      Graph.new(steps: steps, links: links(steps))
    end

    def graph_step(step)
      reaction = parse_reaction(step.reaction)
      sides = sides_of(reaction)
      catalysts = sides ? sides[:reactants].keys & sides[:products].keys : []
      Step.new(label: step.label, reaction: reaction, catalysts: catalysts)
    end

    def links(steps)
      steps.each_with_index.flat_map do |from, i|
        next [] unless from.reaction

        from_products = sides_of(from.reaction)[:products].keys
        steps[(i + 1)..].filter_map { |to| link_between(from, to, from_products) }
      end
    end

    def link_between(from, to, from_products)
      return nil unless to.reaction

      shared = from_products & sides_of(to.reaction)[:reactants].keys
      Link.new(from: from.label, to: to.label, species: shared) unless shared.empty?
    end

    def parse_reaction(text)
      node = AsciiChem.parse(text).nodes.first
      node if node.is_a?(AsciiChem::Model::Reaction) ||
              node.is_a?(AsciiChem::Model::ReactionCascade)
    rescue AsciiChem::ParseError
      nil
    end

    # Coefficient-free species names per side; a cascade's entry side
    # is its head and its exit side is its last step.
    def sides_of(reaction)
      case reaction
      when AsciiChem::Model::Reaction
        reaction.stoichiometry
      when AsciiChem::Model::ReactionCascade
        steps = reaction.steps
        return nil if steps.empty?

        { reactants: steps.first.stoichiometry[:reactants],
          products: steps.last.stoichiometry[:products] }
      end
    end
  end
end
