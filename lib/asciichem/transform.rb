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

    # Plain atom with no Lewis markers.
    rule(element: simple(:el),
        subscript: simple(:sub),
        superscript: simple(:sup)) do
      AtomBuilder.new(el, subscript: sub, superscript: sup).build
    end

    # Atom with isotope (no Lewis).
    rule(element: simple(:el),
        subscript: simple(:sub),
        superscript: simple(:sup),
        isotope: simple(:iso)) do
      AtomBuilder.new(el, isotope: iso, subscript: sub, superscript: sup).build
    end

    # Atom with lone pairs prefix (Lewis).
    rule(lone_pairs: simple(:lp),
        element: simple(:el),
        subscript: simple(:sub),
        superscript: simple(:sup)) do
      AtomBuilder.new(el, subscript: sub, superscript: sup,
                      lone_pairs: lp.to_s.length).build
    end

    # Atom with isotope + lone pairs prefix.
    rule(lone_pairs: simple(:lp),
        element: simple(:el),
        subscript: simple(:sub),
        superscript: simple(:sup),
        isotope: simple(:iso)) do
      AtomBuilder.new(el, isotope: iso, subscript: sub, superscript: sup,
                      lone_pairs: lp.to_s.length).build
    end

    # Atom with radical electrons suffix.
    rule(element: simple(:el),
        subscript: simple(:sub),
        superscript: simple(:sup),
        radical_electrons: simple(:rad)) do
      AtomBuilder.new(el, subscript: sub, superscript: sup,
                      radical_electrons: rad.to_s.length).build
    end

    # Atom with lone pairs prefix AND radical suffix.
    rule(lone_pairs: simple(:lp),
        element: simple(:el),
        subscript: simple(:sub),
        superscript: simple(:sup),
        radical_electrons: simple(:rad)) do
      AtomBuilder.new(el, subscript: sub, superscript: sup,
                      lone_pairs: lp.to_s.length,
                      radical_electrons: rad.to_s.length).build
    end

    # -- bonds ------------------------------------------------------------

    rule(quadruple: simple(:_q)) { Model::Bond.new(kind: :quadruple) }
    rule(triple: simple(:_t))    { Model::Bond.new(kind: :triple) }
    rule(wedge: simple(:_w))     { Model::Bond.new(kind: :wedge) }
    rule(hash: simple(:_h))      { Model::Bond.new(kind: :hash) }
    rule(dative: simple(:_d))    { Model::Bond.new(kind: :dative) }
    rule(wavy: simple(:_wv))     { Model::Bond.new(kind: :wavy) }
    rule(double: simple(:_d2))   { Model::Bond.new(kind: :double) }
    rule(single: simple(:_s))    { Model::Bond.new(kind: :single) }

    # -- molecules -------------------------------------------------------

    rule(stereo: simple(:letter),
         coefficient: subtree(:coef),
         units: subtree(:units)) do
      Model::Molecule.new(
        coefficient: CoefficientNormaliser.new(coef).to_s,
        nodes: Array(units),
        stereo: StereoNormaliser.normalise(letter)
      )
    end

    rule(stereo: simple(:letter), units: subtree(:units)) do
      Model::Molecule.new(
        nodes: Array(units),
        stereo: StereoNormaliser.normalise(letter)
      )
    end

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

    # -- reaction cascades ------------------------------------------------
    #
    # The grammar wraps a chain in `{ cascade: { first: <Reaction>,
    # arrow:..., products:... (repeated) } }`. Fold into a single
    # ReactionCascade with steps[0] = first and each subsequent step
    # built from the previous step's products as reactants.

    rule(cascade: subtree(:data)) do
      CascadeBuilder.new(data).build
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
      def initialize(element, isotope: nil, subscript: nil, superscript: nil,
                     lone_pairs: nil, radical_electrons: nil)
        @element = element
        @isotope = isotope
        @subscript = subscript
        @superscript = superscript
        @lone_pairs = lone_pairs
        @radical_electrons = radical_electrons
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
          oxidation_state: oxidation,
          lone_pairs: positive_int(@lone_pairs),
          radical_electrons: positive_int(@radical_electrons)
        )
      end

      private

      def positive_int(value)
        return nil if value.nil?

        n = value.to_i
        n.positive? ? n : nil
      end

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

    # Builds a ReactionCascade. Parslet delivers the cascade shape in
    # one of two forms depending on how the grammar's sequence
    # flattened:
    #   - Array of segment hashes:
    #     [{ first: <Reaction> }, { arrow:, products: }, ...]
    #   - Single hash with array values:
    #     { first: <Reaction>, arrow: [...], products: [...] }
    # Normalise to a canonical form before building.
    class CascadeBuilder
      def initialize(data)
        @first, @tail = canonicalise(data)
      end

      def build
        steps = [@first]
        @tail.each do |arrow, products|
          prev_products = steps.last.products
          steps << ReactionBuilder.new(prev_products, arrow, products).build
        end
        Model::ReactionCascade.new(steps: steps)
      end

      private

      def canonicalise(data)
        if data.is_a?(Array)
          canonicalise_array(data)
        else
          canonicalise_hash(data)
        end
      end

      def canonicalise_array(arr)
        first = arr.find { |s| s.is_a?(Hash) && s.key?(:first) }[:first]
        tail = arr
                 .select { |s| s.is_a?(Hash) && s.key?(:arrow) }
                 .map { |s| [s[:arrow], s[:products]] }
        [first, tail]
      end

      def canonicalise_hash(hash)
        first = hash[:first]
        arrows = Array(hash[:arrow])
        products = Array(hash[:products])
        tail = arrows.zip(products)
        [first, tail]
      end
    end

    # Maps the captured stereo letter to the model's stereo symbol.
    module StereoNormaliser
      def self.normalise(letter)
        Model::Molecule::STEREO_LETTERS.fetch(letter.to_s) { :unknown }
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
