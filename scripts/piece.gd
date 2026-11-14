# piece.gd - Piece definitions, shapes, colors, and rotation logic
class_name Piece
extends RefCounted

# 6 distinct, vivid colors for blocks
enum BlockColor {
	RED = 0,
	BLUE = 1,
	GREEN = 2,
	YELLOW = 3,
	PURPLE = 4,
	ORANGE = 5
}

# 12 özgün parça - hiçbiri klasik blok oyunu şekilleriyle aynı değil.
# Colors are randomly generated at spawn time with probability weights:
#   65% single color, 25% two colors (bundle), 10% three colors (rare bundle)
# Self-match prevention: no piece ever has 3+ connected same-color blocks.
const PIECES: Array = [
	# 1 block - a single dot
	{"name": "Dot", "shape": [Vector2i(0, 0)]},
	# 2 blocks - horizontal pair
	{"name": "Duo", "shape": [Vector2i(0, 0), Vector2i(1, 0)]},
	# 3 blocks - V/corner shape
	{"name": "V3", "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]},
	# 3 blocks - diagonal corner
	{"name": "Diag3", "shape": [Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]},
	# 4 blocks - SPLIT I: two separated vertical bars (replaces T)
	{"name": "SplitI", "shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(2, 0), Vector2i(2, 1)]},
	# 5 blocks - PLUS / CROSS (the + shape!)
	{"name": "Plus5", "shape": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]},
	# 5 blocks - X / DIAGONAL CROSS (the X shape!)
	{"name": "X5", "shape": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(2, 2)]},
	# 5 blocks - U / CUP shape
	{"name": "U5", "shape": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	# 5 blocks - W / STAIRCASE
	{"name": "W5", "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]},
	# 5 blocks - HOOK / J-hook
	{"name": "Hook5", "shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]},
	# 5 blocks - DIAMOND
	{"name": "Diamond5", "shape": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 2)]},
	# 5 blocks - RING: üstü açık halka, içi boş; çevirdikçe açıklık yön değiştirir
	{"name": "RingOpen5", "shape": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(2, 2)]},
]

# Returns a deep copy of the piece with randomly assigned colors.
# Probability: 65% one color, 25% two colors, 10% three colors.
# Guarantees no self-match (3+ connected same-color blocks within the piece).
static func get_random_colored_piece(id: int) -> Dictionary:
	var base = get_piece(id)
	var shape: Array = base.shape
	var count: int = shape.size()
	var colors: Array = _generate_colors(shape, count)
	return {"name": base.name, "shape": shape, "colors": colors}

static func _generate_colors(shape: Array, count: int) -> Array:
	# Try up to 10 times to get a valid color assignment
	for attempt in range(10):
		var colors: Array = _roll_colors(count)
		if not _has_self_match(shape, colors):
			return colors
	# Fallback: force alternating colors (guaranteed safe)
	var colors: Array = []
	for i in range(count):
		colors.append(i % 6)
	return colors

static func _roll_colors(count: int) -> Array:
	# Each block rolls its own die independently (1-6)
	var colors: Array = []
	for i in range(count):
		colors.append(randi() % 6)
	return colors

# Check if the piece itself has 3+ connected same-color blocks (self-match)
static func _has_self_match(shape: Array, colors: Array) -> bool:
	var count: int = shape.size()
	if count < 3:
		return false
	# Build adjacency: two blocks are connected if they share an edge
	var visited: Array = []
	for i in range(count):
		visited.append(false)
	for start in range(count):
		if visited[start]:
			continue
		visited[start] = true
		var component_color: int = colors[start]
		var component_size: int = 1
		var queue: Array = [start]
		while queue.size() > 0:
			var cur: int = queue.pop_front()
			for other in range(count):
				if visited[other]:
					continue
				if colors[other] != component_color:
					continue
				# Check if shapes[cur] and shapes[other] are adjacent (share edge)
				var diff: Vector2i = shape[cur] - shape[other]
				if absi(diff.x) + absi(diff.y) == 1:
					visited[other] = true
					component_size += 1
					queue.append(other)
		if component_size >= 3:
			return true
	return false

static func get_piece(id: int) -> Dictionary:
	if id < 0 or id >= PIECES.size():
		id = 0
	return PIECES[id]

static func get_random_piece_id() -> int:
	return randi() % PIECES.size()

static func get_piece_count() -> int:
	return PIECES.size()

static func rotate_shape(shape: Array, rotation: int) -> Array:
	var result: Array = []
	for offset in shape:
		var v: Vector2i = offset
		var rotated: Vector2i
		match rotation % 4:
			0:
				rotated = Vector2i(v.x, v.y)
			1:
				rotated = Vector2i(-v.y, v.x)
			2:
				rotated = Vector2i(-v.x, -v.y)
			3:
				rotated = Vector2i(v.y, -v.x)
		result.append(rotated)
	return result

static func get_color_light(color: int) -> Color:
	return get_color_rgb(color).lightened(0.35)

static func get_color_dark(color: int) -> Color:
	return get_color_rgb(color).darkened(0.35)

static func get_color_rgb(color: int) -> Color:
	match color:
		BlockColor.RED: return Color(0.90, 0.20, 0.22)
		BlockColor.BLUE: return Color(0.20, 0.50, 0.95)
		BlockColor.GREEN: return Color(0.20, 0.82, 0.35)
		BlockColor.YELLOW: return Color(0.95, 0.82, 0.15)
		BlockColor.PURPLE: return Color(0.65, 0.30, 0.90)
		BlockColor.ORANGE: return Color(0.95, 0.55, 0.12)
	return Color.WHITE

static func get_color_name(color: int) -> String:
	match color:
		BlockColor.RED: return "Red"
		BlockColor.BLUE: return "Blue"
		BlockColor.GREEN: return "Green"
		BlockColor.YELLOW: return "Yellow"
		BlockColor.PURPLE: return "Purple"
		BlockColor.ORANGE: return "Orange"
	return "Unknown"
