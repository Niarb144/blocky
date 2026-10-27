
extends Area2D

@export_group("Destination")

@export_file("*.tscn")
var destination_level: String = ""

@export var destination_spawn_id: String = "EntryFromPrevious"

@export_group("Unlock Requirements")

# Leave empty for an unlocked passage.
@export var required_key_id: String = ""

var is_locked: bool = false


func _ready() -> void:
	refresh_lock_state()


func refresh_lock_state() -> void:
	is_locked = (
		not required_key_id.is_empty()
		and not GameState.has_key(required_key_id)
	)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if GameState.is_transitioning:
		return

	refresh_lock_state()

	if is_locked:
		print(
			"EXIT LOCKED: Requires ",
			required_key_id
		)
		return

	if destination_level.is_empty():
		push_warning("EXIT: Destination not configured.")
		return

	if not ResourceLoader.exists(destination_level):
		push_error("EXIT: Destination scene missing.")
		return

	print("EXIT UNLOCKED!")

	GameState.is_transitioning = true

	# Inform the destination where to spawn the player.
	GameState.pending_spawn_id = destination_spawn_id

	AudioManager.play_exit()

	# Defer scene changes triggered by physics signals.
	call_deferred("_travel")


func _travel() -> void:
	var error := get_tree().change_scene_to_file(
		destination_level
	)

	if error != OK:
		GameState.pending_spawn_id = ""
		GameState.is_transitioning = false
		push_error("EXIT: Scene transition failed.")
