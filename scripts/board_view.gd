# board_view.gd - Optimized rendering: pre-baked block textures, dirty-flag redraw
extends Node2D

const CELL_SIZE: int = 36
const GRID_WIDTH: int = 10
const GRID_HEIGHT: int = 26
const BUFFER_ROWS: int = 2
const MAX_DEBRIS: int = 120
const DEBRIS_PER_BLOCK: int = 3

var grid_manager: Node
var active_piece: Node

# Animated values
var clear_flash: float = 0.0
var time_accum: float = 0.0

# Debris particles for block destruction animation
var debris: Array = []
var flash_cells: Array = []

# Fall animation for blocks dropped by gravity / line clears
var fall_anims: Array = []

# --- Optimization: pre-rendered block textures per color id ---
var _block_textures: Dictionary = {}
var _needs_redraw: bool = true
# Aktif parça durumu (güvenlik ağı: sinyal kaçarsa da ekran güncellensin)
var _last_piece_pos: Vector2i = Vector2i(-999, -999)
var _last_piece_rot: int = -1
var _last_piece_active: bool = false

func _ready() -> void:
	pass

func init(grid_mgr: Node, active: Node) -> void:
	grid_manager = grid_mgr
	active_piece = active
	if grid_manager:
		grid_manager.grid_changed.connect(_on_grid_changed)
		grid_manager.blocks_cleared.connect(_on_blocks_cleared)
	if active_piece:
		active_piece.piece_moved.connect(_on_piece_moved)
	queue_redraw()

func _on_piece_moved() -> void:
	_needs_redraw = true

func _on_grid_changed() -> void:
	if grid_manager and grid_manager.last_gravity_moves.size() > 0:
		for mv in grid_manager.last_gravity_moves:
			_start_fall(mv)
		grid_manager.last_gravity_moves.clear()
	# Drop animations whose target block no longer matches (cleared in chain / reset)
	var i: int = fall_anims.size() - 1
	while i >= 0:
		var a = fall_anims[i]
		if a.to_row >= GRID_HEIGHT + BUFFER_ROWS or grid_manager.get_cell_color(a.col, a.to_row) != a.color:
			fall_anims.remove_at(i)
		i -= 1
	_needs_redraw = true
	queue_redraw()

func _start_fall(mv: Dictionary) -> void:
	var col: int = mv.col
	var to_row: int = mv.to_row
	if to_row < BUFFER_ROWS:
		return
	var start_row: float = float(mv.from_row)
	for j in range(fall_anims.size()):
		var a = fall_anims[j]
		if a.col == col and a.to_row == mv.from_row:
			start_row = _anim_current_row(a)
			fall_anims.remove_at(j)
			break
	var dist: float = float(to_row) - start_row
	if dist <= 0.0:
		return
	fall_anims.append({
		"col": col, "to_row": to_row, "from_row": start_row,
		"color": mv.color, "t": 0.0,
		"dur": clampf(0.10 + dist * 0.045, 0.12, 0.5),
	})

func _anim_current_row(a: Dictionary) -> float:
	var p: float = clampf(a.t / a.dur, 0.0, 1.0)
	p = p * p
	return lerpf(a.from_row, float(a.to_row), p)

func _on_blocks_cleared(_count: int, _chain: int) -> void:
	clear_flash = 1.0
	if grid_manager and grid_manager.last_cleared_cells.size() > 0:
		for cell in grid_manager.last_cleared_cells:
			_spawn_debris(cell.pos, cell.color)
		grid_manager.last_cleared_cells.clear()
	_needs_redraw = true
	queue_redraw()

func _spawn_debris(grid_pos: Vector2i, color_id: int) -> void:
	if debris.size() >= MAX_DEBRIS:
		return
	var screen_row: int = grid_pos.y - BUFFER_ROWS
	var cx: float = grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5
	var cy: float = screen_row * CELL_SIZE + CELL_SIZE * 0.5
	var base_color: Color = Piece.get_color_rgb(color_id)

	for i in range(DEBRIS_PER_BLOCK):
		var angle: float = randf() * TAU
		var speed: float = randf_range(80.0, 200.0)
		debris.append({
			"pos": Vector2(cx, cy) + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed - 60.0),
			"color": base_color,
			"life": randf_range(0.4, 0.7),
			"max_life": 0.7,
			"size": randf_range(3.0, 7.0),
		})

	flash_cells.append({"pos": Vector2i(grid_pos.x, grid_pos.y), "life": 0.25})

func _process(delta: float) -> void:
	var animating: bool = false

	if clear_flash > 0.0:
		clear_flash = maxf(0.0, clear_flash - delta * 3.0)
		animating = true

	if debris.size() > 0:
		animating = true
		var i: int = debris.size() - 1
		while i >= 0:
			var d = debris[i]
			d.life -= delta
			if d.life <= 0.0:
				debris.remove_at(i)
			else:
				d.vel.y += 300.0 * delta
				d.pos += d.vel * delta
			i -= 1

	if flash_cells.size() > 0:
		animating = true
		var j: int = flash_cells.size() - 1
		while j >= 0:
			flash_cells[j].life -= delta
			if flash_cells[j].life <= 0.0:
				flash_cells.remove_at(j)
			j -= 1

	if fall_anims.size() > 0:
		animating = true
		var k: int = fall_anims.size() - 1
		while k >= 0:
			fall_anims[k].t += delta
			if fall_anims[k].t >= fall_anims[k].dur:
				fall_anims.remove_at(k)
			k -= 1

	# Sadece gerçekten değişim varsa yeniden çiz (eski sürüm her karede çiziyordu)
	# Aktif parçanın konumu/dönüşü değiştiyse mutlaka çiz (sinyal kaçsa bile)
	if active_piece:
		var changed: bool = false
		if active_piece.grid_pos != _last_piece_pos:
			changed = true
		if active_piece.rot_state != _last_piece_rot:
			changed = true
		if active_piece.is_active != _last_piece_active:
			changed = true
		if changed:
			_last_piece_pos = active_piece.grid_pos
			_last_piece_rot = active_piece.rot_state
			_last_piece_active = active_piece.is_active
			_needs_redraw = true

	if animating or _needs_redraw:
		_needs_redraw = false
		queue_redraw()

# --- Pre-baked block texture: tek çizim çağrısıyla 3D görünümlü blok ---
func _get_block_texture(color_id: int) -> Texture2D:
	if _block_textures.has(color_id):
		return _block_textures[color_id]

	var s: int = CELL_SIZE
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var base: Color = Piece.get_color_rgb(color_id)
	var light: Color = Piece.get_color_light(color_id)
	var dark: Color = Piece.get_color_dark(color_id)
	var bevel: int = 5
	var radius: float = 5.0
	var x0: float = 1.0
	var y0: float = 1.0
	var x1: float = float(s) - 1.0
	var y1: float = float(s) - 1.0

	for y in range(s):
		for x in range(s):
			var fx: float = x + 0.5
			var fy: float = y + 0.5
			# Yuvarlatılmış köşe maskesi
			var cx: float = clampf(fx, x0 + radius, x1 - radius)
			var cy: float = clampf(fy, y0 + radius, y1 - radius)
			var dx: float = fx - cx
			var dy: float = fy - cy
			if dx * dx + dy * dy > radius * radius:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var col: Color = base
			if x == 0 or y == 0 or x == s - 1 or y == s - 1:
				col = base.lerp(dark, 0.9)
			elif y <= bevel - 2:
				col = base.lerp(light, 0.85)
			elif y <= bevel + 1:
				col = base.lerp(light, 0.45)
			elif y >= s - bevel:
				col = base.lerp(dark, 0.75)
			elif y >= s - bevel + 1:
				col = base.lerp(dark, 0.5)
			elif x <= 3:
				col = base.lerp(light, 0.4)
			elif x >= s - 4:
				col = base.lerp(dark, 0.5)

			# Parlak nokta
			var gdx: float = fx - (bevel + 2.5)
			var gdy: float = fy - (bevel + 2.5)
			if gdx * gdx + gdy * gdy < 9.0:
				col = col.lerp(light, 0.5)

			img.set_pixel(x, y, col)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_block_textures[color_id] = tex
	return tex

func _draw_block(px: float, py: float, color_id: int, alpha: float = 1.0) -> void:
	var tex: Texture2D = _get_block_texture(color_id)
	draw_texture_rect(tex, Rect2(px, py, CELL_SIZE, CELL_SIZE), false, Color(1, 1, 1, alpha))

# Draw ghost piece at landing position
func _draw_ghost_piece() -> void:
	if not active_piece or not active_piece.is_active:
		return

	var ghost_pos: Vector2i = active_piece.grid_pos
	var shape: Array = active_piece.get_shape()

	while true:
		var can_drop: bool = true
		for offset in shape:
			var v: Vector2i = offset
			var col: int = ghost_pos.x + v.x
			var row: int = ghost_pos.y + 1 + v.y
			if col < 0 or col >= GRID_WIDTH or row >= GRID_HEIGHT + BUFFER_ROWS:
				can_drop = false
				break
			if row >= 0 and not grid_manager.is_cell_empty(col, row):
				can_drop = false
				break
		if can_drop:
			ghost_pos.y += 1
		else:
			break

	if ghost_pos.y == active_piece.grid_pos.y:
		return

	var colors: Array = active_piece.piece_data.colors
	var alpha: float = 0.24

	for i in range(shape.size()):
		var v: Vector2i = shape[i]
		var col: int = ghost_pos.x + v.x
		var row: int = ghost_pos.y + v.y
		var screen_row: int = row - BUFFER_ROWS
		if screen_row >= 0 and screen_row < GRID_HEIGHT and col >= 0 and col < GRID_WIDTH:
			var color_id: int = colors[i] if i < colors.size() else colors[0]
			var px: float = col * CELL_SIZE
			var py: float = screen_row * CELL_SIZE
			_draw_block(px, py, color_id, alpha)

func _draw() -> void:
	if not grid_manager:
		return

	var total_w: float = float(GRID_WIDTH * CELL_SIZE)
	var total_h: float = float(GRID_HEIGHT * CELL_SIZE)

	# Arka plan
	draw_rect(Rect2(0, 0, total_w, total_h), Color(0.05, 0.05, 0.09, 1.0))

	if clear_flash > 0.0:
		draw_rect(Rect2(0, 0, total_w, total_h), Color(1, 1, 1, clear_flash * 0.18))

	_draw_ghost_piece()

	# Animasyonlu hücreleri atla
	var animating: Dictionary = {}
	for a in fall_anims:
		animating[Vector2i(a.col, a.to_row)] = true

	# Doğrudan grid'e eriş (derin kopya yok — performans)
	var grid: Array = grid_manager.grid
	for row in range(BUFFER_ROWS, GRID_HEIGHT + BUFFER_ROWS):
		var row_data: Array = grid[row]
		for col in range(GRID_WIDTH):
			var cell = row_data[col]
			if cell != null:
				if animating.has(Vector2i(col, row)):
					continue
				_draw_block(col * CELL_SIZE, (row - BUFFER_ROWS) * CELL_SIZE, cell.color)

	for a in fall_anims:
		var cur_row: float = _anim_current_row(a)
		var screen_y: float = (cur_row - float(BUFFER_ROWS)) * CELL_SIZE
		if screen_y + CELL_SIZE < 0.0:
			continue
		_draw_block(a.col * CELL_SIZE, screen_y, a.color)

	for fc in flash_cells:
		var f_alpha: float = fc.life / 0.25
		var f_screen_row: int = fc.pos.y - BUFFER_ROWS
		if f_screen_row >= 0:
			draw_rect(Rect2(fc.pos.x * CELL_SIZE, f_screen_row * CELL_SIZE, CELL_SIZE, CELL_SIZE),
				Color(1, 1, 1, f_alpha * 0.6))

	if active_piece and active_piece.is_active:
		var colored_cells: Array = active_piece.get_colored_cells()
		for cell in colored_cells:
			var pos: Vector2i = cell.pos
			var screen_row: int = pos.y - BUFFER_ROWS
			if screen_row >= 0 and screen_row < GRID_HEIGHT and pos.x >= 0 and pos.x < GRID_WIDTH:
				_draw_block(pos.x * CELL_SIZE, screen_row * CELL_SIZE, cell.color)

	# Debris — basit kareler (döndürme yok, çok daha ucuz)
	for d in debris:
		var d_alpha: float = clampf(d.life / d.max_life, 0.0, 1.0)
		var d_color: Color = d.color
		d_color.a = d_alpha
		var dsize: float = d.size
		draw_rect(Rect2(d.pos.x - dsize * 0.5, d.pos.y - dsize * 0.5, dsize, dsize), d_color)

	draw_rect(Rect2(0, 0, total_w, total_h), Color(0.30, 0.33, 0.45, 1.0), false, 2.0)
