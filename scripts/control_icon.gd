# control_icon.gd - Mobil kontrol tuşlarının sembol çizimi
# Düz klavye glifi yerine bevel/parlaklık katmanlı, dokulu semboller çizer.
extends Control

@export var mode: String = "left"
@export var accent: Color = Color(0.35, 0.80, 1.00)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s: Vector2 = size
	# --- Tuş dokusu: üst gloss + alt gölge bandı ---
	draw_rect(Rect2(7.0, 4.0, s.x - 14.0, s.y * 0.30), Color(1, 1, 1, 0.05))
	draw_rect(Rect2(7.0, s.y - s.y * 0.24, s.x - 14.0, s.y * 0.24), Color(0, 0, 0, 0.10))

	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.5)
	var col: Color = accent.lightened(0.40)
	match mode:
		"left":
			_hchevron(c + Vector2(6, -2), 26.0, 40.0, 7.5, -1, col)
			_hchevron(c + Vector2(-12, -2), 26.0, 40.0, 7.5, -1, col)
		"right":
			_hchevron(c + Vector2(-6, -2), 26.0, 40.0, 7.5, 1, col)
			_hchevron(c + Vector2(12, -2), 26.0, 40.0, 7.5, 1, col)
		"down":
			_soft_down(c, col)
		"drop":
			_drop(c, col)
		"rotate":
			_rotate(c, col)


func _vchevron(c: Vector2, w: float, h: float, th: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-w * 0.5, -h * 0.5),
		c + Vector2(0.0, h * 0.42),
		c + Vector2(w * 0.5, -h * 0.5),
	])
	_draw_beveled_polyline(pts, th, col)


func _hchevron(c: Vector2, w: float, h: float, th: float, dir: int, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-dir * w * 0.5, -h * 0.5),
		c + Vector2(dir * w * 0.42, 0.0),
		c + Vector2(-dir * w * 0.5, h * 0.5),
	])
	_draw_beveled_polyline(pts, th, col)


func _draw_beveled_polyline(pts: PackedVector2Array, th: float, col: Color) -> void:
	# 1) alt gölge
	var shadow: PackedVector2Array = PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0.0, 3.5))
	draw_polyline(shadow, Color(0, 0, 0, 0.50), th, true)
	# 2) ana gövde
	draw_polyline(pts, col, th, true)
	# eklem yerlerini yuvarlat (polyline köşeleri boşluk bırakmasın)
	for p in pts:
		draw_circle(p, th * 0.5, col)
	# 3) üst kenar parlaklığı
	var hi: PackedVector2Array = PackedVector2Array()
	for p in pts:
		hi.append(p + Vector2(-1.0, -1.6))
	draw_polyline(hi, Color(1, 1, 1, 0.42), th * 0.30, true)


# Yumuşak aşağı: iki ince chevron + hareket çizgileri (adım adım indirme hissi)
func _soft_down(c: Vector2, col: Color) -> void:
	_vchevron(c + Vector2(0.0, -13.0), 30.0, 15.0, 5.5, col)
	_vchevron(c + Vector2(0.0, 7.0), 30.0, 15.0, 5.5, Color(col.r, col.g, col.b, 0.75))
	# yan hareket çizgileri
	for sx in [-1.0, 1.0]:
		for k in range(2):
			var y: float = c.y + 20.0 + float(k) * 7.0
			draw_line(Vector2(c.x + sx * (23.0 + float(k) * 3.0), y),
				Vector2(c.x + sx * (29.0 + float(k) * 3.0), y),
				Color(1, 1, 1, 0.30 - float(k) * 0.10), 2.5, true)


# Sert düşürme: kalın ok + zemin çizgisi + darbe izleri + "DROP" yazısı
func _drop(c: Vector2, col: Color) -> void:
	var top: float = c.y - 34.0
	var head_top: float = c.y + 2.0
	var tip: float = c.y + 24.0
	# gövde (hafif dikey degrade hissi için 2 parça)
	draw_rect(Rect2(c.x - 7.0, top, 14.0, head_top - top), Color(col.r * 0.85, col.g * 0.85, col.b * 0.85, 1.0))
	draw_rect(Rect2(c.x - 7.0, top, 5.0, head_top - top), Color(1, 1, 1, 0.22))
	# ok başı
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 19.0, head_top),
		Vector2(c.x + 19.0, head_top),
		Vector2(c.x, tip),
	]), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 19.0, head_top),
		Vector2(c.x - 4.0, head_top),
		Vector2(c.x, tip),
	]), Color(1, 1, 1, 0.18))
	# zemin çizgisi (sert iniş vurgusu)
	draw_line(Vector2(c.x - 26.0, tip + 8.0), Vector2(c.x + 26.0, tip + 8.0), col, 4.0, true)
	# darbe izleri
	for sx in [-1.0, 1.0]:
		draw_line(Vector2(c.x + sx * 22.0, tip + 1.0), Vector2(c.x + sx * 31.0, tip - 9.0),
			Color(col.r, col.g, col.b, 0.55), 3.0, true)
	# etiket
	var f: Font = ThemeDB.fallback_font
	draw_string(f, Vector2(0.0, size.y - 10.0), "DROP", HORIZONTAL_ALIGNMENT_CENTER,
		size.x, 15, Color(1, 1, 1, 0.80))


# Döndürme: çember yayı + ok başı + merkez noktası
func _rotate(c: Vector2, col: Color) -> void:
	var r: float = 24.0
	var start_a: float = deg_to_rad(-55.0)
	var end_a: float = deg_to_rad(215.0)
	draw_arc(c + Vector2(0, 3.5), r + 1.0, start_a, end_a, 32, Color(0, 0, 0, 0.45), 8.0, true)
	draw_arc(c, r, start_a, end_a, 32, col, 6.5, true)
	draw_arc(c + Vector2(-1.0, -1.5), r, start_a, end_a, 32, Color(1, 1, 1, 0.30), 2.2, true)
	# ok başı
	var tip: Vector2 = c + Vector2(cos(end_a), sin(end_a)) * r
	var tangent: float = end_a + PI * 0.5
	var p1: Vector2 = tip + Vector2(cos(tangent), sin(tangent)) * 13.0
	var p2: Vector2 = tip + Vector2(cos(tangent + 2.2), sin(tangent + 2.2)) * 12.0
	draw_colored_polygon(PackedVector2Array([tip, p1, p2]), col)
	draw_circle(c, 4.5, Color(col.r, col.g, col.b, 0.85))
	draw_circle(c + Vector2(-1, -1), 2.0, Color(1, 1, 1, 0.5))
