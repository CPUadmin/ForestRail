extends Node
const Fixtures = preload("res://tests/fixtures.gd")

var root: Window:
	get: return get_tree().root

func quit(code: int = 0) -> void:
	get_tree().quit(code)



const Model = preload("res://scripts/model.gd")
var checks = 0
var failures: Array = []

func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	Model.legacy_tanks = true  # physics checks drive far on the old tank sizes (B2.2)
	call_deferred("run")

func setup(id: String, seed_value: int = 42):
	var m = Model.new()
	m.new_game(seed_value)
	m.state.money = 5000
	if id != "handcar": Fixtures.equip(m, id)
	m.state.chapter = {"handcar": 0, "motorcar": 5, "locomotive": 9}[id]
	m.accept_mission(m.current_mission())
	for i in range(m.state.cargo.size()): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	m.depart()
	return m

func pump_at_fps(fps: int) -> Dictionary:
	var m = setup("handcar")
	m.state.brake = 0
	for frame in range(fps * 30):
		var t = float(frame + 1) / fps
		for tick in range(60 / fps):
			preload("res://tests/handcar_input.gd").pull(m)
			m.physics_step(1.0 / 60)
	var distance = float(m.state.s)
	var before = float(m.state.s)
	m.reset_input()
	m.state.brake = 1
	for tick in range(600): m.physics_step(1.0 / 60)
	return {"distance": distance, "braking": absf(float(m.state.s) - before)}

func run() -> void:
	var light = setup("motorcar")
	var heavy = setup("motorcar")
	light.state.cargo = []
	for m in [light, heavy]:
		m.state.engine = true
		m.state.gear = 1
		m.state.throttle = 1
		m.state.brake = 0
		for i in range(120): m.physics_step(1.0 / 60)
	check(light.state.v > heavy.state.v, "cargo mass reduces acceleration under identical input")
	var stopping: Array = []
	for m in [light, heavy]:
		m.state.s = 0
		m.state.v = 3.0
		m.state.engine = false
		m.state.throttle = 0
		m.state.brake = 1
		for i in range(300): m.physics_step(1.0 / 60)
		stopping.append(m.state.s)
	check(stopping[1] > stopping[0], "cargo increases stopping distance")
	var empty = setup("motorcar")
	empty.state.fleet_by_id.motorcar.fuel = 0
	empty.state.engine = true
	empty.state.v = 2.0
	empty.state.brake = 0
	empty.physics_step(1.0 / 60)
	check(not empty.state.engine and empty.state.v > 0, "empty petrol tank stops engine but permits coasting")
	var fps30 = pump_at_fps(30)
	var fps60 = pump_at_fps(60)
	check(absf(fps30.distance - fps60.distance) / fps60.distance <= 0.05, "30/60 FPS travel within 5%")
	check(absf(fps30.braking - fps60.braking) / fps60.braking <= 0.05, "30/60 FPS braking within 5%")
	for seed_value in [17, 42, 103, 2026, 8159]:
		for id in ["handcar", "motorcar", "locomotive"]:
			var m = setup(id, seed_value)
			var worst_s = 40.0
			var worst_grade = 0.0
			var end = 580 if id == "handcar" else 1680
			for s in range(40, end):
				var grade = m.route.slope(s)
				if grade > worst_grade: worst_grade = grade; worst_s = s
			m.state.s = worst_s
			m.state.brake = 1
			m.state.v = 0
			for frame in range(180): m.physics_step(1.0 / 60)
			check(absf(m.state.v) < 0.001 and absf(m.state.s - worst_s) < 0.001, "holding uphill " + id + str(seed_value))
			m.state.direction = -1
			for frame in range(180): m.physics_step(1.0 / 60)
			check(absf(m.state.v) < 0.001, "holding reversed " + id + str(seed_value))
			m.state.direction = 1
			m.state.brake = 0
			for frame in range(900):
				if id == "handcar":
					preload("res://tests/handcar_input.gd").pull(m)
				else:
					m.state.engine = true
					m.state.gear = 1
					m.state.throttle = 1
				m.physics_step(1.0 / 60)
			check(m.state.s > worst_s + 1, "loaded worst hill climb " + id + str(seed_value))
	var m = setup("locomotive")
	# Add every possible capacity level and the heaviest cargo, then test static 6% holding.
	for id in m.state.wagons_by_id:
		m.state.wagons_by_id[id].levels.wagon_platform = 2
	m.state.cargo = []
	for slot in m.slots():
		m.state.cargo.append({"id": slot.key, "slot": slot.key, "type": "logs", "destination": "F", "delivered": false, "health": 1.0})
	for point in m.route.points: point[1] = float(point[0]) * 0.06
	m.state.s = 120
	m.state.v = 0
	m.state.brake = 1
	for i in range(600): m.physics_step(1.0 / 60)
	check(m.state.v == 0, "maximum 12-slot train holds on six percent")
	m.state.direction = -1
	for i in range(600): m.physics_step(1.0 / 60)
	check(m.state.v == 0, "maximum 12-slot train holds reversed on six percent")
	# Invalid semantic saves must be rejected before any live state is replaced.
	var saved = m.serialize()
	for corruption in ["points", "fuel", "cargo", "stats", "wagons"]:
		var bad = saved.duplicate(true)
		match corruption:
			"points": bad.route.points[200] = ["wrong"]
			"fuel": bad.fleet_by_id.locomotive.fuel = "empty"
			"cargo": bad.cargo[0].type = "unknown"
			"stats": bad.stats = {}
			"wagons": bad.consist_ids.append("W01")
		check(not m.validate_save(bad), "reject corrupt " + corruption)
	var report = {"checks": checks, "failures": failures, "fps30": fps30, "fps60": fps60}
	var output = FileAccess.open("user://qa_model/physics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("PHYSICS CHECKS ", checks, "; FAILURES ", failures, "; FPS ", fps30, " vs ", fps60)
	quit(0 if failures.is_empty() else 1)
