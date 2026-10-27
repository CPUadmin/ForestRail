extends RefCounted

const Model = preload("res://scripts/model.gd")
var directory = "user://"
var error = ""

func path(name: String) -> String:
	return directory.path_join(name)

func read_valid(name: String) -> Dictionary:
	if not FileAccess.file_exists(path(name)):
		return {}
	var text = FileAccess.get_file_as_string(path(name))
	var parser = JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary:
		return {}
	var probe = Model.new()
	if not probe.validate_save(parsed):
		return {}
	return parsed

func write(model, preserve_backup: bool = false) -> bool:
	error = ""
	var temp = FileAccess.open(path("save_v2.tmp"), FileAccess.WRITE)
	if temp == null:
		error = "Не удалось записать сохранение. Игра остаётся в памяти"
		return false
	temp.store_string(JSON.stringify(model.serialize()))
	temp.flush()
	var write_error = temp.get_error()
	temp.close()
	if write_error != OK or read_valid("save_v2.tmp").is_empty():
		error = "Проверка нового сохранения не пройдена"
		return false
	if not preserve_backup and not read_valid("save_v2.json").is_empty():
		if DirAccess.copy_absolute(path("save_v2.json"), path("save_v2.backup.json")) != OK:
			error = "Не удалось сохранить резервную копию"
			return false
	if DirAccess.rename_absolute(path("save_v2.tmp"), path("save_v2.json")) != OK:
		error = "Не удалось заменить файл сохранения"
		return false
	return true

func has_any() -> bool:
	return FileAccess.file_exists(path("save_v2.json")) or FileAccess.file_exists(path("save_v2.backup.json"))
