extends Node
# N11: each class reaches its stated top speed on a flat road with a light load, and the
# steam locomotive accelerates slowest of the engines. Handcar speed comes from a scripted
# pumper (tests/handcar_input.gd), not from a person.
const Model = preload("res://scripts/model.gd")
const Fixtures = preload("res://tests/fixtures.gd")
const HandcarInput = preload("res://tests/handcar_input.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func flat_game(kind: String):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	if kind != "handcar":
		Fixtures.equip(m, kind)
		while m.state.consist_ids.size() > 1: m.toggle_wagon(m.state.consist_ids[-1])
		m.refuel()
	var flat: Array = []
	for x in range(-40, 20001): flat.append([float(x), 0.0, float(x)])
	m.route.points = flat
	m.route.length_m = 20000.0
	m.state.phase = "route"
	m.state.s = 100.0
	m.state.brake = 0.0
	m.state.direction = 1
	if kind == "steam": Fixtures.fire_up(m)
	if kind == "motorcar": m.start_engine(true)
	return m

# Full throttle for the given seconds; returns the peak speed and the time to reach given speeds.
func run_class(kind: String, seconds: float, marks: Array) -> Dictionary:
	var m = flat_game(kind)
	var reached: Dictionary = {}
	var peak = 0.0
	var t = 0.0
	while t < seconds:
		if kind == "handcar":
			HandcarInput.pull(m, 1)
		elif kind == "motorcar":
			var gears = m.vehicle_base().gears
			var g = int(m.state.gear)
			var want = 1 if g == 0 else g
			if g >= 1 and g < 4 and float(m.state.v) > float(gears[g - 1][1]) * 0.85: want = g + 1
			if want != g:
				m.state.throttle = 0.0
				m.set_gear(want)
			m.state.throttle = 1.0
		elif kind == "steam":
			m.state.throttle = 1.0
			if float(m.boiler().firebox) < 4.0:
				m.set_door(true)
				while float(m.boiler().firebox) < 9.0 and m.stoke(): pass
				m.set_door(false)
		else:
			m.state.throttle = 1.0
		m.physics_step(1.0 / 60.0)
		t += 1.0 / 60.0
		peak = maxf(peak, float(m.state.v))
		for mark in marks:
			if not reached.has(mark) and float(m.state.v) >= float(mark): reached[mark] = t
	return {"peak": peak, "reached": reached, "m": m}

func run() -> void:
	var results: Dictionary = {}
	for kind in ["handcar", "steam", "motorcar", "locomotive"]:
		results[kind] = run_class(kind, 120.0, [5.0, 10.0])
		var stated = float(results[kind].m.top_speed_kmh(kind))
		var peak_kmh = float(results[kind].peak) * 3.6
		print("SPEEDS ", kind, " peak ", snappedf(peak_kmh, 0.1), " km/h (stated ", stated, "); 10 m/s at ", snappedf(float(results[kind].reached.get(10.0, -1.0)), 0.1), " s")
		check(absf(peak_kmh - stated) <= 2.0, "%s reaches its stated %.0f km/h (got %.1f)" % [kind, stated, peak_kmh])
	var m = Model.new()
	check(m.top_speed_kmh("handcar") == 25.0 and m.top_speed_kmh("steam") == 50.0 and m.top_speed_kmh("motorcar") == 100.0 and m.top_speed_kmh("locomotive") == 75.0, "the owner's top speeds are in the data: 25 / 50 / 100 / 75")
	var steam_t = float(results.steam.reached.get(10.0, 999.0))
	var petrol_t = float(results.motorcar.reached.get(10.0, 999.0))
	var electric_t = float(results.locomotive.reached.get(10.0, 999.0))
	check(steam_t > petrol_t * 1.5 and steam_t > electric_t * 2.0, "the steam locomotive accelerates slowest (%.1f s to 36 km/h against %.1f and %.1f)" % [steam_t, petrol_t, electric_t])
	check(petrol_t > electric_t, "the electric locomotive pulls away fastest (%.1f s against petrol %.1f s)" % [electric_t, petrol_t])
	print("SPEED CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
