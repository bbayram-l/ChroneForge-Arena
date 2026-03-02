## PowerSystem — manages power generation, draw, and adjacency efficiency.
## Formula: PowerEfficiency = AvailablePower / RequiredPower, capped at 1.2×
class_name PowerSystem
extends RefCounted

const ADJACENCY_BONUS: float = 0.05   # +5% per adjacent power module
const MAX_EFFICIENCY: float = 1.2

var grid: MechGrid

func _init(mech_grid: MechGrid) -> void:
	grid = mech_grid

func total_generation() -> float:
	var total := 0.0
	for mod in grid.get_all_modules():
		total += mod.power_gen
	return total

func total_draw() -> float:
	var total := 0.0
	for mod in grid.get_all_modules():
		if not mod.disabled:
			total += mod.power_draw
	return total

## Returns the adjacency-boosted efficiency for the module at `pos`.
func cell_efficiency(pos: Vector2i) -> float:
	var cell := grid.get_cell(pos)
	if cell == null or cell.is_empty():
		return 1.0
	var power_neighbors := 0
	for adj in grid.get_adjacent_modules(pos):
		if adj.category == Module.Category.POWER:
			power_neighbors += 1
	return minf(1.0 + power_neighbors * ADJACENCY_BONUS, MAX_EFFICIENCY)

## Returns the global power state used each combat tick.
func get_state() -> Dictionary:
	var available := total_generation()
	var required  := total_draw()
	var ratio     := available / required if required > 0.0 else 1.0
	return {
		"available":    available,
		"required":     required,
		"efficiency":   minf(ratio, MAX_EFFICIENCY),
		"underpowered": ratio < 1.0,
	}
