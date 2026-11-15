
extends Node

# ==================================================
# SAVE SETTINGS
# ==================================================

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 3


# ==================================================
# SAVE GAME
# ==================================================

func save_game() -> bool:

	var save_data: Dictionary = {
		"version": SAVE_VERSION,

		# Checkpoint information
		"level": GameState.current_level,
		"sanctuary_id": GameState.last_sanctuary_id,

		# All discovered sanctuaries
		"discovered_sanctuaries": (
			GameState.discovered_sanctuaries.duplicate(true)
		),

		# Player resources
		"health": GameState.health,
		"ammo": GameState.ammo,

		# Essence currency
		"essence": GameState.essence,

		# Permanent upgrades
		"vitality": GameState.vitality,
		"ferocity": GameState.ferocity,
		"concentration": GameState.concentration,
		"fluidity": GameState.fluidity
	}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"Could not open save file: ",
			FileAccess.get_open_error()
		)
		return false

	file.store_string(
		JSON.stringify(save_data, "\t")
	)

	file.flush()

	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK:
		push_error("Failed to write save data.")
		return false

	print("Game saved successfully!")
	print("Checkpoint: ", GameState.last_sanctuary_id)
	print(
		"Discovered sanctuaries: ",
		GameState.discovered_sanctuaries.keys()
	)

	return true


# ==================================================
# LOAD GAME
# ==================================================

func load_game() -> bool:

	if not has_save():
		return false

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error("Could not open save file.")
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()

	if json.parse(json_text) != OK:
		push_error("Save file is corrupted.")
		return false

	if not json.data is Dictionary:
		push_error("Invalid save data format.")
		return false

	var data: Dictionary = json.data

	# ----------------------------------------------
	# VALIDATE SAVE VERSION
	# ----------------------------------------------

	var version: int = int(
		data.get("version", -1)
	)

	if version < 1 or version > SAVE_VERSION:
		push_error("Unsupported save version.")
		return false

	# ----------------------------------------------
	# VALIDATE SAVED LEVEL
	# ----------------------------------------------

	var level_path: String = str(
		data.get(
			"level",
			GameState.STARTING_LEVEL
		)
	)

	if not ResourceLoader.exists(level_path):
		push_error("Saved level does not exist.")
		return false

	# ----------------------------------------------
	# RESTORE CHECKPOINT
	# ----------------------------------------------

	GameState.current_level = level_path

	GameState.last_sanctuary_id = str(
		data.get("sanctuary_id", "")
	)

	# ----------------------------------------------
	# RESTORE DISCOVERED SANCTUARIES
	# ----------------------------------------------

	GameState.discovered_sanctuaries.clear()

	var saved_sanctuaries: Variant = (
		data.get("discovered_sanctuaries", {})
	)

	if saved_sanctuaries is Dictionary:

		for sanctuary_id in saved_sanctuaries:

			var saved_level: String = str(
				saved_sanctuaries[sanctuary_id]
			)

			if str(sanctuary_id).is_empty():
				continue

			if not ResourceLoader.exists(saved_level):
				continue

			GameState.discovered_sanctuaries[
				str(sanctuary_id)
			] = saved_level

	# Backward compatibility:
	# Older saves only contain the active checkpoint.
	# Restore it as a discovered sanctuary.

	if (
		not GameState.last_sanctuary_id.is_empty()
		and not GameState.discovered_sanctuaries.has(
			GameState.last_sanctuary_id
		)
	):

		GameState.discovered_sanctuaries[
			GameState.last_sanctuary_id
		] = level_path

	# ----------------------------------------------
	# RESTORE PERMANENT UPGRADES
	# ----------------------------------------------

	GameState.vitality = clampi(
		int(data.get("vitality", 0)),
		0,
		GameState.MAX_STAT_RANK
	)

	GameState.ferocity = clampi(
		int(data.get("ferocity", 0)),
		0,
		GameState.MAX_STAT_RANK
	)

	GameState.concentration = clampi(
		int(data.get("concentration", 0)),
		0,
		GameState.MAX_STAT_RANK
	)

	GameState.fluidity = clampi(
		int(data.get("fluidity", 0)),
		0,
		GameState.MAX_STAT_RANK
	)

	GameState.max_health_changed.emit(
		GameState.get_max_health()
	)

	# ----------------------------------------------
	# RESTORE ESSENCE
	# ----------------------------------------------

	GameState.essence = maxi(
		int(data.get("essence", 0)),
		0
	)

	# ----------------------------------------------
	# RESTORE PLAYER RESOURCES
	# ----------------------------------------------

	GameState.health = int(
		data.get(
			"health",
			GameState.get_max_health()
		)
	)

	GameState.ammo = int(
		data.get(
			"ammo",
			GameState.MAX_AMMO
		)
	)

	# ----------------------------------------------
	# LOAD SUMMARY
	# ----------------------------------------------

	print("Save data loaded successfully!")
	print("Current level: ", GameState.current_level)
	print("Checkpoint: ", GameState.last_sanctuary_id)

	print(
		"Discovered sanctuaries: ",
		GameState.discovered_sanctuaries.keys()
	)

	print("Essence: ", GameState.essence)
	print("Vitality: ", GameState.vitality)
	print("Ferocity: ", GameState.ferocity)
	print("Concentration: ", GameState.concentration)
	print("Fluidity: ", GameState.fluidity)

	return true


# ==================================================
# CHECK IF SAVE EXISTS
# ==================================================

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# ==================================================
# DELETE SAVE
# ==================================================

func delete_save() -> void:

	if has_save():

		var error: Error = DirAccess.remove_absolute(
			SAVE_PATH
		)

		if error != OK:
			push_error("Failed to delete save file.")
		else:
			print("Save file deleted.")


# ==================================================
# RESPAWN PLAYER
# ==================================================

func respawn_player() -> void:

	print("SAVE MANAGER: Player respawning...")

	if not load_game():

		print("SAVE MANAGER: No valid checkpoint found.")

		GameState.reset_for_new_game()

		get_tree().paused = false

		var restart_error: Error = (
			get_tree().change_scene_to_file(
				GameState.current_level
			)
		)

		if restart_error != OK:
			push_error("Failed to restart game.")

		return

	# Reset defeated enemies after death.
	GameState.reset_enemy_progress()

	# Restore player resources.
	GameState.health = GameState.get_max_health()
	GameState.ammo = GameState.MAX_AMMO

	# Respawn at the saved sanctuary.
	GameState.loading_from_save = true

	get_tree().paused = false

	var error: Error = get_tree().change_scene_to_file(
		GameState.current_level
	)

	if error != OK:

		GameState.loading_from_save = false

		push_error("SAVE MANAGER: Respawn failed!")
		return

	print(
		"Respawning at: ",
		GameState.last_sanctuary_id
	)

	print("Health restored: ", GameState.health)
	print("Essence retained: ", GameState.essence)
