extends Node
# Веха 5, В5.6: износ и повреждения узлов (docs/archive/DAMAGE_RU.md). Состояние узла 0..1, эффекты на цифры машины,
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
	# (1.4.4) C1: the skid hurts the axle boxes by the speed (2..6%) and the wheels of every wagon (1.5..4%)
	check(approx(d.wear().condition("motorcar", "bearings"), 1.0 - 0.06), "a skid at 25 m/s takes 6%% of the axle boxes (%.3f)" % d.wear().condition("motorcar", "bearings"))
	check(approx(d.wear().condition("W01", "wheels"), 1.0 - 0.04), "the skid slides the wheels of the wagon too (%.3f)" % d.wear().condition("W01", "wheels"))
	# P2: one event at most 15%, one cause at most 30% of a node in a trip; a new trip starts the count again
	var cap = fresh()
	cap.wear().damage("motorcar", "engine", 0.5, "проба")
	check(approx(cap.wear().condition("motorcar", "engine"), 0.85), "one event takes at most 15%% (%.3f)" % cap.wear().condition("motorcar", "engine"))
	for k in range(4): cap.wear().damage("motorcar", "engine", 0.1, "проба")
	check(approx(cap.wear().condition("motorcar", "engine"), 0.7), "one cause takes at most 30%% in a trip (%.3f)" % cap.wear().condition("motorcar", "engine"))
	cap.wear().damage("motorcar", "engine", 0.05, "другая причина")
	check(approx(cap.wear().condition("motorcar", "engine"), 0.65), "another cause still hurts")
	cap.wear().new_trip()
	cap.wear().damage("motorcar", "engine", 0.05, "проба")
	check(approx(cap.wear().condition("motorcar", "engine"), 0.6) and cap.wear().journal.size() == 1, "a new trip: the cap and the journal start again")
	var step = func(model, seconds: float) -> void:
		for i in range(int(seconds * 60.0)): model.wear_causes_step(1.0 / 60.0)
	# C2: gas against the brake wears both, every second; told once; a light brake is fine
	var fight = fresh()
	fight.state.v = 5.0
	fight.state.throttle = 0.6
	fight.state.brake = 0.6
	step.call(fight, 10.0)
	check(approx(fight.wear().condition("motorcar", "brake"), 0.95, 0.002) and approx(fight.wear().condition("motorcar", "engine"), 0.97, 0.002), "gas against the brake: −0.5%%/s of the brake, −0.3%%/s of the engine (%.3f, %.3f)" % [fight.wear().condition("motorcar", "brake"), fight.wear().condition("motorcar", "engine")])
	check(fight.message.begins_with("Газ против тормоза") and fight.wear().journal_lines()[0].begins_with("Газ против тормоза"), "it is told and written (%s)" % fight.message)
	check(fight.wear().journal.size() == 2, "a cause every second keeps two lines in the journal, not a flood (%d)" % fight.wear().journal.size())
	var light = fresh()
	light.state.v = 5.0
	light.state.throttle = 0.6
	light.state.brake = 0.2
	step.call(light, 10.0)
	check(light.wear().condition("motorcar", "brake") == 1.0, "a light brake with gas hurts nothing")
	# C3: the spinning wheels grind the engine and the axle boxes
	var spin = fresh()
	spin.state.v = 2.0
	spin.wheel_slip = true
	step.call(spin, 10.0)
	check(approx(spin.wear().condition("motorcar", "engine"), 0.97, 0.002) and approx(spin.wear().condition("motorcar", "bearings"), 0.98, 0.002), "spinning: −0.3%%/s engine, −0.2%%/s axle boxes (%.3f, %.3f)" % [spin.wear().condition("motorcar", "engine"), spin.wear().condition("motorcar", "bearings")])
	# C5: full gas, slow, up a 6% hill: every pull node wears and the engine heats more; downhill or at 70% gas nothing
	var hill = func(throttle: float, v: float):
		var h = fresh()
		for point in h.route.points: point[1] = float(point[0]) * 0.06
		h.state.engine = true
		h.state.gear = 1
		h.state.throttle = throttle
		h.state.v = v
		return h
	var heavy = hill.call(0.9, 1.0)
	var heat_before = heavy.heat_rate(heavy.state.fleet_by_id.motorcar)
	heavy.wear_causes_step(1.0 / 60.0)
	check(heavy.heavy_work and heavy.heat_rate(heavy.state.fleet_by_id.motorcar) > heat_before * 1.15, "lugging uphill is heavy work and heats more")
	step.call(heavy, 30.0)
	check(heavy.wear().condition("motorcar", "engine") < 0.99 and heavy.wear().condition("motorcar", "gearbox") < 0.99, "heavy work wears the engine and the box (%.3f, %.3f)" % [heavy.wear().condition("motorcar", "engine"), heavy.wear().condition("motorcar", "gearbox")])
	check(heavy.message.begins_with("Тянет в натяг"), "heavy work is told (%s)" % heavy.message)
	var eased = hill.call(0.7, 1.0)
	step.call(eased, 10.0)
	var down = hill.call(0.9, -1.0)
	step.call(down, 10.0)
	check(not eased.heavy_work and not down.heavy_work and eased.wear().condition("motorcar", "engine") == 1.0 and down.wear().condition("motorcar", "engine") == 1.0, "at 70%% gas or downhill no heavy work")
	# C10: a wagon heavier than 300 kg of cargo wears its wheels and springs half as fast again
	var light_wagon = fresh()
	light_wagon.state.cargo = []
	light_wagon.wear().wear_road(1000.0)
	var overloaded = fresh()
	overloaded.state.cargo = []
	for k in range(3): overloaded.state.cargo.append({"type": "logs", "slot": "W01:%d" % k, "delivered": false, "health": 1.0})
	overloaded.wear().wear_road(1000.0)
	var plain_loss = 1.0 - light_wagon.wear().condition("W01", "wheels")
	var heavy_loss = 1.0 - overloaded.wear().condition("W01", "wheels")
	check(approx(heavy_loss, plain_loss * 1.5, 0.0002) and overloaded.wear().condition("W01", "suspension") < light_wagon.wear().condition("W01", "suspension"), "an overloaded wagon wears 1.5 times faster (%.4f against %.4f)" % [heavy_loss, plain_loss])
	check(overloaded.message.contains("перегружен") and light_wagon.message == "", "the overload is told (%s)" % overloaded.message)
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
	# (1.4.3) below 10% a node may stop the machine, 3% a minute, always after an omen of 8 seconds; 10-19% only limps
	var counts = [0, 0, 0]
	for k in range(3):
		var level = [0.05, 0.15, 0.5][k]
		for seed_value in range(1, 41):
			var b = fresh("motorcar", seed_value)
			b.wear().set_condition("motorcar", "engine", level)
			b.state.v = 6.0
			b.state.throttle = 0.5
			for i in range(60 * 60): b.wear().breakdown_step(1.0 / 60.0); b.state.stats.seconds += 1.0 / 60.0
			if b.wear().broken("motorcar") != "" or not b.wear().omen.is_empty(): counts[k] += 1
	check(counts[0] >= 1 and counts[0] <= 5, "a node at 5%% fails in about 3%% of the minutes: %d of 40 runs" % counts[0])
	check(counts[1] == 0, "a node at 15%% limps but never stops (%d)" % counts[1])
	check(counts[2] == 0, "a node at 50%% never fails")
	# the omen: 8 seconds of warning, then the stop; mended in time, no stop
	var o = fresh("motorcar")
	o.wear().set_condition("motorcar", "engine", 0.05)
	o.state.v = 6.0
	o.state.throttle = 0.5
	var steps = 0
	while o.wear().omen.is_empty() and steps < 60 * 60 * 120:
		o.wear().breakdown_step(1.0 / 60.0); o.state.stats.seconds += 1.0 / 60.0; steps += 1
	check(not o.wear().omen.is_empty() and o.wear().broken("motorcar") == "", "the omen comes before the stop")
	check("wear_omen" in o.events and o.message.contains("на пределе"), "the omen is heard and told (%s)" % o.message)
	for i in range(60 * 7): o.wear().breakdown_step(1.0 / 60.0)
	check(o.wear().broken("motorcar") == "", "after 7 seconds of the omen the machine still goes")
	for i in range(60 * 2): o.wear().breakdown_step(1.0 / 60.0)
	check(o.wear().broken("motorcar") == "engine", "after the omen the engine stops the machine (%s)" % o.wear().broken("motorcar"))
	var saved = fresh("motorcar")
	saved.wear().omen = {"id": "motorcar", "node": "engine", "t": 8.0}
	saved.wear().set_condition("motorcar", "engine", 0.3)
	for i in range(60 * 10): saved.wear().breakdown_step(1.0 / 60.0)
	check(saved.wear().broken("motorcar") == "" and saved.wear().omen.is_empty(), "a node mended during the omen does not stop")
	# limping: a failing node of the pull pulls at half
	var lame = fresh("motorcar")
	lame.wear().set_condition("motorcar", "engine", 0.15)
	check(lame.wear().limping("motorcar") and approx(lame.wear().factor("motorcar", "power"), (0.6 + 0.4 * 0.15) * 0.5), "a failing engine limps at half the pull (%.3f)" % lame.wear().factor("motorcar", "power"))
	lame.wear().set_condition("motorcar", "engine", 0.25)
	check(not lame.wear().limping("motorcar") and approx(lame.wear().factor("motorcar", "power"), 0.6 + 0.4 * 0.25), "a critical engine does not limp yet")
	check(lame.wear().stage("motorcar", "engine") == "critical", "the stage of the engine at 25%% is critical")
	# the zeppelin and the jet: their nodes now weaken the flight and the pull
	var jz = fresh("jet")
	jz.wear().set_condition("jet", "engine", 0.15)
	jz.physics_step(1.0 / 60.0)
	check(approx(jz.jet.wear_scale, jz.wear().factor("jet", "power")) and jz.jet.wear_scale < 0.5, "a failing jet engine gives less thrust (%.2f)" % jz.jet.wear_scale)
	var zz = fresh("zeppelin")
	zz.physics_step(1.0 / 60.0)
	var power_new = float(zz.zep.cfg.power_w)
	var wing_new = float(zz.zep.cfg.wing_area_m2)
	zz.wear().set_condition("zeppelin", "motor", 0.3)
	zz.wear().set_condition("zeppelin", "wing", 0.3)
	zz.physics_step(1.0 / 60.0)
	check(float(zz.zep.cfg.power_w) < power_new * 0.75, "a worn zeppelin motor gives less power (%.0f of %.0f W)" % [float(zz.zep.cfg.power_w), power_new])
	check(float(zz.zep.cfg.wing_area_m2) < wing_new * 0.85, "a worn wing lifts less (%.1f of %.1f m2)" % [float(zz.zep.cfg.wing_area_m2), wing_new])
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
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
