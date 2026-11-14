extends RefCounted

const Model = preload("res://scripts/model.gd")
const PREVIOUS_CAREER = "save_v2.previous_career.json"
var validator
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
	if validator==null: validator=Model.new()
	if not validator.validate_save(parsed):
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

# ui-v2 (owner 14.11): three manual slots besides the current game. A slot is written whole through a temp file and checked.
const SLOTS = 3

func slot_name(n: int) -> String:
	return "save_slot_%d.json" % n

func write_slot(model, n: int) -> bool:
	error = ""
	var temp_name = "save_slot_%d.tmp" % n
	var temp = FileAccess.open(path(temp_name), FileAccess.WRITE)
	if temp == null:
		error = "Не удалось записать слот %d" % n
		return false
	temp.store_string(JSON.stringify(model.serialize()))
	temp.flush()
	var write_error = temp.get_error()
	temp.close()
	if write_error != OK or read_valid(temp_name).is_empty():
		error = "Проверка слота %d не пройдена" % n
		return false
	if FileAccess.file_exists(path(slot_name(n))): DirAccess.remove_absolute(path(slot_name(n)))
	if DirAccess.rename_absolute(path(temp_name), path(slot_name(n))) != OK:
		error = "Не удалось записать слот %d" % n
		return false
	return true

# one line about a save for the list of the menu: the mode, the progress, the coins and when it was written
func summary(name: String) -> String:
	var saved = read_valid(name)
	if saved.is_empty(): return ""
	var when = Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path(name)), true).replace("T", " ").substr(0, 16)
	if str(saved.get("mode", "career")) == "creative": return "творческий режим · " + when
	return "карьера · рейсов %d из 10 · %d монет · %s" % [int(saved.get("chapter", 0)), int(saved.get("money", 0)), when]

func has_any() -> bool:
	return FileAccess.file_exists(path("save_v2.json")) or FileAccess.file_exists(path("save_v2.backup.json"))

func archive_career() -> bool:
	error=""
	for name in ["save_v2.json","save_v2.backup.json"]:
		if read_valid(name).is_empty(): continue
		if DirAccess.copy_absolute(path(name),path(PREVIOUS_CAREER))!=OK:
			error="Не удалось сохранить прежнюю карьеру"
			return false
		return true
	return true
