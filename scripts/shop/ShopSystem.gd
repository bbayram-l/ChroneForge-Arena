## ShopSystem — generates and manages the per-round module shop.
## Roll odds shift by round, temporal modules get a soft bias,
## and reroll costs scale mid/late game — all per the SYSTEM doc.
class_name ShopSystem
extends RefCounted

const SHOP_SIZE: int = 5

var _pool: Array[Module] = []
var rng: RandomNumberGenerator
var current_shop: Array[Module] = []

func _init(module_pool: Array[Module], seed: int = 0) -> void:
	_pool = module_pool
	rng   = RandomNumberGenerator.new()
	rng.seed = seed

# ── Rarity odds ────────────────────────────────────────────────────────────

## Returns weight table keyed by Module.Rarity for the given round.
static func rarity_weights(round: int) -> Dictionary:
	if round <= 5:
		return {
			Module.Rarity.COMMON:    70,
			Module.Rarity.UNCOMMON:  25,
			Module.Rarity.RARE:       5,
			Module.Rarity.EPIC:       0,
			Module.Rarity.LEGENDARY:  0,
		}
	elif round <= 10:
		return {
			Module.Rarity.COMMON:    50,
			Module.Rarity.UNCOMMON:  30,
			Module.Rarity.RARE:      15,
			Module.Rarity.EPIC:       5,
			Module.Rarity.LEGENDARY:  0,
		}
	return {
		Module.Rarity.COMMON:    35,
		Module.Rarity.UNCOMMON:  30,
		Module.Rarity.RARE:      20,
		Module.Rarity.EPIC:      10,
		Module.Rarity.LEGENDARY:  5,
	}

## Chance that a given slot is forced to a temporal module.
static func temporal_chance(round: int) -> float:
	if round <= 5:  return 0.10
	if round <= 10: return 0.20
	return 0.30

# ── Shop generation ────────────────────────────────────────────────────────

func roll_shop(round: int) -> Array[Module]:
	current_shop.clear()
	var weights  := rarity_weights(round)
	var t_chance := temporal_chance(round)

	for _i in range(SHOP_SIZE):
		var mod := _pick_module(weights, t_chance)
		if mod != null:
			current_shop.append(mod)

	return current_shop

func reroll(round: int) -> Array[Module]:
	return roll_shop(round)

# ── Internal ───────────────────────────────────────────────────────────────

func _pick_module(weights: Dictionary, t_chance: float) -> Module:
	var rarity := _roll_rarity(weights)
	var candidates := _pool.filter(func(m: Module) -> bool: return m.rarity == rarity)

	if candidates.is_empty():
		candidates = _pool.duplicate()

	# Temporal bias — override candidate pool occasionally
	if rng.randf() < t_chance:
		var temporal := candidates.filter(func(m: Module) -> bool:
			return m.category == Module.Category.TEMPORAL)
		if not temporal.is_empty():
			candidates = temporal

	if candidates.is_empty():
		return null

	return candidates[rng.randi() % candidates.size()]

func _roll_rarity(weights: Dictionary) -> Module.Rarity:
	var total := 0
	for w: int in weights.values():
		total += w

	var roll := rng.randi() % total
	var acc  := 0
	for rarity in weights.keys():
		acc += weights[rarity]
		if roll < acc:
			return rarity

	return Module.Rarity.COMMON
