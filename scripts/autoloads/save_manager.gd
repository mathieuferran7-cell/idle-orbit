extends Node

const SAVE_PATH := "user://idle_orbit_save.json"
const CURRENT_SAVE_VERSION := 1

func save_game(data: Dictionary) -> void:
	data["save_version"] = CURRENT_SAVE_VERSION
	data["last_played"] = Time.get_unix_time_from_system()
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		EventBus.game_saved.emit()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_warning("SaveManager: corrupt save file, starting fresh")
		return {}
	var data: Dictionary = json.data
	var version := int(data.get("save_version", 0))
	if version < CURRENT_SAVE_VERSION:
		data = _migrate(data, version)
	return data

func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version < 1:
		data["save_version"] = 1
	return data

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func get_seconds_since_last_played() -> float:
	var data := load_game()
	if data.is_empty():
		return 0.0
	var last := float(data.get("last_played", 0))
	if last <= 0:
		return 0.0
	return max(0.0, Time.get_unix_time_from_system() - last)
