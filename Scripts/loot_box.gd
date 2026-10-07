extends StaticBody2D

const AMMO_PICKUP = preload("res://Scenes/ammo_pickup.tscn")
const HEALTH_PICKUP = preload("res://Scenes/health_pickup.tscn")

@export_range(0.0, 1.0, 0.05) var health_drop_chance: float = 0.25

@export_range(1, 6) var min_ammo: int = 1
@export_range(1, 6) var max_ammo: int = 6

@export var max_health: int = 25
@export var drop_spread: float = 10.0

@onready var drop_point: Marker2D = $DropPoint

var health: int

var is_broken := false


func _ready() -> void:
	health = max_health


func take_damage(amount: int) -> void:
	health -= amount

	print("Loot box health: ", health)

	if health <= 0:
		break_box()


func break_box() -> void:
	if is_broken:
		return

	is_broken = true

	AudioManager.play_loot_box_break()

	var ammo_amount: int = randi_range(min_ammo, max_ammo)

	print("=== LOOT BOX BROKEN ===")
	print("Ammo rolled: ", ammo_amount)

	spawn_ammo(ammo_amount)
	try_drop_health()

	queue_free()

func try_drop_health() -> void:
	if randf() > health_drop_chance:
		return

	var health_amount: int = roll_health_amount()

	spawn_health(health_amount)


func roll_health_amount() -> int:
	var roll: float = randf()

	if roll < 0.50:
		return 25
	elif roll < 0.80:
		return 50
	elif roll < 0.95:
		return 75
	else:
		return 100


func spawn_health(amount: int) -> void:
	var pickup = HEALTH_PICKUP.instantiate()

	pickup.health_amount = amount

	get_tree().current_scene.add_child(pickup)

	var random_offset := Vector2(
		randf_range(-drop_spread, drop_spread),
		randf_range(-5.0, 5.0)
	)

	pickup.global_position = drop_point.global_position + random_offset

	print("Spawned ", amount, " health at ", pickup.global_position)	


func spawn_ammo(amount: int) -> void:
	var pickup = AMMO_PICKUP.instantiate()

	pickup.ammo_amount = amount

	get_tree().current_scene.add_child(pickup)

	var random_offset := Vector2(
		randf_range(-drop_spread, drop_spread),
		randf_range(-5.0, 5.0)
	)

	pickup.global_position = drop_point.global_position + random_offset

	print("Spawned ", amount, " ammo at ", pickup.global_position)
