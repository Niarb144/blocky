extends Node2D

var has_key: bool = false

@onready var key = $Key


func _ready() -> void:
	print("Level started")
	print("Key reference: ", key)

	if key != null:
		key.collected.connect(_on_key_collected)
	else:
		print("ERROR: Key node was not found!")


func _on_key_collected() -> void:
	has_key = true
	print("LEVEL: Key collected!")
