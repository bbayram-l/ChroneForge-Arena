# ChronoForge Arena — Codex Context

## Active branch
`Codex/explain-codebase-mm9o56vfv7thwb49-2Kti4`

Always develop on this branch. Push with:
```
git push -u origin Codex/explain-codebase-mm9o56vfv7thwb49-2Kti4
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

## What is built (Month 3 — complete)

- [x] Physics gaps wired — `gyro_stabilizer` (-30% torque in `stability_modifier`), `shock_bracing` (-50% recoil in `apply_recoil`)
- [x] `power_router` — doubles adjacency bonus to +10% per power neighbor in `PowerSystem.cell_efficiency`
- [x] `accuracy_penalty` fed into damage formula — `(1 − acc_pen)` multiplier in `CombatEngine._fire_weapon`; `future_sight` reduces it by 0.15
- [x] `emp_burst` — locks one random opponent module for 3 s with timed re-enable; no direct damage
- [x] `reactive_armor` — 30% burst reduction once every 3 s (uses existing `_p/_e_burst_ready` timers)
- [x] `reflective_field` — reflects 20% of raw incoming damage back at attacker
- [x] `future_sight` — 10% incoming shot dodge chance; -15% accuracy penalty on owned weapons
- [x] `pre_fire_snapshot` — all weapons fire once before the main loop starts
- [x] `rewind_shield` — restores shield to 2-second-ago snapshot on first depletion (one-shot)
- [x] `overdrive_vent` — dumps all quadrant heat when any quadrant hits DISABLE_THRESHOLD; costs 15 HP
- [x] `timeline_split` — 2× damage multiplier on all weapons for first 1.5 seconds of combat
- [x] `entropy_field` — reduces opponent weapon damage by 15% every second (floor 0.3×)
- [x] `capacitor_bank` — explodes on paradox overload; 30 self-damage to owning mech
- [x] HudPanel paradox bar — purple 4th row, PDX +/s rate; turns red above 30/s

### Known gaps (deferred Month 4+)
- `joint_lock` stat effect not wired (no combat mechanic defined yet)
- Paradox meter live update during combat (HUD shows build-time rate only)
- Overload flash / visual feedback on module disable
- `temporal_barrier` DEFENSE special (paradox_rate accumulates correctly; counter mechanic TBD)

## What is built (Month 4 — complete)

- [x] Player lives — 3 lives, lose 1 per loss, draws are neutral (no life lost)
- [x] Run-over screen — `Phase.RUN_OVER` overlay with rounds/wins/losses/MMR stats + RESTART button
- [x] REROLL button — wired to existing `reroll_shop()`, cost shown inline, disabled during combat
- [x] SELL mode — toggle button in shop phase; click a grid cell to sell module for half cost
- [x] Grid save — `_save_player_grid()` writes `user://player_grid.json` after every fight (async PvP foundation)
- [x] Draw outcome — `earn_round_income("draw")` advances round, no life cost, no win bonus
- [x] Status bar lives — ♥♥♥ / ♡ hearts display in HUD status line
- [x] Timeout balance fix — HP% comparison at MAX_TICKS (10% threshold → draw); enemy wins if ahead
- [x] Enemy scaling fix — 4-tier slot system: 4–6 modules (T0) → 7–9 (T1) → 10–12 (T2) → 12–14 (T3)

## What is built (Month 5 — complete)

- [x] Module upgrade system — UPGRADE button in shop phase; click any placed module to spend gold
  and advance it from ★1 → ★2 → ★3 (max). Cost = `cost × current_star_level`.
- [x] Stat boost — each star: base_damage / power_gen / shield_value / heat_reduction / hp × 1.2×
- [x] Duplicate on placement — `MechGrid.place_module` now duplicates the Module Resource so every
  placed copy has independent stats/star_level/disabled state; fixes shared-reference bugs
- [x] Serialize star_level — `player_grid.json` snapshot now includes star levels; deserialize
  re-applies upgrades so async PvP replays see correct stats
- [x] Star display — upgraded cells show ★ / ★★ beneath the module name in MechGridView
- [x] Sell refund includes upgrade investment — refund = `cost × star_level / 2`

## What is built (Month 6 — complete)

- [x] 24 new modules — 36 → 60 total (demo target hit)
  - STRUCTURAL +3: Carbon Weave (COMMON), Blast Plating (UNCOMMON), Armored Chassis (RARE)
  - POWER +3: Solar Tap (COMMON), Fusion Core (RARE), Overcharge Cell (EPIC)
  - WEAPON +6: Scatter Burst / Auto Turret (COMMON/UNCOMMON), Twin Blaster (UNCOMMON),
    Arc Lance / Void Spike (RARE), Siege Cannon 2×2 (EPIC)
  - DEFENSE +3: Ablative Plating (COMMON), Dampening Shell (RARE), Fortress Shell 2×1 (EPIC)
  - THERMAL +3: Thermal Wick (COMMON), Phase Cooler (UNCOMMON), Cryo Injector (RARE)
  - TEMPORAL +3: Stasis Matrix (RARE), Time Dilation (EPIC), Void Resonator (LEGENDARY)
  - AI +3: Overload Safeguard (UNCOMMON), Repair Drone / Targeting Jammer (RARE)
- [x] `repair_drone` wired — regen 1 HP/tick (10 HP/sec) capped at starting max
- [x] `targeting_jammer` wired — adds 0.15 accuracy penalty to all shots fired at the owner
- [x] Ghost ladder — after each fight the enemy grid is saved to `user://ghost_{round}.json`;
  next time the same round comes up there is a 30% chance to load it instead of generating
  a new procedural enemy (async PvP simulation foundation)

## What is built (Month 7 — complete)

- [x] Disabled-module visual — overloaded/heat-disabled cells render darkened (0.65×) in MechGridView;
  both grids refresh immediately after `run_simulation()` so the state is visible before NEXT ROUND
- [x] Hover tooltip — hovering any player grid cell shows a sidebar panel with full module stats,
  star level, upgrade cost (or DISABLED / MAX STAR status)
- [x] Combat log — label below the enemy grid shows post-fight summary: outcome, total damage +
  shot counts per side, last 7 notable events (dodges, overloads, EMP, reflect, rewind, vent, reactive)
- [x] MechGridView `cell_hovered` / `cell_unhovered` signals added

### Known gaps (deferred Month 8+)
- `joint_lock` stat effect not wired
- Real async PvP server (upload/download grids, leaderboard)
- Steam demo build: export preset, main menu, resolution toggle, splash screen
- Balance pass now that 60 modules exist

Month 8 → Steam demo prep (main menu, export, resolution), balance pass

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
