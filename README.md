# ChronoForge Arena

> Build unstable modular mechs.  
> Break physics.  
> Bend time.  
> Out-engineer reality.

ChronoForge Arena is a deterministic, grid-based roguelike auto-battler where players assemble modular mechs, balance structural physics, manage heat and power flow, and manipulate timelines to defeat asynchronous PvP opponents.

This project is designed to be **solo-dev viable**, mechanically deep, and meta-resilient.

---

# 🎮 Core Pillars

ChronoForge is built on five interacting systems:

1. **Spatial Engineering** — Grid-based module placement with adjacency bonuses  
2. **Physics Lite** — Center-of-mass, torque, recoil drift  
3. **Thermal Management** — Quadrant heat tracking and meltdown risk  
4. **Temporal Instability** — Paradox generation and overload consequences  
5. **Economy Strategy** — Drafting, rerolling, and scaling decisions  

The goal is emergent build expression without runaway scaling.

---

# 🧱 Module Taxonomy

Modules are grouped by system layer:

## Structural
- Light Frame
- Reinforced Frame
- Gyro Stabilizer
- Shock Bracing
- Joint Lock

## Power
- Reactor Core
- Micro Reactor
- Capacitor Bank
- Power Router

## Weapons
- Railgun
- Pulse Cannon
- Plasma Saw
- Missile Pod
- Gravity Mine

## Defense
- Kinetic Plating
- Reactive Armor
- Energy Shield
- Reflective Field
- Temporal Barrier

## Thermal
- Heat Sink
- Radiator Loop
- Liquid Coolant
- Overdrive Vent

## Temporal
- Rewind Shield
- Pre-Fire Snapshot
- Echo Cannon
- Timeline Split
- Entropy Field

## AI Modules
- Targeting Matrix
- Counter-Program
- Burst Logic

---

# 🎲 Rarity System

Rarity determines volatility, not just power.

| Tier | Drop Rate | Role |
|------|-----------|------|
| Common | 55% | Stable infrastructure |
| Uncommon | 25% | Synergy enablers |
| Rare | 12% | Archetype definers |
| Epic | 6% | High volatility |
| Legendary | 2% | Rule-breaking modules |

Higher rarity increases:
- Paradox/sec
- Heat spikes
- Structural strain
- Instability

---

# 🧠 Launch Archetypes

## 1. Recoil Berserker
High mass + heavy cannons  
Weak to evasion and accuracy penalties.

## 2. Thermal Overdrive
Intentional overheating for burst spikes.  
Weak to EMP and tempo denial.

## 3. Temporal Assassin
Pre-fire alpha damage with rewind tools.  
Weak to reflect and shield revert.

## 4. Fortress Stabilizer
Shield stacking + balanced weight.  
Weak to entropy and shield lock.

## 5. Paradox Gambler
High temporal stacking with overload risk.  
Weak to sustained safe builds.

Each archetype has built-in failure modes for tuning.

---

# ⚙️ Core Combat Formulas

### Damage

FinalDamage = BaseDamage
× PowerEfficiency
× StabilityModifier
× TemporalModifier
× RandomVariance


### Power Efficiency

PowerEfficiency = AvailablePower / RequiredPower

Capped at 1.2x

### Stability

StabilityModifier = 1 - (TorqueImbalance × 0.5)


### Heat Overload

OverheatPenalty = 1 - (ExcessHeat / MaxHeat)


### Paradox Overload

OverloadChance = (Paradox - 100) × 0.02


### Diminishing Returns

StackModifier = 1 / (1 + 0.15 × (Stacks - 1))


No infinite scaling. Ever.

---

# 🛡 Anti-Meta Strategy

ChronoForge prevents stagnant metas through:

- Hard caps on attack speed, shield efficiency, and power multipliers  
- System-wide diminishing returns  
- Archetype counter modules  
- Paradox taxation scaling with temporal density  
- Shield fatigue mechanics  
- Burst dampening triggers  
- Async matchmaking banding  

Balance focuses on **failure mode tuning**, not blanket nerfs.

---

# 🏗 MVP Technical Architecture

Engine: Godot 4 (GDScript)

### Systems

- Deterministic tick-based combat loop
- Grid placement system
- Physics-lite torque model
- Quadrant heat tracking
- Paradox meter
- Async PvP snapshot storage
- Replay event log renderer

No real-time multiplayer.
No rigid-body physics.
No server-heavy architecture at launch.

---

# 📆 16-Week Development Roadmap

## Month 1
- Grid system
- Combat tick engine
- Power + heat
- Basic shop loop

## Month 2
- Physics-lite layer
- Structural integrity
- AI modules

## Month 3
- Temporal system
- Paradox logic
- Balance pass

## Month 4
- Async PvP snapshots
- Replay viewer
- Steam demo build

---

# 💰 Monetization

Model: Premium

- Base Game: $14.99
- Cosmetic skins
- Reactor glow effects
- Timeline distortion visuals
- Victory animations

No pay-to-win.
No stat unlocks.
Meta progression unlocks only new archetypes or visuals.

---

# 🎯 Design Philosophy

ChronoForge Arena is not about raw stat stacking.

Depth comes from:

Placement × Physics × Heat × Paradox × Economy

If one system dominates, the design has failed.

---

# 🚀 Vision

This project aims to push auto-battlers beyond adjacency optimization into:

- Structural instability
- Temporal manipulation
- Multi-axis build risk
- Emergent mechanical failure

The first auto-battler where your mech can literally fall over.

---

# License

TBD
