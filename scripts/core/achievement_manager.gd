class_name AchievementManager
extends Node

var data: Dictionary = {}
var _unlocked: Dictionary = {}
var _initialized: bool = false
var _suppress_rewards: bool = false

# Persistent stats (cross-prestige)
var _stats: Dictionary = {
	"total_taps": 0,
	"total_modules_bought": 0,
	"total_research_bought": 0,
	"total_events_completed": 0,
	"last_stand_best_wave": 0,
	"cumulative_energy": 0.0,
}

func setup(ach_data: Dictionary) -> void:
	data = ach_data
	_connect_signals()

func _connect_signals() -> void:
	EventBus.mining_tapped.connect(_on_tap)
	EventBus.module_purchased.connect(_on_module_purchased)
	EventBus.research_node_unlocked.connect(_on_research_unlocked)
	EventBus.prestige_completed.connect(_on_prestige_completed)
	EventBus.last_stand_completed.connect(_on_last_stand)
	EventBus.event_choice_made.connect(_on_event_completed)
	EventBus.resource_changed.connect(_on_resource_changed)

func _on_tap(_tech: float) -> void:
	if not _initialized:
		return
	_stats["total_taps"] += 1
	check_all()

func _on_module_purchased(_module_id: String, _count: int) -> void:
	if not _initialized:
		return
	_stats["total_modules_bought"] += 1
	check_all()

func _on_research_unlocked(_node_id: String) -> void:
	if not _initialized:
		return
	_stats["total_research_bought"] += 1
	check_all()

func _on_prestige_completed(_orbits: int) -> void:
	if not _initialized:
		return
	check_all()

func _on_last_stand(waves: int) -> void:
	if not _initialized:
		return
	if waves > _stats["last_stand_best_wave"]:
		_stats["last_stand_best_wave"] = waves
	check_all()

func _on_event_completed() -> void:
	if not _initialized:
		return
	_stats["total_events_completed"] += 1
	check_all()

func _on_resource_changed(type: String, amount: float, _total: float) -> void:
	if not _initialized:
		return
	if type == "energy" and amount > 0:
		_stats["cumulative_energy"] += amount
		# Only check energy-related achievements (throttled — avoid checking every tick)
		if int(_stats["cumulative_energy"]) % 100 < int(amount) + 1:
			check_all()

func check_all() -> void:
	for ach_id in data:
		if _unlocked.get(ach_id, false):
			continue
		if _check_condition(ach_id):
			_unlock(ach_id)

func _check_condition(ach_id: String) -> bool:
	var ach: Dictionary = data.get(ach_id, {})
	var cond: Dictionary = ach.get("condition", {})
	var ctype: String = cond.get("type", "")

	match ctype:
		"module_count":
			return GameManager.module_counts.get(cond.get("module", ""), 0) >= int(cond.get("count", 1))
		"total_modules":
			var total := 0
			for mid in GameManager.module_counts:
				total += GameManager.module_counts[mid]
			return total >= int(cond.get("count", 1))
		"total_taps":
			return _stats["total_taps"] >= int(cond.get("count", 1))
		"total_energy":
			return _stats["cumulative_energy"] >= float(cond.get("amount", 0))
		"prestige_count":
			return GameManager.prestige.prestige_count >= int(cond.get("count", 1))
		"research_count":
			return _stats["total_research_bought"] >= int(cond.get("count", 1))
		"research_unlocked":
			return GameManager.research.is_unlocked(cond.get("node", ""))
		"research_all_maxed":
			return GameManager.research.all_maxed()
		"module_unlocked":
			return GameManager.is_module_unlocked(cond.get("module", ""))
		"total_orbits":
			return GameManager.prestige.orbits >= int(cond.get("count", 1))
		"talent_count":
			return GameManager.prestige.get_total_talent_levels() >= int(cond.get("count", 1))
		"all_talents":
			return GameManager.prestige.all_talents_maxed()
		"last_stand_waves":
			return _stats["last_stand_best_wave"] >= int(cond.get("count", 1))
		"event_count":
			return _stats["total_events_completed"] >= int(cond.get("count", 1))
	return false

func _unlock(ach_id: String) -> void:
	_unlocked[ach_id] = true
	var ach: Dictionary = data.get(ach_id, {})
	if not _suppress_rewards:
		_apply_reward(ach.get("reward", {}))
		EventBus.achievement_unlocked.emit(ach_id, ach)
		AudioManager.play_sfx("upgrade")

func _apply_reward(reward: Dictionary) -> void:
	var rtype: String = reward.get("type", "")
	var amount: float = float(reward.get("amount", 0))
	match rtype:
		"energy":
			GameManager.add_resource("energy", amount)
		"tech":
			GameManager.add_resource("tech", amount)
		"orbits":
			GameManager.prestige.add_orbits(int(amount))

func set_suppress_rewards(val: bool) -> void:
	_suppress_rewards = val

func set_initialized(val: bool) -> void:
	_initialized = val

func get_unlocked_count() -> int:
	var count := 0
	for ach_id in _unlocked:
		if _unlocked[ach_id]:
			count += 1
	return count

func is_unlocked(ach_id: String) -> bool:
	return _unlocked.get(ach_id, false)

func reset() -> void:
	_unlocked.clear()
	_stats = {
		"total_taps": 0,
		"total_modules_bought": 0,
		"total_research_bought": 0,
		"total_events_completed": 0,
		"last_stand_best_wave": 0,
		"cumulative_energy": 0.0,
	}
	_initialized = false

func get_stats() -> Dictionary:
	return _stats

# ── Save/Load ────────────────────────────────────────────────────────────────

func get_state() -> Dictionary:
	return {
		"unlocked": _unlocked.duplicate(),
		"stats": _stats.duplicate(),
	}

func load_state(state: Dictionary) -> void:
	var saved_unlocked: Dictionary = state.get("unlocked", {})
	for ach_id in saved_unlocked:
		_unlocked[ach_id] = bool(saved_unlocked[ach_id])
	var saved_stats: Dictionary = state.get("stats", {})
	for key in _stats:
		if key in saved_stats:
			_stats[key] = saved_stats[key]
	_initialized = true
