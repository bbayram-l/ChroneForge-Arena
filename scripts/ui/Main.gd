## Main — root scene script and game-loop coordinator.
##
## Game loop:
##   SHOP_PHASE  → player clicks cards to select, clicks grid cells to place
##   COMBAT      → deterministic simulation runs instantly, result shown
##   ROUND_END   → player clicks "NEXT ROUND" to continue
##
## Visual nodes are created programmatically in _setup_ui().
extends Node

enum Phase { START_RUN, SHOP_PHASE, COMBAT, ROUND_END }

var phase: Phase = Phase.START_RUN

var player_grid: MechGrid
var enemy_grid:  MechGrid
var shop:        ShopSystem
var engine:      CombatEngine

# UI nodes
var player_grid_view: MechGridView
var enemy_grid_view:  MechGridView
var shop_panel:       ShopPanel
var _status_label:    Label
var _action_btn:      Button
var _selected_offer:  Module = null

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
	_status_label.add_theme_font_size_override("font_size", 15)
	canvas.add_child(_status_label)

	# Action button — "READY" in shop phase, "NEXT ROUND" after combat
	_action_btn = Button.new()
	_action_btn.position = Vector2(1090.0, 6.0)
	_action_btn.size     = Vector2(172.0, 34.0)
	_action_btn.text     = "READY"
	_action_btn.pressed.connect(_on_action_pressed)
	canvas.add_child(_action_btn)

	# Player grid — left side
	# 6×(64+4)−4 = 404 px wide. Two grids centred: (1280−404−80−404)/2 = 196 px margin
	player_grid_view = MechGridView.new()
	player_grid_view.position = Vector2(196.0, 140.0)
	canvas.add_child(player_grid_view)
	player_grid_view.set_title("PLAYER")
	player_grid_view.cell_clicked.connect(_on_player_cell_clicked)
	player_grid_view.refresh(player_grid)

	# Enemy grid — right side
	enemy_grid_view = MechGridView.new()
	enemy_grid_view.position = Vector2(680.0, 140.0)
	canvas.add_child(enemy_grid_view)
	enemy_grid_view.set_title("ENEMY")
	enemy_grid_view.refresh(enemy_grid)

	# Shop panel — below grids
	# 5×210 + 4×14 = 1106 px → left margin (1280−1106)/2 = 87 px
	shop_panel = ShopPanel.new()
	shop_panel.position = Vector2(87.0, 562.0)
	canvas.add_child(shop_panel)
	shop_panel.module_selected.connect(_on_module_selected)

	_update_status()

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
	player_grid_view.refresh(player_grid)
	print("[Setup] Starter: %s placed (free)" % core.display_name)

# ── Phase transitions ──────────────────────────────────────────────────────

func _enter_shop_phase() -> void:
	phase = Phase.SHOP_PHASE
	_selected_offer = null
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
	_update_status()

func _start_combat() -> void:
	phase = Phase.COMBAT
	_action_btn.disabled = true
	_selected_offer = null
	player_grid_view.clear_highlights()

	var combat_seed := GameState.current_round * 1337 + GameState.mmr
	enemy_grid = EnemyMechGenerator.generate(GameState.current_round, combat_seed)
	enemy_grid_view.refresh(enemy_grid)

	engine = CombatEngine.new(player_grid, enemy_grid, combat_seed)
	engine.combat_ended.connect(_on_combat_ended)

	print("[Combat] Starting round %d simulation…" % GameState.current_round)
	var result := engine.run_simulation()
	_print_combat_summary(result)

func _on_combat_ended(result: Dictionary) -> void:
	phase = Phase.ROUND_END
	var won: bool = result.winner == "player"
	GameState.earn_round_income(won)
	_update_status("Last: %s" % ("WIN" if won else "LOSS"))
	_action_btn.text     = "NEXT ROUND"
	_action_btn.disabled = false
	print("[Round %d] %s — Gold: %d" % [
		GameState.current_round,
		"WIN" if won else "LOSS",
		GameState.gold,
	])

func _on_action_pressed() -> void:
	match phase:
		Phase.SHOP_PHASE: _start_combat()
		Phase.ROUND_END:  _enter_shop_phase()

# ── Shop interaction ───────────────────────────────────────────────────────

func _on_module_selected(mod: Module) -> void:
	_selected_offer = mod
	player_grid_view.highlight_valid(mod, player_grid)

func _on_player_cell_clicked(pos: Vector2i) -> void:
	if phase != Phase.SHOP_PHASE or _selected_offer == null:
		return
	if GameState.gold < _selected_offer.cost:
		print("[Shop] Not enough gold (need %d, have %d)" % [_selected_offer.cost, GameState.gold])
		return
	if not player_grid.can_place(pos, _selected_offer):
		return
	if GameState.spend_gold(_selected_offer.cost):
		player_grid.place_module(pos, _selected_offer)
		player_grid_view.refresh(player_grid)
		_update_status()
		print("[Shop] Placed: %s at (%d,%d)" % [_selected_offer.display_name, pos.x, pos.y])
		_selected_offer = null
		shop_panel.deselect()
		player_grid_view.clear_highlights()

# ── Helpers ────────────────────────────────────────────────────────────────

func _update_status(suffix: String = "") -> void:
	var text := "Round %d  |  Gold: %d  |  MMR: %d" % [
		GameState.current_round, GameState.gold, GameState.mmr
	]
	if suffix:
		text += "  |  " + suffix
	_status_label.text = text

func _print_combat_summary(result: Dictionary) -> void:
	print("[Combat] Winner: %s | Player HP: %.1f | Enemy HP: %.1f | Ticks: %d (%.1fs)" % [
		result.winner,
		result.player_hp_remaining,
		result.enemy_hp_remaining,
		result.ticks,
		result.duration_seconds,
	])

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
