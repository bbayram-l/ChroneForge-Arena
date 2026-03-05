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

	# Version label (bottom-right)
	var ver := Label.new()
	ver.position = Vector2(1150.0, 782.0)
	ver.size     = Vector2(120.0, 16.0)
	ver.text     = "v0.9.1-demo"
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
	rtl.bbcode_enabled = true
	rtl.fit_content    = true
	rtl.size           = Vector2(860.0, 0.0)   # height expands with content
	rtl.add_theme_font_size_override("normal_font_size", 12)
	rtl.add_theme_font_size_override("bold_font_size",   13)
	rtl.text = _changelog_text()
	scroll.add_child(rtl)

	# Close button
	var close_btn := _make_btn("✕  CLOSE", Vector2(375.0, 614.0), Vector2(150.0, 36.0), 13)
	close_btn.pressed.connect(func() -> void: _changelog_overlay.visible = false)
	panel.add_child(close_btn)

func _changelog_text() -> String:
	return (
"""[color=#e8941f][b]v0.9.1 — Balance Pass[/b][/color]  [color=#666677]2026-03-06[/color]
[color=#888899]Temporal stack nerfs — fights now last long enough for all five systems to matter.[/color]

[color=#ffdd88]Balance[/color]
• [b]Pre-Fire Snapshot[/b] — shots deal [b]0.8×[/b] damage (unguided opening volley).
  No longer benefits from Timeline Split; they are now distinct mechanics.
• [b]Timeline Split[/b] — multiplier reduced [b]2.0× → 1.5×[/b].
  Still a decisive opener; no longer an instant-kill on late-game enemies.
• [b]Entropy Field[/b] — damage floor raised [b]0.3× → 0.5×[/b] (max −50%, was −70%).
  Tick interval slowed [b]1.0s → 1.5s[/b]; only dominant in extended fights.
• [b]Temporal Pre-load[/b] — combat starts with [b]5 × temporal_count[/b] paradox.
  A 6-Temporal build begins at 30/100 so the meta tax bites from tick 1.
• [b]joint_lock[/b] — now consumed on absorption. Was absorbing unlimited overloads for free.

[color=#ffdd88]Synergies Now Active in Combat[/color]
• [b]Overcharge[/b] (POWER + WEAPON) — +8% weapon damage
• [b]Heat Sink[/b] (THERMAL + WEAPON) — −30% heat generated per shot
• [b]Fortress[/b] (STRUCTURAL + DEFENSE) — +15% starting HP
• [b]Echo Shot[/b] (TEMPORAL + WEAPON) — 5% chance to re-fire at full damage
• [b]Targeting[/b] (AI + WEAPON) — −5% accuracy penalty
• [b]Flux[/b] (POWER + TEMPORAL) — −10% paradox gain rate


[color=#e8941f][b]v0.9.0 — Month 9: Steam Demo Prep[/b][/color]  [color=#666677]2026-03-06[/color]
[color=#888899]Archetypes, combat replay, status keywords, UI polish, 7-card shop.[/color]

[color=#ffdd88]Five Archetypes[/color]
Choose your identity before the run. Each has a unique passive, starter module, strength, weakness, and counter.
• [b]Recoil Berserker[/b] — +25% damage; double recoil (accuracy degrades with every shot). Starter: Railgun.
• [b]Thermal Overdrive[/b] — +25% damage while quadrant heat ≥ 50. Starter: Plasma Saw.
• [b]Temporal Assassin[/b] — temporal weapons fire 15% faster. Starter: Pre-Fire Snapshot.
• [b]Fortress Stabilizer[/b] — shields +25%; gyro_stabilizer torque reduction doubled. Starter: Energy Shield.
• [b]Paradox Gambler[/b] — +30% damage when paradox > 80. Starter: Capacitor Bank.

[color=#ffdd88]Combat Replay[/color]
After every fight a [b]▶ REPLAY FIGHT[/b] button appears on the results panel.
• Plays back at 10 ticks/sec — toggle [b]2× speed[/b] any time.
• Live HP, shield, and paradox bars update each tick.
• Keyword badges show [b]BURN / CRACK / OVERCHARGE[/b] stacks as they accumulate.
• Rolling event feed: shots, dodges, overloads, EMP locks, reflects, vents.
• Pre-fire wins show [b]PRE-FIRE WIN[/b] with all opening-volley events.

[color=#ffdd88]Status Keywords[/color]
• [b]BURN[/b] — heat-generating weapons apply DoT stacks (0.5 HP/tick per stack).
  Decays 2 stacks/s per active THERMAL module. Overdrive Vent clears all Burn.
• [b]CRACK[/b] — high-recoil shots stress the shooter's frame (+2% acc penalty per stack).
  Decays via Blast Plating (1 stack every 2s).
• [b]OVERCHARGE[/b] — power surplus > 1.1× reduces your paradox gain by 10% per tick.

[color=#ffdd88]UI & Gameplay[/color]
• Resolution 1280×720 → [b]1280×800[/b].  Fullscreen toggle fixed on Windows 11.
• [b]7-card shop[/b] (was 5).  Purchased cards disappear immediately.
• Post-battle results panel with outcome, HP remaining, and notable events.
• Combat log moved to a right sidebar — no longer overlaps the enemy grid.
• HUD: heat-per-quadrant bars (TL/TR/BL/BR) and paradox-rate meter.
• Shop cards show category badge + synergy hint when a card would activate a synergy.
• Grid overlay draws coloured synergy borders on active cells.


[color=#e8941f][b]v0.8.0 — Month 8[/b][/color]
• Main menu, fullscreen toggle, version label.


[color=#e8941f][b]v0.7.0 — Month 7[/b][/color]
• Disabled-module darkened visual.  Hover tooltip with full stats.
• Post-fight combat log (last 7 events).


[color=#e8941f][b]v0.6.0 — Month 6[/b][/color]
• [b]60 modules[/b] total (up from 36).  repair_drone, targeting_jammer wired.
• Ghost ladder: 30% chance to replay a previous human opponent each round.


[color=#e8941f][b]v0.5.0 — Month 5[/b][/color]
• Module upgrades ★1 → ★2 → ★3.  Sell refund includes upgrade investment.


[color=#e8941f][b]v0.4.0 — Month 4[/b][/color]
• 3 player lives.  Run-over screen.  REROLL / SELL buttons.  Draw outcome.


[color=#e8941f][b]v0.3.0 — Month 3[/b][/color]
• All special module effects wired (emp_burst, reactive_armor, reflective_field,
  future_sight, pre_fire_snapshot, rewind_shield, overdrive_vent, timeline_split,
  entropy_field, capacitor_bank, gyro_stabilizer, shock_bracing, power_router).


[color=#e8941f][b]v0.2.0 — Month 2[/b][/color]
• Visual grid, click-to-place shop, enemy generator, HUD, torque visualiser.


[color=#e8941f][b]v0.1.0 — Month 1[/b][/color]
• Core engine: grid, power, heat, physics, paradox, combat, shop, economy."""
	)
