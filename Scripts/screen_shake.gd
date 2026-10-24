extends Node

var camera: Camera2D

var base_offset: Vector2 = Vector2.ZERO
var strength: float = 0.0
var remaining: float = 0.0
var total_duration: float = 0.15
var shaking: bool = false


func _ready() -> void:
	camera = get_parent() as Camera2D

	if camera == null:
		push_error("ScreenShake must be a child of Camera2D.")
		set_process(false)
		return

	add_to_group("screen_shake")
	set_process(false)


func shake(
	amount: float = 2.0,
	duration: float = 0.15
) -> void:
	if not is_instance_valid(camera):
		return

	if not camera.is_current():
		return

	if not shaking:
		base_offset = camera.offset

	strength = maxf(strength, amount)
	total_duration = maxf(duration, 0.01)
	remaining = total_duration
	shaking = true

	set_process(true)


func _process(delta: float) -> void:
	remaining = maxf(remaining - delta, 0.0)

	if remaining <= 0.0 or not camera.is_current():
		camera.offset = base_offset

		strength = 0.0
		shaking = false
		set_process(false)
		return

	var current_strength: float = (
		strength * remaining / total_duration
	)

	camera.offset = base_offset + Vector2(
		randf_range(-current_strength, current_strength),
		randf_range(-current_strength, current_strength)
	)
