# 03 — Computational chemistry: QC calculation results

- **Priority:** P2
- **Status:** pending

## Syntax

```
calc(dft, b3lyp/6-31G*){
  energy: -234.5 Hartree
  dipole: [0.1, 0.2, 0.3] Debye
  homo: -0.32 Hartree
  lumo: 0.15 Hartree
  gap: 0.47 Hartree
  zpe: 0.05 Hartree
}
```

## Model

```ruby
class Calculation < Node
  attr_accessor :method, :basis, :properties
  # properties: [{title:, value:, units:}, ...]
end
```

## CML mapping

Maps to `<module convention="convention:compchem">` containing
`<parameterList>` (method/basis) and `<propertyList>` (results).
