## Main — root scene script and game-loop coordinator.
##
## Game loop:
##   SHOP_PHASE  → player clicks cards to select, clicks grid cells to place/sell
##   COMBAT      → deterministic simulation runs instantly, result shown
##   ROUND_END   → player clicks "NEXT ROUND" to continue
##   RUN_OVER    → player clicks "RESTART" to start a new run
##
## Visual nodes are created programmatically in _setup_ui().
extends Node

enum Phase { START_RUN, SHOP_PHASE, COMBAT, ROUND_END, RUN_OVER }

var phase: Phase = Phase.START_RUN

var player_grid: MechGrid
var enemy_grid:  MechGrid
var shop:        ShopSystem
var engine:      CombatEngine

# UI nodes
var _canvas:          CanvasLayer
var player_grid_view: MechGridView
var enemy_grid_view:  MechGridView
var shop_panel:       ShopPanel
var hud_panel:        HudPanel
var _status_label:    Label
var _action_btn:      Button
var _reroll_btn:      Button
var _sell_btn:        Button
var _upgrade_btn:     Button
var _run_over_panel:   Control
var _results_panel:    Panel
var _archetype_panel:  Panel
var _replay_panel:     Panel
var _tooltip_panel:    Panel
var _combat_log:      Label
var _selected_offer:  Module = null
var _sell_mode:       bool   = false
var _upgrade_mode:    bool   = false
var _protected_cells: Array[Vector2i] = []

# ── Screen-edge flash overlay ───────────────────────────────────────────────
var _flash_rect:  ColorRect = null
var _flash_tween: Tween     = null

# ── Drag state ──────────────────────────────────────────────────────────────
var _drag_mod:       Module = null
var _drag_ghost:     Panel  = null
var _drag_last_cell: Vector2i = Vector2i(-1, -1)

# ── Replay state ────────────────────────────────────────────────────────────
var _last_result:           Dictionary = {}
var _replay_timer:          Timer
var _replay_tick:           int        = 0
var _replay_speed_fast:     bool       = false
var _replay_states:         Dictionary = {}   # tick(int) → state dict
var _replay_events_by_tick: Dictionary = {}   # tick(int) → Array[Dictionary]

# ── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	player_grid = MechGrid.new("player")
	enemy_grid  = MechGrid.new("enemy")
	shop        = ShopSystem.new(ModuleRegistry.all_modules, randi())

	_setup_ui()
	_archetype_panel.visible = true

func _setup_ui() -> void:
	_canvas = CanvasLayer.new()
	add_child(_canvas)
	var canvas: CanvasLayer = _canvas

	# Status bar
	_status_label = Label.new()
	_status_label.position = Vector2(10.0, 10.0)
	_status_label.size     = Vector2(900.0, 24.0)
	_status_label.add_theme_font_size_override("font_size", 15)
	canvas.add_child(_status_label)

	# Action button — "READY" in shop phase, "NEXT ROUND" after combat
	_action_btn = Button.new()
	_action_btn.position = Vector2(1090.0, 6.0)
	_action_btn.size     = Vector2(172.0, 34.0)
	_action_btn.text     = "READY"
	_action_btn.pressed.connect(_on_action_pressed)
	canvas.add_child(_action_btn)
	_style_btn(_action_btn, Color("1a5c1a"), Color("2a8c2a"))   # green — go / confirm

	# Reroll button — visible only in shop phase
	_reroll_btn = Button.new()
	_reroll_btn.position = Vector2(1090.0, 46.0)
	_reroll_btn.size     = Vector2(172.0, 28.0)
	_reroll_btn.text     = "REROLL (2g)"
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	canvas.add_child(_reroll_btn)
	_style_btn(_reroll_btn, Color("2a2a3a"), Color("3a3a5a"))   # neutral blue-grey

	# Sell button — toggles sell mode in shop phase
	_sell_btn = Button.new()
	_sell_btn.position = Vector2(1090.0, 80.0)
	_sell_btn.size     = Vector2(172.0, 28.0)
	_sell_btn.text     = "SELL MODULE"
	_sell_btn.pressed.connect(_on_sell_pressed)
	canvas.add_child(_sell_btn)
	_style_btn(_sell_btn, Color("5a1010"), Color("8a2020"))      # red — destructive

	# Upgrade button — toggles upgrade mode in shop phase
	_upgrade_btn = Button.new()
	_upgrade_btn.position = Vector2(1090.0, 114.0)
	_upgrade_btn.size     = Vector2(172.0, 28.0)
	_upgrade_btn.text     = "UPGRADE (★)"
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	canvas.add_child(_upgrade_btn)
	_style_btn(_upgrade_btn, Color("4a3a08"), Color("7a6010"))   # gold — upgrade

	# Player grid — left side
	# 6×(64+4)−4 = 404 px wide. Two grids centred: (1280−404−80−404)/2 = 196 px margin
	# y=50 leaves room for status bar above; HUD fits below at y=484
	player_grid_view = MechGridView.new()
	player_grid_view.position = Vector2(196.0, 50.0)
	canvas.add_child(player_grid_view)
	player_grid_view.set_title("PLAYER")
	player_grid_view.cell_clicked.connect(_on_player_cell_clicked)
	player_grid_view.refresh(player_grid)

	# Enemy grid — right side
	enemy_grid_view = MechGridView.new()
	enemy_grid_view.position = Vector2(680.0, 50.0)
	canvas.add_child(enemy_grid_view)
	enemy_grid_view.set_title("ENEMY")
	enemy_grid_view.refresh(enemy_grid)

	# HUD — stat bars below the player grid
	hud_panel = HudPanel.new()
	hud_panel.position = Vector2(196.0, 464.0)
	canvas.add_child(hud_panel)

	# Shop panel — below HUD
	shop_panel = ShopPanel.new()
	shop_panel.position = Vector2(22.0, 640.0)
	canvas.add_child(shop_panel)
	shop_panel.module_selected.connect(_on_module_selected)
	shop_panel.drag_started.connect(_on_shop_drag_started)
	shop_panel.drag_dropped.connect(_on_shop_drag_dropped)
	GameState.gold_changed.connect(func(_g: int) -> void: shop_panel.refresh_affordability())

	# Run-over overlay (hidden until run ends)
	_run_over_panel = _build_run_over_panel()
	canvas.add_child(_run_over_panel)
	_run_over_panel.visible = false

	# Post-battle results overlay (hidden until combat ends)
	_results_panel = _build_results_panel()
	canvas.add_child(_results_panel)
	_results_panel.visible = false

	# Archetype selection overlay (shown at run start)
	_archetype_panel = _build_archetype_panel()
	canvas.add_child(_archetype_panel)
	_archetype_panel.visible = false

	# Replay overlay (hidden until player clicks REPLAY)
	_replay_panel = _build_replay_panel()
	canvas.add_child(_replay_panel)
	_replay_panel.visible = false

	# Replay timer — drives tick-by-tick playback
	_replay_timer = Timer.new()
	_replay_timer.one_shot = false
	_replay_timer.wait_time = CombatEngine.TICK_RATE
	_replay_timer.timeout.connect(_on_replay_tick)
	add_child(_replay_timer)

	# Module tooltip — right sidebar below upgrade button
	_tooltip_panel = _build_tooltip_panel()
	canvas.add_child(_tooltip_panel)
	_tooltip_panel.visible = false
	player_grid_view.cell_hovered.connect(_on_player_cell_hovered)
	player_grid_view.cell_unhovered.connect(_on_player_cell_unhovered)

	# Combat log — right sidebar panel
	var log_panel := _build_combat_log_panel()
	canvas.add_child(log_panel)

	# Screen-edge weapon fire flash overlay (full-viewport, always on top, ignores mouse)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color.TRANSPARENT
	_flash_rect.z_index = 10
	canvas.add_child(_flash_rect)

	_update_status()

func _build_tooltip_panel() -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(1090.0, 150.0)
	panel.size     = Vector2(172.0, 220.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.96)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.35, 0.50)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.name          = "TooltipLabel"
	lbl.position      = Vector2(6.0, 6.0)
	lbl.size          = Vector2(160.0, 208.0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate      = Color(0.9, 0.9, 0.9)
	panel.add_child(lbl)
	return panel

func _build_results_panel() -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(240.0, 185.0)
	panel.size     = Vector2(800.0, 410.0)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.07, 0.07, 0.10, 0.97)
	style.border_color = Color(0.35, 0.35, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	# Outcome header
	var header := Label.new()
	header.name                    = "Header"
	header.position                = Vector2(0.0, 12.0)
	header.size                    = Vector2(800.0, 40.0)
	header.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 28)
	panel.add_child(header)

	# Round + duration line
	var subheader := Label.new()
	subheader.name               = "Subheader"
	subheader.position           = Vector2(0.0, 52.0)
	subheader.size               = Vector2(800.0, 18.0)
	subheader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subheader.add_theme_font_size_override("font_size", 11)
	subheader.modulate           = Color(0.6, 0.6, 0.65)
	panel.add_child(subheader)

	# Player stats (left column)
	var p_lbl := Label.new()
	p_lbl.name     = "PlayerStats"
	p_lbl.position = Vector2(28.0, 78.0)
	p_lbl.size     = Vector2(350.0, 110.0)
	p_lbl.add_theme_font_size_override("font_size", 11)
	panel.add_child(p_lbl)

	# Centre divider
	var div := ColorRect.new()
	div.position = Vector2(400.0, 78.0)
	div.size     = Vector2(1.0, 110.0)
	div.color    = Color(0.28, 0.28, 0.40)
	panel.add_child(div)

	# Enemy stats (right column)
	var e_lbl := Label.new()
	e_lbl.name     = "EnemyStats"
	e_lbl.position = Vector2(420.0, 78.0)
	e_lbl.size     = Vector2(350.0, 110.0)
	e_lbl.add_theme_font_size_override("font_size", 11)
	panel.add_child(e_lbl)

	# Separator
	var sep_lbl := Label.new()
	sep_lbl.name               = "EventsSep"
	sep_lbl.position           = Vector2(0.0, 196.0)
	sep_lbl.size               = Vector2(800.0, 16.0)
	sep_lbl.text               = "── NOTABLE EVENTS ──"
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_lbl.add_theme_font_size_override("font_size", 9)
	sep_lbl.modulate           = Color(0.42, 0.42, 0.52)
	panel.add_child(sep_lbl)

	# Events list
	var ev_lbl := Label.new()
	ev_lbl.name          = "Events"
	ev_lbl.position      = Vector2(28.0, 216.0)
	ev_lbl.size          = Vector2(744.0, 158.0)
	ev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev_lbl.add_theme_font_size_override("font_size", 10)
	ev_lbl.modulate      = Color(0.72, 0.72, 0.72)
	panel.add_child(ev_lbl)

	# REPLAY button — bottom center
	var replay_btn := Button.new()
	replay_btn.name     = "ReplayBtn"
	replay_btn.position = Vector2(290.0, 370.0)
	replay_btn.size     = Vector2(220.0, 28.0)
	replay_btn.text     = "▶  REPLAY FIGHT"
	replay_btn.add_theme_font_size_override("font_size", 12)
	replay_btn.pressed.connect(_start_replay)
	panel.add_child(replay_btn)

	return panel

func _build_combat_log_panel() -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(1090.0, 375.0)
	panel.size     = Vector2(172.0, 240.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.96)
	style.set_border_width_all(1)
	style.border_color = Color(0.30, 0.30, 0.45)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var header := Label.new()
	header.position = Vector2(6.0, 4.0)
	header.size     = Vector2(160.0, 16.0)
	header.text     = "COMBAT LOG"
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	panel.add_child(header)

	_combat_log = Label.new()
	_combat_log.position      = Vector2(6.0, 22.0)
	_combat_log.size          = Vector2(160.0, 214.0)
	_combat_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_log.add_theme_font_size_override("font_size", 9)
	_combat_log.modulate      = Color(0.75, 0.75, 0.75)
	_combat_log.text          = "— No fights yet —"
	panel.add_child(_combat_log)
	return panel

# ── Replay panel ─────────────────────────────────────────────────────────────
# Layout: 960×330 centered. Two HP+shield bars (left=player, right=enemy),
# a centre tick/time label, live keyword badges, and a scrolling event feed.

func _build_replay_panel() -> Panel:
	const PW: float = 960.0
	const PH: float = 330.0
	var panel := Panel.new()
	panel.position = Vector2((1280.0 - PW) * 0.5, 210.0)
	panel.size     = Vector2(PW, PH)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.05, 0.05, 0.09, 0.97)
	style.border_color = Color(0.30, 0.45, 0.70)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	# Title / tick counter (top centre)
	var title := Label.new()
	title.name               = "ReplayTitle"
	title.position           = Vector2(0.0, 8.0)
	title.size               = Vector2(PW, 22.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	panel.add_child(title)

	# ── Player side (left) ──────────────────────────────────────────────────
	const BAR_W: float = 400.0
	const BAR_H: float = 18.0
	const SHD_H: float = 8.0

	var p_name := Label.new()
	p_name.position = Vector2(20.0, 36.0)
	p_name.size     = Vector2(BAR_W, 18.0)
	p_name.text     = "PLAYER"
	p_name.add_theme_font_size_override("font_size", 11)
	p_name.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	panel.add_child(p_name)

	# HP track + fill
	var p_hp_track := ColorRect.new()
	p_hp_track.position = Vector2(20.0, 56.0)
	p_hp_track.size     = Vector2(BAR_W, BAR_H)
	p_hp_track.color    = Color(0.12, 0.12, 0.12)
	panel.add_child(p_hp_track)
	var p_hp_fill := ColorRect.new()
	p_hp_fill.name     = "PlayerHPFill"
	p_hp_fill.position = Vector2(20.0, 56.0)
	p_hp_fill.size     = Vector2(BAR_W, BAR_H)
	p_hp_fill.color    = Color(0.2, 0.75, 0.2)
	panel.add_child(p_hp_fill)
	var p_hp_lbl := Label.new()
	p_hp_lbl.name     = "PlayerHPVal"
	p_hp_lbl.position = Vector2(20.0, 56.0)
	p_hp_lbl.size     = Vector2(BAR_W, BAR_H)
	p_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_hp_lbl.add_theme_font_size_override("font_size", 10)
	panel.add_child(p_hp_lbl)

	# Shield track + fill
	var p_sh_track := ColorRect.new()
	p_sh_track.position = Vector2(20.0, 76.0)
	p_sh_track.size     = Vector2(BAR_W, SHD_H)
	p_sh_track.color    = Color(0.08, 0.08, 0.18)
	panel.add_child(p_sh_track)
	var p_sh_fill := ColorRect.new()
	p_sh_fill.name     = "PlayerShieldFill"
	p_sh_fill.position = Vector2(20.0, 76.0)
	p_sh_fill.size     = Vector2(BAR_W, SHD_H)
	p_sh_fill.color    = Color(0.3, 0.5, 1.0)
	panel.add_child(p_sh_fill)

	# Keywords
	var p_kw := Label.new()
	p_kw.name     = "PlayerKeywords"
	p_kw.position = Vector2(20.0, 88.0)
	p_kw.size     = Vector2(BAR_W, 18.0)
	p_kw.add_theme_font_size_override("font_size", 10)
	panel.add_child(p_kw)

	# ── Enemy side (right) ──────────────────────────────────────────────────
	var e_x: float = PW - BAR_W - 20.0

	var e_name := Label.new()
	e_name.position = Vector2(e_x, 36.0)
	e_name.size     = Vector2(BAR_W, 18.0)
	e_name.text     = "ENEMY"
	e_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	e_name.add_theme_font_size_override("font_size", 11)
	e_name.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	panel.add_child(e_name)

	var e_hp_track := ColorRect.new()
	e_hp_track.position = Vector2(e_x, 56.0)
	e_hp_track.size     = Vector2(BAR_W, BAR_H)
	e_hp_track.color    = Color(0.12, 0.12, 0.12)
	panel.add_child(e_hp_track)
	var e_hp_fill := ColorRect.new()
	e_hp_fill.name     = "EnemyHPFill"
	e_hp_fill.position = Vector2(e_x, 56.0)
	e_hp_fill.size     = Vector2(BAR_W, BAR_H)
	e_hp_fill.color    = Color(0.8, 0.2, 0.2)
	panel.add_child(e_hp_fill)
	var e_hp_lbl := Label.new()
	e_hp_lbl.name     = "EnemyHPVal"
	e_hp_lbl.position = Vector2(e_x, 56.0)
	e_hp_lbl.size     = Vector2(BAR_W, BAR_H)
	e_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e_hp_lbl.add_theme_font_size_override("font_size", 10)
	panel.add_child(e_hp_lbl)

	var e_sh_track := ColorRect.new()
	e_sh_track.position = Vector2(e_x, 76.0)
	e_sh_track.size     = Vector2(BAR_W, SHD_H)
	e_sh_track.color    = Color(0.08, 0.08, 0.18)
	panel.add_child(e_sh_track)
	var e_sh_fill := ColorRect.new()
	e_sh_fill.name     = "EnemyShieldFill"
	e_sh_fill.position = Vector2(e_x, 76.0)
	e_sh_fill.size     = Vector2(BAR_W, SHD_H)
	e_sh_fill.color    = Color(0.3, 0.5, 1.0)
	panel.add_child(e_sh_fill)

	var e_kw := Label.new()
	e_kw.name     = "EnemyKeywords"
	e_kw.position = Vector2(e_x, 88.0)
	e_kw.size     = Vector2(BAR_W, 18.0)
	e_kw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	e_kw.add_theme_font_size_override("font_size", 10)
	panel.add_child(e_kw)

	# ── Divider + centre stats ───────────────────────────────────────────────
	var cdiv := ColorRect.new()
	cdiv.position = Vector2(PW * 0.5 - 1.0, 36.0)
	cdiv.size     = Vector2(2.0, 70.0)
	cdiv.color    = Color(0.25, 0.25, 0.40)
	panel.add_child(cdiv)

	# ── Paradox meters ────────────────────────────────────────────────────────
	var pdx_sep := Label.new()
	pdx_sep.position             = Vector2(0.0, 110.0)
	pdx_sep.size                 = Vector2(PW, 14.0)
	pdx_sep.text                 = "── PARADOX ──"
	pdx_sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pdx_sep.add_theme_font_size_override("font_size", 8)
	pdx_sep.modulate             = Color(0.5, 0.4, 0.7)
	panel.add_child(pdx_sep)

	var p_pdx_track := ColorRect.new()
	p_pdx_track.position = Vector2(20.0, 126.0)
	p_pdx_track.size     = Vector2(BAR_W, 6.0)
	p_pdx_track.color    = Color(0.10, 0.08, 0.14)
	panel.add_child(p_pdx_track)
	var p_pdx_fill := ColorRect.new()
	p_pdx_fill.name     = "PlayerPDXFill"
	p_pdx_fill.position = Vector2(20.0, 126.0)
	p_pdx_fill.size     = Vector2(BAR_W, 6.0)
	p_pdx_fill.color    = Color(0.65, 0.3, 1.0)
	panel.add_child(p_pdx_fill)

	var e_pdx_track := ColorRect.new()
	e_pdx_track.position = Vector2(e_x, 126.0)
	e_pdx_track.size     = Vector2(BAR_W, 6.0)
	e_pdx_track.color    = Color(0.10, 0.08, 0.14)
	panel.add_child(e_pdx_track)
	var e_pdx_fill := ColorRect.new()
	e_pdx_fill.name     = "EnemyPDXFill"
	e_pdx_fill.position = Vector2(e_x, 126.0)
	e_pdx_fill.size     = Vector2(BAR_W, 6.0)
	e_pdx_fill.color    = Color(0.65, 0.3, 1.0)
	panel.add_child(e_pdx_fill)

	# ── Event feed ────────────────────────────────────────────────────────────
	var ev_sep := Label.new()
	ev_sep.position             = Vector2(0.0, 140.0)
	ev_sep.size                 = Vector2(PW, 14.0)
	ev_sep.text                 = "── EVENTS ──"
	ev_sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_sep.add_theme_font_size_override("font_size", 8)
	ev_sep.modulate             = Color(0.42, 0.42, 0.52)
	panel.add_child(ev_sep)

	var ev_lbl := Label.new()
	ev_lbl.name          = "ReplayEvents"
	ev_lbl.position      = Vector2(20.0, 156.0)
	ev_lbl.size          = Vector2(PW - 40.0, 110.0)
	ev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev_lbl.add_theme_font_size_override("font_size", 10)
	ev_lbl.modulate      = Color(0.80, 0.80, 0.80)
	panel.add_child(ev_lbl)

	# ── Controls ──────────────────────────────────────────────────────────────
	var speed_btn := Button.new()
	speed_btn.name     = "SpeedBtn"
	speed_btn.position = Vector2(PW * 0.5 - 120.0, PH - 36.0)
	speed_btn.size     = Vector2(110.0, 28.0)
	speed_btn.text     = "▶▶  2×"
	speed_btn.add_theme_font_size_override("font_size", 11)
	speed_btn.pressed.connect(_on_replay_speed_toggled)
	panel.add_child(speed_btn)

	var stop_btn := Button.new()
	stop_btn.position = Vector2(PW * 0.5 + 10.0, PH - 36.0)
	stop_btn.size     = Vector2(110.0, 28.0)
	stop_btn.text     = "■  CLOSE"
	stop_btn.add_theme_font_size_override("font_size", 11)
	stop_btn.pressed.connect(_stop_replay)
	panel.add_child(stop_btn)

	return panel

func _start_replay() -> void:
	if _last_result.is_empty():
		return

	# Index event_log by tick
	_replay_states.clear()
	_replay_events_by_tick.clear()
	for entry: Dictionary in _last_result.get("event_log", []):
		var t: int = entry.get("tick", 0)
		if entry.get("type", "") == "state":
			_replay_states[t] = entry
		else:
			if not _replay_events_by_tick.has(t):
				_replay_events_by_tick[t] = []
			_replay_events_by_tick[t].append(entry)

	_replay_tick        = 0
	_replay_speed_fast  = false
	_replay_timer.wait_time = CombatEngine.TICK_RATE

	# Update title and reset speed button label
	var title: Label = _replay_panel.get_node("ReplayTitle")
	title.text = "REPLAY — Round %d  ●  Fight length: %.1fs" % [
		GameState.current_round - 1,
		_last_result.get("duration_seconds", 0.0),
	]
	var speed_btn: Button = _replay_panel.get_node("SpeedBtn")
	speed_btn.text = "▶▶  2×"

	_results_panel.visible = false
	_replay_panel.visible  = true
	_replay_timer.start()

func _on_replay_tick() -> void:
	var total_ticks: int = _last_result.get("ticks", 0)

	# 0-tick fight: enemy killed by pre_fire_snapshot before the main loop.
	# Show tick-0 events (pre-fire shots) then stop immediately.
	if total_ticks == 0:
		var pre_events: Array = _replay_events_by_tick.get(0, [])
		_replay_update_events(pre_events, 0)
		_replay_timer.stop()
		var title: Label = _replay_panel.get_node("ReplayTitle")
		title.text = "REPLAY — Round %d  ●  PRE-FIRE WIN  ✓ DONE" % (GameState.current_round - 1)
		return

	# Grab state snapshot for this tick
	var state: Dictionary = _replay_states.get(_replay_tick, {})
	if not state.is_empty():
		_replay_update_bars(state)
		_replay_update_keywords(state)

	# Show events at this tick
	var tick_events: Array = _replay_events_by_tick.get(_replay_tick, [])
	_replay_update_events(tick_events, _replay_tick)

	_replay_tick += 1
	if _replay_tick > total_ticks:
		_replay_timer.stop()
		var title: Label = _replay_panel.get_node("ReplayTitle")
		title.text += "  ✓ DONE"

func _replay_update_bars(state: Dictionary) -> void:
	const BAR_W: float = 400.0
	var p_hp_init: float  = maxf(_last_result.get("player_hp_initial", 100.0), 1.0)
	var e_hp_init: float  = maxf(_last_result.get("enemy_hp_initial",  100.0), 1.0)
	var p_hp: float       = state.get("player_hp",     0.0)
	var p_sh: float       = state.get("player_shield", 0.0)
	var e_hp: float       = state.get("enemy_hp",      0.0)
	var e_sh: float       = state.get("enemy_shield",  0.0)
	var p_pdx: float      = state.get("player_paradox", 0.0)
	var e_pdx: float      = state.get("enemy_paradox",  0.0)
	var tick: int         = state.get("tick", 0)

	# Update HP fills
	var p_hp_fill: ColorRect = _replay_panel.get_node("PlayerHPFill")
	p_hp_fill.size.x = BAR_W * clampf(p_hp / p_hp_init, 0.0, 1.0)
	var p_hp_lbl: Label = _replay_panel.get_node("PlayerHPVal")
	p_hp_lbl.text = "%.0f / %.0f" % [p_hp, p_hp_init]

	var e_hp_fill: ColorRect = _replay_panel.get_node("EnemyHPFill")
	e_hp_fill.size.x = BAR_W * clampf(e_hp / e_hp_init, 0.0, 1.0)
	var e_hp_lbl: Label = _replay_panel.get_node("EnemyHPVal")
	e_hp_lbl.text = "%.0f / %.0f" % [e_hp, e_hp_init]

	# Shield fills (proportional to initial HP for a consistent scale)
	var p_sh_fill: ColorRect = _replay_panel.get_node("PlayerShieldFill")
	p_sh_fill.size.x = BAR_W * clampf(p_sh / p_hp_init, 0.0, 1.0)
	var e_sh_fill: ColorRect = _replay_panel.get_node("EnemyShieldFill")
	e_sh_fill.size.x = BAR_W * clampf(e_sh / e_hp_init, 0.0, 1.0)

	# Paradox bars (fill when approaching threshold 100)
	const PDX_MAX: float = 150.0
	var p_pdx_fill: ColorRect = _replay_panel.get_node("PlayerPDXFill")
	p_pdx_fill.size.x = BAR_W * clampf(p_pdx / PDX_MAX, 0.0, 1.0)
	p_pdx_fill.color  = Color(1.0, 0.4, 0.4) if p_pdx > 100.0 else Color(0.65, 0.3, 1.0)
	var e_pdx_fill: ColorRect = _replay_panel.get_node("EnemyPDXFill")
	e_pdx_fill.size.x = BAR_W * clampf(e_pdx / PDX_MAX, 0.0, 1.0)
	e_pdx_fill.color  = Color(1.0, 0.4, 0.4) if e_pdx > 100.0 else Color(0.65, 0.3, 1.0)

	# Tick / time in title
	var title: Label = _replay_panel.get_node("ReplayTitle")
	title.text = "REPLAY — Round %d  ●  Tick %d / %d  (%.1fs)" % [
		GameState.current_round - 1,
		tick,
		_last_result.get("ticks", 0),
		tick * CombatEngine.TICK_RATE,
	]

func _replay_update_keywords(state: Dictionary) -> void:
	var p_burn: int    = state.get("player_burn", 0)
	var p_crack: int   = state.get("player_crack", 0)
	var p_oc: bool     = state.get("player_overcharge", false)
	var e_burn: int    = state.get("enemy_burn", 0)
	var e_crack: int   = state.get("enemy_crack", 0)
	var e_oc: bool     = state.get("enemy_overcharge", false)

	var p_kw: Label = _replay_panel.get_node("PlayerKeywords")
	var parts: PackedStringArray = []
	if p_burn  > 0: parts.append("[BURN x%d]" % p_burn)
	if p_crack > 0: parts.append("[CRACK x%d]" % p_crack)
	if p_oc:        parts.append("[OVERCHARGE]")
	p_kw.text = "  ".join(parts)

	var e_kw: Label = _replay_panel.get_node("EnemyKeywords")
	var eparts: PackedStringArray = []
	if e_burn  > 0: eparts.append("[BURN x%d]" % e_burn)
	if e_crack > 0: eparts.append("[CRACK x%d]" % e_crack)
	if e_oc:        eparts.append("[OVERCHARGE]")
	e_kw.text = "  ".join(eparts)

func _replay_update_events(events: Array, tick: int) -> void:
	if events.is_empty():
		return
	var ev_lbl: Label = _replay_panel.get_node("ReplayEvents")
	const MAX_LINES: int = 7
	var lines: PackedStringArray = ev_lbl.text.split("\n")
	for entry: Dictionary in events:
		var actor: String = entry.get("actor", "?")
		var t: String     = entry.get("type", "")
		var line: String
		match t:
			"shot":
				line = "[t%d] %s fired %s → %.0f dmg" % [tick, actor, entry.get("module","?"), entry.get("damage",0.0)]
				# Screen-edge flash: colour = weapon category colour
				var mod_ref: Module = ModuleRegistry.get_module(entry.get("module", ""))
				if mod_ref != null:
					var flash_col: Color = MechGridView.CATEGORY_COLORS.get(mod_ref.category, Color("c43020"))
					_trigger_flash(flash_col)
			"emp_lock":
				line = "[t%d] %s EMP locked: %s" % [tick, actor, entry.get("module","?")]
				_trigger_flash(Color("2050e0"))   # blue — EMP
			"dodge":          line = "[t%d] %s DODGED a shot" % [tick, actor]
			"reflect":        line = "[t%d] %s REFLECTED %.0f dmg" % [tick, actor, entry.get("reflected",0.0)]
			"rewind_shield":
				line = "[t%d] %s REWIND → shield restored" % [tick, actor]
				_trigger_flash(Color("20d0d0"))   # cyan — rewind
				# Brief cyan pulse on the appropriate HP bar to signal shield restoration
				var hp_node_name := "PlayerHPFill" if actor == "player" else "EnemyHPFill"
				var hp_fill: ColorRect = _replay_panel.get_node(hp_node_name)
				var orig_col := hp_fill.color
				var rw_tw := create_tween()
				rw_tw.tween_property(hp_fill, "color", Color("20d0d0"), 0.08)
				rw_tw.tween_property(hp_fill, "color", orig_col, 0.20)
			"paradox_overload":
				line = "[t%d] %s OVERLOAD → %s disabled" % [tick, actor, entry.get("module","?")]
				_trigger_flash(Color("9020c0"))   # purple — paradox overload
				_shake_grid(player_grid_view if actor == "player" else enemy_grid_view)
			"capacitor_explosion":
				line = "[t%d] %s CAPACITOR EXPLODED (30 dmg)" % [tick, actor]
				_trigger_flash(Color("e04010"))   # orange-red — explosion
				_shake_grid(player_grid_view if actor == "player" else enemy_grid_view)
			"overdrive_vent":
				line = "[t%d] %s VENTED all heat" % [tick, actor]
				_trigger_flash(Color("e06010"))   # orange — heat vent
			"reactive_armor": line = "[t%d] %s REACTIVE absorbed burst" % [tick, actor]
			_:                line = ""
		if line != "":
			lines.append(line)
	# Keep last MAX_LINES lines
	if lines.size() > MAX_LINES:
		lines = lines.slice(lines.size() - MAX_LINES)
	ev_lbl.text = "\n".join(lines)

func _on_replay_speed_toggled() -> void:
	_replay_speed_fast = not _replay_speed_fast
	_replay_timer.wait_time = CombatEngine.TICK_RATE * (0.5 if _replay_speed_fast else 1.0)
	var speed_btn: Button = _replay_panel.get_node("SpeedBtn")
	speed_btn.text = "▶  1×" if _replay_speed_fast else "▶▶  2×"

func _stop_replay() -> void:
	_replay_timer.stop()
	_replay_panel.visible  = false
	_results_panel.visible = true

func _build_run_over_panel() -> Control:
	var panel := Panel.new()
	panel.position = Vector2(290.0, 200.0)
	panel.size     = Vector2(700.0, 340.0)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.08, 0.10, 0.95)
	style.border_color = Color(0.8, 0.2, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var title := Label.new()
	title.position = Vector2(0.0, 30.0)
	title.size     = Vector2(700.0, 60.0)
	title.text     = "RUN OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	panel.add_child(title)

	var stats := Label.new()
	stats.name     = "StatsLabel"
	stats.position = Vector2(0.0, 120.0)
	stats.size     = Vector2(700.0, 120.0)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.modulate = Color(0.85, 0.85, 0.85)
	panel.add_child(stats)

	var restart := Button.new()
	restart.position = Vector2(250.0, 270.0)
	restart.size     = Vector2(200.0, 44.0)
	restart.text     = "RESTART"
	restart.add_theme_font_size_override("font_size", 16)
	restart.pressed.connect(_on_restart_pressed)
	panel.add_child(restart)

	return panel

func _build_archetype_panel() -> Panel:
	# Panel spans nearly full viewport width to fit 5 cards
	# 5 cards × 226px + 4 gaps × 10px = 1170px; panel = 1250px; left margin = 40px
	const PANEL_W: float = 1250.0
	const CARD_W:  float = 226.0
	const CARD_GAP: float = 10.0

	var panel := Panel.new()
	panel.position = Vector2(15.0, 155.0)
	panel.size     = Vector2(PANEL_W, 460.0)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.06, 0.06, 0.10, 0.98)
	style.border_color = Color(0.35, 0.35, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var title := Label.new()
	title.position             = Vector2(0.0, 12.0)
	title.size                 = Vector2(PANEL_W, 34.0)
	title.text                 = "CHOOSE YOUR ARCHETYPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	panel.add_child(title)

	var sub := Label.new()
	sub.position             = Vector2(0.0, 46.0)
	sub.size                 = Vector2(PANEL_W, 18.0)
	sub.text                 = "Each archetype has a strength, a weakness, and a natural counter. Choose wisely."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 10)
	sub.modulate             = Color(0.55, 0.55, 0.65)
	panel.add_child(sub)

	var archetypes: Array = [
		{
			"id":       "RECOIL_BERSERKER",
			"name":     "⚙ RECOIL\nBERSERKER",
			"color":    Color("5a1a00"),
			"border":   Color("ff6622"),
			"passive":  "+25% weapon damage.\nRecoil force doubled — accuracy degrades fast.",
			"strength": "Explosive burst DPS",
			"weakness": "Accuracy penalty compounds under torque",
			"counter":  "Light evasive builds",
			"starters": "Micro Reactor\n+ Railgun (RARE)",
		},
		{
			"id":       "THERMAL_OVERDRIVE",
			"name":     "🔥 THERMAL\nOVERDRIVE",
			"color":    Color("5a2a00"),
			"border":   Color("ff9900"),
			"passive":  "+25% weapon damage while quadrant heat ≥ 50.\nHeat is a resource, not a penalty.",
			"strength": "Mid-fight power spike",
			"weakness": "Sudden meltdown collapse",
			"counter":  "EMP / burst builds that deny ramp-up",
			"starters": "Micro Reactor\n+ Plasma Saw (RARE)",
		},
		{
			"id":       "TEMPORAL_ASSASSIN",
			"name":     "⏳ TEMPORAL\nASSASSIN",
			"color":    Color("1a0a40"),
			"border":   Color("8844ff"),
			"passive":  "Temporal weapons fire\n15% faster (−15% cooldown).",
			"strength": "First-strike alpha damage",
			"weakness": "Low durability, high paradox risk",
			"counter":  "Reflective builds / shield reversion",
			"starters": "Micro Reactor\n+ Pre-Fire Snapshot (RARE)",
		},
		{
			"id":       "FORTRESS_STABILIZER",
			"name":     "🛡 FORTRESS\nSTABILIZER",
			"color":    Color("0a2a1a"),
			"border":   Color("44cc88"),
			"passive":  "Shields start +25% higher.\nGyro Stabilizer reduces torque by 60% (vs 30%).",
			"strength": "Maximum survivability",
			"weakness": "Low DPS, bleeds out to sustained fire",
			"counter":  "Entropy field / anti-shield modules",
			"starters": "Micro Reactor\n+ Energy Shield (UNCOMMON)",
		},
		{
			"id":       "PARADOX_GAMBLER",
			"name":     "🌀 PARADOX\nGAMBLER",
			"color":    Color("1a0a2a"),
			"border":   Color("cc44ff"),
			"passive":  "+30% weapon damage when paradox > 80.\nCapacitor Bank blows you up if it overloads.",
			"strength": "Explosive unpredictable scaling",
			"weakness": "Self-destruction chance mid-fight",
			"counter":  "Sustained safe builds that outlast chaos",
			"starters": "Micro Reactor\n+ Capacitor Bank (UNCOMMON)",
		},
	]

	var total_w: float = CARD_W * 5.0 + CARD_GAP * 4.0
	var start_x: float = (PANEL_W - total_w) * 0.5
	for i in range(archetypes.size()):
		var arch: Dictionary = archetypes[i]
		var card := _build_archetype_card(arch, CARD_W)
		card.position = Vector2(start_x + float(i) * (CARD_W + CARD_GAP), 72.0)
		panel.add_child(card)

	return panel

func _build_archetype_card(arch: Dictionary, card_w: float) -> Panel:
	var card := Panel.new()
	card.size = Vector2(card_w, 370.0)

	var style := StyleBoxFlat.new()
	style.bg_color = arch["color"]
	style.border_color = arch["border"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var inner_w: float = card_w - 14.0

	var name_lbl := Label.new()
	name_lbl.position             = Vector2(0.0, 10.0)
	name_lbl.size                 = Vector2(card_w, 44.0)
	name_lbl.text                 = arch["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	card.add_child(name_lbl)

	var div := ColorRect.new()
	div.position = Vector2(10.0, 56.0)
	div.size     = Vector2(card_w - 20.0, 1.0)
	div.color    = arch["border"]
	card.add_child(div)

	# Passive
	var passive_hdr := Label.new()
	passive_hdr.position = Vector2(8.0, 62.0)
	passive_hdr.size     = Vector2(inner_w, 14.0)
	passive_hdr.text     = "PASSIVE"
	passive_hdr.add_theme_font_size_override("font_size", 8)
	passive_hdr.modulate = Color(0.6, 0.6, 0.7)
	card.add_child(passive_hdr)

	var passive_lbl := Label.new()
	passive_lbl.position      = Vector2(8.0, 76.0)
	passive_lbl.size          = Vector2(inner_w, 62.0)
	passive_lbl.text          = arch["passive"]
	passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_lbl.add_theme_font_size_override("font_size", 10)
	card.add_child(passive_lbl)

	# Strength / Weakness / Counter
	var swc_y: float = 146.0
	for pair in [["+ STRENGTH", "strength", Color("88ff88")],
				 ["- WEAKNESS", "weakness", Color("ff8888")],
				 ["⚡ COUNTER",  "counter",  Color("ffcc44")]]:
		var hdr := Label.new()
		hdr.position = Vector2(8.0, swc_y)
		hdr.size     = Vector2(inner_w, 13.0)
		hdr.text     = pair[0]
		hdr.add_theme_font_size_override("font_size", 8)
		hdr.add_theme_color_override("font_color", pair[2])
		card.add_child(hdr)
		var val := Label.new()
		val.position      = Vector2(8.0, swc_y + 13.0)
		val.size          = Vector2(inner_w, 24.0)
		val.text          = arch[pair[1]]
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.add_theme_font_size_override("font_size", 9)
		card.add_child(val)
		swc_y += 38.0

	# Starters
	var starter_hdr := Label.new()
	starter_hdr.position = Vector2(8.0, swc_y)
	starter_hdr.size     = Vector2(inner_w, 13.0)
	starter_hdr.text     = "STARTERS"
	starter_hdr.add_theme_font_size_override("font_size", 8)
	starter_hdr.modulate = Color(0.6, 0.6, 0.7)
	card.add_child(starter_hdr)

	var starter_lbl := Label.new()
	starter_lbl.position      = Vector2(8.0, swc_y + 13.0)
	starter_lbl.size          = Vector2(inner_w, 36.0)
	starter_lbl.text          = arch["starters"]
	starter_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	starter_lbl.add_theme_font_size_override("font_size", 9)
	card.add_child(starter_lbl)

	var btn := Button.new()
	btn.position = Vector2(13.0, 326.0)
	btn.size     = Vector2(card_w - 26.0, 32.0)
	btn.text     = "SELECT"
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_archetype_selected.bind(arch["id"]))
	card.add_child(btn)

	return card

func _on_archetype_selected(archetype: String) -> void:
	GameState.archetype = archetype
	_archetype_panel.visible = false
	hud_panel.set_archetype(archetype)
	print("[Setup] Archetype chosen: %s" % archetype)

	# Reset grids + shop for a fresh run
	_protected_cells.clear()
	player_grid = MechGrid.new("player")
	enemy_grid  = MechGrid.new("enemy")
	player_grid_view.refresh(player_grid)
	enemy_grid_view.refresh(enemy_grid)
	shop = ShopSystem.new(ModuleRegistry.all_modules, randi())

	GameState.start_run()
	GameLogger.log_run_start(archetype)
	_give_starter_modules()
	_enter_shop_phase()

# ── Starter modules ────────────────────────────────────────────────────────

func _give_starter_modules() -> void:
	# All archetypes share the cheapest COMMON POWER module as the protected core.
	var power_starters: Array[Module] = []
	for mod: Module in ModuleRegistry.all_modules:
		if mod.category == Module.Category.POWER and mod.rarity == Module.Rarity.COMMON:
			power_starters.append(mod)
	if power_starters.is_empty():
		return
	power_starters.sort_custom(func(a: Module, b: Module) -> bool: return a.cost < b.cost)
	var core: Module = power_starters[0]
	player_grid.place_module(Vector2i(2, 2), core)
	_protected_cells.append(Vector2i(2, 2))
	print("[Setup] Starter core: %s placed (free)" % core.display_name)

	# Archetype-specific second starter at (3,2)
	var bonus_id := ""
	match GameState.archetype:
		"RECOIL_BERSERKER":   bonus_id = "railgun"            # 2×1, high recoil/dmg
		"THERMAL_OVERDRIVE":  bonus_id = "plasma_saw"         # extreme heat gen
		"TEMPORAL_ASSASSIN":  bonus_id = "pre_fire_snapshot"  # first-strike identity
		"FORTRESS_STABILIZER":bonus_id = "energy_shield"      # shield stacking
		"PARADOX_GAMBLER":    bonus_id = "capacitor_bank"     # explodes on overload
	if bonus_id != "":
		var bonus_mod := _find_module_by_id(bonus_id)
		if bonus_mod != null:
			player_grid.place_module(Vector2i(3, 2), bonus_mod)
			print("[Setup] %s starter: %s placed" % [GameState.archetype, bonus_mod.display_name])

	player_grid_view.refresh(player_grid)
	hud_panel.refresh(player_grid)

func _find_module_by_id(mod_id: String) -> Module:
	for mod: Module in ModuleRegistry.all_modules:
		if mod.id == mod_id:
			return mod
	return null

# ── Phase transitions ──────────────────────────────────────────────────────

func _enter_shop_phase() -> void:
	phase = Phase.SHOP_PHASE
	_results_panel.visible = false
	_replay_panel.visible  = false
	_replay_timer.stop()
	_selected_offer = null
	_sell_mode    = false
	_upgrade_mode = false
	_sell_btn.text    = "SELL MODULE"
	_upgrade_btn.text = "UPGRADE (★)"
	_style_btn(_sell_btn,    Color("5a1010"), Color("8a2020"))
	_style_btn(_upgrade_btn, Color("4a3a08"), Color("7a6010"))
	player_grid_view.clear_highlights()
	player_grid_view.set_mode_overlay("")

	# Reset any overload-disabled modules from the previous fight
	for mod in player_grid.get_all_modules():
		mod.disabled = false

	var offers := shop.roll_shop(GameState.current_round)
	print("[Shop] Round %d — %d offers:" % [GameState.current_round, offers.size()])
	for mod in offers:
		print("  • %s (%s %s) — %d scrap" % [
			mod.display_name,
			Module.Rarity.keys()[mod.rarity],
			Module.Category.keys()[mod.category],
			mod.cost,
		])

	shop_panel.set_player_grid(player_grid)
	shop_panel.show_offers(offers)
	_action_btn.text     = "READY"
	_action_btn.disabled = false
	_reroll_btn.text     = "REROLL (%dg)" % GameState.get_reroll_cost()
	_reroll_btn.disabled = false
	_sell_btn.disabled    = false
	_upgrade_btn.disabled = false
	_update_status()

func _start_combat() -> void:
	phase = Phase.COMBAT
	_action_btn.disabled  = true
	_reroll_btn.disabled  = true
	_sell_btn.disabled    = true
	_upgrade_btn.disabled = true
	_sell_mode    = false
	_upgrade_mode = false
	_selected_offer = null
	player_grid_view.clear_highlights()
	player_grid_view.set_mode_overlay("")

	var combat_seed := GameState.current_round * 1337 + GameState.mmr

	# Ghost ladder: 30% chance to face a previously saved opponent build
	var ghost := _try_load_ghost(GameState.current_round)
	if ghost != null and GameState.current_round >= 5 and randi() % 100 < 30:
		enemy_grid = ghost
		print("[PvP] Using ghost grid for round %d" % GameState.current_round)
	else:
		enemy_grid = EnemyMechGenerator.generate(GameState.current_round, combat_seed)

	# Save this enemy grid for future ghost use
	_save_ghost_grid(enemy_grid, GameState.current_round)
	enemy_grid_view.refresh(enemy_grid)

	engine = CombatEngine.new(player_grid, enemy_grid, combat_seed)
	engine.combat_ended.connect(_on_combat_ended)

	print("[Combat] Starting round %d simulation…" % GameState.current_round)
	GameLogger.log_round_start(GameState.current_round, GameState.gold, player_grid, enemy_grid)
	var result := engine.run_simulation()
	# Refresh grids so disabled modules show darkened
	player_grid_view.refresh(player_grid)
	enemy_grid_view.refresh(enemy_grid)
	_print_combat_summary(result)

func _on_combat_ended(result: Dictionary) -> void:
	# Pass winner string ("player"/"enemy"/"draw") — draw no longer costs a life
	GameState.earn_round_income(result.winner)
	GameLogger.log_combat_result(GameState.current_round - 1, GameState.gold, result)

	var won: bool  = result.winner == "player"
	var draw: bool = result.winner == "draw"
	var outcome_text := "WIN" if won else ("DRAW" if draw else "LOSS")

	# Save player grid snapshot after every fight (async PvP foundation)
	_save_player_grid()

	print("[Round %d] %s — Gold: %d | Lives: %d" % [
		GameState.current_round - 1,
		outcome_text,
		GameState.gold,
		GameState.player_lives,
	])

	if GameState.is_run_over():
		_enter_run_over()
		return

	phase = Phase.ROUND_END
	_update_status("Last: %s" % outcome_text)
	_action_btn.text     = "NEXT ROUND"
	_action_btn.disabled = false

func _enter_run_over() -> void:
	phase = Phase.RUN_OVER
	GameLogger.log_run_end(GameState.current_round - 1, GameState.total_wins, GameState.total_losses, GameState.mmr)
	_results_panel.visible = false
	_action_btn.disabled = true
	var stats_lbl: Label = _run_over_panel.get_node("StatsLabel")
	stats_lbl.text = (
		"Rounds survived: %d\n" +
		"Wins: %d   Losses: %d\n" +
		"Final MMR: %d"
	) % [
		GameState.current_round - 1,
		GameState.total_wins,
		GameState.total_losses,
		GameState.mmr,
	]
	_run_over_panel.visible = true

func _on_action_pressed() -> void:
	match phase:
		Phase.SHOP_PHASE: _start_combat()
		Phase.ROUND_END:  _enter_shop_phase()

func _on_restart_pressed() -> void:
	_run_over_panel.visible  = false
	_results_panel.visible   = false
	_archetype_panel.visible = true

# ── Shop interaction ───────────────────────────────────────────────────────

func _on_module_selected(mod: Module) -> void:
	_sell_mode    = false
	_upgrade_mode = false
	_sell_btn.text    = "SELL MODULE"
	_upgrade_btn.text = "UPGRADE (★)"
	_style_btn(_sell_btn,    Color("5a1010"), Color("8a2020"))
	_style_btn(_upgrade_btn, Color("4a3a08"), Color("7a6010"))
	_selected_offer = mod
	player_grid_view.set_mode_overlay("")
	player_grid_view.highlight_valid(mod, player_grid)

func _on_player_cell_clicked(pos: Vector2i) -> void:
	if phase != Phase.SHOP_PHASE:
		return

	# Sell mode: sell the module at this cell for half its total cost (base + upgrades)
	if _sell_mode:
		var cell := player_grid.get_cell(pos)
		if cell == null or cell.is_empty():
			return
		if pos in _protected_cells:
			return
		var mod: Module = cell.module
		@warning_ignore("INTEGER_DIVISION")
		var refund: int = mod.cost * mod.star_level / 2
		player_grid.remove_module_at(pos)
		GameState.gold += refund
		GameState.gold_changed.emit(GameState.gold)
		player_grid_view.refresh(player_grid)
		hud_panel.refresh(player_grid)
		_update_status()
		print("[Sell] Sold: %s ★%d for %dg" % [mod.display_name, mod.star_level, refund])
		return

	# Upgrade mode: spend gold to boost a placed module's stats
	if _upgrade_mode:
		var cell := player_grid.get_cell(pos)
		if cell == null or cell.is_empty():
			return
		var mod: Module = cell.module
		if mod.star_level >= Module.MAX_STARS:
			print("[Upgrade] %s is already max star (★%d)" % [mod.display_name, Module.MAX_STARS])
			return
		var ucost := mod.upgrade_cost()
		if not GameState.spend_gold(ucost):
			print("[Upgrade] Not enough gold (need %d, have %d)" % [ucost, GameState.gold])
			return
		mod.upgrade()
		player_grid_view.refresh(player_grid)
		hud_panel.refresh(player_grid)
		_update_status()
		print("[Upgrade] %s → ★%d (%dg spent)" % [mod.display_name, mod.star_level, ucost])
		return

	# Normal placement mode
	if _selected_offer == null:
		return
	if GameState.gold < _selected_offer.cost:
		print("[Shop] Not enough gold (need %d, have %d)" % [_selected_offer.cost, GameState.gold])
		return
	if not player_grid.can_place(pos, _selected_offer):
		return
	if GameState.spend_gold(_selected_offer.cost):
		player_grid.place_module(pos, _selected_offer)
		player_grid_view.refresh(player_grid)
		hud_panel.refresh(player_grid)
		_update_status()
		print("[Shop] Placed: %s at (%d,%d)" % [_selected_offer.display_name, pos.x, pos.y])
		shop_panel.remove_offer(_selected_offer)
		_selected_offer = null
		shop_panel.deselect()
		player_grid_view.clear_highlights()

func _on_reroll_pressed() -> void:
	if reroll_shop():
		_reroll_btn.text = "REROLL (%dg)" % GameState.get_reroll_cost()

func _on_sell_pressed() -> void:
	if phase != Phase.SHOP_PHASE:
		return
	_sell_mode = not _sell_mode
	if _sell_mode:
		_sell_btn.text    = "CANCEL SELL"
		_style_btn(_sell_btn, Color("8a1010"), Color("b02020"))   # bright red = active
		_upgrade_mode     = false
		_upgrade_btn.text = "UPGRADE (★)"
		_style_btn(_upgrade_btn, Color("4a3a08"), Color("7a6010"))
		_selected_offer   = null
		shop_panel.deselect()
		player_grid_view.clear_highlights()
		player_grid_view.set_mode_overlay("sell", _protected_cells)
	else:
		_sell_btn.text = "SELL MODULE"
		_style_btn(_sell_btn, Color("5a1010"), Color("8a2020"))   # back to dim red
		player_grid_view.set_mode_overlay("")

func _on_upgrade_pressed() -> void:
	if phase != Phase.SHOP_PHASE:
		return
	_upgrade_mode = not _upgrade_mode
	if _upgrade_mode:
		_upgrade_btn.text = "CANCEL UPGRADE"
		_style_btn(_upgrade_btn, Color("8a6010"), Color("c09020"))  # bright gold = active
		_sell_mode        = false
		_sell_btn.text    = "SELL MODULE"
		_style_btn(_sell_btn, Color("5a1010"), Color("8a2020"))
		_selected_offer   = null
		shop_panel.deselect()
		player_grid_view.clear_highlights()
		player_grid_view.set_mode_overlay("upgrade")
	else:
		_upgrade_btn.text = "UPGRADE (★)"
		_style_btn(_upgrade_btn, Color("4a3a08"), Color("7a6010"))  # back to dim gold
		player_grid_view.set_mode_overlay("")

# ── Helpers ────────────────────────────────────────────────────────────────

## Apply a flat colour theme to a Button (normal / hover / pressed states).
func _style_btn(btn: Button, col_normal: Color, col_hover: Color) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = col_normal
	sn.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sn)
	var sh := StyleBoxFlat.new()
	sh.bg_color = col_hover
	sh.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", sh)
	var sp := StyleBoxFlat.new()
	sp.bg_color = col_hover.lightened(0.15)
	sp.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", sp)
	var sd := StyleBoxFlat.new()
	sd.bg_color = col_normal.darkened(0.4)
	sd.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("disabled", sd)

## Shake a grid view sideways for ~0.3 s (4 quick swings).
func _shake_grid(view: MechGridView) -> void:
	var origin := view.position
	var tw := create_tween()
	tw.tween_property(view, "position:x", origin.x + 6.0, 0.04)
	tw.tween_property(view, "position:x", origin.x - 6.0, 0.06)
	tw.tween_property(view, "position:x", origin.x + 4.0, 0.06)
	tw.tween_property(view, "position:x", origin.x - 4.0, 0.06)
	tw.tween_property(view, "position:x", origin.x, 0.06)

## Flash the screen edge briefly with `col` (semi-transparent, fades in ~0.25 s).
func _trigger_flash(col: Color) -> void:
	if _flash_rect == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_rect.color = Color(col.r, col.g, col.b, 0.30)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.25)

func _update_status(suffix: String = "") -> void:
	var lives_str := ""
	for i in range(GameState.player_lives):
		lives_str += "♥"
	for _i in range(maxi(0, 3 - GameState.player_lives)):
		lives_str += "♡"
	var text := "Round %d  |  Gold: %d  |  MMR: %d  |  %s" % [
		GameState.current_round, GameState.gold, GameState.mmr, lives_str
	]
	if suffix:
		text += "  |  " + suffix
	_status_label.text = text

# ── Drag-and-drop ────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _drag_mod == null or _drag_ghost == null:
		return
	var mouse := get_viewport().get_mouse_position()
	_drag_ghost.position = mouse + Vector2(14.0, 14.0)

	var cell := _screen_to_grid_cell(mouse, player_grid_view)
	if cell.x >= 0:
		var gs   := _drag_mod.grid_size
		var ox: int = clamp(cell.x - gs.x / 2, 0, MechGrid.GRID_WIDTH  - gs.x)
		var oy: int = clamp(cell.y - gs.y / 2, 0, MechGrid.GRID_HEIGHT - gs.y)
		var origin := Vector2i(ox, oy)
		if origin != _drag_last_cell:
			_drag_last_cell = origin
			player_grid_view.show_drag_footprint(origin, _drag_mod)
	else:
		if _drag_last_cell.x >= 0:
			_drag_last_cell = Vector2i(-1, -1)
			player_grid_view.clear_drag_footprint()


func _input(event: InputEvent) -> void:
	if _drag_mod != null and event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			_clear_drag()
			shop_panel.deselect()
			player_grid_view.clear_highlights()


func _on_shop_drag_started(mod: Module) -> void:
	_drag_mod       = mod
	_selected_offer = null
	player_grid_view.clear_highlights()

	var cat_col: Color = MechGridView.CATEGORY_COLORS.get(mod.category, Color("333333"))
	_drag_ghost      = Panel.new()
	_drag_ghost.size = Vector2(110.0, 38.0)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = cat_col.darkened(0.45)
	style.set_corner_radius_all(6)
	style.border_color        = cat_col.lightened(0.2)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	_drag_ghost.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.text                 = mod.display_name
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.add_child(lbl)

	_canvas.add_child(_drag_ghost)


func _on_shop_drag_dropped(mod: Module, screen_pos: Vector2) -> void:
	_clear_drag()
	if phase != Phase.SHOP_PHASE:
		return
	var cell := _screen_to_grid_cell(screen_pos, player_grid_view)
	if cell.x < 0:
		return
	var gs     := mod.grid_size
	var ox: int = clamp(cell.x - gs.x / 2, 0, MechGrid.GRID_WIDTH  - gs.x)
	var oy: int = clamp(cell.y - gs.y / 2, 0, MechGrid.GRID_HEIGHT - gs.y)
	var origin := Vector2i(ox, oy)
	if GameState.gold < mod.cost:
		print("[Shop] Not enough gold (need %d, have %d)" % [mod.cost, GameState.gold])
		return
	if not player_grid.can_place(origin, mod):
		return
	if GameState.spend_gold(mod.cost):
		player_grid.place_module(origin, mod)
		player_grid_view.refresh(player_grid)
		hud_panel.refresh(player_grid)
		_update_status()
		print("[Shop] Dragged: %s at (%d,%d)" % [mod.display_name, origin.x, origin.y])
		shop_panel.remove_offer(mod)
		shop_panel.deselect()


func _clear_drag() -> void:
	_drag_mod       = null
	_drag_last_cell = Vector2i(-1, -1)
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	player_grid_view.clear_drag_footprint()


## Convert a screen position to a grid cell on `grid_view`.
## Returns Vector2i(-1,-1) if outside the grid bounds.
func _screen_to_grid_cell(screen_pos: Vector2, grid_view: MechGridView) -> Vector2i:
	var local := screen_pos - grid_view.global_position
	var step  := float(MechGridView.CELL_SIZE + MechGridView.CELL_GAP)
	var cx    := int(local.x / step)
	var cy    := int(local.y / step)
	if cx < 0 or cx >= MechGrid.GRID_WIDTH or cy < 0 or cy >= MechGrid.GRID_HEIGHT:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)


func _populate_results_panel(result: Dictionary) -> void:
	var winner: String  = result.winner
	var log:    Array   = result.get("event_log", [])

	var p_dmg:       float = 0.0
	var e_dmg:       float = 0.0
	var p_shots:     int   = 0
	var e_shots:     int   = 0
	var p_disabled:  int   = 0
	var e_disabled:  int   = 0
	var p_mod_dmg:   Dictionary     = {}
	var e_mod_dmg:   Dictionary     = {}
	var p_synergies: Array[String]  = []
	var e_synergies: Array[String]  = []
	var events:      Array[String]  = []

	const HIGHLIGHT := ["dodge", "paradox_overload", "emp_lock", "reflect",
		"rewind_shield", "capacitor_explosion", "overdrive_vent",
		"reactive_armor", "heat_disable"]

	for entry: Dictionary in log:
		var t:     String = entry.get("type",  "")
		var actor: String = entry.get("actor", "?")
		var tick:  int    = entry.get("tick",  0)
		if t == "shot":
			var d:   float  = entry.get("damage", 0.0)
			var mid: String = entry.get("module", "?")
			if actor == "player":
				p_dmg += d; p_shots += 1
				p_mod_dmg[mid] = p_mod_dmg.get(mid, 0.0) + d
			else:
				e_dmg += d; e_shots += 1
				e_mod_dmg[mid] = e_mod_dmg.get(mid, 0.0) + d
		if t == "synergy_active":
			var sname: String = entry.get("name", "?")
			if actor == "player":
				if sname not in p_synergies: p_synergies.append(sname)
			else:
				if sname not in e_synergies: e_synergies.append(sname)
		if t in ["heat_disable", "paradox_overload"]:
			if actor == "player": p_disabled += 1
			else:                 e_disabled += 1
		if t in HIGHLIGHT:
			match t:
				"dodge":               events.append("t%d  %s dodged" % [tick, actor])
				"paradox_overload":    events.append("t%d  %s OVERLOAD [%s]" % [tick, actor, entry.get("module", "?")])
				"emp_lock":            events.append("t%d  %s EMP -> %s" % [tick, actor, entry.get("module", "?")])
				"reflect":             events.append("t%d  %s reflected %.0f" % [tick, actor, entry.get("reflected", 0.0)])
				"rewind_shield":       events.append("t%d  %s REWIND SHIELD" % [tick, actor])
				"capacitor_explosion": events.append("t%d  %s CAPACITOR BLAST" % [tick, actor])
				"overdrive_vent":      events.append("t%d  %s VENT (-15 HP)" % [tick, actor])
				"reactive_armor":      events.append("t%d  %s reactive armor" % [tick, actor])
				"heat_disable":        events.append("t%d  %s heat-disabled [%s]" % [tick, actor, entry.get("module", "?")])

	# Header
	var header: Label = _results_panel.get_node("Header")
	match winner:
		"player":
			header.text = "VICTORY"
			header.add_theme_color_override("font_color", Color("40dd60"))
		"enemy":
			header.text = "DEFEAT"
			header.add_theme_color_override("font_color", Color("dd3020"))
		_:
			header.text = "DRAW"
			header.add_theme_color_override("font_color", Color("d0c020"))

	# Subheader
	var sub: Label = _results_panel.get_node("Subheader")
	var timeout_tag := "  [TIMEOUT]" if result.ticks >= CombatEngine.MAX_TICKS else ""
	sub.text = "Round %d%s  ·  %.1f seconds" % [
		GameState.current_round - 1, timeout_tag, result.duration_seconds]

	# Per-side stats with top-3 weapon breakdown
	var p_syn_line := ("Synergies: " + ", ".join(p_synergies) + "\n") if not p_synergies.is_empty() else ""
	var e_syn_line := ("Synergies: " + ", ".join(e_synergies) + "\n") if not e_synergies.is_empty() else ""

	var p_lbl: Label = _results_panel.get_node("PlayerStats")
	p_lbl.text = (
		"PLAYER\n\n"
		+ p_syn_line
		+ "Damage:   %.0f  (%d shots)\n" % [p_dmg, p_shots]
		+ _top_weapons(p_mod_dmg, 3)
		+ "HP left:  %.1f\n" % result.player_hp_remaining
		+ "Disabled: %d module%s" % [p_disabled, "s" if p_disabled != 1 else ""]
	)

	var e_lbl: Label = _results_panel.get_node("EnemyStats")
	e_lbl.text = (
		"ENEMY\n\n"
		+ e_syn_line
		+ "Damage:   %.0f  (%d shots)\n" % [e_dmg, e_shots]
		+ _top_weapons(e_mod_dmg, 3)
		+ "HP left:  %.1f\n" % result.enemy_hp_remaining
		+ "Disabled: %d module%s" % [e_disabled, "s" if e_disabled != 1 else ""]
	)

	# Notable events
	var ev_lbl: Label = _results_panel.get_node("Events")
	ev_lbl.text = "\n".join(events.slice(-8)) if not events.is_empty() else "— No notable events —"

	_results_panel.visible = true


func _top_weapons(mod_dmg: Dictionary, limit: int) -> String:
	if mod_dmg.is_empty():
		return ""
	var pairs: Array = []
	for k in mod_dmg.keys():
		pairs.append([k, mod_dmg[k]])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var lines: PackedStringArray = []
	for i in range(mini(limit, pairs.size())):
		lines.append("  %-18s %.0f" % [pairs[i][0], pairs[i][1]])
	return "\n".join(lines) + "\n"

func _print_combat_summary(result: Dictionary) -> void:
	var timeout_tag := " [TIMEOUT]" if result.ticks >= CombatEngine.MAX_TICKS else ""
	print("[Combat] Winner: %s%s | Player HP: %.1f | Enemy HP: %.1f | Ticks: %d (%.1fs)" % [
		result.winner,
		timeout_tag,
		result.player_hp_remaining,
		result.enemy_hp_remaining,
		result.ticks,
		result.duration_seconds,
	])
	_last_result = result
	_update_combat_log(result.get("event_log", []), result.winner)
	if phase != Phase.RUN_OVER:
		_populate_results_panel(result)

func _update_combat_log(log: Array, winner: String) -> void:
	const HIGHLIGHT := ["dodge", "paradox_overload", "emp_lock", "reflect",
		"rewind_shield", "capacitor_explosion", "overdrive_vent",
		"reactive_armor", "heat_disable"]
	var p_dmg := 0.0
	var e_dmg := 0.0
	var p_shots := 0
	var e_shots  := 0
	var events: Array[String] = []

	for entry: Dictionary in log:
		var t: String = entry.get("type", "")
		var actor: String = entry.get("actor", "?")
		var tick: int = entry.get("tick", 0)
		if t == "shot":
			var d: float = entry.get("damage", 0.0)
			if actor == "player": p_dmg += d; p_shots += 1
			else:                 e_dmg += d; e_shots += 1
		elif t in HIGHLIGHT:
			match t:
				"dodge":               events.append("t%d  %s dodged" % [tick, actor])
				"paradox_overload":    events.append("t%d  %s OVERLOAD [%s]" % [tick, actor, entry.get("module","?")])
				"emp_lock":            events.append("t%d  %s EMP → %s" % [tick, actor, entry.get("module","?")])
				"reflect":             events.append("t%d  %s reflected %.0f" % [tick, actor, entry.get("reflected", 0.0)])
				"rewind_shield":       events.append("t%d  %s REWIND (%.0f shd)" % [tick, actor, entry.get("restored", 0.0)])
				"capacitor_explosion": events.append("t%d  %s CAPACITOR BLAST" % [tick, actor])
				"overdrive_vent":      events.append("t%d  %s VENT (−15HP)" % [tick, actor])
				"reactive_armor":      events.append("t%d  %s reactive armor" % [tick, actor])
				"heat_disable":        events.append("t%d  %s heat-disabled [%s]" % [tick, actor, entry.get("module","?")])

	var outcome := winner.to_upper()
	var header := "%s  |  P %.0fdmg (%d)  E %.0fdmg (%d)" % [outcome, p_dmg, p_shots, e_dmg, e_shots]
	var tail := events.slice(-7)   # last 7 notable events
	tail.insert(0, header)
	_combat_log.text = "\n".join(tail)

func _on_player_cell_hovered(pos: Vector2i) -> void:
	var cell := player_grid.get_cell(pos)
	if cell == null or cell.is_empty():
		_tooltip_panel.visible = false
		return
	var mod := cell.module
	var lbl: Label = _tooltip_panel.get_node("TooltipLabel")
	var lines: Array[String] = []
	var stars := "★".repeat(mod.star_level - 1)
	lines.append(mod.display_name + ("  " + stars if stars else ""))
	lines.append("%s · %s" % [Module.Category.keys()[mod.category], Module.Rarity.keys()[mod.rarity]])
	lines.append("")
	if mod.base_damage  > 0.0: lines.append("DMG  %.0f  RoF %.1f/s" % [mod.base_damage, mod.fire_rate])
	if mod.power_gen    > 0.0: lines.append("GEN  +%.0f" % mod.power_gen)
	if mod.power_draw   > 0.0: lines.append("PWR  −%.0f" % mod.power_draw)
	if mod.hp           > 0.0: lines.append("HP   +%.0f" % mod.hp)
	if mod.shield_value > 0.0: lines.append("SHD  +%.0f" % mod.shield_value)
	if mod.heat_reduction > 0.0: lines.append("COOL +%.0f" % mod.heat_reduction)
	if mod.heat_gen     > 0.0: lines.append("HEAT +%.0f/s" % mod.heat_gen)
	if mod.paradox_rate > 0.0: lines.append("PDX  +%.0f/s" % mod.paradox_rate)
	if mod.recoil_force > 0.0: lines.append("RCOL %.1f" % mod.recoil_force)
	lines.append("")
	if mod.disabled:
		lines.append("[ DISABLED ]")
	elif mod.star_level < Module.MAX_STARS:
		lines.append("Upgrade: %dg → ★%d" % [mod.upgrade_cost(), mod.star_level + 1])
	else:
		lines.append("★ MAX STAR ★")
	lbl.text = "\n".join(lines)
	_tooltip_panel.visible = true

func _on_player_cell_unhovered() -> void:
	_tooltip_panel.visible = false

func _save_player_grid() -> void:
	var data   := player_grid.serialize()
	var json   := JSON.stringify(data, "\t")
	var file   := FileAccess.open("user://player_grid.json", FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()

func _save_ghost_grid(grid: MechGrid, round_num: int) -> void:
	var data := grid.serialize()
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open("user://ghost_%d.json" % round_num, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()

## Try to load a ghost opponent grid from a nearby round (±2).
## Returns null if nothing is saved yet.
func _try_load_ghost(round_num: int) -> MechGrid:
	for offset in [0, -1, 1, -2, 2]:
		var path := "user://ghost_%d.json" % (round_num + offset)
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var json_str := file.get_as_text()
				file.close()
				var data = JSON.parse_string(json_str)
				if data is Dictionary:
					return MechGrid.deserialize(data)
	return null

# ── Public API (called by future UI nodes) ─────────────────────────────────

func buy_module(mod: Module) -> bool:
	if phase != Phase.SHOP_PHASE:
		return false
	return GameState.spend_gold(mod.cost)

func place_module(pos: Vector2i, mod: Module) -> bool:
	if phase != Phase.SHOP_PHASE:
		return false
	if player_grid.place_module(pos, mod):
		player_grid_view.refresh(player_grid)
		return true
	return false

func confirm_build() -> void:
	if phase == Phase.SHOP_PHASE:
		_start_combat()

func reroll_shop() -> bool:
	if phase != Phase.SHOP_PHASE:
		return false
	var cost := GameState.get_reroll_cost()
	if not GameState.spend_gold(cost):
		return false
	var new_offers := shop.reroll(GameState.current_round)
	shop_panel.set_player_grid(player_grid)
	shop_panel.show_offers(new_offers)
	_update_status()
	return true
