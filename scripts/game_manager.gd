# game_manager.gd - Game state, score, flow control (Autoload Singleton)
extends Node

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

var current_state: GameState = GameState.MENU
var score: int = 0
var high_score: int = 0
var level: int = 1
var lines_cleared: int = 0
var chain_count: int = 0
var max_chain: int = 0
var revive_used: bool = false  # Only one revive per game

signal state_changed(new_state: GameState)
signal score_changed(new_score: int)
signal level_changed(new_level: int)
signal level_up(new_level: int)
signal game_started
signal game_over
signal game_paused
signal game_resumed

const BASE_DROP_INTERVAL: float = 1.0  # seconds
const MIN_DROP_INTERVAL: float = 0.1
const LEVEL_SPEED_FACTOR: float = 0.05
const SCORE_PER_LEVEL: int = 1000
const SPEED_STEP: float = 0.25  # her seviyede hız %25 artar

func _ready() -> void:
	load_high_score()

func start_game() -> void:
	score = 0
	level = 1
	lines_cleared = 0
	chain_count = 0
	max_chain = 0
	revive_used = false
	current_state = GameState.PLAYING
	emit_signal("state_changed", current_state)
	emit_signal("game_started")
	emit_signal("score_changed", score)
	emit_signal("level_changed", level)

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		emit_signal("state_changed", current_state)
		emit_signal("game_paused")

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		emit_signal("state_changed", current_state)
		emit_signal("game_resumed")

func end_game() -> void:
	current_state = GameState.GAME_OVER
	if score > high_score:
		high_score = score
		save_high_score()
	emit_signal("state_changed", current_state)
	emit_signal("game_over")

func revive() -> void:
	if revive_used:
		return
	revive_used = true
	current_state = GameState.PLAYING
	emit_signal("state_changed", current_state)
	emit_signal("game_resumed")

func add_score(points: int) -> void:
	score += points
	emit_signal("score_changed", score)
	# Her 1000 skorda bir seviye atla (birikimli)
	var new_level: int = (score / SCORE_PER_LEVEL) + 1
	while new_level > level:
		level += 1
		emit_signal("level_changed", level)
		emit_signal("level_up", level)

func add_lines(count: int) -> void:
	lines_cleared += count
	# Not: seviye artık skor bazlı (her SCORE_PER_LEVEL puan) ilerliyor.

func update_chain(chain_level: int) -> void:
	chain_count = chain_level
	if chain_level > max_chain:
		max_chain = chain_level

func get_drop_interval() -> float:
	# Her seviyede düşme HIZI %25 artar (aralık 1.25e bölünür)
	var speed_mult: float = pow(1.0 + SPEED_STEP, level - 1)
	return max(BASE_DROP_INTERVAL / speed_mult, MIN_DROP_INTERVAL)

func is_playing() -> bool:
	return current_state == GameState.PLAYING

func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER

func reset_to_menu() -> void:
	score = 0
	level = 1
	lines_cleared = 0
	chain_count = 0
	max_chain = 0
	revive_used = false
	current_state = GameState.MENU
	emit_signal("state_changed", current_state)
	emit_signal("score_changed", score)
	emit_signal("level_changed", level)

func save_high_score() -> void:
	var file = FileAccess.open("user://high_score.save", FileAccess.WRITE)
	if file:
		file.store_var(high_score)
		file.close()

func load_high_score() -> void:
	if FileAccess.file_exists("user://high_score.save"):
		var file = FileAccess.open("user://high_score.save", FileAccess.READ)
		if file:
			high_score = file.get_var()
			file.close()
