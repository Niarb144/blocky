
extends Node2D

@export var sanctuary_id: String = "sanctuary_01"

var player_nearby: bool = false

@onready var interaction_label: Label = $InteractionLabel


func _ready() -> void:
	interaction_label.hide()


func _process(_delta: float) -> void:
	if player_nearby:
		if Input.is_action_just_pressed("interact"):
			activate_sanctuary()


func activate_sanctuary() -> void:
	var level := get_tree().current_scene

	GameState.current_level = level.scene_file_path
	GameState.last_sanctuary_id = sanctuary_id

	GameState.rest_at_sanctuary()

	if SaveManager.save_game():
		print("Sanctuary activated: ", sanctuary_id)


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		interaction_label.show()


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		interaction_label.hide()
