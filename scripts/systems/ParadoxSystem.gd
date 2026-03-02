## ParadoxSystem — tracks the Paradox meter for one mech.
## When Paradox > 100 an overload roll fires each tick.
## On overload, a random active module is permanently disabled mid-fight.
class_name ParadoxSystem
extends RefCounted

const OVERLOAD_THRESHOLD: float  = 100.0
const OVERLOAD_RATE:      float  = 0.02   # chance per paradox point above 100
# Meta taxes (from BALANCING doc)
const TAX_4_TEMPORAL: float = 0.20        # +20% gain rate at ≥4 temporal modules
const TAX_6_TEMPORAL: float = 0.30        # additional +30% at ≥6

signal module_disabled(mod: Module)

var grid: MechGrid
var paradox: float = 0.0

func _init(mech_grid: MechGrid) -> void:
	grid = mech_grid

## Called once per combat tick. Accumulates paradox and rolls for overload.
func tick(delta: float, rng: RandomNumberGenerator) -> void:
	# Accumulate from all active temporal modules
	for mod in grid.get_all_modules():
		if mod.category == Module.Category.TEMPORAL and not mod.disabled:
			paradox += mod.paradox_rate * delta

	# Apply meta taxes
	var t_count := _temporal_count()
	if t_count >= 4:
		paradox += paradox * TAX_4_TEMPORAL * delta
	if t_count >= 6:
		paradox += paradox * TAX_6_TEMPORAL * delta
		# Extra overload roll for ≥6 temporal modules
		_try_overload(rng, delta)

	_try_overload(rng, delta)

func _try_overload(rng: RandomNumberGenerator, delta: float) -> void:
	if paradox <= OVERLOAD_THRESHOLD:
		return
	var chance := (paradox - OVERLOAD_THRESHOLD) * OVERLOAD_RATE * delta
	if rng.randf() < chance:
		_trigger_overload()

func _trigger_overload() -> void:
	var candidates := grid.get_all_modules().filter(
		func(m: Module) -> bool: return not m.disabled
	)
	if candidates.is_empty():
		return
	var target: Module = candidates[randi() % candidates.size()]
	target.disabled = true
	module_disabled.emit(target)

func _temporal_count() -> int:
	var count := 0
	for mod in grid.get_all_modules():
		if mod.category == Module.Category.TEMPORAL:
			count += 1
	return count

func overload_chance_per_second() -> float:
	if paradox <= OVERLOAD_THRESHOLD:
		return 0.0
	return (paradox - OVERLOAD_THRESHOLD) * OVERLOAD_RATE

func normalized() -> float:
	return paradox / OVERLOAD_THRESHOLD   # 1.0 = at threshold, >1 = danger zone

func reset() -> void:
	paradox = 0.0
