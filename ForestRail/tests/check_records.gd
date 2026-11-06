extends Node
# В6.6д: режим рекордов (scripts/records.gd и model.track_records): заезд от первой станции до последней и обратно считается с последней остановки,
# лучшее время запоминается по машинам, высшая скорость тоже, телепорт помощью депо не заезд, вкладка открыта в творческом всегда, в карьере после финала.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Records = preload("res://scripts/records.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func run() -> void:
	# --- the pure watcher
	var table = {}
	var r = Records.new()
	var news = r.tick(table, "steam", 0.0, 0, 5, 0.0, true)
	check(news.is_empty() and r.from_station == 0 and not r.running, "standing at the first station: the run is ready")
	news = r.tick(table, "steam", 10.0, 0, 5, 0.0, true)
	r.tick(table, "steam", 12.0, 0, 5, 4.0, true)
	check(r.running, "the train moves: the run goes")
	r.tick(table, "steam", 60.0, 2, 5, 20.0, true)
	check(is_equal_approx(float(table.steam.top_kmh), 72.0), "the top speed is kept (72 km/h)")
	news = r.tick(table, "steam", 150.0, 5, 5, 0.0, true)
	check(news.size() == 1 and news[0].kind == "a_f" and news[0].best and is_equal_approx(float(news[0].seconds), 140.0), "stopped at the last station: A to F took 140 s from the last moment of standing (%s)" % str(news))
	check(is_equal_approx(float(table.steam.a_f), 140.0), "and it is the record")
	# the way back, slower: not a record
	r.tick(table, "steam", 200.0, 5, 5, 3.0, true)
	news = r.tick(table, "steam", 400.0, 0, 5, 0.0, true)
	check(news.size() == 1 and news[0].kind == "f_a" and news[0].best, "the way back is its own record")
	# a second A to F, slower
	r.tick(table, "steam", 410.0, 0, 5, 5.0, true)
	news = r.tick(table, "steam", 650.0, 5, 5, 0.0, true)
	check(news.size() == 1 and not news[0].best and is_equal_approx(float(table.steam.a_f), 140.0), "a slower run is not a record and does not replace it")
	# a faster one
	r.tick(table, "steam", 700.0, 5, 5, 5.0, true)
	r.tick(table, "steam", 800.0, 0, 5, 0.0, true)
	r.tick(table, "steam", 810.0, 0, 5, 5.0, true)
	news = r.tick(table, "steam", 900.0, 5, 5, 0.0, true)
	check(news.size() == 1 and news[0].best and is_equal_approx(float(table.steam.a_f), 100.0), "a faster run takes the record (100 s)")
	# turning back at the first station is no run; a stop in the middle is only a stop
	var t2 = {}
	var r2 = Records.new()
	r2.tick(t2, "motorcar", 0.0, 0, 5, 0.0, true)
	r2.tick(t2, "motorcar", 5.0, 0, 5, 3.0, true)
	r2.tick(t2, "motorcar", 40.0, 2, 5, 0.0, true)   # stopped at a middle station
	r2.tick(t2, "motorcar", 45.0, 2, 5, 3.0, true)
	news = r2.tick(t2, "motorcar", 80.0, 0, 5, 0.0, true)
	check(news.is_empty(), "back to the same station: no run")
	# not on the route (the depot, help): the run is dropped, a teleport is not a run
	r2.tick(t2, "motorcar", 90.0, 0, 5, 3.0, true)
	r2.tick(t2, "motorcar", 95.0, 3, 5, 3.0, false)
	check(r2.from_station == -1 and not r2.running, "leaving the route drops the run")
	news = r2.tick(t2, "motorcar", 96.0, 5, 5, 0.0, true)
	check(news.is_empty(), "arriving at the far end by a teleport is not a run")
	check(Records.time_text(134.6) == "2:14.6" and Records.time_text(0.0) == "—" and Records.time_text(59.99) == "0:59.9", "the time text is minutes:seconds.tenths")

	# --- the model
	var m = Model.new()
	m.new_game(42, 2)
	Fixtures.equip(m, "steam")
	m.state.phase = "route"
	m.state.s = float(m.route.station_s[0])
	m.state.v = 0.0
	m.state.brake = 1.0
	m.physics_step(0.05)
	check(m.records.from_station == 0, "the physics step watches the train (the first station is the start)")
	var last = m.data.stations.size() - 1
	m.records.reset()
	m.state.stats.seconds = 100.0
	m.state.s = float(m.route.station_s[0])
	m.state.v = 0.0
	m.track_records()
	m.state.stats.seconds = 101.0
	m.state.v = 6.0
	m.track_records()
	m.state.stats.seconds = 300.0
	m.state.s = float(m.route.station_s[last])
	m.state.v = 0.0
	m.events.clear()
	m.track_records()
	var rows = m.record_rows()
	var steam_row = {}
	for row in rows:
		if row.id == "steam": steam_row = row
	check(is_equal_approx(float(steam_row.get("a_f", 0.0)), 200.0) and "record" in m.events and "Рекорд" in m.last_record_text, "the model keeps the record and says so (%s)" % m.last_record_text)
	check(rows.size() == Model.VEHICLE_IDS.size(), "the table has a row for every machine")
	# the table lives in the save
	var saved = JSON.parse_string(JSON.stringify(m.state))
	check(saved.records.steam.a_f == 200.0, "the table is in the saved state")

	# --- a real trip by the physics: A to F and back by the electric locomotive records both ways
	var drive = Model.new()
	drive.new_game(42, 2, "creative")
	Fixtures.equip(drive, "locomotive")
	var result = preload("res://tests/trip_driver.gd").round_trip(drive, "F", 1)
	check(result.get("ok", false), "the round trip is driven (%s)" % str(result))
	var loco_row = {}
	for row in drive.record_rows():
		if row.id == "locomotive": loco_row = row
	check(float(loco_row.get("a_f", 0.0)) > 30.0 and float(loco_row.get("f_a", 0.0)) > 30.0, "the real trip leaves both records (%s)" % str(loco_row))
	check(float(loco_row.get("top_kmh", 0.0)) > 20.0, "and the top speed (%s)" % str(loco_row.get("top_kmh", 0.0)))

	# --- who may see the tab
	var career = Model.new()
	career.new_game(7, 2)
	check(not career.records_open(), "in the career the tab is closed before the finale")
	career.state.finale = true
	check(career.records_open(), "and open after the finale")
	var creative = Model.new()
	creative.new_game(7, 2, "creative")
	check(creative.records_open(), "in the creative mode it is always open")

	print("RECORDS CHECKS %d; FAILURES %s" % [checks, str(failures)])
	get_tree().quit(1 if not failures.is_empty() else 0)
