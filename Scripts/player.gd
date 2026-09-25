extends CharacterBody2D

const SPEED := 250.0
const JUMP_VELOCITY := -400.0
const GRAVITY := 1200.0

# player health variables
var max_health: int = 100
var health: int = max_health
var is_dead: bool = false


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Horizontal movement
	var direction := Input.get_axis("move_left", "move_right")

	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func die() -> void:
	if is_dead:
		return

	is_dead = true
	get_tree().call_deferred("reload_current_scene")

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount

	if health <= 0:
		die()
