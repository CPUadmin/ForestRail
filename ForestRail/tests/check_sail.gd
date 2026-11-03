extends Node
# B6.4: the sail car. The wind is a field in place and time (the same for the same seed), the sail
# takes its force from the apparent wind by the angle and the trim, and the car goes where the wind
# pushes it; in a calm it stands, against the wind it does not go.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Wind = preload("res://scripts/wind.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func sail_game() -> Object:
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	Fixtures.equip(m, "sail")
	m.state.phase = "route"
	m.state.s = 600.0
	m.state.v = 0.0
	m.state.brake = 0.0
	return m

# Hold the wind at a fixed vector for a test: a tail wind of `along`, a cross wind of `across`.
func fixed_wind(m, along: float, across: float) -> void:
	m.wind.build(42, m.route.station_s)
	m.wind.gust_times.clear()
	m.wind.gust_power.clear()
	# the field is replaced by one that returns the same vector everywhere
	m.wind = FixedWind.new(along, across, m.route.station_s)

class FixedWind extends RefCounted:
	var station_s: Array = []
	var vector = Vector2.ZERO
	func _init(a: float, c: float, stations: Array) -> void:
		vector = Vector2(a, c)
		station_s = stations.duplicate()
	func at(_s: float, _t: float) -> Vector2: return vector
	func gust_ahead(_s: float, _t: float, _within: float = 4.0) -> float: return -1.0
	func build(_w: int, _s: Array) -> void: pass

func run_seconds(m, seconds: float) -> Dictionary:
	var top = 0.0
	for i in range(int(seconds * 60.0)):
		m.physics_step(1.0 / 60.0)
		top = maxf(top, float(m.state.v))
	return {"v": float(m.state.v), "top": top, "s": float(m.state.s)}

func run() -> void:
	var m = sail_game()
	check(m.vehicle_id() == "sail" and m.human_powered() and m.object_stats("sail").slots == 2 and m.top_speed_kmh("sail") == 36.0, "a sail car with two places, 36 km/h stated")
	check("sail" in Model.VEHICLE_IDS and m.trip_forecast({"dropoffs": []}).is_empty(), "in the garage, no fuel, no forecast")
	# the wind field: the same for the same seed, stronger in the open than in the forest, gusts come in time
	var a = Wind.new()
	var b = Wind.new()
	var stations = [0.0, 900.0, 2100.0, 3500.0, 5200.0, 6800.0]
	a.build(42, stations)
	b.build(42, stations)
	check(a.at(1000.0, 33.0) == b.at(1000.0, 33.0) and a.at(1000.0, 33.0) != a.at(1000.0, 90.0), "the wind is the same for the same seed and changes in time")
	check(a.strength_at(3500.0) > a.strength_at(900.0) + 2.0 and a.strength_at(900.0) >= 2.0, "open water is windier than the forest, and the forest is not dead calm")
	var peak = 0.0
	for k in range(600): peak = maxf(peak, a.gust_at(1000.0, float(k)))
	check(peak > 2.5 and peak < 6.0, "gusts add 3 to 5 m/s (%.1f)" % peak)
	var delay = 1000.0 / maxf(2.0, a.strength_at(1000.0))
	var warned = a.gust_ahead(1000.0, float(a.gust_times[0]) + delay - 2.0)
	check(warned > 1.0 and warned < 3.0, "a coming gust is announced a couple of seconds ahead (%.1f s)" % warned)
	# the sail: a tail wind with the sail open pulls, with the sail edge-on does not
	fixed_wind(m, 6.0, 0.0)
	m.sail_held = true
	m.set_sail_trim(1.0)
	var open_run = run_seconds(m, 20.0)
	check(open_run.v > 2.0 and open_run.v < 8.0, "a 6 m/s tail wind with the sail open moves the car, slower than the wind (%.1f m/s)" % open_run.v)
	var edge = sail_game()
	fixed_wind(edge, 6.0, 0.0)
	edge.sail_held = true
	edge.set_sail_trim(0.0)
	var edge_run = run_seconds(edge, 20.0)
	check(edge_run.v < open_run.v * 0.35, "the sail edge-on pulls much less (%.1f against %.1f)" % [edge_run.v, open_run.v])
	# a side wind: a half-open sail pulls the best, wide open is worse
	var beam = sail_game()
	fixed_wind(beam, 0.0, 8.0)
	beam.sail_held = true
	beam.set_sail_trim(0.45)
	var beam_run = run_seconds(beam, 30.0)
	var beam_wide = sail_game()
	fixed_wind(beam_wide, 0.0, 8.0)
	beam_wide.sail_held = true
	beam_wide.set_sail_trim(1.0)
	var wide_run = run_seconds(beam_wide, 30.0)
	check(beam_run.top > wide_run.top + 0.8 and beam_run.top < 12.0, "on a beam wind the half-open sail beats the wide one (%.1f against %.1f m/s)" % [beam_run.top, wide_run.top])
	check(beam_run.top * 3.6 <= 40.0, "no faster than the stated 36 km/h by much (%.0f km/h)" % (beam_run.top * 3.6))
	# a calm and a head wind
	var calm = sail_game()
	fixed_wind(calm, 0.0, 0.0)
	calm.sail_held = true
	calm.set_sail_trim(0.7)
	check(run_seconds(calm, 20.0).v < 0.05, "in a calm the car stands")
	var head = sail_game()
	fixed_wind(head, -6.0, 0.0)
	head.sail_held = true
	head.set_sail_trim(0.7)
	check(run_seconds(head, 20.0).v < 0.3, "dead against the wind the car does not go")
	# the brake still holds it
	var held = sail_game()
	fixed_wind(held, 6.0, 0.0)
	held.sail_held = true
	held.set_sail_trim(1.0)
	held.state.brake = 1.0
	check(run_seconds(held, 10.0).v < 0.5, "the brake holds the car against the wind")
	# the direction of travel: the same wind is a tail wind one way and a head wind the other
	var back = sail_game()
	fixed_wind(back, 6.0, 0.0)
	back.state.direction = -1
	back.sail_held = true
	back.set_sail_trim(1.0)
	check(run_seconds(back, 10.0).v < 0.3, "turned round, the same wind is a head wind")
	# holding, as with the handcar lever: a sail nobody holds does not pull, a held one does,
	# one made fast on the cleat goes on pulling without the hand
	var free = sail_game()
	fixed_wind(free, 6.0, 0.0)
	free.set_sail_trim(1.0)
	check(not free.sail_engaged() and run_seconds(free, 15.0).v < 0.1, "a sail nobody holds gives no pull in a good wind")
	var cleated = sail_game()
	fixed_wind(cleated, 6.0, 0.0)
	cleated.sail_grab()
	cleated.set_sail_trim(1.0)
	cleated.sail_cleat()
	check(cleated.sail_cleated and not cleated.sail_held, "made fast on the cleat the hand is free")
	var cleated_run = run_seconds(cleated, 15.0)
	check(cleated_run.v > 1.5, "a sail on the cleat goes on pulling (%.1f m/s)" % cleated_run.v)
	cleated.sail_grab()
	check(cleated.sail_held and not cleated.sail_cleated, "taking the sail in the hand frees the cleat")
	cleated.sail_release()
	check(not cleated.sail_engaged(), "letting go lets it flog")
	# a gust the hand cannot hold tears the sheet away; the cleat holds longer and goes at a harder pull
	var gust = sail_game()
	fixed_wind(gust, 11.0, 0.0)
	gust.sail_grab()
	gust.set_sail_trim(1.0)
	run_seconds(gust, 3.0)
	check(not gust.sail_held, "a hard gust pulls the sheet out of the hand")
	var easy = sail_game()
	fixed_wind(easy, 11.0, 0.0)
	easy.sail_grab()
	easy.set_sail_trim(0.3)
	run_seconds(easy, 3.0)
	check(easy.sail_held, "easing the sail in the gust keeps the hold")
	var tough = sail_game()
	fixed_wind(tough, 20.0, 0.0)
	tough.sail_grab()
	tough.set_sail_trim(1.0)
	tough.sail_cleat()
	run_seconds(tough, 3.0)
	check(not tough.sail_cleated, "even the cleat gives way to a storm")
	# trim is clamped, and nothing else has a sail
	m.set_sail_trim(3.0)
	check(is_equal_approx(m.sail_trim, 1.0), "the trim stays in 0..1")
	var hand = Model.new()
	hand.new_game(42, 2)
	hand.set_sail_trim(0.9)
	check(is_equal_approx(hand.sail_trim, 0.6), "only the sail car has a sail")
	# 03.11.2026: two sides, the cleat notches and the any-position lock of the gadget, a stronger sail
	var side_a = sail_game()
	var side_b = sail_game()
	for pair in [[side_a, 1], [side_b, -1]]:
		var s = pair[0]
		fixed_wind(s, 2.0, 6.0)
		s.sail_grab()
		s.set_sail_trim(0.6)
		s.sail_set_side(pair[1])
		for i in range(120): s.physics_step(1.0 / 60.0)
	check(float(side_a.sail_info.force) > float(side_b.sail_info.force) * 1.3, "a boom on the leeward side pulls more than one on the windward side (%.0f against %.0f N)" % [float(side_a.sail_info.force), float(side_b.sail_info.force)])
	var tail_a = sail_game()
	var tail_b = sail_game()
	for pair in [[tail_a, 1], [tail_b, -1]]:
		var s = pair[0]
		fixed_wind(s, 6.0, 0.0)
		s.sail_grab()
		s.set_sail_trim(1.0)
		s.sail_set_side(pair[1])
		for i in range(60): s.physics_step(1.0 / 60.0)
	check(is_equal_approx(float(tail_a.sail_info.force), float(tail_b.sail_info.force)), "in a tail wind the side does not matter")
	var notch = sail_game()
	notch.sail_grab()
	notch.set_sail_trim(0.3)
	notch.sail_cleat()
	check(notch.sail_cleated and is_equal_approx(notch.sail_trim, 0.5), "the plain cleat holds the sheet in a notch (0.5), not at 0.3")
	var free_lock = sail_game()
	free_lock.data.upgrade_catalog.append({"id": "sail_test_lock", "target_type": "sail", "name": "test", "level_costs": [1, 1], "levels": 2, "effects_at_level": {"sail_any_lock": [true, true]}, "scope": "selected_vehicle_id"})
	free_lock.object_state("sail").levels["sail_test_lock"] = 1
	free_lock.sail_grab()
	free_lock.set_sail_trim(0.3)
	free_lock.sail_cleat()
	check(free_lock.sail_cleated and is_equal_approx(free_lock.sail_trim, 0.3), "with the lock gadget the cleat holds the sheet at any opening")
	check(Model.SAIL_AREA_M2 > 6.0 and Model.SAIL_GRIP_N > 220.0, "the sail was made stronger")
	# the free corner moves up and down as well: held high it spills the wind
	var low = sail_game()
	var high = sail_game()
	for pair in [[low, 0.0], [high, 0.9]]:
		var s = pair[0]
		fixed_wind(s, 6.0, 0.0)
		s.sail_grab()
		s.set_sail_trim(1.0)
		s.set_sail_lift(pair[1])
		for i in range(60): s.physics_step(1.0 / 60.0)
	check(float(high.sail_info.force) < float(low.sail_info.force) * 0.65 and float(high.sail_info.force) > 0.0, "a corner held high spills the wind (%.0f against %.0f N)" % [float(high.sail_info.force), float(low.sail_info.force)])
	low.set_sail_lift(5.0)
	check(is_equal_approx(low.sail_lift, 0.9), "the corner can go no higher than 0.9 m")
	print("SAIL CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
