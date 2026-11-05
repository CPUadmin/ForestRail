extends Node
# В6.5, шаг 2: цеппелин в модели игры (Model): скрыт из гаража, покупается, едет по physics_step, рычаги шага и джойстика
# держат положение, топливо расходуется, взлёт на 130 км/ч, крушение: возврат в депо и штраф 50% монет.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh():
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, "zeppelin")
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	m.state.phase = "route"
	m.state.brake = 0.0
	m.state.reverser = 1
	m.state.direction = 1
	return m

func drive(m, seconds: float, follow_pitch: bool = true) -> void:
	for i in range(int(seconds * 60.0)):
		if follow_pitch:
			m.set_zeppelin_pitch(clampf((absf(float(m.state.v)) + 3.0 - 10.0) / 24.0, 0.0, 1.0))
		m.physics_step(1.0 / 60.0)
		if m.zep.crashed: break

func run() -> void:
	var m = fresh()
	check(m.vehicle_id() == "zeppelin", "the zeppelin can be bought and chosen")
	check("zeppelin" in m.HIDDEN_VEHICLE_IDS and "zeppelin" not in m.VEHICLE_IDS, "it is hidden from the garage until the cab and the picture are ready")
	check(m.vehicle_base("zeppelin").top_speed_kmh == 135, "the data: top speed 135 km/h")
	# the levers hold their positions
	check(m.set_zeppelin_pitch(0.7) and is_equal_approx(m.zeppelin_pitch(), 0.7), "the pitch lever is set")
	check(m.set_zeppelin_stick(3.5) and is_equal_approx(m.zeppelin_stick(), 3.5), "the joystick is set to +3.5 degrees")
	m.set_zeppelin_pitch(0.0)
	m.set_zeppelin_stick(0.0)
	for i in range(120): m.physics_step(1.0 / 60.0)
	check(is_equal_approx(m.zeppelin_stick(), 0.0) and is_equal_approx(m.zeppelin_pitch(), 0.0), "with the hands off the levers stay where they were left")
	check(m.set_zeppelin_stick(100.0) and m.zeppelin_stick() == 12.0, "the stick is limited to +12 degrees")
	m.set_zeppelin_stick(0.0)
	# a stranger machine cannot use the zeppelin levers
	var other = Model.new()
	other.new_game(7, 2)
	check(not other.set_zeppelin_pitch(0.5) and not other.set_zeppelin_stick(1.0), "on another machine the zeppelin levers do nothing")
	# a run on the rail: speed rises, the fuel falls, no flight with the nose level
	var run = fresh()
	var fuel0 = float(run.state.fleet_by_id.zeppelin.fuel)
	run.state.engine = true
	run.state.throttle = 1.0
	run.state.brake = 0.0
	drive(run, 40.0)
	check(float(run.state.v) > 20.0, "the zeppelin accelerates on the rail (%.1f m/s)" % float(run.state.v))
	check(float(run.state.s) > 100.0, "and moves along the line (%.0f m)" % float(run.state.s))
	check(float(run.state.fleet_by_id.zeppelin.fuel) < fuel0, "the petrol is spent")
	check(not run.air_fly and not run.zep.crashed, "the nose level: no flight")
	# the takeoff: about 130 km/h, the nose up
	var fly = fresh()
	fly.state.engine = true
	fly.state.throttle = 1.0
	fly.state.s = 0.0
	drive(fly, 90.0)
	var cruise = float(fly.state.v) * 3.6
	check(cruise > 115.0 and not fly.air_fly, "on the rail at over 115 km/h (%.0f)" % cruise)
	fly.set_zeppelin_stick(4.0)
	var lifted = false
	for i in range(60 * 4):
		fly.set_zeppelin_pitch(clampf((absf(float(fly.state.v)) - 7.0) / 24.0, 0.0, 1.0))
		fly.physics_step(1.0 / 60.0)
		if fly.air_fly: lifted = true
		if fly.zep.crashed: break
	check(lifted or fly.zep.crashed, "the nose up at speed: it lifts off the rail")
	# the crash: 50% of the money (at least 300), back to the depot, no game over
	var crash = fresh()
	crash.state.engine = true
	crash.state.throttle = 1.0
	crash.state.s = 2000.0
	crash.state.money = 1000
	crash.state.v = 36.0
	crash.zep.v = 36.0
	crash.set_zeppelin_stick(12.0)
	var crashed = false
	var before = 1000
	for i in range(60 * 20):
		crash.set_zeppelin_pitch(0.5)
		before = int(crash.state.money)
		crash.physics_step(1.0 / 60.0)
		if crash.message.begins_with("Крушение"):
			crashed = true
			break
	check(crashed, "the climb into the treetops is a crash that costs money")
	if crashed:
		# the rescue refuels the tank afterwards, as for every machine (a few coins)
		var left = before - maxi(300, int(round(before * 0.5)))
		check(int(crash.state.money) <= left and int(crash.state.money) > left - 40 and "Штраф 500" in crash.message, "the penalty is half of the money (%d of %d left)" % [int(crash.state.money), before])
		check(float(crash.state.s) == float(crash.route.station_s[0]) and float(crash.state.v) == 0.0, "the machine is back at the depot, stopped")
		check(not crash.air_fly and is_equal_approx(crash.zeppelin_stick(), 0.0), "the flight and the joystick are reset")
		check(crash.message.begins_with("Крушение"), "the message says what happened")
	print("ZEPPELIN MODEL CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
