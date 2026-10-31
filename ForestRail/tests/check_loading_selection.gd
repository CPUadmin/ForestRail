extends Node

const Model=preload("res://scripts/model.gd")
var game
var checks=0
var failures: Array=[]
var economies: Array=[]
var out_dir=""

func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL: ",label)

func station_index(m,id: String) -> int:
	for i in range(m.data.stations.size()):
		if m.data.stations[i].id==id: return i
	return 0

func park(m,index: int) -> void:
	m.state.s=m.service_stop(index);m.state.v=0;m.state.brake=1
	m.stationary_station=index;m.stationary_seconds=0.3

func finish_fixture(m) -> void:
	# This verifies money/state transitions, not driving or mouse handling.
	for item in m.state.cargo.duplicate(true):
		park(m,station_index(m,item.destination))
		check(m.transfer(item.id,""),"accepted cargo delivered in money fixture")
	check(m.state.active.phase=="return","warehouse cargo does not block completion")
	park(m,0)
	check(m.settle(),"fixture pays at home")

func earn(m,target: int) -> int:
	var count=0
	while m.state.money<target and count<30:
		m.refuel()
		check(m.accept_mission(m.free_offers()[0]),"recovery offer remains available")
		check(m.transfer(m.state.cargo[0].id,m.slots()[0].key),"recovery carries only one item")
		check(m.depart(),"partial recovery departure")
		finish_fixture(m)
		count+=1
	return count

func numerical() -> void:
	var m=Model.new();m.new_game(42);m.accept_mission(m.current_mission())
	check(not m.depart(),"empty departure rejected")
	var id=m.state.cargo[0].id
	m.transfer(id,m.slots()[0].key)
	var plan=m.loading_preview()
	check(plan.loaded==1 and plan.offered==2 and plan.mass_kg==215 and plan.reward==60,"partial preview shows mass/slots/pay")
	m.transfer(id,"")
	check(m.loading_preview().loaded==0 and m.loading_preview().reward==0 and m.state.money==0,"removing cargo before departure has no fee")
	m.transfer(id,m.slots()[0].key)
	var restored=Model.new()
	check(restored.restore(m.serialize()) and restored.loading_preview().reward==60,"unfinished selection persists")
	m=restored
	check(m.depart() and m.state.cargo.size()==1 and m.state.active.warehouse_cargo.size()==1,"departure separates accepted set from warehouse")
	check(m.state.active.selection_locked and m.state.active.reward==60,"departure freezes payment")
	check(restored.restore(m.serialize()) and restored.state.cargo.size()==1,"frozen partial order persists")
	var corrupt=m.serialize();corrupt.active.warehouse_cargo[0].slot="handcar:1"
	check(not restored.restore(corrupt),"corrupt warehouse cannot become hidden loaded cargo")
	var money=m.state.money
	finish_fixture(m)
	check(m.state.money==money+60 and m.state.last_result.left_on_warehouse==1,"pay only accepted cargo, warehouse recorded without loss")
	check(not m.settle() and m.state.money==money+60,"partial payout cannot repeat")
	# Legacy active contracts retain their fixed full load and full reward.
	m=Model.new();m.new_game(42);m.accept_mission(m.current_mission())
	var old=m.serialize()
	for key in ["selection_version","selection_locked","offer_reward","offer_value","offered_count"]: old.active.erase(key)
	check(m.restore(old) and not m.selectable_loading(),"legacy contract remains fixed")
	park(m,0)
	m.transfer(m.state.cargo[0].id,m.slots()[0].key)
	check(not m.depart(),"legacy partial departure remains prohibited")
	m.transfer(m.state.cargo[1].id,m.slots()[1].key)
	check(m.depart() and m.state.active.reward==120,"legacy full reward preserved")
	# Grade estimate responds to actual slope and body masses.
	m=Model.new();m.new_game(42);m.accept_mission(m.current_mission())
	m.transfer(m.state.cargo[0].id,m.slots()[0].key)
	for point in m.route.points: point[1]=0.0
	m.loading_cache.clear();var easy=m.loading_preview().duplicate(true)
	for point in m.route.points: point[1]=float(point[0])*0.10
	m.loading_cache.clear();var uphill=m.loading_preview().duplicate(true)
	m.transfer(m.state.cargo[1].id,m.slots()[1].key)
	var heavy=m.loading_preview()
	check(easy.difficulty=="Легко" and uphill.required_force_n>easy.required_force_n,"estimate uses route gravity, not random color")
	check(heavy.required_force_n>uphill.required_force_n and heavy.mass_kg==250,"cargo increases actual uphill demand")
	check(heavy.difficulty=="Потребуется меньшая загрузка","over-demanding climb is explained")
	# Recompute all ten payments, plus recovery after partial loads/purchases.
	for partial in [false,true]:
		m=Model.new();m.new_game(42)
		var recovery=0
		var rows: Array=[]
		for chapter in range(10):
			var purchase={2:"steam",4:"motorcar",8:"locomotive"}.get(chapter,"")
			if purchase!="":
				recovery+=earn(m,int(m.vehicle_base(purchase).cost));check(m.buy_vehicle(purchase),"economy buys "+purchase)
			if (chapter==4 or chapter==9) and not partial:
				recovery+=earn(m,m.wagon_price(m.next_wagon_id()));check(m.buy_wagon(),"full-load economy buys a wagon")
			m.refuel();check(m.accept_mission(m.current_mission()),"economy accepts career")
			var count=1 if partial else m.state.cargo.size()
			for i in range(count): check(m.transfer(m.state.cargo[i].id,m.slots()[i].key),"economy loads chosen amount")
			check(m.depart(),"economy departs chosen amount")
			finish_fixture(m)
			rows.append({"chapter":chapter+1,"money":m.state.money,"accepted":count})
		check(m.state.chapter==10 and m.state.finale,"career can end with chosen partial loads")
		# Exact balance is pinned in check_model; here the full-load career only
		# has to finish solvent after the free runs it needed (3.2 economy).
		if not partial: check(m.state.money>=0 and recovery<=14,"full-load ten-mission economy finishes solvent")
		# Spend on an optional upgrade, cancel a new offer, and earn again.
		m.select_vehicle("handcar");m.upgrade("handcar","handcar_lever")
		var before=int(m.state.money)
		m.accept_mission(m.free_offers()[0]);m.back_to_depot();m.cancel_mission()
		check(m.state.money==before and m.state.active.is_empty(),"cancel has no penalty or payout")
		var extra=earn(m,before+1)
		check(extra>0 and m.state.money>before,"old handcar can earn after purchases and cancellation")
		economies.append({"partial":partial,"recovery_trips":recovery,"rows":rows,"post_purchase_recovery":extra,"scope":"money/state fixture; station positions assigned"})

func frame() -> void:
	game.update_hud();game.art_world.update_view();game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func mouse(point: Vector2,pressed: bool) -> void:
	var e=InputEventMouseButton.new();e.position=point;e.global_position=point
	e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_tree().root.push_input(e,true);await frame()

func drag(id: String,target: Vector2) -> void:
	var source=Vector2.ZERO
	for hit in game.cargo_hits:
		if hit.id==id: source=hit.rect.get_center()
	await mouse(source,true)
	check(game.drag=="cargo" and game.drag_item==id,"GUI captures selected offered item")
	var e=InputEventMouseMotion.new();e.position=target;e.relative=target-source;e.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(e,true);await frame();await mouse(target,false)

func gui() -> void:
	game=load("res://main.tscn").instantiate();get_tree().root.add_child(game)
	game.test_mode=true;game.set_physics_process(false);game.set_process(false)
	game.saves.directory=out_dir.path_join("isolated_profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		get_tree().root.size=resolution
		game.model.new_game(42);game.model.accept_mission(game.model.current_mission());game.screen="game"
		game.camera_s=game.model.state.s;game.camera_y=game.model.route.sample(game.camera_s).y;game.camera_x=game.get_viewport_rect().size.x*0.65
		game.rebuild();await frame();await frame()
		var id=game.model.state.cargo[0].id
		await drag(id,game.slot_hits[0].rect.get_center())
		check(game.model.loading_preview().loaded==1,"one GUI-loaded item enables partial trip")
		await drag(id,game.dock_rect().position+Vector2(500,90))
		check(game.model.loading_preview().loaded==0,"GUI can remove item without penalty")
		await drag(id,game.slot_hits[0].rect.get_center())
		get_tree().root.get_texture().get_image().save_png(out_dir.path_join("choice_"+str(resolution.x)+".png"))
		for b in game.action_bar.get_children():
			if b is Button and b.text=="Отправиться →":
				var p=b.get_global_rect().get_center();await mouse(p,true);await mouse(p,false);break
		check(game.model.state.phase=="route" and game.model.state.cargo.size()==1,"mouse departs with one accepted item")
		var saved=game.saves.read_valid("save_v2.json")
		check(not saved.is_empty() and saved.active.selection_locked and saved.active.reward==60,"GUI saves frozen selection on departure")
		park(game.model,1);game.camera_s=game.model.state.s;game.camera_y=game.model.route.sample(game.camera_s).y
		game.rebuild();await frame();await frame()
		await drag(id,game.dock_rect().get_center())
		check(game.model.state.active.phase=="return" and game.model.state.active.pending_reward==60,"GUI partial delivery completes without warehouse item")
		get_tree().root.get_texture().get_image().save_png(out_dir.path_join("return_"+str(resolution.x)+".png"))

func run() -> void:
	out_dir=ProjectSettings.globalize_path("res://../qa/v3_p6")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--loading-output="): out_dir=arg.trim_prefix("--loading-output=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	numerical();await gui()
	var file=FileAccess.open(out_dir.path_join("loading_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"economies":economies,"input":"Viewport.push_input for choice/removal/departure/delivery; station arrivals are fixtures"},"\t"));file.close()
	print("LOADING SELECTION CHECKS ",checks,"; FAILURES ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
