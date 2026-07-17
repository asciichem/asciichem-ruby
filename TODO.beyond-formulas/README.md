# TODO.beyond-formulas index

Expanding AsciiChem beyond molecular formulas into the full CML
domain. Each workstream adds a new construct type with grammar,
model, formatter, and CML round-trip support.

## Phase 1: Crystallography

| # | Title | Status |
|---|---|---|
| 01 | [Crystallography — unit cell and space group](01-crystallography.md) | **in progress** |

Syntax: `crystal[NaCl](a=5.64,b=5.64,c=5.64,alpha=90,beta=90,gamma=90,sg=Fm-3m){Na@f(0,0,0) Cl@f(0.5,0.5,0.5)}`

## Phase 2: Spectroscopy

| # | Title | Status |
|---|---|---|
| 02 | [NMR / IR / MS spectra](02-spectroscopy.md) | pending |

Syntax:
```
spectrum[nmr](type=1H,solvent=CDCl3){
  1.2: 3H s "CH3"
  7.2: 5H m "ArH"
}
```

## Phase 3: Computational Chemistry

| # | Title | Status |
|---|---|---|
| 03 | [QC calculation results](03-compchem.md) | pending |

Syntax: `calc(b3lyp/6-31G*){energy:-234.5 dipole:[0.1,0.2,0.3]}`

## Phase 4: Structural Extensions

| # | Title | Status |
|---|---|---|
| 04 | [Z-Matrix and fragments](04-structural.md) | pending |

Syntax:
```
zmatrix{C1; H2 C1 1.09; H3 C1 1.09 H2 109.5}
fragment(phenyl){C1-C2=C3-C4=C5-C6=1}
```

## Phase 5: Reaction Mechanisms

| # | Title | Status |
|---|---|---|
| 05 | [Mechanisms and spectators](05-mechanisms.md) | pending |

Syntax: `mechanism{step: A->[TS:B*]->C; spectator:Na+}`

## Architecture

Each domain adds:
1. A new `Model::*` class (autoload from `lib/asciichem/model/`)
2. A grammar rule in `grammar.rb`
3. A transform rule in `transform.rb`
4. `visit_*` methods on formatters (Text, CML, others as needed)
5. ModelAdapter mapping to `Chemicalml::Cml::*` wire classes
6. Specs

The OCP principle: each domain is a self-contained construct that
plugs into the existing `Formula` → `nodes` array. No changes to
existing model classes.
