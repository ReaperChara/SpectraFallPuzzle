# cartoon_hand.gd - Referans pozunda 2B cizgi film eli
# El kendi ekseninde "yukari" cizilir; tum el tilt ile capraz cevrilir.
# Kalin tek siyah dis hat + duz renk + yumusak golge + beyaz kenar parlamasi.
extends Control

@export var facing: int = 1                    # 1 = sag el, -1 = sol el
@export var skin_color: Color = Color(1.0, 0.808, 0.659)
@export var skin_shadow: Color = Color(0.886, 0.604, 0.455)
@export var skin_line: Color = Color(0.808, 0.518, 0.369)
@export var skin_light: Color = Color(1.0, 0.886, 0.769)
@export var sleeve_color: Color = Color(0.141, 0.176, 0.314)
@export var cuff_color: Color = Color(0.337, 0.439, 0.714)
@export var outline_color: Color = Color(0.086, 0.071, 0.110)

const OUTLINE: float = 7.5

# poz
var curl: float = 0.35      # 0 acik yumruk -> 1 tam yumruk
var thumb_curl: float = 0.5
var point: float = 0.0      # isaret parmagi uzama 0..1
var tilt: float = -0.66     # radyan (yaklasik -38 derece) : capraz bakis

# --- siluet parcalari: (a, b, r) kapsulleri + daireler ---
var _solids: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_pose(p_curl: float, p_thumb: float, p_point: float, p_tilt: float = -0.66) -> void:
	curl = clampf(p_curl, 0.0, 1.0)
	thumb_curl = clampf(p_thumb, 0.0, 1.0)
	point = clampf(p_point, 0.0, 1.0)
	tilt = p_tilt
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 300.0
	var origin: Vector2 = Vector2(size.x * 0.5, size.y * 0.62)
	# tum el kendi ekseninde cizilir, sonra tilt ile cevrilir
	draw_set_transform(origin, tilt * float(facing), Vector2(float(facing) * s, s))
	_build()
	# 1) kalin dis hat (ayni kapsuller, buyutulmus)
	for it in _solids:
		_capsule_pre(it, true)
	# 2) dolgu
	for it in _solids:
		_capsule_pre(it, false)
	_shading()


func _build() -> void:
	_solids.clear()
	# --- avuc govdesi ---
	_add_cap(Vector2(-8, 10), Vector2(-4, 62), 44.0)
	_add_cap(Vector2(-30, -10), Vector2(26, -6), 40.0)

	# --- yumruk: 3 bukuk parmak, eklemler SOLDA ---
	var knuck: Array = [
		[-34, 24.0], [-14, 27.0], [8, 25.0],
	]
	var c: float = clampf(curl, 0.0, 1.0)
	for i in range(knuck.size()):
		var kx: float = float(knuck[i][0])
		var kr: float = float(knuck[i][1])
		# govde (avuçtan yukari)
		var top_y: float = -16.0 - 26.0 * (1.0 - c)
		_add_cap(Vector2(kx, -6), Vector2(kx - 4, top_y), kr)
		# eklem tumsagi (sol disari)
		_add_circle(Vector2(kx - kr * 0.72, top_y - kr * 0.15), kr * 0.86)
		# parmak ucu avuca donuk
		_add_cap(Vector2(kx - 2, top_y - 2), Vector2(kx + 4, top_y + 20.0 * c), kr * 0.78)

	# --- isaret parmagi: capraz yukari-sola ---
	var pc: float = clampf(curl * (1.0 - 0.92 * point), 0.0, 1.0)
	var dir_a: float = -0.34  # radyan, yukari-sola
	var l1: float = 54.0 * (1.0 - 0.55 * pc) + 34.0 * point
	var l2: float = 44.0 * (1.0 - 0.70 * pc) + 30.0 * point
	var p0: Vector2 = Vector2(-52, -18)
	var d1: Vector2 = Vector2(sin(dir_a), -cos(dir_a))
	var p1: Vector2 = p0 + d1 * l1
	var a2: float = dir_a + pc * 0.9
	var d2: Vector2 = Vector2(sin(a2), -cos(a2))
	var p2: Vector2 = p1 + d2 * l2
	_add_cap(p0, p1, 15.0)
	_add_cap(p1, p2, 13.6)

	# --- basparmak: sag/on tarafta, govdeye yatik ---
	var tc: float = clampf(thumb_curl, 0.0, 1.0)
	var b0: Vector2 = Vector2(30, 26)
	var b1: Vector2 = Vector2(52 - 6 * tc, 4 - 14 * tc)
	var b2: Vector2 = Vector2(46 - 16 * tc, -16 - 26 * tc)
	_add_cap(b0, b1, 18.0)
	_add_cap(b1, b2, 16.0)

	# --- manşet + kol (bilek sag-alta dogru kalinlasir) ---
	_add_cap(Vector2(-6, 52), Vector2(2, 84), 40.0)
	_add_cap(Vector2(2, 84), Vector2(10, 132), 35.0)


func _add_cap(a: Vector2, b: Vector2, r: float) -> void:
	_solids.append({"t": "cap", "a": a, "b": b, "r": r})


func _add_circle(c: Vector2, r: float) -> void:
	_solids.append({"t": "circ", "c": c, "r": r})


func _capsule_pre(it: Dictionary, outline: bool) -> void:
	var grow: float = OUTLINE if outline else 0.0
	var col: Color = outline_color if outline else skin_color
	if it["t"] == "cap":
		var a: Vector2 = it["a"]
		var b: Vector2 = it["b"]
		var r: float = float(it["r"]) + grow
		draw_line(a, b, col, r * 2.0, true)
		draw_circle(a, r, col)
		draw_circle(b, r, col)
	else:
		draw_circle(it["c"], float(it["r"]) + grow, col)


func _shading() -> void:
	# golge: sag-alt tarafta yumusak koyu ton (kapsul katmani)
	var sh: Color = Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.55)
	for it in _solids:
		if it["t"] == "cap":
			var a: Vector2 = it["a"] + Vector2(7, 7)
			var b: Vector2 = it["b"] + Vector2(5, 5)
			var r: float = float(it["r"]) * 0.72
			draw_line(a, b, sh, r * 2.0, true)
			draw_circle(a, r, sh)
			draw_circle(b, r, sh)
		else:
			draw_circle(it["c"] + Vector2(6, 6), float(it["r"]) * 0.72, sh)

	# isaret parmagi ile avuç arasindaki ayirim cizgisi
	var ln: Color = Color(skin_line.r, skin_line.g, skin_line.b, 0.75)
	var pc: float = clampf(curl * (1.0 - 0.92 * point), 0.0, 1.0)
	var p0: Vector2 = Vector2(-52, -18)
	var l1: float = 54.0 * (1.0 - 0.55 * pc) + 34.0 * point
	var d1: Vector2 = Vector2(sin(-0.34), -cos(-0.34))
	var p1: Vector2 = p0 + d1 * (l1 * 0.82)
	draw_line(p0 + Vector2(6, 4), p1 + Vector2(2, 2), ln, 3.0, true)

	# yumruk parmak oluklari
	var c: float = clampf(curl, 0.0, 1.0)
	var top_y: float = -16.0 - 26.0 * (1.0 - c)
	for gx in [-24.0, -3.0]:
		draw_line(Vector2(gx, top_y + 4), Vector2(gx - 3, top_y - 14.0), ln, 2.8, true)

	# manşet bandi
	var cuff_top: float = 56.0
	draw_line(Vector2(-46, cuff_top), Vector2(46, cuff_top), cuff_color, 30.0, true)
	draw_line(Vector2(-46, cuff_top - 15), Vector2(46, cuff_top - 15), sleeve_color, 8.0, true)
	draw_line(Vector2(-44, 84), Vector2(44, 84), sleeve_color, 74.0, true)

	# beyaz kenar parlamasi (dis hattin ic yani)
	var hi: Color = Color(1, 1, 1, 0.32)
	draw_line(Vector2(-60, 40), Vector2(-30, 96), hi, 5.0, true)
