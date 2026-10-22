
extends CanvasLayer

signal menu_closed

@onready var essence_label: Label = $PanelContainer/VBoxContainer/EssenceLabel

@onready var vitality_button: Button = $PanelContainer/VBoxContainer/VitalityButton
@onready var ferocity_button: Button = $PanelContainer/VBoxContainer/FerocityButton
@onready var concentration_button: Button = $PanelContainer/VBoxContainer/ConcentrationButton
@onready var fluidity_button: Button = $PanelContainer/VBoxContainer/FluidityButton
@onready var close_button: Button = $PanelContainer/VBoxContainer/CloseButton

var buttons: Dictionary = {}

var upgrade_options: Array[String] = [
	"vitality",
	"ferocity",
	"concentration",
	"fluidity",
	"close"
]

var selected_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	buttons = {
		"vitality": vitality_button,
		"ferocity": ferocity_button,
		"concentration": concentration_button,
		"fluidity": fluidity_button
	}

	for stat in buttons:
		var button: Button = buttons[stat]

		button.pressed.connect(
			_on_upgrade_pressed.bind(stat)
		)

	close_button.pressed.connect(close_menu)

	GameState.essence_changed.connect(
		_on_essence_changed
	)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if not event.is_pressed() or event.is_echo():
		return

	if event.is_action("ui_up"):
		selected_index = wrapi(
			selected_index - 1,
			0,
			upgrade_options.size()
		)

		update_selection()
		get_viewport().set_input_as_handled()

	elif event.is_action("ui_down"):
		selected_index = wrapi(
			selected_index + 1,
			0,
			upgrade_options.size()
		)

		update_selection()
		get_viewport().set_input_as_handled()

	elif event.is_action("interact"):
		confirm_selection()
		get_viewport().set_input_as_handled()

	elif event.is_action("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	selected_index = 0

	refresh_menu()
	update_selection()

	show()
	get_tree().paused = true


func close_menu() -> void:
	hide()
	get_tree().paused = false
	menu_closed.emit()



func update_selection() -> void:
	for stat in buttons:
		var button: Button = buttons[stat]
		button.modulate = Color.WHITE

	close_button.modulate = Color.WHITE

	var selected_stat: String = upgrade_options[selected_index]

	if selected_stat == "close":
		close_button.modulate = Color(0.5, 0.8, 1.0)
	else:
		var button: Button = buttons[selected_stat]
		button.modulate = Color(0.5, 0.8, 1.0)



func confirm_selection() -> void:
	var selected_stat: String = upgrade_options[selected_index]

	if selected_stat == "close":
		close_menu()
		return

	# Prevent purchasing unavailable upgrades.
	var cost: int = GameState.get_upgrade_cost(selected_stat)

	if cost < 0 or GameState.essence < cost:
		return

	_on_upgrade_pressed(selected_stat)


func refresh_menu() -> void:
	essence_label.text = "Essence: %d" % GameState.essence

	for stat in buttons:
		var button: Button = buttons[stat]
		var rank: int = GameState.get_stat_rank(stat)
		var cost: int = GameState.get_upgrade_cost(stat)

		if cost < 0:
			button.text = "%s  MAX RANK" % stat.capitalize()
			button.disabled = true
			continue

		button.text = "%s  [%d/5]  -  %d Essence" % [
			stat.capitalize(),
			rank,
			cost
		]

		button.disabled = GameState.essence < cost



func _on_upgrade_pressed(stat: String) -> void:
	var success: bool = GameState.purchase_upgrade(stat)

	if not success:
		print("Upgrade unavailable: ", stat)
		return

	# Refresh Essence and upgrade costs.
	refresh_menu()
	update_selection()

	# Store the upgraded character progression.
	if GameState.last_sanctuary_id != "":
		if SaveManager.save_game():
			print("Upgrade saved: ", stat)
		else:
			push_warning("Failed to save upgrade.")
	else:
		push_warning(
			"No active sanctuary checkpoint. Upgrade not saved."
		)



func _on_essence_changed(_amount: int) -> void:
	refresh_menu()
