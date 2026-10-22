
extends Node

signal ammo_changed(current_ammo: int, max_ammo: int)
signal health_changed(current_health: int, max_health: int)

const MAX_AMMO: int = 6
const MAX_HEALTH: int = 100

const STARTING_LEVEL: String = "res://Scenes/level.tscn"

var current_level: String = STARTING_LEVEL
var last_sanctuary_id: String = ""

var loading_from_save: bool = false

var ammo: int = MAX_AMMO:
	set(value):
		var new_amount: int = clampi(value, 0, MAX_AMMO)

		if ammo == new_amount:
			return

		ammo = new_amount
		ammo_changed.emit(ammo, MAX_AMMO)


var health: int = MAX_HEALTH:
	set(value):
		var new_amount: int = clampi(value, 0, MAX_HEALTH)

		if health == new_amount:
			return

		health = new_amount
		health_changed.emit(health, MAX_HEALTH)


func reset_for_new_game() -> void:
	current_level = STARTING_LEVEL
	last_sanctuary_id = ""
	loading_from_save = false

	ammo = MAX_AMMO
	health = MAX_HEALTH


func rest_at_sanctuary() -> void:
	health = MAX_HEALTH
	ammo = MAX_AMMO
