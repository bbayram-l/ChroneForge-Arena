## CombatEngine — deterministic tick-based combat simulation.
##
## Usage:
##   var engine = CombatEngine.new(player_grid, enemy_grid, rng_seed)
##   var result = engine.run_simulation()
##
## The simulation is fully deterministic given the same seed and grids.
## The event_log can be serialized for async PvP replay.
class_name CombatEngine
extends RefCounted

const TICK_RATE: float = 0.1   # seconds per tick (10 ticks/sec)
const MAX_TICKS: int   = 300   # 30-second hard cap

signal combat_ended(result: Dictionary)

# Grids
var player_grid: MechGrid
var enemy_grid:  MechGrid

# Systems — one set per mech
var _p_power:   PowerSystem
var _e_power:   PowerSystem
var _p_heat:    HeatSystem
var _e_heat:    HeatSystem
var _p_physics: PhysicsLite
var _e_physics: PhysicsLite
var _p_paradox: ParadoxSystem
var _e_paradox: ParadoxSystem

# Live HP / shield
var player_hp:     float
var player_shield: float
var enemy_hp:      float
var enemy_shield:  float

var tick_count: int = 0
var event_log:  Array[Dictionary] = []
var rng:        RandomNumberGenerator

# Weapon cooldown trackers: module.id → remaining seconds
var _p_cooldowns: Dictionary = {}
var _e_cooldowns: Dictionary = {}

# Reactive-armor burst-window timers: module.id → seconds until ready again
var _p_burst_ready: Dictionary = {}
var _e_burst_ready: Dictionary = {}

func _init(p_grid: MechGrid, e_grid: MechGrid, rng_seed: int = 0) -> void:
	player_grid = p_grid
	enemy_grid  = e_grid

	_p_power   = PowerSystem.new(player_grid)
	_e_power   = PowerSystem.new(enemy_grid)
	_p_heat    = HeatSystem.new(player_grid)
	_e_heat    = HeatSystem.new(enemy_grid)
	_p_physics = PhysicsLite.new(player_grid)
	_e_physics = PhysicsLite.new(enemy_grid)
	_p_paradox = ParadoxSystem.new(player_grid)
	_e_paradox = ParadoxSystem.new(enemy_grid)

	# Wire paradox overload callbacks
	_p_paradox.module_disabled.connect(_on_module_disabled.bind(true))
	_e_paradox.module_disabled.connect(_on_module_disabled.bind(false))

	rng = RandomNumberGenerator.new()
	rng.seed = rng_seed

	player_hp     = _base_hp(player_grid)
	player_shield = _base_shield(player_grid)
	enemy_hp      = _base_hp(enemy_grid)
	enemy_shield  = _base_shield(enemy_grid)

# ── Public API ─────────────────────────────────────────────────────────────

func run_simulation() -> Dictionary:
	event_log.clear()
	tick_count = 0
	_p_cooldowns.clear()
	_e_cooldowns.clear()

	while tick_count < MAX_TICKS and player_hp > 0.0 and enemy_hp > 0.0:
		_tick()
		tick_count += 1

	var winner: String
	if player_hp <= 0.0 and enemy_hp <= 0.0:
		winner = "draw"
	elif player_hp <= 0.0:
		winner = "enemy"
	else:
		winner = "player"

	var result := {
		"winner":              winner,
		"player_hp_remaining": player_hp,
		"enemy_hp_remaining":  enemy_hp,
		"ticks":               tick_count,
		"duration_seconds":    tick_count * TICK_RATE,
		"event_log":           event_log,
	}
	combat_ended.emit(result)
	return result

# ── Tick ───────────────────────────────────────────────────────────────────

func _tick() -> void:
	var d := TICK_RATE

	# 1. Paradox accumulation + overload rolls
	_p_paradox.tick(d, rng)
	_e_paradox.tick(d, rng)

	# 2. Heat dissipation
	_p_heat.dissipate(d)
	_e_heat.dissipate(d)

	# 3. Recoil decay
	_p_physics.decay_displacement(d)
	_e_physics.decay_displacement(d)

	# 4. Advance weapon cooldowns and burst-window timers
	_advance_cooldowns(_p_cooldowns, d)
	_advance_cooldowns(_e_cooldowns, d)
	_advance_cooldowns(_p_burst_ready, d)
	_advance_cooldowns(_e_burst_ready, d)

	# 5. Fire weapons
	var p_power := _p_power.get_state()
	var e_power := _e_power.get_state()

	for mod in player_grid.get_all_modules():
		if mod.category == Module.Category.WEAPON and not mod.disabled:
			_fire_weapon(mod, true, p_power)

	for mod in enemy_grid.get_all_modules():
		if mod.category == Module.Category.WEAPON and not mod.disabled:
			_fire_weapon(mod, false, e_power)

	# 6. Snapshot for replay
	_log_tick_state()

func _advance_cooldowns(map: Dictionary, delta: float) -> void:
	for key in map.keys():
		map[key] = maxf(0.0, map[key] - delta)

# ── Weapon firing ──────────────────────────────────────────────────────────

func _fire_weapon(weapon: Module, is_player: bool, power_state: Dictionary) -> void:
	var wid := weapon.id

	# Init cooldown slot
	if not _p_cooldowns.has(wid) and is_player:
		_p_cooldowns[wid] = 0.0
	if not _e_cooldowns.has(wid) and not is_player:
		_e_cooldowns[wid] = 0.0

	var cds := _p_cooldowns if is_player else _e_cooldowns
	if cds[wid] > 0.0:
		return

	var grid    := player_grid if is_player else enemy_grid
	var heat    := _p_heat    if is_player else _e_heat
	var physics := _p_physics if is_player else _e_physics
	var pos     := grid.get_module_position(weapon)

	# Heat disable check
	if heat.is_disabled_by_heat(pos):
		_log("heat_disable", is_player, {"module": wid})
		return

	# Build modifiers
	var power_eff: float = power_state.efficiency
	var stability   := physics.stability_modifier()
	var heat_pen    := heat.overheat_penalty(pos)
	var final_stab  := stability * (1.0 - heat_pen)

	# Resolve damage
	var damage := DamageResolver.resolve_shot(weapon, power_eff, final_stab, 1.0, rng)

	# Side effects
	physics.apply_recoil(weapon)
	heat.add_heat(pos, weapon.heat_gen)

	# Deal damage to the opposing mech
	if is_player:
		_deal_to_enemy(damage, weapon)
	else:
		_deal_to_player(damage, weapon)

	# Reset cooldown
	cds[wid] = 1.0 / weapon.fire_rate if weapon.fire_rate > 0.0 else 9999.0

	_log("shot", is_player, {
		"module":     wid,
		"damage":     snappedf(damage, 0.01),
		"power_eff":  snappedf(power_eff, 0.01),
		"stability":  snappedf(final_stab, 0.01),
	})

# ── Damage application ─────────────────────────────────────────────────────

func _deal_to_player(raw: float, _source: Module) -> void:
	var res := DamageResolver.apply_shield(raw, player_shield, 1.0)
	player_shield = maxf(0.0, player_shield - res.shield_damage)
	player_hp     = maxf(0.0, player_hp     - res.hp_damage)

func _deal_to_enemy(raw: float, _source: Module) -> void:
	var res := DamageResolver.apply_shield(raw, enemy_shield, 1.0)
	enemy_shield = maxf(0.0, enemy_shield - res.shield_damage)
	enemy_hp     = maxf(0.0, enemy_hp     - res.hp_damage)

# ── Paradox overload callback ──────────────────────────────────────────────

func _on_module_disabled(mod: Module, is_player: bool) -> void:
	_log("paradox_overload", is_player, {"module": mod.id})

# ── Logging ────────────────────────────────────────────────────────────────

func _log(event_type: String, is_player: bool, data: Dictionary) -> void:
	var entry := {"tick": tick_count, "type": event_type, "actor": "player" if is_player else "enemy"}
	entry.merge(data)
	event_log.append(entry)

func _log_tick_state() -> void:
	event_log.append({
		"tick":            tick_count,
		"type":            "state",
		"player_hp":       snappedf(player_hp,     0.1),
		"player_shield":   snappedf(player_shield,  0.1),
		"enemy_hp":        snappedf(enemy_hp,       0.1),
		"enemy_shield":    snappedf(enemy_shield,   0.1),
		"player_paradox":  snappedf(_p_paradox.paradox, 0.1),
		"enemy_paradox":   snappedf(_e_paradox.paradox, 0.1),
		"player_heat":     _p_heat.get_state(),
		"enemy_heat":      _e_heat.get_state(),
	})

# ── Helpers ────────────────────────────────────────────────────────────────

static func _base_hp(grid: MechGrid) -> float:
	var hp := 100.0
	for mod in grid.get_all_modules():
		hp += mod.hp
	return hp

static func _base_shield(grid: MechGrid) -> float:
	var shield := 0.0
	for mod in grid.get_all_modules():
		shield += mod.shield_value
	return shield
