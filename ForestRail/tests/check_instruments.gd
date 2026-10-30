extends Node

var game
var checks = 0
var failures: Array = []
var images: Array = []
const OUT = "user://qa_instruments"

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); print("FAIL: ",message)

func shot(name: String) -> void:
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image = get_tree().root.get_texture().get_image()
	image.save_png(OUT.path_join(name+".png"))
	images.append(name)

func key(code: Key, physical: bool = false, echo: bool = false) -> void:
	var event = InputEventKey.new()
	event.pressed=true
	event.echo=echo
	if physical: event.physical_keycode=code
	else: event.keycode=code
	game._input(event)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode=true
	game.settings.fullscreen=false
	game.apply_settings()
	game.saves.directory=OUT
	game.model.new_game(42)
	game.model.accept_mission(game.model.current_mission())
	game.screen="game"
	game.rebuild()
	await shot("handcar_loading")
	check(game.dock_visible(),"loading dock available above instruments")
	check(game.instruments.dial_maximum()==30,"manual dial uses calibrated 0..30 km/h")
	var mass = game.model.train_mass()
	for i in range(2): game.model.transfer(game.model.state.cargo[i].id,game.model.slots()[i].key)
	check(game.model.train_mass()==mass+70,"instrument mass source includes loaded cargo")
	game.model.depart()
	game.model.state.s=127
	game.model.state.v=2
	game.model.state.brake=0
	game.camera_s=127
	game.camera_y=game.model.route.sample(127).y
	game.rebuild()
	check(not game.dock_visible(),"cargo dock hidden during travel")
	await shot("handcar_driving")
	game.drag="pump"
	key(KEY_M,true)
	check(game.modal_kind=="map" and game.paused and game.drag=="","physical M opens map and releases handle")
	var s = game.model.state.s
	var v = game.model.state.v
	game._physics_process(1)
	check(game.model.state.s==s and game.model.state.v==v,"map pauses actual movement")
	await shot("full_map")
	var view = game.overlay.get_child(0)
	check(view.station_hits.size()==6,"full map shows all stations")
	var click = InputEventMouseButton.new()
	click.pressed=true
	click.button_index=MOUSE_BUTTON_LEFT
	click.position=view.station_hits[4]
	view._gui_input(click)
	check(view.selected_station==4,"station click opens its delivery details")
	await shot("selected_station")
	key(KEY_M,true,true)
	check(game.modal_kind=="map","key repeat does not toggle map")
	key(KEY_ESCAPE)
	check(game.modal_kind=="" and not game.paused,"Escape resumes journey")
	game.map_button.pressed.emit()
	check(game.modal_kind=="map","map button opens same view")
	key(KEY_M)
	check(game.modal_kind=="" and not game.paused,"M closes map")
	# Actual GUI events on the minimap, including its transparent click target.
	await get_tree().process_frame
	var point = game.instruments.mini_rect().get_center()
	for pressed in [true,false]:
		var event = InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		get_tree().root.push_input(event,true)
		await get_tree().process_frame
	check(game.modal_kind=="map","minimap click opens full map through GUI")
	game.close_modal()
	game.model.state.s=game.model.route.station_s[1]
	game.model.state.v=0
	game.model.state.brake=1
	for i in range(20): game._physics_process(1.0/60)
	game.camera_s=game.model.state.s
	game.camera_y=game.model.route.sample(game.camera_s).y
	game.rebuild()
	await shot("arrival_unloading")
	check(game.dock_visible(),"unloading dock appears at a stopped station")
	var source = game.cargo_hits[0].rect.get_center()
	for pressed in [true,false]:
		var event = InputEventMouseButton.new()
		event.position=source if pressed else game.dock_rect().get_center()
		event.global_position=event.position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		get_tree().root.push_input(event,true)
		await get_tree().process_frame
	check(game.model.state.cargo[0].delivered,"cargo unload works through GUI above dashboard")
	check(game.model.train_mass()==mass+35,"mass readout source decreases after unloading")
	game.model.rescue()
	game.model.cancel_mission()
	game.model.state.money=50000
	game.model.buy_vehicle("motorcar")
	game.model.state.chapter=2
	game.model.accept_mission(game.model.current_mission())
	game.screen="game"
	game.rebuild()
	check(game.instruments.dial_maximum()==25,"petrol dial adapts to 23.4 km/h")
	game.model.state.fleet_by_id.motorcar.fuel=0.12
	await shot("petrol_low_fuel")
	game.model.rescue()
	game.model.cancel_mission()
	game.model.buy_vehicle("locomotive")
	game.model.buy_wagon()
	game.model.state.chapter=6
	game.model.accept_mission(game.model.current_mission())
	game.screen="game"
	game.rebuild()
	check(game.instruments.dial_maximum()==30,"electric dial adapts to 28.8 km/h")
	# Upgrades change the scale without a new interface setting.
	var upgraded = false
	for branch in game.model.data.upgrade_catalog:
		if branch.effects_at_level.has("high_gear_speed_multiplier"):
			game.model.state.fleet_by_id.locomotive.levels[branch.id]=2
			upgraded=true
	check(upgraded and game.instruments.dial_maximum()>30,"speed upgrade automatically extends scale")
	for dims in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		get_tree().root.size=dims
		game.rebuild()
		await shot("electric_"+str(dims.y))
		check(Rect2(Vector2.ZERO,game.get_viewport_rect().size).encloses(game.instruments.mini_rect()),"minimap fits viewport "+str(dims.y))
		check(game.dock_rect().end.y<game.instruments.mini_rect().position.y,"dock does not cover instruments "+str(dims.y))
		game.toggle_map()
		await shot("map_"+str(dims.y))
		game.close_modal()
	game.settings.text_scale=1.5
	game.model.state.fleet_by_id.locomotive.fuel=0
	game.rebuild()
	await shot("electric_text150_empty")
	game.toggle_map()
	await shot("map_text150")
	check(Rect2(Vector2.ZERO,game.get_viewport_rect().size).encloses(game.overlay.get_child(1).get_child(0).get_global_rect()),"map close button fits with text 150%")
	game.close_modal()
	get_tree().root.size=Vector2i(1280,720)
	game.rebuild()
	await shot("hud_720_text150")
	var bounds = Rect2(Vector2.ZERO,game.get_viewport_rect().size)
	check(bounds.encloses(game.map_button.get_global_rect()),"map button fits at 720p with text 150%")
	check(bounds.encloses(game.map_button.get_parent().get_child(1).get_global_rect()),"pause button fits at 720p with text 150%")
	game.toggle_map()
	await shot("map_720_text150")
	check(bounds.encloses(game.overlay.get_child(1).get_child(0).get_global_rect()),"close button fits at 720p with text 150%")
	var result = {"checks":checks,"failures":failures,"images":images}
	var file = FileAccess.open(OUT.path_join("results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("INSTRUMENT CHECKS ",checks,"; FAILURES ",failures)
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
