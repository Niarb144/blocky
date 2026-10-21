
extends Control

const FIRST_LEVEL: String = "res://Scenes/level.tscn"

@onready var new_game_button: Button = $MenuContainer/VBoxContainer/NewGameButton
@onready var continue_button: Button = $MenuContainer/VBoxContainer/ContinueButton
@onready var controls_button: Button = $MenuContainer/VBoxContainer/ControlsButton
@onready var quit_button: Button = $MenuContainer/VBoxContainer/QuitButton

@onready var menu_container: MarginContainer = $MenuContainer
@onready var controls_menu: Control = $ControlsMenu


func _ready() -> void:
	get_tree().paused = false

	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	controls_menu.hide()
	controls_menu.closed.connect(_on_controls_closed)

	continue_button.disabled = not SaveManager.has_save()



func _on_new_game_pressed() -> void:
	GameState.reset_for_new_game()

	get_tree().paused = false

	get_tree().change_scene_to_file(
		GameState.current_level
	)



func _on_continue_pressed() -> void:
	print("MENU: Continue pressed!")

	if not SaveManager.load_game():
		print("MENU: No valid save found.")
		return

	print("MENU: Loading level: ", GameState.current_level)
	print("MENU: Sanctuary: ", GameState.last_sanctuary_id)
	print("MENU: Health: ", GameState.health)
	print("MENU: Ammo: ", GameState.ammo)

	get_tree().paused = false

	var error := get_tree().change_scene_to_file(
		GameState.current_level
	)

	if error != OK:
		push_error("MENU: Failed to load saved level!")



func _on_controls_pressed() -> void:
	menu_container.hide()
	controls_menu.open_menu()


func _on_controls_closed() -> void:
	menu_container.show()
	controls_button.grab_focus()



func _on_quit_pressed() -> void:
	get_tree().quit()
