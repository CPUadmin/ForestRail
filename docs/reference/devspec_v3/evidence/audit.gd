extends SceneTree

const Model = preload("res://scripts/model.gd")
const Art = preload("res://scripts/art_v3.gd")
var game
var results: Dictionary = {}
var out_dir = ""

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://../work/audit_v3")
	root.set_meta("qa_running", true)
	call_deferred("run")

func refresh() -> void:
	game.queue_redraw()
	game.art_world.update_view()
	await process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await refresh()
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func button_event(p: Vector2, pressed: bool) -> void:
	var e = InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)
	await process_frame

func drag_to(id: String, target: Vector2) -> Dictionary:
	await refresh()
	var source = Vector2.ZERO
	for hit in game.cargo_hits:
		if hit.id == id: source = hit.rect.get_center()
	await button_event(source, true)
	var captured = game.drag_item == id
	await button_event(target, false)
	var item: Dictionary = {}
	for cargo in game.model.state.cargo:
		if cargo.id == id: item = cargo.duplicate(true)
	return {"captured": captured, "source": [source.x,source.y], "target": [target.x,target.y], "delivered": item.get("delivered",false), "slot": item.get("slot","missing"), "toast":game.toast}

func run() -> void:
	root.title = "Лесная колея — проверка разгрузки"
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = out_dir.path_join("session")
	game.settings_path = out_dir.path_join("isolated_settings.json")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.model.new_game(42)
	game.model.accept_mission(game.model.current_mission())
	for i in range(game.model.state.cargo.size()):
		game.model.transfer(game.model.state.cargo[i].id, game.model.slots()[i].key)
	game.model.depart()
	game.model.state.s = game.model.route.station_s[1]
	game.model.state.v = 0
	game.model.state.brake = 1
	game.screen = "game"
	game.paused = false
	game.camera_s = game.model.state.s
	game.camera_y = game.model.route.sample(game.camera_s).y
	game.camera_x = 800
	game.rebuild()
	await shot("01_arrival_before_unload")
	var id = str(game.model.state.cargo[0].id)
	results.dock_visible_at_full_brake = game.dock_visible()
	results.world_platform_drop = await drag_to(id, game.world_point(game.camera_s) + Vector2(370,-22))
	await shot("02_world_platform_drop")
	results.panel_drop = await drag_to(id, game.dock_rect().get_center())
	await shot("03_panel_drop")
	var remaining_id = str(game.model.state.cargo[1].id)
	game.model.state.brake = 0.94
	game.update_hud()
	results.brake_94 = {"stopped":game.model.stopped(), "dock_visible":game.dock_visible(), "transfer":game.model.transfer(remaining_id,""), "message":game.model.message}
	await shot("04_stopped_brake94")
	game.model.state.brake = 1
	game.update_hud()
	results.second_panel_drop = await drag_to(remaining_id,game.dock_rect().get_center())
	results.after_all = {"phase":game.model.state.active.phase,"pending_reward":game.model.state.active.pending_reward,"money":game.model.state.money,"deliveries":game.model.state.stats.deliveries}
	await shot("05_all_delivered")
	var scale_report: Array = []
	for zoom in [0.75,1.0,1.5]:
		game.zoom_level = zoom
		var station = game.art.assets["stations/station_house"]
		var station_width = float(station.region_px[2]) * game.art.scale_for("stations/station_house") * 0.72
		var station_height = float(station.region_px[3]) * game.art.scale_for("stations/station_house") * 0.72
		scale_report.append({"zoom":zoom,"handcar_width_px":game.art.body_width("handcar")*zoom,"station_width_px":station_width,"station_height_px":station_height,"station_to_handcar_width":station_width/(game.art.body_width("handcar")*zoom)})
		await shot("06_scale_"+str(zoom))
	results.scales = scale_report
	game.model.state.money = 5000
	game.model.state.phase = "depot"
	game.model.state.active = {}
	game.model.state.cargo = []
	game.model.buy_vehicle("motorcar")
	game.model.state.offer_serial = 4
	var offer = game.model.free_offers()[0]
	game.model.accept_mission(offer)
	game.screen = "game"
	game.rebuild()
	game.update_hud()
	results.free_offer_title = game.hud.text
	var controls = {}
	for c in ["brake","throttle","gear","start"]:
		var geo = game.lever_geometry(c)
		controls[c] = {"pivot_m":[geo.pivot.x/Art.PX,geo.pivot.y/Art.PX], "length_m":geo.pivot.distance_to(geo.grip)/Art.PX,"grip_height_m":-geo.grip.y/Art.PX}
	results.motor_controls = controls
	physics_audit()
	var f = FileAccess.open(out_dir.path_join("audit_results.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"))
	f.close()
	print("AUDIT_RESULT ",JSON.stringify(results))
	game.queue_free()
	await process_frame
	quit()

func physics_audit() -> void:
	var m = Model.new()
	m.new_game(42)
	m.state.phase = "route"
	m.state.brake = 0
	m.state.v = 2
	var art = Art.new()
	var before = art.mechanism_pose(m)
	for i in range(120): m.physics_step(1.0/60)
	var after = art.mechanism_pose(m)
	results.coasting = {"distance_m":m.state.s,"velocity":m.state.v,"rocker_change_deg":rad_to_deg(after.angle-before.angle),"crank_change_deg":rad_to_deg(angle_difference(before.phase,after.phase)),"wheel_rotation_deg":rad_to_deg(float(m.state.s)/0.21)}
	var positive = art.pose(0,1,1)
	var negative = art.pose(0,-1,1)
	results.midstroke_direction_change = {"same_rocker_deg":rad_to_deg(positive.angle),"crank_jump_deg":rad_to_deg(angle_difference(positive.phase,negative.phase))}
	var empty = Model.new()
	var heavy = Model.new()
	for model in [empty,heavy]:
		model.new_game(42)
		model.state.phase = "route"
		model.state.brake = 0
	heavy.state.cargo = [{"id":"audit","type":"logs","slot":"handcar:0","delivered":false,"destination":"B","health":1.0}]
	for frame in range(120):
		for model in [empty,heavy]:
			model.pump_motion(sin(frame*TAU/60)*deg_to_rad(28)-model.pump_angle)
			model.physics_step(1.0/60)
	results.load_response = {"empty_mass":empty.train_mass(),"loaded_mass":heavy.train_mass(),"empty_v":empty.state.v,"loaded_v":heavy.state.v,"lever_angle_difference_deg":rad_to_deg(empty.pump_angle-heavy.pump_angle)}
