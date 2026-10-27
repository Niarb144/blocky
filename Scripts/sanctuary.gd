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

var player_nearby: bool = false

var player: CharacterBody2D = null

# Whether a sanctuary submenu is currently open.
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

# Existing interaction label.
@onready var interaction_label: Label = $InteractionLabel

# Small menu displayed above the sanctuary.
@onready var interaction_menu: Control = $InteractionMenu

# Two available sanctuary options.
@onready var rest_option: Label = $InteractionMenu/VBoxContainer/RestOption
@onready var upgrade_option: Label = $InteractionMenu/VBoxContainer/UpgradeOption

@onready var fast_travel_option: Label = (
	$InteractionMenu/VBoxContainer/FastTravelOption
)

@onready var fast_travel_menu = (
	$FastTravelMenu
)


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

	fast_travel_menu.menu_closed.connect(
		_on_fast_travel_menu_closed
	)

# ==================================================
# INPUT HANDLING
# ==================================================

func _unhandled_input(event: InputEvent) -> void:
	if not player_nearby:
		return

	if upgrade_menu_open or fast_travel_menu_open:
		return

	if not event.is_pressed() or event.is_echo():
		return

	if event.is_action("ui_up"):
		change_selection(-1)
		get_viewport().set_input_as_handled()

	elif event.is_action("ui_down"):
		change_selection(1)
		get_viewport().set_input_as_handled()

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
	var options: Array[Label] = [
		rest_option,
		upgrade_option,
		fast_travel_option
	]

	var names: Array[String] = [
		"Rest & Save",
		"Upgrade",
		"Fast Travel"
	]

	for i in range(options.size()):
		var selected: bool = (i == selected_option)

		options[i].text = (
			"> " if selected else "  "
		) + names[i]

		options[i].modulate = (
			Color(0.5, 0.8, 1.0)
			if selected
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
			
		2: 
			open_fast_travel_menu()


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
# OPEN FAST TRAVEL MENU
# ==================================================

func open_fast_travel_menu() -> void:
	if fast_travel_menu_open:
		return

	# Rest and save progress before fast travel.
	activate_sanctuary()

	fast_travel_menu_open = true

	# Hide sanctuary interaction UI.
	interaction_menu.hide()
	interaction_label.hide()

	# Disable player movement and combat.
	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.controls_enabled = false

	# Open the destination menu.
	fast_travel_menu.open_menu(sanctuary_id)


# ==================================================
# FAST TRAVEL MENU CLOSED
# ==================================================

func _on_fast_travel_menu_closed() -> void:
	fast_travel_menu_open = false

	if is_instance_valid(player):
		player.controls_enabled = true

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
	
	# Unlock this sanctuary for fast travel.
	GameState.discover_sanctuary(
		sanctuary_id,
		level.scene_file_path
	)
	
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

	interaction_label.hide()
	interaction_menu.hide()

	# Keep the reference while a submenu is open.
	if upgrade_menu_open or fast_travel_menu_open:
		return

	player = null
