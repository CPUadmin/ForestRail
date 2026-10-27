extends RefCounted

const Route = preload("res://scripts/route.gd")
const G = 9.81
const VEHICLE_IDS = ["handcar", "motorcar", "locomotive"]
var data: Dictionary
var route = Route.new()
var state: Dictionary = {}
var message = ""
var pump_angle = 0.0
var pump_pending = 0.0
var pump_stroke = 0.0
var pump_last_direction = 0
var pump_work = 0.0
var acceleration = 0.0
var shock_time = 0.0
var rail_distance = 0.0
var regen_kw = 0.0
var events: Array = []

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))

func new_game(world_seed: int = 42) -> void:
	route.generate(world_seed, data.stations)
	state = {"version": 2, "fleet_by_id": {"handcar": {"levels": {}, "fuel": 0.0, "consist": []}},
		"wagons_by_id": {}, "selected_vehicle_id": "handcar", "consist_ids": [],
		"money": 0, "chapter": 0, "completed_ids": [], "paid_ids": [], "active": {},
		"cargo": [], "s": 0.0, "v": 0.0, "direction": 1, "brake": 1.0, "throttle": 0.0,
		"gear": 0, "engine": false, "phase": "depot", "finale": false,
		"visited_stations": ["A"], "tutorial": true,
		"stats": {"distance": 0.0, "deliveries": 0, "earned": 0, "rescues": 0, "seconds": 0.0}, "offer_serial": 0}
	reset_input()

func reset_input() -> void:
	pump_pending = 0.0
	pump_stroke = 0.0
	pump_last_direction = 0
	pump_work = 0.0

func vehicle_id() -> String:
	return str(state.selected_vehicle_id)

func vehicle_base(id: String = "") -> Dictionary:
	if id == "":
		id = vehicle_id()
	for item in data.vehicles:
		if item.id == id:
			return item
	return {}

func cargo_base(id: String) -> Dictionary:
	for item in data.cargo:
		if item.id == id:
			return item
	return {}

func object_state(id: String) -> Dictionary:
	if state.wagons_by_id.has(id):
		return state.wagons_by_id[id]
	return state.fleet_by_id.get(id, {})

func effects(id: String) -> Dictionary:
	var result: Dictionary = {}
	var object = object_state(id)
	if object.is_empty():
		return result
	for branch in data.upgrade_catalog:
		var lv = int(object.levels.get(branch.id, 0))
		if lv == 0:
			continue
		for key in branch.effects_at_level:
			result[key] = branch.effects_at_level[key][lv - 1]
	return result

func object_stats(id: String) -> Dictionary:
	var wagon = id.begins_with("W")
	var base = data.wagon if wagon else vehicle_base(id)
	var ef = effects(id)
	var slots = int(base.slots if wagon else base.deck_slots) + int(ef.get("add_slots", 0))
	var mass = float(base.mass_kg) + float(ef.get("add_mass_kg", 0))
	var brake_base = 0.0 if wagon else {"handcar": 700.0, "motorcar": 1800.0, "locomotive": 6000.0}[id]
	var result = {"slots": slots, "mass": mass, "rolling": 0.004 * float(ef.get("rolling_multiplier", 1.0)),
		"brake": brake_base * float(ef.get("brake_multiplier", 1.0)) + float(ef.get("add_brake_n", 0)),
		"shock": float(ef.get("cargo_shock_multiplier", 1.0)), "power": 180.0 * float(ef.get("power_multiplier", 1.0)),
		"cycle_work": 120.0 * float(ef.get("work_multiplier", 1.0)),
		"tank": float(base.get("fuel_l", 0)) * float(ef.get("fuel_capacity_multiplier", 1.0))}
	if id == "locomotive":
		result.tank = 0.6 * float(ef.get("fuel_capacity_multiplier", 1.0))
	if not wagon and id != "handcar":
		result.traction = [float(base.traction_n[0]) * float(ef.get("traction_multiplier", 1)) * float(ef.get("low_gear_multiplier", 1)),
			float(base.traction_n[1]) * float(ef.get("traction_multiplier", 1))]
		result.speeds = [float(base.gear_speed_mps[0]), float(base.gear_speed_mps[1]) * float(ef.get("high_gear_speed_multiplier", 1))]
	return result

func body_ids() -> Array:
	return [vehicle_id()] + state.consist_ids

func slots() -> Array:
	var result: Array = []
	for id in body_ids():
		for index in range(object_stats(id).slots):
			result.append({"owner": id, "index": index, "key": id + ":" + str(index)})
	return result

func capacity() -> int:
	return slots().size()

func train_mass() -> float:
	var total = 0.0
	for id in body_ids():
		total += body_mass(id)
	return total

func body_mass(id: String) -> float:
	var total = float(object_stats(id).mass)
	for cargo in state.cargo:
		if str(cargo.slot).begins_with(id + ":") and not cargo.delivered:
			total += float(cargo_base(cargo.type).mass_kg)
	return total

func body_s(index: int) -> float:
	var offset = 0.0 if index == 0 else (3.8 + (index - 1) * 3.5)
	return float(state.s) - float(state.direction) * offset

func train_length() -> float:
	return 3.0 + state.consist_ids.size() * 3.5

func station_index() -> int:
	for i in range(route.station_s.size()):
		if absf(float(state.s) - float(route.station_s[i])) <= 17.5:
			return i
	return -1

func stopped() -> bool:
	return absf(float(state.v)) < 0.1 and float(state.brake) >= 0.95

func depot_editable() -> bool:
	return state.phase == "depot" and stopped() and state.cargo.is_empty() and state.active.is_empty()

func buy_vehicle(id: String) -> bool:
	if not depot_editable() or state.fleet_by_id.has(id):
		return fail("Покупки доступны в депо до погрузки")
	if id == "locomotive" and not state.fleet_by_id.has("motorcar"):
		return fail("Сначала приобрети моторную дрезину")
	var base = vehicle_base(id)
	if int(state.money) < int(base.cost):
		return fail("Не хватает %d монет" % (int(base.cost) - int(state.money)))
	state.money -= int(base.cost)
	state.fleet_by_id[id] = {"levels": {}, "fuel": 0.6 if id == "locomotive" else float(base.fuel_l), "consist": []}
	var wagon_id = "W01" if id == "motorcar" else "W02"
	state.wagons_by_id[wagon_id] = {"levels": {}}
	select_vehicle(id)
	state.consist_ids = ["W01"] if id == "motorcar" else ["W01", "W02"]
	_claim_consist()
	events.append("coins")
	return true

func buy_wagon() -> bool:
	if not depot_editable() or not state.fleet_by_id.has("locomotive") or state.wagons_by_id.has("W03"):
		return fail("Третий вагон доступен после покупки локомотива")
	if state.money < 180:
		return fail("Не хватает %d монет" % (180 - state.money))
	state.money -= 180
	state.wagons_by_id.W03 = {"levels": {}}
	if vehicle_id() == "locomotive" and state.consist_ids.size() < 3:
		state.consist_ids.append("W03")
		_claim_consist()
	return true

func select_vehicle(id: String) -> bool:
	if not depot_editable() or not state.fleet_by_id.has(id):
		return fail("Сменить машину можно в депо без активного груза")
	state.selected_vehicle_id = id
	state.consist_ids = state.fleet_by_id[id].get("consist", []).duplicate()
	state.engine = false
	state.throttle = 0.0
	state.gear = 0
	state.direction = 1
	reset_input()
	return true

func toggle_wagon(id: String) -> bool:
	if not depot_editable() or not state.wagons_by_id.has(id):
		return fail("Состав меняется только в депо до погрузки")
	if id in state.consist_ids:
		state.consist_ids.erase(id)
		_claim_consist()
		return true
	var limit = {"handcar": 0, "motorcar": 1, "locomotive": 3}[vehicle_id()]
	if state.consist_ids.size() >= limit:
		return fail("Эта машина допускает вагонов: %d" % limit)
	state.consist_ids.append(id)
	_claim_consist()
	return true

func _claim_consist() -> void:
	state.fleet_by_id[vehicle_id()].consist = state.consist_ids.duplicate()
	for id in state.fleet_by_id:
		if id == vehicle_id(): continue
		var stored = state.fleet_by_id[id].get("consist", []).duplicate()
		for wagon in state.consist_ids: stored.erase(wagon)
		state.fleet_by_id[id].consist = stored

func upgrade(id: String, branch_id: String) -> bool:
	if not depot_editable() or object_state(id).is_empty():
		return fail("Улучшения доступны в депо до погрузки")
	for branch in data.upgrade_catalog:
		if branch.id != branch_id:
			continue
		if branch.target_type != ("wagon" if id.begins_with("W") else id):
			return fail("Это улучшение другой машины")
		var object = object_state(id)
		var lv = int(object.levels.get(branch_id, 0))
		if lv >= 2:
			return fail("Достигнут максимальный уровень")
		var cost = int(branch.level_costs[lv])
		if state.money < cost:
			return fail("Не хватает %d монет" % (cost - state.money))
		state.money -= cost
		object.levels[branch_id] = lv + 1
		return true
	return false

func refuel() -> bool:
	if state.phase != "depot" or not stopped():
		return fail("Заправка доступна в домашнем депо")
	state.fleet_by_id[vehicle_id()].fuel = object_stats(vehicle_id()).tank
	return true

func current_mission() -> Dictionary:
	if int(state.chapter) >= data.missions.size():
		return {}
	return data.missions[int(state.chapter)]

func mission_count(mission: Dictionary) -> int:
	var count = 0
	for stop in mission.dropoffs:
		for pair in stop.cargo:
			count += int(pair[1])
	return count

func mission_error(mission: Dictionary) -> String:
	if mission.is_empty():
		return "Карьера завершена. Выбирай свободный рейс"
	if mission.tier != vehicle_id():
		return "Нужна техника: " + str(vehicle_base(mission.tier).name)
	var count = mission_count(mission)
	if capacity() < count:
		return "Нужно %d мест: сейчас %d" % [count, capacity()]
	if vehicle_id() != "handcar":
		var distance = 0.0
		for stop in mission.dropoffs:
			for i in range(data.stations.size()):
				if data.stations[i].id == stop.station: distance = maxf(distance, float(route.station_s[i]) * 2)
		var estimated = distance * (0.00045 if vehicle_id() == "motorcar" else 0.00009)
		if float(state.fleet_by_id[vehicle_id()].fuel) < estimated:
			return "Запас мал: нужно примерно %.2f %s. Пополни его в депо" % [estimated, "л" if vehicle_id() == "motorcar" else "кВт·ч"]
	return ""

func free_offers() -> Array:
	var offers: Array = []
	var max_station = 2 if vehicle_id() == "handcar" else 5
	var types = ["sack", "parts", "logs"]
	for i in range(3):
		var destination = 1 + ((i + int(state.offer_serial)) % max_station)
		var cargo_type = types[(i + int(state.offer_serial)) % 3]
		if vehicle_id() == "handcar" and cargo_type == "logs": cargo_type = "sack"
		var count = mini(capacity(), 2 + i)
		var dropoffs: Array = []
		if i == 2 and destination >= 3 and count >= 3:
			dropoffs.append({"station": data.stations[destination - 2].id, "cargo": [[cargo_type, 1]]})
			dropoffs.append({"station": data.stations[destination - 1].id, "cargo": [[cargo_type, 1]]})
			dropoffs.append({"station": data.stations[destination].id, "cargo": [[cargo_type, count - 2]]})
		elif i == 2 and destination > 1 and count >= 2:
			dropoffs.append({"station": data.stations[destination - 1].id, "cargo": [[cargo_type, 1]]})
			count -= 1
			dropoffs.append({"station": data.stations[destination].id, "cargo": [[cargo_type, count]]})
		else:
			dropoffs.append({"station": data.stations[destination].id, "cargo": [[cargo_type, count]]})
		offers.append({"id": "F%d_%d" % [int(state.offer_serial), i], "title": "Свободный рейс · " + data.stations[destination].name,
			"tier": vehicle_id(), "reward": 60 + destination * 25 + i * 15, "dropoffs": dropoffs, "free": true})
	return offers

func accept_mission(mission: Dictionary) -> bool:
	if not depot_editable():
		return fail("Сначала закончи или отмени активный рейс")
	if mission.get("id", "") in state.paid_ids:
		return fail("Этот рейс уже оплачен")
	if not mission.get("free", false) and mission.get("id", "") != current_mission().get("id", ""):
		return fail("Основные рейсы открываются последовательно")
	var problem = mission_error(mission)
	if problem != "":
		return fail(problem)
	state.active = mission.duplicate(true)
	state.active.phase = "loading"
	state.active.pending_reward = 0
	state.active.paid = false
	state.cargo.clear()
	var serial = 0
	for stop in mission.dropoffs:
		for pair in stop.cargo:
			for j in range(int(pair[1])):
				state.cargo.append({"id": str(mission.id) + "_" + str(serial), "type": pair[0], "destination": stop.station,
					"slot": "", "delivered": false, "health": 1.0})
				serial += 1
	state.s = route.station_s[0]
	state.v = 0.0
	state.direction = 1
	state.brake = 1.0
	state.throttle = 0.0
	state.gear = 0
	state.engine = false
	state.phase = "loading"
	reset_input()
	return true

func slot_occupied(key: String) -> bool:
	for item in state.cargo:
		if item.slot == key and not item.delivered:
			return true
	return false

func transfer(cargo_id: String, target_slot: String) -> bool:
	if not stopped() or station_index() < 0 or state.phase == "depot":
		return fail("Нужна станция, остановка и полный тормоз")
	var station = str(data.stations[station_index()].id)
	for item in state.cargo:
		if item.id != cargo_id or item.delivered:
			continue
		if target_slot != "":
			if slot_occupied(target_slot):
				return fail("Это место занято")
			var valid_slot = false
			for slot in slots():
				valid_slot = valid_slot or slot.key == target_slot
			if not valid_slot or item.slot != "" or station != "A":
				return fail("Погрузка доступна на домашней площадке")
			item.slot = target_slot
		else:
			if item.slot == "":
				return false
			if station != "A" and station != item.destination:
				return fail("Этот груз ждут на станции " + station_name(item.destination))
			item.slot = ""
			if station == item.destination:
				item.delivered = true
				state.stats.deliveries += 1
			evaluate_delivery()
		if station != "A" and station not in state.visited_stations:
			state.visited_stations.append(station)
		events.append("cargo")
		return true
	return false

func evaluate_delivery() -> void:
	if state.active.is_empty():
		return
	var all_done = true
	var damage = 0.0
	var fragile_count = 0
	for item in state.cargo:
		all_done = all_done and bool(item.delivered)
		if item.type == "fragile":
			damage += 1.0 - float(item.health)
			fragile_count += 1
	if all_done:
		state.active.phase = "return"
		var fraction = damage / maxf(1, fragile_count)
		state.active.pending_reward = int(round(float(state.active.reward) * (1.0 - 0.3 * fraction)))
		message = "Все грузы доставлены. Разверни состав и возвращайся в Лесную"

func all_loaded() -> bool:
	if state.cargo.is_empty():
		return false
	for item in state.cargo:
		if not item.delivered and item.slot == "":
			return false
	return true

func depart() -> bool:
	if state.active.is_empty() or not all_loaded():
		return fail("Сначала размести весь груз на составе")
	state.phase = "route"
	state.active.phase = "outbound"
	return true

func back_to_depot() -> bool:
	if station_index() != 0 or not stopped():
		return fail("Вернуться в депо можно на станции Лесная")
	if not state.active.is_empty() and state.active.get("phase", "") == "return":
		settle()
		return true
	for item in state.cargo:
		if not item.delivered:
			item.slot = ""
	state.phase = "depot"
	state.engine = false
	state.throttle = 0.0
	return true

func resume_mission() -> bool:
	if state.phase != "depot" or state.active.is_empty():
		return false
	state.phase = "loading"
	return true

func cancel_mission() -> bool:
	if state.phase != "depot" or not stopped():
		return false
	state.active = {}
	state.cargo = []
	state.offer_serial += 1
	return true

func can_turn() -> String:
	if station_index() < 0 or not stopped():
		return "Остановись у станции и затяни тормоз полностью"
	if float(state.throttle) > 0.01:
		return "Сначала убавь подачу до нуля"
	for item in state.cargo:
		if item.slot != "" and not item.delivered:
			return "Сначала выгрузи весь груз"
	return ""

func turn() -> bool:
	var problem = can_turn()
	if problem != "":
		return fail(problem)
	state.direction = -int(state.direction)
	reset_input()
	events.append("gear")
	return true

func settle() -> bool:
	if state.active.is_empty() or state.active.get("phase", "") != "return" or station_index() != 0 or not stopped():
		return false
	var id = str(state.active.id)
	if id in state.paid_ids or state.active.get("paid", false):
		return false
	var reward = int(state.active.pending_reward)
	state.money += reward
	state.stats.earned += reward
	state.paid_ids.append(id)
	state.active.paid = true
	if not state.active.get("free", false):
		state.completed_ids.append(id)
		state.chapter = mini(int(state.chapter) + 1, 10)
	if state.active.get("final", false):
		state.finale = true
		events.append("finale")
	else:
		events.append("coins")
	state.last_result = {"title": state.active.title, "reward": reward, "final": state.active.get("final", false)}
	state.active = {}
	state.cargo = []
	state.offer_serial += 1
	state.phase = "depot"
	state.engine = false
	state.throttle = 0.0
	state.gear = 0
	message = "Рейс окончен. Заработано %d монет" % reward
	return true

func rescue() -> void:
	state.s = route.station_s[0]
	state.v = 0.0
	state.brake = 1.0
	state.throttle = 0.0
	state.gear = 0
	state.engine = false
	state.direction = 1
	state.stats.rescues += 1
	reset_input()
	if not settle():
		state.phase = "depot"
	refuel()
	message = "Помощь доставила состав в депо. Груз и покупки сохранены"

func set_gear(value: int) -> bool:
	if float(state.throttle) >= 0.15:
		return fail("Сначала убавь подачу ниже 15%")
	state.gear = clampi(value, 0, 2)
	events.append("gear")
	return true

func start_engine(value: bool) -> bool:
	if value:
		if int(state.gear) != 0:
			return fail("Для запуска нужна нейтраль Н")
		if float(state.throttle) > 0.01:
			return fail("Для запуска убавь подачу до 0%")
		if state.fleet_by_id[vehicle_id()].fuel <= 0:
			return fail("Запас энергии закончился. Вызови помощь депо")
	state.engine = value
	events.append("gear")
	return true

func pump_motion(delta_radians: float) -> void:
	pump_pending = clampf(pump_pending + delta_radians, -0.2, 0.2)

func physics_step(dt: float) -> void:
	if state.is_empty():
		return
	if state.phase == "depot" or state.phase == "loading":
		reset_input()
		return
	state.stats.seconds += dt
	var ids = body_ids()
	var total = train_mass()
	var grade = 0.0
	var rolling = 0.0
	var max_brake = 0.0
	for i in range(ids.size()):
		var mass = body_mass(ids[i])
		var slope = route.slope(body_s(i))
		var stats = object_stats(ids[i])
		grade -= mass * G * sin(slope)
		rolling += mass * G * cos(slope) * float(stats.rolling)
		max_brake += float(stats.brake)
	var stats = object_stats(vehicle_id())
	var drive = 0.0
	regen_kw = 0.0
	if vehicle_id() == "handcar":
		var amount = clampf(pump_pending, -2.8 * dt, 2.8 * dt)
		pump_pending -= amount
		var before = pump_angle
		pump_angle = clampf(pump_angle + amount, -deg_to_rad(28), deg_to_rad(28))
		var motion = pump_angle - before
		if signi(int(signf(motion))) != pump_last_direction and absf(motion) > 0.00001:
			pump_stroke = 0.0
			pump_last_direction = int(signf(motion))
		pump_stroke += absf(motion)
		var work = 0.0
		if pump_stroke >= deg_to_rad(56) * 0.03:
			work = minf(absf(motion) * float(stats.cycle_work) / (deg_to_rad(56) * 2), float(stats.power) * dt)
		pump_work = work
		var taper = maxf(0, 1.0 - pow(absf(float(state.v)) / 3.34, 2))
		drive = float(state.direction) * minf(220, work / dt / maxf(absf(float(state.v)), 0.8)) * taper
	else:
		var fleet = state.fleet_by_id[vehicle_id()]
		if fleet.fuel <= 0: state.engine = false
		if state.engine and fleet.fuel > 0:
			if vehicle_id() == "motorcar":
				fleet.fuel = maxf(0, float(fleet.fuel) - (0.0003 + 0.002 * float(state.throttle)) * dt)
			if fleet.fuel <= 0:
				state.engine = false
			if int(state.gear) > 0:
				var gear = int(state.gear) - 1
				var traction = float(stats.traction[gear]) * maxf(0, 1 - pow(absf(float(state.v)) / float(stats.speeds[gear]), 2))
				var adhesion = 0.35 * float(stats.mass) * G * cos(route.slope(float(state.s)))
				drive = float(state.direction) * float(state.throttle) * minf(traction, adhesion)
	var brake = float(state.brake) * max_brake
	if vehicle_id() == "locomotive":
		var battery = state.fleet_by_id.locomotive
		# Recover only actual kinetic energy, never energy from a stationary brake.
		var available_power = minf(brake * absf(float(state.v)), total * float(state.v) * float(state.v) / (2 * dt))
		var recovered = available_power * 0.25 if float(state.throttle) < 0.01 else 0.0
		regen_kw = recovered / 1000.0
		var used = absf(drive * float(state.v)) / 0.82 + (120.0 if state.engine else 0.0)
		battery.fuel = clampf(float(battery.fuel) + (recovered - used) * dt / 3600000.0, 0.0, float(stats.tank))
		if battery.fuel <= 0:
			state.engine = false
	var external = drive + grade
	var old_v = float(state.v)
	var resist = rolling + brake + 1.2 * old_v * old_v
	var new_v = old_v
	if absf(old_v) < 0.03 and absf(external) <= rolling + brake:
		new_v = 0.0
	else:
		var movement_sign = signf(old_v) if absf(old_v) >= 0.03 else signf(external)
		new_v = old_v + (external - movement_sign * resist) / total * dt
		if signf(new_v) != movement_sign and absf(external) <= rolling + brake:
			new_v = 0.0
	acceleration = (new_v - old_v) / dt
	state.v = new_v
	var movement = (old_v + new_v) * 0.5 * dt
	state.s += movement
	state.stats.distance += absf(movement)
	rail_distance += absf(movement)
	# Bound the head so that every trailing body remains on the shared curve.
	var rear_span = 3.8 + maxf(0, state.consist_ids.size() - 1) * 3.5 if not state.consist_ids.is_empty() else 0.0
	var lower = -38.0 + (rear_span if state.direction > 0 else 0.0)
	var upper = route.length_m - 2.0 - (rear_span if state.direction < 0 else 0.0)
	if state.s < lower or state.s > upper:
		state.s = clampf(float(state.s), lower, upper)
		state.v = 0.0
		state.brake = 1.0
		state.throttle = 0.0
		message = "Конец линии. Остановись у станции и разверни состав"
	if absf(acceleration) > 1.2:
		shock_time += dt
	else:
		shock_time = 0.0
	if shock_time > 0.25:
		for item in state.cargo:
			if item.type == "fragile" and item.slot != "" and not item.delivered:
				var owner = str(item.slot).split(":")[0]
				item.health = maxf(0, float(item.health) - dt * (absf(acceleration) - 1.2) * 0.1 * float(object_stats(owner).shock))
	if not state.active.is_empty() and state.active.phase == "return" and station_index() == 0 and stopped():
		settle()

func station_name(id: String) -> String:
	for station in data.stations:
		if station.id == id:
			return station.name
	return id

func next_destination() -> String:
	if state.active.is_empty():
		return "A"
	if state.active.phase == "return":
		return "A"
	for stop in state.active.dropoffs:
		for item in state.cargo:
			if item.destination == stop.station and not item.delivered:
				return stop.station
	return "A"

func serialize() -> Dictionary:
	var result = state.duplicate(true)
	result.route = route.serialize()
	result.pump_angle = pump_angle
	return result

func restore(saved: Dictionary) -> bool:
	if not validate_save(saved):
		return false
	state = saved.duplicate(true)
	route.restore(state.route, data.stations)
	state.erase("route")
	pump_angle = float(state.get("pump_angle", 0))
	reset_input()
	return true

func validate_save(saved: Dictionary) -> bool:
	var required = ["version", "route", "fleet_by_id", "wagons_by_id", "selected_vehicle_id", "consist_ids", "money", "chapter", "s", "v", "direction", "brake", "throttle", "gear", "engine", "phase", "cargo", "active", "paid_ids", "completed_ids", "stats", "finale", "visited_stations", "offer_serial", "tutorial"]
	for key in required:
		if not saved.has(key):
			return false
	if not numeric(saved.version) or int(saved.version) != 2 or not saved.route is Dictionary or not saved.fleet_by_id is Dictionary or not saved.wagons_by_id is Dictionary or not saved.cargo is Array:
		return false
	if not saved.active is Dictionary or not saved.stats is Dictionary or not saved.consist_ids is Array or not saved.paid_ids is Array or not saved.completed_ids is Array or not saved.visited_stations is Array:
		return false
	for key in ["money", "chapter", "s", "v", "direction", "brake", "throttle", "gear", "offer_serial"]:
		if not numeric(saved[key]): return false
	if saved.money < 0 or saved.chapter < 0 or saved.chapter > 10 or saved.brake < 0 or saved.brake > 1 or saved.throttle < 0 or saved.throttle > 1 or saved.gear < 0 or saved.gear > 2:
		return false
	if absf(float(saved.v)) > 100 or float(saved.s) < -40 or float(saved.s) > 1760:
		return false
	if not saved.route.has_all(["points", "seed", "generator_version"]) or not saved.route.points is Array or saved.route.points.size() < 1700:
		return false
	var previous_s = -INF
	for point in saved.route.points:
		if not point is Array or point.size() != 3: return false
		for coordinate in point:
			if not numeric(coordinate): return false
		if float(point[2]) <= previous_s: return false
		previous_s = float(point[2])
	for group in [saved.fleet_by_id, saved.wagons_by_id]:
		for id in group:
			if id not in VEHICLE_IDS and id not in ["W01", "W02", "W03"]: return false
			var object = group[id]
			if not object is Dictionary or not object.has("levels") or not object.levels is Dictionary: return false
			if id in VEHICLE_IDS and (not object.has("fuel") or not numeric(object.fuel) or object.fuel < 0): return false
			for branch_id in object.levels:
				var valid = false
				for branch in data.upgrade_catalog:
					valid = valid or (branch.id == branch_id and branch.target_type == ("wagon" if id.begins_with("W") else id))
				if not valid or not numeric(object.levels[branch_id]) or int(object.levels[branch_id]) not in [0, 1, 2]: return false
	if not saved.stats.has_all(["distance", "deliveries", "earned", "rescues", "seconds"]): return false
	for key in saved.stats:
		if not numeric(saved.stats[key]) or saved.stats[key] < 0: return false
	if not saved.active.is_empty():
		if not saved.active.has_all(["id", "title", "tier", "reward", "dropoffs", "phase", "pending_reward", "paid"]): return false
		if saved.active.phase not in ["loading", "outbound", "return"] or not saved.active.dropoffs is Array: return false
		if not numeric(saved.active.reward) or not numeric(saved.active.pending_reward): return false
		for stop in saved.active.dropoffs:
			if not stop is Dictionary or not stop.has_all(["station", "cargo"]): return false
	if not saved.fleet_by_id.has(saved.selected_vehicle_id) or int(saved.money) < 0 or int(saved.chapter) < 0 or int(saved.chapter) > 10:
		return false
	if saved.phase not in ["depot", "loading", "route"] or int(saved.direction) not in [-1, 1]:
		return false
	for id in saved.consist_ids:
		if not saved.wagons_by_id.has(id):
			return false
	if saved.consist_ids.size() > {"handcar": 0, "motorcar": 1, "locomotive": 3}.get(saved.selected_vehicle_id, 0): return false
	if saved.consist_ids.size() != saved.consist_ids.duplicate().reduce(func(acc, value):
		if value not in acc: acc.append(value)
		return acc, []).size(): return false
	var seen: Array = []
	var occupied: Array = []
	for item in saved.cargo:
		if not item is Dictionary or not item.has_all(["id", "type", "slot", "destination", "delivered", "health"]):
			return false
		if item.id in seen or (item.slot != "" and item.slot in occupied):
			return false
		if item.type not in ["sack", "fragile", "logs", "parts"] or item.destination not in ["A", "B", "C", "D", "E", "F"] or not numeric(item.health) or float(item.health) < 0 or float(item.health) > 1:
			return false
		if not item.slot is String or not item.id is String: return false
		if item.slot != "":
			var split = item.slot.split(":")
			if split.size() != 2 or not split[1].is_valid_int() or int(split[1]) < 0 or int(split[1]) > 3: return false
			if split[0] != saved.selected_vehicle_id and split[0] not in saved.consist_ids: return false
		seen.append(item.id)
		if item.slot != "":
			occupied.append(item.slot)
	return true

func numeric(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func fail(text: String) -> bool:
	message = text
	return false
