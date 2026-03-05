## Logger — session log writer for balance analysis.
##
## Writes one JSON Lines file per play session to:
##   user://game_logs/session_YYYYMMDD_HHmmss.jsonl
##
## Each line is a self-contained JSON object. Event types:
##   run_start    — archetype chosen, version
##   round_start  — grid snapshot (all module IDs + positions + stars)
##   combat_result— outcome, ticks, HP%, damage, events, synergies
##   run_end      — rounds/wins/losses/MMR summary
##
## Usage (all calls are optional — missing any is safe):
##   Logger.open_session()                      # called automatically on first log
##   Logger.log_run_start(archetype)
##   Logger.log_round_start(round, gold, player_grid, enemy_grid)
##   Logger.log_combat_result(round, gold_after, result)
##   Logger.log_run_end(rounds, wins, losses, mmr)
extends Node

var _file:    FileAccess = null
var _path:    String     = ""
var _version: String     = ""

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_version = _read_version()
	open_session()

func open_session() -> void:
	if _file != null:
		return  # already open
	DirAccess.make_dir_recursive_absolute("user://game_logs")
	var dt    := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"],
	]
	_path = "user://game_logs/session_%s.jsonl" % stamp
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		push_warning("[Logger] Failed to open log file: %s" % _path)
	else:
		print("[Logger] Session log: %s" % _path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_close()

func _close() -> void:
	if _file != null:
		_file.close()
		_file = null

# ── Public API ───────────────────────────────────────────────────────────────

func log_run_start(archetype: String) -> void:
	_write({
		"type":      "run_start",
		"ts":        _iso_now(),
		"version":   _version,
		"archetype": archetype,
	})

func log_round_start(round: int, gold: int, player_grid: MechGrid, enemy_grid: MechGrid) -> void:
	_write({
		"type":            "round_start",
		"round":           round,
		"gold_before":     gold,
		"player_modules":  _grid_snapshot(player_grid),
		"enemy_modules":   _grid_snapshot(enemy_grid),
	})

func log_combat_result(round: int, gold_after: int, result: Dictionary) -> void:
	var ev_log: Array = result.get("event_log", [])
	var stats := _parse_event_log(ev_log)
	var p_init: float = maxf(result.get("player_hp_initial", 1.0), 1.0)
	var e_init: float = maxf(result.get("enemy_hp_initial",  1.0), 1.0)
	_write({
		"type":             "combat_result",
		"round":            round,
		"outcome":          result.get("winner", "?"),
		"ticks":            result.get("ticks", 0),
		"duration_s":       snappedf(result.get("duration_seconds", 0.0), 0.01),
		"player_hp_pct":    snappedf(result.get("player_hp_remaining", 0.0) / p_init, 0.001),
		"enemy_hp_pct":     snappedf(result.get("enemy_hp_remaining",  0.0) / e_init, 0.001),
		"gold_after":       gold_after,
		"dmg_dealt":        snappedf(stats.p_dmg,   0.1),
		"dmg_taken":        snappedf(stats.e_dmg,   0.1),
		"shots_fired":      stats.p_shots,
		"shots_received":   stats.e_shots,
		"overloads":        stats.overloads,
		"heat_disables":    stats.heat_disables,
		"keyword_stacks":   stats.keyword_stacks,
		"notable_events":   stats.notable,
	})

func log_run_end(rounds: int, wins: int, losses: int, mmr: int) -> void:
	_write({
		"type":             "run_end",
		"ts":               _iso_now(),
		"rounds_survived":  rounds,
		"wins":             wins,
		"losses":           losses,
		"final_mmr":        mmr,
	})
	# Keep file open so subsequent restarts within the same session append cleanly.
	# File is closed on process exit via _notification.

# ── Helpers ──────────────────────────────────────────────────────────────────

func _write(obj: Dictionary) -> void:
	if _file == null:
		open_session()
	if _file == null:
		return
	_file.store_line(JSON.stringify(obj))

func _grid_snapshot(grid: MechGrid) -> Array:
	var out: Array = []
	for mod in grid.get_all_modules():
		var pos := grid.get_module_position(mod)
		out.append({
			"id":   mod.id,
			"cat":  Module.Category.keys()[mod.category],
			"rar":  Module.Rarity.keys()[mod.rarity],
			"star": mod.star_level,
			"pos":  [pos.x, pos.y],
		})
	return out

func _parse_event_log(log: Array) -> Dictionary:
	var p_dmg      := 0.0
	var e_dmg      := 0.0
	var p_shots    := 0
	var e_shots    := 0
	var overloads  := 0
	var heat_dis   := 0
	var burn_peak  := 0
	var crack_peak := 0
	var notable:   Array[String] = []

	for entry: Dictionary in log:
		var t:     String = entry.get("type",  "")
		var actor: String = entry.get("actor", "?")
		var tick:  int    = entry.get("tick",  0)

		match t:
			"shot":
				var d: float = entry.get("damage", 0.0)
				if actor == "player": p_dmg += d; p_shots += 1
				else:                 e_dmg += d; e_shots += 1
			"paradox_overload":
				overloads += 1
				notable.append("t%d %s OVERLOAD [%s]" % [tick, actor, entry.get("module","?")])
			"heat_disable":
				heat_dis += 1
				notable.append("t%d %s heat-disabled [%s]" % [tick, actor, entry.get("module","?")])
			"dodge":
				notable.append("t%d %s dodge" % [tick, actor])
			"emp_lock":
				notable.append("t%d %s EMP→[%s]" % [tick, actor, entry.get("module","?")])
			"reflect":
				notable.append("t%d %s reflect %.0f" % [tick, actor, entry.get("reflected",0.0)])
			"rewind_shield":
				notable.append("t%d %s REWIND" % [tick, actor])
			"capacitor_explosion":
				notable.append("t%d %s CAPACITOR" % [tick, actor])
			"overdrive_vent":
				notable.append("t%d %s VENT" % [tick, actor])
			"reactive_armor":
				notable.append("t%d %s react-armor" % [tick, actor])
			"joint_lock":
				notable.append("t%d %s joint_lock absorbed" % [tick, actor])
			"timeline_split":
				notable.append("t%d %s timeline_split" % [tick, actor])
			"echo_shot":
				notable.append("t%d %s echo_shot" % [tick, actor])
			"burn_apply":
				var stk: int = entry.get("stacks", 0)
				if stk > burn_peak: burn_peak = stk
			"crack_apply":
				var stk: int = entry.get("stacks", 0)
				if stk > crack_peak: crack_peak = stk

	return {
		"p_dmg":   p_dmg,
		"e_dmg":   e_dmg,
		"p_shots": p_shots,
		"e_shots": e_shots,
		"overloads":    overloads,
		"heat_disables": heat_dis,
		"keyword_stacks": {"burn_peak": burn_peak, "crack_peak": crack_peak},
		"notable": notable,
	}

func _iso_now() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"],
	]

func _read_version() -> String:
	const PATH := "res://version.txt"
	if not FileAccess.file_exists(PATH):
		return "?"
	var f := FileAccess.open(PATH, FileAccess.READ)
	var v := f.get_as_text().strip_edges()
	f.close()
	return v
