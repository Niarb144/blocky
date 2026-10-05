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

# Player health
var max_health: int:
	get:
		return GameState.MAX_HEALTH

var health: int:
	get:
		return GameState.health
	set(value):
		GameState.health = value
var is_dead: bool = false
var is_hurt: bool = false
var projectile_released: bool = false

# Existing dash protection
var is_invincible: bool = false

# Protection after taking damage
@export var hurt_invulnerability_duration: float = 0.8
var hurt_invulnerability_timer: float = 0.0

@onready var health_label: Label = $HUD/HealthDisplay/HealthLabel
@onready var health_bar: ProgressBar = $HUD/HealthDisplay/HealthBar

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
	add_to_group("player")
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_animation_frame_changed)

	# These animations must emit animation_finished.
	for animation_name in ["slash", "shoot", "hurt", "death"]:
		animated_sprite.sprite_frames.set_animation_loop(animation_name, false)

	update_health_ui()

	melee_hitbox.monitoring = true
	update_combat_facing()
	
func update_health_ui() -> void:
	health_label.text = "Health: %d/%d" % [health, max_health]

	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = health

func _process(delta: float) -> void:
	if is_dead:
		return
		
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# Don't attack while dashing
	if is_dashing or is_hurt:
		return

	if Input.is_action_just_pressed("attack_melee"):
		melee_attack()

	if Input.is_action_just_pressed("attack_ranged"):
		ranged_attack()

func melee_attack() -> void:
	if is_dead or is_hurt or is_dashing or is_attacking:
		return

	if attack_cooldown > 0.0:
		return

	is_attacking = true
	is_melee_attacking = true
	attack_cooldown = MELEE_COOLDOWN

	hit_targets.clear()
	animated_sprite.play("slash")


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
	if is_dead or is_hurt or is_dashing or is_attacking or ammo <= 0:
		return

	is_attacking = true
	projectile_released = false
	animated_sprite.play("shoot")


func cancel_attack() -> void:
	is_attacking = false
	is_melee_attacking = false
	projectile_released = false
	hit_targets.clear()


func _on_animation_frame_changed() -> void:
	if is_dead or is_hurt or is_dashing:
		return

	if is_attacking and animated_sprite.animation == "shoot":
		if not projectile_released and animated_sprite.frame >= SHOOT_RELEASE_FRAME:
			projectile_released = true
			ammo -= 1
			spawn_projectile()


func _on_animation_finished() -> void:
	match animated_sprite.animation:
		"death":
			if is_dead:
				get_tree().call_deferred("reload_current_scene")
		"hurt":
			is_hurt = false
			update_animation(Input.get_axis("move_left", "move_right"))
		"slash", "shoot":
			cancel_attack()
			update_animation(Input.get_axis("move_left", "move_right"))


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
	if is_dead:
		return

	hurt_invulnerability_timer = maxf(
		hurt_invulnerability_timer - delta,
		0.0
	)

	if is_melee_attacking and not is_dead:
		check_melee_hits()


	# --------------------------------------------------------
	# DASH TIMERS
	# --------------------------------------------------------

	update_dash_timers(delta)


	# Briefly suspend input while hurt; gravity still applies.
	if is_hurt:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return


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
		update_animation(0.0)
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

	if is_dead or is_hurt or dash_cooldown_timer > 0.0:
		return

	cancel_attack()
	footstep_player.stop()
	# Calculate the animation's normal duration.
	var frames: SpriteFrames = animated_sprite.sprite_frames
	var frame_count: int = frames.get_frame_count("dash")
	var animation_fps: float = frames.get_animation_speed("dash")
	var animation_duration: float = 0.0

	for frame_index in range(frame_count):
		animation_duration += frames.get_frame_duration("dash", frame_index) / animation_fps

	# Fit the complete animation into the dash duration.
	animated_sprite.play("dash", animation_duration / DASH_DURATION)
	animated_sprite.set_frame_and_progress(0, 0.0)

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


	animated_sprite.flip_h = dash_direction < 0.0
	update_combat_facing()
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
	# Priority: death > hurt > dash > attack > jump > run / idle.
	if is_dead or is_hurt:
		return

	if is_dashing:
		return

	if is_attacking:
		return

	# Negative vertical velocity also covers the jump's first frame,
	# before move_and_slide updates the floor state.
	if not is_on_floor() or velocity.y < 0.0:
		animated_sprite.play("jump")
	elif direction != 0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")


func update_footsteps(direction: float, delta: float) -> void:
	if is_dead or is_hurt or is_dashing:
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


func take_damage(amount: int, bypass_protection: bool = false) -> void:
	if is_dead or amount <= 0:
		return

	if not bypass_protection:
		if is_invincible or hurt_invulnerability_timer > 0.0:
			return

	health = clampi(health - amount, 0, max_health)
	update_health_ui()

	if health <= 0:
		die()
		return

	hurt_invulnerability_timer = hurt_invulnerability_duration
	cancel_attack()
	is_dashing = false
	is_invincible = false
	dash_timer = 0.0
	is_hurt = true
	velocity.x = 0.0
	footstep_player.stop()
	dash_player.stop()
	animated_sprite.play("hurt")


func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_hurt = false
	is_dashing = false
	is_invincible = false
	cancel_attack()
	velocity = Vector2.ZERO
	footstep_player.stop()
	dash_player.stop()

	animated_sprite.play("death")
	await animated_sprite.animation_finished

	# Restore health for the respawn.
	GameState.health = GameState.MAX_HEALTH
