extends Control

@export var next_button: Button
var screens: Array[String] = ["mod_select_ui.tscn"]
var current_screen: int = -1



func _ready() -> void:
	next_button.connect("pressed", _on_next_screen)

func _on_next_screen():
	var next_screen_scene = load("res://scenes/".path_join(screens[current_screen]))
	var next_screen_instance = next_screen_scene.instantiate()
	get_tree().get_first_node_in_group("screen").queue_free()
	current_screen += 1
	self.add_child(next_screen_instance)
