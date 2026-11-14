# grid_manager.gd - Grid data, flood fill matching, gravity, chain reactions
extends Node

const GRID_WIDTH: int = 10
const GRID_HEIGHT: int = 26
const BUFFER_ROWS: int = 2  # Top buffer for spawning pieces

var grid: Array = []  # 2D array [row][col], each cell is null or {color: int}
var total_score: int = 0
var last_cleared_cells: Array = []  # [{pos: Vector2i, color: int}] for debris animation
var last_gravity_moves: Array = []  # [{col, from_row, to_row, color}] for fall animation

signal blocks_cleared(count: int, chain_level: int)
signal grid_changed
signal game_over

func _ready() -> void:
	_init_grid()

func _init_grid() -> void:
	grid.clear()
	for row in range(GRID_HEIGHT + BUFFER_ROWS):
		var row_data: Array = []
		for col in range(GRID_WIDTH):
			row_data.append(null)
		grid.append(row_data)

func reset_grid() -> void:
	_init_grid()
	total_score = 0
	last_cleared_cells.clear()
	last_gravity_moves.clear()
	emit_signal("grid_changed")

func is_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < GRID_WIDTH and row >= 0 and row < (GRID_HEIGHT + BUFFER_ROWS)

func is_cell_empty(col: int, row: int) -> bool:
	if not is_in_bounds(col, row):
		return false
	return grid[row][col] == null

func get_cell_color(col: int, row: int) -> int:
	if not is_in_bounds(col, row):
		return -1
	if grid[row][col] == null:
		return -1
	return grid[row][col].color

func place_block(col: int, row: int, color: int) -> void:
	if not is_in_bounds(col, row):
		return
	grid[row][col] = {"color": color}
	emit_signal("grid_changed")

func clear_cell(col: int, row: int) -> void:
	if not is_in_bounds(col, row):
		return
	grid[row][col] = null

func find_matches() -> Array:
	# BFS flood fill to find connected components of 3+ same color
	# Returns array of {color: int, cells: Array[Vector2i]}
	var visited: Dictionary = {}
	var matches: Array = []

	for row in range(GRID_HEIGHT + BUFFER_ROWS):
		for col in range(GRID_WIDTH):
			if grid[row][col] == null:
				continue
			var key: String = str(col) + "," + str(row)
			if visited.has(key):
				continue

			var color: int = grid[row][col].color
			var component: Array = []
			var queue: Array = [Vector2i(col, row)]
			visited[key] = true

			while queue.size() > 0:
				var current: Vector2i = queue.pop_front()
				component.append(current)

				var neighbors: Array = [
					Vector2i(current.x + 1, current.y),
					Vector2i(current.x - 1, current.y),
					Vector2i(current.x, current.y + 1),
					Vector2i(current.x, current.y - 1),
				]

				for n in neighbors:
					if not is_in_bounds(n.x, n.y):
						continue
					var nkey: String = str(n.x) + "," + str(n.y)
					if visited.has(nkey):
						continue
					if grid[n.y][n.x] == null:
						continue
					if grid[n.y][n.x].color != color:
						continue
					visited[nkey] = true
					queue.append(n)

			if component.size() >= 3:
				matches.append({"color": color, "cells": component})

	return matches

func clear_matches(matches: Array) -> int:
	var total_cleared: int = 0
	last_cleared_cells.clear()
	for match in matches:
		for cell in match.cells:
			# Capture position and color before clearing for debris animation
			if grid[cell.y][cell.x] != null:
				last_cleared_cells.append({"pos": Vector2i(cell.x, cell.y), "color": grid[cell.y][cell.x].color})
			clear_cell(cell.x, cell.y)
			total_cleared += 1
	emit_signal("grid_changed")
	return total_cleared

func apply_gravity() -> int:
	var max_dist: int = 0
	for col in range(GRID_WIDTH):
		var write_row: int = GRID_HEIGHT + BUFFER_ROWS - 1
		for row in range(GRID_HEIGHT + BUFFER_ROWS - 1, -1, -1):
			if grid[row][col] != null:
				if row != write_row:
					last_gravity_moves.append({
						"col": col, "from_row": row, "to_row": write_row,
						"color": grid[row][col].color
					})
					max_dist = maxi(max_dist, write_row - row)
					grid[write_row][col] = grid[row][col]
					grid[row][col] = null
				write_row -= 1
	emit_signal("grid_changed")
	return max_dist

# Dolu hücrelerin listesi (alev hedefleri için - deste gibi kullanılır)
func get_occupied_cells() -> Array:
	var cells: Array = []
	for row in range(GRID_HEIGHT + BUFFER_ROWS):
		for col in range(GRID_WIDTH):
			if grid[row][col] != null:
				cells.append(Vector2i(col, row))
	return cells

# Tek hücreyi yok eder, yok edilen rengi döndürür (-1: boş/geçersiz)
func destroy_cell(pos: Vector2i) -> int:
	if not is_in_bounds(pos.x, pos.y):
		return -1
	if grid[pos.y][pos.x] == null:
		return -1
	var col: int = grid[pos.y][pos.x].color
	grid[pos.y][pos.x] = null
	last_cleared_cells.append({"pos": pos, "color": col})
	emit_signal("grid_changed")
	return col

# Zincir adımı için puan hesabı (chain 1'den başlar, her adımda çarpan artar)
func chain_score_gain(cleared: int, chain: int) -> int:
	var mult: float = 1.0 + 0.5 * float(chain - 1)
	var gain: int = int(cleared * 10 * mult)
	total_score += gain
	return gain

func find_full_lines() -> Array:
	# Returns array of row indices that are completely filled
	var full_rows: Array = []
	for row in range(GRID_HEIGHT + BUFFER_ROWS):
		var full: bool = true
		for col in range(GRID_WIDTH):
			if grid[row][col] == null:
				full = false
				break
		if full:
			full_rows.append(row)
	return full_rows

func clear_full_lines() -> int:
	var full_rows: Array = find_full_lines()
	if full_rows.size() == 0:
		return 0
	# Capture cleared cells for debris before removing
	for row in full_rows:
		for col in range(GRID_WIDTH):
			if grid[row][col] != null:
				last_cleared_cells.append({"pos": Vector2i(col, row), "color": grid[row][col].color})
	# Record survivor positions (bottom-up per column) before mutation
	var full_set: Dictionary = {}
	for row in full_rows:
		full_set[row] = true
	var old_survivors: Array = []  # [col] -> [{row, color}] bottom-up
	for col in range(GRID_WIDTH):
		var list: Array = []
		for row in range(GRID_HEIGHT + BUFFER_ROWS - 1, -1, -1):
			if not full_set.has(row) and grid[row][col] != null:
				list.append({"row": row, "color": grid[row][col].color})
		old_survivors.append(list)
	# Remove full rows and add empty rows at top
	for row in full_rows:
		grid.remove_at(row)
		var new_row: Array = []
		for col in range(GRID_WIDTH):
			new_row.append(null)
		grid.insert(0, new_row)
	# Pair survivors bottom-up with new positions to record fall animation
	for col in range(GRID_WIDTH):
		var new_list: Array = []
		for row in range(GRID_HEIGHT + BUFFER_ROWS - 1, -1, -1):
			if grid[row][col] != null:
				new_list.append({"row": row, "color": grid[row][col].color})
		var old_list: Array = old_survivors[col]
		if old_list.size() != new_list.size():
			continue  # safety: skip mismatched pairing
		for i in range(old_list.size()):
			if old_list[i].row != new_list[i].row:
				last_gravity_moves.append({
					"col": col, "from_row": old_list[i].row,
					"to_row": new_list[i].row, "color": old_list[i].color
				})
	emit_signal("grid_changed")
	return full_rows.size()

func process_chain_reactions() -> int:
	var chain: int = 0
	var total_score_gain: int = 0
	var chain_multiplier: float = 1.0
	var safety_counter: int = 0

	while true:
		# First check color matches
		var matches: Array = find_matches()
		var cleared: int = 0
		if matches.size() > 0:
			cleared = clear_matches(matches)
			apply_gravity()

		# Satır temizleme (klasik blok oyunları) mekaniği KALDIRILDI — sadece renk eşleşmesi temizler.
		# Tek sıra dolunca patlamaz; oyunu klasik blok oyunlarından farklı ve zorlaştırır.
		var lines: int = 0

		if cleared == 0:
			break

		chain += 1
		var total_cleared: int = cleared
		var score_gain: int = int(total_cleared * 10 * chain_multiplier)
		total_score_gain += score_gain
		total_score += score_gain
		emit_signal("blocks_cleared", total_cleared, chain)

		# Apply gravity after line clear
		if lines > 0:
			apply_gravity()

		chain_multiplier += 0.5

		safety_counter += 1
		if safety_counter > 50:
			push_warning("Chain reaction safety limit reached")
			break

	return total_score_gain

func is_game_over() -> bool:
	# Check if any cell in the buffer zone (top 2 rows) is occupied
	for row in range(BUFFER_ROWS):
		for col in range(GRID_WIDTH):
			if grid[row][col] != null:
				return true
	return false

func get_grid_snapshot() -> Array:
	# Returns a deep copy of the grid for rendering
	var snapshot: Array = []
	for row in range(GRID_HEIGHT + BUFFER_ROWS):
		var row_copy: Array = []
		for col in range(GRID_WIDTH):
			if grid[row][col] == null:
				row_copy.append(null)
			else:
				row_copy.append({"color": grid[row][col].color})
		snapshot.append(row_copy)
	return snapshot
