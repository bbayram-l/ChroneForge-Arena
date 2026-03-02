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

## StabilityModifier from SYSTEM doc: 1 − (TorqueImbalance × 0.5)
func stability_modifier() -> float:
	return 1.0 - torque_imbalance() * 0.5

# ── Recoil ─────────────────────────────────────────────────────────────────

func apply_recoil(weapon: Module) -> void:
	var total_mass := 0.0
	for mod in grid.get_all_modules():
		total_mass += mod.weight
	if total_mass <= 0.0:
		return
	recoil_displacement += weapon.recoil_force / total_mass

## Returns combined accuracy penalty (0.0–0.5).
func accuracy_penalty() -> float:
	var torque_pen  := torque_imbalance() * 0.2      # up to 20% from imbalance
	var recoil_pen  := recoil_displacement * 0.3     # from accumulated drift
	return minf(torque_pen + recoil_pen, 0.5)

## Call each tick to decay accumulated displacement.
func decay_displacement(delta: float) -> void:
	recoil_displacement = maxf(0.0, recoil_displacement - delta * 2.0)
