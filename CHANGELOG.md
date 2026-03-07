# ChronoForge Arena — Changelog

---

## [Unreleased]

### Balance Changes

- **Structural frame tuning (cost/HP pass):**
  - **Reinforced Frame** — cost **3 -> 4**, HP **40 -> 36**.
    Still a high-HP common, but no longer the most efficient early-buy tank piece.
  - **Carbon Weave** — HP **6 -> 8** (cost remains **2**).
    Keeps the ultra-light identity while making the downside less punishing.
  - **Light Frame** — unchanged at cost **2**, HP **10**.
    Remains the baseline common structural filler.

---

## [0.9.2] — Balance Pass v3 — 2026-03-06

### Balance Changes
Data-driven pass from session log analysis (TEMPORAL_ASSASSIN, 8 rounds).
Root findings: heat/paradox activated 0 times; pre_fire_snapshot fired all weapons
with one copy; enemy tier-2 had ★3 weapons at round 8; player ran out of gold.

- **Pre-Fire Snapshot** — each copy now fires **exactly ONE weapon** (was: one
  copy = all weapons fire). Hard cap prevents the opening volley from scaling
  with grid size. Stacking 2 snapshots fires 2 weapons. 0.8× penalty unchanged.
- **Temporal Paradox Pre-load** — raised **5 → 8 per TEMPORAL module**. A
  2-Temporal build now starts at 16/100 PDX (was 10). Temporal downside is
  felt even in 1–3 second fights.
- **Weapon Heat Generation** — all 14 weapon modules ×1.5 heat_gen.
  (`scatter_burst` 3→4.5 / `shard_cannon` 5→7.5 / `railgun` 20→30 /
  `arc_lance` 20→30 / `siege_cannon` 35→52.5). Heat system was invisible in
  play; higher generation makes quadrant thresholds reachable mid-fight.
- **Reflective Field** — minimum **8 raw damage** required to reflect.
  Scatter_burst pellets (5 base dmg) no longer spam 20+ trivial reflect events
  per fight. Only meaningful shots trigger the reflect log and HP cost.
- **Enemy Star Scaling** — tier 2 (rounds 8–11) capped at **★2 for all
  modules** (was: ★3 weapons). Tier 3 (round 12+) gives weapon ★3, others ★2.
  Round 8 enemy had 4× ★3 weapons vs a player with all ★1 modules — wall.
- **Base Income** — raised **5 → 6 gold per round**. Players were hitting 0
  gold before multiple rounds with 16 modules all at ★1; the extra gold
  enables at least one upgrade cycle per typical run.

---

## [0.9.1] — Balance Pass — 2026-03-06

### Temporal Stack Nerfs
The Temporal archetype was ending fights in 0–3 ticks, bypassing heat, paradox, and
torque systems entirely. These changes keep Temporal builds viable while ensuring the
five combat systems stay visible throughout a fight.

- **Pre-Fire Snapshot** — shots now deal **0.8× damage** (snapshot penalty: unguided
  opening volley fires before targeting lock). Temporal builds no longer instant-kill
  late-game enemies on the opening volley.
- **Pre-Fire Snapshot + Timeline Split** — pre-fire no longer benefits from the Timeline
  Split 2× window. They are distinct mechanics; Timeline Split now applies only to the
  main combat loop.
- **Timeline Split** — active damage multiplier reduced **2.0× → 1.5×**. Still a
  powerful opening window; no longer near-instant-kill on its own.
- **Entropy Field** — debuff floor raised **0.3× → 0.5×** (opponent weapons can now be
  suppressed by at most 50%, not 70%). Tick interval slowed **1.0s → 1.5s** so the
  ramp-up takes longer and only dominates in extended fights.
- **Temporal Paradox Pre-load** — combat now starts with `5 × temporal_module_count`
  paradox. A 6-Temporal build begins at 30/100 threshold; the meta tax and overload
  risk apply from tick 1 instead of being irrelevant in short fights.

### Bug Fixes
- **joint_lock** now correctly **consumes itself** (disables) when it absorbs a paradox
  overload. Previously it could absorb unlimited overloads for free.

### Synergy Bonuses (now combat-active)
All six synergies were display-only; they are now wired into the combat simulation:

| Synergy | Categories | Effect |
|---|---|---|
| Overcharge | POWER + WEAPON | +8% weapon damage |
| Heat Sink | THERMAL + WEAPON | −30% heat generated per shot |
| Fortress | STRUCTURAL + DEFENSE | +15% starting HP |
| Echo Shot | TEMPORAL + WEAPON | 5% chance to re-fire at full damage |
| Targeting | AI + WEAPON | −5% accuracy penalty |
| Flux | POWER + TEMPORAL | −10% paradox gain rate |

---

## [0.9.0] — Month 9: Steam Demo Prep — 2026-03-06

### New Features

#### Five Archetypes / Captain Select
Choose your identity before the run starts. Each archetype has a unique passive,
a starter module, a strength, a weakness, and an explicit counter.

| Archetype | Passive | Starter |
|---|---|---|
| Recoil Berserker | +25% weapon damage; double recoil (accuracy degrades with shots) | Railgun |
| Thermal Overdrive | +25% damage while quadrant heat ≥ 50 | Plasma Saw |
| Temporal Assassin | Temporal weapons fire 15% faster | Pre-Fire Snapshot |
| Fortress Stabilizer | Shields start 25% higher; gyro_stabilizer torque reduction doubled | Energy Shield |
| Paradox Gambler | +30% damage when paradox > 80 | Capacitor Bank |

#### Combat Replay
After every fight a **▶ REPLAY FIGHT** button appears on the results panel.
- Plays back the fight at 10 ticks/sec (1× or 2× speed)
- HP, shield, and paradox bars update each tick
- Keyword badges show live BURN / CRACK / OVERCHARGE stacks
- Rolling event feed shows shots, dodges, overloads, EMP locks, reflects, vents
- 0-tick fights (pre-fire kills) show **PRE-FIRE WIN** with all opening-volley events

#### Status Keywords
Three combat keywords now apply mid-fight:
- **BURN** — Heat-generating weapons apply DoT stacks (0.5 HP/tick per stack).
  Decays 2 stacks/sec per THERMAL module; Overdrive Vent clears all Burn.
- **CRACK** — High-recoil weapons (recoil_force > 1) add structural stress to the
  shooter (+2% accuracy penalty per stack). Decays via Blast Plating (1 stack / 2s).
- **OVERCHARGE** — Power surplus > 1.1× reduces paradox gain by 10% per tick.

#### Post-Battle Results Panel
Dedicated overlay after every fight showing outcome, HP remaining, fight duration,
and a summary of notable events (overloads, dodges, EMP locks, reflections, etc.).

### UI Polish
- **Resolution** — 1280×720 → **1280×800** to fit all HUD rows without clipping
- **Fullscreen toggle** — fixed on Windows 11 (was using deprecated
  `DisplayServer.window_set_mode`; now uses `get_window().mode`)
- **Combat log** — moved from below the enemy grid to a dedicated right-sidebar panel;
  no longer overlaps the grid
- **Shop cards** — purchased cards now disappear immediately; remaining cards compact left
- **HUD** — added heat-per-quadrant bars (TL / TR / BL / BR) and paradox-rate meter
- **Shop cards** — category badge (letter icon + colour) and synergy hint tag shown on
  each card when the module would activate a synergy with your current grid
- **Grid overlay** — active synergy categories draw a coloured border around affected cells

### Shop
- Shop size increased **5 → 7 cards** per round

---

## [0.8.0] — Month 8 — 2024-xx-xx

- Main menu scene with PLAY / FULLSCREEN buttons
- Fullscreen toggle wired (fixed in 0.9.0)
- `joint_lock` signal stub (consumption fixed in 0.9.1)

---

## [0.7.0] — Month 7 — 2024-xx-xx

- Disabled-module darkened visual (both grids refresh post-fight)
- Hover tooltip on player grid cells (full stats, star level, upgrade cost)
- Post-fight combat log (last 7 notable events)
- `MechGridView` cell_hovered / cell_unhovered signals

---

## [0.6.0] — Month 6 — 2024-xx-xx

- **60 modules** total (up from 36) across all 7 categories
- `repair_drone` — regenerates 1 HP/tick (10 HP/s), capped at starting max
- `targeting_jammer` — adds 0.15 accuracy penalty to all incoming shots
- Ghost ladder — enemy grids saved to `user://ghost_{round}.json`; 30% replay chance

---

## [0.5.0] — Month 5 — 2024-xx-xx

- Module upgrade system ★1 → ★2 → ★3 (cost = base_cost × current_star)
- Each star: ×1.2 to base_damage / power_gen / shield_value / heat_reduction / hp
- Star level serialised into `player_grid.json` for async PvP replay
- Star display (★ / ★★) shown on grid cells
- Sell refund includes upgrade investment (refund = cost × star_level / 2)

---

## [0.4.0] — Month 4 — 2024-xx-xx

- **3 player lives** — lose 1 per loss; draws are neutral
- Run-over screen with rounds / wins / losses / MMR stats + RESTART button
- REROLL button (cost scales by round: 2 / 3 / 4 scrap)
- SELL mode — click a placed module to sell for half cost
- Grid save — `user://player_grid.json` written after every fight
- Draw outcome — timeout with < 10% HP difference = draw; round advances, no life lost
- Enemy scaling — 4-tier slot system tied to round number

---

## [0.3.0] — Month 3 — 2024-xx-xx

All special module effects wired:
- `gyro_stabilizer` — −30% torque imbalance (−60% for FORTRESS_STABILIZER archetype)
- `shock_bracing` — −50% recoil accumulation
- `power_router` — doubles adjacency bonus to +10% per power neighbour
- `accuracy_penalty` — fed into damage formula; `future_sight` reduces by 0.15
- `emp_burst` — locks one random opponent module for 3s
- `reactive_armor` — 30% burst reduction once every 3s
- `reflective_field` — reflects 20% of raw incoming damage
- `future_sight` — 10% dodge chance; −15% accuracy penalty on own weapons
- `pre_fire_snapshot` — all weapons fire once before the main loop
- `rewind_shield` — restores shield to 2-second-ago snapshot on first depletion
- `overdrive_vent` — dumps all quadrant heat at disable threshold; costs 15 HP
- `timeline_split` — 1.5× damage on all weapons for first 1.5s (was 2.0×; nerfed 0.9.1)
- `entropy_field` — reduces opponent weapon damage by 15% every 1.5s (floor 0.5×)
- `capacitor_bank` — explodes on paradox overload; 30 self-damage
- HUD paradox bar (purple, turns red above 30/s)

---

## [0.2.0] — Month 2 — 2024-xx-xx

- `MechGridView` — programmatic 6×6 grid, category-coloured cells
- `ShopPanel` — 5 rarity-coloured cards + `module_selected` signal
- `EnemyMechGenerator` — 3 seeded archetypes (BRAWLER / FORTRESS / SKIRMISHER)
- Round loop — READY starts combat, NEXT ROUND continues
- `HudPanel` — PWR / STAB / HEAT progress bars, PDX rate, AI info line
- Torque visualiser — CoM dot + ideal-centre crosshair overlay

---

## [0.1.0] — Month 1 — 2024-xx-xx

Core systems built:
- 6×6 placement grid with adjacency queries and serialization
- 36 base modules across 7 categories
- Power, Heat, Physics-Lite, Paradox systems
- Damage resolver (all combat formulas)
- Deterministic tick-loop combat engine
- Shop system with rarity-weighted rolls
- Run economy (interest, MMR, income)
