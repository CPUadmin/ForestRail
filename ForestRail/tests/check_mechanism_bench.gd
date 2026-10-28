extends Node

var bench
var checks=0
var failures: Array=[]
var out_dir=""
var movie=false
var frames=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL: ",label)

func _ready() -> void:
	call_deferred("run")

func frame(count: int = 2) -> void:
	for i in range(count):
		bench.refresh()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		frames+=1

func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=point;event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_tree().root.push_input(event,true)
		await frame()

func key(value: int) -> void:
	var event=InputEventKey.new()
	event.keycode=value;event.pressed=true
	get_tree().root.push_input(event,true)
	await frame()

func shot(name: String) -> void:
	await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name+".png"))

func run() -> void:
	out_dir=ProjectSettings.globalize_path("res://../qa/v3_p3")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mechanism-output="): out_dir=arg.trim_prefix("--mechanism-output=")
	movie="--p3-movie" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().root.size=Vector2i(1600,900)
	bench=load("res://dev/mechanism_bench.gd").new()
	get_tree().root.add_child(bench)
	bench.set_process(false)
	await frame()
	await shot("bench_initial")
	for i in range(120 if movie else 10):
		bench._process(1.0/30 if movie else 1.0/60)
		await frame(1)
	await click(bench.pause_button.get_global_rect().get_center())
	check(not bench.running,"GUI pauses geometric motor")
	var phase=bench.mechanism.phase
	for i in range(30 if movie else 5): bench._process(1.0/30);await frame(1)
	check(bench.mechanism.phase==phase,"arbitrary phase holds exactly while paused")
	await key(KEY_RIGHT)
	check(absf(bench.mechanism.phase-phase-deg_to_rad(1))<1e-10,"one-degree forward step")
	await key(KEY_LEFT)
	check(absf(bench.mechanism.phase-phase)<1e-10,"one-degree reverse step")
	var before=bench.cycles_per_second
	await click(bench.reverse_button.get_global_rect().get_center())
	check(bench.cycles_per_second==-before and bench.mechanism.phase==phase,"reverse changes angular velocity without phase jump")
	await key(KEY_SPACE)
	check(bench.running,"Space resumes")
	bench._process(0.1)
	check(bench.mechanism.phase<phase,"reverse motor rotates backward")
	for i in range(120 if movie else 5): bench._process(1.0/30);await frame(1)
	var rect=bench.phase_slider.get_global_rect()
	await click(Vector2(rect.position.x+rect.size.x*0.37,rect.get_center().y))
	check(not bench.running,"phase slider pauses drive")
	check(absf(fposmod(rad_to_deg(bench.mechanism.phase),360)-133.2)<6,"phase slider seeks arbitrary phase through GUI")
	await shot("bench_arbitrary_phase")
	for degrees in [0,90,180,270]:
		bench.phase_slider.value=degrees
		await shot("bench_phase_"+str(degrees))
		check(absf(bench.frame_pose.phase-bench.mechanism.phase)<1e-10,"display and labels share pose")
		if movie: await frame(15)
	await click(bench.pins_button.get_global_rect().get_center())
	check(not bench.show_pins,"joint overlay can be hidden")
	await shot("bench_no_pins")
	if movie: await frame(30)
	var file=FileAccess.open(out_dir.path_join("bench_gui_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frames,"input":"Viewport.push_input, local coordinates","movie":movie},"\t"));file.close()
	print("MECHANISM BENCH CHECKS ",checks,"; FAILURES ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
