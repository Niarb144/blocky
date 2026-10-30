extends Node2D

enum FireDirection {
	RIGHT,
	LEFT,
	UP,
	DOWN
}

enum TrapState {
	IDLE,
	WARNING,
	OPENING,
	CLOSING,
	RELOADING
}

@export_group("Projectile")
@export var arrow_scene: PackedScene
@export var firing_direction: FireDirection = FireDirection.RIGHT
@export var arrow_speed: float = 450.0
@export var arrow_damage: int = 15

@export_group("Animation")
@export var fire_frame: int = 5

@export_group("Timing")
@export var warning_delay: float = 0.6
@export var fire_interval: float = 1.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var spawn_point: Marker2D = $SpawnPoint

@onready var warning_timer: Timer = $WarningTimer
@onready var fire_timer: Timer = $FireTimer

var player_in_range: bool = false
var state: TrapState = TrapState.IDLE
var arrow_fired: bool = false


func _ready() -> void:
	warning_timer.one_shot = true
	fire_timer.one_shot = true

	warning_timer.wait_time = warning_delay
	fire_timer.wait_time = fire_interval

	sprite.play("shoot")
	sprite.stop()
	sprite.frame = 0

	detection_area.body_entered.connect(
		_on_body_entered
	)
	detection_area.body_exited.connect(
		_on_body_exited
	)

	warning_timer.timeout.connect(
		_on_warning_finished
	)
	fire_timer.timeout.connect(
		_on_reload_finished
	)

	sprite.frame_changed.connect(
		_on_frame_changed
	)
	sprite.animation_finished.connect(
		_on_animation_finished
	)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = true

	if state == TrapState.IDLE:
		start_warning()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = false

	warning_timer.stop()
	fire_timer.stop()

	state = TrapState.IDLE
	arrow_fired = false

	sprite.stop()
	sprite.frame = 0


func start_warning() -> void:
	if not player_in_range:
		return

	state = TrapState.WARNING
	warning_timer.start()


func _on_warning_finished() -> void:
	if not player_in_range:
		return

	start_opening()


func start_opening() -> void:
	state = TrapState.OPENING
	arrow_fired = false

	sprite.stop()
	sprite.frame = 0
	sprite.play("shoot")


func _on_frame_changed() -> void:
	if state != TrapState.OPENING:
		return

	if sprite.frame >= fire_frame and not arrow_fired:
		arrow_fired = true
		fire_arrow()


func _on_animation_finished() -> void:
	if state == TrapState.OPENING:
		# Launcher is fully open.
		if not arrow_fired:
			arrow_fired = true
			fire_arrow()

		state = TrapState.CLOSING
		sprite.play_backwards("shoot")

	elif state == TrapState.CLOSING:
		# Launcher is fully closed.
		sprite.stop()
		sprite.frame = 0

		state = TrapState.RELOADING

		if player_in_range:
			fire_timer.start()
		else:
			state = TrapState.IDLE


func _on_reload_finished() -> void:
	state = TrapState.IDLE

	if player_in_range:
		start_warning()


func get_fire_direction() -> Vector2:
	match firing_direction:
		FireDirection.RIGHT:
			return Vector2.RIGHT
		FireDirection.LEFT:
			return Vector2.LEFT
		FireDirection.UP:
			return Vector2.UP
		FireDirection.DOWN:
			return Vector2.DOWN

	return Vector2.RIGHT


func fire_arrow() -> void:
	if not player_in_range:
		return

	if arrow_scene == null:
		push_warning("Arrow scene not assigned!")
		return

	var arrow = arrow_scene.instantiate()

	get_tree().current_scene.add_child(arrow)

	arrow.global_position = spawn_point.global_position

	arrow.setup(
		get_fire_direction(),
		arrow_speed,
		arrow_damage
	)

	print("Arrow launched at: ", arrow.global_position)
