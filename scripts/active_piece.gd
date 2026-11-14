# active_piece.gd - Active falling piece controller
extends Node2D

var grid_manager: Node
var piece_id: int = 0
var piece_data: Dictionary = {}
var rot_state: int = 0
var grid_pos: Vector2i = Vector2i(4, -2)
var drop_timer: float = 0.0
var is_active: bool = false

signal piece_landed
signal piece_moved

const GRID_WIDTH: int = 10
const GRID_HEIGHT: int = 26
const BUFFER_ROWS: int = 2

func _ready() -> void:
	pass

func init(grid_mgr: Node) -> void:
	grid_manager = grid_mgr

func spawn_new_piece() -> void:
	piece_id = Piece.get_random_piece_id()
	_spawn_at_current()

func spawn_new_piece_with_id(id: int) -> void:
	piece_id = id
	_spawn_at_current()

func _spawn_at_current() -> void:
	piece_data = Piece.get_random_colored_piece(piece_id)
	rot_state = 0
	# Spawn at row 0: just above/at the visible board edge so the piece
	# enters the map almost immediately (top buffer rows are invisible).
	grid_pos = Vector2i(GRID_WIDTH / 2 - 1, 0)
	# If the stack reaches the spawn area, nudge the piece upward
	while grid_pos.y > -4 and not _is_valid_position():
		grid_pos.y -= 1
	is_active = true
	drop_timer = 0.0

func get_shape() -> Array:
	return Piece.rotate_shape(piece_data.shape, rot_state)

# Returns array of {pos: Vector2i, color: int} for each block
func get_colored_cells() -> Array:
	var cells: Array = []
	var shape: Array = get_shape()
	var colors: Array = piece_data.colors
	for i in range(shape.size()):
		var v: Vector2i = shape[i]
		var color: int = colors[i] if i < colors.size() else colors[0]
		cells.append({
			"pos": Vector2i(grid_pos.x + v.x, grid_pos.y + v.y),
			"color": color
		})
	return cells

# Returns just positions (for collision checks)
func get_cells() -> Array:
	var cells: Array = []
	for offset in get_shape():
		var v: Vector2i = offset
		cells.append(Vector2i(grid_pos.x + v.x, grid_pos.y + v.y))
	return cells

func _is_valid_position() -> bool:
	for cell in get_cells():
		if cell.x < 0 or cell.x >= GRID_WIDTH:
			return false
		if cell.y >= GRID_HEIGHT + BUFFER_ROWS:
			return false
		if cell.y >= 0 and not grid_manager.is_cell_empty(cell.x, cell.y):
			return false
	return true

func can_move(dx: int, dy: int) -> bool:
	for cell in get_cells():
		var new_col: int = cell.x + dx
		var new_row: int = cell.y + dy
		if new_col < 0 or new_col >= GRID_WIDTH:
			return false
		if new_row >= GRID_HEIGHT + BUFFER_ROWS:
			return false
		if new_row >= 0 and not grid_manager.is_cell_empty(new_col, new_row):
			return false
	return true

func move_left() -> void:
	if not is_active:
		return
	if can_move(-1, 0):
		grid_pos.x -= 1
		emit_signal("piece_moved")

func move_right() -> void:
	if not is_active:
		return
	if can_move(1, 0):
		grid_pos.x += 1
		emit_signal("piece_moved")

func move_down() -> bool:
	if not is_active:
		return false
	if can_move(0, 1):
		grid_pos.y += 1
		emit_signal("piece_moved")
		return true
	return false

# Hücre kümesinin ağırlık merkezi (taşın kendi ekseni)
func _cells_center(cells: Array) -> Vector2:
	if cells.is_empty():
		return Vector2(grid_pos)
	var sum: Vector2 = Vector2.ZERO
	for c in cells:
		sum += Vector2(c)
	return sum / float(cells.size())

func rotate_piece() -> void:
	if not is_active:
		return
	var old_rot: int = rot_state
	var old_center: Vector2 = _cells_center(get_cells())
	var old_pos: Vector2i = grid_pos

	rot_state = (rot_state + 1) % 4
	# Taş köşeden değil kendi merkezinden dönüyormuş gibi görünsün:
	# dönüş sonrası merkez aynı yerde kalsın diye konumu telafi et.
	var new_center: Vector2 = _cells_center(get_cells())
	var shift: Vector2i = Vector2i(
		roundi(old_center.x - new_center.x),
		roundi(old_center.y - new_center.y))
	grid_pos += shift

	if not _is_valid_position():
		# Merkez korumalı hâli çakışıyorsa yatay kick dene
		for kick in [-1, 1, -2, 2]:
			grid_pos.x += kick
			if _is_valid_position():
				emit_signal("piece_moved")
				return
			grid_pos.x -= kick
		# Hiçbiri olmuyorsa eski hâle dön
		rot_state = old_rot
		grid_pos = old_pos
		return
	# Dönüş geçerliyse de görsel güncellensin (kick gerekmediği durum)
	emit_signal("piece_moved")

func hard_drop() -> void:
	if not is_active:
		return
	while can_move(0, 1):
		grid_pos.y += 1
	land()

func land() -> void:
	if not is_active:
		return
	is_active = false
	# Place each block with its own color
	for cell in get_colored_cells():
		if cell.pos.y >= 0:
			grid_manager.place_block(cell.pos.x, cell.pos.y, cell.color)
	emit_signal("piece_landed")

func _process(delta: float) -> void:
	if not is_active or not GameManager.is_playing():
		return
	drop_timer += delta
	var interval: float = GameManager.get_drop_interval()
	if drop_timer >= interval:
		drop_timer = 0.0
		if not move_down():
			land()
