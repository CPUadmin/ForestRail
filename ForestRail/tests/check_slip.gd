extends Node
# The driving wheels spin when the engine asks more than the rail holds (steam, motorcar, locomotive);
# a smooth trip pays +5% with a medal, a harsh one −5%.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

# The machine with its usual wagons, standing on the line, ready to go.
func fresh(id: String, rain: float = 0.0):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 1000000
	Fixtures.equip(m, id)
	m.weather_force = {"cloud": rain, "rain": rain, "fog": 0.0}
	m.state.phase = "route"
	m.state.s = 300.0
	m.state.v = 0.0
	m.state.direction = 1
	m.state.reverser = 1
	m.state.brake = 0.0
	m.state.throttle = 0.0
	if id == "steam": Fixtures.fire_up(m)
	if id == "motorcar":
		m.state.engine = true
		m.state.gear = 1
	return m

# Drives 6 s with a throttle given by a function of the time; reports the metres, the seconds of spin
# and the throttle at the first spin (-1: none).
func start(m, throttle: Callable) -> Dictionary:
	var from = float(m.state.s)
	var spin = 0.0
	var first = -1.0
	for i in range(360):
		m.state.throttle = float(throttle.call(i / 60.0, m))
		m.physics_step(1.0 / 60.0)
		if m.wheel_slip:
			spin += 1.0 / 60.0
			if first < 0.0: first = float(m.state.throttle)
	return {"m": float(m.state.s) - from, "spin": spin, "first": first}

func run() -> void:
	var floored = func(_t, _m): return 1.0
	var smooth = func(t, m): return minf(t / 0.5, m.throttle_safe())   # opened over half a second, never past the grip
	for id in ["steam", "motorcar", "locomotive"]:
		var hard = start(fresh(id), floored)
		var soft = start(fresh(id), smooth)
		var gentle = start(fresh(id), func(t, _m): return minf(0.65, t / 2.0))
		print("SLIP %s: floored %.1f m in 6 s, spinning %.1f s; smooth %.1f m, spinning %.1f s" % [id, hard.m, hard.spin, soft.m, soft.spin])
		check(hard.spin > 0.5, "%s: floored from a standstill, the wheels spin (%.1f s)" % [id, hard.spin])
		check(soft.spin == 0.0 and gentle.spin == 0.0, "%s: opened smoothly, they do not" % id)
		check(soft.m > hard.m, "%s: the smooth start goes further in 6 s (%.1f m against %.1f m)" % [id, soft.m, hard.m])
		var slow = func(t, _m): return minf(1.0, t / 5.0)
		var dry = start(fresh(id), slow)
		var wet = start(fresh(id, 1.0), slow)
		print("SLIP %s: a slow opening spins at %.2f dry, %.2f wet" % [id, dry.first, wet.first])
		check(wet.first > 0.0 and (dry.first < 0.0 or wet.first < dry.first - 0.1), "%s: in the rain the wheels spin earlier (%.2f against %.2f)" % [id, wet.first, dry.first])
		var safe = start(fresh(id, 1.0), func(_t, _m): return 1.0)
		check(safe.spin > 0.0, "%s: floored in the rain, they spin" % id)
	# the slip lets go when the throttle is eased
	var ease = fresh("locomotive")
	ease.state.throttle = 1.0
	ease.physics_step(1.0 / 60.0)
	check(ease.wheel_slip and ease.events.has("slip"), "the locomotive spins at full throttle and says so")
	ease.state.throttle = 0.6
	ease.physics_step(1.0 / 60.0)
	check(not ease.wheel_slip, "eased to 60%, the wheels grip again")
	ease.state.throttle = ease.throttle_safe()
	for i in range(60): ease.physics_step(1.0 / 60.0)
	check(not ease.wheel_slip and ease.throttle_safe() > 0.7, "the safe throttle does not spin (%.2f)" % ease.throttle_safe())
	# --- 1.4.12: the smarter grip
	var g = fresh("locomotive")
	var at_rest = g.grip_cap()
	g.state.v = 8.0
	var on_the_move = g.grip_cap()
	check(at_rest < on_the_move * 0.95 and at_rest > on_the_move * 0.8, "from a standstill the wheels hold less than on the move (%.0f against %.0f N)" % [at_rest, on_the_move])
	g.state.v = 0.0
	var hill: Array = []
	for x in range(-40, 3001): hill.append([float(x), float(maxi(0, x)) * 0.03, float(x)])
	var flat_grip = g.grip_cap()
	g.route.points = hill
	g.route.length_m = 3000.0
	g.state.s = 300.0
	var hill_grip = g.grip_cap()
	check(hill_grip < flat_grip * 0.97, "a heavy train starting up a 3%% hill grips less (%.0f against %.0f N)" % [hill_grip, flat_grip])
	g.state.direction = -1
	check(g.grip_cap() > hill_grip, "going down the same hill it does not (%.0f N)" % g.grip_cap())
	Model.wear_rules = true
	var wg = fresh("locomotive")
	var new_grip = wg.grip_cap()
	for def in wg.wear().nodes_of("locomotive"):
		if str(def.effect) == "roll": wg.wear().set_condition("locomotive", str(def.id), 0.0)
	check(wg.grip_cap() < new_grip * 0.97, "a worn running gear grips a little less (%.0f against %.0f N)" % [wg.grip_cap(), new_grip])
	Model.wear_rules = false
	# the edge: near the grip the wheels warn before they let go; far from it nothing
	var e = fresh("locomotive")
	e.driving_force(e.grip_cap() * 0.95)
	check(not e.wheel_slip and e.slip_edge > 0.5, "at 95%% of the grip the wheels are on the edge (%.2f) but still hold" % e.slip_edge)
	e.driving_force(e.grip_cap() * 0.5)
	check(e.slip_edge == 0.0, "at half the grip: no warning")
	# a smooth way out: the pull comes back over SLIP_RECOVER_S, not at once
	var r = fresh("locomotive")
	r.state.v = 8.0   # on the move, where the full grip is back and the spinning wheels pull only SPIN_RATIO of it
	var big = r.grip_cap() * 1.5
	r.driving_force(big)
	check(r.wheel_slip, "pulled past the grip, the wheels spin")
	var ask = r.grip_cap() * 0.8
	var first_out = r.driving_force(ask, 1.0 / 60.0)
	check(not r.wheel_slip and first_out < ask * 0.95, "eased, they grip at once, but the pull comes back smoothly (%.0f of %.0f N)" % [first_out, ask])
	var later = 0.0
	for i in range(30): later = r.driving_force(ask, 1.0 / 60.0)
	check(is_equal_approx(later, ask), "after half a second the full pull is back (%.0f of %.0f N)" % [later, ask])
	# --- 1.4.15: the pneumatic train «мягкий воздух» and the air sander
	var pn = fresh("pneumatic")
	var pn_floor = start(pn, func(_t, _m): return 1.0)
	check(pn.spins() and pn_floor.spin == 0.0, "the pneumatic train floored from a standstill on the flat does not spin (soft air)")
	var pn_hill = fresh("pneumatic")
	var steep: Array = []
	for x in range(-40, 3001): steep.append([float(x), float(maxi(0, x)) * 0.06, float(x)])
	pn_hill.route.points = steep
	pn_hill.route.length_m = 3000.0
	pn_hill.state.s = 400.0
	var up = start(pn_hill, func(_t, _m): return 1.0)
	check(up.spin == 0.0, "nor up a 6%% hill, as long as it does not roll back (%.1f s)" % up.spin)
	# the extreme: up a steep hill, already rolling back, a full valve -> it spins, the sander puffs and the wheels catch
	var ex = fresh("pneumatic")
	ex.route.points = steep
	ex.route.length_m = 3000.0
	ex.state.s = 400.0
	ex.state.v = -2.0
	ex.state.throttle = 1.0
	var sand_before = ex.sand_left()
	var air_before = float(ex.state.fleet_by_id.pneumatic.fuel)
	var spun_ex = false
	var sanded = false
	var caught = false
	for i in range(60 * 3):
		ex.physics_step(1.0 / 60.0)
		spun_ex = spun_ex or ex.wheel_slip
		sanded = sanded or ex.events.has("sand")
		if spun_ex and sanded and not ex.wheel_slip: caught = true
	check(spun_ex, "rolling back up a steep hill with the valve full, the wheels spin")
	check(sanded and ex.sand_left() == sand_before - 1, "the sander puffs by itself (sand %d -> %d)" % [sand_before, ex.sand_left()])
	check(caught, "and the wheels catch on the sand")
	check(float(ex.state.fleet_by_id.pneumatic.fuel) < air_before, "a puff takes some air")
	# no sand: it spins on until the valve is eased
	var dry = fresh("pneumatic")
	dry.route.points = steep
	dry.route.length_m = 3000.0
	dry.state.s = 400.0
	dry.state.fleet_by_id.pneumatic.sand = 0
	dry.state.v = -2.0
	dry.state.throttle = 1.0
	var dry_spin = 0
	for i in range(60 * 2):
		dry.physics_step(1.0 / 60.0)
		if dry.wheel_slip: dry_spin += 1
	check(dry_spin > 60 and not dry.events.has("sand"), "with no sand it keeps spinning (%d frames)" % dry_spin)
	dry.state.throttle = 0.3
	for i in range(20): dry.physics_step(1.0 / 60.0)
	check(not dry.wheel_slip, "eased, the wheels catch without sand")
	dry.refill_sand()
	check(dry.sand_left() == 20, "the depot fills the sander (20)")
	# the pole, the jet and the handcar never spin
	for id in ["pole", "jet", "handcar"]:
		var other = fresh(id)
		var spun = false
		for i in range(120):
			other.state.throttle = 1.0
			other.physics_step(1.0 / 60.0)
			spun = spun or other.wheel_slip
		check(not other.spins() and not spun, "%s never spins its wheels" % id)
	# --- the smoothness of the trip
	var jerk = fresh("motorcar")
	jerk.state.active = {"phase": "outbound"}
	jerk.state.v = 10.0
	jerk.track_smooth(1.0 / 60.0, 0.1)
	jerk.state.brake = 1.0
	jerk.track_smooth(1.0 / 60.0, 0.1)
	check(is_equal_approx(float(jerk.state.active.get("rough", 0.0)), 1.5), "the brake jerked on at speed counts 1.5 (%.2f)" % float(jerk.state.active.get("rough", 0.0)))
	var calm = fresh("motorcar")
	calm.state.active = {"phase": "outbound"}
	calm.state.v = 10.0
	for i in range(61):
		calm.state.brake = i / 60.0
		calm.track_smooth(1.0 / 60.0, 0.1)
	check(float(calm.state.active.get("rough", 0.0)) == 0.0, "the brake pulled over a second does not count")
	var crawl = fresh("motorcar")
	crawl.state.active = {"phase": "outbound"}
	crawl.state.v = 3.0
	crawl.track_smooth(1.0 / 60.0, 0.1)
	crawl.state.brake = 1.0
	crawl.track_smooth(1.0 / 60.0, 0.1)
	check(float(crawl.state.active.get("rough", 0.0)) == 0.0, "nor a jerk at a crawl")
	var spinning = fresh("locomotive")
	spinning.state.active = {"phase": "outbound"}
	spinning.state.throttle = 1.0
	for i in range(60): spinning.physics_step(1.0 / 60.0)
	check(float(spinning.state.active.get("rough", 0.0)) > 0.9, "a second of spinning counts a second (%.2f)" % float(spinning.state.active.get("rough", 0.0)))
	# --- the pay
	Model.order_rules = true
	var good = pay(3000.0, 0.0)
	check(good.notes.has("плавный рейс +5%") and good.medals.has("smooth") and good.paid == roundi(good.listed * 1.05), "a clean trip pays +5%% with the medal (%d of %d)" % [good.paid, good.listed])
	var bad = pay(3000.0, 3000.0 / 1000.0 * (Model.SMOOTH_BAD + 1.0))
	check(bad.notes.has("резкая езда −5%") and not bad.medals.has("smooth") and bad.paid == roundi(bad.listed * 0.95), "a harsh trip pays −5%% (%d of %d)" % [bad.paid, bad.listed])
	var mid = pay(3000.0, 3.0 * (Model.SMOOTH_GOOD + Model.SMOOTH_BAD) * 0.5)
	check(mid.notes.is_empty() and mid.medals.is_empty() and mid.paid == mid.listed, "in between: nothing (%s)" % str(mid.notes))
	var short = pay(600.0, 0.0)
	check(short.notes.is_empty() and short.paid == short.listed, "a trip shorter than a kilometre gets no bonus")
	var late = pay(3000.0, 0.0, 2.0)
	check(not late.notes.has("плавный рейс +5%") and not late.medals.has("smooth"), "a late trip gets no bonus (%s)" % str(late.notes))
	var late_bad = pay(3000.0, 30.0, 2.0)
	check(not late_bad.notes.has("резкая езда −5%"), "and no penalty")
	var creative = pay(3000.0, 0.0, 1.0, true)
	check(creative.notes.is_empty() and creative.medals.is_empty(), "the creative mode gets neither (%s)" % str(creative.notes))
	var creative_bad = pay(3000.0, 30.0, 1.0, true)
	check(creative_bad.notes.is_empty(), "neither the penalty")
	Model.order_rules = false
	# --- test drives for the thresholds: a kilometre and a stop, careful and harsh
	for id in ["motorcar", "locomotive", "steam"]:
		var careful = drive_km(fresh(id), false)
		var harsh = drive_km(fresh(id), true)
		print("SLIP DRIVE %s: careful %.2f a km, harsh %.2f a km" % [id, careful.per_km, harsh.per_km])
		check(careful.mark == 1, "%s: a careful kilometre is smooth (%.2f a km)" % [id, careful.per_km])
		# the steam regulator is gentle by itself (the boiler limits the pull): a harsh steam driver only loses the bonus
		check(harsh.mark == -1 if id != "steam" else harsh.mark <= 0, "%s: a harsh one is not (%.2f a km)" % [id, harsh.per_km])
	print("SLIP CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)

# Takes a free order, marks the metres and the rough points of the trip, comes back at a share of the time.
func pay(metres: float, rough: float, fraction: float = 1.0, creative: bool = false) -> Dictionary:
	var m = Model.new()
	m.new_game(42, 2)
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	m.state.money = 5000
	if creative: m.state.mode = "creative"
	var mission = m.free_offers()[0]
	m.accept_mission(mission)
	for i in range(mini(m.state.cargo.size(), m.slots().size())): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	m.depart()
	for item in m.state.cargo: item.delivered = true
	m.evaluate_delivery()
	m.state.stats.seconds = float(m.state.stats.seconds) + float(m.state.active.get("budget_s", 100.0)) * fraction
	m.state.s = float(m.route.station_s[0])
	m.state.v = 0.0
	m.state.brake = 1.0
	m.state.active.pending_reward = int(m.state.active.reward)
	m.state.active.smooth_m = metres
	m.state.active.rough = rough
	var listed = float(m.state.active.reward)
	var before = int(m.state.money)
	m.settle()
	return {"paid": int(m.state.money) - before, "listed": listed, "notes": m.state.last_result.get("notes", []), "medals": m.state.last_result.get("medals", [])}

# A kilometre (and a bit) from a standstill to a stop. Careful: the throttle opened slowly up to the grip, the brake lever drawn
# over a second up to what the rail holds. Harsh: full throttle, the brake slammed on.
func drive_km(m, harsh: bool) -> Dictionary:
	m.state.active = {"phase": "outbound"}
	var target = float(m.state.s) + 1100.0
	var braking = false
	for i in range(60 * 400):
		var speed = absf(float(m.state.v))
		var remaining = target - float(m.state.s)
		if not braking and remaining < m.stopping_distance(speed) * (1.0 if harsh else 1.3) + 3.0: braking = true
		if braking:
			m.state.throttle = 0.0
			m.state.brake = 1.0 if harsh else move_toward(float(m.state.brake), m.brake_safe() if speed > 1.2 else 1.0, 1.0 / 60.0)
			if speed < 0.05: break
		else:
			m.state.throttle = 1.0 if harsh else minf(move_toward(float(m.state.throttle), 1.0, 0.5 / 60.0), m.throttle_safe())
		m.physics_step(1.0 / 60.0)
	var km = float(m.state.active.get("smooth_m", 0.0)) / 1000.0
	return {"mark": m.smooth_mark(), "per_km": float(m.state.active.get("rough", 0.0)) / maxf(1.0, km)}
