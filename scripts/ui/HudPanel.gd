## HudPanel — compact stat readout below the player grid.
## Shows a static analysis of the current mech build at any time.
## Call refresh(grid) after any module placement.
class_name HudPanel
extends Control

const BAR_W:      int = 180
const BAR_H:      int = 10
const ROW_H:      int = 18
const LBL_W:      int = 52
const MINI_BAR_W: int = 140
const MINI_BAR_H: int = 8
const MINI_ROW_H: int = 14
const MINI_LBL_W: int = 30
const QUAD_HEAT_REF: float = 15.0   # heat/s that fills a quadrant bar

var _power_fill:  ColorRect
var _power_lbl:   Label
var _stab_fill:   ColorRect
var _stab_lbl:    Label
var _heat_fill:   ColorRect
var _heat_lbl:    Label
var _pdx_fill:    ColorRect
var _pdx_lbl:     Label
var _info_lbl:    Label
var _quad_fills:  Array = []   # 4 × ColorRect  (TL, TR, BL, BR)
var _quad_lbls:   Array = []   # 4 × Label
var _pdx2_fill:   ColorRect
var _pdx2_lbl:    Label

# ── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_build()

func _build() -> void:
	var rows := [
		["PWR",  0,          Color("30b040"), "_power_fill", "_power_lbl"],
		["STAB", ROW_H,      Color("30a0e0"), "_stab_fill",  "_stab_lbl"],
		["HEAT", ROW_H * 2,  Color("e06010"), "_heat_fill",  "_heat_lbl"],
		["PDX",  ROW_H * 3,  Color("7030b0"), "_pdx_fill",   "_pdx_lbl"],
	]

	for row in rows:
		var tag: String  = row[0]
		var y_off: int   = row[1]
		var color: Color = row[2]
		var fill_key     = row[3]
		var lbl_key      = row[4]

		var tag_lbl := Label.new()
		tag_lbl.position = Vector2(0.0, float(y_off))
		tag_lbl.size     = Vector2(float(LBL_W), float(ROW_H))
		tag_lbl.text     = tag
		tag_lbl.add_theme_font_size_override("font_size", 10)
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(tag_lbl)

		var track := ColorRect.new()
		@warning_ignore("INTEGER_DIVISION")
		track.position = Vector2(float(LBL_W), float(y_off + (ROW_H - BAR_H) / 2))
		track.size     = Vector2(float(BAR_W), float(BAR_H))
		track.color    = Color("222222")
		add_child(track)

		var fill := ColorRect.new()
		fill.position = track.position
		fill.size     = Vector2(0.0, float(BAR_H))
		fill.color    = color
		add_child(fill)
		set(fill_key, fill)

		var val_lbl := Label.new()
		val_lbl.position = Vector2(float(LBL_W + BAR_W + 6), float(y_off))
		val_lbl.size     = Vector2(70.0, float(ROW_H))
		val_lbl.add_theme_font_size_override("font_size", 10)
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(val_lbl)
		set(lbl_key, val_lbl)

	# Info line — active AI module names
	_info_lbl = Label.new()
	_info_lbl.position = Vector2(0.0, float(ROW_H * 4 + 2))
	_info_lbl.size     = Vector2(404.0, float(ROW_H))
	_info_lbl.add_theme_font_size_override("font_size", 10)
	_info_lbl.modulate = Color(0.75, 0.75, 0.75)
	add_child(_info_lbl)

	# ── Heat quadrant mini-bars ─────────────────────────────────────────────
	var y_sep1: int = ROW_H * 5 + 2
	var sep1 := Label.new()
	sep1.position = Vector2(0.0, float(y_sep1))
	sep1.size     = Vector2(404.0, float(MINI_ROW_H))
	sep1.text     = "──── HEAT QUADRANTS ────"
	sep1.add_theme_font_size_override("font_size", 8)
	sep1.modulate = Color(0.45, 0.45, 0.5)
	sep1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(sep1)

	const QUAD_TAGS := ["TL", "TR", "BL", "BR"]
	for qi in range(4):
		var y_q: int = y_sep1 + MINI_ROW_H + qi * MINI_ROW_H

		var tag_lbl := Label.new()
		tag_lbl.position = Vector2(0.0, float(y_q))
		tag_lbl.size     = Vector2(float(MINI_LBL_W), float(MINI_ROW_H))
		tag_lbl.text     = QUAD_TAGS[qi]
		tag_lbl.add_theme_font_size_override("font_size", 9)
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(tag_lbl)

		var track := ColorRect.new()
		@warning_ignore("INTEGER_DIVISION")
		track.position = Vector2(float(MINI_LBL_W), float(y_q + (MINI_ROW_H - MINI_BAR_H) / 2))
		track.size     = Vector2(float(MINI_BAR_W), float(MINI_BAR_H))
		track.color    = Color("222222")
		add_child(track)

		var fill := ColorRect.new()
		fill.position = track.position
		fill.size     = Vector2(0.0, float(MINI_BAR_H))
		fill.color    = Color("e06010")
		add_child(fill)
		_quad_fills.append(fill)

		var val_lbl := Label.new()
		val_lbl.position = Vector2(float(MINI_LBL_W + MINI_BAR_W + 4), float(y_q))
		val_lbl.size     = Vector2(60.0, float(MINI_ROW_H))
		val_lbl.add_theme_font_size_override("font_size", 9)
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(val_lbl)
		_quad_lbls.append(val_lbl)

	# ── Bottom paradox bar ──────────────────────────────────────────────────
	var y_sep2: int = y_sep1 + MINI_ROW_H * 5 + 2
	var sep2 := Label.new()
	sep2.position = Vector2(0.0, float(y_sep2))
	sep2.size     = Vector2(404.0, float(MINI_ROW_H))
	sep2.text     = "──── PARADOX ────"
	sep2.add_theme_font_size_override("font_size", 8)
	sep2.modulate = Color(0.45, 0.35, 0.55)
	sep2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(sep2)

	var y_pdx2: int = y_sep2 + MINI_ROW_H
	var pdx2_tag := Label.new()
	pdx2_tag.position = Vector2(0.0, float(y_pdx2))
	pdx2_tag.size     = Vector2(float(MINI_LBL_W), float(MINI_ROW_H))
	pdx2_tag.text     = "PDX"
	pdx2_tag.add_theme_font_size_override("font_size", 9)
	pdx2_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(pdx2_tag)

	var pdx2_track := ColorRect.new()
	@warning_ignore("INTEGER_DIVISION")
	pdx2_track.position = Vector2(float(MINI_LBL_W), float(y_pdx2 + (MINI_ROW_H - MINI_BAR_H) / 2))
	pdx2_track.size     = Vector2(float(MINI_BAR_W), float(MINI_BAR_H))
	pdx2_track.color    = Color("222222")
	add_child(pdx2_track)

	_pdx2_fill = ColorRect.new()
	_pdx2_fill.position = pdx2_track.position
	_pdx2_fill.size     = Vector2(0.0, float(MINI_BAR_H))
	_pdx2_fill.color    = Color("7030b0")
	add_child(_pdx2_fill)

	_pdx2_lbl = Label.new()
	_pdx2_lbl.position = Vector2(float(MINI_LBL_W + MINI_BAR_W + 4), float(y_pdx2))
	_pdx2_lbl.size     = Vector2(60.0, float(MINI_ROW_H))
	_pdx2_lbl.add_theme_font_size_override("font_size", 9)
	_pdx2_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_pdx2_lbl)

	var total_h: int = y_pdx2 + MINI_ROW_H + 2
	custom_minimum_size = Vector2(404.0, float(total_h))

# ── Public API ──────────────────────────────────────────────────────────────

func refresh(grid: MechGrid) -> void:
	var power_sys   := PowerSystem.new(grid)
	var physics_sys := PhysicsLite.new(grid)

	# Power
	var p_state := power_sys.get_state()
	var eff: float = p_state.efficiency
	_set_bar(_power_fill, eff / PowerSystem.MAX_EFFICIENCY)
	_power_fill.color = _traffic_color(eff / PowerSystem.MAX_EFFICIENCY, Color("30b040"))
	_power_lbl.text   = "%.0f%%" % (eff * 100.0)

	# Stability
	var stab := physics_sys.stability_modifier()
	_set_bar(_stab_fill, stab)
	_stab_fill.color = _traffic_color(stab, Color("30a0e0"))
	_stab_lbl.text   = "%.0f%%" % (stab * 100.0)

	# Heat balance (gen rate vs dissipation capacity)
	var heat_gen   := 0.0
	var heat_cool  := 0.0
	var pdx_rate   := 0.0
	var ai_modules: Array[String] = []

	for mod: Module in grid.get_all_modules():
		heat_gen  += mod.heat_gen
		heat_cool += mod.heat_reduction
		if mod.paradox_rate > 0.0:
			pdx_rate += mod.paradox_rate
		if mod.category == Module.Category.AI:
			ai_modules.append(mod.display_name)

	var net_heat_rate := heat_gen - (HeatSystem.BASE_DISSIPATION + heat_cool)
	var heat_pressure := clampf(heat_gen / maxf(HeatSystem.BASE_DISSIPATION + heat_cool, 1.0), 0.0, 1.0)
	_set_bar(_heat_fill, heat_pressure)
	_heat_fill.color = _traffic_color(1.0 - heat_pressure, Color("e06010"))
	_heat_lbl.text   = "%+.0f/s" % (-net_heat_rate)

	# Paradox rate (max display = 50/s; danger colour above 30/s)
	const PDX_DISPLAY_MAX: float = 50.0
	_set_bar(_pdx_fill, pdx_rate / PDX_DISPLAY_MAX)
	_pdx_fill.color = Color("7030b0") if pdx_rate < 30.0 else Color("c03020")
	_pdx_lbl.text   = "+%.0f/s" % pdx_rate

	# Info line — AI modules active
	_info_lbl.text = ("AI: " + ", ".join(ai_modules)) if not ai_modules.is_empty() else ""

	# Heat quadrant mini-bars — TL=0, TR=1, BL=2, BR=3
	var quad_gen:  Array = [0.0, 0.0, 0.0, 0.0]
	var quad_cool: Array = [0.0, 0.0, 0.0, 0.0]
	for mod: Module in grid.get_all_modules():
		var mpos := grid.get_module_position(mod)
		if mpos.x < 0:
			continue
		var qi: int = (2 if mpos.y >= 3 else 0) + (1 if mpos.x >= 3 else 0)
		quad_gen[qi]  += mod.heat_gen
		if mod.category == Module.Category.THERMAL:
			quad_cool[qi] += mod.heat_reduction

	for qi in range(4):
		var fill_t := clampf(quad_gen[qi] / QUAD_HEAT_REF, 0.0, 1.0)
		_quad_fills[qi].size.x = fill_t * float(MINI_BAR_W)
		_quad_fills[qi].color  = _traffic_color(1.0 - fill_t, Color("e06010"))
		var net_q: float = float(quad_gen[qi]) - (HeatSystem.BASE_DISSIPATION / 4.0 + float(quad_cool[qi]))
		_quad_lbls[qi].text = "%+.0f/s" % (-net_q)

	# Bottom paradox bar (rate-based, same scale as top PDX bar)
	_pdx2_fill.size.x = clampf(pdx_rate / 50.0, 0.0, 1.0) * float(MINI_BAR_W)
	_pdx2_fill.color  = Color("7030b0") if pdx_rate < 30.0 else Color("c03020")
	_pdx2_lbl.text    = "+%.0f/s" % pdx_rate

# ── Helpers ─────────────────────────────────────────────────────────────────

func _set_bar(fill: ColorRect, t: float) -> void:
	fill.size.x = clampf(t, 0.0, 1.0) * float(BAR_W)

## Returns green/yellow/red based on ratio (1.0 = best).
func _traffic_color(ratio: float, good: Color) -> Color:
	if ratio >= 0.75:
		return good
	if ratio >= 0.4:
		return Color("c0a020")
	return Color("c03020")
