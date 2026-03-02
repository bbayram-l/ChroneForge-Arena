## MechGrid — 6×6 grid that holds a mech's modules.
## Pure data layer; no visual coupling.
class_name MechGrid
extends RefCounted

const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 6

var owner_id: String = ""
# cells[y][x] → GridCell
var cells: Array = []

func _init(p_owner_id: String = "") -> void:
	owner_id = p_owner_id
	_init_cells()

func _init_cells() -> void:
	cells = []
	for y in range(GRID_HEIGHT):
		var row: Array[GridCell] = []
		for x in range(GRID_WIDTH):
			row.append(GridCell.new(Vector2i(x, y)))
		cells.append(row)

# ── Accessors ──────────────────────────────────────────────────────────────

func get_cell(pos: Vector2i) -> GridCell:
	if not _in_bounds(pos):
		return null
	return cells[pos.y][pos.x]

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT

# ── Placement ──────────────────────────────────────────────────────────────

func can_place(pos: Vector2i, mod: Module) -> bool:
	for dy in range(mod.grid_size.y):
		for dx in range(mod.grid_size.x):
			var p := Vector2i(pos.x + dx, pos.y + dy)
			if not _in_bounds(p) or not get_cell(p).is_empty():
				return false
	return true

func place_module(pos: Vector2i, mod: Module) -> bool:
	if not can_place(pos, mod):
		return false
	for dy in range(mod.grid_size.y):
		for dx in range(mod.grid_size.x):
			get_cell(Vector2i(pos.x + dx, pos.y + dy)).place_module(mod)
	return true

func remove_module_at(pos: Vector2i) -> Module:
	var cell := get_cell(pos)
	if cell == null or cell.is_empty():
		return null
	var mod := cell.module
	# Clear every cell that references this module
	for row in cells:
		for c: GridCell in row:
			if c.module == mod:
				c.remove_module()
	return mod

# ── Queries ────────────────────────────────────────────────────────────────

func get_adjacent_cells(pos: Vector2i) -> Array[GridCell]:
	var result: Array[GridCell] = []
	for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var cell := get_cell(pos + dir)
		if cell != null:
			result.append(cell)
	return result

func get_adjacent_modules(pos: Vector2i) -> Array[Module]:
	var result: Array[Module] = []
	for cell in get_adjacent_cells(pos):
		if not cell.is_empty() and cell.module not in result:
			result.append(cell.module)
	return result

func get_all_modules() -> Array[Module]:
	var result: Array[Module] = []
	for row in cells:
		for cell: GridCell in row:
			if not cell.is_empty() and cell.module not in result:
				result.append(cell.module)
	return result

func get_module_position(mod: Module) -> Vector2i:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if cells[y][x].module == mod:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

# ── Serialization (async PvP / replay) ────────────────────────────────────

func serialize() -> Dictionary:
	var placed: Array = []
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: GridCell = cells[y][x]
			if not cell.is_empty():
				var already_logged := false
				for entry in placed:
					if entry.module_id == cell.module.id and entry.pos == [x, y]:
						already_logged = true
						break
				if not already_logged:
					placed.append({"pos": [x, y], "module_id": cell.module.id})
	return {"owner": owner_id, "cells": placed}

static func deserialize(data: Dictionary) -> MechGrid:
	var grid := MechGrid.new(data.get("owner", ""))
	for entry in data.get("cells", []):
		var pos := Vector2i(entry.pos[0], entry.pos[1])
		var mod: Module = ModuleRegistry.get_module(entry.module_id)
		if mod != null:
			grid.place_module(pos, mod)
	return grid
