
extends Control

const FIRST_LEVEL: String = "res://Scenes/level.tscn"

@onready var new_game_button: Button = $MenuContainer/VBoxContainer/NewGameButton
@onready var continue_button: Button = $MenuContainer/VBoxContainer/ContinueButton
@onready var controls_button: Button = $MenuContainer/VBoxContainer/ControlsButton
@onready var quit_button: Button = $MenuContainer/VBoxContainer/QuitButton


func _ready() -> void:
	get_tree().paused = false

	new_game_button.pressed.connect(_on_new_game_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	continue_button.disabled = true


func _on_new_game_pressed() -> void:
	GameState.reset_game()
	get_tree().change_scene_to_file(FIRST_LEVEL)


func _on_controls_pressed() -> void:
	get_tree().change_scene_to_file(
		"res://Scenes/Menus/controls_menu.tscn"
	)


func _on_quit_pressed() -> void:
	get_tree().quit()
