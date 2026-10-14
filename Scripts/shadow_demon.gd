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
@export var ranged_min_distance: float = 100.0
@export var ranged_max_distance: float = 350.0
@export var ranged_cooldown: float = 2.5

# Frame where the projectile is released.
@export var projectile_fire_frame: int = 9

var projectile_fired: bool = false


@export_group("Dash Strike")
@export var dash_damage: int = 25
@export var dash_speed: float = 430.0
@export var dash_duration: float = 0.66
@export var dash_windup: float = 0.35
@export var dash_recovery: float = 0.65
@export var dash_cooldown: float = 3.5

@export var dash_min_range: float = 100.0
@export var dash_max_range: float = 260.0

@export_group("Dash Hitbox")
@export var dash_hitbox_offset: Vector2 = Vector2(38.0, 35.0)
@export var dash_hitbox_size: Vector2 = Vector2(75.0, 55.0)


enum DashPhase {
	NONE,
	WINDUP,
	DASHING,
	RECOVERY
}

var dash_phase: DashPhase = DashPhase.NONE

var dash_timer: float = 0.0
var dash_direction: int = 1
var dash_damage_active: bool = false


@export_group("Spinning Slash")
@export var spin_damage: int = 30
@export var spin_range: float = 75.0
@export var spin_cooldown: float = 2.2

@export var spin_start_frame: int = 2
@export var spin_end_frame: int = 5

@export_group("Spin Hitbox")
@export var spin_hitbox_offset: Vector2 = Vector2(0.0, 25.0)
@export var spin_hitbox_size: Vector2 = Vector2(160.0, 85.0)



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
	ENERGY_BLADE,
	DASH_STRIKE,
	SPINNING_SLASH
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
	
	
	var melee_collision: CollisionShape2D = (
		melee_hitbox.get_node("CollisionShape2D")
	)

	melee_collision.shape = melee_collision.shape.duplicate()


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
			if current_attack == AttackType.DASH_STRIKE:
				handle_dash_strike(delta)
			else:
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
	# 1. Check whether the player still exists.
	if not is_instance_valid(player):
		player = null
		change_state(State.IDLE)
		return

	# 2. Calculate the distance to the player.
	var distance_x: float = (
		player.global_position.x - global_position.x
	)

	var distance: float = absf(distance_x)

	# 3. Always face the player before attacking.
	if distance_x > 0.0:
		update_facing_direction(1)
	elif distance_x < 0.0:
		update_facing_direction(-1)

	# 4. Check whether an attack can be performed.
	if attack_cooldown.is_stopped():
		
		var in_melee_range: bool = (
			distance <= spin_range
		)

		var in_ranged_range: bool = (
			distance >= ranged_min_distance
			and distance <= ranged_max_distance
		)

		var in_dash_range: bool = (
			distance >= dash_min_range
			and distance <= dash_max_range
		)

		# Attempt to select an appropriate attack.
		if in_melee_range or in_ranged_range or in_dash_range:
			choose_attack(distance)

			# If an attack started, stop chasing.
			if current_state == State.ATTACK:
				return

	# 5. Stop when close enough to the player.
	if distance <= stopping_distance:
		velocity.x = 0.0
		play_animation("idle")
		return

	# 6. Update obstacle detection.
	ground_check.force_raycast_update()
	wall_check.force_raycast_update()

	# 7. Stop if there is a wall ahead.
	if wall_check.is_colliding():
		velocity.x = 0.0
		play_animation("idle")
		return

	# 8. Stop before walking off a platform.
	if is_on_floor() and not ground_check.is_colliding():
		velocity.x = 0.0
		play_animation("idle")
		return

	# 9. Move toward the player.
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

	# 1. Close-range combat.
	if distance <= spin_range:

		# Basic Slash -> Heavy Slash -> Spinning Slash
		match last_attack:

			AttackType.BASIC_SLASH:
				if distance <= heavy_range:
					start_heavy_attack()
				else:
					start_spin_attack()

			AttackType.HEAVY_SLASH:
				start_spin_attack()

			AttackType.SPINNING_SLASH:
				if distance <= melee_range:
					start_basic_attack()
				else:
					start_heavy_attack()

			_:
				if distance <= melee_range:
					start_basic_attack()
				elif distance <= heavy_range:
					start_heavy_attack()
				else:
					start_spin_attack()

		return

	# 2. Medium-to-long-range combat.
	if distance >= dash_min_range and distance <= dash_max_range:

		# Prioritize dash beyond projectile range.
		if distance > ranged_max_distance:
			start_dash_strike()
			return

		# Alternate between ranged and dash attacks.
		if last_attack == AttackType.ENERGY_BLADE:
			start_dash_strike()
		else:
			start_ranged_attack()

		return

	# 3. Ranged attack outside dash range.
	if (
		distance >= ranged_min_distance
		and distance <= ranged_max_distance
	):
		start_ranged_attack()
		return




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


func start_dash_strike() -> void:
	if current_state != State.CHASE:
		return

	if not attack_cooldown.is_stopped():
		return

	if not animated_sprite.sprite_frames.has_animation("attack_4"):
		push_warning("Missing animation: attack_4")
		return

	if not is_instance_valid(player):
		return

	# Lock direction toward the player.
	var distance_x: float = (
		player.global_position.x - global_position.x
	)

	dash_direction = 1 if distance_x >= 0.0 else -1

	update_facing_direction(dash_direction)

	change_state(State.ATTACK)

	current_attack = AttackType.DASH_STRIKE
	last_attack = AttackType.DASH_STRIKE

	current_attack_damage = dash_damage

	velocity.x = 0.0

	melee_active = false
	dash_damage_active = false

	hit_targets.clear()

	# Enter the preparation stage.
	dash_phase = DashPhase.WINDUP
	dash_timer = dash_windup

	# Reuse the existing melee hitbox.
	melee_hitbox.position = Vector2(
		dash_hitbox_offset.x * dash_direction,
		dash_hitbox_offset.y
	)

	var collision: CollisionShape2D = (
		melee_hitbox.get_node("CollisionShape2D")
	)

	var rectangle: RectangleShape2D = (
		collision.shape as RectangleShape2D
	)

	if rectangle != null:
		rectangle.size = dash_hitbox_size

	# Cooldown prevents repeated dash strikes.
	attack_cooldown.start(dash_cooldown)

	# We'll start the actual attack animation
	# after the wind-up finishes.
	play_animation("idle")

	print("Shadow Demon preparing Dash Strike!")


func handle_dash_strike(delta: float) -> void:
	dash_timer -= delta

	match dash_phase:

		DashPhase.WINDUP:
			velocity.x = 0.0

			if dash_timer <= 0.0:
				begin_dash()

		DashPhase.DASHING:
			perform_dash_movement()

			if dash_timer <= 0.0:
				begin_dash_recovery()

		DashPhase.RECOVERY:
			velocity.x = 0.0

			if dash_timer <= 0.0:
				finish_dash_strike()


func begin_dash() -> void:
	dash_phase = DashPhase.DASHING
	dash_timer = dash_duration

	velocity.x = dash_direction * dash_speed

	# Allow damage during the actual charge.
	dash_damage_active = true
	melee_active = true

	animated_sprite.play("attack_4")
	animated_sprite.set_frame_and_progress(0, 0.0)

	print("Shadow Demon DASH!")


func perform_dash_movement() -> void:
	# Check obstacles in the locked dash direction.
	ground_check.position.x = (
		ground_check_distance * dash_direction
	)

	wall_check.target_position.x = (
		wall_check_distance * dash_direction
	)

	ground_check.force_raycast_update()
	wall_check.force_raycast_update()

	# Stop if a wall is directly ahead.
	if wall_check.is_colliding():
		begin_dash_recovery()
		return

	# Don't charge off platform edges.
	if is_on_floor() and not ground_check.is_colliding():
		begin_dash_recovery()
		return

	velocity.x = dash_direction * dash_speed


func begin_dash_recovery() -> void:
	if dash_phase != DashPhase.DASHING:
		return

	dash_phase = DashPhase.RECOVERY
	dash_timer = dash_recovery

	velocity.x = 0.0

	melee_active = false
	dash_damage_active = false

	# The charge is complete.
	# Return to idle visually while recovering.
	animated_sprite.play("idle")

	print("Shadow Demon recovering...")


func finish_dash_strike() -> void:
	dash_phase = DashPhase.NONE
	dash_timer = 0.0

	melee_active = false
	dash_damage_active = false

	hit_targets.clear()

	current_attack = AttackType.NONE
	current_attack_damage = 0

	velocity.x = 0.0

	# Restore the basic melee hitbox position.
	melee_hitbox.position = Vector2(
		melee_hitbox_offset * facing_direction,
		basic_hitbox_y
	)

	if is_instance_valid(player):
		change_state(State.CHASE)
	else:
		change_state(State.IDLE)


func start_spin_attack() -> void:
	if current_state != State.CHASE:
		return

	if not attack_cooldown.is_stopped():
		return

	if not animated_sprite.sprite_frames.has_animation("attack_5"):
		push_warning("Missing animation: attack_5")
		return

	# Reuse the existing melee attack system.
	start_attack(
		AttackType.SPINNING_SLASH,
		"attack_5",
		spin_damage,
		spin_range,
		0.0,
		spin_start_frame,
		spin_end_frame,
		spin_cooldown
	)

	# Center the hitbox so it covers both sides.
	melee_hitbox.position = spin_hitbox_offset

	# Give the spinning attack a wider collision area.
	var collision: CollisionShape2D = (
		melee_hitbox.get_node("CollisionShape2D")
	)

	var rectangle: RectangleShape2D = (
		collision.shape as RectangleShape2D
	)

	if rectangle != null:
		rectangle.size = spin_hitbox_size

	print("Shadow Demon: Spinning Slash!")


func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
		return

	match current_attack:

		AttackType.BASIC_SLASH, AttackType.HEAVY_SLASH, AttackType.SPINNING_SLASH:
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
				
		
		AttackType.DASH_STRIKE:
			# Damage is controlled by the dash phase,
			# not by the sprite animation frames.
			melee_active = dash_damage_active




func _on_animation_finished() -> void:
	if current_state == State.DEAD:
		return

	# Dash Strike uses its own movement and recovery timers.
	if current_attack == AttackType.DASH_STRIKE:
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
