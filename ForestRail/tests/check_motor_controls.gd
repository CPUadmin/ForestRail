extends Node
const Fixtures = preload("res://tests/fixtures.gd")

const Model=preload("res://scripts/model.gd")
var game
var checks=0
var failures: Array=[]
var out_dir=""
var context=""

func _ready() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(context+label);print("FAIL: ",context,label)

func fixture(id: String):
	var m=Model.new()
	m.new_game(42);m.state.money=10000;Fixtures.equip(m,"motorcar")
	if id=="locomotive": Fixtures.equip(m,id)
	m.select_vehicle(id)
	m.state.phase="route";m.state.s=100;m.state.brake=0
	for p in m.route.points: p[1]=0.0
	return m

func frame() -> void:
	game.update_hud()
	game.art_world.update_view()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func mouse(point: Vector2,pressed: bool) -> void:
	var e=InputEventMouseButton.new()
	e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
	get_tree().root.push_input(e,true)
	await frame()

func pull(id: String,value: float) -> void:
	var point=Vector2.ZERO
	for hit in game.grip_hits:
		if hit.id==id and hit.get("closeup",false): point=hit.position
	check(point!=Vector2.ZERO,"visible closeup grip "+id)
	await mouse(point,true)
	check(game.drag==id,"real mouse captures "+id)
	var target=point
	if id!="start":
		var geo=game.control_geometry(id,true)
		if game.control_kind(id)=="slider": target=geo.pivot+Vector2(0,-float(geo.length)*value)
		else: target=geo.pivot+Vector2(0,-geo.pivot.distance_to(geo.grip)).rotated(lerpf(-0.55,0.55,value))
		var e=InputEventMouseMotion.new()
		e.position=target;e.relative=target-point;e.button_mask=MOUSE_BUTTON_MASK_LEFT
		get_tree().root.push_input(e,true)
		await frame()
		check(game.control_geometry(id,true).grip.distance_to(target)<0.01,"grip follows mouse arc "+id)
	await mouse(target,false)
	check(game.drag=="","release clears capture "+id)

# Drags the petrol gear knob through the neutral channel into a slot.
func pull_gear(gear: int) -> void:
	var point=Vector2.ZERO
	for hit in game.grip_hits:
		if hit.id=="gear" and hit.get("closeup",false): point=hit.position
	check(point!=Vector2.ZERO,"visible closeup grip gear")
	await mouse(point,true)
	check(game.drag=="gear","real mouse captures gear")
	var rect=game.gate_rect(true)
	var here=game.gate_pos
	var slot=game.gate_slot_pos(gear)
	var current=game.gate_local(rect,here)
	for waypoint in [Vector2(here.x,0),Vector2(slot.x,0),slot]:
		var target=game.gate_local(rect,waypoint)
		var e=InputEventMouseMotion.new()
		e.position=target;e.relative=target-current;e.button_mask=MOUSE_BUTTON_MASK_LEFT
		get_tree().root.push_input(e,true)
		await frame()
		current=target
	check(game.control_geometry("gear",true).grip.distance_to(current)<0.01,"knob follows the mouse through the gate")
	await mouse(current,false)
	check(game.drag=="","release clears capture gear")

func energy_checks() -> void:
	for id in ["motorcar","locomotive"]:
		var m=fixture(id)
		check(m.start_engine(true),"neutral zero-pedal start "+id)
		m.set_gear(1);m.state.throttle=0.8
		var before=float(m.state.fleet_by_id[id].fuel)
		m.physics_step(1.0/60)
		check(m.motor_energy.shaft_work_j>0 and m.state.fleet_by_id[id].fuel<before,"first accelerating step consumes work "+id)
		var conversion=8500000.0 if id=="motorcar" else 3600000.0
		check(absf((before-m.state.fleet_by_id[id].fuel)*conversion-m.motor_energy.used_j)<1e-6,"energy store agrees with measured work "+id)
		var clone=Model.new()
		check(clone.restore(m.serialize()) and clone.state.throttle==m.state.throttle and clone.state.brake==m.state.brake,"save preserves controls "+id)
		m.state.throttle=0;m.state.gear=0;m.state.engine=false;m.state.v=0;m.state.brake=1
		before=m.state.fleet_by_id[id].fuel
		for i in range(120): m.physics_step(1.0/60)
		check(m.state.fleet_by_id[id].fuel==before and m.regen_kw==0,"stationary brake never creates energy "+id)
	var petrol=fixture("motorcar")
	petrol.start_engine(true)
	var before=float(petrol.state.fleet_by_id.motorcar.fuel)
	petrol.state.throttle=1
	petrol.physics_step(1)
	check(absf(before-petrol.state.fleet_by_id.motorcar.fuel-0.0012*1.8)<1e-9,"neutral petrol revving at full pedal burns only the idle burn scaled by rpm")
	for speed in [0.01,2.0,5.0]:
		var m=fixture("locomotive")
		m.state.fleet_by_id.locomotive.fuel=0.3;m.state.v=speed;m.state.brake=1
		var kinetic=0.5*m.train_mass()*speed*speed
		m.physics_step(1.0)
		check(m.motor_energy.recovered_j<=kinetic*0.75+0.0001,"regen bounded by actual braking energy, including final stop")
		check(m.motor_energy.recovered_j<=m.motor_energy.brake_work_j*0.75+0.0001,"regen is fraction of brake work")
	var full=fixture("locomotive")
	full.state.fleet_by_id.locomotive.fuel=full.object_stats("locomotive").tank;full.state.v=2;full.state.brake=1
	full.physics_step(1.0/60)
	check(full.regen_kw==0,"full battery does not advertise unaccepted regeneration")
	var m=Model.new();m.new_game(42);m.accept_mission(m.current_mission())
	check(m.mission_origin()=="A","new order records explicit origin")
	var legacy=m.serialize();legacy.active.erase("origin_station_id")
	check(m.restore(legacy) and m.mission_origin()=="A","legacy active order origin migrates")
	var corrupt=m.serialize();corrupt.active.origin_station_id="unknown"
	check(not m.restore(corrupt),"unknown origin rejected before replacing career")
	m.state.active.title="Дальний бор → Дальний бор"
	check(not m.journey_heading().contains("Дальний бор → Дальний бор"),"heading independent from order title")

func world_controls() -> void:
	for id in ["handcar","motorcar","locomotive"]:
		for facing in [-1,1]:
			for zoom in [0.75,1.0,1.5]:
				context="world "+id+" facing="+str(facing)+" zoom="+str(zoom)+" "
				game.model=fixture(id);game.model.state.direction=facing
				game.control_zoom=false;game.zoom_level=zoom;game.rebuild()
				game.camera_s=100;game.camera_x=1040
				await frame()
				var point=Vector2.ZERO
				for hit in game.grip_hits:
					if hit.id=="brake": point=hit.position
				await mouse(point+Vector2(3,1),true)
				check(game.drag=="brake","world grip captures with offset")
				var before=game.model.state.brake
				game.camera_x+=30
				var e=InputEventMouseMotion.new()
				e.position=point;e.relative=Vector2.ZERO;e.button_mask=MOUSE_BUTTON_MASK_LEFT
				get_tree().root.push_input(e,true)
				check(absf(game.model.state.brake-before)<0.00001,"camera movement cannot apply brake")
				var geo=game.lever_geometry("brake")
				var desired=geo.pivot+Vector2(0,-float(geo.length)*0.7) if game.control_kind("brake")=="slider" else geo.pivot+Vector2(0,-geo.pivot.distance_to(geo.grip)).rotated(lerpf(-0.55,0.55,0.7))
				var delta=game.body_transform(id,game.model.body_s(0)).basis_xform(desired-game.lever_target_point)
				e=InputEventMouseMotion.new();e.position=point+delta;e.relative=delta;e.button_mask=MOUSE_BUTTON_MASK_LEFT
				get_tree().root.push_input(e,true)
				await frame()
				check(absf(game.model.state.brake-0.7)<0.00001,"arc follows local mouse travel under facing and zoom")
				await mouse(point+delta,false)
				check(absf(game.model.state.brake-0.7)<0.00001 and game.drag=="","world setting persists on release")

func run() -> void:
	out_dir=ProjectSettings.globalize_path("res://../qa/v3_p5")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--motor-output="): out_dir=arg.trim_prefix("--motor-output=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	energy_checks()
	game=load("res://main.tscn").instantiate();get_tree().root.add_child(game)
	game.test_mode=true;game.set_physics_process(false);game.set_process(false)
	game.saves.directory=out_dir.path_join("isolated_profile")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		get_tree().root.size=resolution
		await get_tree().create_timer(0.15).timeout
		for id in ["motorcar","locomotive"]:
			context=id+" "+str(resolution)+" "
			game.model=fixture(id);game.screen="game";game.rebuild()
			game.camera_s=100;game.camera_y=0;game.camera_x=game.get_viewport_rect().size.x*0.65
			for i in range(6): await frame()
			var buttons=game.ui.find_children("*","Button",true,false)
			for b in buttons:
				if b.text=="Пульт [C]":
					var point=b.get_global_rect().get_center()
					await mouse(point,true);await mouse(point,false)
			check(game.control_zoom,"pult opens with mouse "+id+str(resolution))
			check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(game.control_zoom_rect()),"pult fits window")
			await pull("throttle",0.5)
			check(game.model.state.throttle>0.4,"throttle persists after release")
			if id=="locomotive":
				check(game.control_ids()==["brake","throttle"],"electric pult has only brake and traction")
				check(game.model.set_gear(0) and game.model.state.get("gear",1)>=0 and game.model.start_engine(false),"electric ignores gear and start requests")
				game.model.physics_step(1.0/60)
				check(game.model.state.engine and game.model.state.gear==1,"electric drive always engaged while charged")
			else:
				await pull("start",1)
				check(not game.model.state.engine and game.toast.contains("0%"),"nonzero throttle startup rejected with reason")
				await pull("throttle",0)
				await pull_gear(1)
				await pull("start",1)
				check(not game.model.state.engine and game.toast.contains("нейтраль"),"startup in gear rejected with reason")
				await pull_gear(0)
				await pull("start",1)
				check(game.model.state.engine,"mouse starts at neutral and zero throttle")
				await pull("start",0)
				check(not game.model.state.engine,"second click turns engine off")
				await pull("start",1)
				var switch_point=game.control_geometry("start",true).grip
				await mouse(switch_point,true)
				var slip=InputEventMouseMotion.new()
				slip.position=switch_point+Vector2(25,0);slip.relative=Vector2(25,0);slip.button_mask=MOUSE_BUTTON_MASK_LEFT
				get_tree().root.push_input(slip,true)
				await mouse(slip.position,false)
				check(game.model.state.engine,"dragging away cancels switch click")
				await pull_gear(1)
				check(game.model.state.gear==1,"gear has fixed detent")
				game.model.state.v=2
				await pull_gear(4)
				check(game.model.state.gear==4 and game.model.state.v==2,"upshift while moving with zero throttle")
				await pull("throttle",0.8)
				await pull_gear(1)
				check(game.model.state.gear==4 and game.toast.contains("15%"),"loaded shift rejected with nearby feedback")
			await pull("brake",0.8)
			var value=game.model.state.brake
			await frame()
			check(value>0.5 and game.model.state.brake==value,"brake stays after release without simultaneous holds")
			get_tree().root.get_texture().get_image().save_png(out_dir.path_join(id+"_"+str(resolution.x)+".png"))
			game.control_zoom=false
	await world_controls()
	var result={"checks":checks,"failures":failures,"input":"actual Viewport.push_input; fixtures set only initial state and gear test speed"}
	var file=FileAccess.open(out_dir.path_join("motor_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("MOTOR CONTROL CHECKS ",checks,"; FAILURES ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
