extends Node

var balance: Dictionary = {}
var modules_data: Dictionary = {}
var research: ResearchManager
var prestige: PrestigeManager
var events: EventManager
var achievements: AchievementManager
var quests: QuestManager

var energy: float = 0.0
var tech: float = 0.0
var module_counts: Dictionary = {}

var _tick_accumulator: float = 0.0
var _pending_offline_gains: Dictionary = {}
var _minigame_data: Dictionary = {}
var _pre_prestige_orbits: int = 0
var no_ads: bool = false
var _in_minigame: bool = false
var _post_prestige_pending: int = -1
var _return_to_prestige_tab: bool = false
var tutorial_step: int = 0

func _ready() -> void:
	_load_data_files()
	call_deferred("_post_init")

func _post_init() -> void:
	var save_data := SaveManager.load_game()
	if not save_data.is_empty():
		_apply_save(save_data)
	else:
		achievements.set_initialized(true)
	EventBus.game_loaded.emit()
	var offline_seconds := SaveManager.get_seconds_since_last_played()
	var min_seconds: float = balance.get("offline_min_seconds", 60)
	if offline_seconds >= min_seconds:
		_pending_offline_gains = _calculate_offline_gains(offline_seconds)
		EventBus.game_ready.emit()
		EventBus.offline_gains_ready.emit(_pending_offline_gains)
	else:
		EventBus.game_ready.emit()

func _load_data_files() -> void:
	balance = _read_json("res://data/balance.json")
	modules_data = _read_json("res://data/modules.json")
	energy = float(balance.get("starting_energy", 10.0))
	for module_id in modules_data:
		module_counts[module_id] = 0
	research = ResearchManager.new()
	research.setup(_read_json("res://data/research.json"))
	add_child(research)
	prestige = PrestigeManager.new()
	prestige.setup(_read_json("res://data/prestige.json"))
	prestige.setup_balance(balance)
	add_child(prestige)
	_minigame_data = _read_json("res://data/minigame.json")
	events = EventManager.new()
	events.setup(_read_json("res://data/events.json"), balance)
	add_child(events)
	achievements = AchievementManager.new()
	achievements.setup(_read_json("res://data/achievements.json"))
	add_child(achievements)
	quests = QuestManager.new()
	quests.setup(_read_json("res://data/quests.json"))
	add_child(quests)

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("GameManager: cannot open %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("GameManager: parse error in %s" % path)
		return {}
	return json.data

func _process(delta: float) -> void:
	if _in_minigame:
		return
	_tick_accumulator += delta
	var tick_interval: float = balance.get("tick_interval", 0.25)
	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		_production_tick(tick_interval)

func _production_tick(dt: float) -> void:
	var energy_rate := get_total_production("energy")
	if energy_rate > 0.0:
		add_resource("energy", energy_rate * dt)
	var tech_rate := get_total_production("tech")
	if tech_rate > 0.0:
		add_resource("tech", tech_rate * dt)

func get_total_production(resource_type: String) -> float:
	var total := 0.0
	for module_id in modules_data:
		var mod: Dictionary = modules_data[module_id]
		if mod.get("resource", "") == resource_type:
			total += mod.get("base_production", 0.0) * module_counts.get(module_id, 0)
	if resource_type == "energy":
		total *= research.get_energy_multiplier() * prestige.get_energy_mult()
		total *= events.get_buff_multiplier("energy")
	elif resource_type == "tech":
		total *= events.get_buff_multiplier("tech")
	total *= prestige.get_global_speed() * events.get_buff_multiplier("speed")
	return total

func add_resource(type: String, amount: float) -> void:
	match type:
		"energy":
			energy += amount
			if amount > 0.0:
				prestige.track_energy(amount)
			EventBus.resource_changed.emit("energy", amount, energy)
		"tech":
			tech += amount
			EventBus.resource_changed.emit("tech", amount, tech)

func get_module_cost(module_id: String) -> float:
	var mod: Dictionary = modules_data.get(module_id, {})
	var base_cost: float = mod.get("base_cost", 0.0)
	var growth: float = mod.get("cost_growth", balance.get("module_cost_growth_default", 1.15))
	var count: int = module_counts.get(module_id, 0)
	return base_cost * pow(growth, count) * research.get_cost_multiplier() * prestige.get_module_discount()

func can_afford_module(module_id: String) -> bool:
	return energy >= get_module_cost(module_id) and tech >= get_module_tech_cost(module_id)

func is_module_unlocked(module_id: String) -> bool:
	var mod: Dictionary = modules_data.get(module_id, {})
	var cond = mod.get("unlock_condition")
	if cond == null or (cond is String and cond == ""):
		return true
	if cond is Dictionary:
		var req_module: String = cond.get("module", "")
		var req_count: int = int(cond.get("count", 0))
		return module_counts.get(req_module, 0) >= req_count
	return true

func get_module_tech_cost(module_id: String) -> float:
	var mod: Dictionary = modules_data.get(module_id, {})
	var base: float = mod.get("tech_cost", 0.0)
	if base <= 0.0:
		return 0.0
	var growth: float = mod.get("tech_cost_growth", 1.15)
	var count: int = module_counts.get(module_id, 0)
	return base * pow(growth, count)

func buy_module(module_id: String) -> bool:
	if not is_module_unlocked(module_id):
		return false
	var cost := get_module_cost(module_id)
	var tech_cost := get_module_tech_cost(module_id)
	if energy < cost or tech < tech_cost:
		return false
	energy -= cost
	EventBus.resource_changed.emit("energy", -cost, energy)
	if tech_cost > 0.0:
		tech -= tech_cost
		EventBus.resource_changed.emit("tech", -tech_cost, tech)
	module_counts[module_id] = module_counts.get(module_id, 0) + 1
	EventBus.module_purchased.emit(module_id, module_counts[module_id])
	_check_unlocks()
	return true

func get_bulk_cost(module_id: String, amount: int) -> float:
	var total := 0.0
	var count: int = module_counts.get(module_id, 0)
	var mod: Dictionary = modules_data[module_id]
	var base: float = mod.get("base_cost", 0.0)
	var growth: float = mod.get("cost_growth", balance.get("module_cost_growth_default", 1.15))
	var cm := research.get_cost_multiplier() * prestige.get_module_discount()
	for i in range(amount):
		total += base * pow(growth, count + i) * cm
	return total

func get_max_affordable(module_id: String) -> int:
	var count := 0
	var total := 0.0
	var current: int = module_counts.get(module_id, 0)
	var mod: Dictionary = modules_data[module_id]
	var base: float = mod.get("base_cost", 0.0)
	var growth: float = mod.get("cost_growth", balance.get("module_cost_growth_default", 1.15))
	var cm := research.get_cost_multiplier() * prestige.get_module_discount()
	while true:
		var next_cost := base * pow(growth, current + count) * cm
		if total + next_cost > energy:
			break
		total += next_cost
		count += 1
	return count

func buy_module_bulk(module_id: String, amount: int) -> bool:
	if not is_module_unlocked(module_id):
		return false
	var actual: int = get_max_affordable(module_id) if amount == 0 else mini(amount, get_max_affordable(module_id))
	if actual <= 0:
		return false
	var cost := get_bulk_cost(module_id, actual)
	energy -= cost
	EventBus.resource_changed.emit("energy", -cost, energy)
	module_counts[module_id] = module_counts.get(module_id, 0) + actual
	EventBus.module_purchased.emit(module_id, module_counts[module_id])
	_check_unlocks()
	return true

func buy_talent(tid: String) -> bool:
	return prestige.buy_talent(tid)

func upgrade_research(node_id: String) -> bool:
	return research.upgrade(node_id)

func _check_unlocks() -> void:
	for module_id in modules_data:
		if module_counts.get(module_id, 0) == 0 and is_module_unlocked(module_id):
			EventBus.module_unlocked.emit(module_id)

func _calculate_offline_gains(seconds: float) -> Dictionary:
	var max_offline: float = balance.get("offline_max_seconds", 3600)
	max_offline *= research.get_offline_multiplier() * prestige.get_offline_mult()
	var capped: float = minf(seconds, max_offline)
	var energy_ratio: float = balance.get("offline_energy_ratio", 0.25)
	var tech_ratio: float = balance.get("offline_tech_ratio", 0.25)
	var energy_gained: float = get_total_production("energy") * capped * energy_ratio
	var tech_gained: float = get_total_production("tech") * capped * tech_ratio
	return {
		"energy": energy_gained,
		"tech": tech_gained,
		"seconds": capped,
	}

func claim_offline_gains(multiplier: float = 1.0) -> void:
	if _pending_offline_gains.is_empty():
		return
	var e: float = _pending_offline_gains.get("energy", 0.0) * multiplier
	var t: float = _pending_offline_gains.get("tech", 0.0) * multiplier
	if e > 0.0:
		add_resource("energy", e)
	if t > 0.0:
		add_resource("tech", t)
	_pending_offline_gains = {}

# ── Minigame ─────────────────────────────────────────────────────────────────

func start_prestige_minigame() -> void:
	_pre_prestige_orbits = prestige.get_pending_orbits()
	save()
	_in_minigame = true
	events.set_paused(true)
	AdManager.hide_banner()
	var scene := load("res://scenes/minigame/last_stand.tscn")
	get_tree().change_scene_to_packed(scene)

func quick_prestige() -> void:
	_pre_prestige_orbits = int(prestige.get_pending_orbits() * 0.7)
	complete_prestige_with_bonus(0)

func get_minigame_params() -> Dictionary:
	var total_energy_modules := 0
	var total_tech_modules := 0
	for module_id in modules_data:
		var res_type: String = modules_data[module_id].get("resource", "")
		var count: int = module_counts.get(module_id, 0)
		if res_type == "energy":
			total_energy_modules += count
		elif res_type == "tech":
			total_tech_modules += count
	return {
		"total_energy_modules": total_energy_modules,
		"total_tech_modules": total_tech_modules,
		"data": _minigame_data,
		"pending_orbits": _pre_prestige_orbits,
	}

func complete_prestige_with_bonus(waves_survived: int) -> void:
	var bonus_per_wave: float = _minigame_data.get("orbit_bonus_per_wave", 0.1)
	var bonus_mult: float = 1.0 + waves_survived * bonus_per_wave
	var final_orbits: int = int(_pre_prestige_orbits * bonus_mult)
	prestige.add_orbits(final_orbits)
	prestige.prestige_count += 1
	prestige.total_energy_produced = 0.0
	energy = prestige.get_starting_energy(float(balance.get("starting_energy", 10.0)))
	tech = 0.0
	for module_id in module_counts:
		module_counts[module_id] = 0
	research.setup(research.data)
	if prestige.has_auto_start():
		research.set_level("auto_tap", 1)
	events.reset()
	achievements.reset()
	achievements.set_initialized(true)
	quests.reset()
	_in_minigame = false
	_return_to_prestige_tab = true
	_post_prestige_pending = final_orbits
	save()
	get_tree().change_scene_to_packed(load("res://scenes/main/main.tscn"))

# ── Save/load ────────────────────────────────────────────────────────────────

func _apply_save(data: Dictionary) -> void:
	energy = float(data.get("energy", 0.0))
	tech = float(data.get("tech", 0.0))
	var saved_modules: Dictionary = data.get("module_counts", {})
	for module_id in saved_modules:
		if module_id in module_counts:
			module_counts[module_id] = int(saved_modules[module_id])
	no_ads = bool(data.get("no_ads", false))
	tutorial_step = int(data.get("tutorial_step", 0))
	research.load_state(data.get("research_levels", {}))
	prestige.load_state(data.get("prestige", {}))
	events.load_state(data.get("events", {}))
	achievements.load_state(data.get("achievements", {}))
	quests.load_state(data.get("quests", {}))

func get_save_data() -> Dictionary:
	return {
		"energy": energy,
		"tech": tech,
		"no_ads": no_ads,
		"tutorial_step": tutorial_step,
		"module_counts": module_counts.duplicate(),
		"research_levels": research.get_state(),
		"prestige": prestige.get_state(),
		"events": events.get_state(),
		"achievements": achievements.get_state(),
		"quests": quests.get_state(),
	}

func consume_post_prestige_orbits() -> int:
	var val := _post_prestige_pending
	_post_prestige_pending = -1
	return val

func should_return_to_prestige_tab() -> bool:
	var val := _return_to_prestige_tab
	_return_to_prestige_tab = false
	return val

func claim_quest(quest_id: String) -> bool:
	return quests.claim_quest(quest_id)

func save() -> void:
	SaveManager.save_game(get_save_data())

func full_reset() -> void:
	SaveManager.delete_save()
	energy = float(balance.get("starting_energy", 10.0))
	tech = 0.0
	no_ads = false
	tutorial_step = 0
	for module_id in module_counts:
		module_counts[module_id] = 0
	research.setup(research.data)
	prestige.reset()
	achievements.reset()
	achievements.set_initialized(true)
	quests.reset()
	EventBus.game_ready.emit()

func _notification(what: int) -> void:
	if _in_minigame:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save()
