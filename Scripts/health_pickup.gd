extends Area2D

@export var health_amount: int = 25

@export var health_25_texture: Texture2D
@export var health_50_texture: Texture2D
@export var health_75_texture: Texture2D
@export var health_100_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

var collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	update_sprite()


func update_sprite() -> void:
	match health_amount:
		25:
			sprite.texture = health_25_texture

		50:
			sprite.texture = health_50_texture

		75:
			sprite.texture = health_75_texture

		100:
			sprite.texture = health_100_texture

		_:
			push_warning(
				"Invalid health pickup amount: %d" % health_amount
			)


func _on_body_entered(body: Node) -> void:
	if collected:
		return

	if not body.is_in_group("player"):
		return

	if not body.has_method("heal"):
		return

	var amount_healed: int = body.heal(health_amount)

	# Player was already at full health.
	if amount_healed <= 0:
		return

	collected = true

	print(
		"Collected +",
		amount_healed,
		" health from a +",
		health_amount,
		" pickup."
	)

	queue_free()
