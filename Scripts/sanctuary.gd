
extends Node2D

# ==================================================
# SANCTUARY SETTINGS
# ==================================================

# Unique identifier for this sanctuary.
# Each sanctuary in the game should have its own ID.
@export var sanctuary_id: String = "sanctuary_01"


# ==================================================
# PLAYER INTERACTION STATE
# ==================================================

# Whether the player is inside the interaction area.
var player_nearby: bool = false

# Reference to the player currently interacting.
var player: CharacterBody2D = null

# Whether the upgrade menu is currently open.
var upgrade_menu_open: bool = false

# Current selection:
# 0 = Rest & Save
# 1 = Upgrade
var selected_option: int = 0

const OPTION_COUNT: int = 2


# ==================================================
# SCENE REFERENCES
# ==================================================

# Existing interaction label.
@onready var interaction_label: Label = $InteractionLabel

# Small menu displayed above the sanctuary.
@onready var interaction_menu: Control = $InteractionMenu

# Two available sanctuary options.
@onready var rest_option: Label = $InteractionMenu/VBoxContainer/RestOption
@onready var upgrade_option: Label = $InteractionMenu/VBoxContainer/UpgradeOption

# Existing reusable upgrade menu scene.
@onready var upgrade_menu = $SanctuaryUpgradeMenu


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	# Hide the interaction elements when the level loads.
	interaction_label.hide()
	interaction_menu.hide()

	# Listen for the upgrade menu closing.
	upgrade_menu.menu_closed.connect(
		_on_upgrade_menu_closed
	)


# ==================================================
# INPUT HANDLING
# ==================================================

func _unhandled_input(event: InputEvent) -> void:
	# Ignore input when the player is not nearby
	# or the upgrade menu is already open.
	if not player_nearby or upgrade_menu_open:
		return

	# Only respond to new key presses.
	if not event.is_pressed() or event.is_echo():
		return

	# Navigate upward.
	if event.is_action("ui_up"):
		change_selection(-1)
		get_viewport().set_input_as_handled()

	# Navigate downward.
	elif event.is_action("ui_down"):
		change_selection(1)
		get_viewport().set_input_as_handled()

	# Confirm the currently selected option.
	elif event.is_action("interact"):
		confirm_selection()
		get_viewport().set_input_as_handled()


# ==================================================
# OPTION NAVIGATION
# ==================================================

func change_selection(direction: int) -> void:
	# Cycle between Rest & Save and Upgrade.
	selected_option = wrapi(
		selected_option + direction,
		0,
		OPTION_COUNT
	)

	update_options()


# ==================================================
# UPDATE INTERACTION DISPLAY
# ==================================================

func update_options() -> void:
	# Add an arrow to the selected option.
	if selected_option == 0:
		rest_option.text = "> Rest & Save"
		upgrade_option.text = "  Upgrade"
	else:
		rest_option.text = "  Rest & Save"
		upgrade_option.text = "> Upgrade"

	# Highlight the selected option.
	rest_option.modulate = (
		Color(0.5, 0.8, 1.0)
		if selected_option == 0
		else Color.WHITE
	)

	upgrade_option.modulate = (
		Color(0.5, 0.8, 1.0)
		if selected_option == 1
		else Color.WHITE
	)


# ==================================================
# CONFIRM SELECTED ACTION
# ==================================================

func confirm_selection() -> void:
	match selected_option:
		0:
			activate_sanctuary()

		1:
			open_upgrade_menu()


# ==================================================
# OPEN UPGRADE MENU
# ==================================================

func open_upgrade_menu() -> void:
	if upgrade_menu_open:
		return

	# Activate this sanctuary as the current checkpoint.
	activate_sanctuary()

	upgrade_menu_open = true

	interaction_menu.hide()
	interaction_label.hide()

	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.controls_enabled = false

	upgrade_menu.open_menu()


# ==================================================
# UPGRADE MENU CLOSED
# ==================================================

func _on_upgrade_menu_closed() -> void:
	upgrade_menu_open = false

	# Restore player controls.
	if is_instance_valid(player):
		player.controls_enabled = true

	# Restore the interaction choices if nearby.
	if player_nearby:
		interaction_menu.show()
		interaction_label.show()
		update_options()


# ==================================================
# REST AND SAVE
# ==================================================

func activate_sanctuary() -> void:
	# Get the current level.
	var level := get_tree().current_scene

	if level == null:
		push_warning("Sanctuary: Current level not found.")
		return

	# Store the checkpoint level and sanctuary ID.
	GameState.current_level = level.scene_file_path
	GameState.last_sanctuary_id = sanctuary_id

	# Restore health and ammunition.
	GameState.rest_at_sanctuary()

	# Save the game.
	if SaveManager.save_game():
		print("Sanctuary activated: ", sanctuary_id)
	else:
		push_warning("Sanctuary save failed.")


# ==================================================
# PLAYER ENTERS INTERACTION AREA
# ==================================================

func _on_interaction_area_body_entered(
	body: Node2D
) -> void:
	# Only allow the player to interact.
	if not body.is_in_group("player"):
		return

	player = body as CharacterBody2D
	player_nearby = true

	# Default to the Rest & Save option.
	selected_option = 0

	# Display interaction elements.
	interaction_label.show()
	interaction_menu.show()

	update_options()


# ==================================================
# PLAYER EXITS INTERACTION AREA
# ==================================================

func _on_interaction_area_body_exited(
	body: Node2D
) -> void:
	if not body.is_in_group("player"):
		return

	player_nearby = false

	# Hide interaction elements.
	interaction_label.hide()
	interaction_menu.hide()

	# Clear the player reference.
	player = null
