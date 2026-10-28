
extends Node

# ==================================================
# SAVE SETTINGS
# ==================================================

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 2


# ==================================================
# SAVE GAME
# ==================================================

# Saves the current checkpoint, player resources,
# Essence balance, and permanent upgrade ranks.
func save_game() -> bool:

	var save_data: Dictionary = {
		"version": SAVE_VERSION,

		# Checkpoint information
		"level": GameState.current_level,
		"sanctuary_id": GameState.last_sanctuary_id,

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
	print("Essence saved: ", GameState.essence)

	return true


# ==================================================
# LOAD GAME
# ==================================================

# Reads saved data and restores the player progression.
# Supports existing version 1 saves.
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

	# Allow previous saves without upgrade data.
	var version: int = int(data.get("version", -1))

	if version != 1 and version != SAVE_VERSION:
		push_error("Unsupported save version.")
		return false

	# Validate the saved level before changing GameState.
	var level_path: String = str(
		data.get("level", GameState.STARTING_LEVEL)
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
	# RESTORE PERMANENT UPGRADES
	# ----------------------------------------------

	# Restore these BEFORE health because Vitality
	# changes the maximum health available.

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

	# Notify any active health UI that maximum
	# health may have changed after loading.
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
		data.get("health", GameState.get_max_health())
	)

	GameState.ammo = int(
		data.get("ammo", GameState.MAX_AMMO)
	)

	print("Save data loaded successfully!")
	print("Current level: ", GameState.current_level)
	print("Sanctuary: ", GameState.last_sanctuary_id)
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

# Called after the player death animation finishes.
# Loads the saved checkpoint and restores resources.
func respawn_player() -> void:

	print("SAVE MANAGER: Player respawning...")

	# Attempt to load the most recent save.
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
	#Load Enemy
	GameState.reset_enemy_progress()
	
	# ----------------------------------------------
	# RESTORE PLAYER RESOURCES
	# ----------------------------------------------

	# Health must use the upgraded maximum.
	GameState.health = GameState.get_max_health()

	GameState.ammo = GameState.MAX_AMMO

	# ----------------------------------------------
	# RESPAWN AT SAVED SANCTUARY
	# ----------------------------------------------

	GameState.loading_from_save = true

	get_tree().paused = false

	var error: Error = get_tree().change_scene_to_file(
		GameState.current_level
	)

	if error != OK:
		GameState.loading_from_save = false
		push_error("SAVE MANAGER: Respawn failed!")
		return

	print("Respawning at: ", GameState.last_sanctuary_id)
	print("Health restored: ", GameState.health)
	print("Essence retained: ", GameState.essence)
