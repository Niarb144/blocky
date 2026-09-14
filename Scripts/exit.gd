extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var level = get_parent()

		if level.has_key:
			print("EXIT UNLOCKED!")
		else:
			print("EXIT LOCKED - FIND THE KEY!")
