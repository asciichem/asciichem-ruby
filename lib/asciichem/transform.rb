# frozen_string_literal: true

require "parslet"

module AsciiChem
  # Converts a parse tree (from AsciiChem::Grammar) into a tree of
  # AsciiChem::Model instances.
  #
  # The transform contains minimal logic — it maps hash shapes to
  # constructor calls. Anything semantically tricky (e.g. distinguishing
  # isotope prefix from suffix charge) is encoded in the grammar, not
  # here.
  class Transform < Parslet::Transform
    # -- top level --------------------------------------------------------

    rule(formula: subtree(:subtree)) do
      nodes = FormulaNormaliser.new(subtree).to_a
      Model::Formula.new(nodes: nodes)
    end

    # -- text -------------------------------------------------------------

    rule(text_run: simple(:text)) do
      Model::Text.new(content: text.to_s)
    end

    rule(group_text_run: simple(:text)) do
      Model::Text.new(content: text.to_s)
    end

    # -- embedded math ---------------------------------------------------

    rule(math_source: simple(:source)) do
      formula = Plurimath::Asciimath.new(source.to_s).to_formula
      Model::EmbeddedMath.new(formula: formula, source: source.to_s)
    end

    # -- atoms -----------------------------------------------------------

    # Both prefixed and plain atoms flow through the same builder. The
    # presence of `isotope` distinguishes them.
    rule(element: simple(:el),
        subscript: simple(:sub),
        superscript: simple(:sup),
        isotope: simple(:iso)) do
      AtomBuilder.new(el, isotope: iso, subscript: sub, superscript: sup).build
    end

    rule(element: simple(:el),
        subscript: simple(:sub),
        superscript: simple(:sup)) do
      AtomBuilder.new(el, subscript: sub, superscript: sup).build
    end

    # -- bonds ------------------------------------------------------------

    rule(triple: simple(:_t))   { Model::Bond.new(kind: :triple) }
    rule(double: simple(:_d))   { Model::Bond.new(kind: :double) }
    rule(single: simple(:_s))   { Model::Bond.new(kind: :single) }

    # -- molecules -------------------------------------------------------

    rule(coefficient: subtree(:coef), units: subtree(:units)) do
      Model::Molecule.new(
        coefficient: CoefficientNormaliser.new(coef).to_s,
        nodes: Array(units)
      )
    end

    rule(units: subtree(:units)) do
      Model::Molecule.new(nodes: Array(units))
    end

    # -- groups ----------------------------------------------------------

    rule(open_bracket: simple(:open),
         group_nodes: subtree(:nodes),
         close_bracket: simple(:_close),
         multiplicity: subtree(:mult)) do
      Model::Group.new(
        nodes: Array(nodes),
        multiplicity: MultiplicityNormaliser.new(mult).to_s,
        bracket: Group.bracket_kind(open.to_s)
      )
    end

    # -- reactions -------------------------------------------------------

    rule(reactants: subtree(:reactants),
         arrow: subtree(:arrow),
         products: subtree(:products)) do
      ReactionBuilder.new(reactants, arrow, products).build
    end

    # -- electron configuration ------------------------------------------

    rule(orbitals: sequence(:pairs)) do
      Model::ElectronConfiguration.new(orbitals: pairs)
    end

    # -- internal helpers ------------------------------------------------

    # Lifts the inner nodes of a `formula` capture into a flat array.
    class FormulaNormaliser
      def initialize(subtree)
        @subtree = subtree
      end

      def to_a
        case @subtree
        when Array then @subtree
        when nil   then []
        else            [@subtree]
        end
      end
    end

    # Coefficient is captured as `{ value: "2" }`; we want just the
    # string. nil when no coefficient was present.
    class CoefficientNormaliser
      def initialize(node)
        @node = node
      end

      def to_s
        return nil if @node.nil?

        v = @node.is_a?(Hash) ? @node[:value] : @node
        v&.to_s
      end
    end

    # Multiplicity is captured as `_2` (marker + digits) or nil. Strip
    # the leading underscore.
    class MultiplicityNormaliser
      def initialize(node)
        @node = node
      end

      def to_s
        return nil if @node.nil?

        s = @node.to_s
        s = s[1..] if s.start_with?("_")
        s
      end
    end

    # Builds an Atom, normalising nil/empty strings and pulling apart
    # composite superscripts (charge vs oxidation state vs raw). Exactly
    # one of { charge, oxidation_state, superscript } is set on the
    # resulting atom — they are mutually exclusive views of the
    # superscript position.
    class AtomBuilder
      def initialize(element, isotope: nil, subscript: nil, superscript: nil)
        @element = element
        @isotope = isotope
        @subscript = subscript
        @superscript = superscript
      end

      def build
        charge = detected_charge
        oxidation = detected_oxidation_state
        Model::Atom.new(
          element: @element.to_s,
          isotope: strip_marker(@isotope),
          subscript: strip_marker(@subscript, "_"),
          superscript: raw_superscript(charge, oxidation),
          charge: charge,
          oxidation_state: oxidation
        )
      end

      private

      # Returns the raw superscript only when it isn't a charge or
      # oxidation state (otherwise those carry the info).
      def raw_superscript(charge, oxidation)
        return nil if charge || oxidation

        strip_marker(@superscript, "^")
      end

      def detected_charge
        s = strip_marker(@superscript, "^")
        return nil unless s

        match = s.match(/\A(?<n>\d*)(?<sign>[+-])\z/) ||
                s.match(/\A(?<sign>[+-])(?<n>\d*)\z/)
        return nil unless match

        n = match[:n]
        sign = match[:sign]
        n.empty? ? sign : "#{n}#{sign}"
      end

      def detected_oxidation_state
        s = strip_marker(@superscript, "^")
        return nil unless s

        match = s.match(/\A\(([IVXLCDM]+)\)\z/)
        match && match[1]
      end

      # Strip a leading marker char (`^` or `_`) from the captured
      # value. nil/empty -> nil.
      def strip_marker(value, marker = nil)
        return nil if value.nil?

        s = value.to_s
        s = s[1..] if marker && s.start_with?(marker)
        s = s[1..] if s.start_with?("^", "_")
        s.empty? ? nil : s
      end
    end

    # Builds a Reaction, mapping the arrow hash into arrow kind and
    # conditions.
    class ReactionBuilder
      ARROW_KINDS = {
        "<=>" => :equilibrium,
        "<->" => :resonance,
        "->"  => :forward,
        "<-"  => :reverse
      }.freeze

      def initialize(reactants, arrow, products)
        @reactants = reactants
        @arrow = arrow
        @products = products
      end

      def build
        Model::Reaction.new(
          reactants: as_terms(@reactants),
          products: as_terms(@products),
          arrow: kind,
          conditions: conditions
        )
      end

      private

      def kind
        ARROW_KINDS.fetch(@arrow[:kind].to_s, :forward)
      end

      def conditions
        above = condition_text(@arrow[:above])
        below = condition_text(@arrow[:below])
        return nil unless above || below

        Model::Reaction::Conditions.new(above: above, below: below)
      end

      def condition_text(node)
        return nil if node.nil?

        text = node.is_a?(Hash) ? node[:text] : node
        text&.to_s
      end

      def as_terms(side)
        case side
        when Array then side
        when nil   then []
        else            [side]
        end
      end
    end

    # Maps the literal bracket character to the model's bracket symbol.
    module Group
      def self.bracket_kind(char)
        case char
        when "(" then :paren
        when "[" then :square
        when "{" then :brace
        else          :paren
        end
      end
    end
  end
end
