extends Node
# Живые эффекты в мире (scripts/fx.gd): дым остаётся позади едущего поезда, у стоящего поднимается вверх,
# частиц не больше предела, с заглушённой машиной ничего не выходит.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

# the trip in calm air: the train is moved by hand at a fixed speed, the effects are stepped at 60 Hz
func drive(speed: float, seconds: float) -> int:
	var fx = game.fx()
	var most = 0
	var dt = 1.0 / 60.0
	for i in range(int(seconds * 60.0)):
		game.model.state.s = float(game.model.state.s) + speed * float(int(game.model.state.direction)) * dt
		game.model.state.v = speed * float(int(game.model.state.direction))
		game.model.state.stats.distance = 10.0   # no cylinder cloud in these checks
		fx.update(dt)
		most = maxi(most, fx.count())
	return most

func stack_world(id: String = "steam") -> Vector2:
	var fx = game.fx()
	var local = game.art.steam_stack_local() if id == "steam" else game.art.petrol_stack_local()
	return fx.to_world(fx.body_s_of(id), local)

func mean_s() -> float:
	var fx = game.fx()
	var total = 0.0
	for i in range(fx.count()): total += fx.p_s[i]
	return total / maxf(1.0, float(fx.count()))

func mean_h() -> float:
	var fx = game.fx()
	var total = 0.0
	for i in range(fx.count()): total += fx.p_h[i]
	return total / maxf(1.0, float(fx.count()))

func start(kind: String, direction: int) -> void:
	var m = game.model
	m.state.phase = "depot"
	m.state.v = 0.0
	Fixtures.equip(m, kind)
	if m.vehicle_id() != kind: failures.append("could not take the " + kind)
	Fixtures.fire_up(m)
	m.state.phase = "route"
	m.state.engine = true
	m.state.throttle = 0.6
	m.state.direction = direction
	m.state.s = 1000.0
	m.state.v = 0.0
	if m.state.fleet_by_id.has("steam"): m.state.fleet_by_id.steam.venting = false
	game.camera_s = 1000.0
	game.fx().clear()
	game.fx().wind_scale = 0.0

func run() -> void:
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.set_process(false)   # the effects are stepped by the check, not by the frames
	game.saves.directory = "user://qa_fx"
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42, 2)
	game.model.state.money = 500000
	game.model.state.chapter = 9
	game.screen = "game"
	var fx = game.fx()
	var cap = fx.CAP

	# forward at 10 m/s: the smoke is left behind the chimney
	start("steam", 1)
	var most = drive(10.0, 3.0)
	var stack = stack_world()
	check(fx.count() > 10, "a working steam engine smokes (%d puffs)" % fx.count())
	check(mean_s() < stack.x - 3.0, "going forward the smoke stays behind (mean %.1f m, chimney %.1f m)" % [mean_s(), stack.x])
	check(most <= cap, "no more than %d puffs (%d)" % [cap, most])

	# the same backwards (the machine faces the other way): the smoke is on the other side
	start("steam", -1)
	drive(10.0, 3.0)
	stack = stack_world()
	check(mean_s() > stack.x + 3.0, "going the other way the smoke stays behind on the other side (mean %.1f m, chimney %.1f m)" % [mean_s(), stack.x])

	# standing in calm air: the smoke rises straight above the chimney
	start("steam", 1)
	drive(0.0, 1.0)
	var low = mean_h()
	drive(0.0, 2.0)
	stack = stack_world()
	check(absf(mean_s() - stack.x) < 0.3, "standing, the smoke stays over the chimney (%.2f m off)" % (mean_s() - stack.x))
	check(mean_h() > stack.y + 0.5 and mean_h() > low, "standing, the smoke rises (%.2f m over the rail, chimney %.2f m)" % [mean_h(), stack.y])

	# wind from behind a standing train: the smoke leans ahead with the air
	start("steam", 1)
	fx.wind_scale = 1.0
	var wind_world = float(game.model.wind_here(1000.0).x) * float(int(game.model.state.direction))
	drive(0.0, 3.0)
	if absf(wind_world) > 1.0:
		check(signf(mean_s() - stack_world().x) == signf(wind_world), "standing in wind %.1f m/s, the smoke leans with it (%.2f m)" % [wind_world, mean_s() - stack_world().x])
	fx.wind_scale = 0.0

	# braking: the trail is shorter than at full speed
	start("steam", 1)
	drive(14.0, 3.0)
	var fast_span = stack_world().x - mean_s()
	start("steam", 1)
	drive(3.0, 3.0)
	var slow_span = stack_world().x - mean_s()
	check(slow_span < fast_span, "a slower train leaves a shorter trail (%.1f m against %.1f m)" % [slow_span, fast_span])

	# the cap: many puffs at once never go over it; the reduced setting has a smaller one
	start("steam", 1)
	for i in range(cap + 150): fx.spawn(1000.0, 3.0, 0.0, 1.0, 5.0, 0.1, 0.5, 0.5, Color.WHITE, 1.0)
	check(fx.count() == cap, "the cap holds (%d)" % fx.count())
	game.settings.reduce_motion = true
	fx.clear()
	for i in range(cap + 150): fx.spawn(1000.0, 3.0, 0.0, 1.0, 5.0, 0.1, 0.5, 0.5, Color.WHITE, 1.0)
	check(fx.count() == fx.CAP_REDUCED, "with less motion the cap is smaller (%d)" % fx.count())
	game.settings.reduce_motion = false

	# the engine off: nothing comes out
	start("steam", 1)
	game.model.state.engine = false
	game.model.cool_boiler()
	drive(10.0, 2.0)
	check(fx.count() == 0, "a cold engine makes no smoke (%d)" % fx.count())

	# the safety valve blows white steam even with the regulator shut
	start("steam", 1)
	game.model.state.fleet_by_id.steam.venting = true
	game.model.state.engine = false
	drive(0.0, 1.0)
	check(fx.count() > 5, "the safety valve vents (%d puffs)" % fx.count())

	# the petrol car: the exhaust trails behind too, and stops with the engine
	start("motorcar", 1)
	drive(10.0, 3.0)
	var pipe = stack_world("motorcar")
	check(fx.count() > 5 and mean_s() < pipe.x - 2.0, "the petrol exhaust stays behind (mean %.1f m, pipe %.1f m)" % [mean_s(), pipe.x])
	start("motorcar", 1)
	game.model.state.engine = false
	drive(10.0, 2.0)
	check(fx.count() == 0, "the petrol engine off makes no exhaust (%d)" % fx.count())

	# a new screen starts clean
	start("steam", 1)
	drive(0.0, 1.0)
	game.screen = "depot"
	fx.update(1.0 / 60.0)
	game.screen = "game"
	fx.update(1.0 / 60.0)
	check(fx.count() <= 2, "the puffs are cleared when the screen changes (%d)" % fx.count())

	print("FX CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
