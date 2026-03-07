# ChronoForge Arena — Reference Game Analysis

## Source material
- **Down with the Ship** (DWTS) — `refs/Screenshot_30–42`
- **The Bazaar** — Tempo Games, card-based auto-battler

---

## Down with the Ship

### What it does well

| Feature | Screenshot | CFA status |
|---|---|---|
| Live combat (2× speed toggle) | 31, 32 | Instant — no feedback loop |
| Post-battle tabs: Summary / DPS List / Combat Log / Graph | 41 | Sidebar event log only |
| Stat tooltip: current `84%` + base `(80%)` side-by-side | 35 | Shows post-upgrade values only |
| 9-item shop (3×3 grid) | 30, 33 | 5 cards; now 7 |
| Faction synergies *modify* shop availability | 38 (Strike Optimizer) | Display-only badges |
| Status keywords: Acid, Cracks, Stun | 34, 38 | Ad-hoc specials per module |
| Captain portraits as build seeds | 36, 42 | No archetype selection |
| Multi-currency: Ammo / Fuel / Electricity | 30 HUD | Single gold currency |
| Organic/asymmetric hull shapes | 30, 31 | Strict 6×6 (intentional) |

### Key design principles extracted

1. **Stat transparency** — players must always see base vs buffed. DwtS shows `(80%)` baseline in every tooltip.
2. **Post-battle analytics** — damage dealt, shots fired, stun time, HP restored per side. Creates learning loops without live play.
3. **Shop as build driver** — faction-specific items appear in shop when you own a matching captain/optimizer. The shop *reacts* to your build state.
4. **Status types as cross-item language** — Acid is produced by one item, triggered/amplified by another. Items talk to each other through shared nouns.

---

## The Bazaar

### What it does well

| Feature | CFA status |
|---|---|
| Keyword chains (Burn / Freeze / Poison / Ammo / Shield) | Ad-hoc specials |
| Enchanting — modifiable bonus on any item | Star upgrades only (★1–3) |
| Hero-specific starting item shapes entire run | 3 fixed starter modules |
| Item sizes S/M/L/Unique create slot pressure | `grid_size` exists but underused |
| Visible real-time combat replay | Instant simulation |
| Multicast (item fires N times per trigger) | Not implemented |
| Interest economy: +5 max on 10-gold increments | Identical — validated |
| Anti-stall: Poison/Burn damage escalates over time | Timeout + HP% comparison |

### Key design principles extracted

1. **Keyword = shared contract** — any item can produce or consume a keyword. Adding new items doesn't require new combat code; it reuses the keyword vocabulary.
2. **Enchanting separates identity from power** — the base item defines what it *does*; the enchant defines *how aggressively*. More build expression without more items.
3. **Hero identity as run skeleton** — starting item is unique and un-sellable. It constrains and focuses the build, preventing the "buy everything" approach.
4. **Visible combat creates narrative** — players remember "my Blaze Sword crit at tick 40 then my Freeze triggered". Instant simulation has no story.

---

## CFA Implementation Roadmap

### Priority 1 — Post-battle results panel
**Status: IN PROGRESS**
- Full overlay: VICTORY / DEFEAT / DRAW header
- Per-side: damage dealt, shots fired, HP remaining, modules disabled
- Notable events list (dodge, overload, EMP, reflect, rewind, vent, capacitor)
- Hidden on NEXT ROUND; also hidden on RUN OVER

### Priority 2 — 7-card shop
**Status: DONE**
- `SHOP_SIZE = 7`, `CARD_W = 168`, `GAP = 10`, shop `x = 22`

### Priority 3 — Archetype / captain select
**Before run starts, player picks one of 3:**

| Archetype | Passive | Starter modules |
|---|---|---|
| ENGINEER | Adjacent power modules give +8% eff (vs +5%) | Micro Reactor (protected) + Power Router |
| WARLORD | All weapons get +10% base damage | Micro Reactor (protected) + free ★2 Pulse Cannon |
| CHRONOMANCER | Paradox accumulation −15% globally | Micro Reactor (protected) + Future Sight |

Implementation: pre-run selection screen (programmatic, like MainMenu), writes choice to `GameState.archetype`, checked in `PowerSystem` / `CombatEngine` / `_give_starter_modules()`.

### Priority 4 — Combat replay
**Engine already produces a complete `event_log` with tick numbers.**

Replay system:
- After `run_simulation()`, store `result` in `_last_result`
- Show a REPLAY button in the results panel
- A `Timer` fires every 0.1s (= 1 tick), walks `event_log`, updates HP bars and cell highlights
- 2× speed button halves timer interval
- No changes to `CombatEngine` — purely a visual playback layer

### Priority 5 — Status keyword system
**4 keywords for CFA:**

| Keyword | Produced by | Consumed / amplified by |
|---|---|---|
| **Burn** | Weapons with `heat_gen > 0` apply 1 Burn/shot | THERMAL modules reduce incoming Burn; Overdrive Vent dumps all Burn |
| **Stun** | EMP Burst (already implemented as `emp_lock`) | Counter-Program reacts to Stun (already retaliates) |
| **Crack** | High-recoil weapons (`recoil_force > 1`) apply 1 Crack/shot | Blast Plating absorbs Crack stacks; Gyro Stabilizer reduces Crack gain |
| **Overcharge** | Power surplus > 1.1× marks state as Overcharge | Temporal modules consume Overcharge → −10% paradox rate; Capacitor Bank explodes louder under Overcharge |

Implementation: `CombatEngine` tracks keyword stacks per side in its state dict. Module specials check/set keyword stacks. Existing EMP/reactive logic already approximates Stun — just rename and formalize.

---

## What NOT to implement (scope guard)

| Feature | Reason to skip |
|---|---|
| Multi-currency (Ammo/Fuel/Electricity) | Requires redesigning all 60 module costs — too late pre-demo |
| Asymmetric hull shapes | 6×6 strict grid is a deliberate readability feature |
| Full keyword rework of all 60 modules at once | Surface area too large; add keywords incrementally when adding new modules |
| Multicast | Requires fire_rate refactor; deferred |
