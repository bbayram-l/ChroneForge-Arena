## MechGridView — visual 6×6 grid for one mech's module layout.
## Instantiate via MechGridView.new(), add to a CanvasLayer,
## then call set_title() and refresh(grid).
## Connect cell_clicked to handle player placement input.
class_name MechGridView
extends Control

signal cell_clicked(pos: Vector2i)
signal cell_hovered(pos: Vector2i)
signal cell_unhovered

const CELL_SIZE: int = 64
const CELL_GAP:  int = 4

const CATEGORY_COLORS: Dictionary = {
	Module.Category.STRUCTURAL: Color("6b5a3e"),
	Module.Category.POWER:      Color("2a8fc4"),
	Module.Category.WEAPON:     Color("c43020"),
	Module.Category.DEFENSE:    Color("30a050"),
	Module.Category.THERMAL:    Color("c06010"),
	Module.Category.TEMPORAL:   Color("7030b0"),
	Module.Category.AI:         Color("10b090"),
}
const EMPTY_COLOR          := Color("1e1e22")
const HIGHLIGHT_COLOR      := Color("2a5a2a")   # valid placement cell
const HOVER_COLOR          := Color("4a9a20")   # hovered valid cell
const FOOTPRINT_VALID_COL  := Color(0.20, 0.85, 0.25, 0.80)   # green — can drop here
const FOOTPRINT_INVALID_COL := Color(0.85, 0.15, 0.10, 0.80)  # red   — cannot drop
const CABLE_ENABLE: bool   = true
const CABLE_BASE_COL       := Color(0.05, 0.06, 0.08, 0.75)
const CABLE_SHEATH_COL     := Color(0.18, 0.22, 0.28, 0.90)
const CABLE_HILITE_COL     := Color(0.62, 0.74, 0.86, 0.42)

var _panels:       Array     = []            # [y][x] → Panel
var _title_label:  Label
var _current_grid: MechGrid  = null
var _highlighted:  Array     = []            # Array[Vector2i] valid-placement positions
var _hovered_pos:  Vector2i  = Vector2i(-1, -1)
var _com:          Vector2   = Vector2(3.0, 3.0)   # center-of-mass in grid coords
var _show_com:     bool      = false
var _fp_cells:     Array     = []            # Array[Vector2i] drag-footprint cells
var _fp_valid:     bool      = false
var _mode_overlay: String    = ""           # "sell", "upgrade", or "" for none
var _protected:    Array     = []           # Array[Vector2i] cells immune to sell overlay

# ── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_build()

func _process(_delta: float) -> void:
	# Continuously redraw only when the torque visualizer has a significant imbalance
	# so the pulsing COM ring animates. Skipped when grid is empty.
	if _show_com and _current_grid != null:
		var step := float(CELL_SIZE + CELL_GAP)
		var ideal := Vector2(MechGrid.GRID_WIDTH, MechGrid.GRID_HEIGHT) * step * 0.5
		if (_com * step - ideal).length() > 30.0:
			queue_redraw()

func _build() -> void:
	_panels = []
	var step := CELL_SIZE + CELL_GAP

	_title_label = Label.new()
	_title_label.position = Vector2(0.0, -28.0)
	_title_label.size = Vector2(float(MechGrid.GRID_WIDTH * step), 24.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 14)
	add_child(_title_label)

	custom_minimum_size = Vector2(
		float(MechGrid.GRID_WIDTH  * step - CELL_GAP),
		float(MechGrid.GRID_HEIGHT * step - CELL_GAP)
	)

	for y in range(MechGrid.GRID_HEIGHT):
		var row: Array = []
		for x in range(MechGrid.GRID_WIDTH):
			var panel := Panel.new()
			panel.position = Vector2(float(x * step), float(y * step))
			panel.size     = Vector2(float(CELL_SIZE), float(CELL_SIZE))
			_apply_style(panel, EMPTY_COLOR)

			var label := Label.new()
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_size_override("font_size", 10)
			panel.add_child(label)

			var pos := Vector2i(x, y)
			panel.gui_input.connect(_on_cell_gui_input.bind(pos))
			panel.mouse_entered.connect(_on_cell_entered.bind(pos))
			panel.mouse_exited.connect(_on_cell_exited.bind(pos))

			add_child(panel)
			row.append(panel)
		_panels.append(row)

# ── Public API ──────────────────────────────────────────────────────────────

func set_title(text: String) -> void:
	if _title_label:
		_title_label.text = text

## Redraw every cell to match the current grid state.
func refresh(grid: MechGrid) -> void:
	_current_grid = grid
	# Update center-of-mass for torque visualizer
	var mods := grid.get_all_modules()
	_show_com = not mods.is_empty()
	if _show_com:
		_com = PhysicsLite.new(grid).center_of_mass()
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			_redraw_cell(Vector2i(x, y))
	queue_redraw()

## Highlight cells where `module` can be placed on `grid`.
func highlight_valid(module: Module, grid: MechGrid) -> void:
	_highlighted = []
	_current_grid = grid
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			if grid.can_place(Vector2i(x, y), module):
				_highlighted.append(Vector2i(x, y))
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			_redraw_cell(Vector2i(x, y))

## Set a mode overlay on all grid cells to signal sell/upgrade intent visually.
## mode: "sell" (red border), "upgrade" (gold border), "" (clear).
func set_mode_overlay(mode: String, protected_cells: Array = []) -> void:
	_mode_overlay = mode
	_protected    = protected_cells
	if _current_grid:
		refresh(_current_grid)

## Remove all placement highlights and reset hover state.
func clear_highlights() -> void:
	_highlighted = []
	_hovered_pos = Vector2i(-1, -1)
	if _current_grid:
		refresh(_current_grid)

## Highlight the multi-cell footprint of `module` with origin at `origin`.
## Green if placement is valid, red if not.
func show_drag_footprint(origin: Vector2i, module: Module) -> void:
	var new_cells: Array = []
	for dy in range(module.grid_size.y):
		for dx in range(module.grid_size.x):
			new_cells.append(origin + Vector2i(dx, dy))
	var new_valid := _current_grid != null and _current_grid.can_place(origin, module)
	if new_cells == _fp_cells and new_valid == _fp_valid:
		return
	_fp_cells = new_cells
	_fp_valid  = new_valid
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			_redraw_cell(Vector2i(x, y))

## Clear the drag footprint and restore normal cell colours.
func clear_drag_footprint() -> void:
	if _fp_cells.is_empty():
		return
	_fp_cells = []
	if _current_grid:
		refresh(_current_grid)

# ── Torque visualizer ───────────────────────────────────────────────────────

func _draw() -> void:
	if CABLE_ENABLE and _current_grid != null:
		_draw_cables()
	if not _show_com:
		return
	var step := float(CELL_SIZE + CELL_GAP)
	# Ideal balance point — centre of 6×6 grid in pixel space
	var ideal := Vector2(MechGrid.GRID_WIDTH, MechGrid.GRID_HEIGHT) * step * 0.5
	# Actual centre-of-mass in pixel space
	var com_px := _com * step

	# Dim crosshair at ideal centre
	draw_line(ideal - Vector2(9, 0), ideal + Vector2(9, 0), Color(1, 1, 1, 0.25), 1.0)
	draw_line(ideal - Vector2(0, 9), ideal + Vector2(0, 9), Color(1, 1, 1, 0.25), 1.0)
	draw_circle(ideal, 3.0, Color(1, 1, 1, 0.25))

	# Orange COM indicator + line showing offset from ideal
	var offset := (com_px - ideal).length()
	if offset > 3.0:
		draw_line(ideal, com_px, Color("ff6030aa"), 1.5)
	# Pulse outer ring when torque imbalance is significant (> 30 px offset)
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 400.0)
	if offset > 30.0:
		draw_circle(com_px, 9.0 + 2.0 * pulse, Color(1.0, 0.38, 0.19, 0.4 * pulse))
	draw_circle(com_px, 5.0, Color("ff6030"))

	# Synergy borders — colour-coded per active synergy
	if _current_grid != null:
		var active_syns := SynergySystem.active_synergies(_current_grid)
		if not active_syns.is_empty():
			var cat_colors: Dictionary = {}
			for syn: Dictionary in active_syns:
				for cat: int in syn["cats"]:
					if not cat_colors.has(cat):
						cat_colors[cat] = syn["color"]
			for cy in range(MechGrid.GRID_HEIGHT):
				for cx in range(MechGrid.GRID_WIDTH):
					var cell := _current_grid.get_cell(Vector2i(cx, cy))
					if not cell.is_empty() and cat_colors.has(cell.module.category):
						var px := Vector2(float(cx), float(cy)) * step
						draw_rect(Rect2(px, Vector2(float(CELL_SIZE), float(CELL_SIZE))),
							cat_colors[cell.module.category], false, 2.0)

## Draw deterministic cable bundles between occupied cells to add mech-like wiring.
## - Links orthogonally adjacent occupied cells.
## - Adds "bridge" links across a 1-cell gap for denser mechanical silhouettes.
## - Skips links between cells owned by the same multi-cell module.
func _draw_cables() -> void:
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			var a := Vector2i(x, y)
			if not _is_occupied(a):
				continue

			var r := Vector2i(x + 1, y)
			if _is_linkable(a, r):
				_draw_cable_between(a, r, 1.0)
			var d := Vector2i(x, y + 1)
			if _is_linkable(a, d):
				_draw_cable_between(a, d, 1.0)

			# One-cell bridge links (A . B) make sparse builds look less disconnected.
			var r2 := Vector2i(x + 2, y)
			if _is_linkable(a, r2) and _is_empty_cell(Vector2i(x + 1, y)):
				_draw_cable_between(a, r2, 0.85)
			var d2 := Vector2i(x, y + 2)
			if _is_linkable(a, d2) and _is_empty_cell(Vector2i(x, y + 1)):
				_draw_cable_between(a, d2, 0.85)

func _draw_cable_between(a: Vector2i, b: Vector2i, thickness_scale: float) -> void:
	var start := _cable_anchor(a, b, true)
	var end := _cable_anchor(a, b, false)
	var d := end - start
	var len := d.length()
	if len < 2.0:
		return
	var dir := d / len
	var perp := Vector2(-dir.y, dir.x)

	var side := -1.0 if _cable_rand(a, b, 17) < 0.5 else 1.0
	var bend := (3.5 + 4.0 * _cable_rand(a, b, 23)) * side
	if maxi(absi(a.x - b.x), absi(a.y - b.y)) > 1:
		bend *= 1.35
	var mid := (start + end) * 0.5 + perp * bend

	var pts := PackedVector2Array([
		start,
		start.lerp(mid, 0.45),
		mid,
		mid.lerp(end, 0.55),
		end,
	])

	var w_shell := 4.4 * thickness_scale
	var w_hilite := 1.0 * thickness_scale
	draw_polyline(pts, CABLE_BASE_COL, w_shell + 1.6, true)
	draw_polyline(pts, CABLE_SHEATH_COL, w_shell, true)
	draw_polyline(pts, CABLE_HILITE_COL, w_hilite, true)
	draw_circle(start, 2.2 * thickness_scale, Color(0.16, 0.20, 0.26, 0.95))
	draw_circle(end,   2.2 * thickness_scale, Color(0.16, 0.20, 0.26, 0.95))
	draw_circle(start, 0.95 * thickness_scale, Color(0.68, 0.80, 0.92, 0.75))
	draw_circle(end,   0.95 * thickness_scale, Color(0.68, 0.80, 0.92, 0.75))

func _cable_anchor(a: Vector2i, b: Vector2i, from_a: bool) -> Vector2:
	var src := a if from_a else b
	var dst := b if from_a else a
	var step := float(CELL_SIZE + CELL_GAP)
	var center := Vector2(float(src.x) * step + float(CELL_SIZE) * 0.5, float(src.y) * step + float(CELL_SIZE) * 0.5)
	var delta := dst - src
	var inset := float(CELL_SIZE) * 0.28
	var jitter := (_cable_rand(a, b, 41 if from_a else 43) * 2.0 - 1.0) * 5.0

	if absi(delta.x) >= absi(delta.y):
		var sx: float = sign(float(delta.x))
		center.x += sx * inset
		center.y += jitter
	else:
		var sy: float = sign(float(delta.y))
		center.y += sy * inset
		center.x += jitter
	return center

func _is_linkable(a: Vector2i, b: Vector2i) -> bool:
	if not _in_bounds(a) or not _in_bounds(b):
		return false
	var ca := _current_grid.get_cell(a)
	var cb := _current_grid.get_cell(b)
	if ca == null or cb == null or ca.is_empty() or cb.is_empty():
		return false
	return ca.module != cb.module

func _is_occupied(pos: Vector2i) -> bool:
	if not _in_bounds(pos):
		return false
	var cell := _current_grid.get_cell(pos)
	return cell != null and not cell.is_empty()

func _is_empty_cell(pos: Vector2i) -> bool:
	if not _in_bounds(pos):
		return false
	var cell := _current_grid.get_cell(pos)
	return cell != null and cell.is_empty()

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < MechGrid.GRID_WIDTH and pos.y >= 0 and pos.y < MechGrid.GRID_HEIGHT

func _cable_rand(a: Vector2i, b: Vector2i, salt: int) -> float:
	var h: int = int((a.x + 1) * 73856093) ^ int((a.y + 3) * 19349663)
	h ^= int((b.x + 5) * 83492791) ^ int((b.y + 7) * 265443576)
	h ^= int(salt * 97531)
	h = absi(h % 1000)
	return float(h) / 999.0

# ── Internal rendering ──────────────────────────────────────────────────────

func _redraw_cell(pos: Vector2i) -> void:
	if _current_grid == null:
		return
	var cell:  GridCell = _current_grid.get_cell(pos)
	var panel: Panel    = _panels[pos.y][pos.x]
	var label: Label    = panel.get_child(0)

	var base: Color = EMPTY_COLOR if cell.is_empty() else CATEGORY_COLORS.get(cell.module.category, EMPTY_COLOR)
	if not cell.is_empty() and cell.module.disabled:
		base = base.darkened(0.65)

	var final_color := base
	var overlay_border: Color = Color.TRANSPARENT
	var overlay_border_w: int = 0

	if _fp_cells.has(pos):
		final_color = FOOTPRINT_VALID_COL if _fp_valid else FOOTPRINT_INVALID_COL
	elif _highlighted.has(pos):
		if cell.is_empty():
			final_color = HOVER_COLOR if pos == _hovered_pos else HIGHLIGHT_COLOR
		else:
			final_color = base.lightened(0.3)
	elif not cell.is_empty() and _mode_overlay != "":
		# Sell mode: red border on sellable cells; gold on protected (can't sell)
		if _mode_overlay == "sell":
			if pos in _protected:
				overlay_border   = Color("555520")
				overlay_border_w = 2
			else:
				overlay_border   = Color("c02020")
				overlay_border_w = 2
				final_color      = base.darkened(0.2)
		# Upgrade mode: gold border on cells that can still be upgraded
		elif _mode_overlay == "upgrade":
			if cell.module.star_level < Module.MAX_STARS:
				overlay_border   = Color("c0a020")
				overlay_border_w = 2
				final_color      = base.lightened(0.1)

	_apply_style(panel, final_color, overlay_border, overlay_border_w)
	if cell.is_empty():
		label.text = ""
	else:
		var stars := "★".repeat(cell.module.star_level - 1)
		label.text = cell.module.display_name + ("\n" + stars if stars else "")

func _apply_style(panel: Panel, color: Color, border: Color = Color.TRANSPARENT, border_w: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	if border != Color.TRANSPARENT and border_w > 1:
		style.border_color        = border
		style.border_width_left   = border_w
		style.border_width_right  = border_w
		style.border_width_top    = border_w
		style.border_width_bottom = border_w
	else:
		style.border_color        = color.lightened(0.25)
		style.border_width_left   = 1
		style.border_width_right  = 1
		style.border_width_top    = 1
		style.border_width_bottom = 1
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

# ── Input handlers ──────────────────────────────────────────────────────────

func _on_cell_gui_input(event: InputEvent, pos: Vector2i) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cell_clicked.emit(pos)

func _on_cell_entered(pos: Vector2i) -> void:
	cell_hovered.emit(pos)
	if not _highlighted.has(pos):
		return
	_hovered_pos = pos
	_redraw_cell(pos)

func _on_cell_exited(pos: Vector2i) -> void:
	cell_unhovered.emit()
	if _hovered_pos != pos:
		return
	_hovered_pos = Vector2i(-1, -1)
	_redraw_cell(pos)
