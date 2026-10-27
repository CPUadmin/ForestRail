extends SceneTree

var game
var checks = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
		print("FAIL: ", text)

func press(position: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	game._unhandled_input(event)

func release(position: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	game._input(event)

func motion(delta: Vector2) -> void:
	var event = InputEventMouseMotion.new()
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	game._input(event)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.saves.directory = "user://qa_interaction"
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42)
	game.model.accept_mission(game.model.current_mission())
	game.screen = "game"
	game.camera_s = 0
	game.camera_x = 1040
	game.rebuild()
	await process_frame
	await RenderingServer.frame_post_draw
	check(game.cargo_hits.size() == 2 and game.slot_hits.size() == 2, "visible cargo and slot regions")
	var source = game.cargo_hits[0].rect.get_center()
	var target = game.slot_hits[0].rect.get_center()
	press(source)
	check(game.drag_item == "M01_0", "event-position cargo capture")
	release(Vector2(5, 5))
	check(game.model.state.cargo[0].slot == "", "invalid drop returns cargo")
	press(source)
	release(target)
	check(game.model.state.cargo[0].slot == "handcar:0", "drag-drop uses release event coordinates")
	await process_frame
	await RenderingServer.frame_post_draw
	for hit in game.cargo_hits:
		if hit.id == "M01_1": source = hit.rect.get_center()
	press(source)
	release(game.slot_hits[0].rect.get_center())
	check(game.model.state.cargo[1].slot == "", "occupied slot rejects drop")
	press(source)
	release(game.slot_hits[1].rect.get_center())
	check(game.model.all_loaded(), "both sacks secured")
	game.model.depart()
	game.rebuild()
	await process_frame
	await RenderingServer.frame_post_draw
	var brake_grip = Vector2.ZERO
	var pump_grip = Vector2.ZERO
	for grip in game.grip_hits:
		if grip.id == "brake": brake_grip = grip.position
		if grip.id == "pump": pump_grip = grip.position
	press(brake_grip)
	motion(Vector2(0, 140))
	release(brake_grip + Vector2(0, 140))
	check(game.model.state.brake == 0, "physical brake drag")
	press(pump_grip)
	for i in range(180):
		var target_angle = sin(i / 60.0 * TAU) * deg_to_rad(28)
		motion(Vector2(0, (target_angle - game.model.pump_angle) * 100))
		game._physics_process(1.0 / 60)
	release(pump_grip)
	check(game.model.state.v > 0.4, "mouse motion produces work through game controller")
	var v = float(game.model.state.v)
	game._physics_process(1.0 / 60)
	check(game.model.state.v > 0 and game.model.pump_work == 0, "release preserves coasting without phantom input")
	# Micro-oscillations may not be accumulated into a useful work stroke.
	game.model.state.s = 0
	game.model.state.v = 0
	game.model.reset_input()
	for i in range(600):
		game.model.pump_motion(0.008 if i % 2 == 0 else -0.008)
		game.model.physics_step(1.0 / 60)
	check(game.model.state.v == 0, "micro jitter is not useful power")
	game.drag = "pump"
	game.model.pump_motion(0.2)
	game.pause_game()
	check(game.paused and game.drag == "" and game.model.pump_pending == 0, "pause clears input capture")
	var s = float(game.model.state.s)
	game._physics_process(1)
	check(game.model.state.s == s, "pause freezes simulation")
	game.close_modal()
	game.test_mode = false
	game.focus_lost()
	check(game.paused, "focus loss pauses")
	game.test_mode = true
	game.close_modal()
	game.model.rescue()
	check(game.model.state.cargo.size() == 2 and game.model.state.active.id == "M01", "rescue keeps active loaded order")
	game.model.cancel_mission()
	game.model.state.money = 1000
	game.model.buy_vehicle("motorcar")
	check(not game.model.start_engine(true) or game.model.state.gear == 0, "neutral start")
	game.model.state.throttle = 0.5
	check(not game.model.set_gear(1), "gear cannot move under throttle")
	game.model.state.throttle = 0
	game.model.set_gear(1)
	game.model.state.engine = false
	check(not game.model.start_engine(true), "reject start in gear")
	game.model.set_gear(0)
	check(game.model.start_engine(true), "valid start")
	game.sound.update(game.model, true, false, 0.1)
	check(not game.sound.engine.playing, "engine stops on pause")
	check(game.sound.voices.size() == 6, "bounded audio voices")
	var report = {"checks": checks, "failures": failures}
	var file = FileAccess.open("user://qa_interaction/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("INTERACTION CHECKS ", checks, "; FAILURES ", failures)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
