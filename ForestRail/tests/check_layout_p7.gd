extends Node

var game
var checks=0
var failures: Array=[]
var cases: Array=[]
var out_dir=""
var context=""

func _ready() -> void: call_deferred("run")
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

func click_button(parent: Node,text: String) -> bool:
	for b in parent.find_children("*","Button",true,false):
		if b.text==text and b.is_visible_in_tree():
			await click(b.get_global_rect().get_center());return true
	return false

func fixture(id: String) -> void:
	game.cancel_drag();game.modal_kind="";game.paused=false;game.control_zoom=false;game.toast_seconds=0
	game.model.new_game(42);game.model.state.money=10000
	if id!="handcar": game.model.buy_vehicle("motorcar")
	if id=="locomotive": game.model.buy_vehicle("locomotive")
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
				check(game.hud.get_global_rect().end.x<=game.map_button.get_global_rect().position.x,"route heading and buttons do not overlap")
				for b in game.ui.find_children("*","Button",true,false):
					if b.is_visible_in_tree(): check(viewport.encloses(b.get_global_rect()),"visible HUD button remains inside window")
					if b.text in ["Карта [M]","Пульт [C]","Пауза"]: check(b.size.y<=46,"actual header buttons fit declared panel height")
				var state=JSON.stringify(game.model.serialize())
				await frame(3)
				check(JSON.stringify(game.model.serialize())==state,"redrawing does not change model")
				await shot("route_"+id+"_"+str(resolution.x)+"_"+str(roundi(scale*100)))
				await click(game.instruments.mini_rect().get_center())
				check(game.modal_kind=="map" and game.paused,"minimap opens map through mouse")
				if id=="locomotive" and scale==1.5: await shot("map_"+str(resolution.x)+"_150")
				check(await click_button(game.overlay,"Закрыть [M / Esc]"),"map has mouse close action")
				check(game.modal_kind=="" and not game.paused,"mouse closes map and resumes")
				if id!="handcar":
					check(await click_button(game.ui,"Пульт [C]"),"mouse opens pult at every text scale")
					check(game.control_zoom,"pult actually opened")
					check(viewport.encloses(game.control_zoom_rect()),"pult stays inside window")
					await click(game.control_zoom_rect().position+Vector2(390,20))
					check(not game.control_zoom,"mouse closes pult")
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
