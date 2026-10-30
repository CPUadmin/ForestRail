extends Node

var bench
var game
var checks=0
var failures: Array=[]
var movie=false
var out_dir=""
var cursor=Vector2.ZERO
var clips: Array=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL: ",label)

func _ready() -> void:
	call_deferred("run")

func frame(count: int = 2) -> void:
	for i in range(count):
		game._process(1.0/30 if movie else 1.0/60)
		bench.refresh()
		game.art_world.update_view()
		game.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

func button(point: Vector2, pressed: bool) -> void:
	var event=InputEventMouseButton.new()
	event.position=point;event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_tree().root.push_input(event,true)
	await frame(1)

func move(delta: Vector2) -> void:
	cursor+=delta
	var event=InputEventMouseMotion.new()
	event.position=cursor;event.relative=delta;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(event,true)
	await frame(1)

var grip_side=1.0

func point_for_pump() -> Vector2:
	for hit in game.grip_hits:
		if hit.id=="pump" and float(hit.get("side",1.0))==grip_side: return hit.position
	return Vector2.ZERO

func grab(offset: Vector2 = Vector2.ZERO) -> void:
	await frame()
	cursor=point_for_pump()+offset
	await button(cursor,true)
	check(game.drag=="pump" and game.model.hand_drive.held,"real GUI captures pump")

func target(angle: float) -> void:
	var pose=game.model.handcar.pose()
	var desired=pose.rocker+Vector2(cos(angle),sin(angle))*float(game.model.handcar.config.grip_radius)*grip_side
	var local_delta=desired-game.pump_target_point
	var delta=game.body_transform("handcar",game.model.body_s(0)).basis_xform(local_delta*game.ArtV3.PX)
	await move(delta)

func shot(name: String) -> void:
	await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name+".png"))

func run() -> void:
	out_dir=ProjectSettings.globalize_path("res://../qa/v3_p4")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--drive-output="): out_dir=arg.trim_prefix("--drive-output=")
	movie="--p4-movie" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().root.size=Vector2i(1600,900)
	bench=load("res://dev/handcar_drive_bench.gd").new()
	get_tree().root.add_child(bench)
	game=bench.game
	bench.set_process(false);game.set_process(false);game.set_physics_process(false)
	await frame()
	for facing in [-1,1]:
		for zoom in [0.75,1.0,1.5]:
			for grip_side_value in [-1.0,1.0]:
				grip_side=grip_side_value
				bench.reset_fixture(true)
				game.model.state.direction=facing
				game.zoom_level=zoom
				await grab(Vector2(8,2))
				var before=game.model.handcar.phase
				var initial_target=game.model.hand_drive.target_angle
				check(absf(initial_target-game.model.handcar.pose().angle)<1e-7,"capture offset has no target snap")
				game.camera_s+=3;game.camera_x+=40
				await move(Vector2.ZERO)
				check(absf(game.model.hand_drive.target_angle-initial_target)<1e-5,"camera motion and zero event leave hand force unchanged")
				await target(initial_target+0.28)
				check(absf(game.model.hand_drive.target_angle-initial_target-0.28)<0.0001,"local target invariant under zoom/facing")
				check(game.model.handcar.phase==before,"mouse target does not teleport phase")
				for i in range(45): game._physics_process(1.0/60)
				check(game.model.state.v*facing>0.05,"mouse effort moves coupled drive")
				await button(cursor,false)
				check(not game.model.hand_drive.held,"release removes hand force")
	# Record empty and loaded driving with real GUI events, then release for coast.
	grip_side=1.0
	for loaded in [false,true]:
		bench.reset_fixture(loaded)
		await grab()
		var seconds=16.0 if movie else 3.0
		var fps=30 if movie else 60
		var timer=0.0
		for i in range(int(seconds*fps)):
			var pose=game.model.handcar.pose()
			await target(float(pose.angle)+signf(pose.dangle_dphase)*0.32)
			for tick in range(60/fps): game._physics_process(1.0/60)
			timer+=1.0/fps
		var speed=game.model.state.v
		await shot("loaded_drive" if loaded else "empty_drive")
		await button(cursor,false)
		var phase=game.model.handcar.phase
		for i in range(60 if movie else 10):
			for tick in range(60/fps): game._physics_process(1.0/60)
			await frame(1)
		check(game.model.output_power==0 and game.model.handcar.phase!=phase,"GUI release gives physical coasting")
		check(game.model.hand_drive.last.flywheel_energy>0,"flywheel retains kinetic energy on coast")
		clips.append({"loaded":loaded,"mass_kg":game.model.train_mass(),"seconds":timer,"speed_mps":speed,"flywheel_j":game.model.hand_drive.last.flywheel_energy})
		await shot("loaded_coast" if loaded else "empty_coast")
	# A separate body-edge gesture is required to leave a dead point from rest.
	bench.reset_fixture(true)
	game.model.handcar.set_phase(game.model.handcar.limits.maximum.phase)
	await frame()
	var outer=game.body_transform("handcar",game.model.body_s(0))
	cursor=outer*(Vector2(1.16,-0.45)*game.ArtV3.PX)
	await button(cursor,true)
	check(game.drag=="push","edge captures explicit push gesture")
	var s=game.model.state.s
	await move(Vector2(40,0))
	check(game.model.hand_drive.nudge_work>0 and game.model.hand_drive.push_used<=20,"push counts bounded external work")
	check(game.model.state.s==s,"push changes momentum without phase/position teleport")
	await button(cursor,false)
	await shot("dead_point_push")
	await grab()
	get_tree().root.size=Vector2i(1280,720)
	await frame()
	check(game.drag=="" and not game.model.hand_drive.held,"resize cancels unfinished hand capture")
	get_tree().root.size=Vector2i(1600,900)
	var file=FileAccess.open(out_dir.path_join("input_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"movie":movie,"clips":clips,"input":"Viewport.push_input, real mouse event dispatcher; no phase/s/v writes during recorded driving"},"\t"));file.close()
	print("HANDCAR INPUT CHECKS ",checks,"; FAILURES ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
