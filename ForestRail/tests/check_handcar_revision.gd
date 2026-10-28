extends Node

const Model = preload("res://scripts/model.gd")
var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func setup(id: String):
	var m = Model.new()
	m.new_game(42)
	m.state.money = 5000
	if id != "handcar": m.buy_vehicle("motorcar")
	if id == "locomotive": m.buy_vehicle("locomotive")
	m.state.chapter = {"handcar": 0, "motorcar": 2, "locomotive": 6}[id]
	m.accept_mission(m.current_mission())
	for i in range(m.state.cargo.size()): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	m.depart()
	return m

func run() -> void:
	for id in ["motorcar", "locomotive"]:
		var m = setup(id)
		var positions: Array = []
		for i in range(m.body_ids().size()): positions.append(m.body_s(i))
		var cargo_before = JSON.stringify(m.state.cargo)
		check(m.set_reverser(-1), "reverse from stop with cargo " + id)
		for i in range(positions.size()): check(m.body_s(i) == positions[i], "reverse does not teleport " + id)
		check(m.state.direction == 1 and m.drive_direction() == -1, "reverse is separate from facing " + id)
		m.state.brake = 0
		if id != "handcar":
			m.start_engine(true)
			m.set_gear(1)
			m.state.throttle = 0.7
		for frame in range(240):
			m.physics_step(1.0 / 60)
		check(m.state.s < -0.5 and m.state.v < -0.2, "actual backward propulsion " + id)
		check(not m.set_reverser(1), "cannot reverse while moving " + id)
		check(JSON.stringify(m.state.cargo) == cargo_before, "reverse preserves loaded cargo " + id)
		var copy = Model.new()
		check(copy.restore(m.serialize()) and copy.drive_direction() == -1, "save restores reverser " + id)
		var legacy = m.serialize()
		legacy.erase("reverser")
		legacy.erase("flywheel_energy")
		check(copy.restore(legacy) and copy.state.reverser == 1, "old version save migrates " + id)
	var m = setup("handcar")
	m.state.brake = 0
	var input_work = 0.0
	var output_work = 0.0
	for frame in range(600):
		preload("res://tests/handcar_input.gd").pull(m)
		m.physics_step(1.0 / 60)
		input_work += m.pump_work
		output_work += m.output_power / 60
		check(m.output_power <= m.object_stats("handcar").power + 0.001, "power cap")
	check(output_work <= input_work + 0.01, "measured hand work matches output telemetry")
	check(m.state.v > 2.0, "comfortable loaded handcar start")
	m.reset_input()
	for i in range(300): m.physics_step(1.0 / 60)
	check(m.hand_drive.last.flywheel_energy > 0 and m.output_power == 0 and m.state.v > 0, "physical flywheel coasts with whole drive")
	var view = load("res://scripts/main.gd").new()
	check(view.wheel_rotation(1, 1) > 0 and view.wheel_rotation(1, -1) < 0, "wheel rotation accounts for reflection")
	check(view.wheel_rotation(-1, 1) < 0, "wheel rotation reverses on backward travel")
	view.free()
	var file = FileAccess.open("user://qa_model/handcar_revision.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "input_work": input_work, "output_work": output_work}, "\t"))
	file.close()
	print("HANDCAR CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
