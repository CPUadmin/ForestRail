extends Node
# 1.4.14 Спичка в кабине паровоза (окно): коробок на месте «Розжига», клик даёт спичку, крупная тёрка; медленный взмах
# царапает, резкий ломает, в меру — горит; горящую спичку несут к топке: при закрытой дверце не разжечь, при открытой
# огонь загорается; рывок задувает. Снимки для глаз при 1280x720 и 1600x900. Скорость взмаха задаётся тестом
# (motion с dt 1/60), чтобы не зависеть от частоты кадров окна.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const DT = 1.0 / 60.0

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_matches_view"

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func frame() -> void:
	game.update_hud()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	for i in range(3): await frame()
	get_tree().root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	print("VISUAL ", name)

func button(point: Vector2, pressed: bool) -> void:
	var e = InputEventMouseButton.new()
	e.position = point; e.global_position = point; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_tree().root.push_input(e, true)
	await frame()

func click(point: Vector2) -> void:
	await button(point, true)
	await button(point, false)

func key(code: int) -> void:
	var e = InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.pressed = true
	get_tree().root.push_input(e, true)
	e.pressed = false
	get_tree().root.push_input(e, true)

func move_match(point: Vector2) -> void:
	var e = InputEventMouseMotion.new()
	e.position = point
	e.global_position = point
	e.relative = point - game.match_view().pos
	get_tree().root.push_input(e, true)
	game.match_view().process(DT)

func box_point() -> Vector2:
	for hit in game.grip_hits:
		if hit.id == "start" and hit.get("closeup", false): return hit.position
	return Vector2.ZERO

# a match in hand that is not damp (the damp ones go back into the box)
func take_fresh() -> void:
	for i in range(30):
		await click(box_point())
		if game.model.matches().hand == "fresh": return
		key(KEY_ESCAPE)

# a pass of the match along the striker (nothing held: the cursor just moves) over `frames` frames of 1/60 s
func stroke(share: float, frames: int) -> void:
	var v = game.match_view()
	var s = v.striker_rect()
	var from = Vector2(s.position.x + s.size.x * 0.08, s.get_center().y)
	var to = from + Vector2(s.size.x * share, 0)
	move_match(from)
	for i in range(60): v.process(DT)   # The player may aim before starting the stroke.
	for i in range(1, frames + 1):
		move_match(from.lerp(to, float(i) / float(frames)))
	await frame()

func double_click(point: Vector2) -> void:
	var e = InputEventMouseButton.new()
	e.position = point; e.global_position = point; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true; e.double_click = true
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(e, true)
	await frame()
	await button(point, false)

# carry the hand smoothly to a point, a frame at a time
func carry(to: Vector2, frames: int) -> void:
	var v = game.match_view()
	var from = v.pos
	for i in range(1, frames + 1):
		move_match(from.lerp(to, float(i) / float(frames)))

func fixture():
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 10000
	Fixtures.equip(m, "steam")
	m.select_vehicle("steam")
	m.state.phase = "route"
	m.state.s = 100
	m.state.brake = 1.0
	m.state.throttle = 0.0
	var b = m.boiler()
	b.firebox = 0.0
	b.lit = false
	b.door = false
	m.state.engine = false
	return m

func turn_from_right_edge(id: String) -> void:
	var geo = game.control_geometry(id, true)
	var right = game.pult_t * (geo.pivot + Vector2.RIGHT * geo.radius)
	var down = game.pult_t * (geo.pivot + Vector2.DOWN * geo.radius)
	await button(right, true)
	check(game.drag == id, "the visible right rim can be grabbed: " + id)
	var e = InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = down
	e.global_position = down
	e.relative = down - right
	get_tree().root.push_input(e, true)
	await button(down, false)
	var value = float(game.model.boiler().feed) if id == "gear" else float(game.model.state.throttle)
	check(is_equal_approx(value, PI * 0.5 / game.wheel_sweep()), "a quarter turn on the rim gives a quarter turn: " + id)

func run() -> void:
	var args = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.set_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.match_in_tests = true
	Model.match_rules = true
	for size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		var tag = str(size.x)
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.model = fixture()
		game.toast_seconds = 0.0
		game.screen = "game"
		game.rebuild()
		game.camera_s = 100; game.camera_y = 0; game.camera_x = game.get_viewport_rect().size.x * 0.65
		key(KEY_E)
		game._process(DT)
		for i in range(8): await frame()
		check(game.cab_active() and game.control_kind("start") == "matchbox", "the cab of the steam locomotive has the box of matches " + tag)
		check(box_point() != Vector2.ZERO, "the box has its place on the pult " + tag)
		var door = Rect2()
		var bucket = Rect2()
		for hit in game.steam_hits:
			if hit.id == "door": door = hit.rect
			if hit.id == "bucket": bucket = hit.rect
		await click(door.get_center())
		await button(bucket.get_center(), true)
		await button(game.match_view().fire_rect().get_center(), false)
		check(game.model.boiler().firebox >= game.model.boiler_cfg().min_fire_kg, "coal from the bucket reaches the open firebox " + tag)
		await click(door.get_center())
		await shot("cab_box_" + tag)
		if game.steam_cab().revised():
			game.model.set_feed(0)
			await turn_from_right_edge("gear")
			await turn_from_right_edge("throttle")
		var f = game.model.matches()
		await take_fresh()
		check(f.hand == "fresh" and f.count() < 10, "a click on the box gives a match " + tag)
		var v = game.match_view()
		var view = Rect2(Vector2.ZERO, game.get_viewport_rect().size)
		check(view.encloses(v.striker_rect()) and view.encloses(v.open_box_rect()), "the striker and the open box fit in the window " + tag)
		await shot("striker_" + tag)
		# slow: it only scratches
		await stroke(0.8, 120)
		check(f.hand == "fresh" and game.toast.contains("царапает"), "a slow stroke only scratches " + tag)
		# too sharp: it breaks, and soon leaves the hand
		await stroke(0.8, 6)
		check(f.hand == "broken" and game.toast.contains("сломалась"), "a sharp stroke breaks it " + tag)
		await shot("broken_" + tag)
		for i in range(90): v.process(DT)
		check(f.hand == "", "the broken match is dropped " + tag)
		# in measure: it lights
		await take_fresh()
		await stroke(0.8, 24)
		check(f.lit(), "a stroke in measure lights it " + tag)
		var remaining = f.burn
		game.pause_game()
		for i in range(420): v.process(DT)
		key(KEY_ESCAPE)
		check(not game.paused and game.cab_active() and f.lit() and is_equal_approx(f.burn, remaining), "the paused cab keeps the flame and Esc resumes the trip " + tag)
		await shot("lit_" + tag)
		# over the firebox with the door closed: no fire, the match still burns
		var fire = v.fire_rect()
		await carry(fire.get_center(), 50)
		check(f.lit() and not bool(game.model.boiler().lit), "over the firebox without a click nothing happens " + tag)
		await click(fire.get_center())
		check(f.lit() and not bool(game.model.boiler().lit) and game.toast.contains("Дверца"), "a click with the door closed: no fire, the match still burns " + tag)
		await shot("door_closed_" + tag)
		# open the door, then the match to the fire
		await carry(door.get_center(), 20)
		await click(door.get_center())
		check(bool(game.model.boiler().door), "the door opens with the match in hand " + tag)
		await carry(fire.get_center(), 20)
		check(f.lit() and not bool(game.model.boiler().lit), "over the open firebox it waits for the click " + tag)
		await click(fire.get_center())
		check(bool(game.model.boiler().lit) and not f.in_hand(), "a click with the burning match on the open firebox lights the fire " + tag)
		await shot("fire_lit_" + tag)
		if size.x == 1600:
			game.model.state.stats.seconds = Model.DAY_SECONDS * 0.75
			game.model.state.v = 4.0
			game.model.boiler().pressure = 0.55
			game.model.state.brake = 0.0
			game.toast_seconds = 0.0
			for i in range(45):
				game._process(DT)
				await frame()
			await shot("steam_night_running")
			game.model.state.v = 0.0
			game.model.state.brake = 1.0
		# a jerk blows it out
		game.model.boiler().lit = false
		game.model.state.engine = false
		await take_fresh()
		await stroke(0.8, 24)
		move_match(v.pos + Vector2(0, game.get_viewport_rect().size.y * 0.2))
		check(f.hand == "burnt" and game.toast.contains("задуло"), "a jerk blows it out " + tag)
		for i in range(90): v.process(DT)
		# throwing a match away: a double click, or Esc; a click on the box gives a new one in place of the one in hand
		await take_fresh()
		await double_click(v.pos)
		check(f.hand == "", "a double click throws the match away " + tag)
		await take_fresh()
		key(KEY_ESCAPE)
		check(f.hand == "", "Esc throws it away too " + tag)
		await take_fresh()
		var before = f.count()
		await click(v.open_box_rect().get_center())
		check(f.in_hand() and f.count() == before - 1, "a click on the box with a match in hand gives a new one " + tag)
		game.model.state.fleet_by_id.steam.matches = 0
		await click(box_point())
		check(f.in_hand() and f.count() == 0, "the empty box keeps the last match in hand " + tag)
		key(KEY_ESCAPE)
		game.cab_view = false
		game.update_pult_transform()
		game.saves.collect_warm(true)
	Model.match_rules = false
	print("MATCHES VIEW CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
