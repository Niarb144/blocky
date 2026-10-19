
extends Control

@export_file("*.tscn") var main_menu_scene: String = (
	"res://Scenes/main_menu.tscn"
)

@onready var fade_overlay: ColorRect = $FadeOverlay

@onready var victory_title: Label = (
	$CenterContainer/VBoxContainer/VictoryTitle
)

@onready var victory_message: Label = (
	$CenterContainer/VBoxContainer/VictoryMessage
)

@onready var description: Label = (
	$CenterContainer/VBoxContainer/Description
)

@onready var main_menu_button: Button = (
	$CenterContainer/VBoxContainer/MainMenuButton
)


func _ready() -> void:
	fade_overlay.modulate.a = 1.0

	victory_title.modulate.a = 0.0
	victory_message.modulate.a = 0.0
	description.modulate.a = 0.0
	main_menu_button.modulate.a = 0.0
	main_menu_button.disabled = true

	main_menu_button.pressed.connect(_on_main_menu_pressed)

	play_victory_animation()


func play_victory_animation() -> void:
	var tween: Tween = create_tween()

	# Fade from black.
	tween.tween_property(
		fade_overlay,
		"modulate:a",
		0.0,
		1.0
	)

	# Reveal victory text sequentially.
	tween.tween_property(
		victory_title,
		"modulate:a",
		1.0,
		0.8
	)

	tween.tween_property(
		victory_message,
		"modulate:a",
		1.0,
		0.8
	)

	tween.tween_property(
		description,
		"modulate:a",
		1.0,
		0.6
	)

	tween.tween_property(
		main_menu_button,
		"modulate:a",
		1.0,
		0.5
	)

	tween.tween_callback(
		func() -> void:
			main_menu_button.disabled = false
	)


func _on_main_menu_pressed() -> void:
	if ResourceLoader.exists(main_menu_scene):
		get_tree().change_scene_to_file(main_menu_scene)
	else:
		push_warning("Main menu scene not found: " + main_menu_scene)
