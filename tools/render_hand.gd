# render_hand.gd - El animasyonunu önceden render edip PNG kare dizisi üretir.
# Oyun içinde 3B model YÜKLENMEZ; sadece bu kareler oynatılır (optimizasyon dostu).
extends Node3D

const OUT: String = "res://assets/hand_frames"
const SIZE: int = 512
const HAND_PATH: String = "res://assets/hand/hand.glb"

var _vp: SubViewport
var _pivot: Node3D
var _hand: Node3D
var _skel: Skeleton3D
var _thumb: Array = []
var _index: Array = []
var _mid: Array = []
var _ring: Array = []
var _pinky: Array = []
var _clap_open: float = 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)

	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
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
	key.light_color = Color(1.0, 0.96, 0.90)
	_vp.add_child(key)

	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8, 140, 0)
	rim.light_energy = 0.85
	rim.light_color = Color(0.55, 0.70, 1.0)
	_vp.add_child(rim)

	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_hand = (load(HAND_PATH) as PackedScene).instantiate()
	_pivot.add_child(_hand)
	for ap in _hand.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
		(ap as AnimationPlayer).active = false

	var mi: MeshInstance3D = _hand.find_child("hooded_char_LP", true, false)
	await get_tree().process_frame
	var aabb: AABB = mi.global_transform * mi.get_aabb()
	_hand.position -= aabb.get_center()

	var mat: StandardMaterial3D = mi.get_active_material(0)
	if mat:
		mat = mat.duplicate()
		mat.metallic = 0.0
		mat.roughness = 0.55
		mi.material_override = mat

	_skel = _find_skel(_hand)
	if _skel:
		for n in ["Bone.001", "Bone.002", "Bone.003"]:
			_thumb.append(_skel.find_bone(n))
		for n in ["IndexF_lower", "IndexF_middle", "IndexF_tip"]:
			_index.append(_skel.find_bone(n))
		for n in ["MiddleF_lower", "MiddleF_middle", "MiddleF_tip"]:
			_mid.append(_skel.find_bone(n))
		for n in ["RingF_lower", "RingF_middle", "RingF_tip"]:
			_ring.append(_skel.find_bone(n))
		for n in ["PinkyF_lower", "PinkyF_middle", "PinkyF_tip"]:
			_pinky.append(_skel.find_bone(n))

	# gömlek manşeti (bilekte)
	_make_sleeve()

	_pivot.rotation_degrees = Vector3(-60, 0, -70)
	await get_tree().process_frame

	# döndürme sonrası kadrajı ortala
	var a2: AABB = mi.global_transform * mi.get_aabb()
	_pivot.position -= a2.get_center()
	await get_tree().process_frame

	await _render_all()
	get_tree().quit()


func _make_sleeve() -> void:
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = Color(0.16, 0.20, 0.36)
	cloth.roughness = 0.96
	cloth.metallic = 0.0

	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.135
	cyl.bottom_radius = 0.175
	cyl.height = 0.46
	cyl.radial_segments = 26
	var sleeve: MeshInstance3D = MeshInstance3D.new()
	sleeve.mesh = cyl
	sleeve.material_override = cloth
	sleeve.rotation_degrees = Vector3(90, 0, 0)
	sleeve.position = Vector3(-0.006, -0.004, -0.10)
	_pivot.add_child(sleeve)

	var cuff: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.138
	cm.bottom_radius = 0.138
	cm.height = 0.040
	cm.radial_segments = 26
	cuff.mesh = cm
	var cmat: StandardMaterial3D = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.29, 0.37, 0.60)
	cmat.roughness = 0.72
	cuff.material_override = cmat
	cuff.rotation_degrees = Vector3(90, 0, 0)
	cuff.position = Vector3(-0.006, -0.004, 0.055)
	_pivot.add_child(cuff)


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r: Skeleton3D = _find_skel(c)
		if r:
			return r
	return null


func _pose_bone(idx: int, ang: float) -> void:
	if idx < 0:
		return
	var rest: Quaternion = _skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	_skel.set_bone_pose_rotation(idx, rest * Quaternion(Vector3(0, 0, 1), ang))


func _pose_finger(chain: Array, amt: float) -> void:
	for i in chain.size():
		_pose_bone(chain[i], amt * (0.42 + 0.14 * float(i)))


func _apply(thumb: float, fingers: float, tilt: float) -> void:
	_pose_finger(_thumb, thumb * 0.9)
	_pose_finger(_index, fingers)
	_pose_finger(_mid, fingers * 0.85)
	_pose_finger(_ring, fingers * 0.7)
	_pose_finger(_pinky, fingers * 0.6)
	_pivot.rotation_degrees = Vector3(-60 + tilt * 3.0, tilt * 4.0, -70 + tilt * 5.0)


func _render_all() -> void:
	# 1) BEKLEME (hafif nefes)
	for i in 8:
		var t: float = float(i) / 8.0
		_apply(0.0, 0.0, sin(t * TAU) * 0.3)
		await _save("idle_%02d" % i)

	# 2) ŞIKLATMA: başparmak gerilir -> kapanır -> kıvılcım
	var snap: Array = [0.0, 0.35, 0.75, 1.0, 0.85, 0.45, 0.10, 0.0]
	for i in snap.size():
		_apply(float(snap[i]), float(snap[i]) * 0.25, float(snap[i]) * -0.35)
		await _save("snap_%02d" % i)

	# 3) ALKIŞ: parmaklar açılır (yay gibi), avuç geri çekilir
	for i in 10:
		var t: float = float(i) / 9.0
		var k: float = sin(t * PI)
		_apply(0.0, -0.30 * k, -k * 1.1)
		await _save("clap_%02d" % i)


func _save(frame_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(OUT + "/" + frame_name + ".png")
