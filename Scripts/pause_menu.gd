
extends CanvasLayer

@onready var pause_panel: Control = $PausePanel
@onready var resume_button: Button = $PausePanel/CenterContainer/VBoxContainer/ResumeButton
@onready var controls_button: Button = $PausePanel/CenterContainer/VBoxContainer/ControlsButton
@onready var main_menu_button: Button = $PausePanel/CenterContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $PausePanel/CenterContainer/VBoxContainer/QuitButton

var is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.hide()

	resume_button.pressed.connect(resume_game)
	controls_button.pressed.connect(show_controls)
	main_menu_button.pressed.connect(return_to_menu)
	quit_button.pressed.connect(quit_game)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()

		if is_paused:
			resume_game()
		else:
			pause_game()


func pause_game() -> void:
	is_paused = true
	pause_panel.show()
	get_tree().paused = true
	resume_button.grab_focus()


func resume_game() -> void:
	is_paused = false
	pause_panel.hide()
	get_tree().paused = false


func show_controls() -> void:
	# We will connect this to the controls overlay.
	pass


func return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(
		"res://Scenes/Menus/main_menu.tscn"
	)


func quit_game() -> void:
	get_tree().quit()
