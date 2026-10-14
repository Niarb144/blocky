extends CharacterBody2D


const SHADOW_ENERGY_BLADE = preload(
	"res://Scenes/Projectiles/shadow_energy_blade.tscn"
)


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

@export_group("Melee Attack")
@export var melee_damage: int = 20
@export var melee_range: float = 55.0
@export var melee_hitbox_offset: float = 28.0


@export_group("Heavy Attack")
@export var heavy_damage: int = 35
@export var heavy_range: float = 65.0
@export var heavy_hitbox_offset: float = 35.0

@export var heavy_start_frame: int = 3
@export var heavy_end_frame: int = 4

@export var basic_attack_cooldown: float = 1.2
@export var heavy_attack_cooldown: float = 1.8


@export_group("Melee Hitbox Position")

@export var basic_hitbox_y: float = 35.0
@export var heavy_hitbox_y: float = 30.0


# Frames where the sword can deal damage.
@export var melee_start_frame: int = 2
@export var melee_end_frame: int = 3

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var melee_hitbox: Area2D = $MeleeHitBox
@onready var projectile_spawn: Marker2D = $ProjectileSpawn
@onready var ground_check: RayCast2D = $GroundCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var attack_cooldown: Timer = $AttackCooldown


@export_group("Ranged Attack")
@export var ranged_damage: int = 15
@export var ranged_min_distance: float = 80.0
@export var ranged_max_distance: float = 200.0
@export var ranged_cooldown: float = 2.5

# Frame where the projectile is released.
@export var projectile_fire_frame: int = 9

var projectile_fired: bool = false

var health: int
var current_state: State = State.IDLE

var player: CharacterBody2D = null
var facing_direction: int = 1

var melee_active: bool = false
var hit_targets: Array[Node2D] = []

enum AttackType {
	NONE,
	BASIC_SLASH,
	HEAVY_SLASH,
	ENERGY_BLADE
}


var current_attack: AttackType = AttackType.NONE
var last_attack: AttackType = AttackType.NONE

var current_attack_damage: int = 0

var active_start_frame: int = 0
var active_end_frame: int = 0

var current_attack_range: float = 0.0
var current_hitbox_offset: float = 0.0



func _ready() -> void:
	health = max_health

	# Keep monitoring active for overlap detection.
	melee_hitbox.monitoring = true

	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_exited)

	animated_sprite.frame_changed.connect(_on_animation_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)

	ground_check.enabled = true
	wall_check.enabled = true

	update_facing_direction(1)

	change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

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
			handle_attack()

		State.HURT:
			velocity.x = 0.0

	# Check sword collision during active frames.
	if melee_active:
		check_melee_hits()

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

	# Always face the player before attacking.
	if distance_x > 0.0:
		update_facing_direction(1)
	elif distance_x < 0.0:
		update_facing_direction(-1)

	# Attack when within melee range.
	
# Choose an attack when close enough.
	
	if attack_cooldown.is_stopped():
		if distance <= heavy_range or (
			distance >= ranged_min_distance
			and distance <= ranged_max_distance
		):
			choose_attack(distance)

			if current_state == State.ATTACK:
				return



	# Stay close to the player while waiting.
	if distance <= stopping_distance:
		velocity.x = 0.0
		play_animation("idle")
		return

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


func handle_attack() -> void:
	# Prevent the boss from sliding while attacking.
	velocity.x = 0.0



func choose_attack(distance: float) -> void:
	if current_state != State.CHASE:
		return

	if not attack_cooldown.is_stopped():
		return

	# Ranged attack when the player is farther away.
	if (
		distance >= ranged_min_distance
		and distance <= ranged_max_distance
	):
		start_ranged_attack()
		return

	# Alternate between melee attacks.
	if distance <= heavy_range:
		if last_attack == AttackType.BASIC_SLASH:
			start_heavy_attack()

		elif last_attack == AttackType.HEAVY_SLASH:
			start_basic_attack()

		else:
			if distance <= melee_range:
				start_basic_attack()
			else:
				start_heavy_attack()


func start_basic_attack() -> void:
	start_attack(
		AttackType.BASIC_SLASH,
		"attack_1",
		melee_damage,
		melee_range,
		melee_hitbox_offset,
		melee_start_frame,
		melee_end_frame,
		basic_attack_cooldown
	)


func start_heavy_attack() -> void:
	start_attack(
		AttackType.HEAVY_SLASH,
		"attack_2",
		heavy_damage,
		heavy_range,
		heavy_hitbox_offset,
		heavy_start_frame,
		heavy_end_frame,
		heavy_attack_cooldown
	)


func start_attack(
	attack_type: AttackType,
	animation_name: String,
	damage: int,
	attack_range: float,
	hitbox_offset: float,
	start_frame: int,
	end_frame: int,
	cooldown: float
) -> void:

	if current_state == State.DEAD:
		return

	if not animated_sprite.sprite_frames.has_animation(animation_name):
		push_warning("Missing attack animation: " + animation_name)
		return

	change_state(State.ATTACK)

	velocity.x = 0.0

	current_attack = attack_type
	last_attack = attack_type

	current_attack_damage = damage
	current_attack_range = attack_range
	current_hitbox_offset = hitbox_offset

	active_start_frame = start_frame
	active_end_frame = end_frame

	melee_active = false
	hit_targets.clear()

	# Change melee hitbox position.
	
	# Position the hitbox according to the attack.
	var vertical_offset: float = basic_hitbox_y

	if attack_type == AttackType.HEAVY_SLASH:
		vertical_offset = heavy_hitbox_y

	melee_hitbox.position = Vector2(
		current_hitbox_offset * facing_direction,
		vertical_offset
	)


	# Change hitbox dimensions for this attack.
	var hitbox_shape: CollisionShape2D = (
		melee_hitbox.get_node("CollisionShape2D")
	)

	var rectangle: RectangleShape2D = hitbox_shape.shape as RectangleShape2D

	
	if rectangle != null:
		if attack_type == AttackType.HEAVY_SLASH:
			rectangle.size = Vector2(85.0, 80.0)
		else:
			rectangle.size = Vector2(65.0, 65.0)


	attack_cooldown.start(cooldown)

	animated_sprite.play(animation_name)
	animated_sprite.set_frame_and_progress(0, 0.0)

	print("Shadow Demon attack: ", animation_name)




func check_melee_hits() -> void:
	if not melee_active:
		return

	for body in melee_hitbox.get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue

		if body in hit_targets:
			continue

		if not body.has_method("take_damage"):
			continue

		hit_targets.append(body)

		body.take_damage(current_attack_damage)

		print(
			"Shadow Demon dealt ",
			current_attack_damage,
			" damage using ",
			current_attack
		)


func start_ranged_attack() -> void:
	if current_state != State.CHASE:
		return

	if not attack_cooldown.is_stopped():
		return

	if not animated_sprite.sprite_frames.has_animation("attack_3"):
		push_warning("Shadow Demon: attack_3 animation missing.")
		return

	change_state(State.ATTACK)

	velocity.x = 0.0

	current_attack = AttackType.ENERGY_BLADE
	last_attack = AttackType.ENERGY_BLADE

	melee_active = false
	hit_targets.clear()

	projectile_fired = false

	attack_cooldown.start(ranged_cooldown)

	animated_sprite.play("attack_3")
	animated_sprite.set_frame_and_progress(0, 0.0)

	print("Shadow Demon: Energy Blade!")


func fire_energy_blade() -> void:
	if projectile_fired:
		return

	if current_state != State.ATTACK:
		return

	if current_attack != AttackType.ENERGY_BLADE:
		return

	projectile_fired = true

	var blade = SHADOW_ENERGY_BLADE.instantiate()

	blade.setup(facing_direction, ranged_damage)

	# Add to the level, not to the boss.
	get_tree().current_scene.add_child(blade)

	blade.global_position = projectile_spawn.global_position

	print("Shadow Demon fired Energy Blade!")



func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
		return

	match current_attack:

		AttackType.BASIC_SLASH, AttackType.HEAVY_SLASH:
			var current_frame: int = animated_sprite.frame

			melee_active = (
				current_frame >= active_start_frame
				and current_frame <= active_end_frame
			)

		AttackType.ENERGY_BLADE:
			melee_active = false

			if (
				animated_sprite.frame >= projectile_fire_frame
				and not projectile_fired
			):
				fire_energy_blade()



func _on_animation_finished() -> void:
	if current_state == State.DEAD:
		return

	if current_state != State.ATTACK:
		return

	melee_active = false
	hit_targets.clear()

	current_attack = AttackType.NONE
	current_attack_damage = 0
	projectile_fired = false

	melee_hitbox.position = Vector2(
		melee_hitbox_offset * facing_direction,
		basic_hitbox_y
	)

	if is_instance_valid(player):
		change_state(State.CHASE)
	else:
		change_state(State.IDLE)



func update_facing_direction(direction: int) -> void:
	if direction == 0:
		return

	facing_direction = direction

	# Flip the artwork only.
	visuals.scale.x = absf(visuals.scale.x) * facing_direction

	# Position the melee hitbox in front of the boss.
	
	var hitbox_x: float = melee_hitbox_offset
	var hitbox_y: float = basic_hitbox_y

	if current_attack == AttackType.HEAVY_SLASH:
		hitbox_x = heavy_hitbox_offset
		hitbox_y = heavy_hitbox_y

	melee_hitbox.position = Vector2(
		hitbox_x * facing_direction,
		hitbox_y
	)


	# Position the future projectile spawn.
	projectile_spawn.position.x = (
		absf(projectile_spawn.position.x) * facing_direction
	)

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

	if (
		animated_sprite.animation != animation_name
		or not animated_sprite.is_playing()
	):
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
	projectile_fired = false
	
	velocity = Vector2.ZERO
	melee_active = false
	current_attack = AttackType.NONE
	current_attack_damage = 0
	hit_targets.clear()

	attack_cooldown.stop()

	print("SHADOW DEMON DEFEATED!")

	if animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		animated_sprite.stop()


func _on_player_detected(body: Node2D) -> void:
	if current_state == State.DEAD:
		return

	if body.is_in_group("player") and body is CharacterBody2D:
		player = body
		change_state(State.CHASE)


func _on_player_exited(body: Node2D) -> void:
	if body == player:
		player = null

		if current_state == State.CHASE:
			change_state(State.IDLE)
