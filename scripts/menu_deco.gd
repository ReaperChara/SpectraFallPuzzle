# menu_deco.gd - Ana menü arka plan süsü
# Oyunun GERÇEK parça şekillerini (Plus5, X5, RingOpen5, SplitI, V3...) çizer.
# Amaç: "3 yan yana blok" gibi generic bir görüntü yerine oyunun kendi dilini göstermek.
extends Control

const CELL: float = 46.0

var _textures: Dictionary = {}
var _decor: Array = []
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_layout()
	set_process(true)


func _build_layout() -> void:
	# shape, color, origin, alpha, bob fazı
	_decor = [
		{
			"shape": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
			"color": 5, "origin": Vector2(64, 78), "alpha": 0.60, "phase": 0.0, "scale": 1.0,
		},
		{
			"shape": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(2, 2)],
			"color": 4, "origin": Vector2(452, 84), "alpha": 0.55, "phase": 1.4, "scale": 0.92,
		},
		{
			"shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(2, 0), Vector2i(2, 1)],
			"color": 1, "origin": Vector2(40, 700), "alpha": 0.42, "phase": 2.6, "scale": 0.86,
		},
		{
			"shape": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(2, 2)],
			"color": 2, "origin": Vector2(462, 690), "alpha": 0.45, "phase": 3.9, "scale": 1.0,
		},
		{
			"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
			"color": 0, "origin": Vector2(120, 1030), "alpha": 0.40, "phase": 5.1, "scale": 0.90,
		},
		{
			"shape": [Vector2i(0, 0), Vector2i(1, 0)],
			"color": 3, "origin": Vector2(470, 1040), "alpha": 0.40, "phase": 0.9, "scale": 1.0,
		},
	]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for d in _decor:
		var shape: Array = d["shape"]
		var color_id: int = d["color"]
		var origin: Vector2 = d["origin"]
		var alpha: float = d["alpha"]
		var sc: float = d["scale"]
		var bob: float = sin(_t * 0.7 + float(d["phase"])) * 5.0
		var cell: float = CELL * sc
		var tex: Texture2D = _get_block_texture(color_id)
		for v in shape:
			var pos: Vector2 = origin + Vector2(float(v.x), float(v.y)) * cell + Vector2(0.0, bob)
			draw_texture_rect(tex, Rect2(pos, Vector2(cell, cell)), false, Color(1, 1, 1, alpha))


func _get_block_texture(color_id: int) -> Texture2D:
	if _textures.has(color_id):
		return _textures[color_id]

	var s: int = 48
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var base: Color = Piece.get_color_rgb(color_id)
	var light: Color = Piece.get_color_light(color_id)
	var dark: Color = Piece.get_color_dark(color_id)
	var bevel: int = 6
	var radius: float = 7.0
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
			elif x <= 3:
				col = base.lerp(light, 0.4)
			elif x >= s - 4:
				col = base.lerp(dark, 0.5)
			img.set_pixel(x, y, col)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_textures[color_id] = tex
	return tex
