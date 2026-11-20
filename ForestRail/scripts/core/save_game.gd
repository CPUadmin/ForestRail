extends RefCounted

const Model = preload("res://scripts/core/model.gd")
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
	if name == "save_v2.json": written[directory] = disk_mark(name)   # 1.3.11: checked now, the next save need not parse it again
	return parsed

# 1.3.9: a save used to cost ~42 ms (a torn frame on «Отправиться»): 98% of it is the route's points, which were turned into text,
# parsed back and checked on every write, and the old file was parsed once more before the backup. Now the points' text is made once
# per route, the new file is checked against the text written, and the old file is trusted when it is the very file this object wrote.
const POINTS_MARK = "@@route_points@@"
var points_ref = null
var points_size = -1
var points_text = ""
var written = {}   # directory -> [length, modified time] of the save_v2.json this object wrote and checked

# 1.3.11: the first save on a new or just loaded route still made the points' text (~28 ms, a torn frame at the first autosave).
# warm() makes it on a worker thread as soon as the route is there; the points are never changed after the route is built.
var warm_task = -1
var warm_points = null
var warm_box = {}

static func points_ok(points: Array) -> bool:   # the same check as Model.validate_save makes of every point
	var previous_s = -INF
	for point in points:
		if not point is Array or point.size() != 3: return false
		for coordinate in point:
			if not ((coordinate is int or coordinate is float) and is_finite(float(coordinate))): return false
		if float(point[2]) <= previous_s: return false
		previous_s = float(point[2])
	return true

func cached(points) -> bool:
	return is_same(points, points_ref) and points.size() == points_size

func collect_warm(wait: bool) -> void:
	if warm_task == -1: return
	if not wait and not WorkerThreadPool.is_task_completed(warm_task): return
	WorkerThreadPool.wait_for_task_completion(warm_task)
	warm_task = -1
	if bool(warm_box.get("ok", false)) and warm_points.size() == int(warm_box.size):
		points_ref = warm_points
		points_size = int(warm_box.size)
		points_text = str(warm_box.text)
	warm_points = null

# Called every frame by main.gd: cheap when the text is ready.
func warm(model) -> void:
	collect_warm(false)
	if model == null or model.route == null or warm_task != -1: return
	var points: Array = model.route.points
	if points.is_empty() or cached(points): return
	var box = {"size": points.size()}
	warm_box = box
	warm_points = points
	warm_task = WorkerThreadPool.add_task(func():
		box.text = JSON.stringify(points)
		box.ok = points_ok(points))

# The whole text of a save, or "" when the model's state does not pass the check of a save.
func save_text(model) -> String:
	var data = model.serialize()
	var route = data.route.duplicate()
	var points = route.points
	route.points = POINTS_MARK
	data.route = route
	var text = JSON.stringify(data)
	var parsed = JSON.parse_string(text)   # small without the points: the check sees what a later read will see
	if not parsed is Dictionary or not text.contains('"' + POINTS_MARK + '"'): return ""
	if is_same(points, warm_points): collect_warm(true)
	if not cached(points):
		if not points_ok(points): return ""
		points_text = JSON.stringify(points)
		points_ref = points
		points_size = points.size()
	parsed.route.points = points   # these very points passed points_ok when their text was made
	if validator == null: validator = Model.new()
	if not validator.validate_save(parsed, true): return ""
	return text.replace('"' + POINTS_MARK + '"', points_text)

func disk_mark(name: String) -> Array:
	if not FileAccess.file_exists(path(name)): return []
	return [FileAccess.get_size(path(name)), FileAccess.get_modified_time(path(name))]   # no open: opening a fresh file waits ~10 ms

# Writes the text through a temp file and reads it back; true when the disk holds exactly the text.
func store_checked(name: String, text: String) -> bool:
	var temp = FileAccess.open(path(name), FileAccess.WRITE)
	if temp == null: return false
	temp.store_string(text)
	temp.flush()
	var write_error = temp.get_error()
	var size = temp.get_length()
	temp.close()
	# reading the file back cost ~10 ms (opening a just-written file waits for the disk and the antivirus): the write error
	# and the written size are checked instead
	return write_error == OK and size >= text.length()

func write(model, preserve_backup: bool = false) -> bool:
	error = ""
	var text = save_text(model)
	if text == "":
		error = "Проверка нового сохранения не пройдена"
		return false
	if not store_checked("save_v2.tmp", text):
		error = "Не удалось записать сохранение. Проверь свободное место и доступ к папке."
		return false
	if not preserve_backup:
		var known = written.get(directory, [])
		var good = not known.is_empty() and disk_mark("save_v2.json") == known
		if good or not read_valid("save_v2.json").is_empty():
			if DirAccess.copy_absolute(path("save_v2.json"), path("save_v2.backup.json")) != OK:
				error = "Не удалось сохранить резервную копию"
				return false
	if DirAccess.rename_absolute(path("save_v2.tmp"), path("save_v2.json")) != OK:
		error = "Не удалось заменить файл сохранения"
		return false
	written[directory] = disk_mark("save_v2.json")
	return true

# ui-v2 (owner 14.11): three manual slots besides the current game. A slot is written whole through a temp file and checked.
const SLOTS = 3

func slot_name(n: int) -> String:
	return "save_slot_%d.json" % n

func write_slot(model, n: int) -> bool:
	error = ""
	var temp_name = "save_slot_%d.tmp" % n
	var text = save_text(model)
	if text == "" or not store_checked(temp_name, text):
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
