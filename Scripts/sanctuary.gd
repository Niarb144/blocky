
extends Node2D

# ==================================================
# SANCTUARY SETTINGS
# ==================================================

@export var sanctuary_id: String = "sanctuary_01"

# ==================================================
# PLAYER INTERACTION
# ==================================================

var player_nearby: bool = false
var player: CharacterBody2D = null

var sanctuary_menu_open: bool = false
var upgrade_menu_open: bool = false
var fast_travel_menu_open: bool = false

# 0 = Rest & Save
# 1 = Upgrade
# 2 = Fast Travel

var selected_option: int = 0

const OPTION_COUNT: int = 3

# ==================================================
# SCENE REFERENCES
# ==================================================

@onready var interaction_label: Label = $InteractionLabel

@onready var interaction_menu: Control = $SanctuaryUI/InteractionMenu

@onready var rest_option: Label = (
	$SanctuaryUI/InteractionMenu/PanelContainer/VBoxContainer/RestOption
)

@onready var upgrade_option: Label = (
	$SanctuaryUI/InteractionMenu/PanelContainer/VBoxContainer/UpgradeOption
)

@onready var fast_travel_option: Label = (
	$SanctuaryUI/InteractionMenu/PanelContainer/VBoxContainer/FastTravelOption
)

@onready var upgrade_menu = $SanctuaryUpgradeMenu

@onready var fast_travel_menu = $FastTravelMenu

# Optional visual indicator.
@onready var activation_indicator: CanvasItem = (
	get_node_or_null("ActivationIndicator") as CanvasItem
)


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	# Allow sanctuary menus to work while gameplay is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	interaction_label.hide()
	interaction_menu.hide()

	# Connect submenu closing signals.
	upgrade_menu.menu_closed.connect(
		_on_upgrade_menu_closed
	)

	fast_travel_menu.menu_closed.connect(
		_on_fast_travel_menu_closed
	)

	# Restore activation appearance.
	update_activation_indicator()

	# Configure the main menu.
	update_options()


# ==================================================
# INPUT HANDLING
# ==================================================

func _unhandled_input(event: InputEvent) -> void:

	if not player_nearby:
		return

	# Ignore main menu input while a submenu is open.
	if upgrade_menu_open or fast_travel_menu_open:
		return

	if not event.is_pressed() or event.is_echo():
		return

	# Sanctuary menu is currently open.
	if sanctuary_menu_open:

		if event.is_action("ui_up"):
			change_selection(-1)
			get_viewport().set_input_as_handled()

		elif event.is_action("ui_down"):
			change_selection(1)
			get_viewport().set_input_as_handled()

		elif event.is_action("interact"):
			confirm_selection()
			get_viewport().set_input_as_handled()

		elif event.is_action("ui_cancel"):
			close_sanctuary_menu()
			get_viewport().set_input_as_handled()

		return

	# Open sanctuary when player presses E.
	if event.is_action("interact"):
		get_viewport().set_input_as_handled()
		open_sanctuary()


# ==================================================
# OPEN SANCTUARY
# ==================================================

func open_sanctuary() -> void:

	if sanctuary_menu_open:
		return

	# Activate sanctuary if this is the first visit.
	if not GameState.has_discovered_sanctuary(
		sanctuary_id
	):
		activate_sanctuary()

	selected_option = 0

	sanctuary_menu_open = true

	# Stop player movement.
	if is_instance_valid(player):
		player.velocity = Vector2.ZERO

	# Hide interaction prompt.
	interaction_label.hide()

	# Display sanctuary menu.
	update_options()
	interaction_menu.show()

	# Pause the entire game.
	get_tree().paused = true

	print("SANCTUARY: Menu opened - ", sanctuary_id)


# ==================================================
# CLOSE SANCTUARY
# ==================================================

func close_sanctuary_menu() -> void:

	if not sanctuary_menu_open:
		return

	sanctuary_menu_open = false

	interaction_menu.hide()

	# Resume gameplay.
	get_tree().paused = false

	# Restore interaction prompt.
	if player_nearby:
		interaction_label.show()

		if GameState.has_discovered_sanctuary(
			sanctuary_id
		):
			interaction_label.text = "Press E to Interact"

	print("SANCTUARY: Menu closed.")


# ==================================================
# MENU NAVIGATION
# ==================================================

func change_selection(direction: int) -> void:

	selected_option = wrapi(
		selected_option + direction,
		0,
		OPTION_COUNT
	)

	update_options()


func update_options() -> void:

	var options: Array[Label] = [
		rest_option,
		upgrade_option,
		fast_travel_option
	]

	var names: Array[String] = [
		"REST & SAVE",
		"UPGRADE",
		"FAST TRAVEL"
	]

	for i in range(options.size()):

		var selected: bool = (
			i == selected_option
		)

		options[i].text = (
			"> " if selected else "  "
		) + names[i]

		options[i].modulate = (
			Color(0.5, 0.8, 1.0)
			if selected
			else Color.WHITE
		)


# ==================================================
# CONFIRM SELECTION
# ==================================================

func confirm_selection() -> void:

	match selected_option:

		0:
			rest_and_save()

		1:
			open_upgrade_menu()

		2:
			open_fast_travel_menu()


# ==================================================
# SANCTUARY ACTIVATION
# ==================================================

func register_sanctuary() -> bool:

	var level := get_tree().current_scene

	if level == null:
		push_warning(
			"SANCTUARY: Current level not found."
		)
		return false

	GameState.current_level = level.scene_file_path

	GameState.last_sanctuary_id = sanctuary_id

	GameState.discover_sanctuary(
		sanctuary_id,
		level.scene_file_path
	)

	update_activation_indicator()

	return true


func activate_sanctuary() -> void:

	if not register_sanctuary():
		return

	if SaveManager.save_game():
		print(
			"SANCTUARY: Activated - ",
			sanctuary_id
		)
	else:
		push_warning(
			"SANCTUARY: Activation save failed."
		)


# ==================================================
# REST AND SAVE
# ==================================================

func rest_and_save() -> void:

	if not register_sanctuary():
		return

	# Restore health and ammunition.
	GameState.rest_at_sanctuary()

	# Save updated resources and checkpoint.
	if SaveManager.save_game():

		print(
			"SANCTUARY: Rest and save successful."
		)

	else:

		push_warning(
			"SANCTUARY: Rest save failed."
		)

	# Keep the sanctuary menu open.
	update_options()


# ==================================================
# UPGRADE MENU
# ==================================================

func open_upgrade_menu() -> void:

	if upgrade_menu_open:
		return

	upgrade_menu_open = true
	sanctuary_menu_open = false

	interaction_menu.hide()

	upgrade_menu.open_menu()


func _on_upgrade_menu_closed() -> void:

	upgrade_menu_open = false
	sanctuary_menu_open = true

	if player_nearby:
		update_options()
		interaction_menu.show()


# ==================================================
# FAST TRAVEL MENU
# ==================================================

func open_fast_travel_menu() -> void:

	if fast_travel_menu_open:
		return

	fast_travel_menu_open = true
	sanctuary_menu_open = false

	interaction_menu.hide()

	fast_travel_menu.open_menu(sanctuary_id)


func _on_fast_travel_menu_closed() -> void:

	fast_travel_menu_open = false
	sanctuary_menu_open = true

	if player_nearby:
		update_options()
		interaction_menu.show()


# ==================================================
# ACTIVATION VISUAL INDICATOR
# ==================================================

func update_activation_indicator() -> void:

	if not is_instance_valid(activation_indicator):
		return

	activation_indicator.visible = (
		GameState.has_discovered_sanctuary(
			sanctuary_id
		)
	)


# ==================================================
# PLAYER ENTERS INTERACTION AREA
# ==================================================

func _on_interaction_area_body_entered(
	body: Node2D
) -> void:

	if not body.is_in_group("player"):
		return

	player = body as CharacterBody2D
	player_nearby = true

	if GameState.has_discovered_sanctuary(
		sanctuary_id
	):

		interaction_label.text = (
			"Press E to Interact"
		)

	else:

		interaction_label.text = (
			"Press E to Activate"
		)

	interaction_label.show()


# ==================================================
# PLAYER EXITS INTERACTION AREA
# ==================================================

func _on_interaction_area_body_exited(
	body: Node2D
) -> void:

	if not body.is_in_group("player"):
		return

	player_nearby = false

	interaction_label.hide()

	# Do not destroy the player reference while
	# a sanctuary submenu is still open.
	if sanctuary_menu_open:
		return

	if upgrade_menu_open or fast_travel_menu_open:
		return

	player = null
