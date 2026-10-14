
extends Node2D

var has_key: bool = false
var level_completing: bool = false

@onready var key = $Key
@onready var player: CharacterBody2D = $Player
@onready var level_camera: LevelCameraController = $LevelCamera


func _ready() -> void:
	AudioManager.play_game_audio()
	key.collected.connect(_on_key_collected)

	setup_camera_limits()

	await level_camera.play_level_preview(
		key.global_position
	)


func setup_camera_limits() -> void:
	var bounds := Rect2()
	var has_bounds: bool = false

	for root in [$Floor, $Wall]:
		var layers: Array[TileMapLayer] = []

		if root is TileMapLayer:
			layers.append(root)

		for node in root.find_children(
			"*", "TileMapLayer", true, false
		):
			if node is TileMapLayer:
				layers.append(node)

		for layer in layers:
			var used_rect: Rect2i = layer.get_used_rect()

			if used_rect.size == Vector2i.ZERO:
				continue

			var tile_size := Vector2(layer.tile_set.tile_size)
			var first := used_rect.position
			var last := (
				used_rect.position + used_rect.size
				- Vector2i.ONE
			)

			# Find world-space bounds of occupied tiles
			for x in [first.x, last.x]:
				for y in [first.y, last.y]:
					var center := layer.map_to_local(
						Vector2i(x, y)
					)

					for offset_x in [-0.5, 0.5]:
						for offset_y in [-0.5, 0.5]:
							var offset := Vector2(
								offset_x * tile_size.x,
								offset_y * tile_size.y
							)

							var point := layer.to_global(
								center + offset
							)

							if not has_bounds:
								bounds = Rect2(point, Vector2.ZERO)
								has_bounds = true
							else:
								bounds = bounds.expand(point)

	if not has_bounds:
		return

	level_camera.limit_left = floori(bounds.position.x)
	level_camera.limit_top = floori(bounds.position.y)
	level_camera.limit_right = ceili(bounds.end.x)
	level_camera.limit_bottom = ceili(bounds.end.y)


func _on_key_collected() -> void:
	has_key = true
	print("LEVEL: Key collected!")


func complete_level() -> void:
	if level_completing:
		return

	level_completing = true

	AudioManager.play_exit()

	print("LEVEL COMPLETE!")

	call_deferred("_load_next_level")


func _load_next_level() -> void:
	get_tree().change_scene_to_file(
        "res://Scenes/Levels/boss_level.tscn"
	)
