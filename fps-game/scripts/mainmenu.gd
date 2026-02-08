extends Node3D

@export var world : PackedScene = load("res://scenes/world.tscn")
@export var options : PackedScene = load("res://scenes/options.tscn")
var bgm_player = AudioStreamPlayer.new()

func _ready():
	add_child(bgm_player)
	# Load your music file here
	bgm_player.stream = load("res://assets/Audio/Ambiance.wav") 
	bgm_player.bus = "Master" # Optional: if you made a Music bus
	bgm_player.play()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_packed(world)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_packed(options)


func _on_quit_pressed() -> void:
	get_tree().quit()

func stop_music():
	bgm_player.stop()
