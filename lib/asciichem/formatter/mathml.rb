# frozen_string_literal: true

require "nokogiri"

module AsciiChem
  module Formatter
    # Renders a Model tree as presentation MathML.
    #
    # The headline semantic fix lives here: prefix isotopes bind to the
    # atom, so `^14C` renders as `<msup><mi>C</mi><mn>14</mn></msup>`
    # (Carbon with 14 as superscript). AsciiMath would emit
    # `<msup><mi></mi><mn>14</mn></msup><mi>C</mi>` — a phantom base
    # followed by a sibling atom, which loses the binding.
    class Mathml < Base
      MATHML_NS = "http://www.w3.org/1998/Math/MathML".freeze

      def initialize
        @doc = Nokogiri::XML::Document.new
      end

      # Model entry point. Returns a `<math>` element as a string.
      def visit_formula(formula)
        math = el("math", xmlns: MATHML_NS)
        mrow = el("mrow")
        formula.nodes.each { |n| mrow.add_child(render_node(n)) }
        math.add_child(mrow)
        @doc.root = math
        # Native UTF-8 output preserves unicode arrow entities so specs
        # and downstream consumers see ⇌ and → instead of &#x21CC;.
        @doc.to_xml(encoding: "UTF-8")
      end

      def visit_molecule(molecule)
        mrow = el("mrow")
        if molecule.stereo
          mrow.add_child(mtext("(#{molecule.stereo_letter})-"))
        end
        mrow.add_child(mn(molecule.coefficient)) if molecule.coefficient
        molecule.nodes.each { |n| mrow.add_child(render_node(n)) }
        mrow
      end

      def visit_atom(atom)
        base = mi(atom.element)
        base = wrap_isotope(base, atom)  if atom.isotope
        base = wrap_charge(base, atom)   if atom.charge
        base = wrap_oxidation(base, atom) if atom.oxidation_state
        base = wrap_subsup(base, atom)
        base = wrap_lewis(base, atom)
        base
      end

      def visit_group(group)
        mrow = el("mrow")
        mrow.add_child(mo(group.open_char))
        group.nodes.each { |n| mrow.add_child(render_node(n)) }
        mrow.add_child(mo(group.close_char))
        return mrow unless group.multiplicity

        msub = el("msub")
        msub.add_child(mrow)
        msub.add_child(mn(group.multiplicity))
        msub
      end

      def visit_bond(bond)
        mo(bond.entity)
      end

      def visit_reaction(reaction)
        mrow = el("mrow")
        add_terms(mrow, reaction.reactants)
        mrow.add_child(render_arrow(reaction))
        add_terms(mrow, reaction.products)
        mrow
      end

      def visit_reaction_cascade(cascade)
        mrow = el("mrow")
        return mrow if cascade.steps.empty?

        head = cascade.steps.first
        add_terms(mrow, head.reactants)
        cascade.steps.each do |step|
          mrow.add_child(render_arrow(step))
          add_terms(mrow, step.products)
        end
        mrow
      end

      def visit_electron_configuration(ec)
        mrow = el("mrow")
        ec.orbitals.each_with_index do |(orbital, occupancy), index|
          mrow.add_child(mo("&#xA0;")) if index.positive?
          msup = el("msup")
          msup.add_child(mi(orbital))
          msup.add_child(mn(occupancy))
          mrow.add_child(msup)
        end
        mrow
      end

      def visit_embedded_math(em)
        # Strip the outer <math> wrapper so the embedded fragment slots
        # into our surrounding <mrow>.
        fragment = em.formula.to_mathml
        parsed = Nokogiri::XML(fragment)
        math = parsed.at_xpath("//m:math", m: MATHML_NS)
        return el("mrow") unless math

        # Detach children into a fresh <mrow>.
        mrow = el("mrow")
        math.children.each { |c| mrow.add_child(c.dup) }
        mrow
      end

      def visit_text(text)
        mtext(text.content)
      end

      private

      def render_node(node)
        node.accept(self)
      end

      def add_terms(parent, terms)
        terms.each_with_index do |term, index|
          parent.add_child(mo("+")) if index.positive?
          parent.add_child(render_node(term))
        end
      end

      def render_arrow(reaction)
        op = mo(reaction.arrow_entity)
        return op unless reaction.conditions

        above = reaction.conditions.above
        below = reaction.conditions.below
        return op unless above || below

        moverunder = el(above && below ? "munderover" : (above ? "mover" : "munder"))
        moverunder.add_child(op)
        moverunder.add_child(mtext(above || ""))
        moverunder.add_child(mtext(below || "")) if below
        moverunder
      end

      def wrap_isotope(base, atom)
        msup = el("msup")
        msup.add_child(base)
        msup.add_child(mn(atom.isotope))
        msup
      end

      def wrap_charge(base, atom)
        mrow = el("mrow")
        sign_match = atom.charge.match(/\A(?<n>\d*)(?<sign>[+-])\z/)
        return base unless sign_match

        mrow.add_child(mn(sign_match[:n])) unless sign_match[:n].empty?
        mrow.add_child(mo(sign_match[:sign]))
        wrap_in_sup(base, mrow)
      end

      def wrap_oxidation(base, atom)
        mrow = el("mrow")
        mrow.add_child(mi(atom.oxidation_state))
        wrap_in_sup(base, mrow)
      end

      def wrap_subsup(base, atom)
        has_sub = atom.subscript && !atom.subscript.empty?
        has_sup_raw = atom.superscript && !atom.superscript.empty?
        return base unless has_sub || has_sup_raw

        if has_sub && has_sup_raw
          msubsup = el("msubsup")
          msubsup.add_child(base)
          msubsup.add_child(mn(atom.subscript))
          msubsup.add_child(mn(atom.superscript))
          msubsup
        elsif has_sub
          wrap_in_sub(base, mn(atom.subscript))
        else
          wrap_in_sup(base, mn(atom.superscript))
        end
      end

      # Lewis markers: lone pairs as `:` chars before, radicals as `.`
      # chars after. MathML has no native Lewis structure element; the
      # ASCII stand-in is the canonical form for round-trip.
      def wrap_lewis(base, atom)
        return base unless atom.lone_pairs || atom.radical_electrons

        mrow = el("mrow")
        if atom.lone_pairs
          mrow.add_child(mtext(":" * atom.lone_pairs))
        end
        mrow.add_child(base)
        if atom.radical_electrons
          mrow.add_child(mtext("." * atom.radical_electrons))
        end
        mrow
      end

      def wrap_in_sub(base, sub)
        msub = el("msub")
        msub.add_child(base)
        msub.add_child(sub)
        msub
      end

      def wrap_in_sup(base, sup)
        msup = el("msup")
        msup.add_child(base)
        msup.add_child(sup)
        msup
      end

      # -- Nokogiri element factories ------------------------------------

      def el(name, attrs = {})
        element = Nokogiri::XML::Element.new(name, @doc)
        attrs.each { |k, v| element[k.to_s] = v }
        element
      end

      def mi(content)
        e = el("mi"); e.content = content.to_s; e
      end

      def mn(content)
        e = el("mn"); e.content = content.to_s; e
      end

      def mo(content)
        e = el("mo"); e.content = content.to_s; e
      end

      def mtext(content)
        e = el("mtext"); e.content = content.to_s; e
      end
    end
  end
end
