
extends Control

signal menu_closed

@onready var destination_list: VBoxContainer = (
	$PanelContainer/VBoxContainer/DestinationList
)

@onready var instructions_label: Label = (
	$PanelContainer/VBoxContainer/InstructionsLabel
)

var destination_ids: Array[String] = []
var selected_index: int = 0

var current_sanctuary_id: String = ""


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	hide()


# ==================================================
# OPEN MENU
# ==================================================

func open_menu(from_sanctuary: String) -> void:
	current_sanctuary_id = from_sanctuary
	selected_index = 0

	populate_destinations()
	update_selection()

	show()


# ==================================================
# BUILD DESTINATION LIST
# ==================================================

func populate_destinations() -> void:
	# Clear previous destination labels.
	for child in destination_list.get_children():
		destination_list.remove_child(child)
		child.queue_free()

	destination_ids.clear()

	# Add all discovered sanctuaries.
	for sanctuary_id in GameState.discovered_sanctuaries:
		if sanctuary_id == current_sanctuary_id:
			continue

		destination_ids.append(str(sanctuary_id))

	destination_ids.sort()

	# Create a label for every destination.
	for sanctuary_id in destination_ids:
		var option := Label.new()

		option.name = "Destination_" + sanctuary_id

		option.text = (
			sanctuary_id.replace("_", " ").capitalize()
		)

		option.add_theme_font_size_override(
			"font_size",
			18
		)

		option.custom_minimum_size = Vector2(
			280,
			36
		)

		destination_list.add_child(option)

	# Empty destination list.
	if destination_ids.is_empty():
		var empty_label := Label.new()

		empty_label.text = (
			"No other sanctuaries discovered."
		)

		destination_list.add_child(empty_label)


# ==================================================
# INPUT HANDLING
# ==================================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if not event.is_pressed() or event.is_echo():
		return

	# Close the Fast Travel menu.
	if event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
		return

	if destination_ids.is_empty():
		return

	# Navigate upward.
	if event.is_action("ui_up"):
		get_viewport().set_input_as_handled()
		change_selection(-1)

	# Navigate downward.
	elif event.is_action("ui_down"):
		get_viewport().set_input_as_handled()
		change_selection(1)

	# Confirm Fast Travel.
	elif event.is_action("interact"):
		# Handle input BEFORE changing scenes.
		get_viewport().set_input_as_handled()

		confirm_travel()


# ==================================================
# CHANGE SELECTION
# ==================================================

func change_selection(direction: int) -> void:
	selected_index = wrapi(
		selected_index + direction,
		0,
		destination_ids.size()
	)

	update_selection()


# ==================================================
# UPDATE LABEL APPEARANCE
# ==================================================

func update_selection() -> void:
	for i in range(destination_ids.size()):
		var label: Label = destination_list.get_child(i)

		var selected := i == selected_index

		var display_name: String = (
			destination_ids[i]
				.replace("_", " ")
				.capitalize()
		)

		label.text = (
			"> " if selected else "  "
		) + display_name

		label.modulate = (
			Color(0.5, 0.8, 1.0)
			if selected
			else Color.WHITE
		)


# ==================================================
# CONFIRM TRAVEL
# ==================================================

func confirm_travel() -> void:
	if destination_ids.is_empty():
		return

	var target_id: String = (
		destination_ids[selected_index]
	)

	print("FAST TRAVEL: Destination ", target_id)

	# GameState handles the scene transition.
	GameState.fast_travel(target_id)


# ==================================================
# CLOSE MENU
# ==================================================

func close_menu() -> void:
	hide()
	menu_closed.emit()
