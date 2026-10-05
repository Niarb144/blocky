extends Node

signal ammo_changed(current_ammo: int, max_ammo: int)

const MAX_AMMO: int = 6

var ammo: int = MAX_AMMO:
	set(value):
		var new_amount: int = clampi(value, 0, MAX_AMMO)

		if ammo == new_amount:
			return

		ammo = new_amount
		ammo_changed.emit(ammo, MAX_AMMO)


func reset_for_new_game() -> void:
	ammo = MAX_AMMO
