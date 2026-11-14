# combo_bar.gd - Chain kombo göstergesi
# Barın KENDİSİ süre göstergesidir: dolarken kombo penceresi işler,
# dolduğunda birikmiş alev topları fırlar.
extends Control

# 0.0 -> 1.0 dolum (kombo penceresi ilerlemesi)
var progress: float = 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		if progress > 0.001:
			modulate.a = 1.0
		queue_redraw()

# Kaç alev topu birikti (sadece ince çentikler olarak gösterilir)
var charges: int = 0:
	set(v):
		charges = v
		queue_redraw()

# Geriye dönük uyumluluk
var fill: float:
	get:
		return progress
	set(v):
		progress = v

var nearest_age: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	resized.connect(queue_redraw)


func show_bar() -> void:
	modulate.a = 1.0


func reset() -> void:
	progress = 0.0
	charges = 0


func drain() -> void:
	charges = 0
	progress = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.28)


func _draw() -> void:
	var s: Vector2 = size
	var rad: float = s.y * 0.5

	# Arka plan
	_round_rect(Rect2(0, 0, s.x, s.y), rad, Color(0.06, 0.07, 0.13, 0.90))

	# Dolgu — kombo penceresi ilerledikçe dolar
	if progress > 0.002:
		var w: float = maxf(s.x * progress, s.y)
		# dolarken sarıdan kızgın turuncuya
		var accent: Color = Color(1.0, 0.80, 0.26).lerp(Color(1.0, 0.36, 0.12),
			clampf(progress * 1.15, 0.0, 1.0))
		_round_rect(Rect2(2, 2, w - 4, s.y - 4), (s.y - 4) * 0.5, accent)
		# üst parlaklık
		_round_rect(Rect2(4, 3, maxf(w - 8, 2), (s.y - 6) * 0.38), 3.0,
			Color(1, 1, 1, 0.22))
		# dolum ucundaki parlama (dolmaya hazır hissi)
		if progress < 0.995:
			draw_circle(Vector2(clampf(w - 4.0, rad, s.x - rad), s.y * 0.5),
				s.y * 0.42, Color(1.0, 0.95, 0.75, 0.85))

	# Kenar
	_round_rect(Rect2(0, 0, s.x, s.y), rad, Color(0, 0, 0, 0), true,
		Color(1.0, 0.85, 0.35, 0.38))
	# Dolduğunda kenar parlar
	if progress >= 0.995:
		_round_rect(Rect2(1, 1, s.x - 2, s.y - 2), rad - 1,
			Color(0, 0, 0, 0), true, Color(1.0, 0.62, 0.18, 0.95))

	# Biriken alev topları: barın üstünde küçük çentikler
	if charges > 0:
		var max_dots: int = 10
		var n: int = mini(charges, max_dots)
		var gap: float = 5.0
		var dw: float = 6.0
		var total: float = float(n) * dw + float(n - 1) * gap
		var x0: float = (s.x - total) * 0.5
		for i in range(n):
			var cx: float = x0 + float(i) * (dw + gap) + dw * 0.5
			draw_circle(Vector2(cx, -7.0), 3.0, Color(1.0, 0.45, 0.12, 0.95))
			draw_circle(Vector2(cx - 0.6, -7.6), 1.4, Color(1.0, 0.95, 0.70, 0.95))


func _round_rect(r: Rect2, rad: float, col: Color, outline: bool = false,
		outline_col: Color = Color.WHITE) -> void:
	var use: Color = outline_col if outline else col
	if outline:
		# ince kenar: 4 köşe yayı + 4 çizgi
		var t: float = 1.5
		draw_line(Vector2(r.position.x + rad, r.position.y), Vector2(r.end.x - rad, r.position.y), use, t, true)
		draw_line(Vector2(r.position.x + rad, r.end.y), Vector2(r.end.x - rad, r.end.y), use, t, true)
		draw_line(Vector2(r.position.x, r.position.y + rad), Vector2(r.position.x, r.end.y - rad), use, t, true)
		draw_line(Vector2(r.end.x, r.position.y + rad), Vector2(r.end.x, r.end.y - rad), use, t, true)
		draw_arc(Vector2(r.position.x + rad, r.position.y + rad), rad, PI, PI * 1.5, 8, use, t, true)
		draw_arc(Vector2(r.end.x - rad, r.position.y + rad), rad, PI * 1.5, TAU, 8, use, t, true)
		draw_arc(Vector2(r.position.x + rad, r.end.y - rad), rad, PI * 0.5, PI, 8, use, t, true)
		draw_arc(Vector2(r.end.x - rad, r.end.y - rad), rad, 0.0, PI * 0.5, 8, use, t, true)
		return
	draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2, r.size.y), use)
	draw_rect(Rect2(r.position.x, r.position.y + rad, r.size.x, r.size.y - rad * 2), use)
	draw_circle(Vector2(r.position.x + rad, r.position.y + rad), rad, use)
	draw_circle(Vector2(r.end.x - rad, r.position.y + rad), rad, use)
	draw_circle(Vector2(r.position.x + rad, r.end.y - rad), rad, use)
	draw_circle(Vector2(r.end.x - rad, r.end.y - rad), rad, use)
