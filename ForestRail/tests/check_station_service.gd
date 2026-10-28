extends Node

var game
var checks = 0
var failures: Array = []
var cases: Array = []
var movie = false
var out_dir = ""

func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures.append(text);print("FAIL: ",text)

func _ready() -> void:
	call_deferred("run")

func frame(count: int = 2) -> void:
	for i in range(count):
		game._process(1.0/30 if movie else 1.0/60)
		game.update_hud()
		game.art_world.update_view()
		game.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name+".png"))
	if movie: await frame(24)

func button(point: Vector2, pressed: bool) -> void:
	var event=InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_tree().root.push_input(event,true)
	await frame()

func source_rect(id: String) -> Rect2:
	for hit in game.cargo_hits:
		if hit.id==id: return hit.rect
	return Rect2()

func drag_to(id: String, target: Vector2) -> bool:
	await frame()
	var source=source_rect(id).get_center()
	await button(source,true)
	var captured=game.drag_item==id
	check(captured,"GUI captures "+id)
	var last=source
	for i in range(1,13):
		var point=source.lerp(target,i/12.0)
		var motion=InputEventMouseMotion.new()
		motion.position=point
		motion.relative=point-last
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		get_tree().root.push_input(motion,true)
		last=point
		await frame(2 if movie else 1)
	await button(target,false)
	return captured

func prepare(chapter: int = 0) -> void:
	game.cancel_drag()
	game.selected_cargo=""
	game.model.new_game(42)
	game.model.state.money=10000 if chapter>0 else 0
	if chapter>=2: game.model.buy_vehicle("motorcar")
	game.model.state.chapter=chapter
	check(game.model.accept_mission(game.model.current_mission()),"fixture accepts mission")
	game.screen="game"
	game.paused=false
	game.modal_kind=""
	game.toast_seconds=0
	game.camera_s=game.model.state.s
	game.camera_y=game.model.route.sample(game.camera_s).y
	game.camera_x=game.get_viewport_rect().size.x*0.65
	game.rebuild()
	await frame()
	# Loading itself also goes through mouse events, never transfer().
	var slots=game.model.slots()
	for i in range(game.model.state.cargo.size()):
		var destination=i
		# M05 puts a C-bound sack on both the motorcar and W01.
		if chapter==4 and i==0: destination=2
		elif chapter==4 and i==2: destination=0
		await drag_to(game.model.state.cargo[i].id,game.slot_hits[destination].rect.get_center())
	check(game.model.all_loaded(),"fixture cargo loaded by GUI")
	check(game.model.depart(),"depart fixture")

func arrive(index: int, settle: bool = true) -> void:
	game.model.state.s=game.model.service_stop(index)
	game.model.state.v=0
	game.model.state.brake=1
	game.model.stationary_station=-1
	game.model.stationary_seconds=0
	game.camera_s=game.model.state.s
	game.camera_y=game.model.route.sample(game.camera_s).y
	if settle:
		for i in range(20): game._physics_process(1.0/60)
	game.rebuild()
	await frame()

func platform_point() -> Vector2:
	var r=game.world_platform_rect()
	return Vector2(clampf(game.world_point(game.model.route.station_s[game.station_state().station_index]).x+320*game.view_scale(),30,game.get_viewport_rect().size.x-30),r.position.y+r.size.y*0.6)

func run() -> void:
	out_dir=ProjectSettings.globalize_path("res://../qa/v3_p1")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--station-output="): out_dir=argument.trim_prefix("--station-output=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	movie="--p1-movie" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	game.test_mode=true
	game.saves.directory=out_dir.path_join("session")
	game.settings_path=out_dir.path_join("settings.json")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.settings.fullscreen=false
	game.settings.text_scale=1.0
	game.apply_settings()
	await prepare()
	await arrive(1,false)
	check(not game.station_state().can_transfer,"arrival waits for continuous stationary time")
	for i in range(14): game._physics_process(1.0/60)
	check(not game.station_state().can_transfer,"14 physics ticks are shorter than 0.25 s")
	for i in range(2): game._physics_process(1.0/60)
	check(game.station_state().can_transfer,"station ready after stationary quarter second")
	game.model.state.brake=0.94
	game.model.state.tutorial=false
	await shot("01_brake94")
	check(game.dock_visible() and game.station_state().phase=="brake_required","brake 94 leaves panel visible with precise reason")
	check(game.hint_label.text.contains("тормоз"),"required instruction remains without tutorial")
	await button(source_rect("M01_0").get_center(),true)
	check(game.drag=="" and game.toast.contains("тормоз"),"94 percent cannot transfer")
	await button(source_rect("M01_0").get_center(),false)
	game.model.state.brake=1
	game.model.state.v=0.2
	game.model.update_station_dwell(0)
	check(game.station_state().phase=="stop_required","moving train with full brake cannot unload")
	await arrive(1)
	if not movie:
		game.model.pump_angle=deg_to_rad(28)
		await frame()
		for id in ["M01_0","M01_1"]:
			var r=source_rect(id)
			for point in [r.position+Vector2(4,4),Vector2(r.end.x-4,r.position.y+4),r.end-Vector2(4,4),Vector2(r.position.x+4,r.end.y-4)]:
				await button(point,true)
				check(game.drag_item==id,"visible cargo corner remains clickable beside controls")
				await button(point,false)
	await drag_to("M01_0",Vector2(12,250))
	check(not game.model.state.cargo[0].delivered and game.toast.contains("выделенную"),"invalid drop explains return without losing cargo")
	await shot("02_invalid_drop")
	var source=source_rect("M01_0").get_center()
	await button(source,true)
	var camera_before=Vector3(game.camera_s,game.camera_y,game.camera_x)
	game._process(0.1)
	check(Vector3(game.camera_s,game.camera_y,game.camera_x)==camera_before,"camera freezes while holding cargo")
	var escape=InputEventKey.new()
	escape.keycode=KEY_ESCAPE;escape.pressed=true
	get_tree().root.push_input(escape,true)
	await frame()
	check(game.drag=="" and not game.model.state.cargo[0].delivered,"Escape cancels without losing cargo")
	game.close_modal()
	await frame()
	var before=game.model.train_mass()
	await drag_to("M01_0",platform_point())
	check(game.model.state.cargo[0].delivered and game.model.train_mass()==before-35,"world platform delivers exactly one sack")
	check(game.station_state().phase=="partial" and game.station_state().delivered==1,"partial counter is station deliveries")
	check(game.model.state.money==0 and game.model.state.stats.deliveries==1,"no premature pay")
	await shot("03_world_platform_success")
	var saved=game.saves.read_valid("save_v2.json")
	check(game.model.restore(saved) and game.model.state.cargo[0].delivered,"partial delivery persists")
	for i in range(20): game._physics_process(1.0/60)
	await frame()
	await drag_to("M01_1",game.dock_rect().get_center())
	check(game.model.state.active.phase=="return" and game.model.state.active.pending_reward==100,"panel drop completes deliveries with deferred reward")
	await button(game.dock_rect().get_center(),false)
	check(game.model.state.stats.deliveries==2 and game.model.state.money==0,"duplicate release cannot deliver or pay twice")
	await shot("04_panel_success_return_home")
	if not movie:
		var legacy=load("res://scripts/model.gd").new()
		legacy.new_game(42)
		legacy.state.money=10000
		legacy.buy_vehicle("motorcar")
		legacy.buy_vehicle("locomotive")
		legacy.buy_wagon()
		legacy.state.chapter=9
		legacy.accept_mission(legacy.current_mission())
		legacy.state.s=0
		var old_save=legacy.serialize()
		var money_before=legacy.state.money
		check(legacy.restore(old_save) and legacy.station_interaction().in_zone,"old parked loading formation fits platform after restore")
		check(legacy.state.money==money_before and legacy.state.cargo.size()==6 and old_save.s==0,"loading compatibility preserves cargo, money and original save object")
		legacy.state.phase="depot"
		legacy.state.s=0
		check(legacy.resume_mission() and legacy.station_interaction().can_transfer,"resuming a parked long consist permits loading")
		for dims in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
			get_tree().root.size=dims
			for zoom in [0.75,1.0,1.5]:
				game.zoom_level=zoom
				await prepare()
				await arrive(1)
				await drag_to("M01_0",platform_point())
				await drag_to("M01_1",game.dock_rect().get_center())
				check(game.model.state.stats.deliveries==2,"both targets work at %d / %.2f" % [dims.y,zoom])
				check(game.dock_rect().size.y<=game.get_viewport_rect().size.y*0.18,"station panel within 18 percent")
				cases.append({"resolution":str(dims),"zoom":zoom,"delivered":game.model.state.stats.deliveries})
				await shot("matrix_%d_%.2f" % [dims.y,zoom])
		game.settings.text_scale=1.5
		game.zoom_level=0.75
		await prepare(4)
		await arrive(2)
		check(game.station_state().eligible.size()==2,"multipoint station counts only its own cargo")
		var mass=game.model.train_mass()
		await drag_to("M05_2",platform_point())
		check(game.model.train_mass()==mass and not game.model.state.cargo[2].delivered and game.toast.contains("ждут"),"wrong station rejects cargo with destination message")
		await shot("05_wrong_destination")
		await drag_to("M05_0",platform_point())
		check(game.model.state.cargo[0].delivered,"wagon cargo can reach world platform")
		var rect=source_rect("M05_1")
		await button(rect.get_center(),true)
		await button(rect.get_center(),false)
		await frame()
		check(is_instance_valid(game.unload_selected_button) and not game.unload_selected_button.disabled,"single click selects and enables backup unload button")
		var bp=game.unload_selected_button.get_global_rect().get_center()
		await button(bp,true)
		await button(bp,false)
		check(game.model.state.cargo[1].delivered and game.model.state.active.phase=="outbound","GUI backup button unloads motorcar without ending multipoint order")
		check(game.station_state().phase=="station_complete","intermediate station complete state")
		await shot("06_intermediate_complete")
		await arrive(3)
		await button(source_rect("M05_2").get_center(),true)
		game.test_mode=false
		game.focus_lost()
		game.test_mode=true
		check(game.drag=="" and not game.model.state.cargo[2].delivered,"focus loss cancels cargo transfer")
		game.close_modal()
		await frame()
		await button(source_rect("M05_2").get_center(),true)
		get_tree().root.size=Vector2i(1600,900)
		await frame(4)
		check(game.drag=="" and not game.model.state.cargo[2].delivered,"resizing cancels cargo transfer")
		await button(source_rect("M05_2").get_center(),true)
		game.toggle_map()
		check(game.drag=="" and game.modal_kind=="map","opening map cancels cargo transfer")
		game.close_modal()
		game.model.state.s+=12
		await frame()
		check(game.station_state().phase=="position_required" and not game.station_state().can_transfer,"entire consist must fit marked service interval")
		await shot("07_position_required")
	var result={"checks":checks,"failures":failures,"matrix":cases,"input":"Viewport.push_input in local coordinates; mouse presses/motions/releases routed through GUI","human_novice_trial":"not performed"}
	var file=FileAccess.open(out_dir.path_join("movie_results.json" if movie else "results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("STATION SERVICE CHECKS ",checks,"; FAILURES ",failures)
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
