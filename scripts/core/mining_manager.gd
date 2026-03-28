class_name MiningManager
extends Node

var _cooldown_remaining: float = 0.0
var _tech_per_tap: float = 1.0
var _tap_cooldown: float = 0.15
var _auto_tap_timer: float = 0.0

func setup(balance: Dictionary) -> void:
	_tech_per_tap = float(balance.get("mining_tech_per_tap", 1.0))
	_tap_cooldown = float(balance.get("mining_tap_cooldown", 0.15))

func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta

	var auto_interval := GameManager.research.get_auto_tap_interval()
	if auto_interval > 0.0:
		_auto_tap_timer += delta
		if _auto_tap_timer >= auto_interval:
			_auto_tap_timer = 0.0
			tap()

func can_tap() -> bool:
	return _cooldown_remaining <= 0.0

func _get_module_tap_bonus() -> float:
	var total_tech_modules := 0
	for module_id in GameManager.modules_data:
		if GameManager.modules_data[module_id].get("resource") == "tech":
			total_tech_modules += GameManager.module_counts.get(module_id, 0)
	return 1.0 + 0.10 * total_tech_modules

func tap() -> float:
	if not can_tap():
		return 0.0
	_cooldown_remaining = _tap_cooldown
	var gained := _tech_per_tap * GameManager.research.get_tech_tap_multiplier() * _get_module_tap_bonus()
	GameManager.add_resource("tech", gained)
	EventBus.mining_tapped.emit(gained)
	AudioManager.play_sfx("tick")
	return gained
