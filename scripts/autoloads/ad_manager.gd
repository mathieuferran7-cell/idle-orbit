extends Node

var _ads_config: Dictionary = {}
var _is_available: bool = false

# Rewarded
var _rewarded_ad: RewardedAd = null
var _reward_callback: Callable
var _reward_listener: OnUserEarnedRewardListener
var _load_callback: RewardedAdLoadCallback
var _content_callback: FullScreenContentCallback

# Banner
var _ad_view: AdView = null

func _ready() -> void:
	_ads_config = _read_json("res://data/ads.json")
	# Check if AdMob classes are available (only on Android with plugin)
	if not ClassDB.class_exists("MobileAds"):
		push_warning("AdManager: AdMob not available (desktop/editor mode)")
		return
	_is_available = true
	MobileAds.initialize()
	_setup_callbacks()
	_preload_rewarded()

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data

func _setup_callbacks() -> void:
	_reward_listener = OnUserEarnedRewardListener.new()
	_reward_listener.on_user_earned_reward = _on_user_earned_reward

	_load_callback = RewardedAdLoadCallback.new()
	_load_callback.on_ad_loaded = _on_rewarded_loaded
	_load_callback.on_ad_failed_to_load = _on_rewarded_failed

	_content_callback = FullScreenContentCallback.new()
	_content_callback.on_ad_dismissed_full_screen_content = _on_ad_dismissed

# ── Rewarded ─────────────────────────────────────────────────────────────────

func _preload_rewarded() -> void:
	if not _is_available:
		return
	var id: String = _ads_config.get("rewarded_id", "")
	if id.is_empty():
		return
	RewardedAdLoader.new().load(id, AdRequest.new(), _load_callback)

func show_rewarded(callback: Callable) -> void:
	if not _is_available or _rewarded_ad == null:
		# Fallback: give reward immediately
		callback.call()
		return
	_reward_callback = callback
	_rewarded_ad.full_screen_content_callback = _content_callback
	_rewarded_ad.show(_reward_listener)

func _on_rewarded_loaded(ad: RewardedAd) -> void:
	_rewarded_ad = ad

func _on_rewarded_failed(_error: LoadAdError) -> void:
	_rewarded_ad = null

func _on_user_earned_reward(_item: RewardedItem) -> void:
	if _reward_callback:
		_reward_callback.call()
		_reward_callback = Callable()

func _on_ad_dismissed() -> void:
	if _rewarded_ad:
		_rewarded_ad.destroy()
		_rewarded_ad = null
	_preload_rewarded()

# ── Banner ───────────────────────────────────────────────────────────────────

func show_banner() -> void:
	if not _is_available:
		return
	if _ad_view:
		return
	var id: String = _ads_config.get("banner_id", "")
	if id.is_empty():
		return
	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_ad_view = AdView.new(id, ad_size, AdPosition.Values.BOTTOM)
	_ad_view.load_ad(AdRequest.new())

func hide_banner() -> void:
	if _ad_view:
		_ad_view.destroy()
		_ad_view = null
