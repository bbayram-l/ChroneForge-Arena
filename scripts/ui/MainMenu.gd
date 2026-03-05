## MainMenu — entry-point scene for ChronoForge Arena.
## Programmatic UI consistent with the rest of the codebase.
extends Node

var _fullscreen: bool = false

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

	# Version label (bottom-right)
	var ver := Label.new()
	ver.position = Vector2(1170.0, 782.0)
	ver.size     = Vector2(100.0, 16.0)
	ver.text     = "v0.8-demo"
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
