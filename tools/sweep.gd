# sweep.gd - Farklı açıları tek seferde render edip bir ızgara (kontakt sayfası) üretir.
extends Node3D

const SIZE: int = 300
const COLS: int = 5
const HAND_PATH: String = "res://assets/hand/hand.glb"

var _vp: SubViewport
var _pivot: Node3D
var _cam: Camera3D


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = false
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)

	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.11, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.89, 0.96)
	e.ambient_light_energy = 1.15
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 3.0
	_cam.position = Vector3(0, 0, 4.0)
	_vp.add_child(_cam)

	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -38, 0)
	key.light_energy = 1.35
	_vp.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8, 140, 0)
	rim.light_energy = 0.75
	rim.light_color = Color(0.55, 0.70, 1.0)
	_vp.add_child(rim)

	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	var hand: Node3D = (load(HAND_PATH) as PackedScene).instantiate()
	_pivot.add_child(hand)
	for ap in hand.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
		(ap as AnimationPlayer).active = false
	var mi: MeshInstance3D = hand.find_child("hooded_char_LP", true, false)
	await get_tree().process_frame
	var aabb: AABB = mi.global_transform * mi.get_aabb()
	hand.position -= aabb.get_center()

	var mat: StandardMaterial3D = mi.get_active_material(0)
	if mat:
		mat = mat.duplicate()
		mat.metallic = 0.0
		mat.roughness = 0.55
		mi.material_override = mat

	# (x, y, z) derece kombinasyonları
	var angles: Array = [
		Vector3(-25, 0, -80), Vector3(-35, -20, -70), Vector3(-45, -30, -60),
		Vector3(-55, -40, -50), Vector3(-35, -35, -45),
		Vector3(-60, 0, -70), Vector3(-70, -20, -60), Vector3(-50, -50, -40),
		Vector3(-40, -25, -100), Vector3(-30, -15, -90),
		Vector3(-65, -35, -35), Vector3(-75, -25, -55), Vector3(-45, -15, -120),
		Vector3(-25, -45, -65), Vector3(-55, -55, -30),
	]
	var sheet: Image = Image.create(SIZE * COLS, SIZE * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1, 1))
	for i in angles.size():
		_pivot.rotation_degrees = angles[i]
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = _vp.get_texture().get_image()
		print("  px ", img.get_pixel(10, 10), " size ", img.get_size())
		img.save_png("res://assets/hand_frames/_sw_%02d.png" % i)
		var c: Color = img.get_pixel(SIZE / 2, SIZE / 2)
		print(i, " ", angles[i], " center ", c)
	sheet.save_png("res://assets/hand_frames/_sweep.png")
	get_tree().quit()
