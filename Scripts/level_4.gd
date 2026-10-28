extends Node2D

var level_completing: bool = false

@onready var player: CharacterBody2D = $Player
@onready var level_camera: LevelCameraController = $LevelCamera
@onready var keys_root: Node2D = get_node_or_null("Keys")

func _ready() -> void:
	AudioManager.play_game_audio()

	setup_camera_limits()

	# Restore sanctuary checkpoint.
	if GameState.loading_from_save:
		GameState.loading_from_save = false
		GameState.pending_spawn_id = ""

		restore_saved_position()
		GameState.is_transitioning = false
		return

	# Entering through another level or fast travel.
	if not GameState.pending_spawn_id.is_empty():
		restore_entry_position()

		GameState.is_transitioning = false
		return

	GameState.is_transitioning = false

	# Normal new-game start.
	await preview_uncollected_key()


func restore_entry_position() -> void:
	var spawn_id: String = GameState.pending_spawn_id

	GameState.pending_spawn_id = ""

	if spawn_id.begins_with("sanctuary:"):
		var sanctuary_id := spawn_id.trim_prefix(
			"sanctuary:"
		)

		if place_at_sanctuary(sanctuary_id):
			print("LEVEL: Arrived by fast travel.")
		return

	var spawn_marker: Marker2D = get_node_or_null(
		"EntryPoints/" + spawn_id
	)

	if spawn_marker == null:
		push_error(
			"LEVEL: Entry marker missing: ",
			spawn_id
		)
		return

	player.global_position = spawn_marker.global_position
	player.velocity = Vector2.ZERO

	print("LEVEL: Entered through ", spawn_id)
	

func preview_uncollected_key() -> void:
	for key_node in keys_root.get_children():
		if not is_instance_valid(key_node):
			continue

		if key_node.is_queued_for_deletion():
			continue

		if not key_node is Area2D:
			continue

		if not key_node.get("key_id") is String:
			continue

		if GameState.has_key(key_node.key_id):
			continue

		await level_camera.play_level_preview(
			key_node.global_position
		)
		return


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



func restore_saved_position() -> void:
	if GameState.last_sanctuary_id.is_empty():
		return

	if not place_at_sanctuary(
		GameState.last_sanctuary_id
	):
		push_warning(
			"LEVEL: Saved sanctuary not found."
		)


func place_at_sanctuary(
	sanctuary_id: String
) -> bool:

	var sanctuaries := get_tree().get_nodes_in_group(
		"sanctuaries"
	)

	for sanctuary in sanctuaries:
		if not is_ancestor_of(sanctuary):
			continue

		if sanctuary.sanctuary_id != sanctuary_id:
			continue

		var marker: Marker2D = sanctuary.get_node_or_null(
			"SpawnPoint"
		)

		if marker == null:
			push_error("SANCTUARY: SpawnPoint missing.")
			return false

		player.global_position = marker.global_position
		player.velocity = Vector2.ZERO

		print("LEVEL: Spawned at ", sanctuary_id)
		return true

	return false
