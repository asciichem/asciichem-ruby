# frozen_string_literal: true

require 'parslet'

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
      Model::Text.new(content: TextNormaliser.strip_quotes(text.to_s))
    end

    rule(group_text_run: simple(:text)) do
      Model::Text.new(content: TextNormaliser.strip_quotes(text.to_s))
    end

    # -- embedded math ---------------------------------------------------

    rule(math_source: simple(:source)) do
      formula = Plurimath::Asciimath.new(source.to_s).to_formula
      Model::EmbeddedMath.new(formula: formula, source: source.to_s)
    end

    # -- atoms -----------------------------------------------------------
    #
    # One rule covers every atom shape. The grammar wraps atoms in
    # `.as(:atom)`, so the transform sees `{ atom: { element:...,
    # isotope:..., subscript:..., superscript:..., lone_pairs:...,
    # radical_electrons:... } }` with any of the optional keys absent.
    # AtomBuilder.from_parse_tree normalises the variations.
    rule(atom: subtree(:attrs)) do
      AtomBuilder.from_parse_tree(attrs).build
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

    # -- annotated molecules -------------------------------------------
    #
    # An annotated molecule wraps a built Model::Molecule with
    # `@key("value")` metadata annotations. The grammar produces
    # `{ mol: <Molecule>, annotations: [{ann_type:, ann_value:}, ...] }`.
    # The transform receives the already-built Molecule (parslet
    # transforms bottom-up) and applies the annotations.

    rule(mol: simple(:mol), annotations: subtree(:anns)) do
      AnnotationApplicator.new(mol, Array(anns)).apply
      mol
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

    # Inner rule: each `{orbital:..., occupancy:...}` hash becomes a
    # `[orbital, occupancy]` string pair. The outer rule then collects
    # these into an ElectronConfiguration.
    rule(orbital: simple(:orb), occupancy: simple(:occ)) do
      [orb.to_s, occ.to_s]
    end

    rule(electron_config: subtree(:raw_pairs)) do
      pairs = Array(raw_pairs).map { |pair| Array(pair) }
      Model::ElectronConfiguration.new(orbitals: pairs)
    end

    # -- internal helpers ------------------------------------------------

    # Strips the surrounding `"..."` quotes from a quoted text match.
    # Used by both `text_run` and `group_text_run` rules so the
    # model never carries the delimiters — the formatter re-adds them
    # on output.
    module TextNormaliser
      def self.strip_quotes(s)
        s.start_with?('"') && s.end_with?('"') ? s[1..-2] : s
      end
    end

    # Applies `@key("value")` molecule annotations to a built
    # Model::Molecule. The annotation type determines which field is
    # set: name → names[], inchi/smiles/cas → identifiers[], etc.
    class AnnotationApplicator
      IDENTIFIER_TYPES = %w[inchi smiles cas iupac cid chebi].freeze

      def initialize(molecule, annotations)
        @molecule = molecule
        @annotations = annotations
      end

      def apply
        @annotations.each { |ann| apply_one(ann) }
      end

      private

      def apply_one(ann)
        if ann[:meta_key]
          @molecule.metadata << { name: ann[:meta_key].to_s,
                                  content: ann[:meta_value].to_s }
          return
        end
        type = ann[:ann_type].to_s
        value = ann[:ann_value].to_s
        case type
        when 'name'
          @molecule.names << Model::Name.new(content: value)
        when 'title'
          @molecule.title = value
        when 'formula'
          @molecule.formulas << { concise: value }
        when 'label'
          @molecule.labels << { value: value }
        when *IDENTIFIER_TYPES
          @molecule.identifiers << Model::Identifier.new(value: value, convention: type)
        else
          @molecule.properties << { title: type, value: value }
        end
      end
    end

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
        s = s[1..] if s.start_with?('_')
        s
      end
    end

    # Builds an Atom, normalising nil/empty strings and pulling apart
    # composite superscripts (charge vs oxidation state vs raw). Exactly
    # one of { charge, oxidation_state, superscript } is set on the
    # resulting atom — they are mutually exclusive views of the
    # superscript position.
    class AtomBuilder
      # Construct from a parse-tree hash. The grammar wraps atoms in
      # `.as(:atom)`, so the transform receives one hash with any of
      # these keys present: `:element`, `:isotope`, `:subscript`,
      # `:superscript`, `:lone_pairs`, `:radical_electrons`,
      # `:ring_closures`. Absent keys default to nil. Lewis markers
      # (`:lone_pairs`, `:radical_electrons`) are captured as
      # colon/dot strings whose length is the count.
      def self.from_parse_tree(attrs)
        hash = attrs.is_a?(Hash) ? attrs : {}
        new(
          hash[:element],
          isotope: hash[:isotope],
          subscript: hash[:subscript],
          superscript: hash[:superscript],
          lone_pairs: lewis_count(hash[:lone_pairs]),
          radical_electrons: lewis_count(hash[:radical_electrons]),
          ring_closures: ring_closures_string(hash[:ring_closures]),
          x2: float_or_nil(hash[:x2]),
          y2: float_or_nil(hash[:y2]),
          z2: float_or_nil(hash[:z2]),
          atom_parity: hash[:atom_parity]&.to_s
        )
      end

      def self.float_or_nil(value)
        return nil if value.nil?

        value.to_s.to_f
      end
      private_class_method :float_or_nil

      # Convert a Lewis marker (string of `:` or `.`) to its count.
      # nil/empty → nil.
      def self.lewis_count(value)
        return nil if value.nil?

        length = value.to_s.length
        length.positive? ? length : nil
      end
      private_class_method :lewis_count

      # Normalise the ring-closures capture to a string or nil.
      # parslet delivers the matched digit string or nil if `.maybe`
      # produced nothing.
      def self.ring_closures_string(value)
        s = value.to_s
        s.empty? ? nil : s
      end
      private_class_method :ring_closures_string

      def initialize(element, isotope: nil, subscript: nil, superscript: nil,
                     lone_pairs: nil, radical_electrons: nil,
                     ring_closures: nil,
                     x2: nil, y2: nil, z2: nil, atom_parity: nil)
        @element = element
        @isotope = isotope
        @subscript = subscript
        @superscript = superscript
        @lone_pairs = lone_pairs
        @radical_electrons = radical_electrons
        @ring_closures = ring_closures
        @x2 = x2
        @y2 = y2
        @z2 = z2
        @atom_parity = atom_parity
      end

      def build
        charge = detected_charge
        oxidation = detected_oxidation_state
        Model::Atom.new(
          element: @element.to_s,
          isotope: strip_marker(@isotope),
          subscript: strip_marker(@subscript, '_'),
          superscript: raw_superscript(charge, oxidation),
          charge: charge,
          oxidation_state: oxidation,
          lone_pairs: positive_int(@lone_pairs),
          radical_electrons: positive_int(@radical_electrons),
          ring_closures: @ring_closures,
          x2: @x2,
          y2: @y2,
          z2: @z2,
          atom_parity: @atom_parity
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

        strip_marker(@superscript, '^')
      end

      def detected_charge
        s = strip_marker(@superscript, '^')
        return nil unless s

        match = s.match(/\A(?<n>\d*)(?<sign>[+-])\z/) ||
                s.match(/\A(?<sign>[+-])(?<n>\d*)\z/)
        return nil unless match

        n = match[:n]
        sign = match[:sign]
        n.empty? ? sign : "#{n}#{sign}"
      end

      def detected_oxidation_state
        s = strip_marker(@superscript, '^')
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
        s = s[1..] if s.start_with?('^', '_')
        s.empty? ? nil : s
      end
    end

    # Builds a Reaction, mapping the arrow hash into arrow kind and
    # conditions.
    class ReactionBuilder
      ARROW_KINDS = {
        '<=>' => :equilibrium,
        '<->' => :resonance,
        '->' => :forward,
        '<-' => :reverse
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
        Model::Molecule::STEREO_LETTERS.fetch(letter.to_s, :unknown)
      end
    end

    # Maps the literal bracket character to the model's bracket symbol.
    module Group
      def self.bracket_kind(char)
        case char
        when '(' then :paren
        when '[' then :square
        when '{' then :brace
        else          :paren
        end
      end
    end
  end
end
