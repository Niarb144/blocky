
extends Node2D

enum TrapState {
	IDLE,
	WARNING,
	FIRING,
	COOLDOWN
}

@export_group("Activation")
@export var activation_delay: float = 2.0
@export var fire_duration: float = 1.5
@export var cooldown_duration: float = 2.0

@export_group("Damage")
@export var fire_damage: int = 20
@export var damage_interval: float = 0.5

@onready var pressure_area: Area2D = $PressureArea
@onready var fire_area: Area2D = $FireArea

@onready var flame: AnimatedSprite2D = $FlameSprite
@onready var floor_sprite: Sprite2D = $FloorSprite

@onready var activation_timer: Timer = $ActivationTimer
@onready var fire_timer: Timer = $FireTimer
@onready var damage_timer: Timer = $DamageTimer
@onready var cooldown_timer: Timer = $CooldownTimer

var state: TrapState = TrapState.IDLE
var player_on_plate: bool = false

var warning_tween: Tween

func _ready() -> void:
	flame.visible = false

	activation_timer.one_shot = true
	fire_timer.one_shot = true
	damage_timer.one_shot = false
	cooldown_timer.one_shot = true

	activation_timer.wait_time = activation_delay
	fire_timer.wait_time = fire_duration
	damage_timer.wait_time = damage_interval
	cooldown_timer.wait_time = cooldown_duration

	pressure_area.body_entered.connect(
		_on_pressure_entered
	)
	pressure_area.body_exited.connect(
		_on_pressure_exited
	)

	activation_timer.timeout.connect(activate_fire)
	fire_timer.timeout.connect(deactivate_fire)
	damage_timer.timeout.connect(damage_player)
	cooldown_timer.timeout.connect(reset_trap)


# PLAYER ENTERS PRESSURE PLATE
func _on_pressure_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_on_plate = true

	if state == TrapState.IDLE:
		start_warning()


# PLAYER LEAVES PRESSURE PLATE
func _on_pressure_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_on_plate = false

	if state == TrapState.WARNING:
		cancel_warning()


# WARNING PHASE

func start_warning() -> void:
	state = TrapState.WARNING

	activation_timer.start()

	if warning_tween:
		warning_tween.kill()

	warning_tween = create_tween()
	warning_tween.set_loops()

	warning_tween.tween_property(
		floor_sprite,
		"modulate",
		Color.ORANGE_RED,
		0.25
	)

	warning_tween.tween_property(
		floor_sprite,
		"modulate",
		Color.WHITE,
		0.25
	)

func stop_warning_effect() -> void:
	if warning_tween:
		warning_tween.kill()
		warning_tween = null

	floor_sprite.modulate = Color.WHITE

func cancel_warning() -> void:
	activation_timer.stop()

	floor_sprite.modulate = Color.WHITE

	state = TrapState.IDLE


# FIRE ACTIVATION
func activate_fire() -> void:
	if state != TrapState.WARNING:
		return

	if not player_on_plate:
		cancel_warning()
		return

	state = TrapState.FIRING

	floor_sprite.modulate = Color.RED

	flame.visible = true
	flame.play("fire")

	damage_player()

	damage_timer.start()
	fire_timer.start()


# DAMAGE
func damage_player() -> void:
	if state != TrapState.FIRING:
		return

	for body in fire_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_damage(fire_damage)


# FIRE DEACTIVATION
func deactivate_fire() -> void:
	if state != TrapState.FIRING:
		return

	state = TrapState.COOLDOWN

	damage_timer.stop()

	flame.stop()
	flame.visible = false

	floor_sprite.modulate = Color.WHITE

	cooldown_timer.start()


# RESET TRAP
func reset_trap() -> void:
	state = TrapState.IDLE

	if player_on_plate:
		start_warning()
