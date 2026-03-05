## PhysicsLite — approximates center-of-mass, torque imbalance, and recoil.
## Not a rigid-body simulation — all results are scalar penalties fed into
## the damage formula as StabilityModifier / accuracy penalty.
class_name PhysicsLite
extends RefCounted

var grid: MechGrid
var recoil_displacement: float = 0.0   # accumulated drift from weapon fire

func _init(mech_grid: MechGrid) -> void:
	grid = mech_grid

# ── Center of mass ─────────────────────────────────────────────────────────

func center_of_mass() -> Vector2:
	var total_weight := 0.0
	var weighted := Vector2.ZERO
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			var cell := grid.get_cell(Vector2i(x, y))
			if not cell.is_empty():
				var w := cell.module.weight
				total_weight += w
				weighted += Vector2(x, y) * w
	if total_weight == 0.0:
		return Vector2(MechGrid.GRID_WIDTH * 0.5, MechGrid.GRID_HEIGHT * 0.5)
	return weighted / total_weight

## 0.0 = perfectly balanced; 1.0 = maximally off-center.
func torque_imbalance() -> float:
	var com      := center_of_mass()
	var ideal    := Vector2(MechGrid.GRID_WIDTH * 0.5, MechGrid.GRID_HEIGHT * 0.5)
	var max_dist := ideal.length()
	if max_dist == 0.0:
		return 0.0
	return clampf((com - ideal).length() / max_dist, 0.0, 1.0)

## StabilityModifier: max(0.1, 1 − (TorqueImbalance × 0.5))
## Floor at 0.1 prevents negative or zero modifiers on extreme imbalance.
## gyro_stabilizer: reduces effective torque imbalance by 30% (60% for FORTRESS_STABILIZER).
func stability_modifier() -> float:
	var ti := torque_imbalance()
	if _has_module("gyro_stabilizer"):
		var fortress := GameState.archetype == "FORTRESS_STABILIZER" and grid.owner_id == "player"
		ti *= 0.40 if fortress else 0.70
	return maxf(0.1, 1.0 - ti * 0.5)

# ── Recoil ─────────────────────────────────────────────────────────────────

func apply_recoil(weapon: Module) -> void:
	var total_mass := 0.0
	for mod in grid.get_all_modules():
		total_mass += mod.weight
	if total_mass <= 0.0:
		return
	# shock_bracing: reduces recoil accumulation by 50%
	var factor := 0.5 if _has_module("shock_bracing") else 1.0
	recoil_displacement += weapon.recoil_force / total_mass * factor

## Returns combined accuracy penalty (0.0–0.5).
func accuracy_penalty() -> float:
	var torque_pen  := torque_imbalance() * 0.2      # up to 20% from imbalance
	var recoil_pen  := recoil_displacement * 0.3     # from accumulated drift
	return minf(torque_pen + recoil_pen, 0.5)

## Call each tick to decay accumulated displacement.
func decay_displacement(delta: float) -> void:
	recoil_displacement = maxf(0.0, recoil_displacement - delta * 2.0)

# ── Helpers ────────────────────────────────────────────────────────────────

func _has_module(module_id: String) -> bool:
	for mod in grid.get_all_modules():
		if mod.id == module_id and not mod.disabled:
			return true
	return false
