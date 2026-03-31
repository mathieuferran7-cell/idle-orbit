class_name PrestigeManager
extends Node

var data: Dictionary = {}
var orbits: int = 0
var prestige_count: int = 0
var talent_levels: Dictionary = {}
var total_energy_produced: float = 0.0
var run_modifiers: Dictionary = {}
var _run_start_time: float = 0.0
var _run_events_completed: int = 0

var _threshold_base: float = 500_000.0
var _threshold_growth: float = 3.0

func setup(prestige_data: Dictionary) -> void:
	data = prestige_data
	for tid in data:
		talent_levels[tid] = 0

func setup_balance(balance: Dictionary) -> void:
	_threshold_base = float(balance.get("prestige_threshold_base", 500000.0))
	_threshold_growth = float(balance.get("prestige_threshold_growth", 3.0))

# ── Prestige logic ───────────────────────────────────────────────────────────

func get_threshold() -> float:
	var accel := get_talent_level("prestige_accelerator") * float(data.get("prestige_accelerator", {}).get("per_level", 0))
	var reduction := maxf(0.3, 1.0 - accel)
	return _threshold_base * pow(_threshold_growth, prestige_count) * reduction

func can_prestige() -> bool:
	return total_energy_produced >= get_threshold()

func get_pending_orbits() -> int:
	var base := int(floor(sqrt(total_energy_produced / 1000.0)))
	return int(base * get_orbit_multiplier())

func add_orbits(count: int) -> void:
	orbits += count

func track_energy(amount: float) -> void:
	if amount > 0.0:
		total_energy_produced += amount

# ── Talents ──────────────────────────────────────────────────────────────────

func get_talent_level(tid: String) -> int:
	return talent_levels.get(tid, 0)

func get_talent_max(tid: String) -> int:
	return int(data.get(tid, {}).get("max", 0))

func get_total_talent_levels() -> int:
	var total := 0
	for tid in talent_levels:
		total += talent_levels[tid]
	return total

func all_talents_maxed() -> bool:
	for tid in talent_levels:
		if talent_levels[tid] < get_talent_max(tid):
			return false
	return true

func get_talent_base_cost(tid: String) -> int:
	return int(data.get(tid, {}).get("cost", 999))

func get_talent_cost_growth(tid: String) -> float:
	return float(data.get(tid, {}).get("cost_growth", 1.5))

func get_talent_cost(tid: String) -> int:
	var base := get_talent_base_cost(tid)
	var growth := get_talent_cost_growth(tid)
	var level := get_talent_level(tid)
	return int(base * pow(growth, level))

func get_talent_cost_at_level(tid: String, level: int) -> int:
	var base := get_talent_base_cost(tid)
	var growth := get_talent_cost_growth(tid)
	return int(base * pow(growth, level))

func get_spent_orbits() -> int:
	var total := 0
	for tid in talent_levels:
		for lvl in talent_levels[tid]:
			total += get_talent_cost_at_level(tid, lvl)
	return total

func get_available_orbits() -> int:
	return orbits - get_spent_orbits()

func can_buy_talent(tid: String) -> bool:
	if tid not in data:
		return false
	if get_talent_level(tid) >= get_talent_max(tid):
		return false
	return get_available_orbits() >= get_talent_cost(tid)

func buy_talent(tid: String) -> bool:
	if not can_buy_talent(tid):
		return false
	talent_levels[tid] += 1
	EventBus.resource_changed.emit("orbits", 0, get_available_orbits())
	return true

# ── Bonus getters ────────────────────────────────────────────────────────────

func get_energy_mult() -> float:
	var total := 0.0
	for tid in data:
		var talent: Dictionary = data[tid]
		if tid in ["energy_plus", "energy_plus2", "energy_plus3"]:
			total += get_talent_level(tid) * float(talent.get("per_level", 0))
	return 1.0 + total

func get_tech_tap_mult() -> float:
	var total := get_talent_level("tech_plus") * float(data.get("tech_plus", {}).get("per_level", 0))
	total += get_talent_level("deep_mining") * float(data.get("deep_mining", {}).get("per_level", 0))
	return 1.0 + total

func get_starting_energy(base: float) -> float:
	return base + get_talent_level("start_plus") * float(data.get("start_plus", {}).get("per_level", 0))

func get_global_speed() -> float:
	var total := 0.0
	total += get_talent_level("speed_plus") * float(data.get("speed_plus", {}).get("per_level", 0))
	total += get_talent_level("mega_speed") * float(data.get("mega_speed", {}).get("per_level", 0))
	return 1.0 + total

func get_research_discount() -> float:
	var total := get_talent_level("research_minus") * float(data.get("research_minus", {}).get("per_level", 0))
	return maxf(0.1, 1.0 - total)

func get_module_discount() -> float:
	var total := get_talent_level("module_discount") * float(data.get("module_discount", {}).get("per_level", 0))
	total += get_talent_level("module_cost_reduction") * float(data.get("module_cost_reduction", {}).get("per_level", 0))
	return maxf(0.1, 1.0 - total)

func get_offline_mult() -> float:
	return 1.0 + get_talent_level("offline_plus") * float(data.get("offline_plus", {}).get("per_level", 0))

func get_orbit_multiplier() -> float:
	return 1.0 + get_talent_level("orbit_bonus") * float(data.get("orbit_bonus", {}).get("per_level", 0))

func has_auto_start() -> bool:
	return get_talent_level("auto_start") >= 1

# ── Orbital Memory Weave ─────────────────────────────────────────────────────

func start_run() -> void:
	_run_start_time = Time.get_unix_time_from_system()
	_run_events_completed = 0

func record_event() -> void:
	_run_events_completed += 1

func evaluate_weave(waves_survived: int) -> Dictionary:
	var mods: Dictionary = {}
	var run_duration := Time.get_unix_time_from_system() - _run_start_time
	if _run_start_time > 0.0 and run_duration < 2700.0:
		mods["tap_bonus"] = 2.0
	if waves_survived >= 8:
		mods["hp_bonus"] = 1.25
	if _run_events_completed >= 4:
		mods["event_speed"] = 0.5
	return mods

# ── Save/load ────────────────────────────────────────────────────────────────

func get_state() -> Dictionary:
	return {
		"orbits": orbits,
		"prestige_count": prestige_count,
		"talent_levels": talent_levels.duplicate(),
		"total_energy_produced": total_energy_produced,
		"run_modifiers": run_modifiers.duplicate(),
	}

func load_state(state: Dictionary) -> void:
	orbits = int(state.get("orbits", 0))
	prestige_count = int(state.get("prestige_count", 0))
	total_energy_produced = float(state.get("total_energy_produced", 0.0))
	run_modifiers = state.get("run_modifiers", {})
	var saved_talents: Dictionary = state.get("talent_levels", {})
	for tid in talent_levels:
		talent_levels[tid] = int(saved_talents.get(tid, 0))

func reset() -> void:
	orbits = 0
	prestige_count = 0
	total_energy_produced = 0.0
	for tid in talent_levels:
		talent_levels[tid] = 0
