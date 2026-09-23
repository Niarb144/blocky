extends AnimatableBody2D

@export_category("Movement")
@export var speed: float = 100.0
@export var travel_distance: float = 300.0
@export var move_right: bool = true
@export var wait_time: float = 0.0

var start_position: Vector2
var end_position: Vector2
var target_position: Vector2

var waiting: bool = false
var wait_timer: float = 0.0


func _ready() -> void:
	start_position = global_position

	var direction := 1.0 if move_right else -1.0

	end_position = start_position + Vector2(
		travel_distance * direction,
		0.0
	)

	target_position = end_position


func _physics_process(delta: float) -> void:
	if waiting:
		wait_timer -= delta

		if wait_timer <= 0.0:
			waiting = false

		return

	global_position = global_position.move_toward(
		target_position,
		speed * delta
	)

	if global_position.distance_to(target_position) < 1.0:
		global_position = target_position

		if target_position == end_position:
			target_position = start_position
		else:
			target_position = end_position

		if wait_time > 0.0:
			waiting = true
			wait_timer = wait_time
