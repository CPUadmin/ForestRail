extends RefCounted

const Model = preload("res://scripts/model.gd")
const PREVIOUS_CAREER = "save_v2.previous_career.json"
var directory = "user://"
var error = ""
# Any model instance can validate; reusing the game's avoids reparsing game data.
var validator

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
	if validator == null:
		validator = Model.new()
	if not validator.validate_save(parsed):
		return {}
	return parsed

func write(model) -> bool:
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
	if not read_valid("save_v2.json").is_empty():
		if DirAccess.copy_absolute(path("save_v2.json"), path("save_v2.backup.json")) != OK:
			error = "Не удалось сохранить резервную копию"
			return false
	if DirAccess.rename_absolute(path("save_v2.tmp"), path("save_v2.json")) != OK:
		error = "Не удалось заменить файл сохранения"
		return false
	return true

func has_any() -> bool:
	return FileAccess.file_exists(path("save_v2.json")) or FileAccess.file_exists(path("save_v2.backup.json"))

# Keeps the replaced career out of the regular backup rotation, which the new
# career's own saves would otherwise overwrite on the next write.
func archive_career() -> bool:
	error = ""
	for name in ["save_v2.json", "save_v2.backup.json"]:
		if read_valid(name).is_empty():
			continue
		if DirAccess.copy_absolute(path(name), path(PREVIOUS_CAREER)) != OK:
			error = "Не удалось сохранить прежнюю карьеру"
			return false
		return true
	return true
