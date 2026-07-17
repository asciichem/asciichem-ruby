# 02 — Spectroscopy: NMR / IR / MS spectra

- **Priority:** P2
- **Status:** pending

## Syntax

```
spectrum[nmr](type=1H,solvent=CDCl3,freq=400){
  1.2: 3H s "CH3"
  3.5: 2H q J=7 "CH2"
  7.2: 5H m "C6H5"
}

spectrum[ir]{
  3300: broad "O-H stretch"
  1700: strong "C=O stretch"
}

spectrum[ms]{
  18: 100% "M+"
  17: 23% "M-1"
}
```

## Model

```ruby
class Spectrum < Node
  attr_accessor :type, :params, :peaks
  # peaks: [{position:, intensity:, multiplicity:, assignment:}, ...]
end
```

## CML mapping

Maps to `<spectrum>` with `<peakList>` containing `<peak>` children.
CML peak attributes: `xValue`, `xUnits`, `yValue`, `yUnits`,
`atomRefs`, `title`.
