class_name QuestManager
extends Node

var _daily_pool: Array = []
var _weekly_defs: Array = []
var _daily_count: int = 3

# Active quests state
var _active_daily: Array = []  # Array of quest defs (picked from pool)
var _daily_progress: Dictionary = {}  # quest_id → int
var _daily_claimed: Dictionary = {}   # quest_id → bool
var _weekly_progress: Dictionary = {}
var _weekly_claimed: Dictionary = {}

# Reset tracking
var _last_daily_reset: int = -1  # day_of_year
var _last_weekly_reset: int = -1  # week number (year * 100 + week)

var _reset_check_timer: float = 0.0

func setup(quest_data: Dictionary) -> void:
	_daily_pool = quest_data.get("daily_pool", [])
	_weekly_defs = quest_data.get("weekly", [])
	_daily_count = int(quest_data.get("daily_count", 3))
	_connect_signals()
	_reset_if_needed()

func _process(delta: float) -> void:
	_reset_check_timer += delta
	if _reset_check_timer >= 60.0:
		_reset_check_timer = 0.0
		_reset_if_needed()

func _connect_signals() -> void:
	EventBus.mining_tapped.connect(_on_tap)
	EventBus.module_purchased.connect(_on_module_purchased)
	EventBus.research_node_unlocked.connect(_on_research_unlocked)
	EventBus.prestige_completed.connect(_on_prestige_completed)
	EventBus.last_stand_completed.connect(_on_last_stand)
	EventBus.event_choice_made.connect(_on_event_completed)
	EventBus.resource_changed.connect(_on_resource_changed)

# ── Reset logic ──────────────────────────────────────────────────────────────

func _get_day_of_year() -> int:
	return int(Time.get_unix_time_from_system() / 86400)

func _get_week_number() -> int:
	return int(Time.get_unix_time_from_system() / 604800)

func _reset_if_needed() -> void:
	var today := _get_day_of_year()
	if _last_daily_reset != today:
		_reset_daily(today)
	var week := _get_week_number()
	if _last_weekly_reset != week:
		_reset_weekly(week)

func _reset_daily(today: int) -> void:
	_last_daily_reset = today
	_daily_progress.clear()
	_daily_claimed.clear()
	_pick_daily_quests(today)

func _reset_weekly(week: int) -> void:
	_last_weekly_reset = week
	_weekly_progress.clear()
	_weekly_claimed.clear()

func _pick_daily_quests(seed_val: int) -> void:
	_active_daily.clear()
	if _daily_pool.is_empty():
		return
	# Deterministic shuffle based on day seed
	var indices: Array[int] = []
	for i in _daily_pool.size():
		indices.append(i)
	# Simple Fisher-Yates with seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	# Pick first N
	var pick_count := mini(_daily_count, _daily_pool.size())
	for i in pick_count:
		_active_daily.append(_daily_pool[indices[i]])

# ── Scaling ──────────────────────────────────────────────────────────────────

func _get_scale_factor() -> float:
	return 1.0 + GameManager.prestige.prestige_count * 0.5

func get_scaled_target(quest: Dictionary) -> int:
	var base: int = int(quest.get("objective", {}).get("count", 1))
	if quest.get("scale_with_prestige", false):
		return int(base * _get_scale_factor())
	return base

func get_scaled_reward_amount(quest: Dictionary) -> int:
	var base: int = int(quest.get("reward", {}).get("amount", 0))
	if quest.get("scale_with_prestige", false):
		return int(base * _get_scale_factor())
	return base

# ── Progress tracking ────────────────────────────────────────────────────────

func _track(objective_type: String, amount: int) -> void:
	# Daily
	for quest in _active_daily:
		var qid: String = quest.get("id", "")
		if _daily_claimed.get(qid, false):
			continue
		var obj: Dictionary = quest.get("objective", {})
		if obj.get("type", "") == objective_type:
			var prev: int = _daily_progress.get(qid, 0)
			var new_val: int = prev + amount
			_daily_progress[qid] = new_val
			var target: int = get_scaled_target(quest)
			EventBus.quest_progress.emit(qid, mini(new_val, target), target)
			if new_val >= target and prev < target:
				EventBus.quest_completed.emit(qid)
	# Weekly
	for quest in _weekly_defs:
		var qid: String = quest.get("id", "")
		if _weekly_claimed.get(qid, false):
			continue
		var obj: Dictionary = quest.get("objective", {})
		if obj.get("type", "") == objective_type:
			var prev: int = _weekly_progress.get(qid, 0)
			var new_val: int = prev + amount
			_weekly_progress[qid] = new_val
			var target: int = get_scaled_target(quest)
			EventBus.quest_progress.emit(qid, mini(new_val, target), target)
			if new_val >= target and prev < target:
				EventBus.quest_completed.emit(qid)

func _on_tap(_tech: float) -> void:
	_track("taps", 1)

func _on_module_purchased(_module_id: String, _count: int) -> void:
	_track("modules_bought", 1)

func _on_research_unlocked(_node_id: String) -> void:
	_track("research_bought", 1)

func _on_prestige_completed(_orbits: int) -> void:
	_track("prestiges", 1)

func _on_last_stand(waves: int) -> void:
	# Track as "best in single run" — set progress to max(current, waves)
	for quest in _active_daily:
		var qid: String = quest.get("id", "")
		if _daily_claimed.get(qid, false):
			continue
		var obj: Dictionary = quest.get("objective", {})
		if obj.get("type", "") == "last_stand_waves":
			var prev: int = _daily_progress.get(qid, 0)
			if waves > prev:
				_daily_progress[qid] = waves
				var target: int = int(obj.get("count", 1))
				EventBus.quest_progress.emit(qid, mini(waves, target), target)
				if waves >= target and prev < target:
					EventBus.quest_completed.emit(qid)

func _on_event_completed() -> void:
	_track("events_completed", 1)

var _energy_accum: float = 0.0
var _tech_accum: float = 0.0

func _on_resource_changed(type: String, amount: float, _total: float) -> void:
	if amount <= 0:
		return
	if type == "energy":
		_energy_accum += amount
		if _energy_accum >= 10.0:
			_track("energy_produced", int(_energy_accum))
			_energy_accum = fmod(_energy_accum, 10.0)
	elif type == "tech":
		_tech_accum += amount
		if _tech_accum >= 1.0:
			_track("tech_collected", int(_tech_accum))
			_tech_accum = fmod(_tech_accum, 1.0)

# ── Claim ────────────────────────────────────────────────────────────────────

func claim_quest(quest_id: String) -> bool:
	# Find in daily
	for quest in _active_daily:
		if quest.get("id", "") == quest_id:
			if _daily_claimed.get(quest_id, false):
				return false
			var target: int = get_scaled_target(quest)
			if _daily_progress.get(quest_id, 0) < target:
				return false
			_daily_claimed[quest_id] = true
			_apply_reward(quest, true)
			return true
	# Find in weekly
	for quest in _weekly_defs:
		if quest.get("id", "") == quest_id:
			if _weekly_claimed.get(quest_id, false):
				return false
			var target: int = get_scaled_target(quest)
			if _weekly_progress.get(quest_id, 0) < target:
				return false
			_weekly_claimed[quest_id] = true
			_apply_reward(quest, true)
			return true
	return false

func _apply_reward(quest: Dictionary, scaled: bool = false) -> void:
	var reward: Dictionary = quest.get("reward", {})
	var rtype: String = reward.get("type", "")
	var amount: float = float(get_scaled_reward_amount(quest)) if scaled else float(reward.get("amount", 0))
	match rtype:
		"energy":
			GameManager.add_resource("energy", amount)
		"tech":
			GameManager.add_resource("tech", amount)
		"orbits":
			GameManager.prestige.add_orbits(int(amount))
	AudioManager.play_sfx("upgrade")

func reset() -> void:
	_daily_progress.clear()
	_daily_claimed.clear()
	_weekly_progress.clear()
	_weekly_claimed.clear()
	_energy_accum = 0.0
	_tech_accum = 0.0
	_reset_if_needed()

# ── Query ────────────────────────────────────────────────────────────────────

func get_active_daily() -> Array:
	return _active_daily

func get_weekly() -> Array:
	return _weekly_defs

func get_progress(quest_id: String) -> int:
	if quest_id in _daily_progress:
		return _daily_progress[quest_id]
	if quest_id in _weekly_progress:
		return _weekly_progress[quest_id]
	return 0

func is_claimed(quest_id: String) -> bool:
	return _daily_claimed.get(quest_id, false) or _weekly_claimed.get(quest_id, false)

func is_completable(quest_id: String) -> bool:
	if is_claimed(quest_id):
		return false
	for quest in _active_daily:
		if quest.get("id", "") == quest_id:
			var target: int = get_scaled_target(quest)
			return _daily_progress.get(quest_id, 0) >= target
	for quest in _weekly_defs:
		if quest.get("id", "") == quest_id:
			var target: int = get_scaled_target(quest)
			return _weekly_progress.get(quest_id, 0) >= target
	return false

func get_claimable_count() -> int:
	var count := 0
	for quest in _active_daily:
		if is_completable(quest.get("id", "")):
			count += 1
	for quest in _weekly_defs:
		if is_completable(quest.get("id", "")):
			count += 1
	return count

# ── Save/Load ────────────────────────────────────────────────────────────────

func get_state() -> Dictionary:
	# Store active daily IDs for consistency
	var daily_ids: Array = []
	for quest in _active_daily:
		daily_ids.append(quest.get("id", ""))
	return {
		"last_daily_reset": _last_daily_reset,
		"last_weekly_reset": _last_weekly_reset,
		"daily_ids": daily_ids,
		"daily_progress": _daily_progress.duplicate(),
		"daily_claimed": _daily_claimed.duplicate(),
		"weekly_progress": _weekly_progress.duplicate(),
		"weekly_claimed": _weekly_claimed.duplicate(),
		"energy_accum": _energy_accum,
		"tech_accum": _tech_accum,
	}

func load_state(state: Dictionary) -> void:
	_last_daily_reset = int(state.get("last_daily_reset", -1))
	_last_weekly_reset = int(state.get("last_weekly_reset", -1))

	# Check if reset is needed first
	var today := _get_day_of_year()
	var week := _get_week_number()

	if _last_daily_reset != today:
		_reset_daily(today)
	else:
		# Restore saved daily quests
		var saved_ids: Array = state.get("daily_ids", [])
		_active_daily.clear()
		for sid in saved_ids:
			for quest in _daily_pool:
				if quest.get("id", "") == sid:
					_active_daily.append(quest)
					break
		_daily_progress = state.get("daily_progress", {}).duplicate()
		_daily_claimed = state.get("daily_claimed", {}).duplicate()
		_energy_accum = float(state.get("energy_accum", 0.0))
		_tech_accum = float(state.get("tech_accum", 0.0))

	if _last_weekly_reset != week:
		_reset_weekly(week)
	else:
		_weekly_progress = state.get("weekly_progress", {}).duplicate()
		_weekly_claimed = state.get("weekly_claimed", {}).duplicate()
