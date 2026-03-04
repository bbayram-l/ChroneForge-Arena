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

# Reactive-armor burst-window timers: "reactive_armor" → seconds until ready again
var _p_burst_ready: Dictionary = {}
var _e_burst_ready: Dictionary = {}

# EMP lock timers: module.id → remaining lock seconds
var _p_emp_locks: Dictionary = {}
var _e_emp_locks: Dictionary = {}

# Timeline Split: remaining active seconds (2× damage window)
var _p_timeline_active: float = 0.0
var _e_timeline_active: float = 0.0

# Rewind Shield: one-shot shield restore
var _p_rewind_used: bool  = false
var _e_rewind_used: bool  = false
var _p_shield_snap: float = 0.0   # shield value ~2 s ago (updated every 20 ticks)
var _e_shield_snap: float = 0.0

# Entropy Field: cumulative weapon-damage debuff multipliers
var _p_dmg_mult: float = 1.0   # player weapon output (debuffed by enemy entropy_field)
var _e_dmg_mult: float = 1.0   # enemy  weapon output (debuffed by player entropy_field)
var _p_entropy_cd: int = 10    # ticks until enemy entropy fires against player
var _e_entropy_cd: int = 10    # ticks until player entropy fires against enemy

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
	_p_burst_ready.clear()
	_e_burst_ready.clear()
	_p_emp_locks.clear()
	_e_emp_locks.clear()
	_p_rewind_used    = false
	_e_rewind_used    = false
	_p_shield_snap    = player_shield
	_e_shield_snap    = enemy_shield
	_p_dmg_mult       = 1.0
	_e_dmg_mult       = 1.0
	_p_entropy_cd     = 10
	_e_entropy_cd     = 10

	# timeline_split: active for first 1.5 seconds of combat
	_p_timeline_active = 1.5 if _has_module(player_grid, "timeline_split") else 0.0
	_e_timeline_active = 1.5 if _has_module(enemy_grid,  "timeline_split") else 0.0

	# pre_fire_snapshot: all weapons fire once before the main loop
	if _has_module(player_grid, "pre_fire_snapshot"):
		for mod in player_grid.get_all_modules():
			if mod.category == Module.Category.WEAPON and not mod.disabled:
				_fire_weapon(mod, true)
	if _has_module(enemy_grid, "pre_fire_snapshot"):
		for mod in enemy_grid.get_all_modules():
			if mod.category == Module.Category.WEAPON and not mod.disabled:
				_fire_weapon(mod, false)

	while tick_count < MAX_TICKS and player_hp > 0.0 and enemy_hp > 0.0:
		_tick()
		tick_count += 1

	var winner: String
	if player_hp <= 0.0 and enemy_hp <= 0.0:
		winner = "draw"
	elif player_hp <= 0.0:
		winner = "enemy"
	elif enemy_hp <= 0.0:
		winner = "player"
	else:
		# Timeout: compare HP as a % of each side's starting max
		var p_pct := player_hp / maxf(_base_hp(player_grid), 1.0)
		var e_pct := enemy_hp  / maxf(_base_hp(enemy_grid),  1.0)
		if absf(p_pct - e_pct) < 0.10:
			winner = "draw"
		elif p_pct > e_pct:
			winner = "player"
		else:
			winner = "enemy"

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
	# chrono_anchor: owning side's anchor reduces the OPPONENT's paradox gain rate by 20%
	var p_pdx_mult := 0.80 if _has_module(enemy_grid, "chrono_anchor") else 1.0
	var e_pdx_mult := 0.80 if _has_module(player_grid, "chrono_anchor") else 1.0
	_p_paradox.tick(d, rng, p_pdx_mult)
	_e_paradox.tick(d, rng, e_pdx_mult)

	# 2. Heat dissipation
	_p_heat.dissipate(d)
	_e_heat.dissipate(d)

	# repair_drone: regen 1 HP per tick (10 HP/sec), capped at starting max
	if _has_module(player_grid, "repair_drone"):
		player_hp = minf(_base_hp(player_grid), player_hp + 1.0)
	if _has_module(enemy_grid, "repair_drone"):
		enemy_hp = minf(_base_hp(enemy_grid), enemy_hp + 1.0)

	# overdrive_vent: dump all quadrant heat when any quadrant hits disable threshold (costs 15 HP)
	if _has_module(player_grid, "overdrive_vent"):
		for q in range(4):
			if _p_heat.quadrant_heat[q] >= HeatSystem.DISABLE_THRESHOLD:
				_p_heat.quadrant_heat = [0.0, 0.0, 0.0, 0.0]
				player_hp = maxf(0.0, player_hp - 15.0)
				_log("overdrive_vent", true, {})
				break
	if _has_module(enemy_grid, "overdrive_vent"):
		for q in range(4):
			if _e_heat.quadrant_heat[q] >= HeatSystem.DISABLE_THRESHOLD:
				_e_heat.quadrant_heat = [0.0, 0.0, 0.0, 0.0]
				enemy_hp = maxf(0.0, enemy_hp - 15.0)
				_log("overdrive_vent", false, {})
				break

	# 3. Recoil decay
	_p_physics.decay_displacement(d)
	_e_physics.decay_displacement(d)

	# 4. Advance all timer maps
	_advance_cooldowns(_p_cooldowns, d)
	_advance_cooldowns(_e_cooldowns, d)
	_advance_cooldowns(_p_burst_ready, d)
	_advance_cooldowns(_e_burst_ready, d)
	_advance_cooldowns(_p_emp_locks, d)
	_advance_cooldowns(_e_emp_locks, d)

	# Re-enable EMP-locked modules whose timer just expired
	_release_emp_locks(player_grid, _p_emp_locks)
	_release_emp_locks(enemy_grid,  _e_emp_locks)

	# Decay timeline_split active windows
	_p_timeline_active = maxf(0.0, _p_timeline_active - d)
	_e_timeline_active = maxf(0.0, _e_timeline_active - d)

	# Entropy Field: every 10 ticks (1 s) debuff opponent weapon damage by 15% (floor 0.3×)
	if _has_module(player_grid, "entropy_field"):
		_e_entropy_cd -= 1
		if _e_entropy_cd <= 0:
			_e_dmg_mult = maxf(0.3, _e_dmg_mult * 0.85)
			_e_entropy_cd = 10
			_log("entropy_field", true, {"enemy_dmg_mult": snappedf(_e_dmg_mult, 0.01)})
	if _has_module(enemy_grid, "entropy_field"):
		_p_entropy_cd -= 1
		if _p_entropy_cd <= 0:
			_p_dmg_mult = maxf(0.3, _p_dmg_mult * 0.85)
			_p_entropy_cd = 10
			_log("entropy_field", false, {"player_dmg_mult": snappedf(_p_dmg_mult, 0.01)})

	# Update 2-second shield snapshot (every 20 ticks = 2 s)
	if tick_count % 20 == 0:
		_p_shield_snap = player_shield
		_e_shield_snap = enemy_shield

	# 5. Fire weapons
	for mod in player_grid.get_all_modules():
		if mod.category == Module.Category.WEAPON and not mod.disabled:
			_fire_weapon(mod, true)

	for mod in enemy_grid.get_all_modules():
		if mod.category == Module.Category.WEAPON and not mod.disabled:
			_fire_weapon(mod, false)

	# 6. Snapshot for replay
	_log_tick_state()

func _advance_cooldowns(map: Dictionary, delta: float) -> void:
	for key in map.keys():
		map[key] = maxf(0.0, map[key] - delta)

func _release_emp_locks(grid: MechGrid, locks: Dictionary) -> void:
	var expired: Array = []
	for mod_id in locks.keys():
		if locks[mod_id] <= 0.0:
			expired.append(mod_id)
	for mod_id in expired:
		var mod := _find_module(grid, mod_id)
		if mod != null:
			mod.disabled = false
			_log("emp_unlock", grid == player_grid, {"module": mod_id})
		locks.erase(mod_id)

# ── Weapon firing ──────────────────────────────────────────────────────────

func _fire_weapon(weapon: Module, is_player: bool) -> void:
	var wid := weapon.id

	# Init cooldown slot
	if not _p_cooldowns.has(wid) and is_player:
		_p_cooldowns[wid] = 0.0
	if not _e_cooldowns.has(wid) and not is_player:
		_e_cooldowns[wid] = 0.0

	var cds := _p_cooldowns if is_player else _e_cooldowns
	if cds[wid] > 0.0:
		return

	var grid      := player_grid if is_player else enemy_grid
	var heat      := _p_heat    if is_player else _e_heat
	var physics   := _p_physics if is_player else _e_physics
	var power_sys := _p_power   if is_player else _e_power
	var pos       := grid.get_module_position(weapon)

	# Heat disable check
	if heat.is_disabled_by_heat(pos):
		_log("heat_disable", is_player, {"module": wid})
		return

	# EMP lock check
	var emp_locks := _p_emp_locks if is_player else _e_emp_locks
	if emp_locks.get(wid, 0.0) > 0.0:
		return

	# Build modifiers — per-cell efficiency applies the adjacency bonus
	var raw_ratio  := power_sys.total_generation() / power_sys.total_draw() if power_sys.total_draw() > 0.0 else 1.0
	var power_eff: float = minf(raw_ratio * power_sys.cell_efficiency(pos), PowerSystem.MAX_EFFICIENCY)
	var stability   := physics.stability_modifier()
	var heat_pen    := heat.overheat_penalty(pos)
	var final_stab  := stability * (1.0 - heat_pen)

	# Accuracy penalty from recoil drift and torque
	# future_sight: -15% accuracy penalty on the owning side
	var acc_pen := physics.accuracy_penalty()
	if _has_module(grid, "future_sight"):
		acc_pen = maxf(0.0, acc_pen - 0.15)
	# targeting_jammer: +15% accuracy penalty when firing at the defender
	var opp_grid_j := enemy_grid if is_player else player_grid
	if _has_module(opp_grid_j, "targeting_jammer"):
		acc_pen = minf(1.0, acc_pen + 0.15)

	# AI modifiers
	# targeting_matrix: +10% damage
	var dmg_mult := 1.10 if _has_module(grid, "targeting_matrix") else 1.0
	# burst_logic: 1.4× damage, 2× cooldown
	var burst := _has_module(grid, "burst_logic")
	if burst:
		dmg_mult *= 1.4
	# timeline_split: 2× damage during the 1.5-second active window
	var timeline_active := _p_timeline_active if is_player else _e_timeline_active
	if timeline_active > 0.0:
		dmg_mult *= 2.0
	# entropy_field debuff on this side's output
	var entropy_mult := _p_dmg_mult if is_player else _e_dmg_mult

	# Apply side effects (recoil and heat) before any early-out below
	physics.apply_recoil(weapon)
	heat.add_heat(pos, weapon.heat_gen)

	# Reset cooldown
	var base_cd := 1.0 / weapon.fire_rate if weapon.fire_rate > 0.0 else 9999.0
	cds[wid] = base_cd * (2.0 if burst else 1.0)

	# emp_burst special: lock one random opponent module for 3 s, deal no direct damage
	if wid == "emp_burst":
		var opp_grid  := enemy_grid if is_player else player_grid
		var opp_locks := _e_emp_locks if is_player else _p_emp_locks
		var candidates: Array[Module] = []
		for mod in opp_grid.get_all_modules():
			if not mod.disabled and opp_locks.get(mod.id, 0.0) <= 0.0:
				candidates.append(mod)
		if not candidates.is_empty():
			var target: Module = candidates[rng.randi() % candidates.size()]
			opp_locks[target.id] = 3.0
			target.disabled = true
			_log("emp_lock", is_player, {"module": target.id})
		return

	# Resolve damage
	var damage := DamageResolver.resolve_shot(weapon, power_eff, final_stab, 1.0, rng) \
		* dmg_mult * entropy_mult * (1.0 - acc_pen)

	# Deal damage to the opposing mech
	if is_player:
		_deal_to_enemy(damage, weapon)
	else:
		_deal_to_player(damage, weapon)

	_log("shot", is_player, {
		"module":     wid,
		"damage":     snappedf(damage, 0.01),
		"power_eff":  snappedf(power_eff, 0.01),
		"stability":  snappedf(final_stab, 0.01),
	})

# ── Damage application ─────────────────────────────────────────────────────

func _deal_to_player(raw: float, _source: Module) -> void:
	# future_sight: 10% chance to dodge the incoming shot entirely
	if _has_module(player_grid, "future_sight") and rng.randf() < 0.10:
		_log("dodge", true, {})
		return

	# reactive_armor: 30% burst reduction, once every 3 seconds
	if _has_module(player_grid, "reactive_armor"):
		if _p_burst_ready.get("reactive_armor", 0.0) <= 0.0:
			raw = DamageResolver.apply_reactive_armor(raw)
			_p_burst_ready["reactive_armor"] = 3.0
			_log("reactive_armor", true, {})

	var res := DamageResolver.apply_shield(raw, player_shield, 1.0)
	player_shield = maxf(0.0, player_shield - res.shield_damage)
	player_hp     = maxf(0.0, player_hp     - res.hp_damage)

	# reflective_field: reflect 20% of raw incoming damage back at the attacker
	if _has_module(player_grid, "reflective_field") and raw > 0.0:
		var reflected := raw * 0.20
		enemy_hp = maxf(0.0, enemy_hp - reflected)
		_log("reflect", true, {"reflected": snappedf(reflected, 0.01)})

	# rewind_shield: restore shield to 2-s-ago snapshot on first depletion
	if not _p_rewind_used and player_shield <= 0.0 and _has_module(player_grid, "rewind_shield"):
		player_shield = _p_shield_snap
		_p_rewind_used = true
		_log("rewind_shield", true, {"restored": snappedf(_p_shield_snap, 0.1)})

	# counter_program: retaliate with best available weapon after taking HP damage
	if res.hp_damage > 0.0 and _has_module(player_grid, "counter_program"):
		_counter_shot(true)

func _deal_to_enemy(raw: float, _source: Module) -> void:
	# future_sight: 10% chance to dodge the incoming shot entirely
	if _has_module(enemy_grid, "future_sight") and rng.randf() < 0.10:
		_log("dodge", false, {})
		return

	# reactive_armor: 30% burst reduction, once every 3 seconds
	if _has_module(enemy_grid, "reactive_armor"):
		if _e_burst_ready.get("reactive_armor", 0.0) <= 0.0:
			raw = DamageResolver.apply_reactive_armor(raw)
			_e_burst_ready["reactive_armor"] = 3.0
			_log("reactive_armor", false, {})

	var res := DamageResolver.apply_shield(raw, enemy_shield, 1.0)
	enemy_shield = maxf(0.0, enemy_shield - res.shield_damage)
	enemy_hp     = maxf(0.0, enemy_hp     - res.hp_damage)

	# reflective_field: reflect 20% of raw incoming damage back at the attacker
	if _has_module(enemy_grid, "reflective_field") and raw > 0.0:
		var reflected := raw * 0.20
		player_hp = maxf(0.0, player_hp - reflected)
		_log("reflect", false, {"reflected": snappedf(reflected, 0.01)})

	# rewind_shield: restore shield to 2-s-ago snapshot on first depletion
	if not _e_rewind_used and enemy_shield <= 0.0 and _has_module(enemy_grid, "rewind_shield"):
		enemy_shield = _e_shield_snap
		_e_rewind_used = true
		_log("rewind_shield", false, {"restored": snappedf(_e_shield_snap, 0.1)})

	# counter_program: retaliate with best available weapon after taking HP damage
	if res.hp_damage > 0.0 and _has_module(enemy_grid, "counter_program"):
		_counter_shot(false)

## Fire the highest-damage ready weapon as a counter-program retaliation.
func _counter_shot(is_player: bool) -> void:
	var grid := player_grid if is_player else enemy_grid
	var best: Module = null
	for mod: Module in grid.get_all_modules():
		if mod.category == Module.Category.WEAPON and not mod.disabled and mod.fire_rate > 0.0:
			if best == null or mod.base_damage > best.base_damage:
				best = mod
	if best:
		_fire_weapon(best, is_player)

# ── Paradox overload callback ──────────────────────────────────────────────

func _on_module_disabled(mod: Module, is_player: bool) -> void:
	_log("paradox_overload", is_player, {"module": mod.id})
	# capacitor_bank: explodes on overload, dealing 30 damage to the owning mech
	if mod.id == "capacitor_bank":
		if is_player:
			player_hp = maxf(0.0, player_hp - 30.0)
		else:
			enemy_hp = maxf(0.0, enemy_hp - 30.0)
		_log("capacitor_explosion", is_player, {"damage": 30.0})

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

static func _has_module(grid: MechGrid, module_id: String) -> bool:
	for mod in grid.get_all_modules():
		if mod.id == module_id and not mod.disabled:
			return true
	return false

static func _find_module(grid: MechGrid, module_id: String) -> Module:
	for mod in grid.get_all_modules():
		if mod.id == module_id:
			return mod
	return null
