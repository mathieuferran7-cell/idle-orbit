class_name PrestigeManager
extends Node

var data: Dictionary = {}
var orbits: int = 0
var prestige_count: int = 0
var talent_levels: Dictionary = {}
var total_energy_produced: float = 0.0

const THRESHOLD_BASE := 500_000.0
const THRESHOLD_GROWTH := 3.0

func setup(prestige_data: Dictionary) -> void:
	data = prestige_data
	for tid in data:
		talent_levels[tid] = 0

# ── Prestige logic ───────────────────────────────────────────────────────────

func get_threshold() -> float:
	return THRESHOLD_BASE * pow(THRESHOLD_GROWTH, prestige_count)

func can_prestige() -> bool:
	return total_energy_produced >= get_threshold()

func get_pending_orbits() -> int:
	var base := int(floor(sqrt(total_energy_produced / 1000.0)))
	return int(base * get_orbit_multiplier())

func track_energy(amount: float) -> void:
	if amount > 0.0:
		total_energy_produced += amount

# ── Talents ──────────────────────────────────────────────────────────────────

func get_talent_level(tid: String) -> int:
	return talent_levels.get(tid, 0)

func get_talent_max(tid: String) -> int:
	return int(data.get(tid, {}).get("max", 0))

func get_talent_cost(tid: String) -> int:
	return int(data.get(tid, {}).get("cost", 999))

func get_spent_orbits() -> int:
	var total := 0
	for tid in talent_levels:
		total += talent_levels[tid] * get_talent_cost(tid)
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
		if tid == "energy_plus" or tid == "energy_plus2":
			total += get_talent_level(tid) * float(talent.get("per_level", 0))
	return 1.0 + total

func get_tech_tap_mult() -> float:
	return 1.0 + get_talent_level("tech_plus") * float(data.get("tech_plus", {}).get("per_level", 0))

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
	return maxf(0.1, 1.0 - total)

func get_offline_mult() -> float:
	return 1.0 + get_talent_level("offline_plus") * float(data.get("offline_plus", {}).get("per_level", 0))

func get_orbit_multiplier() -> float:
	return 1.0 + get_talent_level("orbit_bonus") * float(data.get("orbit_bonus", {}).get("per_level", 0))

func has_auto_start() -> bool:
	return get_talent_level("auto_start") >= 1

# ── Save/load ────────────────────────────────────────────────────────────────

func get_state() -> Dictionary:
	return {
		"orbits": orbits,
		"prestige_count": prestige_count,
		"talent_levels": talent_levels.duplicate(),
		"total_energy_produced": total_energy_produced,
	}

func load_state(state: Dictionary) -> void:
	orbits = int(state.get("orbits", 0))
	prestige_count = int(state.get("prestige_count", 0))
	total_energy_produced = float(state.get("total_energy_produced", 0.0))
	var saved_talents: Dictionary = state.get("talent_levels", {})
	for tid in talent_levels:
		talent_levels[tid] = int(saved_talents.get(tid, 0))

func reset() -> void:
	orbits = 0
	prestige_count = 0
	total_energy_produced = 0.0
	for tid in talent_levels:
		talent_levels[tid] = 0
