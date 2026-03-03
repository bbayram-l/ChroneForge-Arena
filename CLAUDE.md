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
    MechGridView.gd         Programmatic 6×6 panel grid + torque visualizer overlay
    ShopPanel.gd            5-card rarity-coloured shop with module_selected signal
    HudPanel.gd             PWR/STAB/HEAT bars + PDX rate / AI info line
data/
  modules.json              36 MVP modules across 7 categories
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
- [x] Module data — 36 modules: STRUCTURAL(5) / POWER(4) / WEAPON(8) / DEFENSE(5) / THERMAL(4) / TEMPORAL(6) / AI(4)
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

- [x] Visual grid scene — `MechGridView` (programmatic 6×6 panel grid, category-coloured)
- [x] Click-to-place module UI — `ShopPanel` cards + cell click → placement flow
- [x] Enemy mech generator — 3 seeded archetypes (BRAWLER / FORTRESS / SKIRMISHER)
- [x] Round loop — READY button starts combat, NEXT ROUND continues
- [x] HUD — `HudPanel`: PWR / STAB / HEAT progress bars with traffic-light colour, PDX rate + AI info line
- [x] Torque visualizer — `MechGridView._draw()` overlays orange COM dot + white ideal-centre crosshair
- [x] AI module logic — `targeting_matrix` (+10% dmg), `burst_logic` (1.4× dmg / 2× CD), `counter_program` (retaliation shot), `chrono_anchor` (20% opponent PDX reduction)

### Month 1 cross-check bugs fixed
- `ParadoxSystem._trigger_overload` used global `randi()` → now uses seeded `rng` (determinism fix)
- `ParadoxSystem.tick()` only accumulated from TEMPORAL category → now uses `paradox_rate > 0` (catches echo_cannon, temporal_barrier)
- `CombatEngine._fire_weapon()` used pre-capped global power ratio → now computes `raw_ratio × cell_efficiency` so adjacency bonus is actually applied

### Known gaps (deferred Month 3+)
- gyro_stabilizer / shock_bracing stat effects not wired in PhysicsLite
- power_router enhanced adjacency (+10%) not wired in PowerSystem
- emp_burst lock, capacitor_bank explosion, all Temporal specials — unimplemented
- PhysicsLite.accuracy_penalty() computed but not fed into damage formula

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
