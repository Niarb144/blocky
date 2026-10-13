
extends CharacterBody2D

enum State {
	IDLE,
	CHASE,
	ATTACK,
	HURT,
	DEAD
}

@export_group("Movement")
@export var move_speed: float = 90.0
@export var gravity: float = 1200.0
@export var stopping_distance: float = 35.0

@export_group("Health")
@export var max_health: int = 400

@export_group("Detection")
@export var ground_check_distance: float = 20.0
@export var wall_check_distance: float = 30.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var melee_hitbox: Area2D = $MeleeHitBox
@onready var ground_check: RayCast2D = $GroundCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var attack_cooldown: Timer = $AttackCooldown

var health: int
var current_state: State = State.IDLE

var player: CharacterBody2D = null
var facing_direction: int = 1


func _ready() -> void:
	health = max_health

	melee_hitbox.set_deferred("monitoring", false)

	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_exited)

	ground_check.enabled = true
	wall_check.enabled = true

	update_facing_direction(1)

	change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	match current_state:
		State.IDLE:
			handle_idle()

		State.CHASE:
			handle_chase()

		State.ATTACK:
			velocity.x = 0.0

		State.HURT:
			velocity.x = 0.0

	move_and_slide()


func handle_idle() -> void:
	velocity.x = 0.0
	play_animation("idle")


func handle_chase() -> void:
	if not is_instance_valid(player):
		player = null
		change_state(State.IDLE)
		return

	var distance_x: float = (
		player.global_position.x - global_position.x
	)

	var distance: float = absf(distance_x)

	# Turn toward player
	if distance_x > 0:
		update_facing_direction(1)
	elif distance_x < 0:
		update_facing_direction(-1)

	# Stop when close enough
	if distance <= stopping_distance:
		velocity.x = 0.0
		play_animation("idle")
		return

	# Do not walk off platforms or into walls
	ground_check.force_raycast_update()
	wall_check.force_raycast_update()

	if wall_check.is_colliding():
		velocity.x = 0.0
		play_animation("idle")
		return

	if is_on_floor() and not ground_check.is_colliding():
		velocity.x = 0.0
		play_animation("idle")
		return

	velocity.x = facing_direction * move_speed
	play_animation("run")


func update_facing_direction(direction: int) -> void:
	if direction == 0:
		return

	facing_direction = direction

	# Flip only the artwork.
	# Keep the physics body unflipped.
	visuals.scale.x = absf(visuals.scale.x) * facing_direction

	# Update raycast positions
	ground_check.position.x = (
		ground_check_distance * facing_direction
	)

	wall_check.target_position.x = (
		wall_check_distance * facing_direction
	)


func change_state(new_state: State) -> void:
	if current_state == State.DEAD:
		return

	current_state = new_state

	match current_state:
		State.IDLE:
			play_animation("idle")

		State.CHASE:
			play_animation("run")

		State.ATTACK:
			velocity.x = 0.0

		State.HURT:
			velocity.x = 0.0


func play_animation(animation_name: String) -> void:
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


func take_damage(amount: int) -> void:
	if current_state == State.DEAD:
		return

	health = maxi(health - amount, 0)

	print("Shadow Demon Health: ", health, "/", max_health)

	if health <= 0:
		die()


func die() -> void:
	current_state = State.DEAD

	velocity = Vector2.ZERO

	melee_hitbox.set_deferred("monitoring", false)

	print("SHADOW DEMON DEFEATED!")

	if animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		animated_sprite.stop()


func _on_player_detected(body: Node2D) -> void:
	if current_state == State.DEAD:
		return

	if body.is_in_group("player"):
		if body is CharacterBody2D:
			player = body
			change_state(State.CHASE)


func _on_player_exited(body: Node2D) -> void:
	if body == player:
		player = null

		if current_state != State.DEAD:
			change_state(State.IDLE)
