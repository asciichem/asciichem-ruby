# frozen_string_literal: true

require 'moxml'

module AsciiChem
  module Cml
    # Carries the molecule-level phase (`NaCl(aq)` aqueous,
    # `H_2O(l)` liquid, `Fe(s)` solid, `CO_2(g)` gas — grammar
    # v0.11.0) through CML round-trip. The canonical model has no
    # phase slot, so the phase rides the aci: namespace as an
    # attribute on the owning `<molecule>`:
    #
    #   <molecule id="m1" aci:phase="aqueous">
    #
    # The same posture the other molecule-level extensions use until
    # the wire schema grows the field. Molecules without a state are
    # untouched (clean CML for plain chemistry).
    module PhaseExtensions
      # -- AsciiChem -> CML ------------------------------------------

      # `{ molecule_id => :aqueous | :liquid | :solid | :gas }` for
      # phase-bearing molecules, in canonical walk order (ids m1, m2,
      # ...).
      def self.collect(formula)
        prefix = ID_PREFIXES.fetch(:molecule)
        map = {}
        each_molecule_in_canonical_order(formula).each_with_index do |molecule, idx|
          map["#{prefix}#{idx + 1}"] = molecule.phase if molecule.phase
        end
        map
      end

      def self.inject(xml, phase_map)
        return xml if phase_map.empty?

        doc = Moxml.parse(xml)
        root = doc.root
        Extensions.ensure_namespace(root)
        phase_map.each do |molecule_id, phase|
          molecule_el = root.at_xpath("//cml:molecule[@id='#{molecule_id}']",
                                      cml: Extensions::CML_NS)
          next unless molecule_el

          molecule_el["#{Extensions::PREFIX}:phase"] = phase.to_s
        end
        doc.to_xml
      end

      # -- CML -> AsciiChem ------------------------------------------

      # `{ molecule_id => :aqueous | :liquid | :solid | :gas }` from
      # aci:phase attributes. Unknown values are ignored (forward compatibility:
      # a later vocabulary joins as data without breaking older
      # readers).
      def self.extract(xml)
        doc = Moxml.parse(xml)
        map = {}
        doc.xpath('//cml:molecule', cml: Extensions::CML_NS).each do |mol_el|
          raw = mol_el["#{Extensions::PREFIX}:phase"]
          next unless raw

          phase = raw.to_sym
          next unless Model::Molecule::PHASES.value?(phase)

          mol_el['id']&.then { |id| map[id] = phase }
        end
        map
      end

      # Walks the rebuilt formula in canonical order — the same walk
      # collect used — so m{n} maps to the n-th molecule.
      def self.restore(formula, phase_map)
        return formula if phase_map.empty?

        prefix = ID_PREFIXES.fetch(:molecule)
        each_molecule_in_canonical_order(formula).each_with_index do |molecule, idx|
          molecule.phase = phase_map["#{prefix}#{idx + 1}"]
        end
        formula
      end

      # Same flattening order GroupExtensions documents: top-level
      # molecules, then reaction reactants/products, then cascade
      # steps — the order ToCanonical walked and assigned m-ids.
      def self.each_molecule_in_canonical_order(formula, &block)
        return to_enum(:each_molecule_in_canonical_order, formula) unless block

        formula.nodes.each do |node|
          case node
          when AsciiChem::Model::Molecule
            yield node
          when AsciiChem::Model::Reaction
            node.reactants.each(&block)
            node.products.each(&block)
          when AsciiChem::Model::ReactionCascade
            node.steps.each do |step|
              step.reactants.each(&block)
              step.products.each(&block)
            end
          end
        end
      end
    end
  end
end
