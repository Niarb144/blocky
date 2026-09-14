extends Area2D

signal collected

@export var float_height: float = 8.0
@export var float_speed: float = 2.0

var start_position: Vector2
var time: float = 0.0


func _ready() -> void:
	start_position = position
	print("Key ready: ", name)


func _process(delta: float) -> void:
	time += delta * float_speed
	
	position.y = start_position.y + sin(time) * float_height


func _on_body_entered(body: Node2D) -> void:
	print("Key detected body: ", body.name)

	if body.is_in_group("player"):
		print("PLAYER INTERACTED WITH KEY!")
		collect()
	else:
		print("Body is NOT in the player group.")


func collect() -> void:
	print("KEY COLLECTED!")
	collected.emit()
	queue_free()
