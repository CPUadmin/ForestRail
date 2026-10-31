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
	check(m.state.money == money and m.state.active.pending_reward == 120, "reward deferred until return")
	check(m.turn() and m.state.direction == -1, "safe turn after unloading")
	m.state.s = 0
	check(m.settle(), "settle M01 at home")
	check(not m.settle() and m.state.money == 120, "no duplicate payment")
	# Drive the ten-mission cycle with manual loading and all dropoffs. Money
	# for purchases comes from real free runs, as a player would earn it
	# (ECONOMY_v3_2_RU.md): steam before M03, petrol and W02 before M05,
	# electric before M09 and W03 before M10.
	var free_runs = 0
	for chapter in range(1, 10):
		var purchase = {2: "steam", 4: "motorcar", 8: "locomotive"}.get(chapter, "")
		if purchase != "":
			free_runs += earn(m, int(m.vehicle_base(purchase).cost))
			check(m.buy_vehicle(purchase), "buy " + purchase)
		if chapter == 4 or chapter == 9:
			free_runs += earn(m, m.wagon_price(m.next_wagon_id()))
			check(m.buy_wagon(), "buy wagon before " + str(m.current_mission().id))
		var mission = m.current_mission()
		check(m.capacity() >= m.mission_count(mission), "room for full " + str(mission.id))
		m = complete(m, mission, true)
	check(m.state.chapter == 10 and m.state.finale and m.state.money >= 0, "career economy and finale")
	check(free_runs >= 3 and free_runs <= 12, "career needs a few free runs, not a grind: %d" % free_runs)
	print("ECONOMY free runs %d, money after M10 %d" % [free_runs, int(m.state.money)])
	m.state.money += 5000
	check(m.state.fleet_by_id.size() == 4 and m.state.wagons_by_id.size() == 3, "garage retains fleet")
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
	for i in range(mini(m.state.cargo.size(), m.slots().size())): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
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
	m.state.throttle = 0.5
	check(m.set_gear(2) and m.start_engine(false) and m.state.gear == 1, "electric drive has no gearbox or start switch")
	var money_before_rescue = int(m.state.money)
	var cargo_before_rescue = m.state.cargo.size()
	var refill_before_rescue = m.refill_cost()
	m.rescue()
	# The tow is free; the refill after it is paid at depot prices (3.2).
	check(m.state.phase == "depot" and m.state.cargo.size() == cargo_before_rescue and cargo_before_rescue > 0 and int(m.state.money) == money_before_rescue - refill_before_rescue, "rescue keeps cargo and charges only the refill")
	check(m.refill_cost() == 0 and refill_before_rescue > 0, "rescue refills the battery")
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
	# A replaced career stays outside the backup rotation of the new one.
	check(storage.write(m), "repair primary save")
	var career_money = int(m.state.money)
	check(storage.archive_career(), "archive career before a new game")
	var fresh = Model.new()
	fresh.new_game(7)
	check(storage.write(fresh) and storage.write(fresh), "new career saves twice")
	check(int(storage.read_valid(SaveGame.PREVIOUS_CAREER).money) == career_money, "previous career survives the new career's saves")
	buffer_checks()
	charge_traction_checks()
	economy_v32_checks()
	worst_economy()
	var report = {"checks": checks, "failures": failures, "engine": Engine.get_version_info().string}
	var out = FileAccess.open("user://qa_model/results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "\t"))
	out.close()
	print("MODEL CHECKS ", checks, "; FAILURES ", failures.size())
	quit(0 if failures.is_empty() else 1)

# Load, deliver, turn, save/restore with the payout pending, settle.
func complete(m, mission: Dictionary, checks_on: bool = false, broken_fragile: bool = false):
	m.refuel()
	var ok = m.accept_mission(mission)
	if checks_on: check(ok, "accept " + str(mission.id))
	var slots = m.slots()
	for i in range(mini(m.state.cargo.size(), slots.size())): m.transfer(m.state.cargo[i].id, slots[i].key)
	if broken_fragile:
		for item in m.state.cargo:
			if item.type == "fragile": item.health = 0.0
	ok = m.depart()
	if checks_on: check(ok, "depart " + str(mission.id))
	for stop in mission.dropoffs:
		park(m,station_index(m,stop.station))
		for item in m.state.cargo.duplicate(true):
			if item.destination == stop.station and not item.delivered: m.transfer(item.id, "")
	if checks_on: check(m.state.active.get("phase","") == "return", "return phase " + str(mission.id))
	m.turn()
	var restored = Model.new()
	ok = restored.restore(m.serialize())
	if checks_on: check(ok, "restore pending payout " + str(mission.id))
	m = restored
	var paid = m.state.paid_ids.size()
	# Stopping at home pays the order by itself; settle() covers a train
	# that is already standing there.
	park(m,0)
	if m.state.paid_ids.size() == paid: m.settle()
	if checks_on: check(m.state.paid_ids.size() == paid + 1, "finish " + str(mission.id))
	return m

# Take the best-paying free run until the target sum is reached.
func earn(m, target: int) -> int:
	var runs = 0
	while int(m.state.money) < target and runs < 20:
		var offers = m.free_offers()
		offers.sort_custom(func(a, b): return int(a.reward) > int(b.reward))
		var model_after = complete(m, offers[0])
		m.state = model_after.state
		runs += 1
	return runs

func station_index(m, id: String) -> int:
	for i in range(m.data.stations.size()):
		if m.data.stations[i].id == id: return i
	return 0

func buffer_checks() -> void:
	for speed in [0.5, 3.0]:
		var m = Model.new()
		m.new_game(42)
		m.state.phase = "route"
		m.state.cargo = [{"id": "crate", "type": "fragile", "destination": "B", "slot": "handcar:0", "delivered": false, "health": 1.0}]
		m.state.brake = 0
		m.state.s = m.route.length_m - 2.004
		m.state.v = speed
		m.physics_step(1.0 / 60)
		check(m.state.v == 0, "buffer stop halts the train at %.1f m/s" % speed)
		var health = float(m.state.cargo[0].health)
		check(health == 1.0 if speed < Model.BUFFER_SAFE_SPEED else health < 1.0, "buffer impact at %.1f m/s damages only fast fragile cargo" % speed)

func charge_traction_checks() -> void:
	var m = Model.new()
	m.new_game(42)
	m.state.money = 5000
	m.buy_vehicle("motorcar")
	m.buy_vehicle("locomotive")
	var tank = float(m.object_stats("locomotive").tank)
	for point in [[1.0, 1.0], [0.75, 1.0], [0.5, 0.7], [0.25, 0.3], [0.15, 0.15], [0.0, 0.0], [0.6, 0.82], [0.2, 0.225]]:
		m.state.fleet_by_id.locomotive.fuel = tank * point[0]
		check(absf(m.charge_traction_factor() - point[1]) < 0.0001, "electric traction %.0f%% charge gives %.1f%% effort" % [point[0] * 100, point[1] * 100])
	m.state.fleet_by_id.motorcar.fuel = 0.1
	check(m.vehicle_id() == "locomotive", "locomotive selected for traction scenario")
	# The same start on the flat at full and at a quarter charge.
	var speeds: Array = []
	for charge in [1.0, 0.25]:
		m.state.fleet_by_id.locomotive.fuel = tank * charge
		m.state.phase = "route"
		m.state.s = 120.0
		m.state.v = 0.0
		m.state.brake = 0.0
		m.state.engine = true
		m.state.gear = 1
		m.state.throttle = 1.0
		for i in range(60): m.physics_step(1.0 / 60)
		speeds.append(float(m.state.v))
	check(speeds[1] > 0 and speeds[1] < speeds[0] * 0.6, "quarter charge pulls clearly weaker than full charge")

func economy_v32_checks() -> void:
	var m = Model.new()
	m.new_game(42)
	m.state.money = 499
	check(not m.buy_vehicle("steam"), "steam costs 500")
	m.state.money = 500
	check(m.buy_vehicle("steam") and m.state.money == 0 and m.capacity() == 2 and m.state.consist_ids == ["W01"], "steam comes with W01 and has no deck places")
	check(m.object_stats("steam").slots == 0 and m.object_stats("motorcar").slots == 0 and m.object_stats("locomotive").slots == 0, "no deck places on steam, petrol, electric")
	# Paid refill: half a tank of coal costs half its price; no money, no coal.
	m.state.fleet_by_id.steam.fuel = 12.0
	m.state.money = 100
	check(m.refill_cost() == 54 and m.refuel() and m.state.money == 46 and is_equal_approx(float(m.state.fleet_by_id.steam.fuel), 24.0), "coal refill is paid")
	m.state.fleet_by_id.steam.fuel = 0.0
	m.state.money = 15
	m.refuel()
	check(m.state.money == 0 and is_equal_approx(float(m.state.fleet_by_id.steam.fuel), 15.0 / 4.5), "too little money buys part of the coal")
	m.state.fleet_by_id.steam.water = 0.0
	check(not m.start_engine(true), "no water, no fire")
	# Missions name the weakest class; stronger machines may take them.
	m.state.fleet_by_id.steam.water = 160.0
	check(m.mission_error(m.data.missions[0]) == "", "steam may run a handcar order")
	m.state.money = 10000
	check(m.buy_wagon() and m.state.wagons_by_id.has("W02") and m.state.money == 9650, "W02 costs 350")
	# Old save: two items on the petrol deck, W01 full -> W01 cannot take
	# them, so the temporary wagon WT carries them until the order is done.
	var old = Model.new()
	old.new_game(42)
	old.state.money = 5000
	old.buy_vehicle("motorcar")
	old.state.chapter = 4
	old.accept_mission(old.current_mission())
	var saved = old.serialize()
	saved.consist_ids = ["W01"]
	saved.fleet_by_id.motorcar.consist = ["W01"]
	saved.wagons_by_id.erase("W02")
	var slots = ["motorcar:0", "motorcar:1", "W01:0", "W01:1"]
	for i in range(saved.cargo.size()): saved.cargo[i].slot = slots[i]
	var migrated = Model.new()
	check(migrated.restore(saved), "old petrol-deck save loads")
	var in_temp = 0
	for item in migrated.state.cargo:
		check(str(item.slot).begins_with("W"), "deck cargo moved to a wagon " + str(item.id))
		if str(item.slot).begins_with(Model.TEMP_WAGON): in_temp += 1
	check(in_temp == 2 and migrated.state.cargo.size() == 4, "temporary wagon holds the two deck items")
	check(migrated.back_to_depot() and migrated.cancel_mission(), "cancel the migrated order from the depot")
	check(not migrated.state.wagons_by_id.has(Model.TEMP_WAGON) and Model.TEMP_WAGON not in migrated.state.consist_ids, "temporary wagon leaves once its cargo is gone")

func worst_economy() -> void:
	var m = Model.new()
	m.new_game(42)
	var runs = 0
	for chapter in range(10):
		var purchase = {2: "steam", 4: "motorcar", 8: "locomotive"}.get(chapter, "")
		if purchase != "":
			runs += earn(m, int(m.vehicle_base(purchase).cost))
			check(m.buy_vehicle(purchase), purchase + " reachable with maximum fragile penalty")
		if chapter == 4 or chapter == 9:
			runs += earn(m, m.wagon_price(m.next_wagon_id()))
			check(m.buy_wagon(), "wagon reachable with maximum fragile penalty")
		m = complete(m, m.current_mission(), true, true)
	check(m.state.finale and m.state.money >= 0 and runs <= 14, "career finishes with maximum fragile penalty: %d free runs" % runs)
	print("ECONOMY worst case free runs %d, money after M10 %d" % [runs, int(m.state.money)])
