class_name EventManager
extends Node

var data: Dictionary = {}
var _active_buffs: Array[Dictionary] = []
var _history: Array[String] = []
var _timer: float = 0.0
var _min_interval: float = 120.0
var _max_interval: float = 300.0
var _cooldown_after: float = 60.0
var _paused: bool = false

var _milestones_triggered: Dictionary = {}

func setup(events_data: Dictionary, balance: Dictionary) -> void:
	data = events_data
	_min_interval = float(balance.get("event_min_interval", 120))
	_max_interval = float(balance.get("event_max_interval", 300))
	_cooldown_after = float(balance.get("event_cooldown_after_choice", 60))
	_reset_timer()
	# Connect milestone signals
	EventBus.module_purchased.connect(_check_milestone_tier2)
	EventBus.research_node_unlocked.connect(_check_milestone_research)
	EventBus.prestige_completed.connect(_check_milestone_prestige)

func _check_milestone_tier2(_module_id: String, _count: int) -> void:
	if _milestones_triggered.get("first_tier2", false):
		return
	# Check if any tier 2 module (requires another module) has count >= 1
	for mid in GameManager.modules_data:
		var cond = GameManager.modules_data[mid].get("unlock_condition")
		if cond is Dictionary and GameManager.module_counts.get(mid, 0) >= 1:
			_milestones_triggered["first_tier2"] = true
			_trigger_milestone_event("crystal_vein")
			return

func _check_milestone_research(_node_id: String) -> void:
	if _milestones_triggered.get("first_maxed_research", false):
		return
	for nid in GameManager.research.data:
		if GameManager.research.is_maxed(nid):
			_milestones_triggered["first_maxed_research"] = true
			_trigger_milestone_event("ancient_transmission")
			return

func _check_milestone_prestige(_orbits: int) -> void:
	if _milestones_triggered.get("first_prestige", false):
		return
	_milestones_triggered["first_prestige"] = true
	# Delay to not conflict with prestige scene transition
	call_deferred("_trigger_milestone_event", "gravity_anomaly")

func _trigger_milestone_event(event_id: String) -> void:
	if _paused:
		return
	if event_id not in data:
		return
	var evt: Dictionary = data[event_id].duplicate(true)
	evt["id"] = event_id
	_paused = true
	EventBus.event_triggered.emit(evt)

func _process(delta: float) -> void:
	if _paused:
		return
	# Tick buffs
	var i := _active_buffs.size() - 1
	while i >= 0:
		_active_buffs[i].remaining -= delta
		if _active_buffs[i].remaining <= 0.0:
			var buff_id: String = _active_buffs[i].id
			_active_buffs.remove_at(i)
			EventBus.buff_ended.emit(buff_id)
		i -= 1
	# Tick event timer
	_timer -= delta
	if _timer <= 0.0:
		var evt := pick_event()
		if not evt.is_empty():
			_paused = true
			EventBus.event_triggered.emit(evt)

func pick_event() -> Dictionary:
	var pool: Array[String] = []
	for eid in data:
		if eid not in _history:
			pool.append(eid)
	if pool.is_empty():
		_history.clear()
		for eid in data:
			pool.append(eid)
	var eid: String = pool[randi() % pool.size()]
	_history.append(eid)
	if _history.size() > 4:
		_history.pop_front()
	var evt: Dictionary = data[eid].duplicate(true)
	evt["id"] = eid
	return evt

func on_choice_made() -> void:
	_paused = false
	_timer = _cooldown_after + randf_range(0, _max_interval - _min_interval)
	EventBus.event_choice_made.emit()

func _get_scaling_factor() -> float:
	# Scale rewards based on total energy produced: 1.0 at 0, grows with sqrt
	var total := GameManager.prestige.total_energy_produced
	return maxf(1.0, sqrt(total / 10000.0))

func apply_reward(reward: Dictionary) -> String:
	var rtype: String = reward.get("type", "")
	var scale := _get_scaling_factor()
	var result_parts: Array[String] = []
	match rtype:
		"energy":
			var amount: float
			if reward.has("amount"):
				amount = float(reward.amount) * scale
			else:
				amount = randf_range(float(reward.get("min", 0)), float(reward.get("max", 0))) * scale
			amount = floorf(amount)
			GameManager.add_resource("energy", amount)
			result_parts.append("+%s ⚡" % NumberFormatter.format(amount))
		"tech":
			var amount: float
			if reward.has("amount"):
				amount = float(reward.amount) * scale
			else:
				amount = randf_range(float(reward.get("min", 0)), float(reward.get("max", 0))) * scale
			amount = floorf(amount)
			GameManager.add_resource("tech", amount)
			result_parts.append("+%s 🔧" % NumberFormatter.format(amount))
		"orbits":
			var amount: int = int(reward.get("amount", 0))
			GameManager.prestige.add_orbits(amount)
			EventBus.resource_changed.emit("orbits", float(amount), float(GameManager.prestige.get_available_orbits()))
			result_parts.append("+%d ⭐" % amount)
		"buff":
			var buff_id: String = reward.get("buff_id", "")
			start_buff(buff_id, float(reward.get("duration", 30)))
			result_parts.append(_buff_display(buff_id, float(reward.get("duration", 30))))
		"module":
			var mid: String = reward.get("module_id", "")
			var count: int = int(reward.get("count", 1))
			if mid in GameManager.module_counts:
				GameManager.module_counts[mid] += count
				EventBus.module_purchased.emit(mid, GameManager.module_counts[mid])
				var mod_name: String = GameManager.modules_data.get(mid, {}).get("name", mid)
				result_parts.append("+%d %s" % [count, mod_name])
		"multi":
			for sub_reward in reward.get("rewards", []):
				var sub_text := apply_reward(sub_reward)
				if sub_text != "":
					result_parts.append(sub_text)
	return "  ".join(result_parts)

func _buff_display(buff_id: String, duration: float) -> String:
	match buff_id:
		"energy_x2": return "⚡x2 %ds" % int(duration)
		"tech_x2": return "🔧x2 %ds" % int(duration)
		"speed_x2": return "⏩x2 %ds" % int(duration)
		"tap_x3": return "👆x3 %ds" % int(duration)
		"research_discount": return "🔬-50%% %ds" % int(duration)
		_: return "%s %ds" % [buff_id, int(duration)]

func start_buff(buff_id: String, duration: float) -> void:
	# Stack: add duration if same buff already active
	for buff in _active_buffs:
		if buff.id == buff_id:
			buff.remaining += duration
			EventBus.buff_started.emit(buff_id, buff.remaining)
			return
	_active_buffs.append({"id": buff_id, "remaining": duration})
	EventBus.buff_started.emit(buff_id, duration)

func get_buff_multiplier(category: String) -> float:
	var mult := 1.0
	for buff in _active_buffs:
		match buff.id:
			"energy_x2":
				if category == "energy":
					mult *= 2.0
			"tech_x2":
				if category == "tech":
					mult *= 2.0
			"speed_x2":
				if category == "speed":
					mult *= 2.0
			"tap_x3":
				if category == "tap":
					mult *= 3.0
			"research_discount":
				if category == "research":
					mult *= 0.5
	return mult

func get_active_buffs() -> Array[Dictionary]:
	return _active_buffs

func reset() -> void:
	_active_buffs.clear()
	_history.clear()
	_milestones_triggered.clear()
	_paused = false
	_reset_timer()

func get_state() -> Dictionary:
	var buffs_data: Array = []
	for buff in _active_buffs:
		buffs_data.append({"id": buff.id, "remaining": buff.remaining})
	return {
		"timer": _timer,
		"history": _history.duplicate(),
		"milestones": _milestones_triggered.duplicate(),
		"buffs": buffs_data,
	}

func load_state(state: Dictionary) -> void:
	_timer = float(state.get("timer", _min_interval))
	_history = []
	for h in state.get("history", []):
		_history.append(str(h))
	_milestones_triggered = {}
	for k in state.get("milestones", {}):
		_milestones_triggered[k] = state["milestones"][k]
	_active_buffs.clear()
	for b in state.get("buffs", []):
		_active_buffs.append({"id": str(b.get("id", "")), "remaining": float(b.get("remaining", 0))})

func _reset_timer() -> void:
	_timer = randf_range(_min_interval, _max_interval)
