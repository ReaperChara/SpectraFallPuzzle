# pose_test.gd - Tek kare: açı + gömlek manşeti yerleşimi testi.
extends Node3D

const SIZE: int = 700
const HAND_PATH: String = "res://assets/hand/hand.glb"

var _vp: SubViewport
var _pivot: Node3D


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
	e.background_color = Color(0.09, 0.10, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.89, 0.96)
	e.ambient_light_energy = 1.15
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)

	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.2
	cam.position = Vector3(0, 0, 4.0)
	_vp.add_child(cam)

	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -38, 0)
	key.light_energy = 1.35
	_vp.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8, 140, 0)
	rim.light_energy = 0.85
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
	print("AABB ", aabb, " merkez ", aabb.get_center())
	await get_tree().process_frame
	print("pivot-space AABB ", mi.global_transform * mi.get_aabb())
	print("mesh global origin ", mi.global_position)

	# manşet: bilek ucunda (parmaklar +z, bilek -z yönünde)
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = Color(0.17, 0.21, 0.37)
	cloth.roughness = 0.96
	cloth.metallic = 0.0

	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.105
	cyl.bottom_radius = 0.135
	cyl.height = 0.34
	cyl.radial_segments = 26
	var sleeve: MeshInstance3D = MeshInstance3D.new()
	sleeve.mesh = cyl
	sleeve.material_override = cloth
	sleeve.rotation_degrees = Vector3(90, 0, 0)
	sleeve.position = Vector3(-0.005, 0.0, -0.10)
	_pivot.add_child(sleeve)

	# manşet bileziği
	var cuff: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.108
	cm.bottom_radius = 0.108
	cm.height = 0.035
	cm.radial_segments = 26
	cuff.mesh = cm
	var cmat: StandardMaterial3D = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.30, 0.38, 0.60)
	cmat.roughness = 0.75
	cuff.material_override = cmat
	cuff.rotation_degrees = Vector3(90, 0, 0)
	cuff.position = Vector3(-0.005, 0.0, 0.045)
	_pivot.add_child(cuff)

	_pivot.rotation_degrees = Vector3(-60, 0, -70)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("res://assets/hand_frames/_pose.png")
	get_tree().quit()


static func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r: Skeleton3D = _find_skel(c)
		if r:
			return r
	return null
