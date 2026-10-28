extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, HURT, DEAD }

#Health Drop
const HEALTH_PICKUP = preload("res://Scenes/health_pickup.tscn")

@export_range(0.0, 1.0, 0.05) var health_drop_chance: float = 0.15
@export var health_drop_offset: Vector2 = Vector2(0, -10)

@export var max_health: int = 100
@export var attack_damage: int = 25

@export var patrol_speed: float = 50.0
@export var chase_speed: float = 150.0
@export var patrol_distance: float = 200.0
@export var detection_range: float = 280.0

@export var attack_range: float = 40.0
@export var attack_height: float = 30.0
@export var attack_cooldown: float = 0.2
@export var attack_hit_frame: int = 6

@export var hurt_duration: float = 0.1
@export var gravity: float = 1200.0
@export var ground_check_offset: float = 12.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var combat_pivot: Node2D = $CombatPivot
@onready var attack_hitbox: Area2D = $CombatPivot/AttackHitbox
@onready var ground_check: RayCast2D = $GroundCheck
@onready var sight_check: RayCast2D = $SightCheck
@export_group("Persistence")
@export var enemy_id: String = ""

var state: State = State.PATROL
var health: int = 0
var spawn_x: float = 0.0
var facing: float = 1.0

var cooldown_remaining: float = 0.0
var hurt_remaining: float = 0.0
var attack_hit_checked: bool = false

@export_group("Essence Reward")
@export var essence_reward: int = 10

var essence_awarded: bool = false

const BLOOD_HIT_PARTICLES = preload(
	"res://Scenes/VisualEffects/blood_hit_particles.tscn"
)

@export_group("Hit Feedback")
@export var blood_hit_offset: Vector2 = Vector2(0, -8)
@export var hit_shake_strength: float = 2.0
@export var hit_shake_duration: float = 0.12

var player: Node2D = null


func _ready() -> void:
	if restore_enemy_state():
		return

	health = max_health
	spawn_x = global_position.x

	player = get_tree().get_first_node_in_group("player") as Node2D

	sprite.animation_finished.connect(_on_animation_finished)

	set_facing(1.0)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)

	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.HURT:
			velocity.x = 0.0
			hurt_remaining -= delta

			if hurt_remaining <= 0.0:
				state = State.PATROL

		State.ATTACK:
			velocity.x = 0.0

			# Check once when the swing reaches its impact frame.
			if not attack_hit_checked and sprite.frame >= attack_hit_frame:
				attack_hit_checked = true
				check_attack_hit()

		State.PATROL, State.CHASE:
			if can_detect_player():
				state = State.CHASE
				chase_player()
			else:
				state = State.PATROL
				patrol()

	move_and_slide()

func restore_enemy_state() -> bool:
	if enemy_id.is_empty():
		push_warning(
			"Enemy persistence ID missing: " + name
		)
		return false

	var level := get_tree().current_scene

	if level == null:
		return false

	if GameState.is_enemy_defeated(
		level.scene_file_path,
		enemy_id
	):
		print("ENEMY: Already defeated: ", enemy_id)

		# Stop interaction immediately.
		process_mode = Node.PROCESS_MODE_DISABLED

		# Remove this enemy instance.
		queue_free()
		return true

	return false

func record_enemy_defeat() -> void:
	if enemy_id.is_empty():
		return

	var level := get_tree().current_scene

	if level == null:
		return

	GameState.register_enemy_defeat(
		level.scene_file_path,
		enemy_id
	)

func can_detect_player() -> bool:
	if not is_instance_valid(player):
		return false

	if bool(player.get("is_dead")):
		return false

	if global_position.distance_to(player.global_position) > detection_range:
		return false

	return has_clear_sight()


func has_clear_sight() -> bool:
	if not is_instance_valid(player):
		return false

	sight_check.target_position = sight_check.to_local(player.global_position)
	sight_check.force_raycast_update()

	return not sight_check.is_colliding()


func patrol() -> void:
	var left_limit: float = spawn_x - patrol_distance
	var right_limit: float = spawn_x + patrol_distance

	# Return toward the patrol area after a chase.
	if global_position.x < left_limit:
		set_facing(1.0)
	elif global_position.x > right_limit:
		set_facing(-1.0)
	elif global_position.x >= right_limit - 2.0 and facing > 0.0:
		set_facing(-1.0)
	elif global_position.x <= left_limit + 2.0 and facing < 0.0:
		set_facing(1.0)

	if is_on_floor() and not can_walk_forward():
		set_facing(-facing)

	velocity.x = facing * patrol_speed
	sprite.play("walk")


func chase_player() -> void:
	var offset: Vector2 = player.global_position - global_position

	if absf(offset.x) > 2.0:
		set_facing(1.0 if offset.x > 0.0 else -1.0)

	if absf(offset.x) <= attack_range and absf(offset.y) <= attack_height:
		velocity.x = 0.0

		if cooldown_remaining <= 0.0:
			start_attack()
		else:
			sprite.play("idle")

		return

	# Wait rather than walking off a ledge or pushing against a wall.
	if is_on_floor() and not can_walk_forward():
		velocity.x = 0.0
		sprite.play("idle")
		return

	velocity.x = facing * chase_speed
	sprite.play("walk")


func can_walk_forward() -> bool:
	ground_check.position.x = ground_check_offset * facing
	ground_check.force_raycast_update()

	return ground_check.is_colliding() and not is_on_wall()


func set_facing(direction: float) -> void:
	facing = direction
	sprite.flip_h = facing < 0.0
	combat_pivot.scale.x = facing


func start_attack() -> void:
	state = State.ATTACK
	velocity.x = 0.0
	attack_hit_checked = false

	sprite.stop()
	sprite.play("attack")


func check_attack_hit() -> void:
	if not is_instance_valid(player):
		return

	if not has_clear_sight():
		return

	for body in attack_hitbox.get_overlapping_bodies():
		if body == player and body.has_method("take_damage"):
			body.take_damage(attack_damage)
			break


func take_damage(amount: int) -> void:
	if state == State.DEAD or amount <= 0:
		return

	health = maxi(health - amount, 0)

	# Runs for normal hits and killing blows.
	play_hit_feedback()
	
	if health == 0:
		die()
		return

	# Taking damage interrupts an unfinished attack.
	state = State.HURT
	velocity.x = 0.0
	hurt_remaining = hurt_duration
	cooldown_remaining = attack_cooldown

	sprite.stop()
	sprite.play("hurt")

func play_hit_feedback() -> void:
	spawn_blood_particles.call_deferred(
		global_position + blood_hit_offset
	)

	get_tree().call_group(
		"screen_shake",
		"shake",
		hit_shake_strength,
		hit_shake_duration
	)
	
func spawn_blood_particles(hit_position: Vector2) -> void:
	var scene: Node2D = get_tree().current_scene as Node2D

	if not is_instance_valid(scene):
		return

	var particles: CPUParticles2D = (
		BLOOD_HIT_PARTICLES.instantiate() as CPUParticles2D
	)

	particles.position = scene.to_local(hit_position)
	scene.add_child(particles)

func try_drop_health() -> void:
	if randf() > health_drop_chance:
		return

	var health_amount: int = roll_health_amount()

	spawn_health_pickup(health_amount)


func roll_health_amount() -> int:
	var roll: float = randf()

	if roll < 0.80:
		return 50
	elif roll < 0.95:
		return 75
	else:
		return 100


func spawn_health_pickup(amount: int) -> void:
	var pickup = HEALTH_PICKUP.instantiate()

	pickup.health_amount = amount

	get_tree().current_scene.add_child(pickup)

	pickup.global_position = global_position + health_drop_offset

	print("Demon dropped ", amount, " health.")

func die() -> void:
	if state == State.DEAD:
		return

	state = State.DEAD
		
	# Record death before unloading the level.
	record_enemy_defeat()
		
	velocity = Vector2.ZERO

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	attack_hitbox.set_deferred("monitoring", false)

	# Award Essence exactly once.
	award_essence()

	# Preserve the existing health drop.
	try_drop_health()

	sprite.stop()
	sprite.play("death")

func award_essence() -> void:
	if essence_awarded:
		return

	essence_awarded = true

	GameState.add_essence(essence_reward)

	print(
		"Demon defeated. +",
		essence_reward,
		" Essence"
	)

func _on_animation_finished() -> void:
	if state == State.DEAD and sprite.animation == &"death":
		queue_free()

	elif state == State.ATTACK and sprite.animation == &"attack":
		cooldown_remaining = attack_cooldown
		state = State.PATROL
