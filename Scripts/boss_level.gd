
extends Node2D

@export_group("Boss Level")
@export_file("*.tscn") var victory_scene: String = (
	"res://Scenes/UI/boss_victory.tscn"
)

@export var victory_delay: float = 1.0

@onready var player: CharacterBody2D = $Player
@onready var boss: CharacterBody2D = $ShadowDemon
@onready var level_camera: LevelCameraController = $LevelCamera

@onready var boss_health_bar: Control = (
	$BossUI/BossHealthBar
)

var level_completing: bool = false


func _ready() -> void:
	# Start dedicated boss music.
	AudioManager.play_boss_audio()

	# Connect the boss UI and defeat event.
	boss_health_bar.setup_boss(boss)
	boss.boss_defeated.connect(_on_boss_defeated)

	# Calculate the arena's camera boundaries.
	setup_camera_limits()

	# Preview the boss instead of a key.
	await level_camera.play_level_preview(
		boss.global_position
	)

	if not is_inside_tree() or level_completing:
		return

	print("SHADOW DEMON BATTLE STARTED!")


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
			if layer.tile_set == null:
				continue

			var used_rect: Rect2i = layer.get_used_rect()

			if used_rect.size == Vector2i.ZERO:
				continue

			var tile_size := Vector2(layer.tile_set.tile_size)
			var first := used_rect.position
			var last := (
				used_rect.position + used_rect.size
				- Vector2i.ONE
			)

			# Find world-space bounds of occupied tiles.
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
		push_warning("Boss arena camera bounds not found.")
		return

	level_camera.limit_left = floori(bounds.position.x)
	level_camera.limit_top = floori(bounds.position.y)
	level_camera.limit_right = ceili(bounds.end.x)
	level_camera.limit_bottom = ceili(bounds.end.y)


func _on_boss_defeated() -> void:
	if level_completing:
		return

	level_completing = true

	print("SHADOW DEMON DEFEATED!")
	print("PLAYER HAS ESCAPED HELL!")

	# Stop boss battle music.
	AudioManager.stop_boss_audio()

	# Give the death animation a moment to settle.
	await get_tree().create_timer(victory_delay).timeout

	if not is_inside_tree():
		return

	# Transition to the victory screen.
	load_victory_scene()


func load_victory_scene() -> void:
	if not ResourceLoader.exists(victory_scene):
		push_error(
			"Victory scene not found: " + victory_scene
		)
		return

	get_tree().change_scene_to_file(victory_scene)
