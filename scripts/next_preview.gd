# next_preview.gd - Draws a mini preview of the next piece
extends Node2D

var piece_data: Dictionary = {}
const MINI_CELL: int = 16

func set_piece(data: Dictionary) -> void:
	piece_data = data

func _draw() -> void:
	if piece_data.is_empty():
		return
	var shape: Array = piece_data.shape
	var colors: Array = piece_data.colors

	# Find bounds of the shape
	var min_x: int = 999
	var max_x: int = -999
	var min_y: int = 999
	var max_y: int = -999
	for offset in shape:
		var v: Vector2i = offset
		min_x = mini(min_x, v.x)
		max_x = maxi(max_x, v.x)
		min_y = mini(min_y, v.y)
		max_y = maxi(max_y, v.y)

	var shape_w: int = max_x - min_x + 1
	var shape_h: int = max_y - min_y + 1
	# Center the shape in the preview area
	var ox: float = -shape_w * MINI_CELL * 0.5
	var oy: float = -shape_h * MINI_CELL * 0.5

	for i in range(shape.size()):
		var v: Vector2i = shape[i]
		var color_id: int = colors[i] if i < colors.size() else colors[0]
		var px: float = ox + (v.x - min_x) * MINI_CELL
		var py: float = oy + (v.y - min_y) * MINI_CELL
		var base_color: Color = Piece.get_color_rgb(color_id)
		var light_color: Color = Piece.get_color_light(color_id)
		var dark_color: Color = Piece.get_color_dark(color_id)

		# Mini block with simple 3D effect
		draw_rect(Rect2(px + 1, py + 1, MINI_CELL - 2, MINI_CELL - 2), base_color)
		draw_rect(Rect2(px + 1, py + 1, MINI_CELL - 2, 3), light_color)
		draw_rect(Rect2(px + 1, py + MINI_CELL - 4, MINI_CELL - 2, 3), dark_color)
		draw_rect(Rect2(px + 1, py + 1, MINI_CELL - 2, MINI_CELL - 2), dark_color, false, 1.0)
