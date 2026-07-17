# 04 — Structural extensions: Z-Matrix and fragments

- **Priority:** P3
- **Status:** pending

## Syntax

### Z-Matrix

```
zmatrix{
  C1
  H2  C1  1.09
  H3  C1  1.09  H2  109.5
  H4  C1  1.09  H2  109.5  H3  120.0
}
```

Each line: atom, reference atom, bond length, [reference atom, angle,
[reference atom, dihedral]].

### Fragments

```
fragment(phenyl){
  C1-C2=C3-C4=C5-C6=1
}
```

Named structural fragments that can be referenced by other molecules.

## Model

```ruby
class ZMatrix < Node
  attr_accessor :rows
  # rows: [{atom:, ref1:, r12:, ref2:, angle:, ref3:, dihedral:}, ...]
end

class Fragment < Node
  attr_accessor :name, :molecule
end
```

## CML mapping

ZMatrix → `<zMatrix>` with rows as `<atom>` references.
Fragment → `<fragment>` containing a `<molecule>`.
