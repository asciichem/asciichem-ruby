# frozen_string_literal: true

module AsciiChem
  module Layout
    # The chemistry-shaped deterministic placer (site#125 step one):
    # rings as regular polygons (fused rings fitted to their shared
    # atoms, spiro rings oriented away from the placed region),
    # chains as 120-degree zigzags grown breadth-first in source
    # order. Fully deterministic — the same molecule always yields
    # the same positions.
    #
    # Operates on a `MoleculeWalker::WalkResult` and returns
    # positions keyed by walk-atom id, so `builtin_layout` can map
    # them onto a `Result` without elkrb.
    module DepictionPlacer
      BOND_LENGTH = 56.0
      COLLISION_RADIUS = BOND_LENGTH / 2

      Point = Struct.new(:x, :y)

      class << self
        # Returns { walk_atom_id => Point } or nil when the graph has
        # no placeable content.
        def place(walk)
          atoms = walk.atoms
          return nil if atoms.empty?

          edges = walk.bonds.map do |bond|
            [index_of(atoms, bond.from_id), index_of(atoms, bond.to_id)]
          end
          positions = Array.new(atoms.length)

          free_x = place_cycles(atoms, edges, positions)
          free_x = grow_placed(edges, positions, free_x)
          place_untethered(atoms, edges, positions, free_x)

          atoms.each_with_index.to_h do |atom, index|
            [atom.id, positions[index]]
          end
        end

        private

        def index_of(atoms, id)
          atoms.index { |a| a.id == id }
        end

        # Rings first, in source order. Each cycle is placed free
        # (nothing placed yet), fused (two or more atoms already
        # placed — fit the polygon to them), or spiro-anchored (one
        # placed atom — orient away from the placed region).
        def place_cycles(atoms, edges, positions)
          free_x = 0.0
          ring_cycles(atoms, edges).each do |cycle|
            anchored = cycle.select { |member| positions[member] }
            if anchored.empty?
              free_x = place_free_cycle(cycle, positions, free_x)
            elsif anchored.length >= 2
              place_fused_cycle(cycle, positions)
            else
              place_anchored_cycle(cycle, positions)
            end
          end
          free_x
        end

        def ring_cycles(atoms, edges)
          pair_rings(atoms).filter_map do |from, to, _digit|
            cycle = ring_cycle(edges, from, to)
            cycle if cycle && cycle.length >= 3
          end
        end

        def place_free_cycle(cycle, positions, free_x)
          radius = polygon_radius(cycle.length)
          place_polygon(cycle, Point.new(free_x, 0.0), radius, 0.0, positions)
          free_x + (radius * 2) + BOND_LENGTH
        end

        # Fused on shared atoms: derive the rigid transform
        # (rotation + translation) that maps the ideal polygon's two
        # placed members onto their laid-out positions, then fill
        # only the unplaced members. Placed atoms never move — the
        # first ring keeps its geometry.
        def place_fused_cycle(cycle, positions)
          a = cycle.find { |member| positions[member] }
          b = cycle.find { |member| positions[member] && member != a }
          ia = cycle.index(a)
          ib = cycle.index(b)
          ideal_a = ideal_point(cycle.length, ia, 0.0)
          ideal_b = ideal_point(cycle.length, ib, 0.0)
          theta = Math.atan2(positions[b].y - positions[a].y,
                             positions[b].x - positions[a].x) -
                  Math.atan2(ideal_b.y - ideal_a.y, ideal_b.x - ideal_a.x)
          cos = Math.cos(theta)
          sin = Math.sin(theta)
          cycle.each_with_index do |member, i|
            next if positions[member]

            dx = ideal_point(cycle.length, i, 0.0).x - ideal_a.x
            dy = ideal_point(cycle.length, i, 0.0).y - ideal_a.y
            positions[member] = Point.new(
              positions[a].x + (dx * cos) - (dy * sin),
              positions[a].y + (dx * sin) + (dy * cos)
            )
          end
        end

        # One placed atom: centre the polygon outward, away from the
        # centroid of everything already placed (a spiro centre must
        # not fold the new ring back onto the old one). When this is
        # the first cycle placed, the radial opposite is used.
        def place_anchored_cycle(cycle, positions)
          anchor = cycle.find { |member| positions[member] }
          anchor_index = cycle.index(anchor)
          anchor_pos = positions[anchor]
          vertex_angle = member_angle(cycle.length, anchor_index)
          center_angle = center_angle_away_from_placed(anchor_pos,
                                                       positions,
                                                       vertex_angle)
          # The anchor sits opposite the centre direction, so the
          # shift must put the anchor's own vertex there (+π).
          shift = center_angle + Math::PI - vertex_angle
          radius = polygon_radius(cycle.length)
          center = Point.new(anchor_pos.x + (radius * Math.cos(center_angle)),
                             anchor_pos.y + (radius * Math.sin(center_angle)))
          cycle.each_with_index do |member, i|
            next if positions[member]

            ideal = ideal_point(cycle.length, i, shift)
            positions[member] = Point.new(center.x + ideal.x, center.y + ideal.y)
          end
        end

        def center_angle_away_from_placed(anchor_pos, positions, fallback)
          placed = positions.compact
          return fallback if placed.length < 2

          centroid = Point.new(placed.sum(&:x) / placed.length,
                               placed.sum(&:y) / placed.length)
          Math.atan2(anchor_pos.y - centroid.y, anchor_pos.x - centroid.x)
        end

        # Chains: grow breadth-first from every placed atom, then
        # from isolated atoms, spreading as ±60° zigzags.
        def grow_placed(edges, positions, free_x)
          positions.each_index do |i|
            grow(i, positions, edges) if positions[i]
          end
          free_x
        end

        def place_untethered(atoms, edges, positions, free_x)
          atoms.each_index do |i|
            next if positions[i]

            positions[i] = Point.new(free_x, 0.0)
            free_x += BOND_LENGTH
            grow(i, positions, edges)
          end
        end

        def pair_rings(atoms)
          open_rings = {}
          pairs = []
          atoms.each_with_index do |atom, index|
            next unless atom.ring_closures

            atom.ring_closures.to_s.each_char do |digit|
              if open_rings.key?(digit)
                pairs << [open_rings.delete(digit), index, digit]
              else
                open_rings[digit] = index
              end
            end
          end
          pairs
        end

        def neighbours(edges, node)
          edges.flat_map do |(from, to)|
            next [to] if from == node
            next [from] if to == node

            []
          end
        end

        # Shortest path from one ring-closure partner to the other,
        # excluding the closure bond itself — the ring's atom cycle.
        def ring_cycle(edges, from, to)
          queue = [[from]]
          visited = { from => true }
          until queue.empty?
            path = queue.shift
            node = path.last
            return path if node == to

            neighbours(edges, node).each do |nb|
              closure = (node == from && nb == to) || (node == to && nb == from)
              next if closure || visited.include?(nb)

              visited[nb] = true
              queue << (path + [nb])
            end
          end
          nil
        end

        # Zigzag growth: each generation turns the opposite way from
        # its parent, so chains alternate instead of curling.
        def grow(start, positions, edges)
          visited = { start => [nil, Math.atan2(positions[start].y, positions[start].x), -1] }
          queue = [start]
          until queue.empty?
            current = queue.shift
            next unless positions[current]

            incoming_angle = visited[current][1]
            children = neighbours(edges, current).reject do |n|
              visited.key?(n) || positions[n]
            end
            children.each do |child|
              next if visited.key?(child)

              turn = -visited[current][2]
              angle = incoming_angle + (turn * Math::PI / 3)
              positions[child] = clear_position(positions[current], angle,
                                                positions)
              visited[child] = [current, angle, turn]
              queue << child
            end
          end
        end

        # Try the preferred spot, then spread out; if the preferred
        # spot is occupied (another substituent, a ring atom), fall
        # back to the candidate farthest from any placed atom.
        # Deterministic: first best wins ties.
        def clear_position(from_pos, angle, positions)
          candidates = [0.0, -Math::PI / 3, Math::PI / 3,
                        -2 * Math::PI / 3, 2 * Math::PI / 3,
                        Math::PI].map do |spread|
            candidate_angle = angle + spread
            Point.new(from_pos.x + (BOND_LENGTH * Math.cos(candidate_angle)),
                      from_pos.y + (BOND_LENGTH * Math.sin(candidate_angle)))
          end
          occupied = positions.compact
          candidates.each do |candidate|
            return candidate if occupied.all? do |other|
              distance(candidate, other) >= COLLISION_RADIUS
            end
          end
          candidates.max_by { |candidate| occupied.sum { |other| distance(candidate, other) } }
        end

        def distance(first_point, second_point)
          Math.sqrt(((first_point.x - second_point.x)**2) +
                    ((first_point.y - second_point.y)**2))
        end

        def polygon_radius(sides)
          BOND_LENGTH / (2 * Math.sin(Math::PI / sides))
        end

        def member_angle(sides, index)
          (Math::PI * 2 * index / sides) - (Math::PI / 2)
        end

        def place_polygon(members, center, radius, shift, positions)
          members.each_with_index do |atom, i|
            angle = member_angle(members.length, i) + shift
            positions[atom] = Point.new(center.x + (radius * Math.cos(angle)),
                                        center.y + (radius * Math.sin(angle)))
          end
        end

        # The ideal polygon vertex position relative to the centre.
        def ideal_point(sides, index, shift)
          radius = polygon_radius(sides)
          angle = member_angle(sides, index) + shift
          Point.new(radius * Math.cos(angle), radius * Math.sin(angle))
        end
      end
    end
  end
end
