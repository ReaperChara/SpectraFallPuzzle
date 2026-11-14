extends SceneTree

func dump(n: Node, d: int) -> void:
	print("  ".repeat(d), n.name, " [", n.get_class(), "]")
	for c in n.get_children():
		dump(c, d + 1)

func _init() -> void:
	var n: Node = (load("res://assets/hand/hand.glb") as PackedScene).instantiate()
	dump(n, 0)
	var sk: Skeleton3D = _find_skel(n)
	if sk:
		print("SKEL bones=", sk.get_bone_count())
		for i in sk.get_bone_count():
			print("  ", i, " ", sk.get_bone_name(i))
	quit(0)

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r: Skeleton3D = _find_skel(c)
		if r:
			return r
	return null
