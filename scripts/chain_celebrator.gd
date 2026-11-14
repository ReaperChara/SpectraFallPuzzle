# chain_celebrator.gd - Chain kutlaması (2B vektör çizgi film elleri).
# Akış: 2 el içeri girer -> 2 kez alkış -> her chain adımında sol el kaybolur,
# sağ el parmak şıklatır -> 2 kez daha alkış -> sırayla alev atışları.
extends Control

signal flame_arrived(cell: Vector2i)
signal flames_finished

const HandSprite := preload("res://scripts/hand_sprite.gd")

const HAND_Y: float = 810.0
const GAP_OPEN: float = 400.0
const GAP_CLOSED: float = 296.0
const HAND_SIZE: float = 260.0
const FLAME_FLIGHT: float = 0.085
const FLAME_BURN: float = 0.10
const FLAME_GAP: float = 0.02

var _hand_l: Control
var _hand_r: Control

var _hands_a: float = 0.0
var _left_vis: float = 1.0
var _right_vis: float = 1.0
var _gap: float = GAP_OPEN
var _clap_lean: float = 0.0
var _snap_amt: float = 0.0
var _flash: float = 0.0
var _clap_anim_t: float = 0.0
var _snap_anim_t: float = 0.0

var _flames: Array = []
var _queue: Array = []
var _launch_cd: float = 0.0
var _emitting_done: bool = false
var _armed: bool = false
var _snap_busy: bool = false
var _snap_queue: int = 0

var _alpha_tween: Tween

# Şimdilik el animasyonları (alkış / şıklatma) kapalı; alevler yine de
# ellerin geleceği bölgeden fırlar. Animasyonlar eklenince true yap.
var hands_enabled: bool = false

# Alevlerin çıkış noktası: CHAIN yazısının dikey ekseni (main_scene set eder).
# 0 veya negatif ise ekran ortası kullanılır.
var fire_origin_x: float = -1.0

func _origin() -> Vector2:
	var ox: float = fire_origin_x if fire_origin_x > 0.0 else size.x * 0.5
	# Eller görünürken ellerin ortasından, animasyonsuz modda CHAIN yazısının
	# hemen altından (kombo çubuğunu kapatmadan) çıkar.
	var oy: float = (HAND_Y - 70.0) if hands_enabled else (HAND_Y - 12.0)
	return Vector2(ox, oy)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_build_hands()
	_sync_hands()


func _build_hands() -> void:
	_hand_l = HandSprite.new()
	_hand_l.facing = -1
	_hand_l.size = Vector2(HAND_SIZE, HAND_SIZE)
	_hand_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_l)

	_hand_r = HandSprite.new()
	_hand_r.facing = 1
	_hand_r.size = Vector2(HAND_SIZE, HAND_SIZE)
	_hand_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_r)


func _sync_hands() -> void:
	var half: float = _gap * 0.5
	var cx: float = size.x * 0.5
	var top: float = HAND_Y - HAND_SIZE * 0.5
	_hand_l.position = Vector2(cx - half - HAND_SIZE * 0.5, top)
	_hand_r.position = Vector2(cx + half - HAND_SIZE * 0.5, top)

	var lean: float = _clap_lean
	var snapv: float = _snap_amt

	# Alkış: sol/sağ eğilir ve kare animasyonu "clap" olur
	_hand_l.rotation = -0.06 - lean * 0.16
	_hand_r.rotation = 0.06 + lean * 0.16
	_hand_l.scale = Vector2.ONE * (1.0 + lean * 0.04)
	_hand_r.scale = Vector2.ONE * (1.0 + lean * 0.04)

	if _snap_anim_t > 0.0:
		_hand_r.play("snap", false)
	elif _clap_anim_t > 0.0:
		_hand_r.play("clap", false)
	else:
		_hand_r.play("idle")
	if _clap_anim_t > 0.0:
		_hand_l.play("clap", false)
	else:
		_hand_l.play("idle")

	var a_l: float = clampf(_hands_a, 0.0, 1.0) * _left_vis
	var a_r: float = clampf(_hands_a, 0.0, 1.0) * _right_vis
	_hand_l.modulate = Color(1, 1, 1, a_l)
	_hand_r.modulate = Color(1, 1, 1, a_r)
	_hand_l.visible = a_l > 0.01 and hands_enabled
	_hand_r.visible = a_r > 0.01 and hands_enabled


# --- Dış API ---------------------------------------------------------------

func play_chain_start() -> void:
	if not hands_enabled:
		return
	_left_vis = 1.0
	_right_vis = 1.0
	show_hands()
	await get_tree().create_timer(0.16).timeout
	await _clap_once()
	await get_tree().create_timer(0.22).timeout
	await _clap_once()


func play_snap() -> void:
	if not hands_enabled:
		return
	if _hands_a < 0.9:
		show_hands()
	if _snap_busy:
		_snap_queue = mini(_snap_queue + 1, 24)
		return
	_run_snap()


func _run_snap() -> void:
	_snap_busy = true
	_snap_anim_t = 0.40
	# combo sırasında sol el kaybolur, sağ el şıklatır
	var fade: Tween = create_tween()
	fade.tween_property(self, "_left_vis", 0.0, 0.16)

	var up: Tween = create_tween()
	up.tween_property(self, "_snap_amt", 1.0, 0.09)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_callback(func(): _flash = 0.55)
	up.tween_interval(0.05)
	up.tween_property(self, "_snap_amt", 0.0, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await up.finished
	_snap_done()


func _snap_done() -> void:
	_snap_busy = false
	if _snap_queue > 0:
		_snap_queue -= 1
		_run_snap()
	elif _flames.is_empty() and _queue.is_empty():
		_hands_idle()


func play_combo_end(targets: Array) -> void:
	_queue = targets.duplicate()
	_flames.clear()
	_emitting_done = false
	_armed = false
	_snap_queue = 0
	_launch_cd = 0.0
	_snap_amt = 0.0
	if not hands_enabled:
		# Animasyon yok: alevler doğrudan ayrılmış bölgeden sırayla çıkar
		_armed = true
		_launch_cd = 0.02
		await flames_finished
		return
	var back: Tween = create_tween()
	back.tween_property(self, "_left_vis", 1.0, 0.18)
	show_hands()
	await get_tree().create_timer(0.18).timeout
	await _clap_once()
	await get_tree().create_timer(0.22).timeout
	await _clap_once()
	await get_tree().create_timer(0.30).timeout
	_armed = true
	_launch_cd = 0.02
	await flames_finished


func cancel_all() -> void:
	_armed = false
	_emitting_done = true
	_snap_queue = 0
	_queue.clear()
	_flames.clear()
	_launch_cd = 0.0
	_flash = 0.0
	_snap_amt = 0.0
	_left_vis = 1.0
	_right_vis = 1.0
	hide_hands()


func show_hands() -> void:
	if _alpha_tween and _alpha_tween.is_valid():
		_alpha_tween.kill()
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(self, "_hands_a", 1.0, 0.20)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_hands() -> void:
	if _alpha_tween and _alpha_tween.is_valid():
		_alpha_tween.kill()
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(self, "_hands_a", 0.0, 0.28)\
		.set_trans(Tween.TRANS_QUAD)


func _hands_idle() -> void:
	if _flames.is_empty() and _queue.is_empty():
		await get_tree().create_timer(0.9).timeout
		_left_vis = 1.0
		_right_vis = 1.0
		hide_hands()


func _clap_once() -> void:
	_clap_anim_t = 0.42
	# eller birbirine doğru kapanır
	var inn: Tween = create_tween().set_parallel(true)
	inn.tween_property(self, "_gap", GAP_CLOSED, 0.10)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	inn.tween_property(self, "_clap_lean", 1.0, 0.10)
	await inn.finished
	_flash = 1.0
	var out: Tween = create_tween().set_parallel(true)
	out.tween_property(self, "_gap", GAP_OPEN, 0.13)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	out.tween_property(self, "_clap_lean", 0.0, 0.13)
	await out.finished


# --- Kare güncellemesi -----------------------------------------------------

func _process(delta: float) -> void:
	var dirty: bool = false

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		dirty = true

	if _clap_anim_t > 0.0:
		_clap_anim_t = maxf(0.0, _clap_anim_t - delta)
	if _snap_anim_t > 0.0:
		_snap_anim_t = maxf(0.0, _snap_anim_t - delta)

	_sync_hands()

	if _launch_cd > 0.0:
		_launch_cd -= delta
		if _launch_cd <= 0.0 and not _queue.is_empty():
			_launch_next_flame()
			dirty = true

	var still: Array = []
	for f in _flames:
		if f.burn > 0.0:
			f.burn += delta
			if f.burn >= FLAME_BURN:
				continue
		else:
			f.t += delta
			if f.t >= FLAME_FLIGHT:
				f.t = FLAME_FLIGHT
				f.burn = 0.0001
				emit_signal("flame_arrived", f.cell)
				_launch_cd = FLAME_BURN + FLAME_GAP
		still.append(f)
		dirty = true
	_flames = still

	if _armed and _queue.is_empty() and _flames.is_empty() and not _emitting_done:
		_emitting_done = true
		_launch_cd = 0.0
		var tw: Tween = create_tween()
		tw.tween_interval(0.28)
		tw.tween_callback(func():
			emit_signal("flames_finished")
			_hands_idle())
		dirty = true

	if dirty or _hands_a > 0.0:
		queue_redraw()


func _launch_next_flame() -> void:
	var target: Dictionary = _queue.pop_front()
	var from: Vector2 = _origin()
	_flames.append({
		"cell": target.cell,
		"from": from,
		"to": target.pos,
		"t": 0.0,
		"burn": 0.0,
	})


# --- 2B katman: alevler ve alkış ışıması -----------------------------------

func _draw() -> void:
	if _flash > 0.01 and _hands_a > 0.01:
		var fc: Vector2 = Vector2(size.x * 0.5, HAND_Y - 30.0)
		draw_circle(fc, 26.0 + (1.0 - _flash) * 34.0,
			Color(1.0, 0.95, 0.75, 0.36 * _flash))
		draw_circle(fc, 13.0, Color(1, 1, 0.92, 0.48 * _flash))

	# Ateş kaynağı: ellerin geleceği bölgede sıcak kor parıltısı
	if not hands_enabled and (not _flames.is_empty() or not _queue.is_empty()):
		var src: Vector2 = _origin()
		var pulse: float = 0.7 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.02)
		draw_circle(src, 38.0, Color(1.0, 0.42, 0.10, 0.16 * pulse))
		draw_circle(src, 20.0, Color(1.0, 0.70, 0.24, 0.28 * pulse))
		draw_circle(src, 9.0, Color(1.0, 0.95, 0.72, 0.42 * pulse))

	for f in _flames:
		if f.burn > 0.0:
			var k: float = clampf(f.burn / FLAME_BURN, 0.0, 1.0)
			var r: float = 30.0 * (1.0 + k * 1.4)
			draw_circle(f.to, r, Color(1.0, 0.52, 0.12, 0.55 * (1.0 - k)))
			draw_circle(f.to, r * 0.55, Color(1.0, 0.88, 0.35, 0.80 * (1.0 - k)))
			draw_circle(f.to, r * 0.24, Color(1.0, 1.0, 0.90, 0.90 * (1.0 - k)))
		else:
			var p: float = clampf(f.t / FLAME_FLIGHT, 0.0, 1.0)
			var pos: Vector2 = f.from.lerp(f.to, p)
			pos.y -= sin(PI * p) * 46.0
			for i in range(3):
				var tp: float = maxf(0.0, p - 0.07 * float(i + 1))
				var tpos: Vector2 = f.from.lerp(f.to, tp)
				tpos.y -= sin(PI * tp) * 46.0
				draw_circle(tpos, 8.0 - float(i) * 2.0,
					Color(1.0, 0.45, 0.10, 0.30 - float(i) * 0.08))
			draw_circle(pos, 13.0, Color(1.0, 0.58, 0.12, 0.95))
			draw_circle(pos, 8.0, Color(1.0, 0.84, 0.30, 1.0))
			draw_circle(pos, 4.0, Color(1.0, 0.98, 0.80, 1.0))
