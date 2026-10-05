extends CanvasLayer

@onready var ammo_label: Label = $MarginContainer/AmmoLabel


func _ready() -> void:
	GameState.ammo_changed.connect(_on_ammo_changed)

	# Show the current count immediately when this level loads.
	_on_ammo_changed(GameState.ammo, GameState.MAX_AMMO)


func _on_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	ammo_label.text = "%d/%d" % [current_ammo, max_ammo]
