# sim_runner.gd — Balance simulation (headless)
# Usage: run via Godot --headless --script tests/sim_runner.gd
# Outputs a CSV summary of energy/tech progression over time
extends SceneTree

const TICK = 0.25
const SIM_DURATION = 1800.0  # 30 minutes
const AUTO_BUY = true  # buy cheapest affordable module each tick

var balance: Dictionary = {}
var modules_data: Dictionary = {}
var module_counts: Dictionary = {}
var energy: float = 10.0
var tech: float = 0.0
var time_elapsed: float = 0.0
var total_taps: int = 0

const OUTPUT_PATH := "C:/Users/mathi/Documents/LittleOrbitREBOOT/tests/sim_result.csv"

func _init() -> void:
	_load_json()
	energy = float(balance.get("starting_energy", 10.0))
	for mod_id in modules_data:
		module_counts[mod_id] = 0

	_run_simulation()
	quit()

func _write_header(file: FileAccess) -> void:
	file.store_line("time_s,energy,tech,energy_rate,tech_rate,modules_summary")

func _load_json() -> void:
	balance = _read_json("res://data/balance.json")
	modules_data = _read_json("res://data/modules.json")

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("Cannot open: %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		printerr("Parse error: %s" % path)
		return {}
	return json.data

func _run_simulation() -> void:
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if not file:
		printerr("Cannot write output to %s" % OUTPUT_PATH)
		return
	_write_header(file)

	var report_interval := 60.0
	var next_report := 0.0

	while time_elapsed <= SIM_DURATION:
		_tick()
		if AUTO_BUY:
			_auto_buy()
		if time_elapsed >= next_report:
			_report(file)
			next_report += report_interval
		time_elapsed += TICK

	file.close()
	print("Sim done → tests/sim_result.csv")

func _tick() -> void:
	var e_rate := _get_production("energy")
	var t_rate := _get_production("tech")
	energy += e_rate * TICK
	tech += t_rate * TICK

func _auto_buy() -> void:
	var cheapest_id := ""
	var cheapest_cost := INF
	for mod_id in modules_data:
		if not _is_unlocked(mod_id):
			continue
		var cost := _get_cost(mod_id)
		if cost < cheapest_cost:
			var can_pay := energy >= cost
			if can_pay:
				cheapest_cost = cost
				cheapest_id = mod_id
	if cheapest_id != "":
		energy -= cheapest_cost
		module_counts[cheapest_id] += 1

func _get_production(resource_type: String) -> float:
	var total := 0.0
	for mod_id in modules_data:
		var mod: Dictionary = modules_data[mod_id]
		if mod.get("resource", "") == resource_type:
			total += float(mod.get("base_production", 0.0)) * module_counts.get(mod_id, 0)
	return total

func _get_cost(mod_id: String) -> float:
	var mod: Dictionary = modules_data[mod_id]
	var base: float = float(mod.get("base_cost", 0.0))
	var growth: float = float(mod.get("cost_growth", 1.15))
	return base * pow(growth, module_counts.get(mod_id, 0))

func _is_unlocked(mod_id: String) -> bool:
	var mod: Dictionary = modules_data[mod_id]
	var cond = mod.get("unlock_condition")
	if cond == null:
		return true
	if cond is Dictionary:
		return module_counts.get(cond.get("module", ""), 0) >= int(cond.get("count", 0))
	return true

func _report(file: FileAccess) -> void:
	var e_rate := _get_production("energy")
	var t_rate := _get_production("tech")
	var summary := ""
	for mod_id in modules_data:
		var c: int = module_counts.get(mod_id, 0)
		if c > 0:
			summary += "%s:%d " % [mod_id.left(6), c]
	file.store_line("%d,%.1f,%.1f,%.2f,%.2f,%s" % [
		int(time_elapsed), energy, tech, e_rate, t_rate, summary.strip_edges()
	])
