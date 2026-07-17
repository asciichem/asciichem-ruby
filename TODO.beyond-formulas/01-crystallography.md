# 01 — Crystallography: unit cell and space group

- **Priority:** P1
- **Status:** in progress

## Motivation

Crystallography is the foundation of materials science. CML's
`<crystal>`, `<scalar>` (for a/b/c/α/β/γ), and `<symmetry>` elements
capture crystal structures. An ASCII encoding is dramatically more
readable than XML:

```
crystal[NaCl](a=5.64,b=5.64,c=5.64,alpha=90,beta=90,gamma=90,sg=Fm-3m){
  Na@f(0,0,0)
  Cl@f(0.5,0.5,0.5)
}
```

vs CML's verbose `<crystal><scalar title="a">5.64</scalar>...`.

## Syntax design

```
crystal[<name>](
  a=<float>, b=<float>, c=<float>,
  alpha=<float>, beta=<float>, gamma=<float>,
  sg=<spacegroup>
) {
  <atoms with @f(x,y,z) fractional coords>
}
```

- `crystal` is a keyword (not an element symbol — parsed before
  molecule).
- Square brackets carry the optional crystal name/title.
- Parentheses carry unit cell parameters as `key=value` pairs.
- Curly braces carry the asymmetric unit atoms with fractional coords.
- `sg` is the Hermann-Mauguin space group symbol.

## Model

```ruby
class Crystal < Node
  attr_accessor :name, :a, :b, :c, :alpha, :beta, :gamma,
                :spacegroup, :atoms
end
```

Atoms inside a crystal use `@f(x,y,z)` fractional coordinates
(already implemented in v0.3.4).

## CML mapping

- `Crystal` → `<crystal>` with child `<scalar>` elements for cell
  parameters and `<symmetry>` for space group.
- Atoms with fractional coords → `<atom xFract="..." yFract="..."`
  zFract="..."/> inside `<atomArray>`.
- The crystal is a child of `<molecule>` (CML convention: crystal
  structures live inside molecules).

## Acceptance criteria

- [ ] `crystal[NaCl](...)` parses to a Crystal model node
- [ ] Text round-trip: `parse(s).to_text == s`
- [ ] CML round-trip: `parse(s).to_cml → parse → .to_text == s`
- [ ] Cell parameters carry through as CML `<scalar>` elements
- [ ] Space group carries as CML `<symmetry>` element
- [ ] Fractional coordinates on atoms (already supported)
