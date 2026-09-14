extends Node2D

var has_key: bool = false
var level_completing: bool = false

@onready var key = $Key


func _ready() -> void:
	key.collected.connect(_on_key_collected)


func _on_key_collected() -> void:
	has_key = true
	print("LEVEL: Key collected!")


func complete_level() -> void:
	if level_completing:
		return

	level_completing = true
	print("LEVEL COMPLETE!")
	call_deferred("_load_next_level")


func _load_next_level() -> void:
	get_tree().change_scene_to_file("res://Scenes/level_2.tscn")
