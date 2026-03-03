## EnemyMechGenerator — builds archetype-based enemy grids for combat simulation.
## Grids are deterministic given the same round_num and rng_seed.
class_name EnemyMechGenerator
extends RefCounted

# ── Archetype slot layouts ──────────────────────────────────────────────────
# Each slot: [Module.Category (as int), x, y]
# Power modules sit centre-grid so adjacent weapons get the +5% efficiency bonus.

static func _brawler_slots() -> Array:
	return [
		[Module.Category.POWER,   2, 2],
		[Module.Category.WEAPON,  1, 2],
		[Module.Category.WEAPON,  3, 2],
		[Module.Category.DEFENSE, 2, 3],
	]

static func _fortress_slots() -> Array:
	return [
		[Module.Category.POWER,      2, 2],
		[Module.Category.POWER,      3, 2],
		[Module.Category.WEAPON,     2, 1],
		[Module.Category.DEFENSE,    1, 2],
		[Module.Category.DEFENSE,    4, 2],
		[Module.Category.STRUCTURAL, 3, 3],
	]

static func _skirmisher_slots() -> Array:
	return [
		[Module.Category.POWER,  2, 2],
		[Module.Category.POWER,  3, 2],
		[Module.Category.WEAPON, 1, 2],
		[Module.Category.WEAPON, 4, 2],
		[Module.Category.WEAPON, 2, 3],
	]

# ── Public API ──────────────────────────────────────────────────────────────

## Returns a fully populated MechGrid for an enemy mech.
## Deterministic: same round_num + rng_seed always produces the same grid.
static func generate(round_num: int, rng_seed: int = 0) -> MechGrid:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var max_rarity := _max_rarity_for_round(round_num)
	var grid       := MechGrid.new("enemy")
	_populate(grid, rng.randi() % 3, max_rarity, rng)

	return grid

# ── Internal ────────────────────────────────────────────────────────────────

static func _populate(grid: MechGrid, archetype: int, max_rarity: Module.Rarity, rng: RandomNumberGenerator) -> void:
	var slots: Array
	match archetype:
		0: slots = _brawler_slots()
		1: slots = _fortress_slots()
		_: slots = _skirmisher_slots()

	for slot in slots:
		var mod := _pick_module(slot[0], max_rarity, rng)
		if mod != null:
			grid.place_module(Vector2i(slot[1], slot[2]), mod)

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
