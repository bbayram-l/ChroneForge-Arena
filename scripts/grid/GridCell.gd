## GridCell — a single cell in a MechGrid.
## Holds module reference plus live heat and structural load values.
class_name GridCell
extends RefCounted

var position: Vector2i
var module: Module = null
var heat: float = 0.0
var structural_load: float = 0.0

func _init(pos: Vector2i) -> void:
	position = pos

func is_empty() -> bool:
	return module == null

func place_module(mod: Module) -> void:
	module = mod
	structural_load = mod.structural_load

func remove_module() -> void:
	module = null
	structural_load = 0.0
	heat = 0.0
