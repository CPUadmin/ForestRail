extends Node
# N12: the pole truck. The pole is a real rod: force only along its axis, the ground holds the
# tip, nothing else limits pushing. The checks cover the ground map, the planting rules, the
# directions of force, the slip, the reach, and a driver that pushes freely and what comes out.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Pole = preload("res://scripts/pole.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

# A long straight line of a given grade, all firm ground unless a test says otherwise.
func line(grade: float, ground: String = "dense") -> Object:
	var m = Model.new()
	m.new_game(42, 1)
	m.state.money = 100000
	Fixtures.equip(m, "pole")
	var points: Array = []
	for x in range(-40, 20001): points.append([float(x), float(x) * grade, float(x)])
	m.route.points = points
	m.route.length_m = 20000.0
	m.pole.segments = [[-100.0, 30000.0, ground]]
	m.pole.built_for = "%d:%.1f" % [int(m.route.seed_value), float(m.route.length_m)]
	m.state.phase = "route"
	m.state.s = 100.0
	m.state.v = 0.0
	m.state.brake = 0.0
	return m

func steps(m, n: int) -> void:
	for i in range(n): m.physics_step(1.0 / 60.0)

# A free pusher: carry the pole to `reach` ahead, plant, lean on it fully, lift when it is
# behind `lift_at` metres, repeat. No pacing of any kind is built into the driver or the pole.
func drive(m, seconds: float, reach: float = 2.2, lift_at: float = -2.2) -> Dictionary:
	var top = 0.0
	var plants = 0
	for i in range(int(seconds * 60.0)):
		if not m.pole.planted():
			m.pole_aim(reach)
			if absf(m.pole.tip - reach) < 0.2 and m.pole.lock <= 0.0 and m.pole_plant():
				plants += 1
				m.pole_effort(1.0)
		else:
			m.pole_effort(1.0)
			if float(m.pole.tip) < lift_at: m.pole_lift()
		m.physics_step(1.0 / 60.0)
		top = maxf(top, float(m.state.v))
	return {"top": top, "v": float(m.state.v), "plants": plants, "s": float(m.state.s)}

func run() -> void:
	var m = line(0.0)
	check(m.vehicle_id() == "pole" and m.human_powered() and m.object_stats("pole").slots == 2, "a pole truck with two places")
	check("pole" in Model.VEHICLE_IDS and m.top_speed_kmh("pole") == 28.0, "in the garage list, stated top speed 28 km/h")
	check(m.state.fleet_by_id.pole.fuel == 0.0 and m.trip_forecast({"dropoffs": []}).is_empty(), "no fuel, no forecast")
	# the ground map
	var a = Pole.new()
	var b = Pole.new()
	var stations = [0.0, 700.0, 1600.0, 3000.0, 4400.0, 5800.0]
	a.build(42, 6000.0, stations)
	b.build(42, 6000.0, stations)
	check(a.segments == b.segments, "the ground is the same for the same seed")
	var c = Pole.new()
	c.build(43, 6000.0, stations)
	check(a.segments != c.segments, "a different seed gives a different ground")
	var lengths_ok = true
	for k in range(a.segments.size() - 1):
		var length = float(a.segments[k][1]) - float(a.segments[k][0])
		if length < 1.99 or length > 6.01 or absf(float(a.segments[k][1]) - float(a.segments[k + 1][0])) > 0.0001: lengths_ok = false
	check(lengths_ok, "stretches of 2 to 6 m without gaps")
	var lake = {}
	var bor = {}
	for k in range(200):
		lake[a.ground_at(3000.0 + float(k) - 100.0).type] = true
		bor[a.ground_at(4400.0 + float(k) - 100.0).type] = true
	check(lake.has("clay") and bor.has("stones"), "clay by the lake, stones in the upper forest")
	# planting rules
	m = line(0.0)
	m.pole.tip = 0.1
	check(not m.pole_plant(), "the tip cannot be planted under the hands")
	m.pole.tip = 2.0
	check(m.pole_plant() and m.pole.planted() and absf(float(m.pole.tip_s) - 102.0) < 0.001, "planted where the tip is")
	var held_v = float(m.state.v)
	steps(m, 30)
	check(absf(float(m.state.v) - held_v) < 0.01 and float(m.pole.force) == 0.0, "a planted pole without effort gives no force")
	# free carrying follows the aim like a spring, never jumps
	m = line(0.0)
	m.pole_aim(-3.0)
	var previous = float(m.pole.tip)
	var jump = 0.0
	for i in range(60):
		steps(m, 1)
		jump = maxf(jump, absf(float(m.pole.tip) - previous))
		previous = float(m.pole.tip)
	check(absf(float(m.pole.tip) + 3.0) < 0.3 and jump < 0.2, "the carried pole swings to the aim without a jump (%.3f m a frame)" % jump)
	# direction of force: tip ahead and a pull drives forward; leaning the other way brakes
	m = line(0.0)
	m.pole.tip = 2.0
	m.pole_plant()
	m.pole_effort(1.0)
	steps(m, 30)
	check(float(m.state.v) > 0.2 and float(m.pole.force) > 0.0, "tip ahead, pull: forward")
	m = line(0.0)
	m.state.v = 4.0
	m.pole.tip = 2.0
	m.pole_plant()
	m.pole_effort(-1.0)
	steps(m, 30)
	check(float(m.state.v) < 4.0 and float(m.pole.force) < 0.0, "tip ahead, lean the other way: stand on the pole and brake")
	m = line(0.0)
	m.pole.tip = -2.0
	m.pole_plant()
	m.pole_effort(1.0)
	steps(m, 30)
	check(float(m.state.v) > 0.2, "tip behind, push off: forward")
	# a person pushes weaker the faster the hands travel along the pole
	var slow = line(0.0)
	slow.state.v = 0.5
	slow.pole.tip = -1.0
	slow.pole_plant()
	slow.pole_effort(1.0)
	steps(slow, 12)
	var quick = line(0.0)
	quick.state.v = 7.0
	quick.pole.tip = -1.0
	quick.pole_plant()
	quick.pole_effort(1.0)
	steps(quick, 12)
	var push_slow = float(slow.pole.force)
	var push_quick = float(quick.pole.force)
	check(push_quick < push_slow * 0.6 and push_quick > 0.0, "the push fades with the hands' speed (%.0f N slow, %.0f N quick)" % [push_slow, push_quick])
	# the ground decides how hard the tip holds
	var force_on = {}
	for ground in ["dense", "clay", "stones", "roots"]:
		var g = line(0.0, ground)
		g.pole.tip = 2.0
		# a stony place may skid the tip: pick a place that does not
		var planted = false
		for k in range(40):
			g.pole.lock = 0.0
			g.pole.tip = 2.0 + 0.07 * float(k)
			if g.pole_plant(): planted = true; break
		g.pole_effort(1.0)
		steps(g, 40)
		force_on[ground] = float(g.pole.force)
		check(planted, "the tip could be planted on " + ground)
	check(force_on.clay < force_on.dense * 0.6 and force_on.stones < force_on.clay and force_on.roots >= force_on.dense, "the ground decides how hard the tip holds: " + str(force_on))
	var sliding = line(0.0, "clay")
	sliding.pole.tip = 2.0
	sliding.pole_plant()
	sliding.pole_effort(1.0)
	steps(sliding, 30)
	check(sliding.pole.slipping and absf(float(sliding.pole.tip_s) - 102.0) > 0.001, "an overpowered tip slips and is dragged")
	# stony places skid a plant the same way every time
	var skids = 0
	var repeat = 0
	for k in range(100):
		var g = line(0.0, "stones")
		g.pole.tip = 0.5 + 0.03 * float(k)
		var first = g.pole_plant()
		var h = line(0.0, "stones")
		h.pole.tip = 0.5 + 0.03 * float(k)
		if h.pole_plant() == first: repeat += 1
		if not first: skids += 1
	check(repeat == 100 and skids > 20 and skids < 60, "about 40%% of stony places skid, always the same ones (%d of 100)" % skids)
	# running past the reach pulls the pole out
	m = line(0.0)
	m.state.v = 6.0
	m.pole.tip = 2.0
	m.pole_plant()
	steps(m, 60 * 2)
	check(not m.pole.planted(), "the truck runs past the pole's reach and pulls it out")
	# clay holds the tip: lifting takes a moment
	var clay = line(0.0, "clay")
	clay.pole.tip = 2.0
	clay.pole_plant()
	clay.pole_lift()
	check(not clay.pole_plant() and clay.pole.lock > 0.3, "pulling the tip out of clay takes time")
	# free pushing: what a driver with no pacing gets out of the pole
	var flat = line(0.0)
	var result = drive(flat, 60.0)
	print("POLE flat: top %.2f m/s (%.1f km/h), %d plants, %.0f m in 60 s" % [result.top, result.top * 3.6, result.plants, result.s - 100.0])
	check(result.top * 3.6 > 14.0 and result.top * 3.6 < 36.0, "free pushing on firm flat ground gets 14-36 km/h (%.1f)" % (result.top * 3.6))
	var hill = line(0.04)
	var hill_result = drive(hill, 60.0)
	print("POLE 4%% hill: top %.2f m/s, %.0f m in 60 s" % [hill_result.top, hill_result.s - 100.0])
	check(hill_result.s - 100.0 > 20.0 and hill_result.top < result.top, "a 4%% hill is climbed, slower than the flat (%.0f m)" % (hill_result.s - 100.0))
	var steep = line(0.05)
	var steep_result = drive(steep, 60.0, 2.2, -2.2)
	print("POLE 5%% hill: top %.2f m/s, %.0f m in 60 s" % [steep_result.top, steep_result.s - 100.0])
	check(steep_result.s - 100.0 > 10.0, "even a 5%% hill is climbed (%.0f m)" % (steep_result.s - 100.0))
	var handcar = Model.new()
	handcar.new_game(42, 1)
	handcar.state.phase = "route"
	check(handcar.pole_plant() == false, "only the pole truck has a pole")
	# loaded and saved
	var other = Model.new()
	m = line(0.0)
	m.state.phase = "depot"
	m.state.active = {}
	m.state.cargo = []
	check(other.restore(m.serialize()) and other.vehicle_id() == "pole", "the pole truck survives saving and loading")
	print("POLE CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
