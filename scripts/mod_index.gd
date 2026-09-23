extends Node

@export var mod_container: VBoxContainer
var mod_files: Array[String]
var config = ConfigFile.new()
var mods_data: Variant
@onready var root_node: Control = self.owner

func _ready():
	var err = config.load(ProjectSettings.globalize_path("res://config.ini"))
	
	if err != OK:
		root_node.config_loaded = false
	
	var index_url = config.get_value("Settings", "index_url", "")
	
	if root_node.config_loaded:
		$HTTPRequest.request(index_url)
	else:
		%Placeholder.text = "Failed to fetch index, config file missing.\nPress install to install the mod loader without mods."

func _load_local_index_files() -> void:
	var index_files: PackedStringArray = DirAccess.get_files_at(ProjectSettings.globalize_path("res://local_indexes"))
	for file in index_files:
		if file.get_extension() == "json":
			var file_open = FileAccess.open("res://local_indexes".path_join(file), FileAccess.READ)
			var file_str = file_open.get_as_text()
			var json = JSON.parse_string(file_str)
			_construct_mod_list(json)

func _on_request_completed(result, response_code, headers, body) -> void:
	if response_code != 200:
		%Placeholder.text = "Failed to fetch index, restart the app to try refetching it.\nPress install to install the mod loader without mods."
		
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	_construct_mod_list(json)
	
func _construct_mod_list(mods) -> void:
	%Placeholder.visible = false
	var mod_button_scene = preload("res://scenes/mod_button.tscn")
	for mod in mods:
		var mod_button_instance = mod_button_scene.instantiate()
		mod_button_instance.download_url = mod["download_url"]
		mod_button_instance.author = mod["author"]
		mod_button_instance.mod_name = mod["mod_name"]
		mod_button_instance.description = mod["description"]
		mod_container.add_child(mod_button_instance)
		mod_files.append(mod["download_url"].split("/")[-1])
