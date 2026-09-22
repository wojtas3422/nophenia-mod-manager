extends Control

@onready var orig_game_line: LineEdit = %OrigGameLine
@onready var orig_button: Button = %OrigButton
@onready var orig_fd: FileDialog = %OrigFD
@onready var patched_game_line: LineEdit = %PatchedGameLine
@onready var patched_button: Button = %PatchedButton
@onready var patched_fd: FileDialog = %PatchedFD
@onready var desktop_shortcut_button: CheckBox = %DesktopShortcutButton
@onready var experimental_button: CheckBox = %ExperimentalButton
@onready var next_button: Button = %NextButton
@onready var install_button: Button = %InstallButton
@onready var star_0: RichTextLabel = %Star0
@onready var star_1: RichTextLabel = %Star1
@onready var star_2: RichTextLabel = %Star2
@onready var path_select_screen: MarginContainer = %path_select
@onready var mod_select_screen: MarginContainer = %mod_select
@onready var mod_downloader: HTTPRequest = %ModDownloader
var already_patched: bool
var config = ConfigFile.new()

var config_file_path = ProjectSettings.globalize_path("res://config.ini")

signal mod_download_complete

var counter := 0

var valid_orig := false:
	set(value):
		valid_orig = value
		if valid_orig and valid_patched:
			next_button.disabled = false
		else:
			next_button.disabled = true
var valid_patched := false:
	set(value):
		valid_patched = value
		if valid_orig and valid_patched:
			next_button.disabled = false
		else:
			next_button.disabled = true

func _ready() -> void:
	orig_game_line.text = find_steam_game_path()
	_on_orig_game_line_text_changed(orig_game_line.text)
	var err = config.load(ProjectSettings.globalize_path("res://config.ini"))
	
	if err != OK:
		OS.alert("Failed to load loader config", "Error!")
		get_tree().quit() # TODO don't exit if the index fails
	
	patched_game_line.text = config.get_value("Settings", "last_patched_path")

func find_steam_game_path() -> String:
	var steam_path := ""
	if OS.get_name() == "Windows":
		var pf = OS.get_environment("ProgramFiles(x86)")
		steam_path = pf.path_join("Steam")
	elif OS.get_name() == "Linux":
		steam_path = OS.get_environment("HOME").path_join(".steam/steam")
	if steam_path.is_empty():
		return ""
	
	var library_file = steam_path.path_join("steamapps/libraryfolders.vdf")
	if not FileAccess.file_exists(library_file):
		return ""
	var steamapps: Array[String] = [steam_path.path_join("steamapps")]
	var file := FileAccess.open(library_file, FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges().begins_with("\"path\""):
			var path := line.split("\"")[3]
			var apps = path.path_join("steamapps")
			steamapps.append(apps)
	file.close()
	
	for apps in steamapps:
		var game_path = apps.path_join("common").path_join("nophenia").replace("\\", "/").simplify_path()
		if DirAccess.dir_exists_absolute(game_path):
			return game_path
	for apps in steamapps:
		var game_path = apps.path_join("common").path_join("nophenia Demo").replace("\\", "/").simplify_path()
		if DirAccess.dir_exists_absolute(game_path):
			return game_path
	return ""

func _on_orig_fd_dir_selected(dir: String) -> void:
	orig_game_line.text = dir
	_on_orig_game_line_text_changed(dir)

func _on_orig_button_pressed() -> void:
	orig_fd.popup_centered_ratio()

func _on_patched_fd_dir_selected(dir: String) -> void:
	patched_game_line.text = dir
	_on_patched_game_line_text_changed(dir)

func _on_patched_button_pressed() -> void:
	patched_fd.popup_centered_ratio()

func _replace_color(text: String, color: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[color=[^\\]]+\\]")
	var replacement = "[color=%s]" % color
	return regex.sub(text, replacement)

func _fetch_exec(path: String) -> String:
	if FileAccess.file_exists(path.path_join("nophenia.exe")):
		return path.path_join("nophenia.exe")
	elif FileAccess.file_exists(path.path_join("nophenia.x86_64")):
		return path.path_join("nophenia.x86_64")
	return ""

func _on_orig_game_line_text_changed(new_text: String) -> void:
	if _fetch_exec(new_text) != "":
		star_0.text = _replace_color(star_0.text, "white")
		valid_orig = true
	else:
		star_0.text = _replace_color(star_0.text, "#818589")
		valid_orig = false

func _on_patched_game_line_text_changed(new_text: String) -> void:
	if new_text != "" and DirAccess.dir_exists_absolute(new_text):
		#star_1.text = _replace_color(star_0.text, "white")
		valid_patched = true
		if DirAccess.dir_exists_absolute(new_text.path_join("mods")):
			already_patched = true
			%InstallButton.text = "Modify"
		else:
			already_patched = false
			%InstallButton.text = "Install"
	else:
		#star_1.text = _replace_color(star_0.text, "#818589")
		valid_patched = false

func _copy_files(from: String, to: String) -> void:
	for file in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(file), to.path_join(file))

func _copy_recursive(from: String, to: String) -> void:
	if not DirAccess.dir_exists_absolute(to):
		DirAccess.make_dir_recursive_absolute(to)
	for file in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(file), to.path_join(file))
	for folder in DirAccess.get_directories_at(from):
		_copy_recursive(from.path_join(folder), to.path_join(folder))

func _merge_cfg_lists(orig_path: String, mod_path: String) -> void:
	var original_config = ConfigFile.new()
	var mod_config = ConfigFile.new()
	original_config.load(orig_path)
	mod_config.load(mod_path)
	
	var merged_dict: Dictionary = {}
	var original_list: Array = original_config.get_value("", "list", [])
	for entry in original_list:
		var class_name_key = entry.get("class", "")
		merged_dict[class_name_key] = entry
	var mod_list: Array = mod_config.get_value("", "list", [])
	for entry in mod_list:
		var class_name_key = entry.get("class", "")
		merged_dict[class_name_key] = entry
	var result: Array = merged_dict.values()
	
	original_config.set_value("", "list", result)
	original_config.save(orig_path)

func _extract() -> bool:
	var status: int
	if OS.get_name() == "Windows":
		var exec_path := ProjectSettings.globalize_path("res://gdre/win/gdre_tools.exe")
		var arguments := PackedStringArray([
			"--headless",
			"--include=res://.godot/**",
			"--extract=%s" % orig_game_line.text.path_join("nophenia.exe"),
			"--output=%s" % patched_game_line.text
		])
		status = OS.execute(exec_path, arguments)
	elif OS.get_name() == "Linux":
		var exec_path := ProjectSettings.globalize_path("res://gdre/linux/gdre_tools.x86_64")
		var arguments := PackedStringArray([
			"--headless",
			"--include=res://.godot/**",
			"--extract=%s" % _fetch_exec(orig_game_line.text),
			"--output=%s" % patched_game_line.text
		])
		status = OS.execute(exec_path, arguments)
	if status != 0:
		OS.alert("Failed to extract", "Patch status")
		for star in [star_0, star_1, star_2]: star.text = _replace_color(star.text, "#FFB19E")
		return false
	DirAccess.rename_absolute(patched_game_line.text.path_join(".godot"), patched_game_line.text.path_join("godot"))
	return true

func _change_icon() -> void:
	if OS.get_name() == "Windows":
		var args = [patched_game_line.text.path_join("nophenia.exe"), "--set-icon", ProjectSettings.globalize_path("res://assets/game-icon.ico")]
		OS.execute(ProjectSettings.globalize_path("res://rcedit-x64.exe"), args)

func _create_desktop_shortcut() -> void:
	if OS.get_name() == "Windows":
		var exec_path = _fetch_exec(patched_game_line.text)
		var lnk = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).path_join("nophenia-mp.lnk").replace("/", "\\")
		var ps_cmd = "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%s');$s.TargetPath='%s';$s.Save()" % [lnk, exec_path]
		OS.execute("powershell", ["-Command", ps_cmd])
	elif OS.get_name() == "Linux":
		var icon_file := patched_game_line.text.path_join("icon.png")
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/game-icon.png"), icon_file)
		var desk = OS.get_environment("HOME").path_join("Desktop")
		var lnk = desk.path_join("nophenia-mp.desktop")
		var exec_path = _fetch_exec(patched_game_line.text)
		OS.execute("chmod", ["+x", exec_path])
		var content = "[Desktop Entry]\nType=Application\nName=nophenia-mp\nExec=%s\nPath=%s\nIcon=%s\n" % [exec_path, patched_game_line.text, icon_file]
		var file = FileAccess.open(lnk, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
			OS.execute("chmod", ["+x", lnk])

func _add_experimental_stuff() -> void:
	pass # TODO

func _collect_mod_urls() -> Array[String]:
	var mods_container = %ModContainer
	var mod_download_urls: Array[String]
	
	for mod in mods_container.get_children():
		if mod.find_child("CheckBox").button_pressed:
			mod_download_urls.append(mod.download_url)
	
	return mod_download_urls



func _on_install_button_pressed() -> void:
	var mods_storage_folder = ProjectSettings.globalize_path("res://mod_loader_artifacts/mods")
	var target_install_mods_folder = patched_game_line.text.path_join("mods")
	install_button.disabled = true
	if already_patched:
		# Patched
		#var mod_index_files: Array[String]
		#for file in %mod_select.mod_files:
			
		#var local_files: Array[String] = DirAccess.get_files_at(patched_game_line.text.path_join("mods"))
		#var files_to_delete: Array[String]
		# TODO don't delete local mods
		for file in DirAccess.get_files_at(patched_game_line.text.path_join("mods")):
			if file.get_extension() == "zip": # fail safe in case something goes wrong, delete only zip files
				DirAccess.remove_absolute(target_install_mods_folder.path_join(file))

		var mod_download_urls: Array[String] = _collect_mod_urls()
		for url in mod_download_urls:
			var filename = url.split("/")[-1]
			mod_downloader.download_file = target_install_mods_folder.path_join(filename)
			mod_downloader.request(url)
			await mod_download_complete
		
		_copy_files(mods_storage_folder, patched_game_line.text.path_join("mods"))
		OS.alert("Game modified succesfully.", "Patch status")
	else:
		# Not patched
		if !%Placeholder.visible: # Placeholder is only hidden once the index loads, it's only visible once index loading goes wrong 
			var mod_download_urls: Array[String] = _collect_mod_urls()
			for url in mod_download_urls:
				var filename = url.split("/")[-1]
				mod_downloader.download_file = ProjectSettings.globalize_path("res://mod_loader_artifacts/mods".path_join(filename))
				mod_downloader.request(url)
				await mod_download_complete
			
		var extracted:= _extract()
		if not extracted:
			return
		_copy_files(orig_game_line.text, patched_game_line.text)
		_copy_recursive(ProjectSettings.globalize_path("res://mod_loader_artifacts"), patched_game_line.text)
		_merge_cfg_lists(
			patched_game_line.text.path_join("godot").path_join("global_script_class_cache.cfg"),
			ProjectSettings.globalize_path("res://mod_loader_globals.cfg")
		)
		_change_icon()
		if desktop_shortcut_button.button_pressed:
			_create_desktop_shortcut()
		if experimental_button.button_pressed:
			_add_experimental_stuff()
		
		for file in DirAccess.get_files_at(mods_storage_folder):
			if file.get_extension() == "zip": # fail safe in case something goes wrong, delete only zip files
				DirAccess.remove_absolute(mods_storage_folder.path_join(file))
		
		OS.alert("Success!", "Patch status")
	
	config.set_value("Settings", "last_patched_path", patched_game_line.text)
	config.save(config_file_path)
	star_2.text = "[wave amp=60.0 freq=1 connected=1]✦"

func _extra_check():
	if randi_range(0, 99 - min(counter, 90)) == 0:
		experimental_button.visible = true

func _on_desktop_shortcut_button_pressed() -> void:
	counter += 1
	_extra_check()

func _on_next_button_pressed() -> void:
	if orig_game_line.text == patched_game_line.text and !already_patched:
		OS.alert("Patching the original install is not recommended as it is known to cause issues. Please pick a different directory for the patched game. Or press next to install anyway", "Warning")
	else:
		if already_patched:
			var mod_files: PackedStringArray = DirAccess.get_files_at(patched_game_line.text.path_join("mods"))
			var mod_index_container = %ModContainer
			for mod in mod_index_container.get_children():
				if mod.download_url.split("/")[-1] in mod_files:
					mod.find_child("CheckBox").button_pressed = true
		path_select_screen.visible = false
		mod_select_screen.visible = true


func _on_mod_downloader_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	mod_download_complete.emit()
