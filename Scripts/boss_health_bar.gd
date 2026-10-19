
extends Control

@onready var health_bar: ProgressBar = (
	$MarginContainer/VBoxContainer/HealthBar
)

@onready var health_label: Label = (
	$MarginContainer/VBoxContainer/HealthLabel
)

@onready var phase_label: Label = (
	$MarginContainer/VBoxContainer/PhaseLabel
)

@onready var boss_name: Label = (
	$MarginContainer/VBoxContainer/BossName
)

var health_tween: Tween


func setup_boss(boss: Node) -> void:
	if not is_instance_valid(boss):
		return

	boss.health_changed.connect(update_health)
	boss.phase_changed.connect(update_phase)

	# Initialize using actual boss values.
	health_bar.max_value = boss.max_health
	health_bar.value = boss.health

	update_health(boss.health, boss.max_health)
	update_phase(boss.current_phase)


func update_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum

	health_label.text = (
		str(current) + " / " + str(maximum) + " HP"
	)

	# Smoothly animate the health bar.
	if health_tween and health_tween.is_running():
		health_tween.kill()

	health_tween = create_tween()

	health_tween.tween_property(
		health_bar,
		"value",
		float(current),
		0.25
	).set_trans(Tween.TRANS_SINE)


func update_phase(new_phase: int) -> void:
	match new_phase:
		0:
			phase_label.text = "PHASE I - THE GUARDIAN"

		1:
			phase_label.text = "PHASE II - SHADOW UNLEASHED"

		2:
			phase_label.text = "PHASE III - HELL'S FURY"
