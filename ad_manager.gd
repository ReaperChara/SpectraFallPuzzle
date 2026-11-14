extends Node
@onready var admob: Admob = $Admob

# ============================================================================
# Reklam yolu: AdMob (tek ag). Chartboost tamamen kaldirildi (v32).
# ============================================================================
signal reward_earned  # Reklam düzgünce izlenip bitince tetiklenir
signal ad_shown       # Ödüllü reklam ekranda gösterildi (artık sayacı durdur)
signal ad_ended_no_reward  # Reklam kapandı ama ödül kazanılmadı (erken kapattı)
signal interstitial_finished  # Interstitial kapandı veya gösterilemedi (paneli aç)

var is_interstitial_loaded: bool = false
var is_rewarded_loaded: bool = false
var is_banner_loaded: bool = false
var _reward_earned_this_ad: bool = false
var _initialized: bool = false

func _ready() -> void:
	# RequestConfiguration (test cihazı ID'si dahil) initialize'dan ÖNCE ayarlanmalı,
	# yoksa Google test cihazını tanımaz ve yeni uygulamada "no fill" (3) döner.
	if admob:
		admob.set_request_configuration()
		admob.initialize()
		_initialized = true
		# Ödüllü reklam sinyallerini bağla
		if admob.has_signal("rewarded_ad_user_earned_reward"):
			admob.rewarded_ad_user_earned_reward.connect(_on_rewarded_user_earned_reward)
		if admob.has_signal("rewarded_ad_showed_full_screen_content"):
			admob.rewarded_ad_showed_full_screen_content.connect(_on_rewarded_ad_showed)
		if admob.has_signal("rewarded_ad_dismissed_full_screen_content"):
			admob.rewarded_ad_dismissed_full_screen_content.connect(_on_rewarded_ad_dismissed)
		# Interstitial sinyalleri
		if admob.has_signal("interstitial_ad_dismissed_full_screen_content"):
			admob.interstitial_ad_dismissed_full_screen_content.connect(_on_interstitial_ad_dismissed)
		if admob.has_signal("interstitial_ad_failed_to_show_full_screen_content"):
			admob.interstitial_ad_failed_to_show_full_screen_content.connect(_on_interstitial_ad_failed_to_show_full_screen_content)
		# Init/banner/interstitial/rewarded sinyalleri ad_manager.tscn içinde
		# [connection] olarak bağlı — burada tekrar bağlamıyoruz (çift bağlama hatası).


# ============================================================================
# AdMob signal handler'lari
# ============================================================================
func _on_rewarded_ad_showed(ad_info) -> void:
	# Reklam ekranda — yükleme sayacı artık gereksiz
	emit_signal("ad_shown")

func _on_rewarded_ad_dismissed(ad_info) -> void:
	# Reklam kapandı. Eğer ödül kazanılmadıysa kullanıcı erken kapattı demektir.
	if not _reward_earned_this_ad:
		emit_signal("ad_ended_no_reward")
	_reward_earned_this_ad = false

func _on_rewarded_user_earned_reward(ad_info, reward_data) -> void:
	_reward_earned_this_ad = true
	emit_signal("reward_earned")

func _on_interstitial_ad_dismissed(ad_info) -> void:
	emit_signal("interstitial_finished")

func _on_interstitial_ad_failed_to_show_full_screen_content(ad_info, error_info) -> void:
	emit_signal("interstitial_finished")

func _on_admob_initialization_completed(status_data) -> void:
	admob.load_banner_ad()
	admob.load_interstitial_ad()
	admob.load_rewarded_ad()

func _on_admob_banner_ad_loaded(ad_info, response_info) -> void:
	is_banner_loaded = true
	admob.show_banner_ad()

func _on_admob_interstitial_ad_loaded(ad_info, response_info) -> void:
	is_interstitial_loaded = true

func _on_admob_rewarded_ad_loaded(ad_info, response_info) -> void:
	is_rewarded_loaded = true


# ============================================================================
# Genel arayuz - main_scene.gd bunlari cagirir
# ============================================================================
func show_interstitial() -> bool:
	if not _initialized:
		return false
	if is_interstitial_loaded:
		is_interstitial_loaded = false
		admob.show_interstitial_ad()
		admob.load_interstitial_ad()
		return true
	return false


func show_rewarded() -> bool:
	if not _initialized:
		return false
	if is_rewarded_loaded:
		print("[AdManager] show_rewarded: REWARDED var, gosteriliyor")
		is_rewarded_loaded = false
		admob.show_rewarded_ad()
		admob.load_rewarded_ad()
		return true
	print("[AdManager] show_rewarded: REWARDED HAZIR DEGIL (is_rewarded_loaded=", is_rewarded_loaded, ")")
	return false
