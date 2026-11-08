extends Node
# Веха 5, В5.6: износ и повреждения узлов (docs/DAMAGE_RU.md). Состояние узла 0..1, эффекты на цифры машины,
# причины повреждений, поломка на ходу, ремонт болтами, деньгами, ремнаборами, на станции и в депо.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh(id: String = "motorcar", seed_value: int = 42):
	Model.wear_rules = true
	var m = Model.new()
	m.new_game(seed_value, 2)
	m.state.money = 100000
	Fixtures.equip(m, id)
	m.state.phase = "route"
	m.state.s = 400.0
	m.state.direction = 1
	m.state.reverser = 1
	m.state.brake = 0.0
	m.state.throttle = 0.0
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	return m

func approx(a: float, b: float, tolerance: float = 0.0005) -> bool:
	return absf(a - b) <= tolerance

func run() -> void:
	# --- the nodes of every machine and of the wagon
	var m = fresh()
	for id in ["handcar", "pole", "sail", "steam", "motorcar", "pneumatic", "locomotive", "W01"]:
		var nodes = m.wear().nodes_of(id)
		check(nodes.size() >= 3, "%s has its nodes (%d)" % [id, nodes.size()])
		var valid = true
		for def in nodes: valid = valid and str(def.effect) in ["brake", "roll", "power", "capacity", "rig", "shock"] and float(def.floor) > 0.0 and float(def.per_km) > 0.0
		check(valid, "%s: every node has a known effect, a floor and a wear per km" % id)
	check(m.wear().nodes_of("steam").size() == 5 and m.wear().nodes_of("W01").size() == 3, "the steam engine has five nodes, a wagon three")
	check(m.wear().condition("motorcar", "engine") == 1.0 and m.wear().factor("motorcar", "power") == 1.0, "a new machine is new")
	check(m.wear().worst("motorcar").cond == 1.0 and not m.wear().warning(), "no lamp on a new machine")
	# the numbers of a new machine are the old numbers
	var plain = Model.new()
	Model.wear_rules = false
	plain.new_game(42, 2)
	plain.state.money = 100000
	Fixtures.equip(plain, "motorcar")
	Model.wear_rules = true
	check(str(plain.object_stats("motorcar")) == str(m.object_stats("motorcar")), "a new machine has exactly the old stats")
	# --- wear from the road
	m.wear().wear_road(1000.0)
	check(approx(m.wear().condition("motorcar", "bearings"), 1.0 - 0.0020) and approx(m.wear().condition("motorcar", "engine"), 1.0 - 0.0020), "a kilometre wears the bearings and the engine by their share (%.4f)" % m.wear().condition("motorcar", "bearings"))
	check(approx(m.wear().condition("W01", "wheels"), 1.0 - 0.0020), "and the wheels of the wagons")
	var rainy = fresh()
	rainy.weather_force = {"cloud": 1.0, "rain": 1.0, "fog": 0.0}
	rainy.wear().wear_road(1000.0)
	check(rainy.wear().condition("motorcar", "bearings") < m.wear().condition("motorcar", "bearings") and approx(rainy.wear().condition("motorcar", "engine"), m.wear().condition("motorcar", "engine")), "rain wears the bearings and the brake faster, not the engine")
	var driven = fresh("locomotive")
	driven.state.throttle = 1.0
	for i in range(60 * 20): driven.physics_step(1.0 / 60.0)
	check(driven.wear().condition("locomotive", "bearings") < 1.0 and driven.wear().condition("locomotive", "motor") < 1.0, "driving wears the nodes")
	var off = fresh("locomotive")
	Model.wear_rules = false
	off.state.throttle = 1.0
	for i in range(60 * 5): off.physics_step(1.0 / 60.0)
	Model.wear_rules = true
	check(not off.object_state("locomotive").has("wear"), "with the wear rules off nothing wears")
	# --- the effects of the worn nodes on the numbers
	var e = fresh("locomotive")
	var base = e.object_stats("locomotive")
	var base_wagon = e.object_stats("W01")
	e.wear().set_condition("locomotive", "brake", 0.5)
	check(approx(float(e.object_stats("locomotive").brake), float(base.brake) * 0.8, 0.5), "a brake at 50%% holds 80%% (%.0f of %.0f)" % [e.object_stats("locomotive").brake, base.brake])
	e.wear().set_condition("locomotive", "motor", 0.5)
	check(approx(float(e.object_stats("locomotive").traction[0]), float(base.traction[0]) * 0.8, 0.5), "a motor at 50%% pulls 80%% (%.0f)" % e.object_stats("locomotive").traction[0])
	e.wear().set_condition("locomotive", "bearings", 0.5)
	check(approx(float(e.object_stats("locomotive").rolling), float(base.rolling) * 1.3, 0.00001), "bearings at 50%% roll 30%% harder (%.5f)" % e.object_stats("locomotive").rolling)
	e.wear().set_condition("locomotive", "battery", 0.0)
	check(approx(float(e.object_stats("locomotive").tank), float(base.tank) * 0.7, 0.001), "a dead battery holds 70%% of the charge (%.2f)" % e.object_stats("locomotive").tank)
	e.wear().set_condition("W01", "coupler", 0.0)
	e.wear().set_condition("W01", "suspension", 0.0)
	check(float(e.object_stats("W01").shock) > float(base_wagon.shock) * 1.5, "a wagon with a bad coupler and springs shakes the cargo harder (%.2f)" % e.object_stats("W01").shock)
	check(e.wear().warning() and e.wear().train_worst().cond == 0.0, "the lamp lights when a node is below 40%")
	# --- damage from mistakes
	var d = fresh()
	d.wear_skid(25.0)
	check(approx(d.wear().condition("motorcar", "brake"), 1.0 - 0.08), "a locked wheel at speed takes 8%% of the brake (%.3f)" % d.wear().condition("motorcar", "brake"))
	var land = fresh()
	land.wear_landing(4.0)
	check(approx(land.wear().condition("W01", "suspension"), 1.0 - 0.09) and land.wear().condition("motorcar", "bearings") < 1.0, "a landing hurts the springs of the wagons (%.3f)" % land.wear().condition("W01", "suspension"))
	var soft = fresh()
	soft.landing_impact(0.8)
	check(soft.wear().condition("W01", "suspension") == 1.0, "a soft landing hurts nothing")
	var buffer = fresh()
	buffer.buffer_impact(3.0)
	check(approx(buffer.wear().condition("W01", "coupler"), 1.0 - 0.11), "a knock on the buffer at 3 m/s takes 11%% of the couplers (%.3f)" % buffer.wear().condition("W01", "coupler"))
	var slow = fresh()
	slow.buffer_impact(0.8)
	check(slow.wear().condition("W01", "coupler") == 1.0, "a gentle touch does not")
	var hot = fresh()
	hot.state.fleet_by_id.motorcar.temp = 1.0
	for i in range(120): hot.thermal_step(1.0 / 60.0, hot.state.fleet_by_id.motorcar)
	check(hot.wear().condition("motorcar", "engine") < 0.99, "an engine at the limit of heat wears (%.4f)" % hot.wear().condition("motorcar", "engine"))
	var cool = fresh()
	cool.state.fleet_by_id.motorcar.temp = 0.5
	for i in range(120): cool.thermal_step(1.0 / 60.0, cool.state.fleet_by_id.motorcar)
	check(cool.wear().condition("motorcar", "engine") == 1.0, "a cool one does not")
	var dry = fresh("steam")
	Fixtures.fire_up(dry)
	dry.state.fleet_by_id.steam.water = 0.0
	dry.state.phase = "route"
	for i in range(30): dry.steam_step(1.0 / 60.0, dry.state.fleet_by_id.steam)
	check(approx(dry.wear().condition("steam", "boiler"), 0.95), "a boiler without water is hurt once (%.3f)" % dry.wear().condition("steam", "boiler"))
	# --- breakdown
	var counts = [0, 0, 0]
	for k in range(3):
		var level = [0.1, 0.5, 0.0][k]
		for seed_value in range(1, 41):
			var b = fresh("motorcar", seed_value)
			b.wear().set_condition("motorcar", "engine", level)
			b.state.v = 6.0
			b.state.throttle = 0.5
			for i in range(60 * 60): b.wear().breakdown_step(1.0 / 60.0); b.state.stats.seconds += 1.0 / 60.0
			if b.wear().broken("motorcar") != "": counts[k] += 1
	check(counts[0] >= 1 and counts[0] <= 5, "a node at 10%% fails in about 3%% of the minutes: %d of 40 runs" % counts[0])
	check(counts[1] == 0, "a node at 50%% never fails")
	var g = fresh("locomotive")
	g.wear().set_condition("locomotive", "motor", 0.0)
	g.state.throttle = 1.0
	for i in range(120): g.physics_step(1.0 / 60.0)
	check(float(g.state.v) < 0.05, "a dead motor does not pull (%.3f m/s)" % float(g.state.v))
	# --- repair with bolts
	var r = fresh("motorcar")
	r.wear().set_condition("motorcar", "engine", 0.5)
	r.casino().junk_add("rusty_bolt", 10)
	check(approx(r.wear().repair_with_bolts("motorcar", "engine", "rusty_bolt", 5), 0.10), "five common bolts give +10%%")
	check(r.casino().junk_count("rusty_bolt") == 5, "and cost five bolts")
	r.casino().junk_add("spark_plug", 5)
	check(approx(r.wear().repair_with_bolts("motorcar", "engine", "spark_plug", 2), 0.10), "two spark plugs of the own machine give +10%%")
	check(r.wear().repair_with_bolts("motorcar", "engine", "brush", 1) == 0.0, "the brush of another machine mends nothing")
	r.casino().junk_add("golden_bolt", 1)
	check(approx(r.wear().repair_with_bolts("motorcar", "engine", "golden_bolt", 1), 0.04), "a rare find gives +4%%")
	check(approx(r.wear().condition("motorcar", "engine"), 0.5 + 0.10 + 0.10 + 0.04), "the engine now (%.2f)" % r.wear().condition("motorcar", "engine"))
	r.wear().set_condition("motorcar", "engine", 0.98)
	r.wear().repair_with_bolts("motorcar", "engine", "rusty_bolt", 5)
	check(r.wear().condition("motorcar", "engine") == 1.0 and r.casino().junk_count("rusty_bolt") == 4, "only as many bolts as it needs are spent (%d left)" % r.casino().junk_count("rusty_bolt"))
	# money
	var money = fresh("motorcar")
	money.wear().set_condition("motorcar", "brake", 0.4)
	var before = int(money.state.money)
	var mended = money.wear().repair_with_money("motorcar", "brake", 0.2)
	check(approx(mended, 0.2) and before - int(money.state.money) == 60, "20%% of a node costs 60 coins (%d)" % (before - int(money.state.money)))
	money.state.money = 30
	var partial = money.wear().repair_with_money("motorcar", "brake", 0.3)
	check(approx(partial, 0.1) and int(money.state.money) == 0, "with 30 coins one mends 10%% (%.2f)" % partial)
	# the kit
	var kit = fresh("motorcar")
	kit.wear().set_condition("motorcar", "gearbox", 0.3)
	check(kit.wear().repair_with_kit("motorcar", "gearbox") == 0.0, "no kit, no repair")
	kit.casino().st().repair_kits = 1
	check(approx(kit.wear().repair_with_kit("motorcar", "gearbox"), 0.25) and kit.casino().st().repair_kits == 0, "a repair kit gives +25%")
	# the line: only a station with a workshop and only up to 50%
	var line = fresh("motorcar")
	line.wear().set_condition("motorcar", "engine", 0.1)
	line.state.s = line.route.station_s[2]
	line.state.v = 0.0
	line.state.brake = 1.0
	check(not line.wear().emergency_possible(), "no workshop at a way station")
	line.state.s = line.route.station_s[0]
	check(line.wear().emergency_possible(), "the home station has one")
	var got = line.wear().emergency_repair("motorcar", "engine")
	check(approx(got, 0.4) and approx(line.wear().condition("motorcar", "engine"), 0.5), "it mends only up to 50%% (%.2f)" % line.wear().condition("motorcar", "engine"))
	check(line.wear().emergency_repair("motorcar", "engine") == 0.0, "and no further")
	# the depot patches up the worst for nothing; a breakdown is cleared
	var depot = fresh("motorcar")
	depot.wear().set_condition("motorcar", "engine", 0.05)
	depot.wear().set_condition("motorcar", "brake", 0.5)
	depot.object_state("motorcar").broken = "engine"
	depot.wear().free_touch_up()
	check(approx(depot.wear().condition("motorcar", "engine"), 0.2) and approx(depot.wear().condition("motorcar", "brake"), 0.5), "the depot lifts a node to 20%% and leaves the others (%.2f)" % depot.wear().condition("motorcar", "engine"))
	check(depot.wear().broken("motorcar") == "" and not depot.wear().cannot_drive("motorcar"), "and the machine goes again")
	check(depot.wear().full_repair_price("motorcar") > 0, "the full repair has a price (%d)" % depot.wear().full_repair_price("motorcar"))
	# --- saving
	var keep = fresh("motorcar")
	keep.wear().set_condition("motorcar", "engine", 0.37)
	keep.wear().set_condition("W01", "wheels", 0.61)
	var loaded = Model.new()
	check(loaded.restore(keep.serialize()) and approx(loaded.wear().condition("motorcar", "engine"), 0.37) and approx(loaded.wear().condition("W01", "wheels"), 0.61), "the state of the nodes is saved with the game")
	var old = fresh("motorcar").serialize()
	for id in old.fleet_by_id: old.fleet_by_id[id].erase("wear")
	var back = Model.new()
	check(back.restore(old) and back.wear().condition("motorcar", "engine") == 1.0, "an old save has every node at 100%")
	# the journal of the trip: the cause, the node and the percent; the same cause adds up; five at most; a new trip clears it
	Model.wear_rules = true
	var jm = Model.new()
	jm.new_game(42, 2)
	jm.wear().damage("handcar", "brake", 0.03, "юз")
	jm.wear().damage("handcar", "brake", 0.04, "юз")
	check(jm.wear().journal.size() == 1 and jm.wear().journal_lines()[0].begins_with("Юз: ") and jm.wear().journal_lines()[0].ends_with("−7%"), "the journal adds up the same cause (%s)" % str(jm.wear().journal_lines()))
	for k in range(8): jm.wear().damage("handcar", "bearings", 0.01, "причина %d" % k)
	check(jm.wear().journal.size() == 5 and jm.wear().journal_lines()[0].begins_with("Причина 7"), "five lines at most, the newest first")
	jm.wear().journal.clear()
	check(jm.wear().journal_lines().is_empty(), "the journal can be cleared")
	# the help of the depot: a quarter of the reward (50..600), the rest goes into a debt that the next reward pays, the pull nodes become new
	Model.wear_rules = true
	var rm = Model.new()
	rm.new_game(42, 2)
	rm.state.money = 1000
	rm.state.active = {"reward": 100}
	check(rm.rescue_fee() == 50, "a small order: the fee is the minimum 50 (%d)" % rm.rescue_fee())
	rm.state.active = {"reward": 800}
	check(rm.rescue_fee() == 200, "a quarter of 800 is 200 (%d)" % rm.rescue_fee())
	rm.state.active = {"reward": 9000}
	check(rm.rescue_fee() == 600, "and never more than 600 (%d)" % rm.rescue_fee())
	rm.state.active = {}
	check(rm.rescue_fee() == 50, "no order: the minimum")
	rm.wear().set_condition("handcar", "lever", 0.1)
	rm.wear().set_condition("handcar", "bearings", 0.1)
	rm.state.money = 30
	rm.rescue()
	check(int(rm.state.money) == 0 and int(rm.state.get("debt", 0)) == 20, "30 coins in the purse pay part of the fee, 20 become a debt (money %d, debt %d)" % [int(rm.state.money), int(rm.state.get("debt", 0))])
	check(rm.wear().condition("handcar", "lever") == 1.0, "the pull node is as new after the help")
	check(rm.wear().condition("handcar", "bearings") < 0.5, "the bearings only get the small touch-up")
	var crm = Model.new()
	crm.new_game(42, 2, "creative")
	check(crm.rescue_fee() == 0, "in the creative mode the help is free")
	Model.wear_rules = false
	var no_rules = Model.new()
	no_rules.new_game(42, 2)
	check(no_rules.rescue_fee() == 0, "the old tests (wear rules off) keep the free tow")
	Model.wear_rules = false
	print("WEAR CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
