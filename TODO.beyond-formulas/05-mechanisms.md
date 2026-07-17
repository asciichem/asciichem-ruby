# 05 — Reaction mechanisms and spectators

- **Priority:** P3
- **Status:** pending

## Syntax

### Reaction mechanism

```
mechanism{
  step1: Cl- + CH3Br -> [TS: Cl...C...Br] -> ClCH3 + Br-
  step2: ClCH3 + Na+ -> CH3Cl + Na+
  spectator: Na+
}
```

### Spectator ions

```
Ag+(aq) + Cl-(aq) -> AgCl(s) | spectator: Na+(aq) NO3-(aq)
```

Inline notation: `| spectator: <atoms>` after the reaction.

## Model

```ruby
class Mechanism < Node
  attr_accessor :steps, :spectators, :reactive_centre
  # steps: [{label:, transition_state:, reaction:}, ...]
end
```

## CML mapping

Mechanism → `<reactionScheme>` with `<reactionStepList>`
containing `<reactionStep>` children.
Spectators → `<spectatorList>` with `<spectator>` children.
ReactiveCentre → `<reactiveCentre>` with atom references.
