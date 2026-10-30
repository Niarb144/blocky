extends Area2D

@export var lifetime: float = 4.0

var damage: int = 15
var direction: Vector2 = Vector2.RIGHT
var speed: float = 450.0

var active: bool = true


func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(
		queue_free
	)


func setup(
	new_direction: Vector2,
	new_speed: float,
	new_damage: int
) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage

	rotation = direction.angle() + PI


func _physics_process(delta: float) -> void:
	if not active:
		return

	var movement := direction * speed * delta
	var next_position := global_position + movement

	var space_state := get_world_2d().direct_space_state

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		next_position
	)

	query.collision_mask = collision_mask
	query.exclude = [get_rid()]

	var result := space_state.intersect_ray(query)

	if not result.is_empty():
		var body: Object = result["collider"]

		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(damage)

		destroy_arrow()
		return

	global_position = next_position


func destroy_arrow() -> void:
	if not active:
		return

	active = false
	queue_free()
