extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var level = get_parent()

	if level.has_key:
		print("EXIT UNLOCKED!")
		level.complete_level()
	else:
		print("EXIT LOCKED - FIND THE KEY!")
