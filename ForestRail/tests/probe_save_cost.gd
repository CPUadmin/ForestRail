extends Node
# Замер для шага 1.3.9: из чего складывается сохранение при выезде (кадр со щелчком «Отправиться»).
# Не тест с галочкой. Запуск: godot --path ForestRail -- --qa-suite=probe_save_cost
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Saves = preload("res://scripts/save_game.gd")

var game

func _ready() -> void:
	call_deferred("run")

func ms(t0: int) -> float:
	return float(Time.get_ticks_usec() - t0) / 1000.0

func run() -> void:
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 500000
	m.state.chapter = 9
	Fixtures.equip(m, "locomotive")
	var saves = Saves.new()
	saves.directory = "user://qa_probe_save"
	DirAccess.make_dir_recursive_absolute(saves.directory)
	saves.write(m)   # a save already on disk, as in a real game
	for round in range(3):
		var t = Time.get_ticks_usec()
		var data = m.serialize()
		var a = ms(t); t = Time.get_ticks_usec()
		var text = JSON.stringify(data)
		var b = ms(t); t = Time.get_ticks_usec()
		var f = FileAccess.open(saves.path("probe.tmp"), FileAccess.WRITE)
		f.store_string(text); f.flush(); f.close()
		var c = ms(t); t = Time.get_ticks_usec()
		var parser = JSON.new(); parser.parse(FileAccess.get_file_as_string(saves.path("probe.tmp")))
		var d = ms(t); t = Time.get_ticks_usec()
		var v = Model.new()
		var e0 = ms(t); t = Time.get_ticks_usec()
		v.validate_save(parser.data)
		var e = ms(t); t = Time.get_ticks_usec()
		var txt = saves.save_text(m)
		var st = ms(t); t = Time.get_ticks_usec()
		saves.store_checked("probe2.tmp", txt)
		var sc = ms(t); t = Time.get_ticks_usec()
		saves.write(m)
		var w = ms(t)
		print("   save_text %.1f  store_checked %.1f" % [st, sc])
		print("SAVE size %d KB  serialize %.1f  stringify %.1f  store %.1f  parse %.1f  Model.new %.1f  validate %.1f  | whole write %.1f ms" % [text.length() / 1024, a, b, c, d, e0, e, w])
	get_tree().quit(0)
