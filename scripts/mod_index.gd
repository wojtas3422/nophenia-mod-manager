extends Node

@export var mod_container: VBoxContainer
var config = ConfigFile.new()
var mods_data: Variant

func _ready():
	var err = config.load("res://config.ini")
	
	if err != OK:
		OS.alert("Failed to load mod index url", "Error!")
		get_tree().quit()
	
	var index_url: String = config.get_value("Settings", "index_url")
	
	$HTTPRequest.request_completed.connect(_on_request_completed)
	$HTTPRequest.request(index_url)

func _on_request_completed(result, response_code, headers, body) -> void:
	if response_code != 200:
		OS.alert("Failed to fetch index.", "Error")
		get_tree().quit() #IMPORTANT skip the screen instead of exiting the app.
		
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	_construct_mod_list(json)
	
func _construct_mod_list(mods) -> void:
	%Placeholder.queue_free()
	var mod_button_scene = preload("res://scenes/mod_button.tscn")
	for mod in mods:
		var mod_button_instance = mod_button_scene.instantiate()
		mod_button_instance.author = mod["author"]
		mod_button_instance.mod_name = mod["mod_name"]
		mod_button_instance.description = mod["description"]
		mod_container.add_child(mod_button_instance)
