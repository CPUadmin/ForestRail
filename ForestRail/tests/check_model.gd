extends Node

var root: Window:
	get: return get_tree().root

func quit(code: int = 0) -> void:
	get_tree().quit(code)



const Model = preload("res://scripts/model.gd")

# Model scenarios may position a fixture directly. Service still has to observe
# the same physical dwell as the GUI, rather than bypassing the new guard.
func park(m, index: int) -> void:
	m.state.s=m.service_stop(index)
	m.state.v=0
	m.state.brake=1
	for i in range(20): m.physics_step(1.0/60)
const SaveGame = preload("res://scripts/save_game.gd")
var checks = 0
var failures: Array = []

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		print("FAIL: ", description)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var m = Model.new()
	m.new_game(42)
	check(m.capacity() == 2 and m.train_mass() == 180, "initial handcar")
	check(m.accept_mission(m.current_mission()), "accept M01")
	check(not m.depart(), "reject departure without cargo")
	var slots = m.slots()
	check(m.transfer(m.state.cargo[0].id, slots[0].key), "load first sack")
	check(not m.transfer(m.state.cargo[1].id, slots[0].key), "cannot duplicate occupied slot")
	check(m.transfer(m.state.cargo[1].id, slots[1].key), "load second sack")
	check(m.train_mass() == 250, "cargo changes physical mass")
	check(m.depart(), "depart with all cargo")
	m.state.v = 1.0
	check(not m.transfer(m.state.cargo[0].id, ""), "cargo cannot move while train moves")
	m.state.v = 0.0
	m.state.s = m.route.station_s[2]
	check(not m.transfer(m.state.cargo[0].id, ""), "wrong station cannot receive cargo")
	m.state.s = 0.0
	m.state.brake = 0.0
	for frame in range(120): m.physics_step(1.0 / 60)
	check(absf(m.state.v) < 0.001, "idle lever produces no drive")
	for frame in range(120):
		preload("res://tests/handcar_input.gd").pull(m)
		m.physics_step(1.0 / 60)
	check(m.state.v > 0.25, "real pump motion drives train")
	var before = float(m.state.v)
	m.reset_input()
	m.physics_step(1.0 / 60)
	check(m.pump_work == 0 and m.state.v > 0, "lever release permits coasting")
	m.state.v = 0
	m.state.brake = 1
	park(m,1)
	var money = int(m.state.money)
	for item in m.state.cargo.duplicate(true): check(m.transfer(item.id, ""), "unload at B")
	check(m.state.money == money and m.state.active.pending_reward == 100, "reward deferred until return")
	check(m.turn() and m.state.direction == -1, "safe turn after unloading")
	m.state.s = 0
	check(m.settle(), "settle M01 at home")
	check(not m.settle() and m.state.money == 100, "no duplicate payment")
	# Drive the actual ten-mission domain cycle with manual loading and all dropoffs.
	for chapter in range(1, 10):
		if chapter == 2: check(m.buy_vehicle("motorcar"), "buy motorcar with W01")
		if chapter == 6: check(m.buy_vehicle("locomotive"), "buy electric locomotive with W02")
		if chapter == 9: check(m.buy_wagon(), "buy W03 for six slots")
		m.refuel()
		var mission = m.current_mission()
		check(m.accept_mission(mission), "accept " + str(mission.id))
		slots = m.slots()
		for i in range(m.state.cargo.size()): check(m.transfer(m.state.cargo[i].id, slots[i].key), "load " + str(mission.id))
		check(m.depart(), "depart " + str(mission.id))
		for stop in mission.dropoffs:
			park(m,station_index(m,stop.station))
			for item in m.state.cargo.duplicate(true):
				if item.destination == stop.station:
					check(m.transfer(item.id, ""), "dropoff " + str(mission.id))
		check(m.state.active.phase == "return", "return phase " + str(mission.id))
		check(m.turn(), "turn " + str(mission.id))
		var saved = m.serialize()
		var restored = Model.new()
		check(restored.restore(saved), "restore pending payout " + str(mission.id))
		m = restored
		m.state.s = 0
		check(m.settle(), "finish " + str(mission.id))
	check(m.state.chapter == 10 and m.state.finale and m.state.money == 1360, "career economy and finale")
	check(m.state.fleet_by_id.size() == 3 and m.state.wagons_by_id.size() == 3, "garage retains fleet")
	var final_restore = Model.new()
	check(final_restore.restore(m.serialize()) and final_restore.state.finale and final_restore.state.chapter == 10, "save and restore after finale")
	check(m.upgrade("handcar", "handcar_lever"), "upgrade retained old vehicle")
	check(m.select_vehicle("handcar") and float(m.effects("handcar").get("work_multiplier",1))>1 and m.object_stats("handcar").power==220, "handcar retains torque upgrade under the physical power cap")
	check(m.select_vehicle("locomotive") and m.state.consist_ids.size() == 3, "vehicle consist configuration retained")
	check(m.upgrade("W01", "wagon_suspension"), "individual wagon upgrade")
	check(m.object_stats("W01").shock == 0.75 and m.object_stats("W02").shock == 1.0, "W01 upgrade leaves W02 stock")
	check(m.upgrade("W01", "wagon_suspension"), "second upgrade")
	check(m.object_stats("W01").shock == 0.5, "absolute second level")
	check(not m.upgrade("W01", "wagon_suspension"), "max upgrade cannot repurchase")
	check(m.select_vehicle("motorcar") and m.toggle_wagon("W01"), "wagon transfer")
	check(m.object_stats("W01").shock == 0.5, "wagon level follows ID")
	for repeat in range(3):
		var offer = m.free_offers()[0]
		check(m.accept_mission(offer), "free offer after finale")
		for i in range(m.state.cargo.size()): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
		m.depart()
		for stop in offer.dropoffs:
			park(m,station_index(m,stop.station))
			for item in m.state.cargo.duplicate(true):
				if item.destination == stop.station: m.transfer(item.id, "")
		m.state.s = 0
		check(m.settle(), "settle free offer")
	# Validate seed continuity, flat stations, physical grade and holding.
	for world_seed in [17, 42, 103, 2026, 8159]:
		m.new_game(world_seed)
		var previous = m.route.sample(-39)
		var max_grade = 0.0
		var max_early = 0.0
		for s in range(-38, 1739):
			var p = m.route.sample(s)
			check(p.distance_to(previous) < 1.01, "continuous seed %d at %d" % [world_seed, s])
			previous = p
			var grade = absf(tan(m.route.slope(s)))
			max_grade = maxf(max_grade, grade)
			if s < 600: max_early = maxf(max_early, grade)
		check(max_grade <= 0.06 and max_early <= 0.03, "grade bounds seed " + str(world_seed))
		for s in m.route.station_s:
			check(absf(m.route.slope(s)) < 0.002, "flat station")
	# Battery: drain under electric traction and regenerate from motion only.
	m.new_game(42)
	m.state.money = 5000
	m.buy_vehicle("motorcar")
	m.buy_vehicle("locomotive")
	m.state.chapter = 6
	m.accept_mission(m.data.missions[6])
	for i in range(m.state.cargo.size()): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	m.depart()
	m.state.engine = true
	m.state.gear = 1
	m.state.throttle = 0.8
	m.state.brake = 0
	var battery = float(m.state.fleet_by_id.locomotive.fuel)
	for i in range(600): m.physics_step(1.0 / 60)
	check(m.state.fleet_by_id.locomotive.fuel < battery and m.state.v > 0, "electric drive consumes battery")
	m.state.engine = false
	m.state.throttle = 0
	m.state.brake = 0.3
	battery = float(m.state.fleet_by_id.locomotive.fuel)
	for i in range(20): m.physics_step(1.0 / 60)
	check(m.state.fleet_by_id.locomotive.fuel > battery, "braking recovers energy")
	m.state.v = 0
	m.state.s = 0
	m.state.brake = 1
	battery = float(m.state.fleet_by_id.locomotive.fuel)
	for i in range(60): m.physics_step(1.0 / 60)
	check(is_equal_approx(m.state.fleet_by_id.locomotive.fuel, battery), "stationary brake never creates energy")
	check(not m.set_gear(2) or m.state.throttle < 0.15, "gear interlock")
	m.state.throttle = 0.5
	check(not m.set_gear(2), "reject shift with throttle")
	m.rescue()
	check(m.state.phase == "depot" and m.state.cargo.size() == 4 and m.state.money == 4220, "rescue preserves cargo and money")
	# Atomic save and corruption recovery use a dedicated directory.
	var storage = SaveGame.new()
	storage.directory = "user://qa_model"
	DirAccess.make_dir_recursive_absolute(storage.directory)
	check(storage.write(m), "write primary save")
	m.state.money += 1
	check(storage.write(m), "write with backup")
	var backup_money = int(storage.read_valid("save_v2.backup.json").money)
	var corrupt = FileAccess.open(storage.path("save_v2.json"), FileAccess.WRITE)
	corrupt.store_string("{ broken")
	corrupt.close()
	check(storage.read_valid("save_v2.json").is_empty(), "corruption detected")
	check(not storage.read_valid("save_v2.backup.json").is_empty(), "backup remains available")
	check(storage.write(m), "save in memory after corrupt primary")
	check(int(storage.read_valid("save_v2.backup.json").money) == backup_money, "corrupt primary cannot overwrite good backup")
	worst_economy()
	var report = {"checks": checks, "failures": failures, "engine": Engine.get_version_info().string}
	var out = FileAccess.open("user://qa_model/results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "\t"))
	out.close()
	print("MODEL CHECKS ", checks, "; FAILURES ", failures.size())
	quit(0 if failures.is_empty() else 1)

func station_index(m, id: String) -> int:
	for i in range(m.data.stations.size()):
		if m.data.stations[i].id == id: return i
	return 0

func worst_economy() -> void:
	var m = Model.new()
	m.new_game(42)
	for chapter in range(10):
		if chapter == 2: check(m.buy_vehicle("motorcar"), "motorcar affordable with maximum fragile penalty")
		if chapter == 6: check(m.buy_vehicle("locomotive"), "locomotive affordable with maximum fragile penalty")
		if chapter == 9: check(m.buy_wagon(), "W03 affordable with maximum fragile penalty")
		m.refuel()
		var mission = m.current_mission()
		check(m.accept_mission(mission), "accept maximum-penalty career " + str(mission.id))
		for i in range(m.state.cargo.size()):
			m.transfer(m.state.cargo[i].id, m.slots()[i].key)
			if m.state.cargo[i].type == "fragile": m.state.cargo[i].health = 0.0
		m.depart()
		for stop in mission.dropoffs:
			park(m,station_index(m,stop.station))
			for item in m.state.cargo.duplicate(true):
				if item.destination == stop.station: m.transfer(item.id, "")
		m.state.s = 0
		m.settle()
	check(m.state.finale and m.state.money == 1234, "worst fragile penalty matches specified 1234 balance")
