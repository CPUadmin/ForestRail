extends Node
# 16.11.2026: the petrol car has 3 forward gears when new; the «Коробка передач» upgrade opens the 4th (level 1)
# and the 5th (level 2). The creative mode has all five. Old saves in a closed gear go down to the highest open one.
# The gate covers a closed slot with a brass plate; the snapshots go to the output folder for the eyes.
const Model = preload("res://scripts/model.gd")
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_gears_unlock"

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func petrol(level: int):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	Fixtures.equip(m, "motorcar")
	while m.state.consist_ids.size() > 1: m.toggle_wagon(m.state.consist_ids[-1])
	m.state.fleet_by_id.motorcar.levels["motorcar_gearbox"] = level
	m.refuel()
	return m

func flat(m) -> void:
	var points: Array = []
	for x in range(-40, 20001): points.append([float(x), 0.0, float(x)])
	m.route.points = points
	m.route.length_m = 20000.0
	m.state.phase = "route"
	m.state.s = 100.0
	m.state.brake = 0.0
	m.state.direction = 1
	m.start_engine(true)

# full throttle on the flat, shifting up by the data speeds of the gears as far as the box lets; the peak in km/h
func peak_kmh(level: int) -> float:
	var m = petrol(level)
	flat(m)
	var best = 0.0
	for i in range(150 * 60):
		var g = int(m.state.gear)
		var want = 1 if g == 0 else g
		if g >= 1 and g < m.gears_open() and float(m.state.v) > float(m.vehicle_base().gears[g - 1][1]) * 0.85: want = g + 1
		if want != g:
			m.state.throttle = 0.0
			m.set_gear(want)
		m.state.throttle = 1.0
		m.physics_step(1.0 / 60.0)
		best = maxf(best, float(m.state.v))
	return best * 3.6

func model_checks() -> void:
	var m = petrol(0)
	check(m.gears_open() == 3, "a new petrol car has 3 forward gears")
	check(m.set_gear(3) and int(m.state.gear) == 3, "the 3rd gear works without the upgrade")
	check(not m.set_gear(4) and int(m.state.gear) == 3, "the 4th gear is refused without the upgrade")
	check(m.message == "4-я передача закрыта. Открой её улучшением «Коробка передач» в мастерской.", "the refusal says how to open the gear: " + m.message)
	check(not m.set_gear(5), "the 5th gear is refused without the upgrade")
	check(m.set_gear(6) and m.set_gear(0), "reverse and neutral are always there")
	m.state.fleet_by_id.motorcar.levels["motorcar_gearbox"] = 1
	check(m.gears_open() == 4 and m.set_gear(4) and int(m.state.gear) == 4, "level 1 opens the 4th gear")
	check(not m.set_gear(5) and m.message.begins_with("5-я передача закрыта"), "level 1 still refuses the 5th")
	m.state.fleet_by_id.motorcar.levels["motorcar_gearbox"] = 2
	check(m.gears_open() == 5 and m.set_gear(5) and int(m.state.gear) == 5, "level 2 opens the 5th gear")
	var creative = Model.new()
	creative.new_game(42, 2, "creative")
	creative.select_vehicle("motorcar")
	check(creative.gears_open() == 5 and creative.set_gear(5), "the creative mode has all five gears")
	# an old save driving in the 5th without the upgrade
	var old = petrol(0)
	old.state.gear = 5
	var saved = old.serialize()
	var back = Model.new()
	back.new_game(42, 2)
	check(back.restore(saved), "the old save loads")
	check(int(back.state.gear) == 3, "a save in the 5th gear without the upgrade comes back in the 3rd (got %d)" % int(back.state.gear))
	check(int(back.state.fleet_by_id.motorcar.levels.get("motorcar_gearbox", 0)) == 0, "the old save gets no free level")
	# the automatic gearbox never goes above the open gear
	var auto = petrol(0)
	auto.state.fleet_by_id.motorcar.levels["motorcar_automatic"] = 1
	check(auto.auto_gearbox(), "the automatic gearbox is fitted")
	flat(auto)
	auto.set_gear(1)
	var highest = 0
	for i in range(90 * 60):
		auto.state.throttle = 1.0
		auto.physics_step(1.0 / 60.0)
		highest = maxi(highest, int(auto.state.gear))
	check(highest == 3, "the automatic gearbox stops at the 3rd gear without the upgrade (got %d)" % highest)
	auto.state.fleet_by_id.motorcar.levels["motorcar_gearbox"] = 1
	for i in range(90 * 60):
		auto.state.throttle = 1.0
		auto.physics_step(1.0 / 60.0)
		highest = maxi(highest, int(auto.state.gear))
	check(highest == 4, "with level 1 the automatic gearbox goes up to the 4th, not the 5th (got %d)" % highest)
	# the stated top speed follows the open gears, and the car really reaches it
	var tops = []
	for level in [0, 1, 2]: tops.append(petrol(level).top_speed_kmh())
	check(tops == [71.0, 108.0, 120.0], "the top speed follows the open gears: %s" % str(tops))
	for level in [0, 1]:
		var got = peak_kmh(level)
		print("GEARS PEAK level ", level, ": ", snappedf(got, 0.1), " km/h")
		check(absf(got - float(tops[level])) <= 2.0, "level %d reaches its stated %.0f km/h (got %.1f)" % [level, tops[level], got])
	var full = peak_kmh(2)
	print("GEARS PEAK level 2: ", snappedf(full, 0.1), " km/h")
	check(full >= 118.0, "with both levels the car reaches the class top of 120 km/h (got %.1f)" % full)

func shot(name: String) -> void:
	for i in range(8): await get_tree().process_frame
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	print("VISUAL ", name)

func view_checks() -> void:
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	game.model.new_game(42)
	game.model.state.money = 5000
	game.model.state.chapter = 4
	Fixtures.equip(game.model, "motorcar")
	var car = game.model.state.fleet_by_id.motorcar
	# the workshop card and the garage line
	var branch = {}
	for item in game.model.data.upgrade_catalog:
		if item.id == "motorcar_gearbox": branch = item
	check(branch.level_costs == [90.0, 180.0] or branch.level_costs == [90, 180], "the gearbox upgrade costs 90 and 180")
	var card = game.depot_ui().upgrade_preview("motorcar", branch)
	check(card.begins_with("Открывает 4-ю передачу: до 108 км/ч\n"), "the level 1 card says first that it opens the 4th: " + card.replace("\n", " | "))
	check(game.depot_ui().garage_line().contains("до 71 км/ч"), "the garage line shows 71 km/h without the upgrade: " + game.depot_ui().garage_line())
	car.levels["motorcar_gearbox"] = 1
	card = game.depot_ui().upgrade_preview("motorcar", branch)
	check(card.begins_with("Открывает 5-ю передачу: до 120 км/ч\n"), "the level 2 card says first that it opens the 5th: " + card.replace("\n", " | "))
	check(game.depot_ui().garage_line().contains("до 108 км/ч"), "the garage line shows 108 km/h with level 1: " + game.depot_ui().garage_line())
	car.levels["motorcar_gearbox"] = 0
	# the gate: the plate stops the knob, and the notice comes not more often than once a second
	check(game.closed_gate_gear(Vector2(1, 0.9)) == 4 and game.closed_gate_gear(Vector2(2, -0.9)) == 5, "the knob in the 4th or the 5th slot hits a plate")
	check(game.closed_gate_gear(Vector2(1, -0.9)) == 0 and game.closed_gate_gear(Vector2(2, 0.9)) == 0, "the 3rd and the reverse are open")
	game.toast = ""
	game.gate_bump(4)
	check(game.toast == game.model.closed_gear_text(4), "the plate gives the notice")
	game.toast = ""
	game.gate_bump(4)
	check(game.toast == "", "the notice is not repeated within a second")
	game.model.accept_mission(game.model.current_mission())
	for i in range(mini(game.model.state.cargo.size(), game.model.slots().size())): game.model.transfer(game.model.state.cargo[i].id, game.model.slots()[i].key)
	game.screen = "game"
	game.camera_s = float(game.model.state.s)
	game.camera_x = 1040
	game.rebuild()
	await get_tree().create_timer(0.2).timeout
	game.model.start_engine(true)
	game.model.set_gear(3)
	for level in [0, 1, 2]:
		car.levels["motorcar_gearbox"] = level
		check(game.closed_gate_gear(Vector2(1, 0.9)) == (4 if level == 0 else 0), "level %d: the 4th slot plate" % level)
		check(game.closed_gate_gear(Vector2(2, -0.9)) == (5 if level < 2 else 0), "level %d: the 5th slot plate" % level)
		await shot("gate_level%d_outside" % level)
		game.cab_view = true
		game.update_pult_transform()
		await shot("gate_level%d_cab" % level)
		var rect = game.gate_rect(true)
		print("GATE CAB RECT ", game.pult_t * rect.position, " ", rect.size * game.pult_t.get_scale())
		game.cab_view = false
		game.update_pult_transform()

func run() -> void:
	var args = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	model_checks()
	await view_checks()
	print("GEARS UNLOCK CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
