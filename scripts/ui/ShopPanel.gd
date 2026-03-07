## ShopPanel — displays module offer cards horizontally.
## Supports click-to-select (then click grid) and drag-to-place workflows.
class_name ShopPanel
extends Control

signal module_selected(mod: Module)
signal drag_started(mod: Module)
signal drag_dropped(mod: Module, screen_pos: Vector2)

const CARD_W:          int   = 160
const CARD_H:          int   = 164
const GAP:             int   = 8
const IMAGE_H:         int   = 56
const DRAG_THRESHOLD:  float = 8.0

const RARITY_COLORS: Dictionary = {
	Module.Rarity.COMMON:    Color("282828"),
	Module.Rarity.UNCOMMON:  Color("1a4a1a"),
	Module.Rarity.RARE:      Color("1a2860"),
	Module.Rarity.EPIC:      Color("380e70"),
	Module.Rarity.LEGENDARY: Color("5a1a00"),
}

var _selected_mod:  Module            = null
var _cards:         Array             = []
var _offers:        Array[Module]     = []
var _player_grid:   MechGrid          = null
var _cost_labels:   Dictionary        = {}   # Module → Label
var _hover_mod:     Module            = null

# Drag / click state
var _pressed_mod:      Module  = null
var _press_screen_pos: Vector2 = Vector2.ZERO
var _is_dragging:      bool    = false

# ── Public API ───────────────────────────────────────────────────────────────

func show_offers(offers: Array[Module]) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_offers = offers.duplicate()
	_cost_labels.clear()
	_hover_mod    = null
	_selected_mod = null
	for i in range(offers.size()):
		var card := _build_card(offers[i], i)
		add_child(card)
		_cards.append(card)

func get_selected() -> Module:
	return _selected_mod

func set_player_grid(grid: MechGrid) -> void:
	_player_grid = grid

func remove_offer(mod: Module) -> void:
	var idx := _offers.find(mod)
	if idx < 0:
		return
	_cost_labels.erase(mod)
	_cards[idx].queue_free()
	_cards.remove_at(idx)
	_offers.remove_at(idx)
	if _hover_mod == mod:
		_hover_mod = null
	# Cards keep their original slot x-positions so remaining slots are predictable.
	# Do NOT reposition — gaps appear but click coordinates stay stable.

func deselect() -> void:
	_selected_mod = null
	_refresh_selection()

## Re-colour cost labels based on current gold — call after any spend/gain.
func refresh_affordability() -> void:
	for mod: Module in _cost_labels.keys():
		var lbl: Label = _cost_labels[mod]
		if is_instance_valid(lbl):
			var affordable := GameState.gold >= mod.cost
			lbl.add_theme_color_override("font_color",
				Color("e8c87a") if affordable else Color("e03020"))

# ── Card construction ────────────────────────────────────────────────────────

func _build_card(mod: Module, index: int) -> Panel:
	var card := Panel.new()
	card.position      = Vector2(float(index * (CARD_W + GAP)), 0.0)
	card.size          = Vector2(float(CARD_W), float(CARD_H))
	card.clip_contents = true
	_apply_card_style(card, mod.rarity, false, false)

	# ── Image area ──────────────────────────────────────────────────────────
	var cat_col: Color = MechGridView.CATEGORY_COLORS.get(mod.category, Color("333333"))

	var img_bg := ColorRect.new()
	img_bg.position      = Vector2(6.0, 6.0)
	img_bg.size          = Vector2(float(CARD_W - 12), float(IMAGE_H))
	img_bg.color         = Color(cat_col.r, cat_col.g, cat_col.b, 0.22)
	img_bg.mouse_filter  = MOUSE_FILTER_IGNORE
	img_bg.clip_contents = true
	card.add_child(img_bg)

	var img_path := "res://assets/modules/%s.png" % mod.id
	if ResourceLoader.exists(img_path):
		var img := TextureRect.new()
		# Fill the img_bg completely — no manual coordinate math needed.
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.texture      = load(img_path)
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.mouse_filter = MOUSE_FILTER_IGNORE
		img_bg.add_child(img)   # child of img_bg, not card

	# ── Category badge (top-right, over image) ───────────────────────────────
	var badge_bg := ColorRect.new()
	badge_bg.position     = Vector2(float(CARD_W - 18), 6.0)
	badge_bg.size         = Vector2(12.0, 12.0)
	badge_bg.color        = cat_col
	badge_bg.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(badge_bg)

	var badge_lbl := Label.new()
	badge_lbl.position             = Vector2(float(CARD_W - 18), 4.0)
	badge_lbl.size                 = Vector2(12.0, 14.0)
	badge_lbl.text                 = SynergySystem.category_icon(mod.category)
	badge_lbl.add_theme_font_size_override("font_size", 8)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(badge_lbl)

	# ── Module name ──────────────────────────────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.position      = Vector2(8.0, float(IMAGE_H + 10))
	name_lbl.size          = Vector2(float(CARD_W - 16), 22.0)
	name_lbl.text          = mod.display_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# ── Category · Rarity [Size] ─────────────────────────────────────────────
	var size_tag := ""
	if mod.grid_size.x > 1 or mod.grid_size.y > 1:
		size_tag = "  [%dx%d]" % [mod.grid_size.x, mod.grid_size.y]
	var meta_lbl := Label.new()
	meta_lbl.position     = Vector2(8.0, float(IMAGE_H + 32))
	meta_lbl.size         = Vector2(float(CARD_W - 16), 14.0)
	meta_lbl.text         = "%s · %s%s" % [
		Module.Category.keys()[mod.category],
		Module.Rarity.keys()[mod.rarity],
		size_tag,
	]
	meta_lbl.add_theme_font_size_override("font_size", 9)
	meta_lbl.modulate     = Color(0.72, 0.72, 0.72)
	meta_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(meta_lbl)

	# ── Stats ────────────────────────────────────────────────────────────────
	var stats_lbl := Label.new()
	stats_lbl.position      = Vector2(8.0, float(IMAGE_H + 48))
	stats_lbl.size          = Vector2(float(CARD_W - 16), 34.0)
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.text          = _stat_lines(mod)
	stats_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
	card.add_child(stats_lbl)

	# ── Synergy hint ─────────────────────────────────────────────────────────
	if _player_grid != null:
		var syns := SynergySystem.synergies_for(mod, _player_grid)
		if not syns.is_empty():
			var syn: Dictionary = syns[0]
			var syn_lbl := Label.new()
			syn_lbl.position     = Vector2(8.0, float(CARD_H - 32))
			syn_lbl.size         = Vector2(float(CARD_W - 16), 14.0)
			syn_lbl.text         = "* %s" % syn["name"]
			syn_lbl.add_theme_font_size_override("font_size", 9)
			syn_lbl.add_theme_color_override("font_color", syn["color"])
			syn_lbl.mouse_filter = MOUSE_FILTER_IGNORE
			card.add_child(syn_lbl)

	# ── Cost (bottom, red when unaffordable) ─────────────────────────────────
	var cost_lbl := Label.new()
	cost_lbl.position  = Vector2(8.0, float(CARD_H - 17))
	cost_lbl.size      = Vector2(float(CARD_W - 16), 15.0)
	cost_lbl.text      = "%d scrap" % mod.cost
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	var affordable := GameState.gold >= mod.cost
	cost_lbl.add_theme_color_override("font_color",
		Color("e8c87a") if affordable else Color("e03020"))
	card.add_child(cost_lbl)
	_cost_labels[mod] = cost_lbl

	# ── Signals ──────────────────────────────────────────────────────────────
	card.gui_input.connect(_on_card_gui_input.bind(mod))
	card.mouse_entered.connect(_on_card_hover_enter.bind(mod))
	card.mouse_exited.connect(_on_card_hover_exit.bind(mod))
	return card


func _stat_lines(mod: Module) -> String:
	var parts: PackedStringArray = []
	if mod.base_damage    > 0.0: parts.append("DMG %.0f  RoF %.1f/s" % [mod.base_damage, mod.fire_rate])
	if mod.power_gen      > 0.0: parts.append("GEN +%.0f"   % mod.power_gen)
	if mod.power_draw     > 0.0: parts.append("PWR -%.0f"   % mod.power_draw)
	if mod.hp             > 0.0: parts.append("HP  +%.0f"   % mod.hp)
	if mod.shield_value   > 0.0: parts.append("SHD +%.0f"   % mod.shield_value)
	if mod.heat_reduction > 0.0: parts.append("COOL+%.0f"   % mod.heat_reduction)
	if mod.paradox_rate   > 0.0: parts.append("PDX +%.0f/s" % mod.paradox_rate)
	if parts.is_empty():         parts.append(mod.description.substr(0, 55))
	return "\n".join(parts)


func _apply_card_style(card: Panel, rarity: Module.Rarity, selected: bool, hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = RARITY_COLORS.get(rarity, Color("282828"))
	if hovered and not selected:
		style.bg_color = style.bg_color.lightened(0.14)
	style.set_corner_radius_all(6)
	if selected:
		style.border_color        = Color("e0e040")
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2
	elif hovered:
		style.border_color        = Color(1.0, 1.0, 1.0, 0.25)
		style.border_width_left   = 1
		style.border_width_right  = 1
		style.border_width_top    = 1
		style.border_width_bottom = 1
	card.add_theme_stylebox_override("panel", style)


# ── Input: card press (records which card was pressed) ───────────────────────

func _on_card_gui_input(event: InputEvent, mod: Module) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_pressed_mod      = mod
		_press_screen_pos = get_viewport().get_mouse_position()
		# Immediate visual selection feedback
		_selected_mod = mod
		_refresh_selection()


# ── Input: motion → drag start; release → click or drop ─────────────────────

func _input(event: InputEvent) -> void:
	if _pressed_mod == null:
		return

	if event is InputEventMouseMotion:
		if not _is_dragging:
			var dist := (get_viewport().get_mouse_position() - _press_screen_pos).length()
			if dist > DRAG_THRESHOLD:
				_is_dragging = true
				drag_started.emit(_pressed_mod)

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _is_dragging:
				_is_dragging = false
				drag_dropped.emit(_pressed_mod, get_viewport().get_mouse_position())
			else:
				module_selected.emit(_pressed_mod)
			_pressed_mod = null


# ── Hover effects ────────────────────────────────────────────────────────────

func _on_card_hover_enter(mod: Module) -> void:
	_hover_mod = mod
	var idx := _offers.find(mod)
	if idx >= 0 and idx < _cards.size():
		_apply_card_style(_cards[idx], mod.rarity, mod == _selected_mod, true)

func _on_card_hover_exit(mod: Module) -> void:
	if _hover_mod == mod:
		_hover_mod = null
	var idx := _offers.find(mod)
	if idx >= 0 and idx < _cards.size():
		_apply_card_style(_cards[idx], mod.rarity, mod == _selected_mod, false)

func _refresh_selection() -> void:
	for i in range(mini(_cards.size(), _offers.size())):
		var hovered := (_offers[i] == _hover_mod)
		_apply_card_style(_cards[i], _offers[i].rarity, _offers[i] == _selected_mod, hovered)
