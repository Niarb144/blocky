extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var footstep_player: AudioStreamPlayer2D = $FootstepPlayer
@onready var dash_player: AudioStreamPlayer2D = $DashPlayer

#movement
const SPEED := 250.0
const JUMP_VELOCITY := -400.0
const GRAVITY := 1200.0

# Coyote time
const COYOTE_TIME := 0.12
var coyote_timer: float = 0.0

# Dash
const DASH_SPEED := 800.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 0.5

# Upward wall dash
const WALL_DASH_SPEED := 700.0

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0


# Wall movement
const WALL_SLIDE_SPEED := 100.0
const WALL_JUMP_VELOCITY := -400.0
const WALL_JUMP_HORIZONTAL_SPEED := 350.0
var wall_detected: bool = false
var wall_normal: Vector2 = Vector2.ZERO

var is_wall_grabbing: bool = false

# Player health variables
var max_health: int = 100
var health: int = max_health
var is_dead: bool = false
var is_invincible: bool = false

# Combat
const MAX_AMMO: int = GameState.MAX_AMMO
const MELEE_COOLDOWN := 0.30
const MELEE_DAMAGE := 25
const SHOOT_RELEASE_FRAME := 7

var ammo: int:
	get:
		return GameState.ammo
	set(value):
		GameState.ammo = value

var is_attacking := false
var attack_cooldown := 0.0

var is_melee_attacking: bool = false

var hit_targets: Array[Node] = []

@onready var combat_pivot: Node2D = $CombatPivot
@onready var melee_hitbox: Area2D = $CombatPivot/MeleeHitBox
@onready var shoot_point: Marker2D = $CombatPivot/ShootPoint

# Footstep audio
var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL := 0.25

func _ready() -> void:
	melee_hitbox.monitoring = true
	update_combat_facing()

func _process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# Don't attack while dashing
	if is_dashing:
		return

	if Input.is_action_just_pressed("attack_melee"):
		melee_attack()

	if Input.is_action_just_pressed("attack_ranged"):
		ranged_attack()

func melee_attack() -> void:
	if is_dead or is_attacking:
		return

	if attack_cooldown > 0.0:
		return

	is_attacking = true
	is_melee_attacking = true
	attack_cooldown = MELEE_COOLDOWN

	hit_targets.clear()
	animated_sprite.play("slash")

	await animated_sprite.animation_finished

	is_melee_attacking = false
	is_attacking = false

func check_melee_hits() -> void:
	var bodies := melee_hitbox.get_overlapping_bodies()

	print("Melee bodies detected: ", bodies.size())

	for body in bodies:
		print("Detected: ", body.name)

		if body in hit_targets:
			continue

		if body.has_method("take_damage"):
			print("Damaging: ", body.name)

			body.take_damage(MELEE_DAMAGE)
			hit_targets.append(body)
	
func ranged_attack() -> void:
	if is_attacking:
		return

	if ammo <= 0:
		return

	is_attacking = true

	animated_sprite.play("shoot")

	# Wait until we reach the release frame
	while animated_sprite.animation == "shoot":
		await animated_sprite.frame_changed

		if animated_sprite.frame >= SHOOT_RELEASE_FRAME:
			break

	# Fire the projectile at the correct animation frame
	ammo -= 1
	spawn_projectile()

	# Wait for the rest of the animation
	await animated_sprite.animation_finished

	is_attacking = false
	
func spawn_projectile() -> void:
	var projectile_scene = preload("res://Scenes/projectile.tscn")
	var projectile = projectile_scene.instantiate()

	var projectile_direction := Vector2.RIGHT

	if animated_sprite.flip_h:
		projectile_direction = Vector2.LEFT

	get_tree().current_scene.add_child(projectile)

	projectile.global_position = shoot_point.global_position
	projectile.setup(projectile_direction)
	
func add_ammo(amount: int) -> int:
	var space_available: int = MAX_AMMO - ammo

	if space_available <= 0:
		return 0

	var amount_added: int = mini(amount, space_available)

	ammo += amount_added

	print("Ammo: ", ammo, "/", MAX_AMMO)

	return amount_added
	
func update_combat_facing() -> void:
	if animated_sprite.flip_h:
		combat_pivot.scale.x = -1.0
	else:
		combat_pivot.scale.x = 1.0

func _physics_process(delta: float) -> void:
	if is_melee_attacking and not is_dead:
		check_melee_hits()


	# --------------------------------------------------------
	# DASH TIMERS
	# --------------------------------------------------------

	update_dash_timers(delta)


	# --------------------------------------------------------
	# WALL DETECTION
	# --------------------------------------------------------

	update_wall_grab()


	# --------------------------------------------------------
	# START DASH
	# --------------------------------------------------------

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		start_dash()


	# --------------------------------------------------------
	# DASH MOVEMENT
	# --------------------------------------------------------

	if is_dashing:
		handle_dash()
		move_and_slide()
		return


	# --------------------------------------------------------
	# GRAVITY
	# --------------------------------------------------------

	if not is_on_floor():

		if is_wall_grabbing:
			velocity.y = min(
				velocity.y + GRAVITY * delta,
				WALL_SLIDE_SPEED
			)
		else:
			velocity.y += GRAVITY * delta


	# --------------------------------------------------------
	# COYOTE TIME
	# --------------------------------------------------------

	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta


	# --------------------------------------------------------
	# INPUT
	# --------------------------------------------------------

	var direction := Input.get_axis("move_left", "move_right")


	# --------------------------------------------------------
	# JUMP
	# --------------------------------------------------------

	if Input.is_action_just_pressed("jump"):

		# Normal jump
		if coyote_timer > 0.0:

			velocity.y = JUMP_VELOCITY
			coyote_timer = 0.0

		# Wall jump
		elif is_wall_grabbing:

			velocity.y = WALL_JUMP_VELOCITY

			# Push player away from wall
			velocity.x = wall_normal.x * WALL_JUMP_HORIZONTAL_SPEED

			is_wall_grabbing = false


	# --------------------------------------------------------
	# HORIZONTAL MOVEMENT
	# --------------------------------------------------------

	if is_wall_grabbing:

		# Completely stop horizontal movement while grabbing
		velocity.x = 0.0

	elif direction != 0:

		velocity.x = direction * SPEED
		var facing_left := direction < 0

		animated_sprite.flip_h = facing_left
		update_combat_facing()

	else:

		velocity.x = move_toward(
			velocity.x,
			0,
			SPEED
		)


	# --------------------------------------------------------
	# ANIMATION
	# --------------------------------------------------------
	if not is_attacking:
		update_animation(direction)


	# --------------------------------------------------------
	# FOOTSTEPS
	# --------------------------------------------------------

	update_footsteps(direction, delta)


	# --------------------------------------------------------
	# MOVE
	# --------------------------------------------------------

	move_and_slide()


func update_dash_timers(delta: float) -> void:

	if dash_timer > 0.0:

		dash_timer -= delta

		if dash_timer <= 0.0:

			is_dashing = false
			is_invincible = false


	if dash_cooldown_timer > 0.0:

		dash_cooldown_timer -= delta


func start_dash() -> void:

	if dash_cooldown_timer > 0.0:
		return


	is_dashing = true
	is_invincible = true
	
	dash_player.play()

	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN


	# --------------------------------------------------------
	# WALL DASH
	# --------------------------------------------------------

	if is_wall_grabbing:

		# Dash upward when attached to a wall
		velocity.x = 0.0
		velocity.y = -WALL_DASH_SPEED

		is_wall_grabbing = false

		return


	# --------------------------------------------------------
	# NORMAL DASH
	# --------------------------------------------------------

	var direction := Input.get_axis(
		"move_left",
		"move_right"
	)


	if direction != 0:

		dash_direction = direction

	else:

		dash_direction = -1.0 if animated_sprite.flip_h else 1.0


	velocity.x = dash_direction * DASH_SPEED
	velocity.y = 0.0


func handle_dash() -> void:

	# Wall dash travels vertically
	if velocity.y < 0.0 and velocity.x == 0.0:

		velocity.y = -WALL_DASH_SPEED
		velocity.x = 0.0

	# Normal dash travels horizontally
	else:

		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0.0

func update_wall_grab() -> void:

	is_wall_grabbing = false


	# Cannot grab walls while standing on floor
	if is_on_floor():
		return


	# No wall detected
	if not is_on_wall():
		return


	wall_normal = get_wall_normal()


	var direction := Input.get_axis(
		"move_left",
		"move_right"
	)


	# Player must actively press toward the wall
	if direction * wall_normal.x < 0:

		is_wall_grabbing = true
		
func update_wall_debug() -> void:
	wall_detected = is_on_wall()

	if wall_detected:
		wall_normal = get_wall_normal()
	else:
		wall_normal = Vector2.ZERO

	queue_redraw()

func _draw() -> void:
	if wall_detected:
		draw_line(
			Vector2.ZERO,
			-wall_normal * 50.0,
			Color.RED,
			4.0
		)

func update_animation(direction: float) -> void:
	if is_dead:
		return

	if direction != 0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")


func update_footsteps(direction: float, delta: float) -> void:
	if is_dead:
		footstep_player.stop()
		footstep_timer = 0.0
		return

	# Only play footsteps when moving on the ground
	if is_on_floor() and direction != 0:
		footstep_timer -= delta

		if footstep_timer <= 0.0:
			footstep_player.play()
			footstep_timer = FOOTSTEP_INTERVAL
	else:
		# Reset the timer when airborne or standing still
		footstep_timer = 0.0


func die() -> void:
	if is_dead:
		return

	is_dead = true
	get_tree().call_deferred("reload_current_scene")


func take_damage(amount: int) -> void:
	if is_dead or is_invincible:
		return

	health -= amount

	if health <= 0:
		die()
