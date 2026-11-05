extends Node
# Веха 5, В5.1–В5.3: живой состав. Упругие сцепки с люфтом, подвеска и качание кузовов, груз на ремнях.
# Главное правило: жёсткая основная физика не меняется, живой слой только добавляет картинку, звук
# и порчу хрупкого груза.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Live = preload("res://scripts/live.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

# An electric locomotive with all its wagons on the line, ready to roll (it needs no engine start).
func fresh(live: bool, cargo: bool = false):
	Model.live_effects = live
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 1000000
	Fixtures.equip(m, "locomotive")
	m.state.phase = "route"
	m.state.s = 400.0
	m.state.v = 0.0
	m.state.direction = 1
	m.state.reverser = 1
	m.state.brake = 0.0
	m.state.throttle = 0.0
	m.state.cargo = []
	if cargo:
		var wagon = str(m.state.consist_ids[0])
		m.state.cargo = [
			{"id": "f1", "type": "fragile", "destination": "B", "slot": wagon + ":0", "delivered": false, "health": 1.0, "weight_kg": 60},
			{"id": "l1", "type": "logs", "destination": "B", "slot": wagon + ":1", "delivered": false, "health": 1.0, "weight_kg": 120},
		]
	return m

func run_steps(m, seconds: float) -> void:
	for i in range(int(seconds * 60.0)):
		m.physics_step(1.0 / 60.0)

func run() -> void:
	# --- the rigid physics is the same with the live layer on and off
	var rigid = fresh(false)
	var live = fresh(true)
	for m in [rigid, live]:
		m.state.throttle = 1.0
	run_steps(rigid, 6.0)
	run_steps(live, 6.0)
	check(is_equal_approx(float(rigid.state.s), float(live.state.s)) and is_equal_approx(float(rigid.state.v), float(live.state.v)), "the live layer does not change the way (%.3f vs %.3f)" % [float(rigid.state.s), float(live.state.s)])
	check(float(rigid.state.fleet_by_id.locomotive.fuel) == float(live.state.fleet_by_id.locomotive.fuel), "nor the energy spent")
	# --- start: the wagons lag, the couplers stretch, the slack is taken up with a knock
	var m = fresh(true)
	var n = m.body_ids().size()
	check(n >= 3, "the train has the machine and wagons (%d bodies)" % n)
	m.state.throttle = 1.0
	var max_stretch = 0.0
	var clanks = 0
	var lag_last = 0.0
	for i in range(60 * 5):
		m.physics_step(1.0 / 60.0)
		while not m.events.is_empty():
			if str(m.events.pop_front()) == "clank": clanks += 1
		max_stretch = maxf(max_stretch, m.live.extension(1))
		lag_last = m.live.slack_m(n - 1)
	check(max_stretch > Live.PLAY, "the first coupler stretches past its free play (%.3f m)" % max_stretch)
	check(max_stretch < Live.LIMIT, "and stays within the buffers (%.3f m)" % max_stretch)
	check(lag_last < -0.03, "the last wagon lags behind the rigid place when the train pulls away (%.3f m)" % lag_last)
	check(clanks >= 1, "the slack is taken up with a knock (%d)" % clanks)
	check(m.live.peak_tension >= 0.0 and m.live.peak_tension < 40000.0, "the pull in the couplers is sane (%.0f N)" % m.live.peak_tension)
	# braking: the buffers push, the couplers are compressed
	m.state.throttle = 0.0
	m.state.brake = 1.0
	var min_ext = 0.0
	var brake_clanks = 0
	for i in range(60 * 4):
		m.physics_step(1.0 / 60.0)
		while not m.events.is_empty():
			if str(m.events.pop_front()) == "clank": brake_clanks += 1
		min_ext = minf(min_ext, m.live.extension(1))
	check(min_ext < -Live.PLAY * 0.5, "braking pushes the wagons into one another (%.3f m)" % min_ext)
	check(brake_clanks >= 1, "braking knocks too (%d)" % brake_clanks)
	run_steps(m, 6.0)
	check(absf(float(m.state.v)) < 0.05, "the train has stopped")
	var loosest = 0.0
	for i in range(1, n): loosest = maxf(loosest, absf(m.live.extension(i)))
	check(loosest < Live.PLAY + 0.02, "every coupler rests within its free play at a stop (%.3f of %.3f)" % [loosest, Live.PLAY])
	# --- the rigid picture: with the layer off nothing moves in the picture
	var off = fresh(false)
	off.state.throttle = 1.0
	run_steps(off, 3.0)
	check(off.live.n == 0 and off.body_s_render(2) == off.body_s(2) - off.render_shift(), "with the layer off the bodies keep their rigid places")
	# --- suspension and rocking
	var r = fresh(true)
	r.state.throttle = 1.0
	var nose_up = 0.0
	var worst_lift = 0.0
	for i in range(60 * 4):
		r.physics_step(1.0 / 60.0)
		nose_up = maxf(nose_up, r.live.rock_rad(0))
		worst_lift = maxf(worst_lift, absf(r.live.lift_m(0)))
	check(nose_up > 0.0001 and nose_up <= 0.006, "acceleration produces only subtle suspension pitch (%.4f rad)" % nose_up)
	r.state.throttle = 0.0
	r.state.brake = 1.0
	var nose_down = 0.0
	for i in range(60 * 3):
		r.physics_step(1.0 / 60.0)
		nose_down = minf(nose_down, r.live.rock_rad(0))
	check(nose_down < -0.0001 and nose_down >= -0.006, "braking pitch stays subtle (%.4f rad)" % nose_down)
	check(worst_lift > 0.0005 and worst_lift <= Live.LIFT_LIMIT, "the body bobs on the joints at speed (%.4f m)" % worst_lift)
	# Constant acceleration must not wind up angular velocity against the pitch stop.
	var pitch_model = fresh(true)
	for acceleration in [20.0, -20.0]:
		pitch_model.live.reset(pitch_model.body_ids().size())
		pitch_model.acceleration = acceleration
		for step in range(120):
			pitch_model.live.step(pitch_model, 1.0 / 60.0)
		check(absf(pitch_model.live.rock_rad(0)) <= 0.006, "strong acceleration keeps the body aligned with the rail")
		pitch_model.acceleration = 0.0
		for step in range(120):
			pitch_model.live.step(pitch_model, 1.0 / 60.0)
		check(absf(pitch_model.live.rock_rad(0)) < 0.0001 and absf(float(pitch_model.live.rock_v[0])) < 0.0001, "pitch settles after forward or reverse acceleration ends")
	# a landing shakes every body
	var l = fresh(true)
	run_steps(l, 0.1)
	l.live.landed(5.0)
	var shaken = 0.0
	for i in range(30):
		l.physics_step(1.0 / 60.0)
		shaken = maxf(shaken, absf(l.live.lift_m(0)))
	check(shaken > 0.01, "a landing shakes the body on its springs (%.4f m)" % shaken)
	# --- cargo on its straps
	var c = fresh(true, true)
	c.state.throttle = 1.0
	var back = 0.0
	for i in range(60 * 3):
		c.physics_step(1.0 / 60.0)
		back = minf(back, c.live.cargo_p("l1"))
	check(back < -0.01, "the load slides back when the train pulls away (%.3f m)" % back)
	c.state.throttle = 0.0
	c.state.brake = 1.0
	var forward = 0.0
	for i in range(60 * 3):
		c.physics_step(1.0 / 60.0)
		forward = maxf(forward, c.live.cargo_p("l1"))
	check(forward > 0.01, "and forward when it brakes (%.3f m)" % forward)
	run_steps(c, 8.0)
	check(absf(c.live.cargo_p("l1")) < 0.02, "at a stop the straps pull the load back to its place (%.3f)" % c.live.cargo_p("l1"))
	check(c.live.cargo_p("nothing") == 0.0, "no load, no shift")
	# a hard knock of a load against the side hurts the fragile one and only the fragile one
	var hard = fresh(true, true)
	hard.state.v = 12.0
	hard.state.brake = 1.0
	hard.state.throttle = 0.0
	run_steps(hard, 3.0)
	check(float(hard.state.cargo[1].health) == 1.0, "a log is not hurt")
	var soft = fresh(true, true)
	soft.state.throttle = 0.2
	run_steps(soft, 6.0)
	check(float(soft.state.cargo[0].health) >= 0.999, "a gentle start does not hurt the fragile load (%.3f)" % float(soft.state.cargo[0].health))
	# --- the rest of the checks of the model: reset when the train changes
	var t = fresh(true)
	run_steps(t, 1.0)
	t.live.reset()
	check(t.live.n == 0 and t.live.slack_m(1) == 0.0 and t.live.lift_m(1) == 0.0, "reset empties the layer and reads are safe")
	t.state.phase = "depot"
	t.physics_step(1.0 / 60.0)
	check(t.live.n == 0, "in the depot the layer sleeps")
	Model.live_effects = false
	print("LIVE CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
