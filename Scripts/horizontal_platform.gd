extends AnimatableBody2D

@export var speed: float = 100.0

@onready var point_a: Marker2D = $PointA
@onready var point_b: Marker2D = $PointB

var point_a_position: Vector2
var point_b_position: Vector2
var target_position: Vector2


func _ready() -> void:
	point_a_position = point_a.global_position
	point_b_position = point_b.global_position

	target_position = point_b_position


func _physics_process(delta: float) -> void:
	global_position = global_position.move_toward(
		target_position,
		speed * delta
	)

	if global_position.distance_to(target_position) < 1.0:
		if target_position == point_b_position:
			target_position = point_a_position
		else:
			target_position = point_b_position
