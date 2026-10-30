extends RefCounted

const Route = preload("res://scripts/route.gd")
const StationInteraction = preload("res://scripts/station_interaction.gd")
const HandcarMechanism = preload("res://scripts/handcar_mechanism.gd")
const HandcarDrive = preload("res://scripts/handcar_drive.gd")
const G = 9.81
const BUFFER_SAFE_SPEED = 1.0
const VEHICLE_IDS = ["handcar", "motorcar", "locomotive"]
var data: Dictionary
var route = Route.new()
var state: Dictionary = {}
var message = ""
var pump_angle = 0.0
var handcar = HandcarMechanism.new()
var hand_drive = HandcarDrive.new()
var pump_work = 0.0
var output_power = 0.0
var acceleration = 0.0
var shock_time = 0.0
var rail_distance = 0.0
var regen_kw = 0.0
var motor_energy: Dictionary = {}
var loading_cache: Dictionary = {}
var events: Array = []
var stationary_seconds = 0.25
var stationary_station = 0

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))

func new_game(world_seed: int = 42) -> void:
	loading_cache.clear()
	route.generate(world_seed, data.stations)
	state = {"version": 2, "fleet_by_id": {"handcar": {"levels": {}, "fuel": 0.0, "consist": []}},
		"wagons_by_id": {}, "selected_vehicle_id": "handcar", "consist_ids": [],
		"money": 0, "chapter": 0, "completed_ids": [], "paid_ids": [], "active": {},
		"cargo": [], "s": 0.0, "v": 0.0, "direction": 1, "brake": 1.0, "throttle": 0.0,
		"gear": 0, "engine": false, "phase": "depot", "finale": false, "reverser": 1,
		"visited_stations": ["A"], "tutorial": true,
		"stats": {"distance": 0.0, "deliveries": 0, "earned": 0, "rescues": 0, "seconds": 0.0}, "offer_serial": 0}
	reset_input()
	handcar = HandcarMechanism.new()
	hand_drive = HandcarDrive.new()
	pump_angle = 0.0
	stationary_seconds=0.25
	stationary_station=0

func station_interaction() -> Dictionary:
	return StationInteraction.evaluate(self)

func service_stop(index: int) -> float:
	return StationInteraction.stop_position(self,index)

func update_station_dwell(dt: float) -> void:
	var interaction = station_interaction()
	if interaction.in_zone and absf(float(state.v))<=StationInteraction.STOP_SPEED and float(state.brake)>=StationInteraction.BRAKE:
		if stationary_station!=int(interaction.station_index): stationary_seconds=0.0
		stationary_station=int(interaction.station_index)
		stationary_seconds=minf(1,stationary_seconds+dt)
	else:
		stationary_seconds=0.0
		stationary_station=-1

func reset_input() -> void:
	hand_drive.release()
	pump_work = 0.0
	output_power = 0.0

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
		"shock": float(ef.get("cargo_shock_multiplier", 1.0)), "power": 220.0,
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
	return float(state.s) - float(state.direction) * body_offset(index)

func body_offset(index: int) -> float:
	return preload("res://scripts/world_geometry.gd").offset(body_ids(),index)

func train_length() -> float:
	return preload("res://scripts/world_geometry.gd").train_length(body_ids())

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
	state.reverser = 1
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
	if capacity() < 1:
		return "Нужно хотя бы одно свободное место для груза"
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
	state.active.origin_station_id = "A"
	state.active.selection_version = 1
	state.active.selection_locked = false
	state.active.offer_reward = int(mission.reward)
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
	state.active.offered_count=state.cargo.size()
	state.active.offer_value=0.0
	for cargo in state.cargo: state.active.offer_value+=cargo_value(cargo)
	loading_cache.clear()
	state.s = route.station_s[0]
	state.v = 0.0
	state.direction = 1
	state.reverser = 1
	state.brake = 1.0
	state.throttle = 0.0
	state.gear = 0
	state.engine = false
	state.phase = "loading"
	state.s = service_stop(0)
	stationary_station=0
	stationary_seconds=0.25
	reset_input()
	return true

func slot_occupied(key: String) -> bool:
	for item in state.cargo:
		if item.slot == key and not item.delivered:
			return true
	return false

func transfer(cargo_id: String, target_slot: String) -> bool:
	var interaction = station_interaction()
	if not interaction.can_transfer:
		return fail(interaction.reason)
	var station = str(interaction.station_id)
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
	if selectable_loading():
		for item in state.cargo:
			if item.slot!="": return true
		return false
	for item in state.cargo:
		if not item.delivered and item.slot == "":
			return false
	return true

func selectable_loading() -> bool:
	return not state.active.is_empty() and int(state.active.get("selection_version",0))==1 and not state.active.get("selection_locked",false)

func cargo_value(item: Dictionary) -> float:
	var distance=1.0
	for i in range(data.stations.size()):
		if data.stations[i].id==item.destination: distance=maxf(1,float(route.station_s[i])-float(route.station_s[0]))
	return maxf(1,float(cargo_base(item.type).mass_kg))*distance

func selected_reward() -> int:
	if not selectable_loading(): return int(state.active.get("reward",0))
	var value=0.0
	for item in state.cargo:
		if item.slot!="": value+=cargo_value(item)
	if value==0: return 0
	return maxi(1,roundi(float(state.active.offer_reward)*value/maxf(1,float(state.active.offer_value))))

# Share of the maximum tractive effort the battery can still deliver (TZ 3.1,
# N6). It scales force, never the current speed; other machines return 1.
func charge_traction_factor() -> float:
	var curve=vehicle_base().get("charge_traction_curve",[])
	if curve.is_empty(): return 1.0
	var tank=float(object_stats(vehicle_id()).tank)
	var charge=clampf(float(state.fleet_by_id[vehicle_id()].fuel)/maxf(0.000001,tank),0,1)
	for i in range(1,curve.size()):
		if charge<=float(curve[i][0]):
			var a=curve[i-1]
			var b=curve[i]
			return lerpf(float(a[1]),float(b[1]),(charge-float(a[0]))/maxf(0.000001,float(b[0])-float(a[0])))
	return float(curve[-1][1])

func loading_preview() -> Dictionary:
	var loaded=0
	var signature=vehicle_id()+str(state.consist_ids)+str(route.seed_value)+str(snappedf(charge_traction_factor(),0.01))
	for item in state.cargo:
		signature+=str(item.id)+str(item.slot)
		if item.slot!="" and not item.delivered: loaded+=1
	if loading_cache.get("signature","")==signature: return loading_cache
	var target_id=next_destination()
	var target_s=float(state.s)
	for i in range(data.stations.size()):
		if data.stations[i].id==target_id: target_s=float(route.station_s[i])
	var required=0.0
	var steepest=0.0
	var first_hill=-1.0
	var ids=body_ids()
	for s in range(ceili(float(state.s)),ceili(target_s)+1,2):
		var force=0.0
		var positive=0.0
		for i in range(ids.size()):
			var slope=route.slope(float(s)-body_offset(i))
			var mass=body_mass(ids[i])
			force+=mass*G*(sin(slope)+float(object_stats(ids[i]).rolling)*cos(slope))
			positive=maxf(positive,tan(slope))
		required=maxf(required,force)
		steepest=maxf(steepest,positive)
		if first_hill<0 and positive>0.008: first_hill=float(s)-float(state.s)
	var available=220.0/1.4
	if vehicle_id()!="handcar":
		var stats=object_stats(vehicle_id())
		available=minf(float(stats.traction[0])*maxf(0,1-pow(1.4/float(stats.speeds[0]),2))*charge_traction_factor(),0.35*float(stats.mass)*G)
	var ratio=required/maxf(1,available)
	var difficulty="Потребуется меньшая загрузка" if ratio>1 else ("Тяжёлый подъём" if ratio>0.7 else "Легко")
	loading_cache={"signature":signature,"loaded":loaded,"offered":int(state.active.get("offered_count",state.cargo.size())),"capacity":capacity(),"mass_kg":train_mass(),"reward":selected_reward(),"max_grade":steepest,"first_hill_m":first_hill,"required_force_n":required,"available_force_n":available,"difficulty":difficulty,"assessment_speed_mps":1.4}
	return loading_cache

func depart() -> bool:
	if state.active.is_empty() or not all_loaded():
		return fail("Погрузи хотя бы один предмет" if selectable_loading() else "Сначала размести весь груз на составе")
	if selectable_loading():
		state.active.reward=selected_reward()
		var accepted: Array=[]
		var warehouse: Array=[]
		for item in state.cargo:
			if item.slot!="": accepted.append(item)
			else: warehouse.append(item)
		state.active.warehouse_cargo=warehouse
		state.active.accepted_ids=[]
		for item in accepted: state.active.accepted_ids.append(item.id)
		state.active.selection_locked=true
		state.cargo=accepted
		loading_cache.clear()
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
	state.s=service_stop(0)
	stationary_station=0
	stationary_seconds=0.25
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
	state.reverser = 1
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
	state.last_result = {"title": state.active.title, "reward": reward, "final": state.active.get("final", false),"left_on_warehouse":state.active.get("warehouse_cargo",[]).size()}
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
	state.reverser = 1
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

func set_reverser(value: int) -> bool:
	if vehicle_id()=="handcar": return fail("Направление ручной дрезины задаётся усилием на рычаге")
	if not stopped(): return fail("Для смены направления остановись и затяни тормоз")
	if float(state.throttle) > 0.01: return fail("Для реверса убавь подачу до нуля")
	state.reverser = 1 if value >= 0 else -1
	reset_input()
	events.append("gear")
	message = "Тяга направлена вправо →" if drive_direction() > 0 else "← Тяга направлена влево"
	return true

func drive_direction() -> int:
	return int(state.direction) * int(state.get("reverser", 1))

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

func grab_pump() -> void:
	hand_drive.grab(handcar.pose().angle)

func set_pump_target(angle: float, at_time: float = -1) -> void:
	hand_drive.set_target(clampf(angle,-0.75,0.75),at_time)

func handcar_potential_at(offset: float) -> float:
	var result=0.0
	for i in range(body_ids().size()):
		result+=body_mass(body_ids()[i])*G*route.sample(body_s(i)+offset).y
	return result

func can_push_handcar() -> bool:
	return vehicle_id()=="handcar" and state.phase=="route" and float(state.brake)<0.1 and absf(float(state.v))<0.5 and absf(float(handcar.pose().dangle_dphase))<0.035

func begin_push() -> void:
	hand_drive.push_used=0.0
	hand_drive.push_displacement=0.0
	hand_drive.push_active=can_push_handcar()

func push_handcar(distance_m: float) -> bool:
	if not hand_drive.push_active or float(state.brake)>=0.1 or absf(float(state.v))>=0.5 or distance_m==0: return false
	hand_drive.push_displacement+=distance_m
	var available=float(hand_drive.config.nudge_force_n)*maxf(0,absf(hand_drive.push_displacement)-0.03)
	var amount=minf(float(hand_drive.config.nudge_work_per_gesture_j),available)-hand_drive.push_used
	if amount<=0: return false
	var k=0.21*float(handcar.config.gear_ratio)
	var effective_mass=hand_drive.inertia(train_mass(),0.21,float(handcar.config.gear_ratio))/(k*k)
	var old_energy=0.5*effective_mass*float(state.v)*float(state.v)
	var sign_value=signf(hand_drive.push_displacement)
	var new_energy=old_energy+amount
	if float(state.v)*sign_value<0:
		if amount<old_energy: new_energy=old_energy-amount;sign_value=signf(float(state.v))
		else: new_energy=amount-old_energy
	state.v=sign_value*sqrt(2*new_energy/effective_mass)
	hand_drive.nudge_work+=new_energy-old_energy
	hand_drive.push_used+=amount
	return true

func physics_step(dt: float) -> void:
	if state.is_empty() or dt<=0:
		return
	update_station_dwell(dt)
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
	var hand_result: Dictionary = {}
	if vehicle_id() == "handcar":
		hand_result=hand_drive.step(handcar,float(state.v),total,int(state.direction),0.21,dt,grade,rolling,float(state.brake)*max_brake,minf(220.0,float(stats.power)),float(effects(vehicle_id()).get("work_multiplier",1.0)),handcar_potential_at)
		pump_angle=handcar.pose().angle
		pump_work=maxf(0,float(hand_result.hand_work))
		output_power=pump_work/dt
	else:
		var fleet = state.fleet_by_id[vehicle_id()]
		if fleet.fuel <= 0: state.engine = false
		if state.engine and fleet.fuel > 0:
			if fleet.fuel <= 0:
				state.engine = false
			if int(state.gear) > 0:
				var gear = int(state.gear) - 1
				var traction = float(stats.traction[gear]) * maxf(0, 1 - pow(absf(float(state.v)) / float(stats.speeds[gear]), 2)) * charge_traction_factor()
				var adhesion = 0.35 * float(stats.mass) * G * cos(route.slope(float(state.s)))
				drive = float(drive_direction()) * float(state.throttle) * minf(traction, adhesion)
	var brake = float(state.brake) * max_brake
	var old_v = float(state.v)
	var new_v = old_v
	var movement=0.0
	if vehicle_id()=="handcar":
		new_v=hand_result.velocity
		movement=hand_result.delta_s
	else:
		var external = drive + grade
		var resist = rolling + brake + 1.2 * old_v * old_v
		if absf(old_v) < 0.03 and absf(external) <= rolling + brake:
			new_v = 0.0
		else:
			var movement_sign = signf(old_v) if absf(old_v) >= 0.03 else signf(external)
			new_v = old_v + (external - movement_sign * resist) / total * dt
			if signf(new_v) != movement_sign and absf(external) <= rolling + brake: new_v = 0.0
		movement=(old_v+new_v)*0.5*dt
	if vehicle_id()!="handcar":
		# Settle energy against the distance actually integrated, including
		# the first accelerating step and the last stopping step.
		var shaft_work=absf(drive*movement)
		var kinetic_change=0.5*total*(new_v*new_v-old_v*old_v)
		var dissipated=maxf(0,drive*movement+grade*movement-kinetic_change)
		var resist=rolling+brake+1.2*old_v*old_v
		var brake_work=minf(brake*absf(movement),dissipated*brake/maxf(0.000001,resist))
		var fleet=state.fleet_by_id[vehicle_id()]
		var before=float(fleet.fuel)
		var used=0.0
		var recovered=0.0
		if vehicle_id()=="locomotive":
			used=shaft_work/0.82+(120.0*dt if state.engine else 0.0)
			recovered=0.25*brake_work if float(state.throttle)<0.01 else 0.0
			recovered=minf(recovered,maxf(0,(float(stats.tank)-before)*3600000.0+used))
			fleet.fuel=clampf(before+(recovered-used)/3600000.0,0,float(stats.tank))
			regen_kw=recovered/dt/1000.0
		else:
			# Game calibration: petrol 34 MJ/l, 20% shaft efficiency,
			# plus a small idle burn. Higher load costs more through work.
			used=shaft_work/0.20+(10200.0*dt if state.engine else 0.0)
			fleet.fuel=maxf(0,before-used/34000000.0)
		motor_energy={"shaft_work_j":shaft_work,"brake_work_j":brake_work,"used_j":used,"recovered_j":recovered,"delta_store":float(fleet.fuel)-before}
		if fleet.fuel<=0: state.engine=false
	acceleration=(new_v-old_v)/dt
	state.v=new_v
	state.s+=movement
	state.stats.distance += absf(movement)
	rail_distance += absf(movement)
	# Bound the head so that every trailing body remains on the shared curve.
	var rear_span = body_offset(body_ids().size()-1)
	var lower = -38.0 + (rear_span if state.direction > 0 else 0.0)
	var upper = route.length_m - 2.0 - (rear_span if state.direction < 0 else 0.0)
	if state.s < lower or state.s > upper:
		state.s = clampf(float(state.s), lower, upper)
		var damaged=buffer_impact(absf(float(state.v)))
		state.v = 0.0
		state.brake = 1.0
		state.throttle = 0.0
		message = "Конец линии. Остановись и выбери обратное направление тяги"
		if damaged: message="Удар об упор: посуда пострадала. Подъезжай к концу линии медленнее"
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

func buffer_impact(speed: float) -> bool:
	if speed<=BUFFER_SAFE_SPEED: return false
	var damaged=false
	for item in state.cargo:
		if item.type=="fragile" and item.slot!="" and not item.delivered:
			var owner=str(item.slot).split(":")[0]
			item.health=maxf(0,float(item.health)-minf(1.0,(speed-BUFFER_SAFE_SPEED)*0.25)*float(object_stats(owner).shock))
			damaged=true
	return damaged

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
			if selectable_loading() and not selected_loading_has_none() and item.slot=="": continue
			if item.destination == stop.station and not item.delivered:
				return stop.station
	return "A"

func selected_loading_has_none() -> bool:
	for item in state.cargo:
		if item.slot!="": return false
	return true

func mission_origin() -> String:
	return str(state.active.get("origin_station_id","A"))

func journey_heading() -> String:
	var destination=next_destination()
	if not state.active.is_empty() and state.active.get("phase","")=="return":
		return "Возвращение: "+station_name(destination)
	var origin=mission_origin()
	if origin==destination: return "Следующая: "+station_name(destination)
	return station_name(origin)+" → "+station_name(destination)

func serialize() -> Dictionary:
	var result = state.duplicate(true)
	result.route = route.serialize()
	result.pump_angle = pump_angle
	result.handcar_phase = handcar.phase
	result.handcar_drive_version = 1
	result.erase("flywheel_energy")
	return result

func restore(saved: Dictionary) -> bool:
	if not validate_save(saved):
		return false
	state = saved.duplicate(true)
	loading_cache.clear()
	if not state.active.is_empty(): state.active.origin_station_id=state.active.get("origin_station_id","A")
	route.restore(state.route, data.stations)
	state.erase("route")
	pump_angle = float(state.get("pump_angle", 0))
	handcar = HandcarMechanism.new()
	hand_drive = HandcarDrive.new()
	if state.has("handcar_phase"):
		handcar.set_phase(float(state.handcar_phase))
	else:
		handcar.seek_rocker(lerpf(float(handcar.limits.minimum.angle),float(handcar.limits.maximum.angle),clampf((pump_angle+deg_to_rad(28))/deg_to_rad(56),0,1)))
	state.reverser = int(state.get("reverser", 1))
	stationary_seconds=0.0
	stationary_station=-1
	# Old loading saves used a fixed locomotive centre at s=0. A long
	# consist can extend beyond the newly marked platform there. Position
	# that parked depot formation once, before driving is enabled.
	if state.phase=="loading":
		var interaction=station_interaction()
		if interaction.station_id=="A" and not interaction.in_zone:
			state.s=service_stop(0)
			message="Состав подготовлен на домашней погрузочной площадке"
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
		if saved.active.has("origin_station_id"):
			var known_origin=false
			for station in data.stations: known_origin=known_origin or saved.active.origin_station_id==station.id
			if not known_origin: return false
		if not numeric(saved.active.reward) or not numeric(saved.active.pending_reward): return false
		if saved.active.has("selection_version"):
			var active=saved.active
			if not numeric(active.selection_version) or int(active.selection_version)!=1: return false
			if not active.has_all(["selection_locked","offer_reward","offer_value","offered_count"]): return false
			if not active.selection_locked is bool or not numeric(active.offer_reward) or not numeric(active.offer_value) or not numeric(active.offered_count): return false
			if active.offer_reward<=0 or active.offer_value<=0 or active.offered_count<1 or active.offered_count>64: return false
			if active.reward>active.offer_reward or active.reward<0: return false
			if not active.selection_locked and active.phase!="loading": return false
			if active.selection_locked:
				if not active.has_all(["warehouse_cargo","accepted_ids"]) or not active.warehouse_cargo is Array or not active.accepted_ids is Array: return false
				if saved.cargo.is_empty() or active.accepted_ids.size()!=saved.cargo.size() or active.warehouse_cargo.size()+saved.cargo.size()!=int(active.offered_count): return false
				var accepted_ids: Array=[]
				for item in saved.cargo:
					if not item is Dictionary or not item.has("id") or item.id in accepted_ids or item.id not in active.accepted_ids: return false
					accepted_ids.append(item.id)
				var stock_ids: Array=[]
				for item in active.warehouse_cargo:
					if not item is Dictionary or not item.has_all(["id","type","slot","destination","delivered","health"]): return false
					if item.id in accepted_ids or item.id in stock_ids or item.slot!="" or item.delivered: return false
					if cargo_base(str(item.type)).is_empty() or not numeric(item.health): return false
					stock_ids.append(item.id)
		for stop in saved.active.dropoffs:
			if not stop is Dictionary or not stop.has_all(["station", "cargo"]): return false
	if not saved.fleet_by_id.has(saved.selected_vehicle_id) or int(saved.money) < 0 or int(saved.chapter) < 0 or int(saved.chapter) > 10:
		return false
	if saved.phase not in ["depot", "loading", "route"] or int(saved.direction) not in [-1, 1]:
		return false
	if saved.has("reverser") and (not numeric(saved.reverser) or int(saved.reverser) not in [-1, 1]): return false
	if saved.has("flywheel_energy") and (not numeric(saved.flywheel_energy) or saved.flywheel_energy < 0 or saved.flywheel_energy > 80): return false
	if saved.has("handcar_phase") and not numeric(saved.handcar_phase): return false
	if saved.has("handcar_drive_version") and (not numeric(saved.handcar_drive_version) or int(saved.handcar_drive_version)!=1 or not saved.has("handcar_phase")): return false
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
