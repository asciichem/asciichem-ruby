# frozen_string_literal: true

module AsciiChem
  # Converts between the domain semantic model (AsciiChem::Model::*)
  # and the canonical wire form (AsciiChem::Wire::*). This is a
  # model-to-model translation in the spirit of ModelAdapter — every
  # (de)serialisation to/from JSON itself is performed by lutaml-model
  # on the Wire classes; this adapter only routes types and maps
  # fields.
  #
  # Emission (to_wire/to_model_json) covers every wire type.
  # Ingestion (from_wire/from_model_json) currently covers the
  # lossless core set: formula, atom, molecule, group, bond,
  # identifier, name, reaction (+conditions), reaction-cascade,
  # electron-configuration, embedded-math, text. The beyond-formulas
  # nodes (mechanism, spectrum, crystal, zmatrix, calculation) are
  # emission-only until their round-trip acceptance lands in the
  # corpus.
  module WireAdapter
    CORE_INGEST_TYPES = %w[
      formula atom molecule group bond identifier name reaction
      reaction-cascade electron-configuration embedded-math text
    ].freeze

    class << self
      def to_model_json(formula)
        to_wire(formula).to_json
      end

      def from_model_json(json)
        from_wire(wire_tree_from_hash(JSON.parse(json)))
      end

      # domain -> wire ------------------------------------------------

      def to_wire(node)
        case node
        when AsciiChem::Model::Formula then formula_to_wire(node)
        when AsciiChem::Model::Molecule then molecule_to_wire(node)
        when AsciiChem::Model::Group then group_to_wire(node)
        when AsciiChem::Model::Atom then atom_to_wire(node)
        when AsciiChem::Model::Bond then bond_to_wire(node)
        when AsciiChem::Model::Identifier then identifier_to_wire(node)
        when AsciiChem::Model::Name then name_to_wire(node)
        when AsciiChem::Model::Reaction then reaction_to_wire(node)
        when AsciiChem::Model::ReactionCascade then cascade_to_wire(node)
        when AsciiChem::Model::ElectronConfiguration then econfig_to_wire(node)
        when AsciiChem::Model::EmbeddedMath then math_to_wire(node)
        when AsciiChem::Model::Text then text_to_wire(node)
        when AsciiChem::Model::Mechanism then mechanism_to_wire(node)
        when AsciiChem::Model::Spectrum then spectrum_to_wire(node)
        when AsciiChem::Model::Crystal then crystal_to_wire(node)
        when AsciiChem::Model::ZMatrix then zmatrix_to_wire(node)
        when AsciiChem::Model::Calculation then calculation_to_wire(node)
        else raise ArgumentError, "no wire form for #{node.class}"
        end
      end

      # wire -> domain ------------------------------------------------

      def from_wire(wire)
        type = wire.type
        unless CORE_INGEST_TYPES.include?(type)
          raise ArgumentError, "wire ingestion not implemented for #{type.inspect}"
        end

        send(:"#{type.tr('-', '_')}_from_wire", wire)
      end

      # Discriminator-routed tree construction from a parsed JSON
      # hash. Per-node deserialisation stays in lutaml-model; this
      # only routes `type` and re-injects routed children into
      # polymorphic collections (which lutaml deserialises flat).
      def wire_tree_from_hash(hash)
        type = hash.fetch("type") { raise KeyError, "wire node missing type discriminator" }
        klass = AsciiChem::Wire::REGISTRY.fetch(type) do
          raise KeyError, "unknown wire node type #{type.inspect}"
        end

        wire = klass.from_json(JSON.generate(hash))
        case type
        when "formula", "molecule", "group"
          wire.nodes = hash.fetch("nodes", []).map { |child| wire_tree_from_hash(child) }
        when "reaction"
          wire.reactants = hash.fetch("reactants", []).map { |child| wire_tree_from_hash(child) }
          wire.products = hash.fetch("products", []).map { |child| wire_tree_from_hash(child) }
        when "reaction-cascade"
          wire.steps = hash.fetch("steps", []).map { |child| wire_tree_from_hash(child) }
        end
        wire
      end

      private

      def formula_to_wire(node)
        AsciiChem::Wire::Formula.new(type: "formula", nodes: node.nodes.map { |n| to_wire(n) })
      end

      def atom_to_wire(atom)
        AsciiChem::Wire::Atom.new(
          type: "atom",
          element: atom.element,
          isotope: digits_or_nil(atom.isotope), charge: str_or_nil(atom.charge),
          subscript: digits_or_nil(atom.subscript),
          oxidation_state: str_or_nil(atom.oxidation_state),
          lone_pairs: int_or_nil(atom.lone_pairs),
          radical_electrons: int_or_nil(atom.radical_electrons),
          ring_closures: str_or_nil(atom.ring_closures),
          aromatic: bool_or_nil(atom.aromatic),
          hydrogens: int_or_nil(atom.hydrogens)
        )
      end

      # Fuzz corpus inputs like `H_{2a}O` parse with the raw braced
      # text in the subscript field (the Text formatter round-trips it
      # verbatim by design). The canonical wire form carries only
      # schema-clean values; junk never enters the wire.
      def digits_or_nil(value)
        str_or_nil(value)&.then { |s| s.match?(/\A\d+\z/) ? s : nil }
      end

      def str_or_nil(value)
        value.is_a?(String) ? value : nil
      end

      def bool_or_nil(value)
        value.nil? ? nil : !!value
      end

      def int_or_nil(value)
        value.is_a?(Integer) ? value : nil
      end

      def molecule_to_wire(node)
        AsciiChem::Wire::Molecule.new(
          type: "molecule",
          nodes: node.nodes.map { |n| to_wire(n) },
          coefficient: node.coefficient,
          stereo: stereo_to_wire(node.stereo),
          identifiers: node.identifiers.map { |i| identifier_to_wire(i) }
        )
      end

      # Stereo markers cross the wire as the v1 enum strings
      # ("R", "alpha", ...); the model carries symbols.
      def stereo_to_wire(stereo)
        return nil unless stereo

        AsciiChem::Model::Molecule::STEREO_TO_LETTER.fetch(stereo)
      end

      def stereo_from_wire(stereo)
        return nil unless stereo

        AsciiChem::Model::Molecule::STEREO_LETTERS.fetch(stereo.to_s)
      end

      def group_to_wire(node)
        AsciiChem::Wire::Group.new(
          type: "group",
          nodes: node.nodes.map { |n| to_wire(n) },
          multiplicity: node.multiplicity,
          bracket: node.bracket.to_s
        )
      end

      def bond_to_wire(node)
        AsciiChem::Wire::Bond.new(type: "bond", kind: node.kind.to_s)
      end

      def identifier_to_wire(node)
        AsciiChem::Wire::Identifier.new(
          type: "identifier",
          value: node.value, convention: node.convention.to_s, dict_ref: node.dict_ref
        )
      end

      def name_to_wire(node)
        AsciiChem::Wire::Name.new(
          type: "name",
          content: node.content, convention: node.convention, dict_ref: node.dict_ref
        )
      end

      def reaction_to_wire(node)
        AsciiChem::Wire::Reaction.new(
          type: "reaction",
          reactants: node.reactants.map { |m| molecule_to_wire(m) },
          products: node.products.map { |m| molecule_to_wire(m) },
          arrow: node.arrow.to_s,
          conditions: conditions_to_wire(node.conditions)
        )
      end

      def conditions_to_wire(conditions)
        return nil unless conditions

        AsciiChem::Wire::ReactionConditions.new(above: conditions.above, below: conditions.below)
      end

      def cascade_to_wire(node)
        AsciiChem::Wire::ReactionCascade.new(
          type: "reaction-cascade",
          steps: node.steps.map { |r| reaction_to_wire(r) }
        )
      end

      def econfig_to_wire(node)
        AsciiChem::Wire::ElectronConfiguration.new(
          type: "electron-configuration",
          orbitals: node.orbitals.map do |(label, count)|
            AsciiChem::Wire::OrbitalOccupancy.new(orbital: label.to_s, occupancy: count.to_s)
          end,
          term_symbol: term_symbol_to_wire(node.term_symbol)
        )
      end

      def term_symbol_to_wire(term)
        return nil unless term

        AsciiChem::Wire::TermSymbol.new(
          multiplicity: term.multiplicity.to_s, letter: term.letter.to_s, j_value: term.j_value.to_s
        )
      end

      def math_to_wire(node)
        AsciiChem::Wire::EmbeddedMath.new(type: "embedded-math", source: node.source)
      end

      def text_to_wire(node)
        AsciiChem::Wire::Text.new(type: "text", content: node.content)
      end

      def mechanism_to_wire(node)
        AsciiChem::Wire::Mechanism.new(
          type: "mechanism",
          steps: node.steps.map do |step|
            AsciiChem::Wire::MechanismStep.new(label: step.label, reaction: reaction_to_wire(step.reaction))
          end,
          spectators: node.spectators.map { |m| molecule_to_wire(m) }
        )
      end

      def spectrum_to_wire(node)
        AsciiChem::Wire::Spectrum.new(
          type: "spectrum",
          technique: node.type,
          params: node.params,
          peaks: node.peaks.map do |peak|
            AsciiChem::Wire::SpectrumPeak.new(
              position: peak.position, intensity: peak.intensity,
              multiplicity: peak.multiplicity, assignment: peak.assignment
            )
          end
        )
      end

      def crystal_to_wire(node)
        AsciiChem::Wire::Crystal.new(
          type: "crystal",
          name: node.name, a: node.a, b: node.b, c: node.c,
          alpha: node.alpha, beta: node.beta, gamma: node.gamma,
          spacegroup: node.spacegroup,
          atoms: node.atoms.map { |atom| atom_to_wire(atom) }
        )
      end

      def zmatrix_to_wire(node)
        AsciiChem::Wire::ZMatrix.new(
          type: "zmatrix",
          rows: node.rows.map do |row|
            AsciiChem::Wire::ZRow.new(
              atom: row.atom, ref1: row.ref1, distance: row.distance,
              ref2: row.ref2, angle: row.angle, ref3: row.ref3, dihedral: row.dihedral
            )
          end
        )
      end

      def calculation_to_wire(node)
        AsciiChem::Wire::Calculation.new(
          type: "calculation",
          method: node.method, basis: node.basis,
          properties: node.properties.map do |prop|
            AsciiChem::Wire::CalculatedProperty.new(
              title: prop.title, value: prop.value, units: prop.units,
              dict_ref: prop.dict_ref, convention: prop.convention
            )
          end
        )
      end

      # -- ingestion (core set) ----------------------------------------

      def formula_from_wire(wire)
        AsciiChem::Model::Formula.new(nodes: wire.nodes.map { |n| from_wire(n) })
      end

      def atom_from_wire(wire)
        AsciiChem::Model::Atom.new(
          element: wire.element, isotope: wire.isotope, subscript: wire.subscript,
          charge: wire.charge, oxidation_state: wire.oxidation_state,
          lone_pairs: wire.lone_pairs, radical_electrons: wire.radical_electrons,
          ring_closures: wire.ring_closures,
          aromatic: wire.aromatic, hydrogens: wire.hydrogens
        )
      end

      def molecule_from_wire(wire)
        AsciiChem::Model::Molecule.new(
          nodes: Array(wire.nodes).map { |n| from_wire(n) },
          coefficient: wire.coefficient,
          stereo: stereo_from_wire(wire.stereo),
          identifiers: Array(wire.identifiers).map { |i| identifier_from_wire(i) }
        )
      end

      def group_from_wire(wire)
        AsciiChem::Model::Group.new(
          nodes: wire.nodes.map { |n| from_wire(n) },
          multiplicity: wire.multiplicity,
          bracket: wire.bracket&.to_sym
        )
      end

      def bond_from_wire(wire)
        AsciiChem::Model::Bond.new(kind: wire.kind.to_sym)
      end

      def identifier_from_wire(wire)
        AsciiChem::Model::Identifier.new(
          value: wire.value, convention: wire.convention, dict_ref: wire.dict_ref
        )
      end

      def name_from_wire(wire)
        AsciiChem::Model::Name.new(
          content: wire.content, convention: wire.convention, dict_ref: wire.dict_ref
        )
      end

      def reaction_from_wire(wire)
        conditions = wire.conditions &&
                     AsciiChem::Model::Reaction::Conditions.new(above: wire.conditions.above,
                                                                below: wire.conditions.below)
        AsciiChem::Model::Reaction.new(
          reactants: Array(wire.reactants).map { |m| molecule_from_wire(m) },
          products: Array(wire.products).map { |m| molecule_from_wire(m) },
          arrow: wire.arrow.to_sym,
          conditions: conditions
        )
      end

      def reaction_cascade_from_wire(wire)
        AsciiChem::Model::ReactionCascade.new(
          steps: Array(wire.steps).map { |r| reaction_from_wire(r) }
        )
      end

      def electron_configuration_from_wire(wire)
        AsciiChem::Model::ElectronConfiguration.new(
          orbitals: Array(wire.orbitals).map { |o| [o.orbital, o.occupancy] },
          term_symbol: wire.term_symbol &&
                       AsciiChem::Model::ElectronConfiguration::TermSymbol.new(
                         multiplicity: wire.term_symbol.multiplicity,
                         letter: wire.term_symbol.letter,
                         j_value: wire.term_symbol.j_value
                       )
        )
      end

      def embedded_math_from_wire(wire)
        AsciiChem::Model::EmbeddedMath.new(
          formula: Plurimath::Asciimath.new(wire.source).to_formula,
          source: wire.source
        )
      end

      def text_from_wire(wire)
        AsciiChem::Model::Text.new(content: wire.content)
      end
    end
  end
end
