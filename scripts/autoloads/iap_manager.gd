class_name IAPManager
extends Node

var _products: Dictionary = {}
var _purchased: Dictionary = {}  # product_id → bool

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, error: String)

func setup(data: Dictionary) -> void:
	_products = data
	for pid in _products:
		_purchased[pid] = false

func purchase(product_id: String) -> void:
	if product_id not in _products:
		purchase_failed.emit(product_id, "Unknown product")
		return
	if _purchased.get(product_id, false):
		purchase_failed.emit(product_id, "Already purchased")
		return
	# TODO: In release, call Google Play Billing plugin here instead of stub
	if OS.is_debug_build():
		_on_purchase_success(product_id)
	else:
		# TODO: Integrate Google Play Billing Library via plugin
		# For now, stub mode in release too until plugin is wired
		_on_purchase_success(product_id)

func _on_purchase_success(product_id: String) -> void:
	_purchased[product_id] = true
	_apply_product(product_id)
	purchase_completed.emit(product_id)

func _apply_product(product_id: String) -> void:
	match product_id:
		"no_ads":
			GameManager.no_ads = true
			AdManager.hide_banner()
		"starter_pack":
			var rewards: Dictionary = _products.get("starter_pack", {}).get("rewards", {})
			var orbit_count: int = int(rewards.get("orbits", 50))
			GameManager.prestige.add_orbits(orbit_count)
			EventBus.resource_changed.emit("orbits", float(orbit_count), float(GameManager.prestige.get_available_orbits()))
			# TODO: offline_boost_hours — implement when offline boost system supports timed bonuses

func is_purchased(product_id: String) -> bool:
	return _purchased.get(product_id, false)

func restore_purchases() -> void:
	# Stub: restore from save data (already loaded via load_state)
	for pid in _purchased:
		if _purchased[pid]:
			_apply_product(pid)

func get_state() -> Dictionary:
	return _purchased.duplicate()

func load_state(state: Dictionary) -> void:
	for pid in state:
		if pid in _purchased:
			_purchased[pid] = bool(state[pid])
	# Re-apply active purchases (e.g. no_ads flag)
	for pid in _purchased:
		if _purchased[pid]:
			_apply_product(pid)
