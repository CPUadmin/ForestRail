extends "res://tests/check_handcar_input.gd"

var started_ms=0
var duration_s=1200.0
var last_report=0.0
var last_release=0.0
var stop_file=""
var regrabs=0
var station_visits=0
var completed=0

func frame(count: int=2) -> void:
	for i in range(count):
		game._process(minf(0.1,maxf(0.001,get_process_delta_time())))
		game.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

func click_button(text: String,prefix: bool=false) -> bool:
	for b in game.ui.find_children("*","Button",true,false)+game.overlay.find_children("*","Button",true,false):
		if (b.text==text or (prefix and b.text.begins_with(text))) and not b.disabled:
			for scroll in game.ui.find_children("*","ScrollContainer",true,false):
				if scroll.is_ancestor_of(b): scroll.ensure_control_visible(b)
			await frame(3)
			var p=b.get_global_rect().get_center()
			await button(p,true);await button(p,false)
			return true
	return false

func cargo_drag(id: String,target_point: Vector2,slot_index: int=-1) -> void:
	await frame()
	var from=Vector2.ZERO
	for hit in game.cargo_hits:
		if hit.id==id: from=hit.rect.get_center()
	check(from!=Vector2.ZERO,"soak cargo remains selectable")
	cursor=from;await button(cursor,true)
	check(game.drag=="cargo","soak mouse captures cargo")
	if slot_index>=0: target_point=game.slot_hits[slot_index].rect.get_center()
	await move(target_point-cursor);await button(cursor,false)
	game.update_hud();await frame(3)

func brake(value: float) -> void:
	if absf(float(game.model.state.brake)-value)<0.001: return
	if game.drag!="": await button(cursor,false)
	var point=Vector2.ZERO
	for hit in game.grip_hits:
		if hit.id=="brake" and not hit.get("closeup",false): point=hit.position
	cursor=point;await button(point,true)
	if game.drag != "brake":
		check(false, "soak captures brake at %s (captured %s)" % [point, game.drag])
		return
	var geo=game.lever_geometry("brake")
	var target=geo.pivot+Vector2(0,-geo.pivot.distance_to(geo.grip)).rotated(lerpf(-0.55,0.55,value))
	var outer=game.body_transform(game.model.vehicle_id(),game.model.body_s_render(0))
	var delta=outer.basis_xform(target-game.lever_target_point)
	await move(delta);await button(cursor,false)
	check(absf(float(game.model.state.brake)-value)<0.01,"soak brake changes through mouse")

func report(done: bool,reason: String="") -> void:
	var elapsed=(Time.get_ticks_msec()-started_ms)/1000.0
	var value={"complete":done,"reason":reason,"elapsed_wall_s":elapsed,"target_s":duration_s,
		"checks":checks,"failures":failures,"regrabs":regrabs,"station_visits":station_visits,"completed_trips":completed,
		"distance_m":game.model.state.get("stats",{}).get("distance",0),"memory_static_bytes":OS.get_static_memory_usage(),
		"input":"Viewport.push_input only; normal game physics; no position, phase or speed assignments",
		"human_trial":false}
	var f=FileAccess.open(out_dir.path_join("soak_progress.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(value,"\t"));f.close()
	if done or reason!="":
		f=FileAccess.open(out_dir.path_join("soak_results.json"),FileAccess.WRITE)
		f.store_string(JSON.stringify(value,"\t"));f.close()
	print("SOAK P8 ",snappedf(elapsed,0.1),"s; visits ",station_visits,"; trips ",completed,"; failures ",failures)

func run() -> void:
	out_dir=ProjectSettings.globalize_path("res://../qa/v3_p8")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--soak-output="): out_dir=arg.trim_prefix("--soak-output=")
		if arg.begins_with("--soak-duration="): duration_s=float(arg.trim_prefix("--soak-duration="))
		if arg.begins_with("--stop-file="): stop_file=arg.trim_prefix("--stop-file=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game=load("res://main.tscn").instantiate();game.test_mode=true
	game.saves.directory=out_dir.path_join("soak_profile_"+str(Time.get_ticks_usec()))
	game.settings_path=game.saves.directory.path_join("settings.json")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.add_child(game);game.set_process(false)
	game.settings.master=0;game.apply_settings()
	get_tree().root.size=Vector2i(1280,720)
	await frame(6)
	started_ms=Time.get_ticks_msec()
	check(await click_button("Новая игра"),"soak starts from actual new-game button")
	if game.model.vehicle_id() != "handcar":
		# The normal career now starts with a pole. Use a fresh isolated lever
		# handcar career so the timed part still exercises the intended controls.
		game.model.new_game(42, 2)
		game.selected_object = game.model.vehicle_id()
		game.rebuild()
		await frame(3)
	while (Time.get_ticks_msec()-started_ms)/1000.0<duration_s and failures.is_empty():
		if stop_file!="" and FileAccess.file_exists(stop_file):
			game.save_game();report(false,"autonomous guard requested stop");get_tree().quit(3);return
		var elapsed=(Time.get_ticks_msec()-started_ms)/1000.0
		if elapsed-last_report>=30:
			last_report=elapsed;report(false)
		if game.modal_kind=="result":
			completed+=1
			check(await click_button("Продолжить перевозки"),"result can continue by mouse")
		elif game.screen=="depot":
			check(await click_button("К погрузке →" if int(game.model.state.chapter)==0 else "Взять ·",int(game.model.state.chapter)>0),"soak chooses contract through UI")
		elif game.model.state.phase=="loading":
			var id=str(game.model.state.cargo[0].id)
			await cargo_drag(id,Vector2.ZERO,0)
			check(await click_button("Отправиться →"),"soak departs through UI")
		else:
			var m=game.model
			var destination=m.next_destination()
			var index=game.station_number(destination)
			var remaining=(m.service_stop(index)-float(m.state.s))*int(m.state.direction)
			var stop_distance=m.stopping_distance(absf(float(m.state.v)))
			var interaction=game.station_state()
			if interaction.can_transfer and interaction.station_id==destination:
				station_visits+=1
				if game.drag!="": await button(cursor,false)
				for item in m.state.cargo.duplicate(true):
					if item.destination==destination and not item.delivered: await cargo_drag(item.id,game.dock_rect().get_center())
				game.save_game()
				if m.state.active.get("phase","")=="return" and destination!="A": check(await click_button("Развернуть"),"soak turns consist through UI")
			elif remaining<maxf(1.4,stop_distance+0.7):
				await brake(m.brake_safe() if absf(float(m.state.v)) > 1.2 else 1.0)
			else:
				await brake(0.0)
				if m.can_push_handcar():
					if game.drag!="": await button(cursor,false)
					cursor=game.body_transform("handcar",m.body_s(0))*(Vector2(1.16,-0.45)*game.ArtV3.PX)
					await button(cursor,true);await move(Vector2(35*int(m.state.direction),0));await button(cursor,false)
				if game.drag!="pump": await grab();regrabs+=1
				if elapsed-last_release>=30 and absf(float(m.state.v))>0.5:
					await button(cursor,false);await frame(12);await grab();regrabs+=1;last_release=elapsed
				var pose=m.handcar.pose()
				await target(float(pose.angle)+signf(pose.dangle_dphase)*0.32)
		await frame(1)
	game.cancel_drag();game.save_game()
	if not failures.is_empty(): await shot("soak_failure")
	check((Time.get_ticks_msec()-started_ms)/1000.0>=duration_s,"full soak wall duration reached")
	if duration_s>=1200: check(station_visits>=2 and completed>=1,"continuous soak includes stations and payout")
	report(failures.is_empty(),"finished" if failures.is_empty() else "check failed")
	get_tree().quit(0 if failures.is_empty() else 1)
