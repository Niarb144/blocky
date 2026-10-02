extends Area2D

var ammo_amount: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.has_method("add_ammo"):
		return

	var amount_added: int = body.add_ammo(ammo_amount)

	if amount_added <= 0:
		return

	ammo_amount -= amount_added

	AudioManager.play_weapon_drop()
	
	print("Collected ", amount_added, " ammo")

	# Remove the pickup only when all its ammo has been collected
	if ammo_amount <= 0:
		queue_free()
