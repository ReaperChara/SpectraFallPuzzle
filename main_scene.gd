extends Node2D

# Node references
@onready var grid_manager: Node = $GridManager
@onready var board_view: Node2D = $BoardView
@onready var active_piece: Node2D = $ActivePiece
@onready var score_label: Label = $UI/ScoreLabel
@onready var level_label: Label = $UI/LevelLabel
@onready var high_score_label: Label = $UI/HighScoreLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var game_over_score: Label = $UI/GameOverPanel/ScoreLabel
@onready var game_over_label: Label = $UI/GameOverPanel/GameOverLabel
@onready var revive_button: Button = $UI/GameOverPanel/ReviveButton
@onready var restart_button: Button = $UI/GameOverPanel/RestartButton
@onready var pause_button: Button = $UI/PauseButton
@onready var chain_label: Label = $UI/ChainLabel
@onready var chain_score_label: Label = $UI/ChainScoreLabel
@onready var combo_bar: Control = $UI/ComboBar
@onready var celebrator: Control = $UI/ChainCelebrator
@onready var levelup_panel: Control = $UI/LevelUpPanel
@onready var levelup_content: Control = $UI/LevelUpPanel/LevelUpContent
@onready var levelup_label: Label = $UI/LevelUpPanel/LevelUpContent/LevelUpLabel
@onready var levelup_sub_label: Label = $UI/LevelUpPanel/LevelUpContent/LevelUpSubLabel
var levelup_tween: Tween
var levelup_base_pos: Vector2 = Vector2.ZERO

# Ad loading (revive)
@onready var ad_loading_panel: Control = $UI/AdLoadingPanel
@onready var ad_spinner: Control = $UI/AdLoadingPanel/Spinner
var ad_timer: float = 0.0
var ad_waiting: bool = false   # loading ekranı açık, reklam henüz gösterilmedi
var ad_showing: bool = false   # reklam şu anda ekranda (artık sayaç çalışmaz)
var await_interstitial: bool = false  # interstitial gösterildi, kapanınca game-over paneli açılsın
const AD_TIMEOUT: float = 15.0  # reklam bu sürede hiç gelmezse "kaybettiniz"

# Start screen
@onready var start_panel: Control = $UI/StartPanel
@onready var start_button: Button = $UI/StartPanel/StartButton
@onready var gameover_menu_button: Button = $UI/GameOverPanel/MenuButton

# Settings
@onready var settings_panel: Control = $UI/SettingsPanel
@onready var settings_button: Button = $UI/StartPanel/SettingsButton
@onready var settings_close_button: Button = $UI/SettingsPanel/CloseButton
@onready var music_slider: HSlider = $UI/SettingsPanel/MusicSlider
@onready var sfx_slider: HSlider = $UI/SettingsPanel/SfxSlider
@onready var music_value: Label = $UI/SettingsPanel/MusicValue
@onready var sfx_value: Label = $UI/SettingsPanel/SfxValue
const SETTINGS_PATH: String = "user://settings.cfg"

# Pause menu
@onready var pause_panel: Control = $UI/PausePanel
@onready var pause_score_label: Label = $UI/PausePanel/PauseScoreLabel
@onready var continue_button: Button = $UI/PausePanel/ContinueButton
@onready var pause_restart_button: Button = $UI/PausePanel/RestartButton
@onready var menu_button: Button = $UI/PausePanel/MenuButton

# Side panel
@onready var side_panel: Control = $UI/SidePanel
@onready var next_piece_name: Label = $UI/NextPieceName
@onready var next_preview: Node2D = $UI/NextPreview

# Mobile control buttons
@onready var mobile_controls: Control = $UI/MobileControls
@onready var left_button: Button = $UI/MobileControls/LeftButton
@onready var right_button: Button = $UI/MobileControls/RightButton
@onready var rotate_button: Button = $UI/MobileControls/RotateButton
@onready var drop_button: Button = $UI/MobileControls/DropButton
@onready var soft_drop_button: Button = $UI/MobileControls/SoftDropButton
@onready var edge_glow: Node2D = $EdgeGlow

var next_piece_id: int = 0
var is_game_over_handled: bool = false
var game_started: bool = false

# Soft drop hold (S / Down / ▼ button)
var soft_drop_held: bool = false
var soft_drop_timer: float = 0.0
const SOFT_DROP_INTERVAL: float = 0.05

# Chain label animation
var chain_tween: Tween

# --- Kombo penceresi / ateş topu seviyesi -----------------------------------
# Combo bittiğinde bir süre "pencere" açılır; bu süre içinde yeni chain
# gelirse ateş topu sayısı azalmaz, artar. Pencere bitince sıfırlanır.
const COMBO_WINDOW_MAX: float = 5.0
var combo_window_t: float = 0.0
var fire_level: int = 0
var _firing: bool = false

# Bar dolunca birikmiş ateş toplarını fırlatır
func _launch_pending_fire() -> void:
	if _firing or fire_level <= 0:
		return
	_firing = true
	var pending: int = fire_level
	fire_level = 0
	combo_window_t = 0.0
	await _play_brimstone(pending)
	_firing = false
	if combo_bar:
		combo_bar.drain()

# Touch control variables
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touching: bool = false
const SWIPE_THRESHOLD: float = 50.0
const TAP_MAX_DURATION: float = 0.3
# Gestures (tap=rotate, swipe=move) only work over the game board,
# so touching buttons never rotates the piece as a side effect.
const GESTURE_RECT: Rect2 = Rect2(0, 95, 395, 960)

func _ready() -> void:
	grid_manager.reset_grid()
	board_view.init(grid_manager, active_piece)
	active_piece.init(grid_manager)

	# Connect signals
	active_piece.piece_landed.connect(_on_piece_landed)
	grid_manager.blocks_cleared.connect(_on_blocks_cleared)
	if celebrator:
		celebrator.flame_arrived.connect(_on_flame_arrived)
	# Ateş topları CHAIN yazısıyla aynı dikey eksenden çıksın
	if celebrator and chain_label:
		celebrator.fire_origin_x = chain_label.position.x + chain_label.size.x * 0.5
	GameManager.game_over.connect(_on_game_over)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.level_up.connect(_on_level_up)

	# UI buttons
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if revive_button:
		revive_button.pressed.connect(_on_revive_pressed)
	# Reklam ödül kazanınca (düzgünce bitince) revive akışını sürdür
	if AdManager:
		if AdManager.has_signal("reward_earned"):
			AdManager.reward_earned.connect(_on_reward_earned)
		if AdManager.has_signal("ad_shown"):
			AdManager.ad_shown.connect(_on_ad_shown)
		if AdManager.has_signal("ad_ended_no_reward"):
			AdManager.ad_ended_no_reward.connect(_on_ad_no_reward)
		if AdManager.has_signal("interstitial_finished"):
			AdManager.interstitial_finished.connect(_on_interstitial_finished)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)

	# Mobile control buttons
	if left_button:
		left_button.pressed.connect(func(): active_piece.move_left())
	if right_button:
		right_button.pressed.connect(func(): active_piece.move_right())
	if rotate_button:
		rotate_button.pressed.connect(func(): active_piece.rotate_piece())
	if drop_button:
		drop_button.pressed.connect(func(): active_piece.hard_drop())
	if soft_drop_button:
		soft_drop_button.button_down.connect(_on_soft_drop_button_down)

		soft_drop_button.button_up.connect(_on_soft_drop_button_up)

	# Start screen
	if game_over_panel:
		game_over_panel.visible = false
	if start_panel:
		start_panel.visible = true
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	# Hide mobile controls on menu
	if mobile_controls:
		mobile_controls.visible = false
	_set_hud_visible(false)

	# Pause menu
	if pause_panel:
		pause_panel.visible = false
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if pause_restart_button:
		pause_restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	if gameover_menu_button:
		gameover_menu_button.pressed.connect(_on_menu_pressed)

	# Settings
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if settings_close_button:
		settings_close_button.pressed.connect(_on_settings_closed)
	_setup_audio_buses()
	_load_settings()
	if music_slider:
		music_slider.value_changed.connect(_on_music_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_changed)
	if music_value:
		music_value.text = str(int(music_slider.value)) + "%"
	if sfx_value:
		sfx_value.text = str(int(sfx_slider.value)) + "%"
	_style_settings_panel()
	_style_game_over_buttons()
	if settings_panel:
		settings_panel.visible = false

	# Show start state
	_update_ui()
	_style_control_buttons()
	if levelup_panel:
		levelup_base_pos = levelup_content.position
		levelup_panel.visible = false

func _on_start_pressed() -> void:
	if celebrator:
		celebrator.cancel_all()
	if combo_bar:
		combo_bar.drain()
	if start_panel:
		start_panel.visible = false
	_set_hud_visible(true)
	if mobile_controls:
		mobile_controls.visible = true
	_set_controls_enabled(true)
	game_started = true
	GameManager.start_game()
	_spawn_next_piece()
	_update_ui()

func _process(delta: float) -> void:
	# Reklam yükleme: 15 sn say (spinner kendi script'inde döner)
	# Sayaç sadece reklam HENÜZ gösterilmediyken çalışır; reklam ekrandayken durur
	if ad_waiting and not ad_showing:
		ad_timer -= delta
		if ad_timer <= 0.0:
			_ad_timeout()
	# Continuous soft drop while S/Down/▼ is held
	if soft_drop_held and GameManager.is_playing() and active_piece.is_active:
		soft_drop_timer += delta
		while soft_drop_timer >= SOFT_DROP_INTERVAL:
			soft_drop_timer -= SOFT_DROP_INTERVAL
			if not active_piece.move_down():
				# Bottom reached while soft dropping: lock immediately
				active_piece.land()
				break
	if not GameManager.is_playing():
		return
	# Kombo penceresi: bar DOLANA kadar chain serisi devam eder, alev atılmaz.
	# Dolunca birikmiş ateş topu sayısı kadar alev fırlar.
	if combo_window_t > 0.0:
		combo_window_t = maxf(0.0, combo_window_t - delta)
		if combo_bar:
			# 0.0 -> 1.0 : bar doluyor
			combo_bar.progress = 1.0 - combo_window_t / COMBO_WINDOW_MAX
		if combo_window_t <= 0.0 and not _firing:
			_launch_pending_fire()
	if grid_manager.is_game_over() and not is_game_over_handled:
		is_game_over_handled = true
		GameManager.end_game()

func _input(event: InputEvent) -> void:
	if not GameManager.is_playing():
		soft_drop_held = false
		return

	if event is InputEventKey:
		# Soft drop: hold S / Down for fast continuous fall
		if event.keycode == KEY_S or event.keycode == KEY_DOWN:
			if event.pressed and not event.echo:
				soft_drop_held = true
				soft_drop_timer = SOFT_DROP_INTERVAL  # immediate first step
				active_piece.move_down()
			elif not event.pressed:
				soft_drop_held = false
			return
		if event.pressed:
			match event.keycode:
				KEY_LEFT, KEY_A:
					active_piece.move_left()
				KEY_RIGHT, KEY_D:
					active_piece.move_right()
				KEY_UP, KEY_W, KEY_X:
					active_piece.rotate_piece()
				KEY_SPACE:
					active_piece.hard_drop()
				KEY_P, KEY_ESCAPE:
					_on_pause_pressed()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			# Ignore touches on buttons/panels — only the board is gesture-active
			if not GESTURE_RECT.has_point(touch_event.position):
				is_touching = false
				return
			touch_start_pos = touch_event.position
			touch_start_time = Time.get_ticks_msec() / 1000.0
			is_touching = true
		else:
			if is_touching:
				var touch_end_pos: Vector2 = touch_event.position
				var touch_duration: float = (Time.get_ticks_msec() / 1000.0) - touch_start_time
				var delta: Vector2 = touch_end_pos - touch_start_pos
				if touch_duration < TAP_MAX_DURATION and delta.length() < SWIPE_THRESHOLD:
					active_piece.rotate_piece()
				elif delta.length() >= SWIPE_THRESHOLD:
					if abs(delta.x) > abs(delta.y):
						if delta.x > 0:
							active_piece.move_right()
						else:
							active_piece.move_left()
					else:
						if delta.y > 0:
							active_piece.hard_drop()
						else:
							active_piece.rotate_piece()
				is_touching = false
	elif event is InputEventScreenDrag:
		if not is_touching:
			return
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		var delta: Vector2 = drag_event.position - touch_start_pos
		if delta.length() >= SWIPE_THRESHOLD:
			if abs(delta.x) > abs(delta.y):
				if delta.x > 0:
					active_piece.move_right()
				else:
					active_piece.move_left()
			else:
				if delta.y > 0:
					active_piece.move_down()
			touch_start_pos = drag_event.position

func _on_piece_landed() -> void:
	_resolve_chains()

# Zincir çözümü ARTIK ADIM ADIM ilerler:
#   1) eşleşenler patlar (debris + flash)
#   2) kalan bloklar görünür şekilde aşağı düşer
#   3) düşme bitince yeni eşleşmeler kontrol edilir ve tekrar patlar
# Böylece oyuncu "düştü, sonra patladı" sırasını net görür.
var _resolving_chains: bool = false

func _resolve_chains() -> void:
	if _resolving_chains:
		return
	_resolving_chains = true
	# Pencere açıkken gelen chain "devam eden kombo" sayılır: ateş sayısı artar
	var continuing: bool = combo_window_t > 0.0
	var chain: int = 0
	while true:
		var matches: Array = grid_manager.find_matches()
		if matches.size() == 0:
			break
		chain += 1
		var cleared: int = grid_manager.clear_matches(matches)
		if cleared <= 0:
			break
		# Patlama anını görünür kıl (debris/flash sinyalle tetiklenir)
		grid_manager.emit_signal("blocks_cleared", cleared, chain)
		var gain: int = grid_manager.chain_score_gain(cleared, chain)
		if gain > 0:
			GameManager.add_score(gain)
		if chain >= 2:
			_show_chain_score(gain, chain)
			if chain == 2 and celebrator:
				celebrator.play_chain_start()
			if celebrator:
				celebrator.play_snap()
			if combo_bar:
				combo_bar.show_bar()
			# Ateş topu sayısı: chain büyüdükçe artar (birikimli).
			fire_level = maxi(fire_level, chain)
			combo_window_t = COMBO_WINDOW_MAX
			if combo_bar:
				combo_bar.progress = 0.0
		# Patlama izleri okunabilsin diye kısa bekleme
		await get_tree().create_timer(0.16).timeout
		# Ardından yerçekimi: düşüş animasyonu tamamlanana kadar bekle
		var max_dist: int = grid_manager.apply_gravity()
		if max_dist > 0:
			var fall_t: float = clampf(0.10 + float(max_dist) * 0.045, 0.12, 0.50)
			await get_tree().create_timer(fall_t + 0.04).timeout
		# Bir sonraki zincir halkası için küçük nefes payı
		await get_tree().create_timer(0.05).timeout

	# Pencere içinde gelen yeni chain kombo serisini sürdürür: bir adım bonus
	if chain >= 2 and continuing:
		fire_level += 1
	if combo_bar and fire_level > 0:
		combo_bar.charges = fire_level
	# Kombo finali BURADA atılmaz: bar dolana kadar birikir (bkz. _process).

	_resolving_chains = false
	if grid_manager.is_game_over():
		is_game_over_handled = true
		GameManager.end_game()
		return
	_spawn_next_piece()


# Chain skorunu zincir yazısının altında gösterir
func _show_chain_score(gain: int, chain: int) -> void:
	if not chain_score_label:
		return
	chain_score_label.text = "+" + str(gain)
	chain_score_label.modulate = Color(0.55, 1.0, 0.60) if chain < 4 else Color(1.0, 0.82, 0.35)
	chain_score_label.modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(chain_score_label, "modulate:a", 0.0, 0.55)		.set_delay(0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# Combo bitti: alevler SIRAYLA fırlar; her alev bir hücreyi yok eder,
# ardından yerçekimi uygulanır ve sonraki alev çıkar (bam-bam-bam).
func _play_brimstone(chain: int) -> void:
	if not celebrator:
		return
	var cells: Array = grid_manager.get_occupied_cells()
	cells.shuffle()
	# Ateş topu sayısı: pencere/chain seviyesiyle artan değer
	var want: int = maxi(fire_level, chain)
	var count: int = mini(want, cells.size())
	var targets: Array = []
	for i in range(count):
		var cell: Vector2i = cells[i]
		targets.append({"cell": cell, "pos": _cell_to_screen(cell)})
	if combo_bar:
		combo_bar.drain()
	await celebrator.play_combo_end(targets)

	# Alev sonrası oluşan eşleşmeler: chain gibi sayılır ve görünür olur
	var waves: int = 0
	while waves < 8:
		var m: Array = grid_manager.find_matches()
		if m.size() == 0:
			break
		waves += 1
		var cleared: int = grid_manager.clear_matches(m)
		if cleared <= 0:
			break
		grid_manager.emit_signal("blocks_cleared", cleared, waves)
		var g: int = grid_manager.chain_score_gain(cleared, waves + 1)
		GameManager.add_score(g)
		_show_chain_score(g, waves + 1)
		await get_tree().create_timer(0.16).timeout
		var md: int = grid_manager.apply_gravity()
		if md > 0:
			await get_tree().create_timer(clampf(0.10 + float(md) * 0.045, 0.12, 0.50) + 0.04).timeout


# Bir alev hücreye ulaştı: blok yanar (yok edilir), yerçekimi uygulanır
func _on_flame_arrived(cell: Vector2i) -> void:
	var destroyed: int = grid_manager.destroy_cell(cell)
	if destroyed >= 0:
		GameManager.add_score(15)
		grid_manager.apply_gravity()


# Izgara hücresi -> ekran koordinatı (BoardView: pos 10,105 + 36px hücre)
func _cell_to_screen(cell: Vector2i) -> Vector2:
	var origin: Vector2 = board_view.position if board_view else Vector2(10, 105)
	var cs: float = 36.0
	return Vector2(origin.x + float(cell.x) * cs + cs * 0.5,
		origin.y + float(cell.y - 2) * cs + cs * 0.5)

func _on_soft_drop_button_down() -> void:
	soft_drop_held = true
	soft_drop_timer = SOFT_DROP_INTERVAL
	active_piece.move_down()

func _on_soft_drop_button_up() -> void:
	soft_drop_held = false

# ---------- Ses / Ayarlar ----------
# Master dışında "Music" ve "SFX" bus'ları yoksa oluşturur.
func _setup_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _bus_volume_to_slider(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 100.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	var db: float = AudioServer.get_bus_volume_db(idx)
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)

func _apply_bus_volume(bus_name: String, percent: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if percent <= 0.0:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(percent / 100.0))

func _load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var music: float = 100.0
	var sfx: float = 100.0
	if cfg.load(SETTINGS_PATH) == OK:
		music = float(cfg.get_value("audio", "music", 100.0))
		sfx = float(cfg.get_value("audio", "sfx", 100.0))
	if music_slider:
		music_slider.set_value_no_signal(music)
	if sfx_slider:
		sfx_slider.set_value_no_signal(sfx)
	_apply_bus_volume("Music", music)
	_apply_bus_volume("SFX", sfx)

func _save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "music", music_slider.value if music_slider else 100.0)
	cfg.set_value("audio", "sfx", sfx_slider.value if sfx_slider else 100.0)
	cfg.save(SETTINGS_PATH)

func _on_music_changed(value: float) -> void:
	if music_value:
		music_value.text = str(int(value)) + "%"
	_apply_bus_volume("Music", value)
	_save_settings()

func _on_sfx_changed(value: float) -> void:
	if sfx_value:
		sfx_value.text = str(int(value)) + "%"
	_apply_bus_volume("SFX", value)
	_save_settings()

func _on_settings_pressed() -> void:
	if settings_panel:
		settings_panel.visible = true
		settings_panel.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(settings_panel, "modulate:a", 1.0, 0.15)

func _on_settings_closed() -> void:
	if settings_panel:
		settings_panel.visible = false

func _style_settings_panel() -> void:
	if settings_button:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.11, 0.18, 0.9)
		sb.border_color = Color(0.45, 0.50, 0.85, 0.45)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(18)
		settings_button.add_theme_stylebox_override("normal", sb)
		var hover: StyleBoxFlat = sb.duplicate()
		hover.bg_color = Color(0.14, 0.16, 0.26, 0.95)
		hover.border_color = Color(0.55, 0.65, 1.0, 0.75)
		settings_button.add_theme_stylebox_override("hover", hover)
		var pressed: StyleBoxFlat = sb.duplicate()
		pressed.bg_color = Color(0.08, 0.09, 0.15, 0.95)
		settings_button.add_theme_stylebox_override("pressed", pressed)
		settings_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		settings_button.add_theme_color_override("font_color", Color(0.72, 0.78, 0.95))
		settings_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	if settings_close_button:
		var cb: StyleBoxFlat = StyleBoxFlat.new()
		cb.bg_color = Color(0.12, 0.13, 0.22, 0.95)
		cb.border_color = Color(0.45, 0.50, 0.85, 0.5)
		cb.set_border_width_all(2)
		cb.set_corner_radius_all(20)
		settings_close_button.add_theme_stylebox_override("normal", cb)
		settings_close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

# Game over butonları: parlak olmasın, arka planla kaynaşsın (soluk/silik)
func _style_game_over_buttons() -> void:
	for btn in [revive_button, restart_button, gameover_menu_button]:
		if not btn:
			continue
		var normal: StyleBoxFlat = StyleBoxFlat.new()
		normal.bg_color = Color(0.10, 0.10, 0.17, 0.65)
		normal.border_color = Color(0.30, 0.32, 0.45, 0.35)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(20)
		var hover: StyleBoxFlat = normal.duplicate()
		hover.bg_color = Color(0.15, 0.16, 0.25, 0.85)
		hover.border_color = Color(0.40, 0.45, 0.65, 0.55)
		var pressed: StyleBoxFlat = normal.duplicate()
		pressed.bg_color = Color(0.08, 0.08, 0.14, 0.9)
		pressed.border_color = Color(0.45, 0.50, 0.70, 0.7)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("hover_pressed", pressed)
		btn.add_theme_stylebox_override("disabled", normal)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82))
		btn.add_theme_color_override("font_hover_color", Color(0.95, 0.97, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.88, 0.90, 0.98))
		btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.46, 0.52))

# Oyun bittiğinde/durduğunda alt kontrol tuşlarını soluk + devre dışı yapar
func _set_controls_enabled(enabled: bool) -> void:
	if not mobile_controls:
		return
	if enabled:
		mobile_controls.modulate = Color(1, 1, 1, 1)
	else:
		mobile_controls.modulate = Color(0.55, 0.58, 0.72, 0.40)
	for b in [left_button, right_button, soft_drop_button, drop_button, rotate_button]:
		if b:
			b.disabled = not enabled

# Mobil kontrol tuşlarına tema uyumlu görünüm verir (düz klavye tuşu gibi durmasın)
func _style_control_buttons() -> void:
	_style_control_button(left_button, Color(0.35, 0.80, 1.00))
	_style_control_button(soft_drop_button, Color(0.45, 0.62, 1.00))
	_style_control_button(drop_button, Color(1.00, 0.62, 0.16))
	_style_control_button(rotate_button, Color(0.72, 0.48, 1.00))
	_style_control_button(right_button, Color(0.35, 0.80, 1.00))

func _style_control_button(btn: Button, accent: Color) -> void:
	if not btn:
		return
	var base_bg: Color = Color(0.075, 0.085, 0.145).lerp(accent, 0.20)
	var hover_bg: Color = Color(0.09, 0.10, 0.17).lerp(accent, 0.32)
	var press_bg: Color = Color(0.06, 0.07, 0.12).lerp(accent, 0.62)

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = base_bg
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(24)
	normal.shadow_color = Color(0, 0, 0, 0.40)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	normal.set_content_margin_all(4)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = hover_bg
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.85)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = press_bg
	pressed.border_color = accent.lightened(0.25)
	pressed.set_border_width_all(3)
	# neon his: kenarın arkasında renkli glow, gölge yok (tuş yüzeye oturur)
	pressed.shadow_color = Color(accent.r, accent.g, accent.b, 0.55)
	pressed.shadow_size = 9
	pressed.shadow_offset = Vector2.ZERO

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.07, 0.07, 0.10)
	disabled.border_color = Color(0.25, 0.26, 0.32, 0.6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", accent.lightened(0.55))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_focus_color", accent.lightened(0.55))

	# Basma hissi: tuş hafifçe aşağı çöker, sembol de onunla iner
	btn.button_down.connect(func(): _animate_button_press(btn, true))
	btn.button_up.connect(func(): _animate_button_press(btn, false))

func _animate_button_press(btn: Button, is_down: bool) -> void:
	if not btn:
		return
	if not btn.has_meta("rest_pos"):
		btn.set_meta("rest_pos", btn.position)
	var rest: Vector2 = btn.get_meta("rest_pos")
	var prev_tween: Variant = btn.get_meta("press_tween", null)
	if prev_tween is Tween and (prev_tween as Tween).is_valid():
		(prev_tween as Tween).kill()
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	var art: Control = btn.get_node_or_null("Art")
	if art:
		art.pivot_offset = art.size * 0.5
	if is_down:
		tw.set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "position", rest + Vector2(0, 5), 0.06)
		tw.parallel().tween_property(btn, "modulate", Color(0.88, 0.90, 1.0), 0.06)
		if art:
			tw.parallel().tween_property(art, "scale", Vector2(0.94, 0.94), 0.06)
	else:
		tw.set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "position", rest, 0.12)
		tw.parallel().tween_property(btn, "modulate", Color.WHITE, 0.12)
		if art:
			tw.parallel().tween_property(art, "scale", Vector2.ONE, 0.12)
	btn.set_meta("press_tween", tw)

func _on_blocks_cleared(count: int, chain_level: int) -> void:
	GameManager.update_chain(chain_level)
	# Yüksek chain: ekran kenarları parlar
	if edge_glow and chain_level >= 3:
		var glow_col: Color = Color(1.0, 0.85, 0.25)
		if chain_level >= 5:
			glow_col = Color(1.0, 0.45, 0.85)
		elif chain_level >= 4:
			glow_col = Color(1.0, 0.60, 0.22)
		edge_glow.trigger(glow_col, clampf(0.55 + 0.15 * float(chain_level), 0.6, 1.3))
	if not chain_label:
		return
	# Kill previous animation
	if chain_tween and chain_tween.is_valid():
		chain_tween.kill()
	# Reset transform for pop-in
	chain_label.pivot_offset = Vector2(chain_label.size.x * 0.5, chain_label.size.y * 0.5)
	chain_label.scale = Vector2(0.2, 0.2)
	chain_label.rotation_degrees = 0.0
	if chain_level > 1:
		chain_label.text = "CHAIN x" + str(chain_level) + "!"
		chain_label.modulate = Color(1, 0.85, 0.2)
	else:
		chain_label.text = "+" + str(count * 10) + " pts"
		chain_label.modulate = Color(0.45, 1.0, 0.45)
	chain_label.modulate.a = 1.0

	# Big pop + wobble + fade out animation
	var big_scale: Vector2 = Vector2(1.4, 1.4) if chain_level <= 1 else Vector2(1.75, 1.75)
	chain_tween = create_tween()
	# Pop in with overshoot + tilt
	chain_tween.tween_property(chain_label, "scale", big_scale, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	chain_tween.parallel().tween_property(chain_label, "rotation_degrees", 7.0, 0.12)
	# Wobble back
	chain_tween.tween_property(chain_label, "rotation_degrees", -6.0, 0.14)
	chain_tween.tween_property(chain_label, "rotation_degrees", 0.0, 0.1)
	chain_tween.tween_property(chain_label, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Hold, then fade out
	chain_tween.tween_property(chain_label, "modulate:a", 0.0, 0.7)\
		.set_delay(0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _spawn_next_piece() -> void:
	# Use pre-rolled next_piece_id, then roll a new one
	if next_piece_id == -1:
		next_piece_id = Piece.get_random_piece_id()
	active_piece.spawn_new_piece_with_id(next_piece_id)
	# Roll new next piece with random colors
	next_piece_id = Piece.get_random_piece_id()
	var next_data = Piece.get_random_colored_piece(next_piece_id)
	if next_piece_name:
		next_piece_name.text = next_data.name
	# Update visual preview
	if next_preview:
		next_preview.set_piece(next_data)
		next_preview.queue_redraw()

func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = "Score: " + str(new_score)
	if high_score_label:
		high_score_label.text = "Best: " + str(GameManager.high_score)

func _on_level_changed(new_level: int) -> void:
	if level_label:
		level_label.text = "Level: " + str(new_level)

func _on_level_up(new_level: int) -> void:
	if not levelup_panel or not levelup_content or not levelup_label:
		return
	# Aynı anda yeni level gelirse eski animasyonu kes
	if levelup_tween and levelup_tween.is_valid():
		levelup_tween.kill()

	levelup_panel.visible = true
	levelup_panel.modulate = Color(1, 1, 1, 1)
	# Örtü sabit kalır; yalnızca yazı bloğu hareket eder
	levelup_content.pivot_offset = Vector2(levelup_content.size.x * 0.5, levelup_content.size.y * 0.5)
	levelup_content.scale = Vector2(0.15, 0.15)
	levelup_content.rotation_degrees = -12.0
	levelup_content.position = levelup_base_pos
	levelup_label.modulate = Color(1, 1, 1, 1)
	levelup_sub_label.text = "(Speed +25%)  Lv." + str(new_level)

	# Renkli dalga: hızlı renk geçişleri
	var rainbow: Array[Color] = [
		Color(1.0, 0.25, 0.35),  # kırmızı
		Color(1.0, 0.65, 0.15),  # turuncu
		Color(1.0, 0.95, 0.2),   # sarı
		Color(0.35, 1.0, 0.4),   # yeşil
		Color(0.25, 0.85, 1.0),  # camgöbeği
		Color(0.55, 0.45, 1.0),  # mor
		Color(1.0, 0.45, 0.9),   # pembe
	]

	levelup_tween = create_tween()
	# 1) Hızlı pop-in (overshoot) + dönerek düzel
	levelup_tween.tween_property(levelup_content, "scale", Vector2(1.25, 1.25), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	levelup_tween.parallel().tween_property(levelup_content, "rotation_degrees", 6.0, 0.18)
	# Renk dalgası boyunca
	for i in range(rainbow.size()):
		levelup_tween.tween_property(levelup_label, "modulate", rainbow[i], 0.075)
	# 2) Yerine otur + hafif salınım
	levelup_tween.tween_property(levelup_content, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	levelup_tween.parallel().tween_property(levelup_content, "rotation_degrees", -4.0, 0.16)
	levelup_tween.tween_property(levelup_content, "rotation_degrees", 0.0, 0.12)
	# 3) Kısa bekleme (ekranda uzun kalmadan)
	levelup_tween.tween_interval(0.4)
	# 4) Aynı hareketle hızlıca çık: büyüyüp yukarı kayarak kaybol
	levelup_tween.tween_property(levelup_content, "scale", Vector2(1.55, 1.55), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	levelup_tween.parallel().tween_property(levelup_content, "position:y", levelup_base_pos.y - 90.0, 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	levelup_tween.parallel().tween_property(levelup_content, "rotation_degrees", 14.0, 0.25)
	levelup_tween.parallel().tween_property(levelup_panel, "modulate:a", 0.0, 0.25)
	levelup_tween.tween_callback(_hide_levelup)

func _hide_levelup() -> void:
	if levelup_panel:
		levelup_panel.visible = false
	if levelup_label:
		levelup_label.modulate = Color(1, 1, 1, 1)

func _on_game_over() -> void:
	# Oyun bitti: alt kontrol tuşları soluk + devre dışı (panel örtüsünün altında kalır)
	_set_controls_enabled(false)
	if game_over_score:
		game_over_score.text = "Score: " + str(GameManager.score)
	var go_high = $UI/GameOverPanel/HighScoreLabel
	if go_high:
		go_high.text = "Best: " + str(GameManager.high_score)
	if revive_button:
		revive_button.visible = not GameManager.revive_used
	# Interstitial akışı:
	# - Normal game over (revive hakkı varken): 5sn interstitial 1 kez gösterilir,
	#   game-over paneli ancak reklam KAPANINCA açılır (öylece ödüllü reklamla yarışmaz/çakışmaz).
	# - Revive sonrası tekrar kaybedince: interstitial yok, panel direkt açılır (2. kez 5sn atılmaz).
	if AdManager and not GameManager.revive_used and AdManager.has_signal("interstitial_finished"):
		var shown: bool = AdManager.show_interstitial()
		if shown:
			await_interstitial = true
			if game_over_panel:
				game_over_panel.visible = false  # interstitial kapanınca açılacak
			return
	# Interstitial yok / yüklenmedi / revive kullanıldı → panel direkt açılır
	await_interstitial = false
	if game_over_panel:
		game_over_panel.visible = true

func _on_interstitial_finished() -> void:
	# Interstitial kapandı (veya gösterilemedi) → şimdi game-over panelini göster
	if not await_interstitial:
		return
	await_interstitial = false
	if game_over_panel:
		game_over_panel.visible = true

func _on_restart_pressed() -> void:
	# Oyunu baştan başlat: tahta temizle, skor sıfırla, pause/game-over panelini kapat
	grid_manager.reset_grid()
	# Kombo/ateş durumunu da sıfırla
	fire_level = 0
	combo_window_t = 0.0
	_firing = false
	if combo_bar:
		combo_bar.drain()
	is_game_over_handled = false
	next_piece_id = -1
	game_started = true
	if pause_panel:
		pause_panel.visible = false
	if game_over_panel:
		game_over_panel.visible = false
	if start_panel:
		start_panel.visible = false
	_set_hud_visible(true)
	if mobile_controls:
		mobile_controls.visible = true
	_set_controls_enabled(true)
	if pause_button:
		pause_button.text = "II"
	GameManager.start_game()
	_spawn_next_piece()
	_update_ui()

func _on_revive_pressed() -> void:
	if GameManager.revive_used:
		return
	if ad_waiting or ad_showing:
		return  # zaten reklam akışında, tekrar basma sayacı sıfırlamasın
	# Loading ekranı: ortada dönen şey + 15 sn sayacı başlat
	if game_over_label:
		game_over_label.text = "GAME OVER"
	if game_over_panel:
		game_over_panel.visible = false
	if ad_loading_panel:
		ad_loading_panel.visible = true
	ad_timer = AD_TIMEOUT
	ad_waiting = true
	ad_showing = false
	# Reklamı başlat
	if AdManager:
		AdManager.show_rewarded()

func _on_ad_shown() -> void:
	# Ödüllü reklam ekranda göründü → yükleme sayacını durdur,
	# böylece uzun reklamlarda 15sn timeout ödülü yutmez
	if not ad_waiting and not ad_showing:
		return  # revive akışıyla ilgisi olmayan bir reklam
	ad_showing = true
	ad_waiting = false
	if ad_loading_panel:
		ad_loading_panel.visible = false

func _on_reward_earned() -> void:
	# Reklam düzgünce izlenip bitti → loading kapat, patlama + yeniden doğuş
	if not ad_waiting and not ad_showing:
		return
	_end_ad_wait()
	_revive_game()

func _on_ad_no_reward() -> void:
	# Reklam kapandı ama ödül kazanılmadı (erken kapattı) → "Kaybettiniz"
	if not ad_showing:
		return
	_end_ad_wait()
	_show_game_over_lost()

func _ad_timeout() -> void:
	# 15 sn içinde reklam hiç ekrana gelmedi → loading kapat, "Kaybettiniz" geri gelsin
	_end_ad_wait()
	_show_game_over_lost()

func _end_ad_wait() -> void:
	ad_waiting = false
	ad_showing = false
	if ad_loading_panel:
		ad_loading_panel.visible = false

func _show_game_over_lost() -> void:
	_set_controls_enabled(false)
	if game_over_label:
		game_over_label.text = "KAYBETTİNİZ!"
	if game_over_panel:
		game_over_panel.visible = true
	if game_over_score:
		game_over_score.text = "Score: " + str(GameManager.score)
	if revive_button:
		revive_button.visible = not GameManager.revive_used

func _revive_game() -> void:
	_set_hud_visible(true)
	# PATLAMA: tüm dolu hücrelerin rengini al
	var cells_to_explode: Array = []
	for row in range(grid_manager.GRID_HEIGHT + grid_manager.BUFFER_ROWS):
		for col in range(grid_manager.GRID_WIDTH):
			var c: int = grid_manager.get_cell_color(col, row)
			if c >= 0:
				cells_to_explode.append({"pos": Vector2i(col, row), "color": c})
	# Tüm hücreleri temizle
	for row in range(grid_manager.GRID_HEIGHT + grid_manager.BUFFER_ROWS):
		for col in range(grid_manager.GRID_WIDTH):
			grid_manager.clear_cell(col, row)
	# Patlama efekti: beyaz flash + her hücre için debris
	if board_view:
		board_view.clear_flash = 1.0
		for cell in cells_to_explode:
			board_view._spawn_debris(cell.pos, cell.color)
		board_view.queue_redraw()
	grid_manager.emit_signal("grid_changed")
	# Skor korunur, sadece durum PLAYING'e döner
	GameManager.revive()
	is_game_over_handled = false
	if game_over_panel:
		game_over_panel.visible = false
	_set_controls_enabled(true)
	_spawn_next_piece()

func _on_pause_pressed() -> void:
	if GameManager.is_playing():
		GameManager.pause_game()
		_set_controls_enabled(false)
		if pause_panel:
			pause_panel.visible = true
			if pause_score_label:
				pause_score_label.text = "Score: " + str(GameManager.score)
		if pause_button:
			pause_button.text = "▶"
	else:
		GameManager.resume_game()
		_set_controls_enabled(true)
		if pause_panel:
			pause_panel.visible = false
		if pause_button:
			pause_button.text = "II"

func _on_continue_pressed() -> void:
	GameManager.resume_game()
	_set_controls_enabled(true)
	if pause_panel:
		pause_panel.visible = false
	if pause_button:
		pause_button.text = "II"

func _set_hud_visible(is_visible: bool) -> void:
	var nodes: Array = [
		$UI/HeaderBG, $UI/ScoreLabel, $UI/LevelLabel, $UI/NextLabel,
		$UI/HighScoreLabel, $UI/PauseButton, $UI/SidePanel,
	]
	for n in nodes:
		if n:
			n.visible = is_visible

func _on_menu_pressed() -> void:
	GameManager.reset_to_menu()
	_set_hud_visible(false)
	if pause_panel:
		pause_panel.visible = false
	if game_over_panel:
		game_over_panel.visible = false
	if settings_panel:
		settings_panel.visible = false
	if start_panel:
		start_panel.visible = true
	if mobile_controls:
		mobile_controls.visible = false
	if pause_button:
		pause_button.text = "II"
	is_game_over_handled = false
	next_piece_id = -1
	grid_manager.reset_grid()
	_update_ui()

func _update_ui() -> void:
	if score_label:
		score_label.text = "Score: " + str(GameManager.score)
	if level_label:
		level_label.text = "Level: " + str(GameManager.level)
	if high_score_label:
		high_score_label.text = "Best: " + str(GameManager.high_score)
