extends Node3D

@export var world : PackedScene = load("res://scenes/world.tscn")
@export var options : PackedScene = load("res://scenes/options.tscn")

func _on_start_pressed() -> void:
	get_tree().change_scene_to_packed(world)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_packed(options)


func _on_quit_pressed() -> void:
	get_tree().quit()
