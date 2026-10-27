
extends Area2D

signal collected(key_id: String)

@export var key_id: String = "catacomb_key"

@export_group("Floating Animation")
@export var float_height: float = 8.0
@export var float_speed: float = 2.0

var start_position: Vector2
var time: float = 0.0
var is_collected: bool = false


func _ready() -> void:
	# Keys are restored when the level loads.
	if GameState.has_key(key_id):
		queue_free()
		return

	start_position = position

	print("KEY READY: ", key_id)


func _process(delta: float) -> void:
	if is_collected:
		return

	time += delta * float_speed

	position.y = (
		start_position.y
		+ sin(time) * float_height
	)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	collect()


func collect() -> void:
	if is_collected:
		return

	is_collected = true

	GameState.collect_key(key_id)

	AudioManager.play_key_pickup()

	collected.emit(key_id)

	print("KEY COLLECTED: ", key_id)

	queue_free()
