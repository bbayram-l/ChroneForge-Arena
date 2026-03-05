## MainMenu — entry-point scene for ChronoForge Arena.
## Programmatic UI consistent with the rest of the codebase.
extends Node

var _fullscreen:        bool    = false
var _changelog_overlay: Control = null

func _ready() -> void:
	_build_ui()

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
	var bar := ColorRect.new()
	bar.position = Vector2(0.0, 0.0)
	bar.size     = Vector2(1280.0, 4.0)
	bar.color    = Color(0.9, 0.5, 0.1)
	canvas.add_child(bar)

	# Title
	var title := Label.new()
	title.position = Vector2(0.0, 230.0)
	title.size     = Vector2(1280.0, 80.0)
	title.text     = "CHRONOFORGE ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.92, 0.58, 0.12))
	canvas.add_child(title)

	# Tagline
	var tag := Label.new()
	tag.position = Vector2(0.0, 316.0)
	tag.size     = Vector2(1280.0, 28.0)
	tag.text     = "Build unstable modular mechs.  Break physics.  Bend time."
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 15)
	tag.modulate = Color(0.55, 0.55, 0.62)
	canvas.add_child(tag)

	# Divider
	var div := ColorRect.new()
	div.position = Vector2(540.0, 358.0)
	div.size     = Vector2(200.0, 1.0)
	div.color    = Color(0.3, 0.3, 0.35)
	canvas.add_child(div)

	# PLAY button
	var play_btn := _make_btn("PLAY", Vector2(515.0, 376.0), Vector2(250.0, 56.0), 22)
	play_btn.pressed.connect(_on_play)
	canvas.add_child(play_btn)

	# Fullscreen toggle
	var fs_btn := _make_btn("FULLSCREEN: OFF", Vector2(515.0, 444.0), Vector2(250.0, 38.0), 13)
	fs_btn.name = "FullscreenBtn"
	fs_btn.pressed.connect(_on_fullscreen_pressed.bind(fs_btn))
	canvas.add_child(fs_btn)

	# QUIT button
	var quit_btn := _make_btn("QUIT", Vector2(515.0, 494.0), Vector2(250.0, 38.0), 13)
	quit_btn.pressed.connect(_on_quit)
	canvas.add_child(quit_btn)

	# WHAT'S NEW button
	var log_btn := _make_btn("WHAT'S NEW", Vector2(515.0, 544.0), Vector2(250.0, 38.0), 13)
	log_btn.pressed.connect(_on_changelog_pressed.bind(canvas))
	canvas.add_child(log_btn)

	# Version label (bottom-right) — read from version.txt at runtime
	var ver := Label.new()
	ver.position = Vector2(1120.0, 782.0)
	ver.size     = Vector2(150.0, 16.0)
	ver.text     = "v%s-demo" % _read_version()
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_font_size_override("font_size", 10)
	ver.modulate = Color(0.35, 0.35, 0.38)
	canvas.add_child(ver)

func _make_btn(text: String, pos: Vector2, sz: Vector2, font_size: int) -> Button:
	var btn := Button.new()
	btn.position = pos
	btn.size     = sz
	btn.text     = text
	btn.add_theme_font_size_override("font_size", font_size)
	return btn

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

