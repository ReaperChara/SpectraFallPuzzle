extends SceneTree

func _init() -> void:
	var n: Node = (load("res://assets/hand/hand.glb") as PackedScene).instantiate()
	var sk: Skeleton3D = _find_skel(n)
	var mi: MeshInstance3D = n.find_child("hooded_char_LP", true, false)
	var aabb: AABB = mi.global_transform * mi.get_aabb()
	print("AABB ", aabb)
	for bn in ["HandMain","IndexF_lower","IndexF_tip","PinkyF_lower","Bone.003"]:
		var idx: int = sk.find_bone(bn)
		print(bn, " idx=", idx, " global=", sk.global_transform * sk.get_bone_global_pose(idx).origin)
	quit(0)

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r: Skeleton3D = _find_skel(c)
		if r:
			return r
	return null
