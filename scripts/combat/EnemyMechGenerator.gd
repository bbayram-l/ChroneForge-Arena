## EnemyMechGenerator — builds archetype-based enemy grids for combat simulation.
## Grids are deterministic given the same round_num and rng_seed.
##
## Archetypes scale across 4 tiers so later rounds field meaningfully larger enemies:
##   Tier 0 (rounds  1–3):  4–6 modules  — UNCOMMON cap
##   Tier 1 (rounds  4–7):  7–9 modules  — RARE cap
##   Tier 2 (rounds  8–11): 10–12 modules — EPIC cap, adds AI
##   Tier 3 (rounds 12+):   12–15 modules — LEGENDARY cap, adds Temporal + more AI
class_name EnemyMechGenerator
extends RefCounted

# ── Archetype slot layouts ──────────────────────────────────────────────────
# Each slot: [Module.Category (as int), x, y]
# Power modules sit centre-grid so adjacent weapons get the efficiency bonus.
# Category int mapping: STRUCTURAL=0 POWER=1 WEAPON=2 DEFENSE=3 THERMAL=4 TEMPORAL=5 AI=6

static func _brawler_slots(tier: int) -> Array:
	match tier:
		0:
			return [
				[Module.Category.POWER,   2, 2],
				[Module.Category.WEAPON,  1, 2],
				[Module.Category.WEAPON,  3, 2],
				[Module.Category.DEFENSE, 2, 3],
			]
		1:
			return [
				[Module.Category.POWER,      2, 2],
				[Module.Category.POWER,      3, 3],
				[Module.Category.WEAPON,     1, 2],
				[Module.Category.WEAPON,     3, 2],
				[Module.Category.WEAPON,     2, 1],
				[Module.Category.DEFENSE,    2, 3],
				[Module.Category.STRUCTURAL, 0, 2],
			]
		2:
			return [
				[Module.Category.POWER,      2, 2],
				[Module.Category.POWER,      3, 3],
				[Module.Category.WEAPON,     1, 2],
				[Module.Category.WEAPON,     3, 2],
				[Module.Category.WEAPON,     2, 1],
				[Module.Category.WEAPON,     4, 2],
				[Module.Category.DEFENSE,    2, 3],
				[Module.Category.DEFENSE,    1, 3],
				[Module.Category.STRUCTURAL, 0, 2],
				[Module.Category.AI,         0, 3],
			]
		_:  # tier 3
			return [
				[Module.Category.POWER,      2, 2],
				[Module.Category.POWER,      3, 3],
				[Module.Category.POWER,      2, 0],
				[Module.Category.WEAPON,     1, 2],
				[Module.Category.WEAPON,     3, 2],
				[Module.Category.WEAPON,     2, 1],
				[Module.Category.WEAPON,     4, 2],
				[Module.Category.WEAPON,     0, 1],
				[Module.Category.DEFENSE,    2, 3],
				[Module.Category.DEFENSE,    1, 3],
				[Module.Category.STRUCTURAL, 0, 2],
				[Module.Category.AI,         0, 3],
				[Module.Category.TEMPORAL,   4, 1],
			]

static func _fortress_slots(tier: int) -> Array:
	match tier:
		0:
			return [
				[Module.Category.POWER,      2, 2],
				[Module.Category.POWER,      3, 2],
				[Module.Category.WEAPON,     2, 1],
				[Module.Category.DEFENSE,    1, 2],
				[Module.Category.DEFENSE,    4, 2],
				[Module.Category.STRUCTURAL, 3, 3],
			]
		1:
			return [
				[Module.Category.POWER,      2, 2],
				[Module.Category.POWER,      3, 2],
				[Module.Category.WEAPON,     2, 1],
				[Module.Category.WEAPON,     4, 1],
				[Module.Category.DEFENSE,    1, 2],
				[Module.Category.DEFENSE,    4, 2],
				[Module.Category.DEFENSE,    2, 3],
				[Module.Category.STRUCTURAL, 3, 3],
				[Module.Category.THERMAL,    0, 2],
			]
		2:
			return [
				[Module.Category.POWER,      2, 2],
				[Module.Category.POWER,      3, 2],
				[Module.Category.POWER,      1, 2],
				[Module.Category.WEAPON,     2, 1],
				[Module.Category.WEAPON,     4, 1],
				[Module.Category.DEFENSE,    0, 2],
				[Module.Category.DEFENSE,    4, 2],
				[Module.Category.DEFENSE,    2, 3],
				[Module.Category.DEFENSE,    3, 3],
				[Module.Category.STRUCTURAL, 0, 3],
				[Module.Category.THERMAL,    1, 3],
				[Module.Category.AI,         4, 3],
			]
		_:  # tier 3
			return [
				[Module.Category.POWER,      2, 2],
				[Module.Category.POWER,      3, 2],
				[Module.Category.POWER,      1, 2],
				[Module.Category.WEAPON,     2, 1],
				[Module.Category.WEAPON,     4, 1],
				[Module.Category.WEAPON,     3, 1],
				[Module.Category.DEFENSE,    0, 2],
				[Module.Category.DEFENSE,    4, 2],
				[Module.Category.DEFENSE,    2, 3],
				[Module.Category.DEFENSE,    3, 3],
				[Module.Category.STRUCTURAL, 0, 3],
				[Module.Category.THERMAL,    1, 3],
				[Module.Category.AI,         4, 3],
				[Module.Category.TEMPORAL,   0, 1],
			]

static func _skirmisher_slots(tier: int) -> Array:
	match tier:
		0:
			return [
				[Module.Category.POWER,  2, 2],
				[Module.Category.POWER,  3, 2],
				[Module.Category.WEAPON, 1, 2],
				[Module.Category.WEAPON, 4, 2],
				[Module.Category.WEAPON, 2, 3],
			]
		1:
			return [
				[Module.Category.POWER,  2, 2],
				[Module.Category.POWER,  3, 2],
				[Module.Category.WEAPON, 1, 2],
				[Module.Category.WEAPON, 4, 2],
				[Module.Category.WEAPON, 2, 3],
				[Module.Category.WEAPON, 0, 2],
				[Module.Category.AI,     4, 3],
			]
		2:
			return [
				[Module.Category.POWER,   2, 2],
				[Module.Category.POWER,   3, 2],
				[Module.Category.POWER,   1, 2],
				[Module.Category.WEAPON,  1, 1],
				[Module.Category.WEAPON,  4, 2],
				[Module.Category.WEAPON,  2, 3],
				[Module.Category.WEAPON,  0, 2],
				[Module.Category.WEAPON,  3, 1],
				[Module.Category.AI,      4, 3],
				[Module.Category.TEMPORAL, 0, 1],
			]
		_:  # tier 3
			return [
				[Module.Category.POWER,   2, 2],
				[Module.Category.POWER,   3, 2],
				[Module.Category.POWER,   1, 2],
				[Module.Category.WEAPON,  1, 1],
				[Module.Category.WEAPON,  4, 2],
				[Module.Category.WEAPON,  2, 3],
				[Module.Category.WEAPON,  0, 2],
				[Module.Category.WEAPON,  3, 1],
				[Module.Category.WEAPON,  4, 1],
				[Module.Category.WEAPON,  0, 3],
				[Module.Category.AI,      4, 3],
				[Module.Category.TEMPORAL, 0, 1],
			]

# ── Public API ──────────────────────────────────────────────────────────────

## Returns a fully populated MechGrid for an enemy mech.
## Deterministic: same round_num + rng_seed always produces the same grid.
static func generate(round_num: int, rng_seed: int = 0) -> MechGrid:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var max_rarity := _max_rarity_for_round(round_num)
	var grid       := MechGrid.new("enemy")
	_populate(grid, rng.randi() % 3, round_num, max_rarity, rng)

	return grid

# ── Internal ────────────────────────────────────────────────────────────────

static func _populate(grid: MechGrid, archetype: int, round_num: int, max_rarity: Module.Rarity, rng: RandomNumberGenerator) -> void:
	var tier  := _tier_for_round(round_num)
	var slots: Array
	match archetype:
		0: slots = _brawler_slots(tier)
		1: slots = _fortress_slots(tier)
		_: slots = _skirmisher_slots(tier)

	for slot in slots:
		var mod := _pick_module(slot[0], max_rarity, rng)
		if mod != null:
			grid.place_module(Vector2i(slot[1], slot[2]), mod)

	_apply_star_upgrades(grid, tier)

## Upgrade enemy modules based on tier so they scale with the player's build progression.
## Tier 1: weapon ★2.  Tier 2: weapon ★2, power ★2.  Tier 3: weapon ★3, power ★2.
## ★3 weapons are capped to tier 3 (round 12+) so mid-game enemies aren't walls.
static func _apply_star_upgrades(grid: MechGrid, tier: int) -> void:
	if tier == 0:
		return
	for mod: Module in grid.get_all_modules():
		var upgrades: int = 0
		match tier:
			1:
				upgrades = 1 if mod.category == Module.Category.WEAPON else 0
			2:
				upgrades = 1   # weapon ★2, power ★2, others ★2
			3:
				if   mod.category == Module.Category.WEAPON: upgrades = 2   # ★3
				else:                                        upgrades = 1   # ★2
		for _i in range(upgrades):
			mod.upgrade()

## Returns 0–3 tier based on round.
## Staggered to give player more time to build before enemy star upgrades kick in.
## T0 (R1-5): bare builds. T1 (R6-9): weapons ★2. T2 (R10-13): all ★2. T3 (R14+): weapons ★3.
static func _tier_for_round(round_num: int) -> int:
	if round_num <= 5:   return 0
	if round_num <= 9:   return 1
	if round_num <= 13:  return 2
	return 3

## Rarity ceiling rises with round number, matching shop odds progression.
static func _max_rarity_for_round(round_num: int) -> Module.Rarity:
	if round_num <= 3:  return Module.Rarity.UNCOMMON
	if round_num <= 7:  return Module.Rarity.RARE
	if round_num <= 11: return Module.Rarity.EPIC
	return Module.Rarity.LEGENDARY

static func _pick_module(cat: int, max_rarity: Module.Rarity, rng: RandomNumberGenerator) -> Module:
	var candidates: Array[Module] = []
	for mod: Module in ModuleRegistry.all_modules:
		if mod.category == cat and mod.rarity <= max_rarity:
			candidates.append(mod)
	if candidates.is_empty():
		return null
	return candidates[rng.randi() % candidates.size()]
