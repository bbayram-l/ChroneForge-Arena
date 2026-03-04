## ParadoxSystem — tracks the Paradox meter for one mech.
## When Paradox > 100 an overload roll fires each tick.
## On overload, a random active module is permanently disabled mid-fight.
class_name ParadoxSystem
extends RefCounted

const OVERLOAD_THRESHOLD: float  = 100.0
const VOLATILITY_K:       float  = 0.05   # exponential overload curve steepness
# Meta taxes (from BALANCING doc)
const TAX_4_TEMPORAL: float = 0.20        # +20% gain rate at ≥4 temporal modules
const TAX_6_TEMPORAL: float = 0.30        # additional +30% at ≥6

signal module_disabled(mod: Module)

var grid: MechGrid
var paradox: float = 0.0

func _init(mech_grid: MechGrid) -> void:
	grid = mech_grid

## Called once per combat tick. Accumulates paradox and rolls for overload.
## rate_mult < 1.0 when the opponent has a chrono_anchor active.
func tick(delta: float, rng: RandomNumberGenerator, rate_mult: float = 1.0) -> void:
	# Accumulate from ALL modules with paradox_rate (echo_cannon, temporal_barrier, etc.)
	for mod in grid.get_all_modules():
		if mod.paradox_rate > 0.0 and not mod.disabled:
			paradox += mod.paradox_rate * delta * rate_mult

	# Apply meta taxes
	var t_count := _temporal_count()
	if t_count >= 4:
		paradox += paradox * TAX_4_TEMPORAL * delta
	if t_count >= 6:
		paradox += paradox * TAX_6_TEMPORAL * delta
		# Extra overload roll for ≥6 temporal modules
		_try_overload(rng, delta)

	_try_overload(rng, delta)

## Exponential overload curve: OverloadChance/s = 1 − e^(−k × excess)
## This creates a false sense of safety near threshold, then rapidly ramps:
##   Paradox 105 → 22%/s  |  115 → 53%/s  |  130 → 78%/s  |  150 → 92%/s
func _try_overload(rng: RandomNumberGenerator, delta: float) -> void:
	if paradox <= OVERLOAD_THRESHOLD:
		return
	var excess := paradox - OVERLOAD_THRESHOLD
	var chance := (1.0 - exp(-VOLATILITY_K * excess)) * delta
	if rng.randf() < chance:
		_trigger_overload(rng)

func _trigger_overload(rng: RandomNumberGenerator) -> void:
	# joint_lock: 50% chance to absorb the overload (consumed each use)
	if _has_module("joint_lock") and rng.randf() < 0.5:
		return
	var candidates := grid.get_all_modules().filter(
		func(m: Module) -> bool: return not m.disabled
	)
	if candidates.is_empty():
		return
	# Use seeded rng — determinism requires no global randi() in combat
	var target: Module = candidates[rng.randi() % candidates.size()]
	target.disabled = true
	module_disabled.emit(target)

func _has_module(module_id: String) -> bool:
	for mod in grid.get_all_modules():
		if mod.id == module_id and not mod.disabled:
			return true
	return false

func _temporal_count() -> int:
	var count := 0
	for mod in grid.get_all_modules():
		if mod.category == Module.Category.TEMPORAL:
			count += 1
	return count

func overload_chance_per_second() -> float:
	if paradox <= OVERLOAD_THRESHOLD:
		return 0.0
	return 1.0 - exp(-VOLATILITY_K * (paradox - OVERLOAD_THRESHOLD))

func normalized() -> float:
	return paradox / OVERLOAD_THRESHOLD   # 1.0 = at threshold, >1 = danger zone

func reset() -> void:
	paradox = 0.0
