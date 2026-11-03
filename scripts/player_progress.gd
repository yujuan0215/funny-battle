extends RefCounted
## Only completed levels are persisted; a retry never overwrites a previous clear.

const SAVE_PATH := "user://player_progress.json"
const LAB_SAVE_PATH := "user://test_lab_progress.json"
const VERSION := 1


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if data.get("version", 0) != VERSION or not data.get("levels", null) is Dictionary:
		return {}
	return data


static func load_progress(path: String = SAVE_PATH) -> Dictionary:
	var data := _read(path)
	if data.is_empty():
		data = _read(path + ".bak")
	return data if not data.is_empty() else {"version": VERSION, "levels": {}}


static func is_cleared(level: int, path: String = SAVE_PATH) -> bool:
	var levels: Dictionary = load_progress(path)["levels"]
	return levels.get(str(level), false) == true


static func mark_cleared(level: int, path: String = SAVE_PATH) -> Error:
	var data := load_progress(path)
	data["levels"][str(level)] = true
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	# Keep the last valid save before replacing the file on the same filesystem.
	if not _read(path).is_empty():
		var copied := DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
		if copied != OK:
			return copied
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
