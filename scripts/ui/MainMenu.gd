## MainMenu — entry-point scene for ChronoForge Arena.
## Programmatic UI consistent with the rest of the codebase.
extends Node

var _fullscreen:        bool    = false
var _changelog_overlay: Control = null
var _accent_bar: ColorRect = null
var _title_label: Label = null
var _tag_label: Label = null
var _play_btn: Button = null
var _idle_t: float = 0.0

func _ready() -> void:
	_build_ui()
	set_process(true)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Background
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size     = Vector2(1280.0, 800.0)
	bg.color    = Color(0.04, 0.04, 0.06)
	canvas.add_child(bg)

	# Accent bar (top)
	_accent_bar = ColorRect.new()
	_accent_bar.position = Vector2(0.0, 0.0)
	_accent_bar.size     = Vector2(1280.0, 4.0)
	_accent_bar.color    = Color(0.9, 0.5, 0.1)
	canvas.add_child(_accent_bar)

	# Title
	_title_label = Label.new()
	_title_label.position = Vector2(0.0, 230.0)
	_title_label.size     = Vector2(1280.0, 80.0)
	_title_label.text     = "CHRONOFORGE ARENA"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 54)
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.58, 0.12))
	canvas.add_child(_title_label)

	# Tagline
	_tag_label = Label.new()
	_tag_label.position = Vector2(0.0, 316.0)
	_tag_label.size     = Vector2(1280.0, 28.0)
	_tag_label.text     = "Build unstable modular mechs.  Break physics.  Bend time."
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.add_theme_font_size_override("font_size", 15)
	_tag_label.modulate = Color(0.55, 0.55, 0.62)
	canvas.add_child(_tag_label)

	# Divider
	var div := ColorRect.new()
	div.position = Vector2(540.0, 358.0)
	div.size     = Vector2(200.0, 1.0)
	div.color    = Color(0.3, 0.3, 0.35)
	canvas.add_child(div)

	# PLAY button
	_play_btn = _make_btn("PLAY", Vector2(515.0, 376.0), Vector2(250.0, 56.0), 22, true)
	_play_btn.name = "PlayBtn"
	_play_btn.pressed.connect(_on_play)
	canvas.add_child(_play_btn)

	# Fullscreen toggle
	var fs_btn := _make_btn("FULLSCREEN: OFF", Vector2(515.0, 444.0), Vector2(250.0, 38.0), 13)
	fs_btn.name = "FullscreenBtn"
	fs_btn.pressed.connect(_on_fullscreen_pressed.bind(fs_btn))
	canvas.add_child(fs_btn)

	# QUIT button
	var quit_btn := _make_btn("QUIT", Vector2(515.0, 494.0), Vector2(250.0, 38.0), 13)
	quit_btn.name = "QuitBtn"
	quit_btn.pressed.connect(_on_quit)
	canvas.add_child(quit_btn)

	# WHAT'S NEW button
	var log_btn := _make_btn("WHAT'S NEW", Vector2(515.0, 544.0), Vector2(250.0, 38.0), 13)
	log_btn.name = "ChangelogBtn"
	log_btn.pressed.connect(_on_changelog_pressed.bind(canvas))
	canvas.add_child(log_btn)
	_play_btn.focus_neighbor_bottom = NodePath("../FullscreenBtn")
	fs_btn.focus_neighbor_top = NodePath("../PlayBtn")
	fs_btn.focus_neighbor_bottom = NodePath("../QuitBtn")
	quit_btn.focus_neighbor_top = NodePath("../FullscreenBtn")
	quit_btn.focus_neighbor_bottom = NodePath("../ChangelogBtn")
	log_btn.focus_neighbor_top = NodePath("../QuitBtn")
	call_deferred("_focus_play_button")

	# Version label (bottom-right) — read from version.txt at runtime
	var ver := Label.new()
	ver.position = Vector2(1120.0, 782.0)
	ver.size     = Vector2(150.0, 16.0)
	ver.text     = "v%s-demo" % _read_version()
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_font_size_override("font_size", 10)
	ver.modulate = Color(0.35, 0.35, 0.38)
	canvas.add_child(ver)

func _make_btn(text: String, pos: Vector2, sz: Vector2, font_size: int, primary: bool = false) -> Button:
	var btn := Button.new()
	btn.position = pos
	btn.size     = sz
	btn.text     = text
	btn.add_theme_font_size_override("font_size", font_size)
	btn.focus_mode = Control.FOCUS_ALL
	_style_menu_btn(btn, primary)
	return btn

func _style_menu_btn(btn: Button, primary: bool) -> void:
	var bg := Color("3a2a18") if primary else Color("1e2026")
	var hov := Color("5a3d20") if primary else Color("2a2e38")
	var press := Color("754c20") if primary else Color("38414f")

	var sn := StyleBoxFlat.new()
	sn.bg_color = bg
	sn.border_color = Color(0.62, 0.43, 0.20, 0.35) if primary else Color(0.45, 0.48, 0.55, 0.35)
	sn.set_border_width_all(1)
	sn.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sn)

	var sh := StyleBoxFlat.new()
	sh.bg_color = hov
	sh.border_color = Color(0.95, 0.78, 0.42, 0.55) if primary else Color(0.78, 0.82, 0.92, 0.45)
	sh.set_border_width_all(2)
	sh.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", sh)

	var sp := StyleBoxFlat.new()
	sp.bg_color = press
	sp.border_color = Color(0.98, 0.82, 0.45) if primary else Color(0.84, 0.88, 0.96, 0.6)
	sp.set_border_width_all(2)
	sp.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", sp)

	var sf := StyleBoxFlat.new()
	sf.bg_color = hov
	sf.border_color = Color(1.0, 0.85, 0.45)
	sf.set_border_width_all(3)
	sf.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("focus", sf)

	var sd := StyleBoxFlat.new()
	sd.bg_color = bg.darkened(0.35)
	sd.border_color = Color(0.35, 0.35, 0.35, 0.35)
	sd.set_border_width_all(1)
	sd.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("disabled", sd)

func _focus_play_button() -> void:
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.grab_focus()

func _process(delta: float) -> void:
	_idle_t += delta
	if _title_label != null:
		_title_label.position.y = 230.0 + sin(_idle_t * 1.15) * 2.5
	if _tag_label != null:
		_tag_label.position.y = 316.0 + sin(_idle_t * 0.95 + 0.8) * 1.5
		var alpha := 0.72 + 0.16 * (0.5 + 0.5 * sin(_idle_t * 1.1))
		_tag_label.modulate = Color(0.55, 0.55, 0.62, alpha)
	if _accent_bar != null:
		var g := 0.50 + 0.05 * sin(_idle_t * 1.05)
		var b := 0.10 + 0.03 * sin(_idle_t * 1.65 + 1.3)
		_accent_bar.color = Color(0.90, g, b, 1.0)

# ── Handlers ────────────────────────────────────────────────────────────────

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_fullscreen_pressed(btn: Button) -> void:
	_fullscreen = not _fullscreen
	if _fullscreen:
		get_window().mode = Window.MODE_FULLSCREEN
		btn.text = "FULLSCREEN: ON"
	else:
		get_window().mode = Window.MODE_WINDOWED
		btn.text = "FULLSCREEN: OFF"

func _on_quit() -> void:
	get_tree().quit()

func _on_changelog_pressed(canvas: CanvasLayer) -> void:
	if _changelog_overlay != null:
		_changelog_overlay.visible = true
		return
	_build_changelog_overlay(canvas)

func _build_changelog_overlay(canvas: CanvasLayer) -> void:
	_changelog_overlay = Control.new()
	_changelog_overlay.position = Vector2.ZERO
	_changelog_overlay.size     = Vector2(1280.0, 800.0)
	canvas.add_child(_changelog_overlay)

	# Dim background
	var dim := ColorRect.new()
	dim.position = Vector2.ZERO
	dim.size     = Vector2(1280.0, 800.0)
	dim.color    = Color(0.0, 0.0, 0.0, 0.72)
	_changelog_overlay.add_child(dim)

	# Panel
	var panel := Panel.new()
	panel.position = Vector2(190.0, 72.0)
	panel.size     = Vector2(900.0, 656.0)
	_changelog_overlay.add_child(panel)

	# Title bar
	var title_bar := ColorRect.new()
	title_bar.position = Vector2(0.0, 0.0)
	title_bar.size     = Vector2(900.0, 44.0)
	title_bar.color    = Color(0.10, 0.08, 0.05)
	panel.add_child(title_bar)

	var title_lbl := Label.new()
	title_lbl.position = Vector2(0.0, 8.0)
	title_lbl.size     = Vector2(900.0, 28.0)
	title_lbl.text     = "CHANGELOG"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.58, 0.12))
	panel.add_child(title_lbl)

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8.0, 50.0)
	scroll.size     = Vector2(884.0, 558.0)
	panel.add_child(scroll)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled       = true
	rtl.fit_content          = true   # height grows to fit text
	rtl.custom_minimum_size  = Vector2(860.0, 0.0)   # fixes width inside ScrollContainer
	rtl.add_theme_font_size_override("normal_font_size", 12)
	rtl.add_theme_font_size_override("bold_font_size",   13)
	rtl.add_theme_color_override("default_color", Color(0.82, 0.82, 0.86))
	rtl.text = _changelog_text()
	scroll.add_child(rtl)

	# Close button
	var close_btn := _make_btn("✕  CLOSE", Vector2(375.0, 614.0), Vector2(150.0, 36.0), 13)
	close_btn.pressed.connect(func() -> void: _changelog_overlay.visible = false)
	panel.add_child(close_btn)

## Read version.txt shipped with the game. Falls back to "?" if missing.
func _read_version() -> String:
	const PATH := "res://version.txt"
	if not FileAccess.file_exists(PATH):
		return "?"
	var f := FileAccess.open(PATH, FileAccess.READ)
	var v := f.get_as_text().strip_edges()
	f.close()
	return v

## Read data/patchnotes.txt (BBCode, generated by release.sh from CHANGELOG.md).
## Falls back to a short error message so the overlay always opens cleanly.
func _changelog_text() -> String:
	const PATH := "res://data/patchnotes.txt"
	if not FileAccess.file_exists(PATH):
		return "[color=#888]Patch notes not found.\nRun tools/generate_patchnotes.py to generate data/patchnotes.txt.[/color]"
	var f := FileAccess.open(PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	return text
