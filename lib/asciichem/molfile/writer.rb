# frozen_string_literal: true

module AsciiChem
  module Molfile
    # Model molecule → V2000 molfile. Authored x2/y2 coordinates are
    # used when present; otherwise a deterministic 2D layout is
    # computed (Layout walks atoms in the same order as
    # Structure::Graph, so positions map by index). Charges and
    # isotopes are emitted as `M  CHG` / `M  ISO` property lines.
    #
    # Tetrahedral chirality crosses as a WEDGE on the stereocentre's
    # first bond (TH1 → up, TH2 → down), oriented centre → neighbour:
    # the oracle ignores the V2000 atom-parity field for 2D input
    # (verified against inchi-1 1.07.5 — enantiomers only separate
    # through the wedge), so the parity field alone never carries
    # stereo. Directional bonds (`/`, `\`, E/Z) have no V2000 field:
    # the model's Bond#direction is documented as a molfile loss
    # rather than silently invented from geometry.
    class Writer
      BOND_TYPES = {
        single: 1, double: 2, triple: 3, aromatic: 4,
        wedge: 1, hash: 1
      }.freeze
      BOND_STEREO = { wedge: 1, hash: 6 }.freeze
      CHIRALITY_PARITY = { 'TH1' => 1, 'TH2' => 2 }.freeze

      def initialize(molecule, name: nil, layout: true)
        @molecule = molecule
        @name = name
      @layout = layout
      end

      def write
        @atoms, @edges = Structure::Graph.build!(@molecule)
        raise ParseError, "molecule has no bonds — a formula is not a structure" if @edges.empty? && @atoms.length > 1

        materialize_aromatic_hydrogens
        atoms = @atoms
        edges = @edges

        lines = []
        lines << @name.to_s
        lines << "  AsciiChem"
        lines << ""
        lines << format("%3d%3d  0  0  0  0  0  0  0  0999 V2000", atoms.length, edges.length)

        coords = atoms.each_index.map do |index|
          coordinates(atoms[index], index, atoms)
        end
        lay_out_ez(edges, coords)
        atoms.each_with_index do |atom, index|
          x, y = coords[index]
          lines << format("%10.4f%10.4f%10.4f %-3s 0  0%3d%3d  0  0  0  0  0  0  0  0  0",
                          x, y, atom.z2 || 0.0, atom.element,
                          CHIRALITY_PARITY.fetch(atom.chirality, 0),
                          hcount_code(atom))
        end

        wedges = wedge_bonds(atoms, edges)
        edges.each do |edge|
          type = BOND_TYPES.fetch(edge.kind) do
            raise ParseError, "#{edge.kind} bonds have no molfile V2000 type"
          end
          stereo = BOND_STEREO.fetch(edge.kind, 0)
          from, to = edge.from, edge.to
          if (wedge = wedges[edge.object_id])
            from, to, stereo = wedge
          end
          lines << format("%3d%3d%3d%3d  0  0  0  0  0  0  0",
                          from + 1, to + 1, type, stereo)
        end

        lines << property_line("M  CHG", charge_pairs(atoms))
        lines << property_line("M  ISO", isotope_pairs(atoms))
        lines << "M  END"
        lines.compact.join("\n") << "\n"
      end

      private

      # Directional bonds draw the E/Z layer: a direction rides a
      # single bond adjacent to a double bond, and the substituent's
      # SIDE of that double bond is the drawn information. The layout's
      # arbitrary placement carries no side semantics, so each
      # directional substituent is mirrored across the double-bond
      # axis until its side sign matches the drawn rule (the chemomer
      # synthesis's oracle-verified convention: `/` puts the
      # substituent opposite the axis direction in string order, `\`
      # puts it alongside). `C/C=C/C` draws trans, `C/C=C\C` cis.
      def lay_out_ez(edges, coords)
        edges.each do |edge|
          next unless edge.direction

          resolved = double_bond_axis(edges, edge)
          next unless resolved

          axis, p_index, u_index = resolved
          q_index = axis.from == p_index ? axis.to : axis.from

          # Place the substituent perpendicular to the double-bond
          # axis, on the drawn side, anchored at its bond partner. The
          # side reads against the STRING-ORDERED axis (a→b, the
          # chemomer lift's invariant — `/` draws the substituent
          # above when it follows the axis in string order, below when
          # it precedes; `\` mirrors), so `C/C=C/C` draws trans and
          # `C/C=C\C` cis regardless of which end the axis runs from.
          # The layout's own placement carries no side semantics
          # (elkrb draws chains collinear), so the stereobond's
          # neighbourhood is synthesized outright.
          a_index, b_index = [p_index, q_index].minmax
          ax, ay = coords[a_index]
          bx, by = coords[b_index]
          px, py = coords[p_index]
          dx, dy = bx - ax, by - ay
          length = Math.sqrt(dx * dx + dy * dy)
          nx, ny = -dy / length, dx / length
          side = (edge.direction == :up ? 1 : -1) * (u_index > a_index ? 1 : -1)
          coords[u_index] = [px + nx * length * side, py + ny * length * side]
        end
      end

      # The double-bond axis a directional bond borders: which end of
      # the single bond touches a kind-2 bond's atom, with that
      # endpoint, the substituent (the other end), and the double-bond
      # edge whose other endpoint completes the axis.
      def double_bond_axis(edges, single)
        touches = lambda do |atom, other|
          edge = edges.find do |candidate|
            candidate.kind == :double &&
              ((candidate.from == atom && candidate.to != other) ||
               (candidate.to == atom && candidate.from != other))
          end
          edge ? [edge, atom, single.from == atom ? single.to : single.from] : nil
        end
        touches.call(single.from, single.to) || touches.call(single.to, single.from)
      end

      # One wedge per chiral atom, on its first bond, oriented
      # centre → neighbour: TH1 rises (stereo 1), TH2 falls (6).
      # Returns { edge.object_id => [from, to, stereo] }.
      def wedge_bonds(atoms, edges)
        wedges = {}
        atoms.each_with_index do |atom, index|
          next unless CHIRALITY_PARITY.key?(atom.chirality)

          edge = edges.find { |e| e.from == index || e.to == index }
          next unless edge

          stereo = atom.chirality == 'TH1' ? 1 : 6
          wedges[edge.object_id] =
            if edge.from == index
              [index, edge.to, stereo]
            else
              [index, edge.from, stereo]
            end
        end
        wedges
      end

      # MDL H-count code: 0 default, 1 H0, 2 H1, 3 H2, ... — so a
      # stated count n crosses as n + 1.
      def hcount_code(atom)
        atom.hydrogens.nil? ? 0 : atom.hydrogens + 1
      end

      # The H atom records materialized for aromatic carriers (see
      # materialize_aromatic_hydrogens); the writer's atom-line and
      # property-pair reads need only these fields.
      HydrogenAtom = Struct.new(:element, :z2, :chirality, :hydrogens,
                                :charge, :isotope, keyword_init: true)

      # Aromatic carriers lose their bracket H in the identity pipe:
      # the V2000 H-count column is oracle-ignored (the release engine
      # never reads it — the hcount-ignored oracle recording), and the
      # valence derivation does not hand aromatic atoms their H (Hückel
      # perception reads aromatic N as pyridine-type by default), so a
      # pyrrole's [nH] reads one hydrogen short (asciichem-ruby#181).
      # The explicit H atom is the one transport that survives — the
      # same posture as [2H], which is a real atom. Non-aromatic
      # carriers are untouched: their H derive by valence everywhere,
      # and materializing those would churn the recorded corpus
      # molfiles (the alanine stereocenters) whose bytes the fixtures
      # pin.
      def materialize_aromatic_hydrogens
        @h_carriers = {}
        extra_atoms = []
        extra_edges = []
        @atoms.each_with_index do |atom, index|
          next unless atom.aromatic && atom.hydrogens.to_i.positive?

          atom.hydrogens.times do |nth|
            target = @atoms.length + extra_atoms.length
            @h_carriers[target] = [index, nth]
            extra_atoms << HydrogenAtom.new(element: 'H', z2: nil,
                                            chirality: nil, hydrogens: nil)
            extra_edges << Structure::Graph::Edge.new(from: index, to: target,
                                                      kind: :single)
          end
        end
        @atoms += extra_atoms
        @edges += extra_edges
      end

      # Authored coordinates win; otherwise positions from the
      # deterministic 2D layout (same walk order as the graph).
      # Materialized H atoms sit offset from their carrier (stacked
      # when several), since no layout position exists for them.
      def coordinates(atom, index, _atoms)
        if (carrier = @h_carriers[index])
          x, y = coordinates(@atoms[carrier[0]], carrier[0], _atoms)
          return [x + 0.75, y + 0.75 * carrier[1]]
        end

        return [0.0, 0.0] unless @layout

        @layout_positions ||= AsciiChem::Layout.layout(@molecule).atoms
        placed = @layout_positions[index]
        placed ? [placed.x, placed.y] : [0.0, 0.0]
      end

      def charge_pairs(atoms)
        atoms.each_with_index
             .filter_map { |atom, i| [i + 1, charge_value(atom.charge)] if atom.charge }
      end

      def isotope_pairs(atoms)
        atoms.each_with_index
             .filter_map { |atom, i| [i + 1, atom.isotope.to_i] if atom.isotope }
      end

      # The model's number-then-sign charge ("2+") → signed integer.
      def charge_value(charge)
        count = charge[/\A\d+/]&.to_i || 1
        charge.end_with?("-") ? -count : count
      end

      def property_line(prefix, pairs)
        return nil if pairs.empty?

        pairs.reduce(+"#{prefix}%3d" % pairs.length) do |line, (idx, value)|
          line << format("%4d%4d", idx, value)
        end
      end
    end
  end
end
