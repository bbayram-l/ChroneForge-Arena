## MechGridView — visual 6×6 grid for one mech's module layout.
## Instantiate via MechGridView.new(), add to a CanvasLayer,
## then call set_title() and refresh(grid).
## Connect cell_clicked to handle player placement input.
class_name MechGridView
extends Control

signal cell_clicked(pos: Vector2i)
signal cell_hovered(pos: Vector2i)
signal cell_unhovered

const CELL_SIZE: int = 60
const CELL_GAP:  int = 8
const MODULE_ART_PATH_FMT: String = "res://assets/modules/%s.png"

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
const CABLE_ANIM_FPS: float = 30.0
const CABLE_BASE_COL       := Color(0.05, 0.06, 0.08, 0.75)
const CABLE_SHEATH_COL     := Color(0.18, 0.22, 0.28, 0.90)
const CABLE_HILITE_COL     := Color(0.62, 0.74, 0.86, 0.42)
const CABLE_PULSE_COL      := Color(0.70, 0.90, 1.00, 0.70)
const STRUCT_SEAM_LIGHT    := Color(0.72, 0.82, 0.92, 0.16)
const STRUCT_SEAM_DARK     := Color(0.03, 0.04, 0.05, 0.42)
const STRUCT_BRACE_DARK    := Color(0.03, 0.04, 0.05, 0.40)
const STRUCT_BRACE_LIGHT   := Color(0.66, 0.76, 0.86, 0.12)
const STRUCT_RIVET_DARK    := Color(0.04, 0.05, 0.06, 0.86)
const STRUCT_RIVET_LIGHT   := Color(0.74, 0.84, 0.94, 0.36)

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
var _cache_dirty:  bool      = true
var _cables_active: bool     = false
var _anim_time: float        = 0.0
var _anim_redraw_accum: float = 0.0
var _cable_segments: Array   = []           # [{pts,thickness,phase,speed,leaf_tip}]
var _cable_nodes_px: PackedVector2Array = PackedVector2Array()
var _cable_leaf_tips: PackedVector2Array = PackedVector2Array()
var _struct_lines: Array     = []           # [{a,b,c,w}]
var _struct_rivets: Array    = []           # [{p,r}]
var _module_texture_cache: Dictionary = {}  # module_id -> Texture2D|null

# ── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_build()

func _process(delta: float) -> void:
	# Continuously redraw only when the torque visualizer has a significant imbalance
	# so the pulsing COM ring animates. Skipped when grid is empty.
	var needs_redraw := false
	if _show_com and _current_grid != null:
		var step := float(CELL_SIZE + CELL_GAP)
		var ideal := Vector2(MechGrid.GRID_WIDTH, MechGrid.GRID_HEIGHT) * step * 0.5
		if (_com * step - ideal).length() > 30.0:
			needs_redraw = true
	if CABLE_ENABLE and _cables_active:
		_anim_time += delta
		_anim_redraw_accum += delta
		var frame_step: float = 1.0 / CABLE_ANIM_FPS
		if _anim_redraw_accum >= frame_step:
			_anim_redraw_accum -= frame_step
			needs_redraw = true
	if needs_redraw:
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
			panel.clip_contents = true
			_apply_style(panel, EMPTY_COLOR)

			var art := TextureRect.new()
			art.name = "Art"
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.offset_left = 1.0
			art.offset_top = 1.0
			art.offset_right = -1.0
			art.offset_bottom = -1.0
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.mouse_filter = MOUSE_FILTER_IGNORE
			panel.add_child(art)

			var info_bg := ColorRect.new()
			info_bg.name = "InfoBg"
			info_bg.anchor_left = 0.0
			info_bg.anchor_top = 1.0
			info_bg.anchor_right = 1.0
			info_bg.anchor_bottom = 1.0
			info_bg.offset_left = 1.0
			info_bg.offset_top = -18.0
			info_bg.offset_right = -1.0
			info_bg.offset_bottom = -1.0
			info_bg.color = Color(0.04, 0.05, 0.06, 0.72)
			info_bg.mouse_filter = MOUSE_FILTER_IGNORE
			panel.add_child(info_bg)

			var label := Label.new()
			label.name = "InfoLabel"
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
			label.offset_left          = 2.0
			label.offset_top           = 2.0
			label.offset_right         = -2.0
			label.offset_bottom        = -2.0
			label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_size_override("font_size", 8)
			label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
			label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.95))
			label.add_theme_constant_override("outline_size", 2)
			label.mouse_filter = MOUSE_FILTER_IGNORE
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
	_cache_dirty = true
	_anim_redraw_accum = 0.0
	_rebuild_visual_cache()
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
	if _cache_dirty:
		_rebuild_visual_cache()
	if _current_grid != null:
		_draw_structural_overlay()
		if CABLE_ENABLE:
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

## Draw cached structural seam/rivet overlays for a more industrial mech panel look.
func _draw_structural_overlay() -> void:
	for line_v in _struct_lines:
		var line: Dictionary = line_v
		var a: Vector2 = line["a"]
		var b: Vector2 = line["b"]
		var col: Color = line["c"]
		var w: float = float(line["w"])
		draw_line(a, b, col, w, true)
	for rivet_v in _struct_rivets:
		var rivet: Dictionary = rivet_v
		var p: Vector2 = rivet["p"]
		var r: float = float(rivet["r"])
		draw_circle(p, r + 0.55, STRUCT_RIVET_DARK)
		draw_circle(p, r, STRUCT_RIVET_LIGHT)

## Draw the cached cable tree (branches + leaves) with animated shading.
func _draw_cables() -> void:
	for seg_v in _cable_segments:
		var seg: Dictionary = seg_v
		var pts: PackedVector2Array = seg["pts"]
		if pts.size() < 2:
			continue
		var th: float = float(seg["thickness"])
		var phase: float = float(seg["phase"])
		var speed: float = float(seg["speed"])
		var is_leaf_tip: bool = bool(seg["leaf_tip"])
		var pulse: float = 0.5 + 0.5 * sin((_anim_time * speed * TAU) + phase)
		var w_shell: float = 5.2 * th
		var w_hilite: float = 1.0 * th
		var shadow_pts := _offset_polyline(pts, Vector2(1.4, 1.4))
		draw_polyline(shadow_pts, Color(0, 0, 0, 0.26), w_shell + 2.0, true)
		draw_polyline(pts, CABLE_BASE_COL, w_shell + 1.4, true)
		var sheath_col := CABLE_SHEATH_COL.darkened(0.14 - 0.08 * pulse)
		draw_polyline(pts, sheath_col, w_shell, true)
		var hilite_col := CABLE_HILITE_COL
		hilite_col.a = (0.18 + 0.24 * pulse) * (0.70 if is_leaf_tip else 1.0)
		draw_polyline(pts, hilite_col, w_hilite, true)

		var pulse_t: float = fposmod((_anim_time * speed) + phase / TAU, 1.0)
		var pulse_pos := _sample_polyline(pts, pulse_t)
		var pulse_col := CABLE_PULSE_COL
		pulse_col.a = (0.20 + 0.32 * pulse) * (0.8 if is_leaf_tip else 1.0)
		var pulse_r: float = (1.0 + 1.4 * th) * (0.85 if is_leaf_tip else 1.0)
		draw_circle(pulse_pos, pulse_r, pulse_col)
		draw_circle(pulse_pos, pulse_r * 0.46, Color(0.96, 1.0, 1.0, 0.45))

		# Edge sockets at both ends keep cable readability high in tight builds.
		var start_p: Vector2 = pts[0]
		var end_p: Vector2 = pts[pts.size() - 1]
		var sock_r: float = 1.15 + th * 1.25
		draw_circle(start_p, sock_r + 0.45, Color(0.06, 0.08, 0.10, 0.90))
		draw_circle(end_p, sock_r + 0.45, Color(0.06, 0.08, 0.10, 0.90))
		draw_circle(start_p, sock_r, Color(0.76, 0.88, 0.98, 0.48))
		draw_circle(end_p, sock_r, Color(0.76, 0.88, 0.98, 0.48))

	for node_pos: Vector2 in _cable_nodes_px:
		draw_circle(node_pos, 2.4, Color(0.13, 0.16, 0.20, 0.96))
		draw_circle(node_pos, 1.1, Color(0.76, 0.86, 0.94, 0.60))

	var leaf_glow: float = 0.5 + 0.5 * sin(_anim_time * 4.5)
	for tip_pos: Vector2 in _cable_leaf_tips:
		draw_circle(tip_pos, 1.8, Color(0.72, 0.88, 1.0, 0.18 + 0.20 * leaf_glow))

## Rebuild all geometry used by overlay rendering.
## Heavy work happens only when grid contents change; draw loop reuses this cache.
func _rebuild_visual_cache() -> void:
	_cable_segments = []
	_cable_nodes_px = PackedVector2Array()
	_cable_leaf_tips = PackedVector2Array()
	_struct_lines = []
	_struct_rivets = []
	_cables_active = false
	if _current_grid == null:
		_cache_dirty = false
		return
	_build_structural_cache()
	if CABLE_ENABLE:
		_build_cable_cache()
	_cables_active = not _cable_segments.is_empty()
	_cache_dirty = false

func _build_structural_cache() -> void:
	var step: float = float(CELL_SIZE + CELL_GAP)
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			var pos := Vector2i(x, y)
			if not _is_occupied_cell(pos):
				continue
			var tl := Vector2(float(x) * step, float(y) * step)
			var tr := tl + Vector2(float(CELL_SIZE), 0.0)
			var bl := tl + Vector2(0.0, float(CELL_SIZE))
			var br := tl + Vector2(float(CELL_SIZE), float(CELL_SIZE))
			var o: float = 4.0
			var i: float = 11.0

			if not _is_occupied_cell(Vector2i(x, y - 1)):
				_add_struct_line(tl + Vector2(o, o), tr + Vector2(-o, o), STRUCT_SEAM_LIGHT, 1.2)
			if not _is_occupied_cell(Vector2i(x - 1, y)):
				_add_struct_line(tl + Vector2(o, o), bl + Vector2(o, -o), STRUCT_SEAM_LIGHT, 1.2)
			if not _is_occupied_cell(Vector2i(x + 1, y)):
				_add_struct_line(tr + Vector2(-o, o), br + Vector2(-o, -o), STRUCT_SEAM_DARK, 1.3)
			if not _is_occupied_cell(Vector2i(x, y + 1)):
				_add_struct_line(bl + Vector2(o, -o), br + Vector2(-o, -o), STRUCT_SEAM_DARK, 1.3)

			_add_struct_line(tl + Vector2(i, float(CELL_SIZE) - i), tr + Vector2(-i, i), STRUCT_BRACE_DARK, 1.4)
			_add_struct_line(tl + Vector2(i + 1.0, float(CELL_SIZE) - i - 1.0), tr + Vector2(-i - 1.0, i + 1.0), STRUCT_BRACE_LIGHT, 0.9)
			_add_struct_rivet(tl + Vector2(8.0, 8.0), 1.1)
			_add_struct_rivet(tr + Vector2(-8.0, 8.0), 1.1)
			_add_struct_rivet(bl + Vector2(8.0, -8.0), 1.1)
			_add_struct_rivet(br + Vector2(-8.0, -8.0), 1.1)

			var cell: GridCell = _current_grid.get_cell(pos)
			if cell != null and not cell.is_empty() and cell.module.category == Module.Category.STRUCTURAL:
				var y_mid: float = float(CELL_SIZE) * 0.5
				_add_struct_line(tl + Vector2(10.0, y_mid), tr + Vector2(-10.0, y_mid), Color(0.76, 0.84, 0.92, 0.23), 1.3)

func _build_cable_cache() -> void:
	var nodes := _collect_module_nodes()
	if nodes.is_empty():
		return

	for node_v in nodes:
		var node: Dictionary = node_v
		_cable_nodes_px.append(node["center"])

	var root_idx := _nearest_root_index(nodes)
	var tree_edges := _build_tree_edges(nodes, root_idx)
	var info := _build_depth_info(nodes.size(), root_idx, tree_edges)
	var depths: Array = info["depths"]
	var child_counts: Array = info["child_counts"]
	var max_depth: int = int(info["max_depth"])
	var degrees: Array = []
	degrees.resize(nodes.size())
	for i in range(nodes.size()):
		degrees[i] = 0
	for edge_v in tree_edges:
		var edge: Dictionary = edge_v
		var p_i: int = int(edge["parent"])
		var c_i: int = int(edge["child"])
		degrees[p_i] = int(degrees[p_i]) + 1
		degrees[c_i] = int(degrees[c_i]) + 1

	for edge_v in tree_edges:
		var edge: Dictionary = edge_v
		var parent_idx: int = int(edge["parent"])
		var child_idx: int = int(edge["child"])
		var parent_node: Dictionary = nodes[parent_idx]
		var child_node: Dictionary = nodes[child_idx]
		var parent_center: Vector2 = parent_node["center"]
		var child_center: Vector2 = child_node["center"]
		var start := _module_anchor_towards(parent_node, child_center, parent_idx, child_idx, true)
		var end := _module_anchor_towards(child_node, parent_center, parent_idx, child_idx, false)
		var depth_i: int = int(depths[child_idx])
		var depth_ratio: float = float(depth_i) / float(maxi(1, max_depth))
		var thickness: float = lerpf(1.24, 0.72, depth_ratio)
		if int(child_counts[child_idx]) == 0:
			thickness *= 0.92
		var seed: int = _hash_int((parent_idx + 5) * 11887 ^ (child_idx + 11) * 17749)
		_append_branch_segment(start, end, thickness, seed, false)

	if tree_edges.is_empty():
		var root_room: int = maxi(0, 2 - int(degrees[root_idx]))
		_append_leaf_segments(root_idx, -1, nodes, depths, max_depth, root_room)
		return

	for i in range(nodes.size()):
		if i == root_idx:
			continue
		if int(child_counts[i]) != 0:
			continue
		var parent_idx: int = -1
		for edge_v in tree_edges:
			var edge: Dictionary = edge_v
			if int(edge["child"]) == i:
				parent_idx = int(edge["parent"])
				break
		var room: int = maxi(0, 2 - int(degrees[i]))
		_append_leaf_segments(i, parent_idx, nodes, depths, max_depth, room)

func _collect_module_nodes() -> Array:
	var grouped: Dictionary = {}
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			var pos := Vector2i(x, y)
			var cell: GridCell = _current_grid.get_cell(pos)
			if cell == null or cell.is_empty():
				continue
			var module_id: int = cell.module.get_instance_id()
			if not grouped.has(module_id):
				grouped[module_id] = {"sum": Vector2.ZERO, "count": 0}
			var entry: Dictionary = grouped[module_id]
			var sum: Vector2 = entry["sum"]
			sum += _cell_center(pos)
			entry["sum"] = sum
			entry["count"] = int(entry["count"]) + 1
			grouped[module_id] = entry

	var keys: Array = grouped.keys()
	keys.sort()
	var nodes: Array = []
	for key_v in keys:
		var module_id: int = int(key_v)
		var entry: Dictionary = grouped[module_id]
		var count: int = int(entry["count"])
		if count <= 0:
			continue
		var sum: Vector2 = entry["sum"]
		var center: Vector2 = sum / float(count)
		# Small deterministic offset prevents mirrored perfect symmetry.
		var cx_i: int = int(round(center.x))
		var cy_i: int = int(round(center.y))
		var nudge := Vector2(
			(_rand01(module_id ^ cx_i, 701) * 2.0 - 1.0) * 2.3,
			(_rand01(module_id ^ cy_i, 709) * 2.0 - 1.0) * 2.3
		)
		nodes.append({
			"id": module_id,
			"center": center + nudge,
		})
	return nodes

func _nearest_root_index(nodes: Array) -> int:
	var step: float = float(CELL_SIZE + CELL_GAP)
	var center_target := Vector2(
		float(MechGrid.GRID_WIDTH) * step * 0.5,
		float(MechGrid.GRID_HEIGHT) * step * 0.5
	)
	var best_idx: int = 0
	var best_d: float = 1e20
	for i in range(nodes.size()):
		var node: Dictionary = nodes[i]
		var center: Vector2 = node["center"]
		var d: float = center.distance_squared_to(center_target)
		if d < best_d:
			best_d = d
			best_idx = i
	return best_idx

func _build_tree_edges(nodes: Array, root_idx: int) -> Array:
	var edges: Array = []
	if nodes.size() <= 1:
		return edges

	# Degree-capped path growth:
	# always extend from one of two current chain endpoints.
	# This guarantees every node has <= 2 cable connections.
	var left_end: int = root_idx
	var right_end: int = root_idx
	var degrees: Array = []
	degrees.resize(nodes.size())
	for i in range(nodes.size()):
		degrees[i] = 0
	var remaining: Dictionary = {}
	for i in range(nodes.size()):
		if i != root_idx:
			remaining[i] = true

	while not remaining.is_empty():
		var best_side: int = -1 # 0 = left, 1 = right
		var best_parent: int = -1
		var best_child: int = -1
		var best_score: float = 1e20

		var rem_keys: Array = remaining.keys()
		rem_keys.sort()
		for side in [0, 1]:
			var p: int = left_end if side == 0 else right_end
			if int(degrees[p]) >= 2:
				continue
			var p_node: Dictionary = nodes[p]
			var p_center: Vector2 = p_node["center"]
			for c_v in rem_keys:
				var c: int = int(c_v)
				var c_node: Dictionary = nodes[c]
				var c_center: Vector2 = c_node["center"]
				var axis_pen: float = 0.08 * float(min(abs(p_center.x - c_center.x), abs(p_center.y - c_center.y)))
				var asym_seed: int = _hash_int(
					(p + 1) * 92821
					^ (c + 1) * 68917
					^ int(p_center.x) * 19349663
					^ int(c_center.y) * 83492791
					^ side * 97531
				)
				var asym_noise: float = (_rand01(asym_seed, 73) - 0.5) * 7.0
				var score: float = p_center.distance_to(c_center) + axis_pen + asym_noise
				if score < best_score:
					best_score = score
					best_side = side
					best_parent = p
					best_child = c

		if best_child < 0:
			break
		edges.append({"parent": best_parent, "child": best_child})
		degrees[best_parent] = int(degrees[best_parent]) + 1
		degrees[best_child] = int(degrees[best_child]) + 1
		if best_side == 0:
			left_end = best_child
		else:
			right_end = best_child
		remaining.erase(best_child)

	return edges

func _build_depth_info(node_count: int, root_idx: int, tree_edges: Array) -> Dictionary:
	var depths: Array = []
	var child_counts: Array = []
	depths.resize(node_count)
	child_counts.resize(node_count)
	for i in range(node_count):
		depths[i] = -1
		child_counts[i] = 0
	depths[root_idx] = 0

	var max_depth: int = 0
	for edge_v in tree_edges:
		var edge: Dictionary = edge_v
		var p: int = int(edge["parent"])
		var c: int = int(edge["child"])
		var d_parent: int = int(depths[p])
		var d_child: int = d_parent + 1
		depths[c] = d_child
		child_counts[p] = int(child_counts[p]) + 1
		max_depth = maxi(max_depth, d_child)

	return {
		"depths": depths,
		"child_counts": child_counts,
		"max_depth": max_depth,
	}

func _module_anchor_towards(node: Dictionary, to_point: Vector2, parent_idx: int, child_idx: int, from_parent: bool) -> Vector2:
	var center: Vector2 = node["center"]
	var dir := to_point - center
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var node_id: int = int(node["id"])
	var salt: int = (17 if from_parent else 29) + parent_idx * 97 + child_idx * 151 + node_id
	var jitter: float = (_rand01(node_id, salt) * 2.0 - 1.0) * (float(CELL_SIZE) * 0.085)
	# Push anchors slightly into the inter-cell gap so cables remain visible.
	var out_to_gap: float = float(CELL_SIZE) * 0.5 + float(CELL_GAP) * 0.28
	return center + dir * out_to_gap + perp * jitter

func _append_branch_segment(start: Vector2, end: Vector2, thickness: float, seed: int, leaf_tip: bool) -> void:
	var delta := end - start
	var len: float = delta.length()
	if len < 4.0:
		return
	var dir := delta / len
	var perp := Vector2(-dir.y, dir.x)
	var spatial_seed: int = _hash_int(
		seed
		^ int(start.x * 37.0) * 73856093
		^ int(start.y * 41.0) * 19349663
		^ int(end.x * 43.0) * 83492791
		^ int(end.y * 47.0) * 265443576
	)
	var side: float = -1.0 if _rand01(spatial_seed, 11) < 0.5 else 1.0
	var bend: float = lerpf(4.4, 12.8, _rand01(spatial_seed, 13)) * side
	if len > float(CELL_SIZE + CELL_GAP):
		bend *= 1.25
	var mid := (start + end) * 0.5 + perp * bend
	var lead_t: float = 0.36 + _rand01(spatial_seed, 17) * 0.15
	var tail_t: float = 0.48 + _rand01(spatial_seed, 19) * 0.15
	var pts := PackedVector2Array([
		start,
		start.lerp(mid, lead_t),
		mid,
		mid.lerp(end, tail_t),
		end,
	])
	_cable_segments.append({
		"pts": pts,
		"thickness": thickness,
		"phase": _rand01(spatial_seed, 23) * TAU,
		"speed": lerpf(0.20, 0.46, _rand01(spatial_seed, 29)),
		"leaf_tip": leaf_tip,
	})
	if leaf_tip:
		_cable_leaf_tips.append(end)

func _append_leaf_segments(node_idx: int, parent_idx: int, nodes: Array, depths: Array, max_depth: int, max_extra_connections: int) -> void:
	if max_extra_connections <= 0:
		return
	var node: Dictionary = nodes[node_idx]
	var center: Vector2 = node["center"]
	var outward := Vector2.RIGHT
	if parent_idx >= 0:
		var parent: Dictionary = nodes[parent_idx]
		var parent_center: Vector2 = parent["center"]
		var away := center - parent_center
		if away.length_squared() > 0.0001:
			outward = away.normalized()

	var depth_i: int = int(depths[node_idx])
	var depth_ratio: float = float(depth_i) / float(maxi(1, max_depth))
	var node_id: int = int(node["id"])
	var base_seed: int = _hash_int(node_id ^ (node_idx + 3) * 809 ^ (parent_idx + 11) * 1237)
	var leaf_count: int = 1 + int(_rand01(base_seed, 31) > 0.64)
	leaf_count = mini(leaf_count, max_extra_connections)
	if leaf_count <= 0:
		return

	for i in range(leaf_count):
		var seed: int = _hash_int(base_seed ^ (i + 1) * 2971)
		var angle: float = deg_to_rad(28.0 + 50.0 * _rand01(seed, 37))
		if _rand01(seed, 41) < 0.5:
			angle = -angle
		var dir := outward.rotated(angle)
		var start := center + dir * (float(CELL_SIZE) * 0.27)
		var len_px: float = lerpf(11.0, 20.0, _rand01(seed, 43)) * lerpf(1.0, 0.74, depth_ratio)
		var end := start + dir * len_px
		var perp := Vector2(-dir.y, dir.x)
		var mid := start.lerp(end, 0.55) + perp * ((_rand01(seed, 47) * 2.0 - 1.0) * 2.4)
		var pts := PackedVector2Array([start, mid, end])
		_cable_segments.append({
			"pts": pts,
			"thickness": lerpf(0.48, 0.38, depth_ratio),
			"phase": _rand01(seed, 53) * TAU,
			"speed": lerpf(0.30, 0.62, _rand01(seed, 59)),
			"leaf_tip": true,
		})
		_cable_leaf_tips.append(end)

func _sample_polyline(pts: PackedVector2Array, t: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	if pts.size() == 1:
		return pts[0]
	var total_len: float = 0.0
	for i in range(pts.size() - 1):
		total_len += pts[i].distance_to(pts[i + 1])
	if total_len <= 0.0001:
		return pts[pts.size() - 1]
	var target: float = clamp(t, 0.0, 1.0) * total_len
	var run: float = 0.0
	for i in range(pts.size() - 1):
		var seg_len: float = pts[i].distance_to(pts[i + 1])
		if run + seg_len >= target:
			var lt: float = 0.0 if seg_len <= 0.0001 else (target - run) / seg_len
			return pts[i].lerp(pts[i + 1], lt)
		run += seg_len
	return pts[pts.size() - 1]

func _offset_polyline(pts: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p + delta)
	return out

func _add_struct_line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	_struct_lines.append({"a": a, "b": b, "c": col, "w": w})

func _add_struct_rivet(p: Vector2, r: float) -> void:
	_struct_rivets.append({"p": p, "r": r})

func _is_occupied_cell(pos: Vector2i) -> bool:
	if _current_grid == null or not _in_bounds(pos):
		return false
	var cell: GridCell = _current_grid.get_cell(pos)
	return cell != null and not cell.is_empty()

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < MechGrid.GRID_WIDTH and pos.y >= 0 and pos.y < MechGrid.GRID_HEIGHT

func _cell_center(pos: Vector2i) -> Vector2:
	var step: float = float(CELL_SIZE + CELL_GAP)
	return Vector2(
		float(pos.x) * step + float(CELL_SIZE) * 0.5,
		float(pos.y) * step + float(CELL_SIZE) * 0.5
	)

func _hash_int(v: int) -> int:
	var h: int = v
	h = int(h * 1664525 + 1013904223)
	h ^= (h >> 16)
	h = int(h * 2246822519)
	h ^= (h >> 13)
	return absi(h)

func _rand01(a: int, b: int = 0) -> float:
	var h: int = _hash_int(a ^ int(b * 1103515245))
	return float(h % 10000) / 9999.0

# ── Internal rendering ──────────────────────────────────────────────────────

func _redraw_cell(pos: Vector2i) -> void:
	if _current_grid == null:
		return
	var cell:  GridCell = _current_grid.get_cell(pos)
	var panel: Panel    = _panels[pos.y][pos.x]
	var art: TextureRect = panel.get_node("Art") as TextureRect
	var info_bg: ColorRect = panel.get_node("InfoBg") as ColorRect
	var label: Label = panel.get_node("InfoLabel") as Label

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
		if art != null:
			art.texture = null
			art.visible = false
		if info_bg != null:
			info_bg.visible = false
		label.text = ""
	else:
		if art != null:
			var tex: Texture2D = _get_module_texture(cell.module.id)
			art.texture = tex
			art.visible = tex != null
			art.modulate = Color(1.0, 1.0, 1.0, 0.40 if cell.module.disabled else 0.96)
		var stars := "★".repeat(cell.module.star_level - 1)
		label.text = cell.module.display_name + ("\n" + stars if stars else "")
		if info_bg != null:
			info_bg.visible = true

func _get_module_texture(module_id: String) -> Texture2D:
	if _module_texture_cache.has(module_id):
		return _module_texture_cache[module_id] as Texture2D
	var path: String = MODULE_ART_PATH_FMT % module_id
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_module_texture_cache[module_id] = tex
	return tex

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
