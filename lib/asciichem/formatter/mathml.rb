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
        # Isotope is a LEFT superscript per IUPAC (¹⁴C). Use
        # <mmultiscripts> with <mprescripts/> so the binding stays on
        # the atom — the AsciiMath `<msup><mi></mi>...<mi>C</mi>`
        # pattern (empty base + sibling) loses the binding.
        base = attach_isotope_prefix(base, atom) if atom.isotope
        base = wrap_lewis_prefix(base, atom)
        # When the atom has BOTH subscript and a superscript-style
        # marker (charge, oxidation state, or raw superscript), emit
        # a single <msubsup> rather than nesting <msub> inside <msup>.
        base = wrap_sub_and_super(base, atom)
        base = wrap_lewis_suffix(base, atom)
        base
      end

      def attach_isotope_prefix(base, atom)
        multi = el("mmultiscripts")
        multi.add_child(base)
        multi.add_child(el("none"))
        multi.add_child(el("none"))
        multi.add_child(Nokogiri::XML::Element.new("mprescripts", @doc))
        multi.add_child(el("none"))
        multi.add_child(mn(atom.isotope))
        multi
      end

      def wrap_lewis_prefix(base, atom)
        return base unless atom.lone_pairs

        mrow = el("mrow")
        mrow.add_child(mtext(":" * atom.lone_pairs))
        mrow.add_child(base)
        mrow
      end

      def wrap_lewis_suffix(base, atom)
        return base unless atom.radical_electrons

        mrow = el("mrow")
        mrow.add_child(base)
        mrow.add_child(mtext("." * atom.radical_electrons))
        mrow
      end

      # Combine subscript + superscript-style marker into the right
      # MathML element. Cases:
      #   sub + super  -> <msubsup>
      #   sub only     -> <msub>
      #   super only   -> <msup> (with charge/oxidation/raw super)
      #   neither      -> base unchanged
      def wrap_sub_and_super(base, atom)
        has_sub = atom.subscript && !atom.subscript.empty?
        super_node = super_element(atom)
        return base unless has_sub || super_node
        return wrap_in_sub(base, mn(atom.subscript)) if has_sub && !super_node
        return wrap_in_sup(base, super_node) if !has_sub && super_node

        msubsup = el("msubsup")
        msubsup.add_child(base)
        msubsup.add_child(mn(atom.subscript))
        msubsup.add_child(super_node)
        msubsup
      end

      # Build the MathML element for whichever superscript-style
      # marker is set (charge > oxidation_state > raw superscript).
      # Returns nil if none is set.
      def super_element(atom)
        if atom.charge
          row = charge_row(atom.charge)
          return row if row
        end
        if atom.oxidation_state
          mrow = el("mrow")
          mrow.add_child(mi(atom.oxidation_state))
          return mrow
        end
        if atom.superscript
          return mn(atom.superscript)
        end
        nil
      end

      def charge_row(charge)
        match = charge.match(/\A(?<n>\d*)(?<sign>[+-])\z/) ||
                charge.match(/\A(?<sign>[+-])(?<n>\d*)\z/)
        return nil unless match

        mrow = el("mrow")
        mrow.add_child(mn(match[:n])) unless match[:n].empty?
        mrow.add_child(mo(match[:sign]))
        mrow
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
        moverunder.add_child(render_condition(above)) if above
        moverunder.add_child(render_condition(below)) if below
        moverunder
      end

      # Render a reaction-condition string. The condition is captured
      # as raw text by the grammar, but chemists expect `_N` and `^N`
      # patterns to render as proper sub/superscripts. We parse the
      # condition as AsciiChem and use its MathML output. If the parse
      # fails (e.g. the condition is free-form prose), fall back to
      # plain <mtext>.
      def render_condition(text)
        return mtext("") if text.nil? || text.empty?

        begin
          inner = AsciiChem.parse(text).to_mathml
          parsed = Nokogiri::XML(inner)
          math = parsed.at_xpath("//m:math", m: MATHML_NS)
          if math
            mrow = el("mrow")
            math.children.each { |c| mrow.add_child(c.dup) }
            return mrow
          end
        rescue AsciiChem::ParseError, AsciiChem::Error
          # fall through to plain text
        end
        mtext(text)
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
        e = el("mi", mathvariant: "normal")
        e.content = content.to_s
        e
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
