## ShopPanel — displays up to 5 module offer cards horizontally.
## Call show_offers() each round. Connect module_selected to handle selection.
class_name ShopPanel
extends Control

signal module_selected(mod: Module)

const CARD_W: int = 210
const CARD_H: int = 150
const GAP:    int = 14

const RARITY_COLORS: Dictionary = {
	Module.Rarity.COMMON:    Color("282828"),
	Module.Rarity.UNCOMMON:  Color("1a4a1a"),
	Module.Rarity.RARE:      Color("1a2860"),
	Module.Rarity.EPIC:      Color("380e70"),
	Module.Rarity.LEGENDARY: Color("5a1a00"),
}

var _selected_mod: Module  = null
var _cards:        Array   = []   # Panel nodes
var _offers:       Array[Module] = []

# ── Public API ──────────────────────────────────────────────────────────────

func show_offers(offers: Array[Module]) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_offers = offers.duplicate()
	_selected_mod = null

	for i in range(offers.size()):
		var card := _build_card(offers[i], i)
		add_child(card)
		_cards.append(card)

func get_selected() -> Module:
	return _selected_mod

func deselect() -> void:
	_selected_mod = null
	_refresh_selection()

# ── Card construction ────────────────────────────────────────────────────────

func _build_card(mod: Module, index: int) -> Panel:
	var card := Panel.new()
	card.position = Vector2(float(index * (CARD_W + GAP)), 0.0)
	card.size     = Vector2(float(CARD_W), float(CARD_H))
	_apply_card_style(card, mod.rarity, false)

	# Module name
	var name_lbl := Label.new()
	name_lbl.position = Vector2(8.0, 8.0)
	name_lbl.size     = Vector2(float(CARD_W - 16), 26.0)
	name_lbl.text     = mod.display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(name_lbl)

	# Category · Rarity
	var meta_lbl := Label.new()
	meta_lbl.position = Vector2(8.0, 36.0)
	meta_lbl.size     = Vector2(float(CARD_W - 16), 18.0)
	meta_lbl.text     = "%s · %s" % [Module.Category.keys()[mod.category], Module.Rarity.keys()[mod.rarity]]
	meta_lbl.add_theme_font_size_override("font_size", 10)
	meta_lbl.modulate = Color(0.75, 0.75, 0.75)
	card.add_child(meta_lbl)

	# Stats
	var stats_lbl := Label.new()
	stats_lbl.position      = Vector2(8.0, 58.0)
	stats_lbl.size          = Vector2(float(CARD_W - 16), 64.0)
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.text = _stat_lines(mod)
	card.add_child(stats_lbl)

	# Cost (bottom-right)
	var cost_lbl := Label.new()
	cost_lbl.position  = Vector2(float(CARD_W - 60), float(CARD_H - 24))
	cost_lbl.size      = Vector2(52.0, 18.0)
	cost_lbl.text      = "%d scrap" % mod.cost
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(cost_lbl)

	card.gui_input.connect(_on_card_input.bind(mod))
	return card

func _stat_lines(mod: Module) -> String:
	var parts: PackedStringArray = []
	if mod.base_damage  > 0.0: parts.append("DMG %.0f  RoF %.1f/s" % [mod.base_damage, mod.fire_rate])
	if mod.power_gen    > 0.0: parts.append("GEN +%.0f"  % mod.power_gen)
	if mod.power_draw   > 0.0: parts.append("PWR -%.0f"  % mod.power_draw)
	if mod.hp           > 0.0: parts.append("HP  +%.0f"  % mod.hp)
	if mod.shield_value > 0.0: parts.append("SHD +%.0f"  % mod.shield_value)
	if mod.heat_reduction > 0.0: parts.append("COOL+%.0f" % mod.heat_reduction)
	if mod.paradox_rate > 0.0: parts.append("PDX +%.0f/s"% mod.paradox_rate)
	if parts.is_empty():       parts.append(mod.description.substr(0, 55))
	return "\n".join(parts)

func _apply_card_style(card: Panel, rarity: Module.Rarity, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = RARITY_COLORS.get(rarity, Color("282828"))
	style.set_corner_radius_all(6)
	if selected:
		style.border_color        = Color("e0e040")
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2
	card.add_theme_stylebox_override("panel", style)

# ── Input / selection ───────────────────────────────────────────────────────

func _on_card_input(event: InputEvent, mod: Module) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_selected_mod = mod
		_refresh_selection()
		module_selected.emit(mod)

func _refresh_selection() -> void:
	for i in range(min(_cards.size(), _offers.size())):
		_apply_card_style(_cards[i], _offers[i].rarity, _offers[i] == _selected_mod)
