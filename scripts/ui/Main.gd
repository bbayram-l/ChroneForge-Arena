## Main — root scene script and game-loop coordinator.
##
## Wires together the shop draft phase and combat simulation.
## This is the single entry point for the MVP game loop:
##
##   1. START_RUN  → earn income, roll shop
##   2. SHOP_PHASE → player buys modules, places them on their grid
##   3. COMBAT     → deterministic simulation runs, result logged
##   4. ROUND_END  → apply result, loop back to step 1
##
## Visual presentation is left to child scenes/UI nodes;
## this class manages only state and transitions.
extends Node

enum Phase { START_RUN, SHOP_PHASE, COMBAT, ROUND_END }

var phase: Phase = Phase.START_RUN

var player_grid: MechGrid
var enemy_grid:  MechGrid
var shop:        ShopSystem
var engine:      CombatEngine

# ── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	player_grid = MechGrid.new("player")
	enemy_grid  = MechGrid.new("enemy")
	shop        = ShopSystem.new(ModuleRegistry.all_modules, randi())

	GameState.start_run()
	_enter_shop_phase()

# ── Phase transitions ──────────────────────────────────────────────────────

func _enter_shop_phase() -> void:
	phase = Phase.SHOP_PHASE
	var offers := shop.roll_shop(GameState.current_round)
	print("[Shop] Round %d — %d offers:" % [GameState.current_round, offers.size()])
	for mod in offers:
		print("  • %s (%s %s) — %d scrap" % [
			mod.display_name,
			Module.Rarity.keys()[mod.rarity],
			Module.Category.keys()[mod.category],
			mod.cost,
		])

	# MVP auto-buy: purchase the first affordable weapon/power module for demo
	_auto_draft(offers)

func _auto_draft(offers: Array[Module]) -> void:
	for mod in offers:
		if GameState.gold >= mod.cost:
			if mod.category in [Module.Category.WEAPON, Module.Category.POWER]:
				if GameState.spend_gold(mod.cost):
					_place_module_auto(mod)
					print("[Draft] Bought: %s" % mod.display_name)
					break
	_start_combat()

func _place_module_auto(mod: Module) -> void:
	# Find first open cell on the player grid
	for y in range(MechGrid.GRID_HEIGHT):
		for x in range(MechGrid.GRID_WIDTH):
			if player_grid.place_module(Vector2i(x, y), mod):
				return

func _start_combat() -> void:
	phase = Phase.COMBAT

	# Seed from round so replays are reproducible
	var seed := GameState.current_round * 1337 + GameState.mmr
	engine = CombatEngine.new(player_grid, enemy_grid, seed)
	engine.combat_ended.connect(_on_combat_ended)

	print("[Combat] Starting round %d simulation…" % GameState.current_round)
	var result := engine.run_simulation()
	_print_combat_summary(result)

func _on_combat_ended(result: Dictionary) -> void:
	phase = Phase.ROUND_END
	var won := result.winner == "player"
	GameState.earn_round_income(won)
	print("[Round %d] %s — Gold: %d" % [
		GameState.current_round,
		"WIN" if won else "LOSS",
		GameState.gold,
	])

# ── Helpers ────────────────────────────────────────────────────────────────

func _print_combat_summary(result: Dictionary) -> void:
	print("[Combat] Winner: %s | Player HP: %.1f | Enemy HP: %.1f | Ticks: %d (%.1fs)" % [
		result.winner,
		result.player_hp_remaining,
		result.enemy_hp_remaining,
		result.ticks,
		result.duration_seconds,
	])

# ── Public API (called by UI nodes) ───────────────────────────────────────

## Buy a module from the current shop offer list.
func buy_module(mod: Module) -> bool:
	if phase != Phase.SHOP_PHASE:
		return false
	return GameState.spend_gold(mod.cost)

## Attempt to place a module at a grid position.
func place_module(pos: Vector2i, mod: Module) -> bool:
	if phase != Phase.SHOP_PHASE:
		return false
	return player_grid.place_module(pos, mod)

## Confirm the build and start combat.
func confirm_build() -> void:
	if phase != Phase.SHOP_PHASE:
		return
	_start_combat()

## Reroll the shop (costs gold).
func reroll_shop() -> bool:
	if phase != Phase.SHOP_PHASE:
		return false
	var cost := GameState.get_reroll_cost()
	if not GameState.spend_gold(cost):
		return false
	shop.reroll(GameState.current_round)
	return true
