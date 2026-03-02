## HeatSystem — quadrant-based heat tracking.
## Grid is divided into four quadrants (TL/TR/BL/BR).
## Modules overheat when their quadrant exceeds BASE_HEAT_TOLERANCE.
## At DISABLE_THRESHOLD the module is forced offline.
class_name HeatSystem
extends RefCounted

enum Quadrant { TOP_LEFT = 0, TOP_RIGHT = 1, BOTTOM_LEFT = 2, BOTTOM_RIGHT = 3 }

const BASE_HEAT_TOLERANCE: float = 100.0
const DISABLE_THRESHOLD:   float = 150.0
const BASE_DISSIPATION:    float = 5.0    # heat removed per second naturally

var grid: MechGrid
var quadrant_heat: Array[float] = [0.0, 0.0, 0.0, 0.0]

func _init(mech_grid: MechGrid) -> void:
	grid = mech_grid

# ── Quadrant mapping ───────────────────────────────────────────────────────

func quadrant_of(pos: Vector2i) -> Quadrant:
	var mid_x := MechGrid.GRID_WIDTH  / 2
	var mid_y := MechGrid.GRID_HEIGHT / 2
	if pos.x < mid_x and pos.y < mid_y:
		return Quadrant.TOP_LEFT
	elif pos.x >= mid_x and pos.y < mid_y:
		return Quadrant.TOP_RIGHT
	elif pos.x < mid_x and pos.y >= mid_y:
		return Quadrant.BOTTOM_LEFT
	return Quadrant.BOTTOM_RIGHT

# ── Mutation ───────────────────────────────────────────────────────────────

func add_heat(pos: Vector2i, amount: float) -> void:
	quadrant_heat[quadrant_of(pos)] += amount

## Called once per combat tick. Applies natural dissipation + thermal modules.
func dissipate(delta: float) -> void:
	var reductions := _thermal_reductions()
	for q in range(4):
		var rate := (BASE_DISSIPATION + reductions[q]) * delta
		quadrant_heat[q] = maxf(0.0, quadrant_heat[q] - rate)

func _thermal_reductions() -> Array[float]:
	var result: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			var cell := grid.get_cell(Vector2i(x, y))
			if not cell.is_empty() and cell.module.category == Module.Category.THERMAL:
				result[quadrant_of(Vector2i(x, y))] += cell.module.heat_reduction
	return result

# ── Queries ────────────────────────────────────────────────────────────────

## 0.0 = no penalty; 1.0 = full penalty (module output zeroed).
func overheat_penalty(pos: Vector2i) -> float:
	var heat := quadrant_heat[quadrant_of(pos)]
	if heat <= BASE_HEAT_TOLERANCE:
		return 0.0
	return (heat - BASE_HEAT_TOLERANCE) / BASE_HEAT_TOLERANCE

func is_disabled_by_heat(pos: Vector2i) -> bool:
	return quadrant_heat[quadrant_of(pos)] >= DISABLE_THRESHOLD

func get_state() -> Dictionary:
	return {
		"top_left":     quadrant_heat[Quadrant.TOP_LEFT],
		"top_right":    quadrant_heat[Quadrant.TOP_RIGHT],
		"bottom_left":  quadrant_heat[Quadrant.BOTTOM_LEFT],
		"bottom_right": quadrant_heat[Quadrant.BOTTOM_RIGHT],
	}
