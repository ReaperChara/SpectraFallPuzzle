extends Node3D

func _ready() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.07, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.95)
	e.ambient_light_energy = 1.2
	env.environment = e
	add_child(env)

	var hand: Node3D = (load("res://assets/hand/hand.glb") as PackedScene).instantiate()
	add_child(hand)
	var mi: MeshInstance3D = hand.find_child("hooded_char_LP", true, false)
	var aabb: AABB = mi.global_transform * mi.get_aabb()
	var center: Vector3 = aabb.get_center()

	# pivot: elin gerçek merkezinde dönsün
	var pivot: Node3D = Node3D.new()
	pivot.position = center
	add_child(pivot)
	remove_child(hand)
	pivot.add_child(hand)
	hand.position = -center

	await get_tree().process_frame
	var aabb2: AABB = mi.global_transform * mi.get_aabb()
	print("YENI AABB ", aabb2)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.0
	cam.position = Vector3(0, 0, 3)
	add_child(cam)
	var l: DirectionalLight3D = DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, -25, 0)
	l.light_energy = 1.4
	add_child(l)

	var angles: Array = [Vector3(0,0,0), Vector3(-70,0,0), Vector3(-90,0,0), Vector3(0,90,0), Vector3(-35,-35,25)]
	for i in angles.size():
		pivot.rotation_degrees = angles[i]
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/opencode/ref/view_%d.png" % i)
	get_tree().quit()
