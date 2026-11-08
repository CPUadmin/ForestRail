extends Node
const Fixtures = preload("res://tests/fixtures.gd")

var game
var checks=0
var failures: Array=[]
var cases: Array=[]
var out_dir=""
var context=""

func _ready() -> void:
	preload("res://scripts/model.gd").legacy_tanks = true  # these tests are about the screens, on the old tank sizes (B2.2)
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(context+label);print("FAIL: ",context,label)

func frame(count: int=2) -> void:
	for i in range(count):
		game.update_hud();game.art_world.update_view();game.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var e=InputEventMouseButton.new();e.position=point;e.global_position=point
		e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
		e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_tree().root.push_input(e,true)
		await frame()
	await frame(2)  # let the reaction to the click settle before the check reads the state

# Click and wait for the expected reaction; if none comes, repeat the click (at most 3 repeats).
# The check itself stays strict: the caller still verifies the state afterwards.
func click_until(point: Vector2,done: Callable) -> void:
	for attempt in range(4):
		await click(point)
		if done.call(): return

# the cab is entered by a click on an empty place of the machine: the middle of its body away from the levers
func click_machine_for_cab() -> bool:
	for attempt in range(4):
		var rect = Rect2()
		for hit in game.body_hits:
			if hit.id == game.model.vehicle_id(): rect = hit.rect
		if rect.size.x <= 0: return false
		var spot = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.85)
		await click(spot)
		await frame(3)
		if game.cab_active(): return true
	return false

func click_button(parent: Node,text: String,done: Callable=Callable()) -> bool:
	for attempt in range(4):
		var found=false
		for b in parent.find_children("*","Button",true,false):
			if b.text==text and b.is_visible_in_tree():
				found=true
				await click(b.get_global_rect().get_center());break
		if not found: return attempt>0 and done.is_valid() and done.call()
		if not done.is_valid() or done.call(): return true
	return false

func fixture(id: String) -> void:
	game.cancel_drag();game.modal_kind="";game.paused=false; game.toast_seconds=0
	game.model.new_game(42);game.model.state.money=10000
	if id!="handcar": Fixtures.equip(game.model,id)
	game.model.accept_mission(game.model.free_offers()[0])
	game.model.transfer(game.model.state.cargo[0].id,game.model.slots()[0].key)
	game.model.depart();game.model.state.s=160;game.model.state.v=2;game.model.state.brake=0
	game.screen="game";game.camera_s=160;game.camera_y=game.model.route.sample(160).y;game.camera_x=game.get_viewport_rect().size.x*0.65
	game.rebuild()

func shot(name: String) -> void:
	await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name+".png"))

func run() -> void:
	out_dir=ProjectSettings.globalize_path("res://../qa/v3_p7")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--layout-output="): out_dir=arg.trim_prefix("--layout-output=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game=load("res://main.tscn").instantiate();game.test_mode=true
	get_tree().root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.saves.directory=out_dir.path_join("isolated_profile");DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.settings.fullscreen=false;game.apply_settings()
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		get_tree().root.size=resolution
		await get_tree().create_timer(0.15).timeout
		for scale in [1.0,1.25,1.5]:
			game.settings.text_scale=scale
			for id in ["handcar","motorcar","locomotive"]:
				context=str(resolution)+" "+str(scale)+" "+id+" "
				fixture(id);await frame(6)
				var viewport=game.get_viewport_rect()
				var ratio=game.instruments.permanent_panel_height()/viewport.size.y
				check(ratio<=0.22+0.0001,"permanent panels <=22% "+str(resolution))
				check(not game.hint_label.visible and not game.order_label.visible and not game.action_bar.visible,"moving view hides station context")
				check(game.instruments.mini_rect().end.x<=viewport.size.x-game.instruments.status_width()-22,"map and status do not overlap")
				check(game.hud.get_global_rect().end.x<=game.menu_hud_button.get_parent().get_global_rect().position.x,"route heading and buttons do not overlap")
				for b in game.ui.find_children("*","Button",true,false):
					if b.is_visible_in_tree(): check(viewport.encloses(b.get_global_rect()),"visible HUD button remains inside window")
					if b == game.menu_hud_button: check(b.size.y<=46,"actual header buttons fit declared panel height")
				var state=JSON.stringify(game.model.serialize())
				await frame(3)
				check(JSON.stringify(game.model.serialize())==state,"redrawing does not change model")
				await shot("route_"+id+"_"+str(resolution.x)+"_"+str(roundi(scale*100)))
				await click_until(game.instruments.mini_rect().get_center(),func(): return game.modal_kind=="map" and game.paused)
				check(game.modal_kind=="map" and game.paused,"minimap opens map through mouse")
				if id=="locomotive" and scale==1.5: await shot("map_"+str(resolution.x)+"_150")
				check(await click_button(game.overlay,"Закрыть [M / Esc]",func(): return game.modal_kind=="" and not game.paused),"map has mouse close action")
				check(game.modal_kind=="" and not game.paused,"mouse closes map and resumes")
				if id!="handcar":
					check(await click_machine_for_cab(),"a mouse click on the machine opens the cab at every text scale")
					await frame(3)
					check(game.cab_active(),"the cab actually opened")
					check(viewport.encloses(game.pult_screen_rect()),"the cab's controls stay inside the window")
					game.toggle_cab_view()
					check(not game.cab_active(),"the cab closes")
				cases.append({"window":str(resolution),"text_scale":scale,"vehicle":id,"hud_fraction":ratio})
			# Scrolling screens must keep their navigation available at 150%.
			fixture("handcar");game.model.rescue();game.model.cancel_mission();game.screen="depot";game.tab="Рейсы";game.rebuild()
			await shot("depot_"+str(resolution.x)+"_"+str(roundi(scale*100)))
			for b in game.ui.find_children("*","Button",true,false):
				if b.text in ["Гараж","Состав","Улучшения","Рейсы"]: check(b.size.x>=b.get_minimum_size().x,"depot navigation fits its column")
	game.settings.text_scale=1;get_tree().root.size=Vector2i(1600,900)
	fixture("handcar")
	for i in range(6):
		game.model.state.s=game.model.service_stop(i);game.model.state.v=0;game.model.state.brake=1
		game.model.stationary_station=i;game.model.stationary_seconds=0.3
		game.camera_s=game.model.state.s;game.camera_y=game.model.route.sample(game.camera_s).y;game.camera_x=1040
		game.rebuild();await shot("station_"+str(i))
	game.screen="menu";game.rebuild();await shot("menu")
	var file=FileAccess.open(out_dir.path_join("layout_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"input":"Viewport.push_input; initial world states are fixtures; screenshot inspection required"},"\t"));file.close()
	print("LAYOUT P7 CHECKS ",checks,"; FAILURES ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
