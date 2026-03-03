## MechGridView — visual 6×6 grid for one mech's module layout.
## Instantiate via MechGridView.new(), add to a CanvasLayer,
## then call set_title() and refresh(grid).
## Connect cell_clicked to handle player placement input.
class_name MechGridView
extends Control

signal cell_clicked(pos: Vector2i)

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
const EMPTY_COLOR     := Color("1e1e22")
const HIGHLIGHT_COLOR := Color("2a5a2a")   # valid placement cell
const HOVER_COLOR     := Color("4a9a20")   # hovered valid cell

var _panels:       Array     = []            # [y][x] → Panel
var _title_label:  Label
var _current_grid: MechGrid  = null
var _highlighted:  Array     = []            # Array[Vector2i] valid-placement positions
var _hovered_pos:  Vector2i  = Vector2i(-1, -1)
var _com:          Vector2   = Vector2(3.0, 3.0)   # center-of-mass in grid coords
var _show_com:     bool      = false

# ── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_build()

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

## Remove all placement highlights and reset hover state.
func clear_highlights() -> void:
	_highlighted = []
	_hovered_pos = Vector2i(-1, -1)
	if _current_grid:
		refresh(_current_grid)

# ── Torque visualizer ───────────────────────────────────────────────────────

func _draw() -> void:
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
	if (com_px - ideal).length() > 3.0:
		draw_line(ideal, com_px, Color("ff6030aa"), 1.5)
	draw_circle(com_px, 5.0, Color("ff6030"))

# ── Internal rendering ──────────────────────────────────────────────────────

func _redraw_cell(pos: Vector2i) -> void:
	if _current_grid == null:
		return
	var cell:  GridCell = _current_grid.get_cell(pos)
	var panel: Panel    = _panels[pos.y][pos.x]
	var label: Label    = panel.get_child(0)

	var base: Color = EMPTY_COLOR if cell.is_empty() else CATEGORY_COLORS.get(cell.module.category, EMPTY_COLOR)

	var final_color := base
	if _highlighted.has(pos):
		if cell.is_empty():
			final_color = HOVER_COLOR if pos == _hovered_pos else HIGHLIGHT_COLOR
		else:
			final_color = base.lightened(0.3)

	_apply_style(panel, final_color)
	label.text = "" if cell.is_empty() else cell.module.display_name

func _apply_style(panel: Panel, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color            = color
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
	if not _highlighted.has(pos):
		return
	_hovered_pos = pos
	_redraw_cell(pos)

func _on_cell_exited(pos: Vector2i) -> void:
	if _hovered_pos != pos:
		return
	_hovered_pos = Vector2i(-1, -1)
	_redraw_cell(pos)
