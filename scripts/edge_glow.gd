# edge_glow.gd - Ekran kenarı parlama efekti (chain patlamalarında)
extends Node2D

const SCREEN_SIZE: Vector2 = Vector2(720, 1280)
const THICKNESS: float = 110.0
const LINES: int = 16

var intensity: float = 0.0
var glow_color: Color = Color(1.0, 0.85, 0.25)


func trigger(color: Color = Color(1.0, 0.85, 0.25), strength: float = 1.0) -> void:
	glow_color = color
	intensity = clampf(strength, 0.0, 1.5)
	queue_redraw()


func _process(delta: float) -> void:
	if intensity > 0.0:
		intensity = maxf(0.0, intensity - delta * 1.8)
		queue_redraw()


func _draw() -> void:
	if intensity <= 0.01:
		return
	var step_h: float = THICKNESS / float(LINES)
	for i in range(LINES):
		# Kenardan içeri doğru: en dışta parlak, içeri doğru söner
		var t: float = float(i) / float(LINES)
		var alpha: float = intensity * 0.30 * pow(1.0 - t, 2.2)
		if alpha <= 0.002:
			continue
		var c: Color = Color(glow_color.r, glow_color.g, glow_color.b, alpha)
		var offset: float = float(i) * step_h
		# Üst / alt
		draw_rect(Rect2(0.0, offset, SCREEN_SIZE.x, step_h + 0.5), c)
		draw_rect(Rect2(0.0, SCREEN_SIZE.y - offset - step_h, SCREEN_SIZE.x, step_h + 0.5), c)
		# Sol / sağ
		draw_rect(Rect2(offset, 0.0, step_h + 0.5, SCREEN_SIZE.y), c)
		draw_rect(Rect2(SCREEN_SIZE.x - offset - step_h, 0.0, step_h + 0.5, SCREEN_SIZE.y), c)
