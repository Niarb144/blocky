
extends Node

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1


func save_game() -> bool:
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"level": GameState.current_level,
		"sanctuary_id": GameState.last_sanctuary_id,
		"health": GameState.health,
		"ammo": GameState.ammo
	}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error("Could not open save file.")
		return false

	file.store_string(
		JSON.stringify(save_data, "\t")
	)

	file.close()

	print("Game saved successfully!")
	return true


func load_game() -> bool:
	if not has_save():
		return false

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()

	if json.parse(json_text) != OK:
		push_error("Save file is corrupted.")
		return false

	if not json.data is Dictionary:
		return false

	var data: Dictionary = json.data

	if data.get("version", -1) != SAVE_VERSION:
		push_error("Unsupported save version.")
		return false

	var level_path: String = str(
		data.get("level", GameState.STARTING_LEVEL)
	)

	if not ResourceLoader.exists(level_path):
		push_error("Saved level does not exist.")
		return false

	GameState.current_level = level_path

	GameState.last_sanctuary_id = str(
		data.get("sanctuary_id", "")
	)

	GameState.health = int(
		data.get("health", GameState.MAX_HEALTH)
	)

	GameState.ammo = int(
		data.get("ammo", GameState.MAX_AMMO)
	)

	print("Save data loaded!")
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
