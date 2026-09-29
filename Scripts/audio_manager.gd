extends Node

@onready var music: AudioStreamPlayer = $GameBackgroundMusic
@onready var ambience: AudioStreamPlayer = $CaveAmbience


func play_game_audio() -> void:
	if not music.playing:
		music.play()

	if not ambience.playing:
		ambience.play()


func stop_game_audio() -> void:
	music.stop()
	ambience.stop()
