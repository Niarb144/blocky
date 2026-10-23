extends Node2D

@export var speed: float = 300.0
@export var lifetime: float = 5.0

# Select the player's layer AND all ground/wall/platform layers.
@export_flags_2d_physics var hit_mask: int = 0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 15

var excluded_bodies: Array[RID] = []
var spent: bool = false


func setup(
	shot_direction: Vector2,
	shot_damage: int,
	shooter_rid: RID
) -> void:
	direction = shot_direction.normalized()
	damage = shot_damage
	excluded_bodies = [shooter_rid]

	global_rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if spent:
		return

	lifetime -= delta

	if lifetime <= 0.0:
		spent = true
		queue_free()
		return

	var next_position: Vector2 = (
		global_position + direction * speed * delta
	)

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		next_position,
		hit_mask,
		excluded_bodies
	)

	query.hit_from_inside = true

	var hit: Dictionary = (
		get_world_2d().direct_space_state.intersect_ray(query)
	)

	if not hit.is_empty():
		spent = true
		global_position = hit["position"]

		var body: Node = hit["collider"] as Node

		if is_instance_valid(body):
			if body.is_in_group("player"):
				if body.has_method("take_damage"):
					body.take_damage(damage)

		queue_free()
		return

	global_position = next_position
