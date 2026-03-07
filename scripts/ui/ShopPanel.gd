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
const MODULE_ART_PATH_FMT: String = "res://assets/modules/%s.png"
const CARD_ART_OVERSCAN: float = 0.0

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
var _module_texture_cache: Dictionary = {}   # module_id -> Texture2D|null

# Drag / click state
var _pressed_mod:      Module  = null
var _press_screen_pos: Vector2 = Vector2.ZERO
var _is_dragging:      bool    = false

# ── Public API ───────────────────────────────────────────────────────────────

func show_offers(offers: Array[Module]) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_offers.clear()
	# Clone per-slot offers so duplicate IDs don't alias UI state.
	for offered: Module in offers:
		_offers.append(offered.duplicate() as Module)
	_cost_labels.clear()
	_hover_mod    = null
	_selected_mod = null
	_pressed_mod  = null
	_is_dragging  = false
	for i in range(_offers.size()):
		var card := _build_card(_offers[i], i)
		add_child(card)
		_cards.append(card)

func get_selected() -> Module:
	return _selected_mod

func get_selected_slot() -> int:
	return find_offer_slot(_selected_mod)

func get_offer_count() -> int:
	return _offers.size()

func get_offer_at(slot: int) -> Module:
	if slot < 0 or slot >= _offers.size():
		return null
	return _offers[slot]

func find_offer_slot(mod: Module) -> int:
	if mod == null:
		return -1
	for i in range(_offers.size()):
		if is_same(_offers[i], mod):
			return i
	return -1

func set_player_grid(grid: MechGrid) -> void:
	_player_grid = grid

func remove_offer(mod: Module) -> void:
	remove_offer_at(_offers.find(mod))

func remove_offer_at(slot: int) -> void:
	if slot < 0 or slot >= _offers.size():
		return
	var mod: Module = _offers[slot]
	_cost_labels.erase(mod)
	_cards[slot].queue_free()
	_cards.remove_at(slot)
	_offers.remove_at(slot)
	if _hover_mod != null and is_same(_hover_mod, mod):
		_hover_mod = null
	if _selected_mod != null and is_same(_selected_mod, mod):
		_selected_mod = null
	_refresh_selection()
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

	var tex: Texture2D = _get_module_texture(mod.id)
	if tex != null:
		var img := TextureRect.new()
		# Fill the img_bg completely — no manual coordinate math needed.
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.offset_left = -CARD_ART_OVERSCAN
		img.offset_top = -CARD_ART_OVERSCAN
		img.offset_right = CARD_ART_OVERSCAN
		img.offset_bottom = CARD_ART_OVERSCAN
		img.texture      = tex
		img.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = MOUSE_FILTER_IGNORE
		img_bg.add_child(img)   # child of img_bg, not card
	else:
		img_bg.add_child(_build_card_art_fallback(mod))

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

func _get_module_texture(module_id: String) -> Texture2D:
	if _module_texture_cache.has(module_id):
		return _module_texture_cache[module_id] as Texture2D
	var path: String = MODULE_ART_PATH_FMT % module_id
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_module_texture_cache[module_id] = tex
	return tex

func _build_card_art_fallback(mod: Module) -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = MOUSE_FILTER_IGNORE

	var tone: Color = MechGridView.CATEGORY_COLORS.get(mod.category, Color("333333"))
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(tone.r, tone.g, tone.b, 0.42)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	wrap.add_child(bg)

	var icon := Label.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.text = SynergySystem.category_icon(mod.category)
	icon.add_theme_font_size_override("font_size", 24)
	icon.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.72))
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	wrap.add_child(icon)

	return wrap


func _apply_card_style(card: Panel, rarity: Module.Rarity, selected: bool, hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = RARITY_COLORS.get(rarity, Color("282828"))
	if hovered and not selected:
		style.bg_color = style.bg_color.lightened(0.14)
	if selected:
		style.bg_color = style.bg_color.lightened(0.08)
	style.set_corner_radius_all(6)
	card.position.y = -2.0 if selected else (-1.0 if hovered else 0.0)
	card.z_index = 2 if selected else (1 if hovered else 0)
	if selected:
		style.border_color        = Color("ffd24a")
		style.border_width_left   = 3
		style.border_width_right  = 3
		style.border_width_top    = 3
		style.border_width_bottom = 3
	elif hovered:
		style.border_color        = Color(1.0, 1.0, 1.0, 0.25)
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2
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
	var idx := find_offer_slot(mod)
	if idx >= 0 and idx < _cards.size():
		var selected := _selected_mod != null and is_same(_selected_mod, mod)
		_apply_card_style(_cards[idx], mod.rarity, selected, true)

func _on_card_hover_exit(mod: Module) -> void:
	if _hover_mod != null and is_same(_hover_mod, mod):
		_hover_mod = null
	var idx := find_offer_slot(mod)
	if idx >= 0 and idx < _cards.size():
		var selected := _selected_mod != null and is_same(_selected_mod, mod)
		_apply_card_style(_cards[idx], mod.rarity, selected, false)

func _refresh_selection() -> void:
	for i in range(mini(_cards.size(), _offers.size())):
		var hovered := _hover_mod != null and is_same(_offers[i], _hover_mod)
		var selected := _selected_mod != null and is_same(_offers[i], _selected_mod)
		_apply_card_style(_cards[i], _offers[i].rarity, selected, hovered)
