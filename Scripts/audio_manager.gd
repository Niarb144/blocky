extends Node

@onready var music: AudioStreamPlayer = $GameBackgroundMusic
@onready var ambience: AudioStreamPlayer = $CaveAmbience
@onready var key_pickup_sound: AudioStreamPlayer = $KeyPickupSound
@onready var exit_sound: AudioStreamPlayer = $ExitSound
@onready var loot_box_break: AudioStreamPlayer = $LootboxBreak
@onready var weapon_drop: AudioStreamPlayer = $WeaponDrop
@onready var health_pickup: AudioStreamPlayer = $HealthPickup

@onready var attack_slash: AudioStreamPlayer = $AttackSlash
@onready var attack_heavy: AudioStreamPlayer = $AttackHeavy


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


func play_health_pickup() -> void:
	health_pickup.play()


func play_exit() -> void:
	exit_sound.play()


func play_attack_slash() -> void:
	attack_slash.play()


func play_attack_heavy() -> void:
	attack_heavy.play()
