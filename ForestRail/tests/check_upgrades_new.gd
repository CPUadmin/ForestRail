extends Node
# The ordinary upgrades of the pole truck, the sail car, the steam engine and the pneumatic train:
# each branch buys, shows in the machine's numbers and really reaches the physics.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Wind = preload("res://scripts/wind.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	Model.legacy_tanks = true
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

class FixedWind extends RefCounted:
	var station_s: Array = []
	var vector = Vector2.ZERO
	func _init(a: float, c: float, stations: Array) -> void:
		vector = Vector2(a, c)
		station_s = stations.duplicate()
	func at(_s: float, _t: float) -> Vector2: return vector
	func gust_ahead(_s: float, _t: float, _within: float = 4.0) -> float: return -1.0
	func build(_w: int, _s: Array) -> void: pass

func game(kind: String, chapter: int = 4):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = chapter
	Fixtures.equip(m, kind)
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	return m

func set_level(m, kind: String, branch: String, level: int) -> void:
	m.object_state(kind).levels[branch] = level

func run() -> void:
	var base = game("pole")
	var branches: Array = []
	for b in base.data.upgrade_catalog:
		if b.target_type in ["pole", "sail", "steam", "pneumatic"] and not b.get("gadget", false): branches.append(b)
	check(branches.size() == 16, "sixteen new branches in the catalog (%d)" % branches.size())
	for b in branches:
		var m = game(str(b.target_type))
		var before = m.object_stats(str(b.target_type))
		check(m.depot_editable() or true, "setup")
		m.state.phase = "depot"
		var bought_1 = m.upgrade(str(b.target_type), str(b.id))
		var bought_2 = m.upgrade(str(b.target_type), str(b.id))
		var bought_3 = m.upgrade(str(b.target_type), str(b.id))
		check(bought_1 and bought_2 and not bought_3, "%s buys twice and no more" % b.id)
		var ef = m.effects(str(b.target_type))
		var ok = true
		for key in b.effects_at_level: ok = ok and is_equal_approx(float(ef[key]), float(b.effects_at_level[key][1]))
		check(ok, "%s: level two takes the numbers from the data" % b.id)
		var after = m.object_stats(str(b.target_type))
		if "brake_multiplier" in b.effects_at_level: check(float(after.brake) > float(before.brake) * 1.5, "%s: the brake is stronger" % b.id)
		if "rolling_multiplier" in b.effects_at_level: check(float(after.rolling) < float(before.rolling) * 0.9, "%s: less rolling resistance" % b.id)
		if "fuel_capacity_multiplier" in b.effects_at_level: check(float(after.tank) > float(before.tank) * 1.2, "%s: a bigger tank" % b.id)
		if "water_capacity_multiplier" in b.effects_at_level: check(float(after.water) > float(before.water) * 1.2, "%s: more water" % b.id)
		if "traction_multiplier" in b.effects_at_level: check(float(after.traction[0]) > float(before.traction[0]) * 1.1, "%s: more traction" % b.id)
	# pole: the force and the grip reach the pole
	var pole = game("pole")
	set_level(pole, "pole", "pole_shaft", 2)
	set_level(pole, "pole", "pole_tip", 2)
	pole.state.phase = "route"
	pole.state.s = 100.0
	pole.state.brake = 0.0
	pole.physics_step(1.0 / 60.0)
	check(is_equal_approx(pole.pole.force_scale, 1.25) and is_equal_approx(pole.pole.grip_scale, 1.45), "the upgraded pole is stronger and grips better")
	# sail: more cloth and a stronger rigging pull more in the same wind
	var runs: Array = []
	for lv in [0, 2]:
		var s = game("sail")
		s.state.phase = "route"
		s.state.s = 600.0
		s.state.v = 0.0
		s.state.brake = 0.0
		s.wind.build(42, s.route.station_s)
		s.wind = FixedWind.new(5.0, 0.0, s.route.station_s)
		set_level(s, "sail", "sail_cloth", lv)
		s.sail_grab()
		s.set_sail_trim(1.0)
		for i in range(600): s.physics_step(1.0 / 60.0)
		runs.append(float(s.state.s) - 600.0)
	check(runs[1] > runs[0] * 1.1, "a bigger sail takes the car farther in ten seconds (%.1f against %.1f m)" % [runs[1], runs[0]])
	# steam: the boiler makes more steam, the firebox burns less coal
	var pressure: Array = []
	var coal_left: Array = []
	for lv in [0, 2]:
		var st = game("steam", 2)
		Fixtures.fire_up(st)
		st.boiler().pressure = 0.0
		st.boiler().firebox = 8.0
		set_level(st, "steam", "steam_boiler", lv)
		set_level(st, "steam", "steam_firebox", lv)
		for i in range(60 * 6): st.steam_step(1.0 / 60.0, st.state.fleet_by_id.steam)
		pressure.append(float(st.boiler().pressure))
		for i in range(60 * 60): st.steam_step(1.0 / 60.0, st.state.fleet_by_id.steam)
		coal_left.append(float(st.boiler().firebox))
	check(pressure[1] > pressure[0], "the better boiler makes pressure faster (%.3f against %.3f)" % [pressure[1], pressure[0]])
	check(coal_left[1] > coal_left[0], "the better firebox burns less coal (%.2f against %.2f kg)" % [coal_left[1], coal_left[0]])
	# pneumatic: insulated pipes frost over more slowly
	var frost: Array = []
	for lv in [0, 2]:
		var pn = game("pneumatic", 5)
		set_level(pn, "pneumatic", "pneumatic_pipes", lv)
		pn.state.phase = "route"
		pn.state.v = 5.0
		pn.state.throttle = 1.0
		for i in range(600): pn.update_frost(pn.state.fleet_by_id.pneumatic, 1.0 / 60.0)
		frost.append(pn.frost())
	check(frost[1] < frost[0] * 0.8, "insulated pipes frost more slowly (%.3f against %.3f)" % [frost[1], frost[0]])
	# the gadgets of the sail car: one level, a lot of money, no mark on the machine
	var shop = game("sail")
	shop.state.phase = "depot"
	shop.state.money = 1000
	check(not shop.upgrade("sail", "sail_spinnaker") and shop.message.contains("Не хватает"), "a gadget is out of reach without the money")
	shop.state.money = 5000
	check(shop.upgrade("sail", "sail_spinnaker") and not shop.upgrade("sail", "sail_spinnaker"), "the spinnaker is bought once")
	check(shop.upgrade("sail", "sail_autopilot"), "and the autopilot too")
	check(not shop.upgrade("pole", "sail_spinnaker") and not shop.upgrade("steam", "sail_spinnaker"), "a gadget belongs to its own type only")
	var pull: Array = []
	for spinnaker in [false, true]:
		var s = game("sail")
		s.state.phase = "route"
		s.state.s = 600.0
		s.state.brake = 0.0
		s.wind.build(42, s.route.station_s)
		s.wind = FixedWind.new(6.0, 0.0, s.route.station_s)
		if spinnaker: s.object_state("sail").levels["sail_spinnaker"] = 1
		s.sail_grab()
		s.set_sail_trim(1.0)
		s.physics_step(1.0 / 60.0)
		pull.append(float(s.sail_info.pulled))
	check(pull[1] > pull[0] * 1.6, "the spinnaker pulls much more in a tail wind (%.0f against %.0f N)" % [pull[1], pull[0]])
	var pilot = game("sail")
	pilot.state.phase = "route"
	pilot.state.s = 600.0
	pilot.state.brake = 0.0
	pilot.wind.build(42, pilot.route.station_s)
	pilot.wind = FixedWind.new(5.0, 5.0, pilot.route.station_s)
	pilot.object_state("sail").levels["sail_autopilot"] = 1
	pilot.sail_grab()
	pilot.set_sail_trim(0.3)
	pilot.sail_cleat()
	check(is_equal_approx(pilot.sail_trim, 0.3), "with the autopilot the sheet is made fast at any opening")
	for i in range(60 * 4): pilot.physics_step(1.0 / 60.0)
	check(absf(pilot.sail_trim - 0.3) > 0.1, "and the autopilot trims it by itself (%.2f)" % pilot.sail_trim)
	# the gadgets of the steam engine: the superheater and the mechanical stoker
	var steam_shop = game("steam", 2)
	steam_shop.state.phase = "depot"
	steam_shop.state.money = 10000
	check(steam_shop.upgrade("steam", "steam_superheater") and steam_shop.upgrade("steam", "steam_stoker") and not steam_shop.upgrade("steam", "steam_stoker"), "the steam gadgets are bought once")
	check(not steam_shop.upgrade("sail", "steam_stoker"), "a steam gadget belongs to the steam engine only")
	var coal: Array = []
	var box: Array = []
	for kind in ["plain", "superheater", "stoker"]:
		var st = game("steam", 2)
		Fixtures.fire_up(st)
		st.state.phase = "route"
		st.boiler().firebox = 5.0
		st.boiler().chill = 0.0
		var bucket_before = float(st.state.fleet_by_id.steam.fuel)
		if kind == "superheater": st.object_state("steam").levels["steam_superheater"] = 1
		if kind == "stoker": st.object_state("steam").levels["steam_stoker"] = 1
		for i in range(60 * 60): st.steam_step(1.0 / 60.0, st.state.fleet_by_id.steam)
		coal.append(bucket_before - float(st.state.fleet_by_id.steam.fuel))
		box.append(float(st.boiler().firebox))
	check(box[1] > box[0], "the superheater burns less coal (%.2f against %.2f kg left in the firebox)" % [box[1], box[0]])
	check(box[2] > 5.0 and coal[2] > 0.5 and box[2] > box[0] + 2.0, "the stoker feeds the fire from the bucket by itself (%.2f kg in the firebox, %.2f from the bucket)" % [box[2], coal[2]])
	check(coal[0] == 0.0, "without the stoker nobody feeds the fire")
	print("NEW UPGRADES CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
