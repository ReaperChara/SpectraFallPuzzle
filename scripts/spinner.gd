# spinner.gd - Reklam yüklenirken ortada dönen mükemmel daire yay
extends Control

var angle: float = 0.0
var arc_degrees: float = 100.0  # yayının açısı (derece)
var radius: float = 30.0
var thickness: float = 6.0
var spin_speed: float = 240.0  # derece/saniye

func _ready() -> void:
	# Her zaman merkezden dönsün diye köşe yok, kendimiz çiziyoruz
	pivot_offset = size * 0.5

func _process(delta: float) -> void:
	if not visible:
		return
	angle += delta * spin_speed
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var start: float = deg_to_rad(angle)
	var end: float = deg_to_rad(angle + arc_degrees)
	# Arka halka (soluk tam daire)
	draw_arc(center, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.15), thickness, true)
	# Dönen parlak yay
	draw_arc(center, radius, start, end, 48, Color(1, 1, 1, 0.95), thickness, true)
