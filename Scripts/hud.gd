
extends CanvasLayer

@onready var ammo_label: Label = $MarginContainer/VBoxContainer/AmmoLabel
@onready var essence_label: Label = $MarginContainer/VBoxContainer/EssenceLabel


func _ready() -> void:
	# Listen for ammo changes.
	GameState.ammo_changed.connect(_on_ammo_changed)

	# Listen for Essence changes.
	GameState.essence_changed.connect(_on_essence_changed)

	# Initialize both displays.
	_on_ammo_changed(GameState.ammo, GameState.MAX_AMMO)
	_on_essence_changed(GameState.essence)


func _on_ammo_changed(
	current_ammo: int,
	max_ammo: int
) -> void:
	ammo_label.text = "%d/%d" % [
		current_ammo,
		max_ammo
	]


func _on_essence_changed(amount: int) -> void:
	essence_label.text = "Essence: %d" % amount
