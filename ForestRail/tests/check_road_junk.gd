extends Node
# Веха 6, В6.11 этап «б»: источники болтов в рейсе (docs/KAZIK_ECONOMY_RU.md). Журнал рейса, выпадение хлама пути
# и машины по условиям, редкий шлак, блики у рельса, итог «Принесли с дороги», сохранение.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	Model.legacy_tanks = true
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh(seed_value: int = 42, vehicle: String = ""):
	var m = Model.new()
	m.new_game(seed_value, 2)
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	m.state.money = 5000
	if vehicle != "": Fixtures.equip(m, vehicle)
	return m

# Takes a free order, loads, leaves; the caller can change the log of the trip before the train comes home.
func leave(m, night: bool = false) -> void:
	var mission = m.free_offers()[0]
	check(m.accept_mission(mission), "the order is accepted (%s)" % m.message)
	for i in range(mini(m.state.cargo.size(), m.slots().size())): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	if night: m.state.stats.seconds = 18.0 * 60.0
	check(m.depart(), "the train leaves (%s)" % m.message)

# The train comes home after `fraction` of the time budget; returns the finds of the trip.
func come_home(m, fraction: float = 1.0) -> Array:
	for item in m.state.cargo: item.delivered = true
	m.evaluate_delivery()
	m.state.stats.seconds = float(m.state.stats.seconds) + float(m.state.active.budget_s) * fraction
	m.state.s = float(m.route.station_s[0])
	m.state.v = 0.0
	m.state.brake = 1.0
	m.state.active.pending_reward = int(m.state.active.reward)
	check(m.settle(), "the order is settled")
	return m.state.last_result.finds

func count_of(finds: Array, id: String) -> int:
	for entry in finds:
		if str(entry.id) == id: return int(entry.count)
	return 0

func run() -> void:
	Model.order_rules = true
	Model.junk_rules = true
	Model.wear_rules = true
	# --- the log starts with the first departure and lays the glints
	var a = fresh()
	check(not a.casino().has_trip(), "no order, no log")
	leave(a)
	var t = a.casino().trip()
	check(a.casino().has_trip() and t.glints.size() >= 1 and t.glints.size() <= 2, "the log of the trip has one or two glints (%d)" % t.glints.size())
	var inside = true
	for g in t.glints: inside = inside and float(g.s) >= 300.0 and float(g.s) <= float(a.route.length_m) - 300.0
	check(inside, "and they lie along the line, away from its ends")
	var a2 = fresh()
	leave(a2)
	check(str(a2.casino().trip().glints) == str(t.glints), "the same career and the same order lay the same glints")
	# --- rules off: nothing is logged, nothing falls
	Model.junk_rules = false
	var off = fresh()
	leave(off)
	check(not off.casino().has_trip(), "with the rules off there is no log")
	check(come_home(off).is_empty(), "and no finds")
	Model.junk_rules = true
	var creative = Model.new()
	creative.new_game(42, 2, "creative")
	creative.state.money = 1000000
	check(creative.accept_mission(creative.free_offers()[0]), "creative takes an order")
	for i in range(mini(creative.state.cargo.size(), creative.slots().size())): creative.transfer(creative.state.cargo[i].id, creative.slots()[i].key)
	creative.depart()
	check(not creative.casino().has_trip(), "the creative mode keeps no log")
	# --- the road: a bolt for every few hundred metres, the steep places, a heavy load, hard stops, the switches
	var b = fresh()
	leave(b)
	b.state.stats.distance = float(b.state.active.trip.dist0) + 13600.0
	b.state.active.trip.steep_m = 560.0
	b.state.active.trip.cargo_kg = 700.0
	b.state.active.trip.skids = 5
	b.state.active.trip.visited = ["A", "B", "D", "F"]
	var finds = come_home(b, 1.0)
	var rusty = count_of(finds, "rusty_bolt")
	check(rusty >= 6 and rusty <= 8, "13.6 km give six to eight rusty bolts (%d)" % rusty)
	var plates = count_of(finds, "tie_plate")
	check(plates >= 2 and plates <= 3, "560 m of steep line give two or three base plates (%d)" % plates)
	check(count_of(finds, "fishplate") == 2, "a load of 700 kg gives two fishplates (%d)" % count_of(finds, "fishplate"))
	check(count_of(finds, "brake_shoe") == 3, "hard stops give brake shoes, at most three (%d)" % count_of(finds, "brake_shoe"))
	check(count_of(finds, "rail_clip") == 2, "standing at the switches D and F gives two clips (%d)" % count_of(finds, "rail_clip"))
	check(count_of(finds, "bearing_cover") == 1, "a trip within 5%% of the time brings a bearing cover")
	check(b.casino().junk_count("rusty_bolt") == rusty and b.casino().junk_count("fishplate") == 2, "everything went into the bag")
	check(int(b.state.last_result.finds.size()) >= 5 and str(b.state.last_result.finds[0].name) != "", "the result lists the finds with their names")
	# a light, calm trip brings little
	var c = fresh()
	leave(c)
	c.state.stats.distance = float(c.state.active.trip.dist0) + 600.0
	c.state.active.trip.cargo_kg = 100.0
	var calm = come_home(c, 0.6)
	check(count_of(calm, "fishplate") == 0 and count_of(calm, "brake_shoe") == 0 and count_of(calm, "rail_clip") == 0 and count_of(calm, "tie_plate") == 0, "a short light calm trip brings no heavy, brake, switch or steep finds")
	check(count_of(calm, "bearing_cover") == 0, "and being early, no bearing cover")
	check(count_of(calm, "rusty_bolt") <= 1, "just a rusty bolt now and then (%d)" % count_of(calm, "rusty_bolt"))
	# a late trip still brings the common bolts but not the premium ones
	var d = fresh()
	leave(d)
	d.state.stats.distance = float(d.state.active.trip.dist0) + 9000.0
	var late = come_home(d, 1.3)
	check(d.state.last_result.late and count_of(late, "rusty_bolt") >= 3 and count_of(late, "bearing_cover") == 0, "a late trip brings the bolts of the road, not the premium ones")
	# --- the machine's own parts: by distance (hand cars) or by what hurt it
	var h = fresh(42, "handcar")
	leave(h)
	h.state.stats.distance = float(h.state.active.trip.dist0) + 4000.0
	check(count_of(come_home(h), "lever_bolt") == 3, "a hand car loses a lever bolt every 1.3 km (four km, three bolts)")
	var mc = fresh(42, "motorcar")
	leave(mc)
	check(count_of(come_home(mc), "spark_plug") == 0, "a calm petrol car keeps its plugs")
	var hot = fresh(42, "motorcar")
	leave(hot)
	hot.wear().damage("motorcar", "engine", 0.04, "перегрев")
	hot.wear().damage("W01", "wheels", 0.5, "тест")
	check(is_equal_approx(float(hot.casino().trip().damage), 0.04), "the damage of the machine is logged, that of the wagons is not (%.3f)" % float(hot.casino().trip().damage))
	check(count_of(come_home(hot), "spark_plug") == 1, "0.04 of damage shakes one plug loose")
	var wrecked = fresh(42, "motorcar")
	leave(wrecked)
	wrecked.wear().damage("motorcar", "engine", 0.3, "перегрев")
	check(count_of(come_home(wrecked), "spark_plug") == 4, "a very hard trip is capped at four")
	var sail = fresh(42, "sail")
	leave(sail)
	sail.wear().damage("sail", "rigging", 0.08, "порыв сорвал шкот")
	check(count_of(come_home(sail), "sail_block") == 3, "a gust that tears the sheet gives three blocks")
	# --- the rare things
	var lanterns = 0
	for seed_value in range(1, 41):
		var n = fresh(seed_value)
		leave(n, true)
		if count_of(come_home(n, 0.6), "cracked_lantern") > 0: lanterns += 1
	check(lanterns >= 5 and lanterns <= 25, "a night trip may bring a cracked lantern, about a third (%d of 40)" % lanterns)
	var day = fresh()
	leave(day)
	check(count_of(come_home(day, 1.0), "cracked_lantern") == 0 and count_of(day.state.last_result.finds, "stationmaster_watch") == 0, "no lantern by day, no watch without a streak")
	var streak = fresh()
	streak.casino().st().streak = 3
	leave(streak)
	check(count_of(come_home(streak, 1.0), "stationmaster_watch") == 1, "an exact trip on the streak of three brings the stationmaster's watch")
	# --- the glints by the rail
	var g = fresh()
	leave(g)
	var glint = g.casino().glints()[0]
	g.state.s = float(glint.s) + 400.0
	g.state.v = 0.0
	check(g.casino().glint_pickable(0) == "Далеко от состава", "a glint far from the train cannot be picked")
	g.state.s = float(glint.s) + 3.0
	g.state.v = 12.0
	check(g.casino().glint_pickable(0) == "Слишком быстро, чтобы нагнуться", "nor at speed")
	g.state.v = 2.0
	check(g.casino().glint_pickable(0) == "", "near the train and slow it can be picked")
	var before = g.casino().junk_count("track_spike") + g.casino().junk_count("golden_bolt")
	var got = g.casino().pick_glint(0)
	check(got in ["track_spike", "golden_bolt"] and g.casino().junk_count(got) >= 1 and g.casino().junk_count("track_spike") + g.casino().junk_count("golden_bolt") == before + 1, "the pick lands in the bag (%s)" % got)
	check("glint" in g.events and g.message.begins_with("Нашёл у рельса"), "with a sound and a line")
	check(g.casino().pick_glint(0) == "" and g.casino().glint_pickable(0) == "Здесь уже пусто", "and only once")
	g.state.stats.distance = float(g.state.active.trip.dist0) + 2000.0
	var with_glint = come_home(g, 1.0)
	check(count_of(with_glint, got) >= 1, "the glint is in the list of the finds at the end")
	var golds = 0
	var seen = 0
	for seed_value in range(1, 201):
		var s = fresh(seed_value)
		leave(s)
		for glint_entry in s.casino().glints():
			seen += 1
			if bool(glint_entry.golden): golds += 1
	check(seen >= 300 and golds >= 15 and golds <= 60, "about nine in a hundred glints are golden (%d of %d)" % [golds, seen])
	# --- saving in the middle of a trip
	var keep = fresh()
	leave(keep)
	keep.casino().trip().skids = 2
	var loaded = Model.new()
	check(loaded.restore(keep.serialize()) and loaded.casino().has_trip() and int(loaded.casino().trip().skids) == 2 and loaded.casino().glints().size() == keep.casino().glints().size(), "the log of the trip is saved with the game")
	Model.order_rules = false
	Model.junk_rules = false
	Model.wear_rules = false
	print("ROAD JUNK CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
