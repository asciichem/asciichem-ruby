# frozen_string_literal: true

module AsciiChem
  module Cml
    # Carries AsciiChem-specific fields through CML round-trip via an
    # `aci:` (AsciiChem extension) namespace. CML's standard wire
    # format covers element, isotope, charge, count, hydrogen count,
    # and spin multiplicity — but not oxidation state, lone pairs,
    # radical electrons, or anything else AsciiChem might add. Without
    # this side channel, those fields are silently dropped on
    # AsciiChem → CML → AsciiChem round-trip.
    #
    # This module is a facade over two distinct concerns:
    #
    #   - {AtomAttributes} — per-atom fields via `aci:<wire_name>`
    #     attributes on `<atom>` elements. Registry: FIELDS.
    #   - {TopLevel} — standalone constructs via `<aci:<element_name>
    #     position="N">...</aci:...>` children of `<cml>`. Registry:
    #     TopLevel::HANDLERS.
    #
    # Both sub-modules share the aci: namespace (constants below).
    # Adding a new atom field = one entry in AtomAttributes::FIELDS.
    # Adding a new top-level construct = one entry in TopLevel::HANDLERS.
    module Extensions
      NAMESPACE = 'https://asciichem.org/cml-ext'
      PREFIX = 'aci'
      CML_NS = 'http://www.xml-cml.org/schema'

      autoload :AtomAttributes, 'asciichem/cml/extensions/atom_attributes'
      autoload :TopLevel, 'asciichem/cml/extensions/top_level'

      # -- Facade (backwards-compat) ---------------------------------
      # These delegate to the sub-modules. New code should reference
      # AtomAttributes / TopLevel directly.

      def self.collect(atom_mapping)
        AtomAttributes.collect(atom_mapping)
      end

      def self.inject(xml, extensions)
        AtomAttributes.inject(xml, extensions)
      end

      def self.extract(xml)
        AtomAttributes.extract(xml)
      end

      def self.restore(formula, canonical_doc, extensions)
        AtomAttributes.restore(formula, canonical_doc, extensions)
      end

      def self.collect_top_level(formula)
        TopLevel.collect(formula)
      end

      def self.inject_top_level(xml, top_level)
        TopLevel.inject(xml, top_level)
      end

      def self.extract_top_level(xml)
        TopLevel.extract(xml)
      end

      def self.restore_top_level(formula, top_level)
        TopLevel.restore(formula, top_level)
      end
    end
  end
end
