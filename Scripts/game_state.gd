extends Node

signal ammo_changed(current_ammo: int, max_ammo: int)
signal health_changed(current_health: int, max_health: int)

const MAX_AMMO: int = 6
const MAX_HEALTH: int = 100

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
	ammo = MAX_AMMO
	health = MAX_HEALTH
