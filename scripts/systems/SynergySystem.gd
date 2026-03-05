## SynergySystem — static helpers for cross-category module synergies.
## No instance required; call static methods directly.
class_name SynergySystem

const SYNERGIES: Array = [
	{"cats": [Module.Category.POWER,      Module.Category.WEAPON],    "name": "Overcharge", "color": Color("ffbb00"), "desc": "weapons gain power bonus"},
	{"cats": [Module.Category.THERMAL,    Module.Category.WEAPON],    "name": "Heat Sink",  "color": Color("00bbff"), "desc": "weapons run cooler"},
	{"cats": [Module.Category.STRUCTURAL, Module.Category.DEFENSE],   "name": "Fortress",   "color": Color("88aacc"), "desc": "+15% max HP"},
	{"cats": [Module.Category.TEMPORAL,   Module.Category.WEAPON],    "name": "Echo Shot",  "color": Color("aa44ff"), "desc": "5% echo chance"},
	{"cats": [Module.Category.AI,         Module.Category.WEAPON],    "name": "Targeting",  "color": Color("00ffaa"), "desc": "+5% accuracy"},
	{"cats": [Module.Category.POWER,      Module.Category.TEMPORAL],  "name": "Flux",       "color": Color("ff44aa"), "desc": "-10% paradox rate"},
]

## Returns synergy dicts that would become active if `mod` were added to `grid`.
static func synergies_for(mod: Module, grid: MechGrid) -> Array:
	var present_cats: Array = []
	for m: Module in grid.get_all_modules():
		if not present_cats.has(m.category):
			present_cats.append(m.category)
	var result: Array = []
	for syn: Dictionary in SYNERGIES:
		if mod.category in syn["cats"]:
			var partner_cat: int = syn["cats"][0] if mod.category == syn["cats"][1] else syn["cats"][1]
			if partner_cat in present_cats:
				result.append(syn)
	return result

## Returns all synergy dicts currently active in `grid`.
static func active_synergies(grid: MechGrid) -> Array:
	var present_cats: Array = []
	for m: Module in grid.get_all_modules():
		if not present_cats.has(m.category):
			present_cats.append(m.category)
	var result: Array = []
	for syn: Dictionary in SYNERGIES:
		if syn["cats"][0] in present_cats and syn["cats"][1] in present_cats:
			result.append(syn)
	return result

## Single-character icon for a module category.
static func category_icon(cat: Module.Category) -> String:
	match cat:
		Module.Category.STRUCTURAL: return "S"
		Module.Category.POWER:      return "P"
		Module.Category.WEAPON:     return "W"
		Module.Category.DEFENSE:    return "D"
		Module.Category.THERMAL:    return "T"
		Module.Category.TEMPORAL:   return "Θ"
		Module.Category.AI:         return "A"
	return "?"
