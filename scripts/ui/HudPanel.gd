## HudPanel — compact stat readout below the player grid.
## Shows a static analysis of the current mech build at any time.
## Call refresh(grid) after any module placement.
class_name HudPanel
extends Control

const BAR_W: int = 180
const BAR_H: int = 10
const ROW_H: int = 18
const LBL_W: int = 52

var _power_fill:  ColorRect
var _power_lbl:   Label
var _stab_fill:   ColorRect
var _stab_lbl:    Label
var _heat_fill:   ColorRect
var _heat_lbl:    Label
var _info_lbl:    Label

# ── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_build()

func _build() -> void:
	var rows := [
		["PWR",  0,          Color("30b040"), "_power_fill", "_power_lbl"],
		["STAB", ROW_H,      Color("30a0e0"), "_stab_fill",  "_stab_lbl"],
		["HEAT", ROW_H * 2,  Color("e06010"), "_heat_fill",  "_heat_lbl"],
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

	# Info line — paradox rate + heat balance
	_info_lbl = Label.new()
	_info_lbl.position = Vector2(0.0, float(ROW_H * 3 + 2))
	_info_lbl.size     = Vector2(404.0, float(ROW_H))
	_info_lbl.add_theme_font_size_override("font_size", 10)
	_info_lbl.modulate = Color(0.75, 0.75, 0.75)
	add_child(_info_lbl)

	custom_minimum_size = Vector2(404.0, float(ROW_H * 4))

# ── Public API ──────────────────────────────────────────────────────────────

func refresh(grid: MechGrid) -> void:
	var power_sys   := PowerSystem.new(grid)
	var physics_sys := PhysicsLite.new(grid)

	# Power
	var p_state := power_sys.get_state()
	var eff     := p_state.efficiency
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

	# Info line
	var parts: PackedStringArray = []
	if pdx_rate > 0.0:
		parts.append("PDX +%.0f/s" % pdx_rate)
	if not ai_modules.is_empty():
		parts.append("AI: " + ", ".join(ai_modules))
	_info_lbl.text = "  ".join(parts) if not parts.is_empty() else ""

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
