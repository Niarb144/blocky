
extends Control

signal closed

@onready var destination_list: ItemList = (
	$PanelContainer/VBoxContainer/DestinationList
)

@onready var travel_button: Button = (
	$PanelContainer/VBoxContainer/TravelButton
)

@onready var back_button: Button = (
	$PanelContainer/VBoxContainer/BackButton
)

var destination_ids: Array[String] = []


func _ready() -> void:
	travel_button.pressed.connect(_on_travel_pressed)
	back_button.pressed.connect(_on_back_pressed)

	destination_list.item_selected.connect(
		_on_destination_selected
	)

	hide()


func open_menu() -> void:
	populate_destinations()
	show()


func populate_destinations() -> void:
	destination_list.clear()
	destination_ids.clear()

	for sanctuary_id in GameState.discovered_sanctuaries:
		destination_ids.append(str(sanctuary_id))
		destination_list.add_item(
			str(sanctuary_id).replace("_", " ").capitalize()
		)

	travel_button.disabled = true


func _on_destination_selected(
	_index: int
) -> void:
	travel_button.disabled = false


func _on_travel_pressed() -> void:
	var selected := destination_list.get_selected_items()

	if selected.is_empty():
		return

	var index: int = selected[0]

	GameState.fast_travel(destination_ids[index])


func _on_back_pressed() -> void:
	hide()
	closed.emit()
