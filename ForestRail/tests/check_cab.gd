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
	m.state.chapter = {"steam": 2, "motorcar": 5, "locomotive": 9}[kind]
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
		for kind in ["steam", "motorcar", "locomotive"]:
			context = "%s %s " % [kind, str(resolution)]
			await prepare(kind)
			check(game.ui.visible and not game.cab_active(), "outside the cab the usual screen is shown")
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
		# Steam: the fire door is opened by a click and coal is dragged to it on the dashboard.
		context = "steam parts %s " % str(resolution)
		await prepare("steam")
		await key(KEY_E)
		for i in range(6): await frame()
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
	print("CAB CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
