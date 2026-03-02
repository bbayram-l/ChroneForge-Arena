# ChronoForge Arena — Claude Code Context

## Active branch
`claude/explain-codebase-mm9o56vfv7thwb49-2Kti4`

Always develop on this branch. Push with:
```
git push -u origin claude/explain-codebase-mm9o56vfv7thwb49-2Kti4
```

---

## Project summary
Deterministic, grid-based roguelike auto-battler. Players build modular mechs on a 6×6 grid, balance power / heat / torque / paradox, and fight asynchronous PvP opponents via snapshot replay.

**Engine:** Godot 4.6 — GDScript, Mobile renderer
**Model:** Premium $14.99, cosmetics only, no P2W
**Scope:** Solo-dev viable

---

## Design documents
| File | Contents |
|---|---|
| `README.md` | Core pillars, module list, rarity table, archetypes, formulas, roadmap |
| `SYSTEM` | Full balance math, rarity tiers, archetype definitions |
| `BALANCING` | Anti-meta strategy, counter matrix, meta taxes, patch workflow |
| `architecture` | Tech stack, system layers, server strategy |
| `CONTEXT` | High-level design intentions and constraints |

---

## Codebase structure

```
project.godot               Godot 4.6 project config (autoloads declared)
scenes/
  Main.tscn                 Entry-point scene (references scripts/ui/Main.gd)
scripts/
  autoload/
    GameState.gd            Run economy, income formula, MMR (singleton)
    ModuleRegistry.gd       Loads data/modules.json at startup (singleton)
  modules/
    Module.gd               Base Resource — all stat fields for every module
  grid/
    GridCell.gd             Single cell: module ref, heat, structural load
    MechGrid.gd             6×6 grid: placement, adjacency queries, serialize
  systems/
    PowerSystem.gd          Gen/draw ratio + adjacency efficiency (cap 1.2×)
    HeatSystem.gd           Quadrant heat tracking, dissipation, disable threshold
    PhysicsLite.gd          Center-of-mass, torque imbalance, recoil drift
    ParadoxSystem.gd        Paradox accumulation, meta taxes, overload rolls
  combat/
    DamageResolver.gd       Pure static helpers — all formulas from SYSTEM doc
    CombatEngine.gd         Deterministic tick loop (10 ticks/sec) + event log
  shop/
    ShopSystem.gd           Rarity-weighted rolls, temporal bias, reroll
  ui/
    Main.gd                 Game-loop coordinator: shop → combat → round end
data/
  modules.json              35 MVP modules across 7 categories
```

---

## Key design decisions

### Five systems interact — none dominates
`FinalDamage = BaseDamage × PowerEfficiency × StabilityModifier × TemporalModifier × RandomVariance`

- **Power:** `AvailablePower / RequiredPower`, capped at 1.2×. Adjacent power modules give +5% each.
- **Heat:** Quadrant-based (TL/TR/BL/BR). Penalty starts at 100 heat, module disables at 150.
- **Torque:** `StabilityModifier = 1 − (TorqueImbalance × 0.5)`. Center-of-mass drift from weapon placement.
- **Paradox:** Accumulates from Temporal modules. Overload chance = `(Paradox − 100) × 0.02` per second. ≥4 Temporal = +20% gain rate; ≥6 = +50% + extra roll.
- **Economy:** Interest capped at 5 gold. Shop odds shift at round 6 and 11. Reroll cost scales mid/late.

### Rarity = variance, not raw power
Common → stable. Legendary → rule-breaking but inconsistent and counterable.

### No infinite scaling
`StackModifier = 1 / (1 + 0.15 × (Stacks − 1))` applied globally. Hard caps: attack speed ≤2×, shield efficiency ≤1.8×, power efficiency ≤1.2×, paradox reduction ≤60%.

### Async PvP only at launch
No real-time multiplayer. Enemy grids are serialized snapshots. `MechGrid.serialize()` / `MechGrid.deserialize()` handle this.

---

## What is built (Month 1 MVP — complete)

- [x] Grid system — 6×6 placement, adjacency queries, serialization
- [x] Module data — 35 modules: STRUCTURAL / POWER / WEAPON / DEFENSE / THERMAL / TEMPORAL / AI
- [x] Power system — generation, draw, adjacency efficiency
- [x] Heat system — quadrant tracking, dissipation, overheat penalties
- [x] Physics-lite — center-of-mass, torque imbalance, recoil displacement
- [x] Paradox system — accumulation, meta taxes, overload signal
- [x] Damage resolver — all combat formulas as pure static helpers
- [x] Combat engine — deterministic tick loop, event log, result dictionary
- [x] Shop system — rarity-weighted rolls with temporal bias per round
- [x] Game state — run economy, income, MMR
- [x] Main loop — shop → combat → round-end coordinator

---

## What comes next (Month 2)

- [ ] Visual grid scene — `TileMap` or `GridContainer` for the 6×6 mech builder
- [ ] Drag-and-drop module placement UI
- [ ] HUD — heat bars per quadrant, paradox meter, power state indicator
- [ ] Torque visualizer — center-of-mass marker on grid
- [ ] Shop UI — card display with rarity colour coding
- [ ] AI module logic — `targeting_matrix`, `burst_logic`, `counter_program` effects
- [ ] Enemy mech generator — simple archetype-based builds for async PvP prototype

Month 3 → temporal system effects, paradox visuals, balance pass
Month 4 → async PvP snapshots, replay viewer, Steam demo build

---

## Lint rules to keep clean
GDScript warnings seen so far — apply these patterns consistently:

| Issue | Fix |
|---|---|
| `SHADOWED_GLOBAL_IDENTIFIER` — local var/param named `seed` | Rename to `rng_seed` or `combat_seed` |
| Cannot infer type from `Dictionary` value via `:=` | Use explicit annotation e.g. `var x: float = dict.key` |

---

## Module categories quick reference
`STRUCTURAL` · `POWER` · `WEAPON` · `DEFENSE` · `THERMAL` · `TEMPORAL` · `AI`

Rarity enum: `COMMON` · `UNCOMMON` · `RARE` · `EPIC` · `LEGENDARY`

To add a new module: add an entry to `data/modules.json`. No code changes required.

---

## Archetype counter matrix (balance reference)
| Archetype | Hard counters |
|---|---|
| Burst / Alpha (Temporal Assassin, Recoil Berserker) | Reactive Armor, Temporal Barrier, Targeting Jammer AI |
| Fortress (shield stacking) | EMP Burst, Entropy Field, Overdrive Vent pressure |
| Ramp / Scaling (Thermal Overdrive, Paradox Gambler) | Chrono Anchor, sustained DPS, cooling denial |

Healthy meta targets: top build winrate 55–58%, ≥3 viable archetypes at high MMR, avg fight 10–18 sec.
