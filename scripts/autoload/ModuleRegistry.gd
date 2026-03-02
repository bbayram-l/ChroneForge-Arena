## ModuleRegistry — global singleton (autoload)
## Loads all module definitions from data/modules.json at startup.
extends Node

var all_modules: Array[Module] = []
var _by_id: Dictionary = {}

func _ready() -> void:
	_load_modules()

func _load_modules() -> void:
	var file := FileAccess.open("res://data/modules.json", FileAccess.READ)
	if file == null:
		push_error("ModuleRegistry: cannot open res://data/modules.json")
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("ModuleRegistry: JSON parse error — " + json.get_error_message())
		return

	for entry: Dictionary in json.get_data():
		var mod := Module.new()
		mod.id               = entry.get("id", "")
		mod.display_name     = entry.get("name", "")
		mod.category         = Module.Category[entry.get("category", "STRUCTURAL")]
		mod.rarity           = Module.Rarity[entry.get("rarity", "COMMON")]
		mod.description      = entry.get("description", "")
		mod.cost             = entry.get("cost", 3)
		mod.grid_size        = Vector2i(entry.get("grid_w", 1), entry.get("grid_h", 1))
		mod.weight           = entry.get("weight", 1.0)
		mod.structural_load  = entry.get("structural_load", 1.0)
		mod.power_gen        = entry.get("power_gen", 0.0)
		mod.power_draw       = entry.get("power_draw", 0.0)
		mod.heat_gen         = entry.get("heat_gen", 0.0)
		mod.heat_reduction   = entry.get("heat_reduction", 0.0)
		mod.base_damage      = entry.get("base_damage", 0.0)
		mod.fire_rate        = entry.get("fire_rate", 0.0)
		mod.recoil_force     = entry.get("recoil_force", 0.0)
		mod.hp               = entry.get("hp", 0.0)
		mod.shield_value     = entry.get("shield_value", 0.0)
		mod.paradox_rate     = entry.get("paradox_rate", 0.0)
		all_modules.append(mod)
		_by_id[mod.id] = mod

	print("ModuleRegistry: loaded %d modules." % all_modules.size())

func get_module(id: String) -> Module:
	return _by_id.get(id, null)

func get_by_category(cat: Module.Category) -> Array[Module]:
	return all_modules.filter(func(m: Module) -> bool: return m.category == cat)

func get_by_rarity(rar: Module.Rarity) -> Array[Module]:
	return all_modules.filter(func(m: Module) -> bool: return m.rarity == rar)
