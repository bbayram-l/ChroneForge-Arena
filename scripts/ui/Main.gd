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
var player_grid_view: MechGridView
var enemy_grid_view:  MechGridView
var shop_panel:       ShopPanel
var hud_panel:        HudPanel
var _status_label:    Label
var _action_btn:      Button
var _reroll_btn:      Button
var _sell_btn:        Button
var _upgrade_btn:     Button
var _run_over_panel:  Control
var _selected_offer:  Module = null
var _sell_mode:       bool   = false
var _upgrade_mode:    bool   = false
var _protected_cells: Array[Vector2i] = []

# ── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	player_grid = MechGrid.new("player")
	enemy_grid  = MechGrid.new("enemy")
	shop        = ShopSystem.new(ModuleRegistry.all_modules, randi())

	_setup_ui()
	GameState.start_run()
	_give_starter_modules()
	_enter_shop_phase()

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

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

	# Reroll button — visible only in shop phase
	_reroll_btn = Button.new()
	_reroll_btn.position = Vector2(1090.0, 46.0)
	_reroll_btn.size     = Vector2(172.0, 28.0)
	_reroll_btn.text     = "REROLL (2g)"
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	canvas.add_child(_reroll_btn)

	# Sell button — toggles sell mode in shop phase
	_sell_btn = Button.new()
	_sell_btn.position = Vector2(1090.0, 80.0)
	_sell_btn.size     = Vector2(172.0, 28.0)
	_sell_btn.text     = "SELL MODULE"
	_sell_btn.pressed.connect(_on_sell_pressed)
	canvas.add_child(_sell_btn)

	# Upgrade button — toggles upgrade mode in shop phase
	_upgrade_btn = Button.new()
	_upgrade_btn.position = Vector2(1090.0, 114.0)
	_upgrade_btn.size     = Vector2(172.0, 28.0)
	_upgrade_btn.text     = "UPGRADE (★)"
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	canvas.add_child(_upgrade_btn)

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
	hud_panel.position = Vector2(196.0, 484.0)
	canvas.add_child(hud_panel)

	# Shop panel — below HUD
	shop_panel = ShopPanel.new()
	shop_panel.position = Vector2(87.0, 566.0)
	canvas.add_child(shop_panel)
	shop_panel.module_selected.connect(_on_module_selected)

	# Run-over overlay (hidden until run ends)
	_run_over_panel = _build_run_over_panel()
	canvas.add_child(_run_over_panel)
	_run_over_panel.visible = false

	_update_status()

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

# ── Starter modules ────────────────────────────────────────────────────────

func _give_starter_modules() -> void:
	# Place the cheapest COMMON POWER module for free — the mech's built-in chassis.
	var starters: Array[Module] = []
	for mod: Module in ModuleRegistry.all_modules:
		if mod.category == Module.Category.POWER and mod.rarity == Module.Rarity.COMMON:
			starters.append(mod)
	if starters.is_empty():
		return
	starters.sort_custom(func(a: Module, b: Module) -> bool: return a.cost < b.cost)
	var core: Module = starters[0]
	player_grid.place_module(Vector2i(2, 2), core)
	_protected_cells.append(Vector2i(2, 2))
	player_grid_view.refresh(player_grid)
	hud_panel.refresh(player_grid)
	print("[Setup] Starter: %s placed (free)" % core.display_name)

# ── Phase transitions ──────────────────────────────────────────────────────

func _enter_shop_phase() -> void:
	phase = Phase.SHOP_PHASE
	_selected_offer = null
	_sell_mode    = false
	_upgrade_mode = false
	_sell_btn.text    = "SELL MODULE"
	_upgrade_btn.text = "UPGRADE (★)"
	player_grid_view.clear_highlights()

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

	var combat_seed := GameState.current_round * 1337 + GameState.mmr

	# Ghost ladder: 30% chance to face a previously saved opponent build
	var ghost := _try_load_ghost(GameState.current_round)
	if ghost != null and randi() % 100 < 30:
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
	var result := engine.run_simulation()
	_print_combat_summary(result)

func _on_combat_ended(result: Dictionary) -> void:
	# Pass winner string ("player"/"enemy"/"draw") — draw no longer costs a life
	GameState.earn_round_income(result.winner)

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
	_run_over_panel.visible = false
	# Clear player grid
	_protected_cells.clear()
	player_grid = MechGrid.new("player")
	enemy_grid  = MechGrid.new("enemy")
	player_grid_view.refresh(player_grid)
	enemy_grid_view.refresh(enemy_grid)
	# Reset shop with new seed
	shop = ShopSystem.new(ModuleRegistry.all_modules, randi())
	GameState.start_run()
	_give_starter_modules()
	_enter_shop_phase()

# ── Shop interaction ───────────────────────────────────────────────────────

func _on_module_selected(mod: Module) -> void:
	_sell_mode    = false
	_upgrade_mode = false
	_sell_btn.text    = "SELL MODULE"
	_upgrade_btn.text = "UPGRADE (★)"
	_selected_offer = mod
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
		_upgrade_mode     = false
		_upgrade_btn.text = "UPGRADE (★)"
		_selected_offer   = null
		shop_panel.deselect()
		player_grid_view.clear_highlights()
	else:
		_sell_btn.text = "SELL MODULE"

func _on_upgrade_pressed() -> void:
	if phase != Phase.SHOP_PHASE:
		return
	_upgrade_mode = not _upgrade_mode
	if _upgrade_mode:
		_upgrade_btn.text = "CANCEL UPGRADE"
		_sell_mode        = false
		_sell_btn.text    = "SELL MODULE"
		_selected_offer   = null
		shop_panel.deselect()
		player_grid_view.clear_highlights()
	else:
		_upgrade_btn.text = "UPGRADE (★)"

# ── Helpers ────────────────────────────────────────────────────────────────

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
	shop_panel.show_offers(new_offers)
	_update_status()
	return true
