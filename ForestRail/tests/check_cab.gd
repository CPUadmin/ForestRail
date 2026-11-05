extends Node
# Cab scene on E: the whole screen becomes the cab, the track ahead is seen through
# the glass and the dashboard carries the working pult (same states as outside).
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var checks = 0
var failures: Array = []
var out_dir = ""
var context = ""

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(context + label); print("FAIL: ", context, label)

func frame() -> void:
	game.update_hud()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func mouse(point: Vector2, pressed: bool) -> void:
	var e = InputEventMouseButton.new()
	e.position = point
	e.global_position = point
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	get_tree().root.push_input(e, true)
	await frame()

func move(to: Vector2, from: Vector2) -> void:
	var e = InputEventMouseMotion.new()
	e.position = to
	e.relative = to - from
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(e, true)
	await frame()

func key(code: int) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	get_tree().root.push_input(e, true)
	await frame()

func shot(name: String) -> void:
	await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func prepare(kind: String) -> void:
	var m = Model.new()
	m.new_game(42)
	m.state.money = 10000
	m.state.chapter = {"steam": 2, "motorcar": 5, "pneumatic": 5, "locomotive": 9}[kind]
	Fixtures.equip(m, kind)
	m.state.phase = "route"
	m.state.s = 100.0
	m.state.brake = 0.0
	for p in m.route.points: p[1] = 0.0
	game.model = m
	game.screen = "game"
	game.cab_view = false
	game.camera_s = 100.0
	game.camera_x = game.get_viewport_rect().size.x * 0.65
	game.rebuild()
	for i in range(6): await frame()

func grip(id: String) -> Vector2:
	for hit in game.grip_hits:
		if hit.id == id and hit.get("closeup", false): return hit.position
	return Vector2.ZERO

func run() -> void:
	out_dir = ProjectSettings.globalize_path("res://../qa/cab_view")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cab-output="): out_dir = arg.trim_prefix("--cab-output=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = out_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	for resolution in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = resolution
		await get_tree().create_timer(0.2).timeout
		var view = Rect2(Vector2.ZERO, game.get_viewport_rect().size)
		for kind in ["steam", "motorcar", "pneumatic", "locomotive"]:
			context = "%s %s " % [kind, str(resolution)]
			await prepare(kind)
			check(game.ui.visible and not game.cab_active(), "outside the cab the usual screen is shown")
			await shot("outside_%s_%d" % [kind, resolution.y])
			await key(KEY_E)
			for i in range(10): await frame()
			check(game.cab_active() and not game.ui.visible, "E opens the cab and covers the rest of the screen")
			check(game.pult_t.get_scale().x >= 0.9, "dashboard pult is about life size or larger")
			var seen: Array = []
			for hit in game.grip_hits:
				if not hit.get("closeup", false): continue
				seen.append(hit.id)
				check(view.has_point(hit.position), "dashboard grip %s is on screen" % hit.id)
			for id in game.control_ids(): check(id in seen, "dashboard has " + id)
			check(game.cab_exit_rect.size.x > 0 and view.encloses(game.cab_exit_rect), "exit button is on screen")
			check(game.cab_sides.size() == 2 and game.cab_sides[0].visible and game.cab_sides[1].visible, "both side windows show in the cab")
			for window in game.cab_sides: check(view.encloses(Rect2(window.position, window.size)), "side window is on screen")
			game.model.state.v = 4.0
			game.cab_jolt = 1.0
			for i in range(8): await frame()
			check(game.needle_state.size() >= 2, "gauge needles keep their own spring state")
			check(is_finite(game.cab_shake().x) and is_finite(game.cab_shake().y), "cab shake is a finite offset")
			game.model.state.v = 0.0
			await shot("cab_%s_%d" % [kind, resolution.y])
			# The brake is pulled with the mouse on the dashboard: the lever follows, drop keeps it.
			var brake_at = grip("brake")
			await mouse(brake_at, true)
			check(game.drag == "brake", "mouse grabs the brake on the dashboard")
			await move(brake_at + Vector2(60, -10), brake_at)
			check(game.drag == "brake" and float(game.model.state.brake) != 0.0, "dragging the lever changes the brake")
			var kept = float(game.model.state.brake)
			await key(KEY_E)
			check(game.drag == "" and not game.cab_active() and absf(float(game.model.state.brake) - kept) < 0.0001, "E drops the grab and keeps the lever position")
			for i in range(6): await frame()
			check(game.ui.visible, "the usual screen is back after the cab")
		# Petrol: the gear gate works on the dashboard.
		context = "motorcar gate %s " % str(resolution)
		await prepare("motorcar")
		game.model.state.brake = 1.0
		game.model.start_engine(true)
		await key(KEY_E)
		for i in range(6): await frame()
		var knob = grip("gear")
		await mouse(knob, true)
		check(game.drag == "gear", "gear knob is grabbed on the dashboard")
		var rect = game.gate_rect(true)
		var here = game.gate_pos
		var slot = game.gate_slot_pos(1)
		var current = game.pult_t * game.gate_local(rect, here)
		for waypoint in [Vector2(here.x, 0), Vector2(slot.x, 0), slot]:
			var target = game.pult_t * game.gate_local(rect, waypoint)
			await move(target, current)
			current = target
		await mouse(current, false)
		check(int(game.model.state.gear) == 1, "the knob dragged through the gate selects first gear")
		await key(KEY_E)
		# Electric: the direction switch and the emergency stop are real buttons.
		context = "electric buttons %s " % str(resolution)
		await prepare("locomotive")
		game.model.state.engine = true
		await frame()
		check(game.electric_start_flash > 0.0, "electric power-on starts a brief flash")
		if resolution.y == 900: await shot("electric_start_flash")
		game.model.state.brake = 1.0
		await key(KEY_E)
		for i in range(6): await frame()
		var forward_rect = Rect2()
		var back_rect = Rect2()
		var emergency_rect = Rect2()
		for hit in game.cab_hits:
			if hit.id == "forward": forward_rect = hit.rect
			elif hit.id == "back": back_rect = hit.rect
			elif hit.id == "emergency": emergency_rect = hit.rect
		check(view.encloses(forward_rect) and view.encloses(back_rect) and view.encloses(emergency_rect), "direction and emergency buttons are on screen")
		await mouse(back_rect.get_center(), true)
		await mouse(back_rect.get_center(), false)
		check(int(game.model.state.reverser) == -1, "the back button reverses the traction")
		await mouse(forward_rect.get_center(), true)
		await mouse(forward_rect.get_center(), false)
		check(int(game.model.state.reverser) == 1, "the forward button restores it")
		game.model.state.brake = 0.0
		game.model.state.throttle = 0.6
		await mouse(emergency_rect.get_center(), true)
		await mouse(emergency_rect.get_center(), false)
		check(float(game.model.state.brake) == 1.0 and float(game.model.state.throttle) == 0.0, "the emergency stop drops traction and brakes")
		await key(KEY_E)
		for i in range(6): await frame()
		# Steam: the fire door is opened by a click and coal is dragged to it on the dashboard.
		context = "steam parts %s " % str(resolution)
		await prepare("steam")
		await key(KEY_E)
		for i in range(6): await frame()
		var whistle := Rect2()
		for hit in game.cab_hits:
			if hit.id == "whistle": whistle = hit.rect
		check(whistle.has_area() and view.encloses(whistle), "steam whistle cord has a visible click target")
		var whistles = int(game.sound.played.get("whistle", 0))
		await mouse(whistle.get_center(), true)
		await mouse(whistle.get_center(), false)
		check(game.whistle_pull > 0.0 and int(game.sound.played.get("whistle", 0)) == whistles + 1, "click pulls the cord and plays the steam whistle")
		if resolution.y == 900: await shot("steam_whistle")
		var door = Rect2()
		var bucket = Rect2()
		for hit in game.steam_hits:
			if hit.id == "door": door = hit.rect
			else: bucket = hit.rect
		check(view.encloses(door) and view.encloses(bucket), "bucket and door buttons are on screen")
		await mouse(door.get_center(), true)
		await mouse(door.get_center(), false)
		check(bool(game.model.boiler().door), "click opens the fire door")
		var coal_before = float(game.model.state.fleet_by_id.steam.fuel)
		var fire = game.steam_fire_rect(game.control_zoom_rect())
		var fire_centre = game.pult_t * (fire.position + fire.size * 0.5)
		await mouse(bucket.get_center(), true)
		check(game.drag == "coal", "coal is grabbed on the dashboard")
		await move(fire_centre, bucket.get_center())
		await mouse(fire_centre, false)
		check(float(game.model.state.fleet_by_id.steam.fuel) < coal_before and float(game.model.boiler().firebox) > 0.0, "coal dropped on the firebox goes in")
		await key(KEY_E)
	# B3.1 / B3.2: no pult any more; the cab goes down by itself at a platform and comes back when the train moves off
	context = "auto "
	await prepare("motorcar")
	for button in game.ui.find_children("*", "Button", true, false): check(not button.text.begins_with("Пульт"), "no pult button in the header")
	check(not game.settings.keys.has("pult"), "no pult key in the settings")
	await key(KEY_E)
	for i in range(4): await frame()
	check(game.cab_active(), "E raises the cab")
	game.model.state.s = float(game.model.route.station_s[1])
	game.model.state.v = 0.0
	game.model.state.brake = 1.0
	for i in range(4): await frame()
	check(not game.cab_view and game.cab_resume, "stopping at a platform lowers the cab")
	game.model.state.brake = 0.0
	game.model.state.v = 2.0
	game.model.state.s += 40.0
	for i in range(4): await frame()
	check(game.cab_view and not game.cab_resume, "moving off raises the cab again")
	await key(KEY_E)
	game.model.state.s = float(game.model.route.station_s[2])
	game.model.state.v = 0.0
	game.model.state.brake = 1.0
	for i in range(4): await frame()
	await key(KEY_E)
	for i in range(4): await frame()
	check(game.cab_view, "the cab raised by hand at a platform stays")
	# the petrol dashboard: lamp, wipers and horn buttons really work
	context = "petrol buttons "
	await prepare("motorcar")
	await key(KEY_E)
	for i in range(8): await frame()
	var wanted = {}
	for hit in game.cab_hits:
		if hit.id in ["light", "wiper", "whistle"]: wanted[hit.id] = hit.rect
	check(wanted.size() == 3 and game.get_viewport_rect().encloses(wanted.light) and game.get_viewport_rect().encloses(wanted.whistle), "the three buttons are on the dashboard and on the screen")
	var lit_before = game.lights_lit()
	await mouse(wanted.light.get_center(), true)
	await mouse(wanted.light.get_center(), false)
	check(game.lights_lit() != lit_before and game.lamp_manual >= 0, "the lamp button switches the headlamp")
	await mouse(wanted.wiper.get_center(), true)
	await mouse(wanted.wiper.get_center(), false)
	check(game.wiper_on, "the wiper button switches the wipers on")
	game.wiper_phase = 0.45
	await shot("petrol_wipers_sweep")
	await mouse(wanted.whistle.get_center(), true)
	await mouse(wanted.whistle.get_center(), false)
	check(game.cab_active(), "the horn button leaves the cab as it was")
	game.model.state.stats.seconds = 18.0 * 60.0
	game.lamp_manual = 1
	for i in range(6): await frame()
	await shot("petrol_night_lamp")
	game.lamp_manual = -1
	game.wiper_phase = 0.97
	game.wiper_on = false
	await get_tree().create_timer(0.12).timeout
	check(game.wiper_phase == 0.0, "wipers complete the pass and park when switched off")
	await key(KEY_E)
	# B4.1: the time of day. A day is 24 minutes of driving, it starts at seven and is the same for a save.
	context = "daynight "
	var clock = Model.new()
	clock.new_game(42)
	check(is_equal_approx(clock.world_hours(), 7.0) and clock.daylight() > 0.7, "the day starts at seven in the morning, in the light")
	clock.state.stats.seconds = 6.0 * 60.0
	check(is_equal_approx(clock.world_hours(), 13.0) and is_equal_approx(clock.daylight(), 1.0) and clock.night_amount() == 0.0, "at one o'clock it is full day")
	clock.state.stats.seconds = 18.0 * 60.0
	check(is_equal_approx(clock.world_hours(), 1.0) and clock.daylight() == 0.0 and clock.night_amount() == 1.0, "at one at night it is dark")
	clock.state.stats.seconds = 1440.0
	check(is_equal_approx(clock.world_hours(), 7.0), "a day later it is seven again")
	clock.state.stats.seconds = 23.5 * 60.0 * 24.0 / 24.0
	check(clock.twilight() >= 0.0 and clock.clock_text().length() == 5, "the clock reads as hh:mm (%s)" % clock.clock_text())
	var round_trip = Model.new()
	round_trip.new_game(42)
	var saved = clock.serialize()
	check(round_trip.restore(saved) and is_equal_approx(round_trip.world_hours(), clock.world_hours()), "a save knows the hour")
	await prepare("motorcar")
	game.model.state.stats.seconds = 18.0 * 60.0
	game.model.state.engine = true
	for i in range(8): await frame()
	await shot("night_outside_motorcar")
	await key(KEY_E)
	for i in range(8): await frame()
	await shot("night_cab_motorcar")
	check(game.cab_active(), "the cab works at night")
	await key(KEY_E)
	game.model.state.stats.seconds = 11.5 * 60.0
	for i in range(6): await frame()
	await shot("dusk_outside_motorcar")
	# B4.2: the weather is the same for the same career and the same time, starts clear, and has all its kinds
	context = "weather "
	var w1 = Model.new()
	w1.new_game(42)
	var w2 = Model.new()
	w2.new_game(42)
	var w3 = Model.new()
	w3.new_game(77)
	check(str(w1.weather_at(500.0)) == str(w2.weather_at(500.0)), "the same career gives the same weather")
	var different = false
	for k in range(40): different = different or str(w1.weather_at(100.0 * k)) != str(w3.weather_at(100.0 * k))
	check(different, "another career has other weather")
	check(float(w1.weather_at(0.0).cloud) == 0.0 and float(w1.weather_at(0.0).rain) == 0.0 and float(w1.weather_at(0.0).fog) == 0.0, "a new career starts in clear weather")
	var rainy = 0
	var foggy = 0
	var cloudy = 0
	var samples = 0
	var rain_at = -1.0
	var fog_at = -1.0
	for k in range(0, 40 * 1440, 60):
		var w = w1.weather_at(float(k))
		samples += 1
		if float(w.rain) > 0.35: rainy += 1
		if float(w.fog) > 0.4: foggy += 1
		if float(w.cloud) > 0.45: cloudy += 1
		if float(w.rain) > 0.7 and rain_at < 0.0: rain_at = float(k)
		if float(w.fog) > 0.6 and fog_at < 0.0: fog_at = float(k)
		check(float(w.cloud) >= 0.0 and float(w.cloud) <= 1.0 and float(w.rain) >= 0.0 and float(w.rain) <= 1.0 and float(w.fog) >= 0.0 and float(w.fog) <= 1.0, "weather stays in 0..1")
	check(float(rainy) / samples > 0.03 and float(rainy) / samples < 0.4, "it rains sometimes but not always (%.0f%% of the time)" % (100.0 * rainy / samples))
	check(float(cloudy) / samples > 0.1 and float(cloudy) / samples < 0.7, "clouds come and go (%.0f%%)" % (100.0 * cloudy / samples))
	check(foggy > 0 and rain_at >= 0.0 and fog_at >= 0.0, "there is fog and heavy rain in forty days (fog %d samples)" % foggy)
	await prepare("motorcar")
	game.model.state.engine = true
	if rain_at >= 0.0:
		game.model.state.stats.seconds = rain_at
		for i in range(8): await frame()
		check(game.model.weather_name() == "дождь", "the hud names the rain")
		await shot("rain_outside_motorcar")
		await key(KEY_E)
		for i in range(8): await frame()
		await shot("rain_cab_motorcar")
		await key(KEY_E)
	if fog_at >= 0.0:
		game.model.state.stats.seconds = fog_at
		for i in range(8): await frame()
		await shot("fog_outside_motorcar")
	game.model.route = w1.route
	game.model.state.stats.seconds = 0.0
	var uphill = 100.0
	var downhill = 100.0
	for s in range(100, int(w1.route.length_m) - 100, 10):
		if w1.route.slope(s) > w1.route.slope(uphill): uphill = float(s)
		if w1.route.slope(s) < w1.route.slope(downhill): downhill = float(s)
	check(w1.route.slope(uphill) > 0.01 and w1.route.slope(downhill) < -0.01, "the route has uphill and downhill views")
	await key(KEY_E)
	for grade in [["uphill", uphill], ["downhill", downhill]]:
		game.model.state.s = grade[1]
		await shot("cab_" + grade[0])
	for index in [1, 4, 5]:
		game.model.state.s = float(game.model.route.station_s[index]) - 14.0
		await shot("cab_station_" + game.model.data.stations[index].id)
	print("CAB CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
