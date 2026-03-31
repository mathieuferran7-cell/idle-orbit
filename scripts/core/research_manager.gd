class_name ResearchManager
extends Node

var data: Dictionary = {}
var _levels: Dictionary = {}  # node_id -> current level (int)

func setup(research_data: Dictionary) -> void:
	data = research_data
	for node_id in data:
		_levels[node_id] = 0

func get_level(node_id: String) -> int:
	return _levels.get(node_id, 0)

func get_max_level(node_id: String) -> int:
	return int(data.get(node_id, {}).get("max_level", 1))

func is_unlocked(node_id: String) -> bool:
	return get_level(node_id) >= 1

func is_maxed(node_id: String) -> bool:
	return get_level(node_id) >= get_max_level(node_id)

func all_maxed() -> bool:
	for node_id in _levels:
		if not is_maxed(node_id):
			return false
	return true

func get_next_cost(node_id: String) -> float:
	var node: Dictionary = data.get(node_id, {})
	var level := get_level(node_id)
	var cost_values: Array = node.get("cost_values", [])
	if cost_values.size() > level:
		return float(cost_values[level])
	var base: float = float(node.get("base_cost", 0))
	var growth: float = float(node.get("cost_growth", 1.5))
	return base * pow(growth, level)

func get_effective_cost(node_id: String) -> float:
	var base_cost := get_next_cost(node_id)
	var discount := GameManager.prestige.get_research_discount()
	var buff := GameManager.events.get_buff_multiplier("research")
	return base_cost * discount * buff

func can_upgrade(node_id: String) -> bool:
	if is_maxed(node_id):
		return false
	var node: Dictionary = data.get(node_id, {})
	if node.is_empty():
		return false
	for req in node.get("requires", []):
		if not is_unlocked(req):
			return false
	return GameManager.tech >= get_effective_cost(node_id)

func upgrade(node_id: String) -> bool:
	if not can_upgrade(node_id):
		return false
	var cost := get_effective_cost(node_id)
	GameManager.tech -= cost
	EventBus.resource_changed.emit("tech", -cost, GameManager.tech)
	_levels[node_id] = get_level(node_id) + 1
	EventBus.research_node_unlocked.emit(node_id)
	return true

# --- Effect getters ---

func get_energy_multiplier() -> float:
	var total := 0.0
	for node_id in _levels:
		var effect: Dictionary = data[node_id].get("effect", {})
		if effect.get("type") == "energy_multiplier":
			total += get_level(node_id) * float(data[node_id].get("effect_per_level", 0.0))
	return 1.0 + total

func get_cost_multiplier() -> float:
	var total := 0.0
	for node_id in _levels:
		var effect: Dictionary = data[node_id].get("effect", {})
		if effect.get("type") == "module_cost_multiplier":
			total += get_level(node_id) * float(data[node_id].get("effect_per_level", 0.0))
	return max(0.1, 1.0 - total)

func get_offline_multiplier() -> float:
	var total := 0.0
	for node_id in _levels:
		var effect: Dictionary = data[node_id].get("effect", {})
		if effect.get("type") == "offline_multiplier":
			total += get_level(node_id) * float(data[node_id].get("effect_per_level", 0.0))
	return 1.0 + total

func get_auto_tap_interval() -> float:
	var best := 0.0
	for node_id in _levels:
		var lvl := get_level(node_id)
		if lvl == 0:
			continue
		var effect: Dictionary = data[node_id].get("effect", {})
		if effect.get("type") == "auto_tap_interval":
			var vals: Array = data[node_id].get("effect_values", [])
			if lvl - 1 < vals.size():
				var interval := float(vals[lvl - 1])
				if best == 0.0 or interval < best:
					best = interval
	return best

func get_tech_tap_multiplier() -> float:
	var total := 0.0
	for node_id in _levels:
		var effect: Dictionary = data[node_id].get("effect", {})
		if effect.get("type") == "tech_tap_multiplier":
			total += get_level(node_id) * float(data[node_id].get("effect_per_level", 0.0))
	return 1.0 + total

# --- Display helpers ---

func set_level(node_id: String, level: int) -> void:
	_levels[node_id] = level

func get_effect_label(node_id: String) -> String:
	var level := get_level(node_id)
	var node: Dictionary = data.get(node_id, {})
	var etype: String = node.get("effect", {}).get("type", "none")
	match etype:
		"energy_multiplier":
			return "+%.0f%% ⚡" % (level * float(node.get("effect_per_level", 0)) * 100)
		"auto_tap_interval":
			if level == 0:
				return "Auto: —"
			var vals: Array = node.get("effect_values", [])
			return "Auto: %.0fs" % float(vals[level - 1])
		"module_cost_multiplier":
			return "−%.0f%% coût" % (level * float(node.get("effect_per_level", 0)) * 100)
		"offline_multiplier":
			return "+%.0f%% offline" % (level * float(node.get("effect_per_level", 0)) * 100)
		"tech_tap_multiplier":
			return "+%.0f%% 🔧/tap" % (level * float(node.get("effect_per_level", 0)) * 100)
		_:
			return "Débloqué" if level >= 1 else "—"

func get_next_effect_label(node_id: String) -> String:
	var level := get_level(node_id)
	var next := level + 1
	var node: Dictionary = data.get(node_id, {})
	var etype: String = node.get("effect", {}).get("type", "none")
	match etype:
		"energy_multiplier":
			return "+%.0f%% ⚡" % (next * float(node.get("effect_per_level", 0)) * 100)
		"auto_tap_interval":
			var vals: Array = node.get("effect_values", [])
			if next - 1 < vals.size():
				return "Auto: %.0fs" % float(vals[next - 1])
			return ""
		"module_cost_multiplier":
			return "−%.0f%% coût" % (next * float(node.get("effect_per_level", 0)) * 100)
		"offline_multiplier":
			return "+%.0f%% offline" % (next * float(node.get("effect_per_level", 0)) * 100)
		"tech_tap_multiplier":
			return "+%.0f%% 🔧/tap" % (next * float(node.get("effect_per_level", 0)) * 100)
		_:
			return ""

# --- Save/load ---

func load_state(levels: Dictionary) -> void:
	for node_id in _levels:
		_levels[node_id] = int(levels.get(node_id, 0))

func get_state() -> Dictionary:
	return _levels.duplicate()
