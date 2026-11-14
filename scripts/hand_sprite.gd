# hand_sprite.gd - Kare tabanlı (PIL ile üretilmiş) 2B çizgi film eli.
# idle / clap / snap dizilerini sırayla oynatır.
extends Control

const FRAME_DIR := "res://assets/hand_frames2/"

@export var facing: int = 1

var _idle: Array[Texture2D] = []
var _clap: Array[Texture2D] = []
var _snap: Array[Texture2D] = []
var _cur: Array[Texture2D] = []
var _state: String = "idle"
var _frame: int = 0
var _acc: float = 0.0
var _fps: float = 14.0
var _loop: bool = true
var _done_cb: Callable

var _tex: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_frames()
	_tex = TextureRect.new()
	_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	play("idle")


func _load_frames() -> void:
	var dir: DirAccess = DirAccess.open(FRAME_DIR)
	if dir == null:
		push_warning("hand_sprite: kare klasörü yok " + FRAME_DIR)
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if f.ends_with(".png"):
			names.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for n in names:
		var tex: Texture2D = load(FRAME_DIR + n)
		if tex == null:
			continue
		if n.begins_with("idle_"):
			_idle.append(tex)
		elif n.begins_with("clap_"):
			_clap.append(tex)
		elif n.begins_with("snap_"):
			_snap.append(tex)


func play(state: String, loop: bool = true, on_done: Callable = Callable()) -> void:
	if state == _state and loop:
		return
	_state = state
	_loop = loop
	_done_cb = on_done
	_frame = 0
	_acc = 0.0
	match state:
		"clap":
			_cur = _clap
			_fps = 22.0 if not loop else 14.0
		"snap":
			_cur = _snap
			_fps = 24.0 if not loop else 14.0
		_:
			_cur = _idle
			_fps = 8.0
	if _cur.is_empty():
		_cur = _idle
	_apply()


func _process(delta: float) -> void:
	if _cur.is_empty():
		return
	_acc += delta
	var step: float = 1.0 / _fps
	if _acc < step:
		return
	_acc -= step
	_frame += 1
	if _frame >= _cur.size():
		if _loop:
			_frame = 0
		else:
			_frame = _cur.size() - 1
			_apply()
			var cb: Callable = _done_cb
			_done_cb = Callable()
			if cb.is_valid():
				cb.call()
			return
	_apply()


func _apply() -> void:
	if _tex == null or _cur.is_empty():
		return
	_tex.texture = _cur[clampi(_frame, 0, _cur.size() - 1)]
	_tex.flip_h = facing < 0
