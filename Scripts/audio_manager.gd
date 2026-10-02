extends Node

@onready var music: AudioStreamPlayer = $GameBackgroundMusic
@onready var ambience: AudioStreamPlayer = $CaveAmbience
@onready var key_pickup_sound: AudioStreamPlayer = $KeyPickupSound
@onready var exit_sound: AudioStreamPlayer = $ExitSound
@onready var loot_box_break: AudioStreamPlayer = $LootboxBreak
@onready var weapon_drop: AudioStreamPlayer = $WeaponDrop


func play_game_audio() -> void:
	if not music.playing:
		music.play()

	if not ambience.playing:
		ambience.play()


func stop_game_audio() -> void:
	music.stop()
	ambience.stop()


func play_key_pickup() -> void:
	key_pickup_sound.play()

func play_loot_box_break() -> void:
	loot_box_break.play()

func play_weapon_drop() -> void:
	weapon_drop.play()

func play_exit() -> void:
	exit_sound.play()
	
#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_accept"):
		#play_key_pickup()
