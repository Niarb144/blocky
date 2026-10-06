extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

var transitioning: bool = false


func _ready() -> void:
	color_rect.modulate.a = 0.0


func transition_to(scene_path: String) -> void:
	if transitioning:
		return

	transitioning = true

	# Fade to black
	var fade_out := create_tween()
	fade_out.tween_property(
		color_rect,
		"modulate:a",
		1.0,
		0.6
	)

	await fade_out.finished

	# Change level
	get_tree().change_scene_to_file(scene_path)

	# Small pause while screen is black
	await get_tree().create_timer(0.2).timeout

	# Fade back into gameplay
	var fade_in := create_tween()
	fade_in.tween_property(
		color_rect,
		"modulate:a",
		0.0,
		0.6
	)

	await fade_in.finished

	transitioning = false
