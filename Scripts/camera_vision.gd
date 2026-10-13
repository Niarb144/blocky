
class_name LevelCameraController
extends Camera2D

enum CameraState {
	PREVIEW,
	FOLLOW,
	VISION,
	RETURNING
}

var camera_state: CameraState = CameraState.FOLLOW

@export_group("Normal Follow")
@export var follow_speed: float = 5.0

@export_group("Level Preview")
@export var preview_move_duration: float = 1.5
@export var preview_focus_duration: float = 1.5
@export var preview_return_duration: float = 1.5

@export_group("Spectral Vision")
@export var vision_distance: float = 300.0
@export var vision_speed: float = 260.0
@export var return_speed: float = 500.0
@export var wall_clearance: float = 20.0

@export_group("Wall Detection")
@export_flags_2d_physics var wall_collision_mask: int = 1

@export_group("Visual Effects")
@export var fade_duration: float = 0.25
@export_range(0.0, 1.0) var filter_opacity: float = 0.42

@onready var player: CharacterBody2D = $"../Player"
@onready var overlay: ColorRect = $VisionOverlay/ColorRect

var active_tween: Tween


func _ready() -> void:
	make_current()

	# Run before player movement processing
	process_physics_priority = -10

	position_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false

	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	global_position = player.global_position


func _physics_process(delta: float) -> void:
	match camera_state:

		CameraState.PREVIEW:
			# The preview tween controls camera movement
			pass

		CameraState.FOLLOW:
			follow_player(delta)

			if Input.is_action_pressed("vision_mode"):
				var direction := get_input_direction()

				if direction != Vector2.ZERO:
					start_vision()
					update_vision(delta)

		CameraState.VISION:
			if Input.is_action_pressed("vision_mode"):
				update_vision(delta)
			else:
				end_vision()

		CameraState.RETURNING:
			update_return(delta)


# -----------------------------------
# NORMAL CAMERA FOLLOW
# -----------------------------------

func follow_player(delta: float) -> void:
	global_position = global_position.lerp(
		player.global_position,
		minf(1.0, follow_speed * delta)
	)


# -----------------------------------
# LEVEL INTRODUCTION
# -----------------------------------

func play_level_preview(key_position: Vector2) -> void:
	camera_state = CameraState.PREVIEW
	player.controls_enabled = false

	global_position = player.global_position

	# Travel toward the key
	var move_tween := create_tween()

	move_tween.tween_property(
		self,
		"global_position",
		key_position,
		preview_move_duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	await move_tween.finished

	# Focus briefly on the key
	await get_tree().create_timer(
		preview_focus_duration
	).timeout

	# Return to player
	var return_tween := create_tween()

	return_tween.tween_property(
		self,
		"global_position",
		player.global_position,
		preview_return_duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	await return_tween.finished

	global_position = player.global_position

	camera_state = CameraState.FOLLOW
	player.controls_enabled = true


# -----------------------------------
# START SPECTRAL VISION
# -----------------------------------

func start_vision() -> void:
	camera_state = CameraState.VISION

	player.controls_enabled = false
	player.velocity.x = 0.0

	animate_overlay(filter_opacity)


# -----------------------------------
# UPDATE SPECTRAL VISION
# -----------------------------------

func update_vision(delta: float) -> void:
	var direction := get_input_direction()

	if direction == Vector2.ZERO:
		return

	var target := get_vision_target(direction)

	global_position = global_position.move_toward(
		target,
		vision_speed * delta
	)


# -----------------------------------
# DIRECTIONAL INPUT
# -----------------------------------

func get_input_direction() -> Vector2:
	var direction := Vector2.ZERO

	if Input.is_action_pressed("vision_right"):
		direction.x += 1.0

	if Input.is_action_pressed("vision_left"):
		direction.x -= 1.0

	if Input.is_action_pressed("vision_up"):
		direction.y -= 1.0

	if Input.is_action_pressed("vision_down"):
		direction.y += 1.0

	# Restrict vision to 4 directions
	if absf(direction.x) >= absf(direction.y):
		direction.y = 0.0
	else:
		direction.x = 0.0

	return direction.normalized()


# -----------------------------------
# WALL DETECTION
# -----------------------------------


func get_vision_target(direction: Vector2) -> Vector2:
	var origin: Vector2 = player.global_position

	var destination: Vector2 = (
		origin + direction * vision_distance
	)

	# Get visible screen dimensions in world units
	var viewport_size: Vector2 = (
		get_viewport_rect().size / zoom
	)

	var half_screen: Vector2 = viewport_size / 2.0

	# Distance from camera center to screen edge
	var camera_extent: float = 0.0

	if direction.x != 0.0:
		camera_extent = half_screen.x
	else:
		camera_extent = half_screen.y

	# Detect walls, floors, or ceilings
	var query := PhysicsRayQueryParameters2D.create(
		origin,
		destination,
		wall_collision_mask
	)

	query.exclude = [player.get_rid()]

	var result: Dictionary = (
		get_world_2d().direct_space_state.intersect_ray(query)
	)

	if not result.is_empty():
		var hit_position: Vector2 = result["position"]

		var hit_distance: float = (
			origin.distance_to(hit_position)
		)

		# Stop before the visible camera edge hits geometry
		var allowed_distance: float = maxf(
			0.0,
			hit_distance - camera_extent - wall_clearance
		)

		destination = (
			origin + direction * allowed_distance
		)

	return destination



# -----------------------------------
# END SPECTRAL VISION
# -----------------------------------

func end_vision() -> void:
	camera_state = CameraState.RETURNING

	animate_overlay(0.0)


# -----------------------------------
# RETURN TO PLAYER
# -----------------------------------

func update_return(delta: float) -> void:
	global_position = global_position.move_toward(
		player.global_position,
		return_speed * delta
	)

	if global_position.distance_to(
		player.global_position
	) <= 0.5:

		global_position = player.global_position

		camera_state = CameraState.FOLLOW
		player.controls_enabled = true


# -----------------------------------
# BLUE FILTER ANIMATION
# -----------------------------------

func animate_overlay(target_alpha: float) -> void:
	if active_tween and active_tween.is_running():
		active_tween.kill()

	active_tween = create_tween()

	active_tween.tween_property(
		overlay,
		"modulate:a",
		target_alpha,
		fade_duration
	)


# -----------------------------------
# CAMERA STATE HELPER
# -----------------------------------

func is_busy() -> bool:
	return camera_state != CameraState.FOLLOW
