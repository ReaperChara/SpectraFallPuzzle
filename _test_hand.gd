extends Control

const Hand := preload("res://scripts/cartoon_hand.gd")

func _ready() -> void:
	var W: int = 720
	var H: int = 1280
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.23)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var poses: Array = [
		["open", 0.15, 0.45, 0.0],
		["clap", 0.35, 0.55, 0.0],
		["snap", 0.62, 0.05, 1.0],
		["fist", 0.95, 0.85, 0.0],
	]
	var i: int = 0
	for p in poses:
		var h: Control = Hand.new()
		h.facing = 1
		h.set_anchors_preset(Control.PRESET_TOP_LEFT)
		h.position = Vector2(20 + (i % 2) * 350, 200 + (i / 2) * 480)
		h.size = Vector2(320, 440)
		add_child(h)
		h.set_pose(float(p[1]), float(p[2]), float(p[3]))
		var lbl: Label = Label.new()
		lbl.text = str(p[0])
		lbl.position = h.position + Vector2(10, 400)
		lbl.add_theme_font_size_override("font_size", 22)
		add_child(lbl)
		i += 1

	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("/tmp/opencode/hand_godot.png")
	print("saved")
	get_tree().quit()
