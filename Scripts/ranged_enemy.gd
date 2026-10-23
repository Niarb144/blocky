extends CharacterBody2D

enum State { IDLE, SHOOT, HURT, DEAD }

const ENEMY_PROJECTILE = preload(
	"res://Scenes/Projectiles/enemy_projectile.tscn"
)

const AMMO_PICKUP = preload(
	"res://Scenes/ammo_pickup.tscn"
)

@export_group("Health")
@export var max_health: int = 60
@export var hurt_duration: float = 0.3

@export_group("Ranged Attack")
@export var projectile_damage: int = 15
@export var detection_range: float = 400.0
@export var attack_cooldown: float = 1.5

# Zero-based animation frame index.
@export var shoot_release_frame: int = 4

# Offset from the player root toward their body centre.
@export var player_aim_offset: Vector2 = Vector2.ZERO

# Select only solid ground/wall/platform layers.
@export_flags_2d_physics var world_mask: int = 0

@export_group("Ammo Drop")
@export_range(0.0, 1.0, 0.05) var ammo_drop_chance: float = 1.0
@export_range(1, 6) var min_ammo_drops: int = 1
@export_range(1, 6) var max_ammo_drops: int = 3
@export var ammo_drop_offset: Vector2 = Vector2(0, -10)
@export var ammo_drop_spread: float = 10.0

@export_group("Essence Reward")
@export var essence_reward: int = 10

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aim_pivot: Node2D = $AimPivot
@onready var shoot_point: Marker2D = $AimPivot/ShootPoint

var state: State = State.IDLE
var health: int = 0

var cooldown_remaining: float = 0.0
var hurt_remaining: float = 0.0
var shot_released: bool = false

var essence_awarded: bool = false
var player: Node2D = null


func _ready() -> void:
	health = max_health

	find_player()

	sprite.animation_finished.connect(
		_on_animation_finished
	)

	sprite.frame_changed.connect(
		_on_sprite_frame_changed
	)

	sprite.play("idle")


func find_player() -> void:
	player = get_tree().get_first_node_in_group(
		"player"
	) as Node2D


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	cooldown_remaining = maxf(
		cooldown_remaining - delta,
		0.0
	)

	if not is_instance_valid(player):
		find_player()

	match state:
		State.HURT:
			hurt_remaining -= delta

			if hurt_remaining <= 0.0:
				state = State.IDLE
				sprite.play("idle")

		State.SHOOT:
			# Track the player during the wind-up.
			# The projectile direction locks when fired.
			if player_is_alive():
				update_aim()

		State.IDLE:
			if can_detect_player():
				update_aim()

				if cooldown_remaining <= 0.0:
					start_shooting()
			else:
				sprite.play("idle")


func player_is_alive() -> bool:
	if not is_instance_valid(player):
		return false

	return not bool(player.get("is_dead"))


func get_target_position() -> Vector2:
	return player.global_position + player_aim_offset


func can_detect_player() -> bool:
	if not player_is_alive():
		return false

	var distance: float = shoot_point.global_position.distance_to(
		get_target_position()
	)

	if distance > detection_range:
		return false

	return has_clear_sight()


func has_clear_sight() -> bool:
	if not player_is_alive():
		return false

	var exclusions: Array[RID] = [get_rid()]

	var query := PhysicsRayQueryParameters2D.create(
		shoot_point.global_position,
		get_target_position(),
		world_mask,
		exclusions
	)

	query.hit_from_inside = true

	var hit: Dictionary = (
		get_world_2d().direct_space_state.intersect_ray(query)
	)

	return hit.is_empty()


func update_aim() -> void:
	var offset: Vector2 = (
		get_target_position() - aim_pivot.global_position
	)

	if offset.length_squared() > 0.001:
		aim_pivot.global_rotation = offset.angle()

	# Keep the body upright, facing left or right.
	if absf(offset.x) > 2.0:
		sprite.flip_h = offset.x < 0.0


func start_shooting() -> void:
	state = State.SHOOT
	shot_released = false

	sprite.stop()
	sprite.play("shoot")

	# Also supports a release frame of zero.
	_on_sprite_frame_changed()


func _on_sprite_frame_changed() -> void:
	if state != State.SHOOT:
		return

	if sprite.animation != &"shoot":
		return

	if shot_released:
		return

	if sprite.frame < shoot_release_frame:
		return

	shot_released = true

	# Cancel this shot if the player escaped or moved behind cover.
	if not can_detect_player():
		return

	update_aim()

	var origin: Vector2 = shoot_point.global_position
	var shot_direction: Vector2 = (
		get_target_position() - origin
	).normalized()

	if shot_direction == Vector2.ZERO:
		return

	# Defer scene creation to avoid physics query errors.
	spawn_projectile.call_deferred(
		origin,
		shot_direction
	)


func spawn_projectile(
	origin: Vector2,
	shot_direction: Vector2
) -> void:
	var scene: Node = get_tree().current_scene

	if not is_instance_valid(scene):
		return

	var projectile = ENEMY_PROJECTILE.instantiate()

	scene.add_child(projectile)

	projectile.global_position = origin

	projectile.setup(
		shot_direction,
		projectile_damage,
		get_rid()
	)


func take_damage(amount: int) -> void:
	if state == State.DEAD or amount <= 0:
		return

	health = maxi(health - amount, 0)

	if health == 0:
		die()
		return

	# Interrupt an unfinished shooting animation.
	state = State.HURT
	hurt_remaining = hurt_duration
	cooldown_remaining = attack_cooldown

	sprite.stop()
	sprite.play("hurt")


func die() -> void:
	if state == State.DEAD:
		return

	state = State.DEAD
	velocity = Vector2.ZERO

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	award_essence()

	if randf() < ammo_drop_chance:
		drop_ammo.call_deferred(
			global_position + ammo_drop_offset
		)

	sprite.stop()
	sprite.play("death")


func award_essence() -> void:
	if essence_awarded:
		return

	essence_awarded = true
	GameState.add_essence(essence_reward)


func drop_ammo(drop_position: Vector2) -> void:
	var scene: Node = get_tree().current_scene

	if not is_instance_valid(scene):
		return

	var minimum: int = mini(min_ammo_drops, max_ammo_drops)
	var maximum: int = maxi(min_ammo_drops, max_ammo_drops)
	var count: int = randi_range(minimum, maximum)

	for index in range(count):
		var pickup = AMMO_PICKUP.instantiate()

		scene.add_child(pickup)

		var horizontal_offset: float = 0.0

		if count > 1:
			horizontal_offset = lerpf(
				-ammo_drop_spread,
				ammo_drop_spread,
				float(index) / float(count - 1)
			)

		pickup.global_position = drop_position + Vector2(
			horizontal_offset,
			0.0
		)


func _on_animation_finished() -> void:
	if state == State.DEAD and sprite.animation == &"death":
		queue_free()

	elif state == State.SHOOT and sprite.animation == &"shoot":
		cooldown_remaining = attack_cooldown
		state = State.IDLE
		sprite.play("idle")
