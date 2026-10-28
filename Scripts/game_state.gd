extends Node

signal ammo_changed(current_ammo: int, max_ammo: int)
signal health_changed(current_health: int, max_health: int)
signal essence_changed(amount: int)
signal upgrade_purchased(stat: String, rank: int)
signal max_health_changed(value: int)

const MAX_AMMO: int = 6
const MAX_HEALTH: int = 100
const MAX_STAT_RANK: int = 5

const STARTING_LEVEL: String = "res://Scenes/level.tscn"

const UPGRADE_BASE_COSTS := {
	"vitality": 50,
	"ferocity": 60,
	"concentration": 75,
	"fluidity": 85
}

const UPGRADE_COST_INCREASE: int = 25

var current_level: String = STARTING_LEVEL
var last_sanctuary_id: String = ""
var loading_from_save: bool = false

# Progression
var essence: int = 0:
	set(value):
		essence = maxi(value, 0)
		essence_changed.emit(essence)

var vitality: int = 0
var ferocity: int = 0
var concentration: int = 0
var fluidity: int = 0

# Resources
var ammo: int = MAX_AMMO:
	set(value):
		ammo = clampi(value, 0, MAX_AMMO)
		ammo_changed.emit(ammo, MAX_AMMO)

var health: int = MAX_HEALTH:
	set(value):
		health = clampi(value, 0, get_max_health())
		health_changed.emit(health, get_max_health())


# ============================================
# WORLD PROGRESSION
# ============================================

var collected_keys: Dictionary = {}

# Sanctuaries the player has discovered.
# sanctuary_id -> level scene path
var discovered_sanctuaries: Dictionary = {}

# Temporary scene-entry information.
var pending_spawn_id: String = ""

# Prevent multiple simultaneous scene transitions.
var is_transitioning: bool = false


func collect_key(key_id: String) -> void:
	if key_id.is_empty():
		return

	if collected_keys.get(key_id, false):
		return

	collected_keys[key_id] = true

	print("GAMESTATE: Collected key: ", key_id)


func has_key(key_id: String) -> bool:
	return collected_keys.get(key_id, false)


func discover_sanctuary(
	sanctuary_id: String,
	level_path: String
) -> void:
	if sanctuary_id.is_empty():
		return

	if not ResourceLoader.exists(level_path):
		return

	discovered_sanctuaries[sanctuary_id] = level_path

	print("GAMESTATE: Discovered ", sanctuary_id)


func has_discovered_sanctuary(
	sanctuary_id: String
) -> bool:
	return discovered_sanctuaries.has(sanctuary_id)


func reset_level_progress() -> void:
	collected_keys.clear()
	discovered_sanctuaries.clear()
	pending_spawn_id = ""
	is_transitioning = false


func get_max_health() -> int:
	return MAX_HEALTH + vitality * 10


func get_melee_multiplier() -> float:
	return 1.0 + ferocity * 0.05


func get_ranged_multiplier() -> float:
	return 1.0 + concentration * 0.07


func get_dash_cooldown(base_cooldown: float) -> float:
	return maxf(
		base_cooldown * (1.0 - fluidity * 0.03),
		0.1
	)


func add_essence(amount: int) -> void:
	if amount <= 0:
		return

	essence += amount


func get_stat_rank(stat: String) -> int:
	match stat:
		"vitality":
			return vitality
		"ferocity":
			return ferocity
		"concentration":
			return concentration
		"fluidity":
			return fluidity
		_:
			return -1


func get_upgrade_cost(stat: String) -> int:
	if not UPGRADE_BASE_COSTS.has(stat):
		return -1

	var rank: int = get_stat_rank(stat)

	if rank >= MAX_STAT_RANK:
		return -1

	return (
		int(UPGRADE_BASE_COSTS[stat])
		+ rank * UPGRADE_COST_INCREASE
	)


func purchase_upgrade(stat: String) -> bool:
	var cost: int = get_upgrade_cost(stat)

	if cost < 0 or essence < cost:
		return false

	var old_max_health: int = get_max_health()

	match stat:
		"vitality":
			vitality += 1
		"ferocity":
			ferocity += 1
		"concentration":
			concentration += 1
		"fluidity":
			fluidity += 1
		_:
			return false

	essence -= cost

	if stat == "vitality":
		var increase: int = get_max_health() - old_max_health
		health += increase
		max_health_changed.emit(get_max_health())

	upgrade_purchased.emit(stat, get_stat_rank(stat))

	print("Purchased ", stat, " upgrade.")

	return true


func reset_for_new_game() -> void:
	current_level = STARTING_LEVEL
	last_sanctuary_id = ""
	loading_from_save = false

	vitality = 0
	ferocity = 0
	concentration = 0
	fluidity = 0
	essence = 0

	ammo = MAX_AMMO
	health = get_max_health()

	max_health_changed.emit(get_max_health())
	
	reset_level_progress()
	reset_enemy_progress()

func rest_at_sanctuary() -> void:
	health = get_max_health()
	ammo =+1



func fast_travel(sanctuary_id: String) -> void:
	if is_transitioning:
		return

	if not has_discovered_sanctuary(sanctuary_id):
		push_warning("Sanctuary has not been discovered.")
		return

	var destination: String = str(
		discovered_sanctuaries[sanctuary_id]
	)

	if not ResourceLoader.exists(destination):
		push_error("Fast travel scene does not exist.")
		return

	is_transitioning = true

	# Normal travel, not checkpoint loading.
	loading_from_save = false

	pending_spawn_id = "sanctuary:" + sanctuary_id

	get_tree().paused = false

	var error := get_tree().change_scene_to_file(
		destination
	)

	if error != OK:
		is_transitioning = false
		pending_spawn_id = ""
		push_error("Failed to fast travel.")

# ==================================================
# ENEMY PERSISTENCE
# ==================================================

# Tracks defeated enemies during the current run.
# This data is NOT written into SaveManager.
#
# Example:
# {
#     "res://Scenes/level.tscn": {
#         "blood_monster_01": true,
#         "blood_monster_02": true
#     }
# }

var defeated_enemies: Dictionary = {}


# Record an enemy as defeated.
func register_enemy_defeat(
	level_path: String,
	enemy_id: String
) -> void:

	if level_path.is_empty() or enemy_id.is_empty():
		return

	if not defeated_enemies.has(level_path):
		defeated_enemies[level_path] = {}

	defeated_enemies[level_path][enemy_id] = true

	print(
		"GAMESTATE: Enemy defeated: ",
		enemy_id,
		" in ",
		level_path
	)


# Check whether an enemy was defeated.
func is_enemy_defeated(
	level_path: String,
	enemy_id: String
) -> bool:

	if not defeated_enemies.has(level_path):
		return false

	return defeated_enemies[level_path].get(
		enemy_id,
		false
	)


# Restore regular enemies after player death.
func reset_enemy_progress() -> void:
	defeated_enemies.clear()

	print("GAMESTATE: Enemy population reset.")
