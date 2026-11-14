extends Node2D

@onready var cel: Control = $ChainCelebrator

var _dir: String = "/home/ruddy/chainshots"


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_dir + "/" + name + ".png")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	for f in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir + "/" + f)

	await get_tree().create_timer(0.6).timeout
	cel.play_chain_start()
	await get_tree().create_timer(0.30).timeout
	await _shot("01_hands_in")
	await get_tree().create_timer(0.14).timeout
	await _shot("02_clap")

	for i in range(6):
		await get_tree().create_timer(0.30).timeout
		cel.play_snap()
		if i == 0:
			await get_tree().create_timer(0.06).timeout
			await _shot("03_snap")
	await get_tree().create_timer(0.9).timeout
	await _shot("04_snaps_done")

	var targets: Array = []
	for i in range(6):
		targets.append({
			"cell": Vector2i(i, 24),
			"pos": Vector2(120.0 + float(i) * 72.0, 560.0),
		})
	cel.play_combo_end(targets)

	await get_tree().create_timer(0.16).timeout
	await _shot("05_final_clap")
	await get_tree().create_timer(0.45).timeout
	await _shot("06_flame1")
	await get_tree().create_timer(0.35).timeout
	await _shot("07_flame2")
	await get_tree().create_timer(0.6).timeout
	await _shot("08_flames_mid")
	await get_tree().create_timer(2.4).timeout
	await _shot("09_done")
	get_tree().quit()
