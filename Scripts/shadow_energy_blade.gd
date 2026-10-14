
extends Area2D

@export_group("Projectile Settings")
@export var speed: float = 350.0
@export var damage: int = 15

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lifetime: Timer = $LifeTime

var direction: int = 1
var has_hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	lifetime.timeout.connect(_on_lifetime_timeout)

	animated_sprite.flip_h = direction < 0

	if animated_sprite.sprite_frames.has_animation("travel"):
		animated_sprite.play("travel")


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	global_position.x += direction * speed * delta


func setup(
	shoot_direction: int,
	projectile_damage: int
) -> void:
	direction = 1 if shoot_direction >= 0 else -1
	damage = projectile_damage


func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return

	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)

		destroy()
		return

	# A physical obstacle blocks the projectile.
	destroy()


func _on_lifetime_timeout() -> void:
	destroy()


func destroy() -> void:
	if has_hit:
		return

	has_hit = true
	set_deferred("monitoring", false)
	queue_free()
