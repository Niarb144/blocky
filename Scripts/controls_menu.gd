
extends Control

signal closed

@onready var controls_list: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ControlsList
@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

# Action names must match Project Settings > Input Map.
const CONTROL_ACTIONS: Dictionary = {
	"Move Left": "move_left",
	"Move Right": "move_right",
	"Jump": "jump",
	"Dash": "dash",
	"Melee Attack": "attack_melee",
	"Ranged Attack": "attack_ranged",
	"Pause": "pause"
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	back_button.pressed.connect(close_menu)
	update_controls()


func update_controls() -> void:
	for child in controls_list.get_children():
		child.queue_free()

	for label_text in CONTROL_ACTIONS:
		var action: String = CONTROL_ACTIONS[label_text]

		var row := HBoxContainer.new()

		var action_label := Label.new()
		action_label.text = label_text
		action_label.custom_minimum_size.x = 160.0

		var key_label := Label.new()
		key_label.text = get_action_keys(action)

		row.add_child(action_label)
		row.add_child(key_label)

		controls_list.add_child(row)


func get_action_keys(action: String) -> String:
	if not InputMap.has_action(action):
		return "Not configured"

	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var keys: Array[String] = []

	for event in events:
		var text: String = event.as_text()

		if not keys.has(text):
			keys.append(text)

	if keys.is_empty():
		return "Unassigned"

	return " / ".join(keys)


func open_menu() -> void:
	update_controls()
	show()
	back_button.grab_focus()


func close_menu() -> void:
	hide()
	closed.emit()
