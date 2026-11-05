extends RefCounted

const Route = preload("res://scripts/route.gd")
const StationInteraction = preload("res://scripts/station_interaction.gd")
const HandcarMechanism = preload("res://scripts/handcar_mechanism.gd")
const HandcarDrive = preload("res://scripts/handcar_drive.gd")
const Pole = preload("res://scripts/pole.gd")
const Casino = preload("res://scripts/casino.gd")
const Live = preload("res://scripts/live.gd")
const Wear = preload("res://scripts/wear.gd")
const Wind = preload("res://scripts/wind.gd")
const Zeppelin = preload("res://scripts/zeppelin.gd")
const G = 9.81
const BUFFER_SAFE_SPEED = 1.0
const VEHICLE_IDS = ["handcar", "pole", "sail", "steam", "motorcar", "pneumatic", "locomotive", "zeppelin"]
const WAGON_IDS = ["W01", "W02", "W03"]
# Classes that exist in the data but are not shown to the player yet (no view, no cab).
const HIDDEN_VEHICLE_IDS = []   # machines that exist in the data but are not shown in the garage yet (none now)
# Holds cargo migrated from an old petrol deck until it is unloaded (ECONOMY_v3_2_RU.md).
const TEMP_WAGON = "WT"
var data: Dictionary
var route = Route.new()
var state: Dictionary = {}
var message = ""
var pump_angle = 0.0
var handcar = HandcarMechanism.new()
var hand_drive = HandcarDrive.new()
var pole = Pole.new()
# The sail car (B6.4): the wind over the line, the trim of the sail (0 edge-on .. 1 wide open) and
# the numbers of the last step for the hud and the picture.
var wind = Wind.new()
var zep = Zeppelin.new()   # the running model of the rail zeppelin (B6.5), only used while it is the chosen machine
var sail_trim = 0.6
# Holding (as with the handcar lever): the sail pulls only while the hand holds the free corner or the
# sheet is made fast on the cleat; let go and it flogs like a flag and pulls nothing.
# 03.11.2026: the sail was made stronger (a bigger cloth, a firmer grip and cleat)
const SAIL_GRIP_N = 280.0
const SAIL_CLEAT_N = 400.0
const SAIL_AREA_M2 = 8.0
# Without the gadget the cleat holds the sheet only at these openings; with it, at any
const SAIL_NOTCHES = [0.0, 0.5, 1.0]
var sail_held = false
var sail_cleated = false
var sail_over = 0.0
var sail_lift = 0.0   # how high the free corner of the sail is held above its place on the boom, metres (-0.35 .. 0.9)
var sail_side = 1   # which side of the car the boom is swung to: 1 the far side, -1 the near side
var sail_info: Dictionary = {}
# B1.1: the brake was set by the platform itself, not by the player
var auto_brake = false
var hold_armed = false   # the train has been moving since it last held itself
# Flight off a crest (N14): height above the rail (0 on it) and the ballistic height and speed.
var air_z = 0.0
var air_fly = false
var air_y = 0.0
var air_vy = 0.0
var last_landing = 0.0
var pump_work = 0.0
var output_power = 0.0
var acceleration = 0.0
var shock_time = 0.0
var rail_distance = 0.0
var regen_kw = 0.0
var valve_held = false
# Distance travelled in the last physics step, for drawing between steps.
var last_movement = 0.0
var shift_cut = 0.0
var stall_clock = 0.0
var motor_energy: Dictionary = {}
var loading_cache: Dictionary = {}
var events: Array = []
var last_refill_cost = 0
var stationary_seconds = 0.25
var stationary_station = 0

# Calibration tests measure real consumption over whole round trips with the tank sizes they were
# calibrated for; they set this to get the old full-size tanks (B2.2 halved petrol and battery and cut
# the air tank to a third). The game itself never sets it.
static var legacy_tanks = false
# B4.4: deadlines and bonuses of the orders. The tests of the older numbers leave it off; the game switches it on.
static var order_rules = false
# B5: the live train (elastic couplers, rocking, shifting cargo). The picture, the sound and the damage of the
# fragile cargo; the main physics of the train stays rigid. The tests of the older numbers leave it off.
static var live_effects = false
# B5.6: wear and damage of the nodes. The tests of the older numbers leave it off (every node stays new).
static var wear_rules = false
# B6.11 b: bolts from the road (the log of a trip, drops at the end, glints by the rail). The old tests leave it off.
static var junk_rules = false
var _wear = null
var live = Live.new()
var last_clank = 0.0
var last_cargo_hit = 0.0
const DEADLINE_GRACE = 1.05     # up to 5% over the time is still "on time"
const DEADLINE_FINE = 0.25      # the fine of a late free order, of its reward
const NIGHT_BONUS = 0.30

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	if legacy_tanks:
		for item in data.vehicles:
			if item.has("fuel_l") and item.id == "motorcar": item.fuel_l = float(item.fuel_l) * 2.0
			if item.has("battery_kwh"): item.battery_kwh = float(item.battery_kwh) * 2.0
			if item.has("air_bar"): item.air_bar = float(item.air_bar) * 3.0

# line_version 1 is the original 1.7 km line (what the tests use unless they ask), 2 the long
# line of about 6.8 km that the game gives to a new career (N7.3).
# starter: the free machine of a new career (the tests keep the handcar, the game starts on the pole truck).
func new_game(world_seed: int = 42, line_version: int = 1, mode: String = "career", spread: bool = false, starter: String = "handcar") -> void:
	loading_cache.clear()
	route.generate(world_seed, data.stations, line_version, [], spread)
	state = {"version": 2, "fleet_by_id": {starter: {"levels": {}, "fuel": 0.0, "consist": []}},
		"wagons_by_id": {}, "selected_vehicle_id": starter, "consist_ids": [],
		"money": 0, "chapter": 0, "completed_ids": [], "paid_ids": [], "active": {},
		"cargo": [], "s": 0.0, "v": 0.0, "direction": 1, "brake": 1.0, "throttle": 0.0,
		"gear": 0, "gearbox": 5, "engine": false, "phase": "depot", "finale": false, "reverser": 1,
		"visited_stations": ["A"], "tutorial": true,
		"stats": {"distance": 0.0, "deliveries": 0, "earned": 0, "rescues": 0, "seconds": 0.0}, "offer_serial": 0}
	reset_input()
	handcar = HandcarMechanism.new()
	hand_drive = HandcarDrive.new()
	pole = Pole.new()
	air_z = 0.0
	air_fly = false
	pump_angle = 0.0
	stationary_seconds=0.25
	stationary_station=0
	if mode == "creative": setup_creative()

# Creative mode (sandbox): every machine and wagon is in the garage, money and fuel do not
# run out, any order can be taken any number of times, and nothing is saved as progress.
const CREATIVE_MONEY = 99999999

func creative() -> bool:
	return str(state.get("mode", "career")) == "creative"

func setup_creative() -> void:
	state.mode = "creative"
	state.money = CREATIVE_MONEY
	var home = vehicle_id()
	for id in VEHICLE_IDS:
		if not state.fleet_by_id.has(id): buy_vehicle(id)
	while next_wagon_id() != "":
		if not buy_wagon(): break
	select_vehicle(home)
	state.money = CREATIVE_MONEY
	state.tutorial = false
	message = ""

func station_interaction() -> Dictionary:
	return StationInteraction.evaluate(self)

func service_stop(index: int) -> float:
	return StationInteraction.stop_position(self,index)

func update_station_dwell(dt: float) -> void:
	var interaction = station_interaction()
	if interaction.in_zone and absf(float(state.v))<=StationInteraction.STOP_SPEED:
		if stationary_station!=int(interaction.station_index): stationary_seconds=0.0
		stationary_station=int(interaction.station_index)
		stationary_seconds=minf(1,stationary_seconds+dt)
	else:
		stationary_seconds=0.0
		stationary_station=-1

# B1.1: what the player is asking the machine to do right now: open the throttle (a petrol car
# also needs a gear), grip the handcar lever, or lean on a planted pole.
func drive_command() -> bool:
	if state.is_empty(): return false
	match vehicle_id():
		"handcar": return hand_drive.held
		"pole": return pole.planted() and absf(pole.effort_target) > 0.05
		"sail": return sail_trim > 0.35 and sail_engaged()
		"motorcar": return float(state.throttle) > 0.02 and int(state.gear) > 0 and bool(state.engine)
		_: return float(state.throttle) > 0.02

# Driving off from the loading platform is the departure: no button, no brake to release.
func try_depart_by_driving() -> bool:
	if state.phase != "loading" or not depart(): return false
	state.brake = 0.0
	auto_brake = false
	return true

# A train that has come to rest on a platform holds itself; it lets go as soon as the player asks for
# traction. If the player takes the brake lever himself, the lever decides.
func update_auto_hold() -> void:
	if state.phase != "route": return
	if absf(float(state.v)) > 0.3: hold_armed = true
	var driving = drive_command()
	if auto_brake:
		if float(state.brake) < 0.9: auto_brake = false
		elif driving:
			state.brake = 0.0
			auto_brake = false
		return
	if driving or not hold_armed or float(state.brake) >= 0.95: return
	if absf(float(state.v)) > StationInteraction.STOP_SPEED: return
	if station_interaction().in_zone:
		state.brake = 1.0
		auto_brake = true
		hold_armed = false

func reset_input() -> void:
	hand_drive.release()
	sail_held = false
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
	var brake_base = 0.0 if wagon else float(base.brake_n)
	var result = {"slots": slots, "mass": mass, "rolling": 0.004 * float(ef.get("rolling_multiplier", 1.0)),
		"brake": brake_base * float(ef.get("brake_multiplier", 1.0)) + float(ef.get("add_brake_n", 0)),
		"shock": float(ef.get("cargo_shock_multiplier", 1.0)), "power": 220.0,
		"tank": float(base.get("battery_kwh", base.get("coal_kg", base.get("fuel_l", base.get("air_bar", 0))))) * float(ef.get("fuel_capacity_multiplier", 1.0)) * (1.0 if base.has("air_bar") else line_tank_scale(base)),
		"water": float(base.get("water_l", 0)) * line_tank_scale(base, true) * float(ef.get("water_capacity_multiplier", 1.0))}
	if not wagon and not human_powered(id):
		result.traction = [float(base.traction_n[0]) * float(ef.get("traction_multiplier", 1)) * float(ef.get("low_gear_multiplier", 1)),
			float(base.traction_n[1]) * float(ef.get("traction_multiplier", 1))]
		result.speeds = [float(base.gear_speed_mps[0]), float(base.gear_speed_mps[1]) * float(ef.get("high_gear_speed_multiplier", 1))]
		if base.has("gears"):
			# Manual gearbox: the two low gears use the low-gear upgrade, the two high ones the speed upgrade.
			result.traction = []
			result.speeds = []
			for i in range(base.gears.size()):
				var low = float(ef.get("low_gear_multiplier", 1)) if i < 2 else 1.0
				var high = float(ef.get("high_gear_speed_multiplier", 1)) if i >= 2 else 1.0
				result.traction.append(float(base.gears[i][0]) * float(ef.get("traction_multiplier", 1)) * low)
				result.speeds.append(float(base.gears[i][1]) * high)
	if wear_rules or object_state(id).has("wear"): apply_wear(id, result)
	return result

# The worn nodes weaken the numbers: the brake, the pull, the rolling resistance, the battery or the air tank, the shaking.
func apply_wear(id: String, result: Dictionary) -> void:
	var w = wear()
	result.brake = float(result.brake) * w.factor(id, "brake")
	result.rolling = float(result.rolling) * (2.0 - w.factor(id, "roll"))
	result.shock = float(result.shock) * (2.0 - w.factor(id, "shock"))
	result.tank = float(result.tank) * w.factor(id, "capacity")
	if result.has("traction"):
		var power = w.factor(id, "power")
		for i in range(result.traction.size()): result.traction[i] = float(result.traction[i]) * power

# The two classes that run on a person: no fuel, no cab, no pult, no reverser.
func human_powered(id: String = "") -> bool:
	return (id if id != "" else vehicle_id()) in ["handcar", "pole", "sail"]

func rank(id: String) -> int:
	return int(vehicle_base(id).get("rank", 0))

# Tanks grow with the line; each class may need a little more or less than the plain
# length ratio on the long line (line_tank_factor in the data, e.g. the electric drive
# weakens when the battery runs low and so needs headroom for a round trip).
func line_tank_scale(base: Dictionary, water: bool = false) -> float:
	var factor = float(base.get("line_water_factor" if water else "line_tank_factor", 1.0)) if route.version >= 2 else 1.0
	return route.fuel_scale() * factor

func max_wagons(id: String) -> int:
	return int(vehicle_base(id).get("max_wagons", 0))

func wagon_price(id: String) -> int:
	return int(data.wagon_prices.get(id, 0))

func next_wagon_id() -> String:
	for id in WAGON_IDS:
		if not state.wagons_by_id.has(id): return id
	return ""

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
	if state.fleet_by_id.has(id):
		return fail("Эта машина уже в гараже")
	if not depot_editable():
		return fail("Покупки доступны в депо до погрузки")
	var base = vehicle_base(id)
	if int(state.money) < int(base.cost):
		return fail("Не хватает %d монет" % (int(base.cost) - int(state.money)))
	state.money -= int(base.cost)
	state.fleet_by_id[id] = {"levels": {}, "fuel": 0.0, "consist": []}
	if id == "pneumatic":
		state.fleet_by_id[id].ice_spots = [0.0, 0.0, 0.0, 0.0]
		state.fleet_by_id[id].drain_t = [0.0, 0.0, 0.0, 0.0]
		state.fleet_by_id[id].reducer = 1.0
		state.fleet_by_id[id].heating = false
	var stats = object_stats(id)
	state.fleet_by_id[id].fuel = float(stats.tank)
	if float(stats.water) > 0: state.fleet_by_id[id].water = float(stats.water)
	# A machine without deck places comes with a first wagon, so it can earn.
	if int(base.deck_slots) == 0 and not state.wagons_by_id.has("W01"):
		state.wagons_by_id.W01 = {"levels": {}}
	select_vehicle(id)
	var free_wagons: Array = []
	for wagon in WAGON_IDS:
		if not state.wagons_by_id.has(wagon): continue
		var taken = false
		for other in state.fleet_by_id:
			if other != id and wagon in state.fleet_by_id[other].get("consist", []): taken = true
		if not taken: free_wagons.append(wagon)
	if free_wagons.is_empty():
		for wagon in WAGON_IDS:
			if state.wagons_by_id.has(wagon): free_wagons.append(wagon)
	state.consist_ids = free_wagons.slice(0, max_wagons(id))
	_claim_consist()
	events.append("coins")
	return true

func buy_wagon() -> bool:
	var id = next_wagon_id()
	if id == "":
		return fail("Все три вагона уже куплены")
	if not depot_editable():
		return fail("Покупки доступны в депо до погрузки")
	var price = wagon_price(id)
	if int(state.money) < price:
		return fail("Не хватает %d монет" % (price - int(state.money)))
	state.money -= price
	state.wagons_by_id[id] = {"levels": {}}
	if state.consist_ids.size() < max_wagons(vehicle_id()):
		state.consist_ids.append(id)
		_claim_consist()
	events.append("coins")
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
	var limit = max_wagons(vehicle_id())
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

# The casino (bolts, tokens, the wheel, the cards of the gadgets): a short-lived helper over the state.
func casino() -> Object:
	return Casino.new(self)

# Wear and damage of the nodes (wear.gd); one helper for the whole model.
func wear() -> Object:
	if _wear == null: _wear = Wear.new(self)
	return _wear

# A hit to the node of a machine that makes the given action; only when the wear rules are on.
func wear_hit(id: String, effect: String, amount: float, why: String = "", preferred: String = "") -> void:
	if wear_rules and not creative(): wear().damage_effect(id, effect, amount, why, preferred)

func wear_skid(speed: float) -> void:
	if not wear_rules or creative(): return
	wear().damage(vehicle_id(), "brake", 0.03 + 0.05 * clampf(speed / 25.0, 0.0, 1.0), "колёса заблокированы")
	wear().damage_effect(vehicle_id(), "roll", 0.02, "колёса заблокированы")

func wear_landing(impact: float) -> void:
	if not wear_rules or creative(): return
	var a = minf(0.12, 0.03 + 0.02 * (impact - 1.0))
	for id in body_ids():
		if id.begins_with("W"):
			wear().damage(id, "suspension", a, "приземление")
			wear().damage(id, "coupler", a * 0.7, "приземление")
		else:
			wear().damage_effect(id, "roll", a * 0.5, "приземление")

func wear_buffer(speed: float) -> void:
	if not wear_rules or creative(): return
	var a = minf(0.15, 0.05 + 0.03 * (speed - BUFFER_SAFE_SPEED))
	for id in body_ids():
		if id.begins_with("W"):
			wear().damage(id, "coupler", a, "удар об упор")
			wear().damage(id, "suspension", a * 0.6, "удар об упор")
		else:
			wear().damage_effect(id, "roll", a * 0.4, "удар об упор")

func upgrade(id: String, branch_id: String, via_card: bool = false, with_bolts: bool = false) -> bool:
	if not depot_editable() or object_state(id).is_empty():
		return fail("Улучшения доступны в депо до погрузки")
	for branch in data.upgrade_catalog:
		if branch.id != branch_id:
			continue
		if branch.target_type != ("wagon" if id.begins_with("W") else id):
			return fail("Это улучшение другой машины")
		if branch.get("gadget", false) and bool(data.casino.cards_only) and not via_card:
			return fail("Гаджет выбивается только в лудке: найди карточку в казике")
		var object = object_state(id)
		var lv = int(object.levels.get(branch_id, 0))
		if lv >= int(branch.get("levels", 2)):
			return fail("Уже установлено" if branch.get("gadget", false) else "Достигнут максимальный уровень")
		var cost = int(branch.level_costs[lv])
		# B6.11 c: a half of the price may be paid with the bolts of the bag (gadgets only come from the casino)
		var plan: Dictionary = {}
		if with_bolts:
			if branch.get("gadget", false): return fail("Гаджеты болтами не оплачиваются: их выбивают в казике")
			plan = casino().bolt_plan(cost)
			if int(plan.count) <= 0: return fail("В мешке нет болтов, чтобы доплатить")
			cost -= int(plan.coins)
		if state.money < cost:
			return fail("Не хватает %d монет" % (cost - state.money))
		state.money -= cost
		if with_bolts: casino().pay_bolts(plan)
		object.levels[branch_id] = lv + 1
		return true
	return false

func station_services(id: String) -> Dictionary:
	for station in data.stations:
		if station.id == id: return station.get("services", {})
	return {}

# The service offered right here: at the home depot when stopped, at a station when the
# train stands at the platform braked (the same condition as unloading). Prices are the
# class price times the station's multiplier; only stations with a service in the data
# offer it.
func service_offer() -> Dictionary:
	if human_powered(): return {}
	var id = ""
	if state.phase == "depot":
		if stopped(): id = "A"
	elif state.phase == "route":
		var interaction = station_interaction()
		if interaction.can_transfer: id = str(interaction.station_id)
	var services = station_services(id) if id != "" else {}
	return {} if services.is_empty() else {"station": id, "services": services}

func refuel() -> bool:
	var offer = service_offer()
	if offer.is_empty():
		return fail("Заправка есть в домашнем депо и на станциях с услугой: остановись у платформы")
	var services: Dictionary = offer.services
	var fleet = state.fleet_by_id[vehicle_id()]
	var stats = object_stats(vehicle_id())
	var water_added = false
	if float(stats.water) > 0 and services.has("water"):
		water_added = float(fleet.get("water", 0)) < float(stats.water) - 0.0001
		fleet.water = float(stats.water)
	var fuel_mult = fuel_service_mult(services)
	if fuel_mult < 0.0:
		if water_added:
			message = "Вода пополнена"
			return true
		return fail("Здесь нет заправки для этой машины")
	var missing = maxf(0, float(stats.tank) - float(fleet.fuel))
	var price = 0.0 if creative() else float(vehicle_base().get("refill_price", 0)) * fuel_mult
	if missing <= 0.0001 or price <= 0:
		fleet.fuel = float(stats.tank)
		return true
	# Pay for what is missing; with too little money fill what it buys.
	var amount = minf(missing, float(state.money) / price)
	var cost = ceili(amount * price - 0.0001)
	if amount <= 0.0001:
		return fail("Нет денег на пополнение: нужно %d монет" % ceili(missing * price))
	state.money -= cost
	fleet.fuel = float(fleet.fuel) + amount
	last_refill_cost = cost
	message = "Пополнено за %d монет" % cost if amount >= missing - 0.0001 else "Хватило денег только на часть запаса: %d монет" % cost
	return true

# How much room is left in the tank (in its own unit); 0 when it is full.
func tank_missing() -> float:
	if human_powered(): return 0.0
	return maxf(0.0, float(object_stats(vehicle_id()).tank) - float(state.fleet_by_id[vehicle_id()].fuel))

func refill_cost() -> int:
	if creative(): return 0
	var stats = object_stats(vehicle_id())
	var offer = service_offer()
	var multiplier = maxf(0.0, fuel_service_mult(offer.services)) if not offer.is_empty() else 1.0
	return ceili(maxf(0, float(stats.tank) - float(state.fleet_by_id[vehicle_id()].fuel)) * float(vehicle_base().get("refill_price", 0)) * multiplier - 0.0001)

# Longest stretch the machine has to cover on its own on a trip A -> far station -> A,
# when it can refill at the given positions (the home depot at 0 always counts).
func longest_leg(far_s: float, service_s: Array) -> float:
	var points: Array = [0.0]
	var sorted = service_s.duplicate()
	sorted.sort()
	for point in sorted:
		if float(point) > 0.0 and float(point) <= far_s: points.append(float(point))
	var leg = 0.0
	for i in range(1, points.size()): leg = maxf(leg, float(points[i]) - float(points[i - 1]))
	var last = float(points[-1])
	if far_s > last: leg = maxf(leg, 2.0 * (far_s - last))
	return leg

func mission_far_s(mission: Dictionary) -> float:
	var far = 0.0
	for stop in mission.get("dropoffs", []):
		for i in range(data.stations.size()):
			if data.stations[i].id == stop.station: far = maxf(far, float(route.station_s[i]))
	return far

# What a trip needs against what is in the tank. The rates are measured on this road by
# tests/check_forecast.gd (round trips driven with the player's own inputs, 20% margin) and
# the test fails if the model drifts away from them. A fixed part (start-up) plus distance: the road climbs under
# 20 m, so slope does not move the estimate; recalibrate when the line changes (N7.3).
func trip_forecast(mission: Dictionary = {}) -> Dictionary:
	if mission.is_empty(): mission = state.active
	if human_powered() or mission.is_empty(): return {}
	var base = vehicle_base()
	var fuel_points: Array = []
	var water_points: Array = []
	for i in range(data.stations.size()):
		var services = data.stations[i].get("services", {})
		if fuel_service_mult(services) >= 0.0: fuel_points.append(float(route.station_s[i]))
		if services.has("water"): water_points.append(float(route.station_s[i]))
	var far = mission_far_s(mission)
	var stats = object_stats(vehicle_id())
	var fleet = state.fleet_by_id[vehicle_id()]
	var leg = longest_leg(far, fuel_points)
	var water_leg = longest_leg(far, water_points)
	var suffix = "_v2" if route.version >= 2 else ""
	var rate = float(base.get("energy_per_m" + suffix, base.energy_per_m))
	var fixed = float(base.get("energy_fixed" + suffix, base.get("energy_fixed", 0.0) if suffix == "" else 0.0))
	var water_rate = float(base.get("water_per_m" + suffix, base.get("water_per_m", 0.0)))
	# a heavy load costs more: the rolling part of the energy grows with the cargo against the empty train
	# (measured: logs doubling the mass of the motorcar cost it 12%, the locomotive 10% for 42%; 0.35 covers all, thermal effects included)
	var empty_mass = 0.0
	for id in body_ids(): empty_mass += float(object_stats(id).mass)
	var cargo_mass = 0.0
	for stop in mission.get("dropoffs", []):
		for entry in stop.get("cargo", []): cargo_mass += float(cargo_base(str(entry[0])).mass_kg) * float(entry[1])
	var load_factor = 1.0 + 0.35 * cargo_mass / maxf(empty_mass, 1.0)
	return {"far_m": far, "leg_m": leg, "need": (fixed + leg * rate) * load_factor, "load_factor": load_factor, "have": float(fleet.fuel), "tank": float(stats.tank),
		"water_leg_m": water_leg, "water_need": water_leg * water_rate if float(stats.water) > 0 else 0.0,
		"water_have": float(fleet.get("water", 0)), "water_tank": float(stats.water), "unit": str(base.energy_unit)}

func current_mission() -> Dictionary:
	if int(state.chapter) >= data.missions.size():
		return {}
	return scaled_mission(data.missions[int(state.chapter)])

# On a longer line a career order pays in proportion to how much farther its far station
# is, so income per minute (and the time to afford a machine) stays what it was.
func mission_reward_scale(mission: Dictionary) -> float:
	if route.version < 2 or route.station_x.is_empty(): return 1.0
	var old_far = 0.0
	var new_far = 0.0
	for stop in mission.get("dropoffs", []):
		for i in range(data.stations.size()):
			if data.stations[i].id == stop.station:
				old_far = maxf(old_far, float(data.stations[i].s_m))
				new_far = maxf(new_far, float(route.station_x[i]))
	return new_far / old_far if old_far > 0.0 else 1.0

func scaled_mission(mission: Dictionary) -> Dictionary:
	var scale = mission_reward_scale(mission)
	if scale == 1.0 or mission.has("reward_scale"): return mission
	var copy = mission.duplicate(true)
	copy.reward = roundi(float(mission.reward) * scale)
	copy.reward_scale = scale
	return copy

func mission_count(mission: Dictionary) -> int:
	var count = 0
	for stop in mission.dropoffs:
		for pair in stop.cargo:
			count += int(pair[1])
	return count

func mission_error(mission: Dictionary) -> String:
	if mission.is_empty():
		return "Карьера завершена. Выбирай свободный рейс"
	if rank(vehicle_id()) < rank(str(mission.tier)) and not creative():
		return "Нужна техника не слабее: " + str(vehicle_base(mission.tier).name)
	if capacity() < 1:
		return "Нужно хотя бы одно свободное место для груза"
	if not human_powered():
		var forecast = trip_forecast(mission)
		if float(forecast.need) > float(forecast.tank):
			return "Бака не хватит на участок %.0f м без заправки: нужно примерно %.2f %s, бак %.2f. Нужна заправка по пути" % [forecast.leg_m, forecast.need, forecast.unit, forecast.tank]
		if float(forecast.have) < float(forecast.need):
			return "Запас мал: нужно примерно %.2f %s на %.0f м без заправки. Пополни его в депо" % [forecast.need, forecast.unit, forecast.leg_m]
		if float(forecast.water_tank) > 0 and float(forecast.water_have) < float(forecast.water_need):
			return "Мало воды: нужно примерно %.0f л на %.0f м без воды. Пополни её в депо" % [forecast.water_need, forecast.water_leg_m]
	return ""

func free_offers() -> Array:
	var offers: Array = []
	var reach = str(vehicle_base().get("free_reach", "F"))
	var max_station = 5
	for i in range(data.stations.size()):
		if data.stations[i].id == reach: max_station = i
	var types = ["sack", "parts", "logs"]
	for i in range(3):
		var destination = 1 + ((i + int(state.offer_serial)) % max_station)
		var cargo_type = types[(i + int(state.offer_serial)) % 3]
		if human_powered() and cargo_type == "logs": cargo_type = "sack"
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
			"tier": vehicle_id(), "reward": free_reward(dropoffs), "dropoffs": dropoffs, "free": true})
	return offers

# Per item: (25 + 0.06 per metre) times the class multiplier (ECONOMY_v3_2_RU.md).
func free_reward(dropoffs: Array) -> int:
	var total = 0.0
	for stop in dropoffs:
		var distance = 0.0
		for i in range(data.stations.size()):
			if data.stations[i].id == stop.station: distance = float(route.station_x[i])
		for pair in stop.cargo: total += (25.0 + 0.06 * distance) * int(pair[1])
	return roundi(total * float(vehicle_base().get("free_reward_multiplier", 1.0)))

# The time the order allows, in the game time of the road: the way there and back at 55% of the top speed
# and a minute and a half at the platforms, so that a careful driver is on time and a quick one is early.
func mission_budget_s(mission: Dictionary) -> float:
	var top = maxf(5.0, top_speed_kmh() / 3.6)
	var stops = mission.get("dropoffs", []).size()
	return 2.0 * mission_far_s(mission) / (0.55 * top) + 90.0 + 40.0 * float(stops)

# A heavy or big load pays more: from 300 kg +10%, from 600 kg +20%, and five places and more +10%.
func cargo_bonus(items: Array) -> float:
	var kilos = 0.0
	for item in items: kilos += float(cargo_base(item.type).mass_kg)
	var bonus = 0.2 if kilos >= 600.0 else (0.1 if kilos >= 300.0 else 0.0)
	if items.size() >= 5: bonus += 0.1
	return bonus

# Seconds left to the deadline of the order on the road; a large number when there is none.
func deadline_left() -> float:
	if state.active.is_empty() or not state.active.has("budget_s") or float(state.active.get("t_start", -1.0)) < 0.0: return 1.0e9
	return float(state.active.budget_s) * DEADLINE_GRACE - (float(state.stats.seconds) - float(state.active.t_start))

func accept_mission(mission: Dictionary) -> bool:
	if not mission.get("free", false): mission = scaled_mission(mission)
	if not depot_editable():
		return fail("Сначала закончи или отмени активный рейс")
	if mission.get("id", "") in state.paid_ids and not creative():
		return fail("Этот рейс уже оплачен")
	if not mission.get("free", false) and mission.get("id", "") != current_mission().get("id", "") and not creative():
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
	if order_rules and not creative():
		state.active.budget_s = mission_budget_s(mission)
		state.active.t_start = -1.0
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
	if vehicle_id()=="pole": available=Pole.F_MAX*0.6
	if vehicle_id()=="sail": available=140.0
	if not human_powered():
		var stats=object_stats(vehicle_id())
		available=minf(float(stats.traction[0])*maxf(0,1-pow(1.4/float(stats.speeds[0]),2))*charge_traction_factor(),0.35*float(stats.mass)*G)
	var ratio=required/maxf(1,available)
	var difficulty="Потребуется меньшая загрузка" if ratio>1 else ("Тяжёлый подъём" if ratio>0.7 else "Легко")
	loading_cache={"signature":signature,"loaded":loaded,"offered":int(state.active.get("offered_count",state.cargo.size())),"capacity":capacity(),"mass_kg":train_mass(),"reward":selected_reward(),"max_grade":steepest,"first_hill_m":first_hill,"required_force_n":required,"available_force_n":available,"difficulty":difficulty,"assessment_speed_mps":1.4}
	return loading_cache

func depart() -> bool:
	state.burst_left = 0.0
	state.burst_cooldown = 0.0
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
	if junk_rules and not creative(): casino().trip_start()
	if state.active.has("budget_s") and float(state.active.get("t_start", -1.0)) < 0.0:
		# the clock starts with the first departure; the load decides the bonus for a heavy cargo
		state.active.t_start = float(state.stats.seconds)
		state.active.night_start = night_amount() >= 0.6
		state.active.cargo_bonus = cargo_bonus(state.cargo)
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
	cool_boiler()
	return true

# B1.2d: "just drive": leave the depot without an order, no cargo, no pay, the same physics and fuel.
func start_free_ride() -> bool:
	if state.phase != "depot": return fail("Выехать можно из депо")
	if not state.active.is_empty(): return fail("Сначала продолжи или отмени начатый рейс")
	state.cargo = []
	state.phase = "route"
	state.s = service_stop(0)
	state.v = 0.0
	state.brake = 0.0
	state.throttle = 0.0
	state.direction = 1
	stationary_station = -1
	stationary_seconds = 0.0
	auto_brake = false
	hold_armed = false
	message = ""
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
	drop_temporary_wagon()
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
	live.reset()
	events.append("gear")
	return true

func settle() -> bool:
	if state.active.is_empty() or state.active.get("phase", "") != "return" or station_index() != 0 or not stopped():
		return false
	var id = str(state.active.id)
	if id in state.paid_ids or state.active.get("paid", false):
		return false
	var reward = int(state.active.pending_reward)
	# B4.4: early pays extra, on time is 100%, late costs a fine and the order burns (a story order is only cancelled)
	var late = false
	var exact = false
	var story = not state.active.get("free", false)
	var notes: Array = []
	if state.active.has("budget_s") and float(state.active.get("t_start", -1.0)) >= 0.0 and not creative():
		var budget = maxf(1.0, float(state.active.budget_s))
		var ratio = (float(state.stats.seconds) - float(state.active.t_start)) / budget
		exact = ratio >= float(data.casino.sources.exact_low) and ratio <= float(data.casino.sources.exact_high)
		if ratio > DEADLINE_GRACE:
			late = true
		else:
			var bonus = 0.0
			if ratio <= 0.75:
				bonus += 0.25
				notes.append("раньше срока +25%")
			elif ratio <= 0.9:
				bonus += 0.10
				notes.append("раньше срока +10%")
			if bool(state.active.get("night_start", false)):
				bonus += NIGHT_BONUS
				notes.append("ночной рейс +30%")
			var heavy = float(state.active.get("cargo_bonus", 0.0))
			if heavy > 0.0:
				bonus += heavy
				notes.append("тяжёлый и большой груз +%d%%" % roundi(heavy * 100.0))
			reward = roundi(float(reward) * (1.0 + bonus))
	if late:
		if story:
			reward = 0
			notes.append("срок вышел: рейс отменён, начни его заново")
		else:
			var fine = mini(int(state.money), roundi(DEADLINE_FINE * float(state.active.reward)))
			reward = -fine
			notes.append("опоздал: штраф %d, заказ сгорел" % fine)
	state.money += reward
	state.stats.earned += maxi(0, reward)
	if not creative() and not (late and story): state.paid_ids.append(id)
	state.active.paid = true
	var finds: Array = []
	if junk_rules and not creative(): finds = casino().trip_finds(exact, late)
	if not late and not creative(): casino().trip_done(bool(state.active.get("night_start", false)) or rain_effect() > 0.3)
	if not state.active.get("free", false) and not creative() and not late:
		state.completed_ids.append(id)
		state.chapter = mini(int(state.chapter) + 1, 10)
	if late:
		events.append("land")
	elif state.active.get("final", false) and not creative():
		state.finale = true
		events.append("finale")
	else:
		events.append("coins")
	if creative(): state.money = CREATIVE_MONEY
	state.last_result = {"title": state.active.title, "reward": reward, "final": state.active.get("final", false) and not creative() and not late, "late": late, "notes": notes, "finds": finds, "left_on_warehouse":state.active.get("warehouse_cargo",[]).size()}
	state.active = {}
	state.cargo = []
	drop_temporary_wagon()
	state.offer_serial += 1
	state.phase = "depot"
	state.engine = false
	state.throttle = 0.0
	state.gear = 0
	cool_boiler()
	if wear_rules: wear().free_touch_up()
	message = ("Рейс окончен. Заработано %d монет" % reward if reward >= 0 else "Рейс окончен с штрафом: %d монет" % -reward) + (" · " + ", ".join(notes) if not notes.is_empty() else "")
	return true

func rescue() -> void:
	state.s = route.station_s[0]
	state.v = 0.0
	state.brake = 1.0
	state.throttle = 0.0
	state.gear = 0
	state.engine = false
	cool_boiler()
	state.direction = 1
	state.reverser = 1
	live.reset()
	state.stats.rescues += 1
	reset_input()
	if not settle():
		state.phase = "depot"
	if wear_rules: wear().free_touch_up()
	refuel()
	message = "Помощь доставила состав в депо. Груз и покупки сохранены"

func set_gear(value: int) -> bool:
	if vehicle_id() in ["locomotive", "steam"]: return true
	if float(state.throttle) >= 0.15:
		return fail("Сначала убавь подачу ниже 15%")
	var wanted = clampi(value, 0, 6 if vehicle_id() == "motorcar" else 2)
	if vehicle_id() == "motorcar":
		var cfg = vehicle_base().engine
		var moving = absf(float(state.v)) > float(cfg.stop_speed_mps)
		if wanted != int(state.gear) and (wanted == 6 or int(state.gear) == 6) and moving:
			return fail("Задняя передача включается только после остановки")
		if wanted != int(state.gear) and wanted != 0 and moving: shift_cut = float(cfg.shift_cut_s)
	state.gear = wanted
	events.append("gear")
	return true

func set_reverser(value: int) -> bool:
	if vehicle_id()=="handcar": return fail("Направление ручной дрезины задаётся усилием на рычаге")
	if vehicle_id()=="pole": return fail("Шестовая идёт туда, куда толкнул шест")
	if vehicle_id()=="sail": return fail("Парусная идёт туда, куда её тянет парус")
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
	if vehicle_id() == "locomotive": return true
	if vehicle_id() == "steam": return light_fire() if value else douse_fire()
	if value:
		if vehicle_id() == "motorcar" and engine_temp() > TEMP_RESTART:
			return fail("Двигатель слишком горячий (%d%%): подожди, пока остынет" % roundi(engine_temp() * 100.0))
		if int(state.gear) != 0:
			return fail("Для запуска нужна нейтраль Н")
		if float(state.throttle) > 0.01:
			return fail("Для запуска убавь подачу до 0%")
		if state.fleet_by_id[vehicle_id()].fuel <= 0:
			return fail("Запас энергии закончился. Вызови помощь депо")
		if float(object_stats(vehicle_id()).water) > 0 and float(state.fleet_by_id[vehicle_id()].get("water", 0)) <= 0:
			return fail("Без воды котёл не разжечь. Пополни её в депо")
	state.engine = value
	events.append("gear")
	return true

# --- B4.1: the time of day. A game day is 24 minutes of driving (the clock runs only on the road, like
# the other statistics) and starts at seven in the morning, so that a save always knows what hour it is.
const DAY_SECONDS = 1440.0
const DAY_START_HOUR = 7.0

func world_hours() -> float:
	if state.is_empty(): return DAY_START_HOUR
	return fposmod(DAY_START_HOUR + float(state.stats.seconds) / DAY_SECONDS * 24.0, 24.0)

# 1 in the day, 0 in the night, soft at dawn (5-8) and dusk (18-21).
func daylight() -> float:
	var h = world_hours()
	return smoothstep(5.0, 8.0, h) * (1.0 - smoothstep(18.0, 21.0, h))

func night_amount() -> float:
	return 1.0 - daylight()

# Warm light of sunrise and sunset: strongest at 6:30 and 19:30.
func twilight() -> float:
	var h = world_hours()
	return clampf(1.0 - absf(h - 6.5) / 1.5, 0.0, 1.0) + clampf(1.0 - absf(h - 19.5) / 1.5, 0.0, 1.0)

# --- B4.2: the weather. Value noise over the game time, the same for the same career (seed) and for a
# save; it starts clear, so that a new player meets the forest in good weather first.
const WEATHER_SEGMENT_DAYS = 0.3

func weather_knot(channel: int, index: int) -> float:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(route.seed_value) * 7919 + channel * 104729 + index * 15485863
	return rng.randf()

func weather_noise(channel: int, days: float) -> float:
	var x = days / WEATHER_SEGMENT_DAYS
	var i = floori(x)
	return lerpf(weather_knot(channel, i), weather_knot(channel, i + 1), smoothstep(0.0, 1.0, x - float(i)))

var weather_force: Dictionary = {}   # tests (and nothing else) may fix the weather
var weather_effect = 1.0             # the player's setting: 1 normal, 0.5 weaker, 0 none (rain, fog and cold of the weather)
var weather_frequency = 1.0

func weather_at(seconds: float) -> Dictionary:
	if not weather_force.is_empty(): return weather_force
	var days = (DAY_START_HOUR / 24.0) + seconds / DAY_SECONDS
	var weather_days = (DAY_START_HOUR / 24.0) + seconds / DAY_SECONDS * weather_frequency
	var early = smoothstep(0.05, 0.4, seconds / DAY_SECONDS)
	var n = weather_noise(1, weather_days)
	var cloud = smoothstep(0.35, 0.8, n) * early
	var rain = smoothstep(0.7, 0.88, n) * early
	var hour = fposmod(days * 24.0, 24.0)
	var morning = 1.0 if hour >= 4.0 and hour <= 10.0 else 0.55
	var fog = smoothstep(0.68, 0.9, weather_noise(2, weather_days)) * morning * early
	return {"cloud": cloud, "rain": rain, "fog": fog}

func weather() -> Dictionary:
	if state.is_empty(): return {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	return weather_at(float(state.stats.seconds))

# B4.3: what the weather does to the game (physics). All of it is scaled by the player's setting.
func rain_effect() -> float:
	return float(weather().rain) * weather_effect

func fog_effect() -> float:
	return float(weather().fog) * weather_effect

# 0..1: the cold of the night (60%) and of the rain (20%).
func cold() -> float:
	return clampf(night_amount() * 0.6 + float(weather().rain) * 0.2, 0.0, 1.0) * weather_effect

# Wet rails: the wheels grip up to 30% worse, and the brake is up to 20% weaker.
func grip_factor() -> float:
	return 1.0 - 0.3 * rain_effect()

# How far ahead the driver can read the line: 400 m, in a thick fog 150 m.
func sight_m() -> float:
	return 400.0 - 250.0 * fog_effect()

func weather_name() -> String:
	var w = weather()
	if float(w.rain) > 0.35: return "дождь"
	if float(w.fog) > 0.4: return "туман"
	if float(w.cloud) > 0.45: return "облачно"
	return "ясно"

func clock_text() -> String:
	var h = world_hours()
	return "%02d:%02d" % [int(h), int(fposmod(h, 1.0) * 60.0)]

# --- B3.4: temperature of the petrol engine and the electric motor ---
# One number 0..1 per machine (fleet entry "temp"). It warms with the work done and cools with the
# speed of the air going past (Newton cooling), so a long climb at a crawl overheats and a run
# at speed does not. Over 0.85 the pull weakens; the petrol engine stalls at 1.0 and will not start
# again until it is under 0.6.
const TEMP_AMBIENT = 0.1
const TEMP_HOT = 0.85
const TEMP_RESTART = 0.6

# --- Supercapacitor (gadget of the electric locomotive, docs/GADGET_EFFECTS_PROPOSAL_RU.md): a button gives +50% of the pull
# for 5 seconds, takes 2% of the battery and needs 45 seconds to charge again.
const BURST_SECONDS = 5.0
const BURST_COOLDOWN = 45.0
const BURST_PULL = 1.5
const BURST_BATTERY_SHARE = 0.02

func supercap_installed() -> bool:
	return vehicle_id() == "locomotive" and float(effects("locomotive").get("locomotive_supercap", 0)) > 0.0

func burst_left() -> float:
	return float(state.get("burst_left", 0.0))

func burst_cooldown() -> float:
	return float(state.get("burst_cooldown", 0.0))

func burst_ready() -> bool:
	if not supercap_installed() or state.phase != "route": return false
	if burst_left() > 0.0 or burst_cooldown() > 0.0: return false
	var cost = float(object_stats("locomotive").tank) * BURST_BATTERY_SHARE
	return float(state.fleet_by_id.locomotive.fuel) > cost

func start_burst() -> bool:
	if not burst_ready(): return false
	var fleet = state.fleet_by_id.locomotive
	fleet.fuel = maxf(0.0, float(fleet.fuel) - float(object_stats("locomotive").tank) * BURST_BATTERY_SHARE)
	state.burst_left = BURST_SECONDS
	state.burst_cooldown = BURST_COOLDOWN
	events.append("burst")
	return true

func burst_step(dt: float) -> void:
	if state.has("burst_left") and float(state.burst_left) > 0.0: state.burst_left = maxf(0.0, float(state.burst_left) - dt)
	if state.has("burst_cooldown") and float(state.burst_cooldown) > 0.0: state.burst_cooldown = maxf(0.0, float(state.burst_cooldown) - dt)

func burst_factor() -> float:
	return BURST_PULL if burst_left() > 0.0 else 1.0

func has_temperature(id: String = "") -> bool:
	return (id if id != "" else vehicle_id()) in ["motorcar", "locomotive"]

func engine_temp() -> float:
	if not has_temperature(): return 0.0
	return float(state.fleet_by_id[vehicle_id()].get("temp", TEMP_AMBIENT))

# Heat the machine makes per second at the moment.
func heat_rate(fleet: Dictionary) -> float:
	var throttle = float(state.throttle)
	if vehicle_id() == "motorcar":
		if not state.engine: return 0.0
		var gear = int(state.gear)
		var low_gear = 1.0 + 0.1 * maxf(0.0, float(4 - gear)) if gear >= 1 and gear <= 5 else (1.3 if gear == 6 else 1.0)
		return 0.035 * (0.1 + 0.9 * throttle) * low_gear
	# electric: the current heats it (squared), regeneration heats it too
	var cfg = vehicle_base()
	return float(cfg.get("heat_per_s", 0.07)) * throttle * throttle + (0.02 if regen_kw > 0.01 else 0.0)

func thermal_step(dt: float, fleet: Dictionary) -> void:
	if not has_temperature(): return
	# in the cold the machine settles at a lower temperature, so it is cold for longer
	var ambient = TEMP_AMBIENT * (1.0 - 0.6 * cold())
	var temp = float(fleet.get("temp", TEMP_AMBIENT))
	var liquid = vehicle_id() == "locomotive" and float(effects("locomotive").get("liquid_cooling", 0)) > 0.0   # gadget: liquid cooling
	var cooling = (0.03 + 0.004 * absf(float(state.v))) * (temp - ambient) * (1.3 if liquid else 1.0)
	temp = clampf(temp + (heat_rate(fleet) * (0.6 if liquid else 1.0) * (1.0 if state.phase == "route" else 0.3) - cooling) * dt, ambient * 0.5, 1.0)
	fleet.temp = temp
	if wear_rules and temp > TEMP_HOT: wear_hit(vehicle_id(), "power", 0.01 * (temp - TEMP_HOT) / (1.0 - TEMP_HOT) * dt, "перегрев")
	if vehicle_id() == "motorcar" and temp >= 1.0 and bool(state.engine):
		state.engine = false
		events.append("gear")
		message = "Двигатель перегрелся и заглох. Подожди, пока остынет, потом пуск"

# Multiplier of the pull from the temperature: a cold petrol engine is weak for a moment, a hot one weaker.
func thermal_factor() -> float:
	if not has_temperature(): return 1.0
	var temp = engine_temp()
	var hot = lerpf(1.0, 0.7 if vehicle_id() == "motorcar" else 0.6, clampf((temp - TEMP_HOT) / (1.0 - TEMP_HOT), 0.0, 1.0))
	var cold = 1.0
	if vehicle_id() == "motorcar" and temp < 0.2: cold = lerpf(0.8, 1.0, clampf((temp - TEMP_AMBIENT) / (0.2 - TEMP_AMBIENT), 0.0, 1.0))
	if vehicle_id() == "locomotive": hot *= 1.0 - 0.2 * cold()
	return hot * cold

# --- Petrol gearbox: forward gears 1-5, N (0), R (=6). The fifth is an overdrive, B3.6 ---

# Engine fraction 0..1 between idle and the rev limit.
# Drawing runs at the display rate, the model steps at 60 Hz. Positions for the
# picture are pulled back by the part of the last step that has not happened yet
# on screen, so motion is smooth at any frame rate.
func render_shift() -> float:
	return (1.0 - clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)) * last_movement

func render_s() -> float:
	return float(state.s) - render_shift()

func body_s_render(index: int) -> float:
	var slack = float(state.direction) * live.slack_m(index) if live_effects else 0.0   # the couplers play
	return body_s(index) + slack - render_shift()

# Air drag per class (the old single 1.2 is right for the slow machines; a fast machine
# is streamlined). N11 sets the top speeds with this and the power limit below.
# --- Pneumatic train (N12): compressed air, frost on the pipes ---

# What one bar of the 150 is worth in joules; the long line scales it so that a full tank
# is still about one round trip (N10), like every other class.
func air_joule_per_bar() -> float:
	var base = vehicle_base("pneumatic")
	return float(base.air_joule_per_bar) * route.fuel_scale() * float(base.get("line_tank_factor", 1.0)) if route.version >= 2 else float(base.air_joule_per_bar)

func pneumatic_fleet() -> Dictionary:
	return state.fleet_by_id.get("pneumatic", {})

# Four spots on the pipes frost over unevenly; the machine feels their mean.
func frost() -> float:
	var spots = pneumatic_fleet().get("ice_spots", [0.0, 0.0, 0.0, 0.0])
	var total = 0.0
	for spot in spots: total += float(spot)
	return total / maxf(1.0, float(spots.size()))

# --- B6.2: the reducer and the heating of the pipes (decision of the owner 01.11.2026, ROADMAP_RU.md section 6.6)
# Two pressures: the receiver (the store, `fuel`) and the working pressure that goes to the cylinders. The wheel of the reducer
# (3 turns, position 0..1) sets the working pressure from 10% to 60% of a full tank; the pull grows with it, the frost on
# the pipes grows with its 1.5th power. The heating tap slows the frost down 5 times and costs 15% more air; four drain
# valves let the condensate out: not pressed for 60 s of running, a spot gets an ice plug (the frost there grows twice as fast).
const REDUCER_MIN = 0.10
const REDUCER_MAX = 0.60
const HEATING_FROST = 0.2
const HEATING_AIR = 1.15
const DRAIN_SECONDS = 60.0
const PLUG_FROST = 2.0

func reducer_position() -> float:
	return clampf(float(pneumatic_fleet().get("reducer", 1.0)), 0.0, 1.0)

func set_reducer(position: float) -> bool:
	if vehicle_id() != "pneumatic": return false
	state.fleet_by_id.pneumatic.reducer = clampf(position, 0.0, 1.0)
	return true

# The setting of the reducer as a fraction of a full tank (0.10 .. 0.60)
func reducer_setting() -> float:
	return lerpf(REDUCER_MIN, REDUCER_MAX, reducer_position())

# The working pressure in bar: what the reducer lets through, but not more than the receiver holds
func working_pressure() -> float:
	if vehicle_id() != "pneumatic": return 0.0
	return minf(float(state.fleet_by_id.pneumatic.fuel), reducer_setting() * float(object_stats("pneumatic").tank))

func heating_on() -> bool:
	return bool(pneumatic_fleet().get("heating", false))

func set_heating(on: bool) -> bool:
	if vehicle_id() != "pneumatic": return false
	state.fleet_by_id.pneumatic.heating = on
	events.append("gear")
	return true

# Seconds of running since the drain valve of the spot was pressed
func drain_age(spot: int) -> float:
	var ages: Array = pneumatic_fleet().get("drain_t", [0.0, 0.0, 0.0, 0.0])
	return float(ages[spot]) if spot >= 0 and spot < ages.size() else 0.0

func plugged(spot: int) -> bool:
	return drain_age(spot) > DRAIN_SECONDS

func drain_due(spot: int) -> bool:
	return drain_age(spot) > 0.8 * DRAIN_SECONDS

func drain(spot: int) -> bool:
	if vehicle_id() != "pneumatic": return false
	var fleet = state.fleet_by_id.pneumatic
	var ages: Array = fleet.get("drain_t", [0.0, 0.0, 0.0, 0.0])
	if spot < 0 or spot >= ages.size(): return false
	ages[spot] = 0.0
	fleet.drain_t = ages
	events.append("gear")
	return true

func pneumatic_factor() -> float:
	if vehicle_id() != "pneumatic": return 1.0
	# the pull is full from 40% of a full tank upwards (it was 60 bar of 150); now the working pressure counts, not the receiver
	return minf(1.0, working_pressure() / (0.4 * float(object_stats("pneumatic").tank))) * (1.0 - 0.7 * frost())

func update_frost(fleet: Dictionary, dt: float) -> void:
	var spots: Array = fleet.get("ice_spots", [0.0, 0.0, 0.0, 0.0])
	var running = absf(float(state.v)) > 0.3 and float(state.throttle) > 0.0
	var weights = [1.0, 0.8, 0.6, 0.4]
	var ages: Array = fleet.get("drain_t", [0.0, 0.0, 0.0, 0.0])
	var reducer_k = pow(reducer_setting() / REDUCER_MAX, 1.5)   # the frost grows with the 1.5th power of the working pressure (1 with the wheel all the way open)
	var heating_k = HEATING_FROST if bool(fleet.get("heating", false)) else 1.0
	for i in range(spots.size()):
		if absf(float(state.v)) > 0.3: ages[i] = float(ages[i]) + dt   # the condensate gathers while the train is moving
		if running:
			var plug_k = PLUG_FROST if float(ages[i]) > DRAIN_SECONDS else 1.0
			spots[i] = minf(1.0, float(spots[i]) + 0.02 * float(effects("pneumatic").get("frost_multiplier", 1.0)) * (1.0 + 0.8 * cold()) * float(state.throttle) * (float(fleet.fuel) / float(object_stats("pneumatic").tank)) * float(weights[i]) * reducer_k * heating_k * plug_k * dt)
		elif absf(float(state.v)) < 0.1: spots[i] = maxf(0.0, float(spots[i]) - 0.01 * dt)
	fleet.ice_spots = spots
	fleet.drain_t = ages
	if wear_rules and frost() > 0.5: wear().damage("pneumatic", "seals", 0.01 * dt / 60.0, "иней на трубках")

# A click on a frosted spot knocks a quarter of the ice off it.
func chip_ice(spot: int) -> bool:
	if vehicle_id() != "pneumatic": return false
	var fleet = state.fleet_by_id.pneumatic
	var spots: Array = fleet.get("ice_spots", [0.0, 0.0, 0.0, 0.0])
	if spot < 0 or spot >= spots.size() or float(spots[spot]) < 0.05: return false
	spots[spot] = maxf(0.0, float(spots[spot]) - 0.25)
	fleet.ice_spots = spots
	events.append("gear")
	return true

# The multiplier of this station's fuel service for the current machine: the pneumatic
# train fills from a compressor ("air") where there is one, otherwise from the fuel service.
func fuel_service_mult(services: Dictionary) -> float:
	if vehicle_id() == "pneumatic" and services.has("air"): return float(services.air)
	return float(services.fuel) if services.has("fuel") else -1.0

# The class's stated top speed (km/h) in the base build with a light load; the speed tests
# hold the model to it.
func top_speed_kmh(id: String = "") -> float:
	var base = vehicle_base(id) if id != "" else vehicle_base()
	return float(base.get("top_speed_kmh", 0.0))

func drag_coefficient() -> float:
	return float(vehicle_base().get("drag", 1.2))

# Power limit of the drive (W): the pull cannot exceed power / speed, so the machine
# is strong at a standstill but accelerates more and more slowly as it speeds up. The
# steam locomotive's limit follows the boiler pressure, the electric one the charge.
func power_limit_force(scale: float = 1.0) -> float:
	var cap = float(vehicle_base().get("power_cap_w", 0.0))
	if cap <= 0.0: return INF
	return cap * scale / maxf(absf(float(state.v)), 1.5)

func boiler_cap_scale() -> float:
	return clampf(float(boiler().pressure) * 1.25, 0.0, 1.0)

func engine_rpm_fraction() -> float:
	if vehicle_id() != "motorcar" or not state.engine: return 0.0
	var gear = int(state.gear)
	var thr = float(state.throttle)
	if gear == 0: return thr
	var idx = 0 if gear == 6 else gear - 1
	var ratio = absf(float(state.v)) / float(object_stats("motorcar").speeds[idx])
	return clampf(maxf(ratio, thr * 0.3), 0.0, 1.0)

func engine_rpm() -> float:
	if vehicle_id() != "motorcar" or not state.engine: return 0.0
	var cfg = vehicle_base().engine
	return lerpf(float(cfg.idle_rpm), float(cfg.max_rpm), engine_rpm_fraction())

# Engine braking: with the pedal released and a gear in, the engine drags the car in
# proportion to its speed. Neutral and a stopped engine do not.
func engine_brake_force() -> float:
	if vehicle_id() != "motorcar" or not state.engine or int(state.gear) == 0 or float(state.throttle) > 0.05: return 0.0
	return float(vehicle_base().engine.engine_brake_n) * engine_rpm_fraction()

# Too high a gear at walking pace under throttle stalls the engine after a moment.
func petrol_stall_check(gear: int, stats: Dictionary, dt: float) -> void:
	var cfg = vehicle_base().engine
	var ratio = absf(float(state.v)) / float(stats.speeds[gear])
	if gear >= 2 and float(state.throttle) > 0.3 and ratio < float(cfg.stall_below):
		stall_clock += dt
	else:
		stall_clock = maxf(0.0, stall_clock - dt * 2.0)
	if stall_clock >= float(cfg.stall_seconds):
		stall_clock = 0.0
		state.engine = false
		events.append("gear")
		if wear_rules and not creative():
			wear().damage("motorcar", "engine", 0.02, "двигатель глох на передаче")
			wear().damage("motorcar", "gearbox", 0.02, "двигатель глох на передаче")
		message = "Двигатель заглох: передача слишком высокая для этого хода. Нейтраль, пуск, потом пониже"

# High gears pull weakly at low engine speed: the engine lugs.
func petrol_lug(gear: int, stats: Dictionary) -> float:
	if vehicle_id() != "motorcar" or gear < 2: return 1.0
	var cfg = vehicle_base().engine
	var ratio = absf(float(state.v)) / float(stats.speeds[gear])
	if ratio >= float(cfg.lug_below): return 1.0
	return lerpf(float(cfg.lug_min), 1.0, ratio / float(cfg.lug_below))

# --- Steam boiler (N4). Simplified game model, see VEHICLE_CLASSES_v3_1_RU.md ---

func boiler_cfg() -> Dictionary:
	return vehicle_base("steam").boiler

# The boiler lives in the steam fleet entry; old saves get cold defaults.
func boiler() -> Dictionary:
	var fleet = state.fleet_by_id.steam
	for key in ["firebox", "heat", "pressure", "chill"]:
		if not fleet.has(key): fleet[key] = 0.0
	for key in ["lit", "door", "venting"]:
		if not fleet.has(key): fleet[key] = false
	if not fleet.has("feed"): fleet.feed = float(boiler_cfg().default_feed)
	return fleet

func pressure_bar() -> float:
	if not state.fleet_by_id.has("steam"): return 0.0
	return float(boiler().pressure) * float(boiler_cfg().max_pressure_bar)

func steam_ready() -> bool:
	return vehicle_id() == "steam" and pressure_bar() >= float(boiler_cfg().work_pressure_bar)

func cool_boiler() -> void:
	if not state.get("fleet_by_id", {}).has("steam"): return
	var b = boiler()
	b.lit = false
	b.door = false
	b.heat = 0.0
	b.pressure = 0.0
	b.venting = false

# A save from before N4 had no boiler. A mid-trip steam save gets a warm one,
# so the career does not strand on load.
func migrate_boiler() -> void:
	if not state.fleet_by_id.has("steam"): return
	var fresh = not state.fleet_by_id.steam.has("pressure")
	var b = boiler()
	if fresh and state.phase == "route" and vehicle_id() == "steam":
		b.firebox = 6.0
		b.lit = true
		b.heat = 1.0
		b.pressure = 0.8

func set_door(open: bool) -> bool:
	if vehicle_id() != "steam": return fail("Топка есть только у паровоза")
	boiler().door = open
	events.append("gear")
	return true

func stoke() -> bool:
	if vehicle_id() != "steam": return fail("Топка есть только у паровоза")
	var b = boiler()
	var cfg = boiler_cfg()
	var fleet = state.fleet_by_id.steam
	if not bool(b.door): return fail("Сначала открой топочную дверцу")
	if float(fleet.fuel) <= 0.0: return fail("Уголь в ведре закончился. Пополни его в депо")
	var room = float(cfg.firebox_kg) - float(b.firebox)
	if room < 0.5: return fail("Топка полна")
	var kg = minf(minf(float(cfg.portion_kg), room), float(fleet.fuel))
	fleet.fuel = float(fleet.fuel) - kg
	b.firebox = float(b.firebox) + kg
	# fresh coal cools the fire for a moment, the more the bigger the portion
	b.chill = float(cfg.get("chill_s", 5.0)) * kg / float(cfg.portion_kg)
	events.append("cargo")
	return true

func light_fire() -> bool:
	if vehicle_id() != "steam": return fail("Розжиг нужен только паровозу")
	var b = boiler()
	if bool(b.lit): return fail("Огонь уже горит")
	if float(b.firebox) < float(boiler_cfg().min_fire_kg):
		return fail("В топке нет угля. Открой дверцу и брось уголь из ведра")
	if float(state.fleet_by_id.steam.get("water", 0)) <= 0.0:
		return fail("Без воды котёл не разжечь. Пополни её в депо")
	b.lit = true
	state.engine = true
	events.append("gear")
	message = "Огонь разожжён. Давление растёт, подожди"
	return true

func douse_fire() -> bool:
	if vehicle_id() != "steam": return true
	boiler().lit = false
	state.engine = false
	events.append("gear")
	return true

func set_feed(value: float) -> void:
	if vehicle_id() == "steam": boiler().feed = clampf(value, 0.0, 1.0)

# One tick of fire, water and steam. Returns the signed pull of the engine.
func steam_step(dt: float, fleet: Dictionary) -> float:
	var cfg = boiler_cfg()
	var b = boiler()
	var on_route = state.phase == "route"
	state.gear = 1
	# The regulator is spring loaded: let go and it closes. It never brakes.
	if on_route and not valve_held and float(state.throttle) > 0.0:
		state.throttle = maxf(0.0, float(state.throttle) - dt / float(cfg.spring_seconds))
	var valve = float(state.throttle) if on_route else 0.0
	var water = float(fleet.get("water", 0))
	if bool(b.lit) and float(b.firebox) <= 0.0: b.lit = false
	var burning = bool(b.lit)
	# B3.4: the heat follows the coal on the grate, a thin fire is a weak one; a fresh portion chills it
	var fill = float(b.firebox) / float(cfg.firebox_kg)
	b.chill = maxf(0.0, float(b.chill) - dt)
	if float(effects("steam").get("steam_stoker", 0)) > 0.0: b.chill = 0.0
	var heat_target = 0.0
	if burning:
		heat_target = smoothstep(0.0, float(cfg.get("thin_fire", 0.3)), fill) * (1.0 - float(cfg.get("chill_loss", 0.3)) * clampf(float(b.chill) / float(cfg.get("chill_s", 5.0)), 0.0, 1.0))
	var gadgets = effects("steam")
	var superheater = float(gadgets.get("steam_superheater", 0)) > 0.0
	var stoker = float(gadgets.get("steam_stoker", 0)) > 0.0
	# the mechanical stoker feeds the fire from the bucket by itself and keeps it at about half a grate, without chilling it
	if stoker and burning and bool(b.lit):
		var want = 0.55 * float(cfg.firebox_kg)
		if float(b.firebox) < want - 0.4 and float(fleet.fuel) > 0.0:
			var feed = minf(minf(0.18 * dt, want - float(b.firebox)), float(fleet.fuel))
			fleet.fuel = float(fleet.fuel) - feed
			b.firebox = float(b.firebox) + feed
	var chill_k = 1.0 + 0.4 * cold()   # in the cold the fire and the boiler lose heat faster
	b.heat = move_toward(float(b.heat), heat_target, dt * (1.0 if heat_target > float(b.heat) else chill_k) / float(cfg.heat_rise_s if heat_target > float(b.heat) else cfg.heat_fall_s))
	if burning:
		b.firebox = maxf(0.0, float(b.firebox) - (float(cfg.idle_burn_kg_s) + float(cfg.load_burn_kg_s) * valve) * float(effects("steam").get("fire_burn_multiplier", 1.0)) * (0.7 if float(effects("steam").get("steam_superheater", 0)) > 0.0 else 1.0) * (1.2 if float(effects("steam").get("steam_stoker", 0)) > 0.0 else 1.0) * dt)
	# Steam appears only from fire AND water; the tap limits how fast.
	var feed_k = clampf(float(b.feed) / float(cfg.feed_full), 0.0, 1.0) if water > 0.0 else 0.0
	var door_k = float(cfg.door_open_loss) if bool(b.door) else 1.0
	# an overfull firebox chokes: up to 30% less steam
	var choke = 1.0 - float(cfg.get("choke_loss", 0.3)) * clampf((fill - float(cfg.get("choke_from", 0.85))) / (1.0 - float(cfg.get("choke_from", 0.85))), 0.0, 1.0)
	var made = float(cfg.steam_per_s) * float(effects("steam").get("steam_power_multiplier", 1.0)) * (1.1 if superheater else 1.0) * float(b.heat) * feed_k * door_k * choke * dt
	var p = float(b.pressure)
	var spent = minf(p + made, float(cfg.use_per_s) * valve * dt)
	var cooling = float(cfg.cooling_per_s) * (1.0 - float(b.heat)) * dt * chill_k
	var after = p + made - spent - cooling
	var vented = maxf(0.0, after - 1.0)
	b.pressure = clampf(after, 0.0, 1.0)
	b.venting = vented > 0.0
	fleet.water = maxf(0.0, water - (made - vented) * float(cfg.water_l_per_unit))
	if wear_rules and burning and water <= 0.0 and float(b.heat) > 0.3 and not bool(b.get("dry_hit", false)):
		b.dry_hit = true
		wear().damage("steam", "boiler", 0.05, "котёл без воды")
	elif water > 0.0: b.dry_hit = false
	state.engine = bool(b.lit)
	if not on_route: return 0.0
	var stats = object_stats("steam")
	var low = float(cfg.work_pressure_bar) / float(cfg.max_pressure_bar)
	var strong = smoothstep(low, 0.8, float(b.pressure))
	var vmax = lerpf(float(stats.speeds[0]), float(stats.speeds[1]), smoothstep(low, 1.0, float(b.pressure)))
	var pull = float(stats.traction[0]) * strong * valve * maxf(0.0, 1.0 - pow(absf(float(state.v)) / vmax, 2))
	pull = minf(pull, power_limit_force(boiler_cap_scale()))
	var adhesion = 0.35 * float(stats.mass) * G * cos(route.slope(float(state.s))) * grip_factor()
	return float(drive_direction()) * minf(pull, adhesion)

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

# --- Rail zeppelin (B6.5): the levers live in the state (the throttle and the brake are the usual ones), the physics in zeppelin.gd
func zeppelin_pitch() -> float:
	return clampf(float(state.get("zep_pitch", 0.0)), 0.0, 1.0)

func zeppelin_stick() -> float:
	return clampf(float(state.get("zep_stick", 0.0)), -6.0, 12.0)

func set_zeppelin_pitch(value: float) -> bool:
	if vehicle_id() != "zeppelin": return false
	state.zep_pitch = clampf(value, 0.0, 1.0)
	return true

# the joystick: the angle of attack in degrees; it stays where it was left
func set_zeppelin_stick(degrees: float) -> bool:
	if vehicle_id() != "zeppelin": return false
	state.zep_stick = clampf(degrees, -6.0, 12.0)
	return true

func set_zeppelin_air_brake(on: bool) -> bool:
	if vehicle_id() != "zeppelin": return false
	state.zep_air_brake = on
	return true

func zeppelin_restart() -> bool:
	if vehicle_id() != "zeppelin": return false
	zep.throttle = float(state.throttle)
	if not zep.restart(): return fail("Мотор не заводится: закрой газ и дай ему остыть")
	state.engine = true
	return true

# One step of the zeppelin on the line. Returns the new speed along the rail (the movement is integrated by the caller).
func zeppelin_step(dt: float, fleet: Dictionary, old_v: float) -> float:
	var forward = float(drive_direction())
	if forward == 0.0: forward = 1.0
	var slope = route.slope(float(state.s)) * forward
	# the wind along the nose: the wind of the line is along the direction of the consist, the reverser turns the nose
	var wind_along = wind_here().x * float(int(state.get("reverser", 1)))
	zep.cfg.fuel_l = float(vehicle_base().fuel_l)
	zep.fuel = float(fleet.fuel)
	zep.v = old_v * forward
	zep.set_throttle(float(state.throttle))
	zep.set_pitch(zeppelin_pitch())
	zep.set_stick(zeppelin_stick())
	zep.set_pad_brake(float(state.brake))
	zep.set_air_brake(bool(state.get("zep_air_brake", false)))
	zep.step(dt, slope, wind_along)
	fleet.fuel = zep.fuel
	state.engine = not zep.stalled and not zep.crashed and zep.fuel > 0.0
	air_fly = zep.airborne
	air_z = zep.z
	air_vy = zep.vz
	for event in zep.events:
		if event == "crash":
			events.append("crash")
		elif event in ["takeoff", "land", "stall", "overheat", "redline"]:
			events.append("zep_" + event)
	return zep.v * forward

# a crashed zeppelin: half of the money (the share is in the data), the machine is brought to the depot as by the rescue
func zeppelin_crashed() -> void:
	var cfg = vehicle_base("zeppelin").get("zeppelin", {})
	zep.cfg.crash_penalty_share = float(cfg.get("crash_penalty_share", 0.5))
	zep.cfg.crash_penalty_min = float(cfg.get("crash_penalty_min", 300))
	var penalty = zep.crash_penalty(int(state.money))
	state.money = maxi(0, int(state.money) - penalty)
	var reason = zep.crash_reason
	zep.reset(float(vehicle_base("zeppelin").fuel_l))
	air_fly = false
	air_z = 0.0
	air_vy = 0.0
	state.zep_pitch = 0.0
	state.zep_stick = 0.0
	rescue()
	message = "Крушение: %s. Штраф %d монет. Машину привезли в депо" % [reason, penalty]

# --- Sail car (B6.4): the sail takes the force from the apparent wind, the player trims it ---
func wind_ready() -> void:
	if wind.station_s != route.station_s: wind.build(int(route.seed_value), route.station_s)

# The wind here and now, x along the travel direction (tail wind positive), y across.
func wind_here(s: float = -9999.0) -> Vector2:
	wind_ready()
	var place = float(state.s) if s < -9000.0 else s
	var vector = wind.at(place, float(state.stats.seconds))
	# a rain squall is gusty: up to 2 m/s more along the wind
	if vector.length() > 0.1: vector += vector.normalized() * 2.0 * rain_effect()
	return Vector2(vector.x * float(int(state.direction)), vector.y)

func set_sail_trim(value: float) -> void:
	if vehicle_id() == "sail": sail_trim = clampf(value, 0.0, 1.0)

func set_sail_lift(value: float) -> void:
	if vehicle_id() == "sail": sail_lift = clampf(value, -0.35, 0.9)

func sail_set_side(value: int) -> void:
	if vehicle_id() == "sail": sail_side = 1 if value >= 0 else -1

func sail_engaged() -> bool:
	return sail_held or sail_cleated

# Take the free corner of the sail in the hand (off the cleat if it was made fast there).
func sail_grab() -> void:
	if vehicle_id() != "sail": return
	sail_held = true
	sail_cleated = false
	sail_over = 0.0

func sail_release() -> void:
	sail_held = false

# Make the sheet fast on the cleat: the trim stays, the hand is free.
func sail_cleat() -> void:
	if vehicle_id() != "sail" or not sail_held: return
	sail_cleated = true
	sail_held = false
	sail_over = 0.0
	# the plain cleat holds the sheet in its notches; the gadget lets it hold anywhere
	if not bool(effects("sail").get("sail_any_lock", false)):
		var nearest = SAIL_NOTCHES[0]
		for notch in SAIL_NOTCHES:
			if absf(float(notch) - sail_trim) < absf(float(nearest) - sail_trim): nearest = notch
		sail_trim = float(nearest)
	events.append("gear")

# How well the trim suits the angle of the apparent wind: 1 is perfect, 0 is no pull.
func sail_best_trim(beta: float) -> float:
	var best = 1.0
	if beta > 0.52: best = lerpf(1.0, 0.45, clampf((beta - 0.52) / (PI * 0.5 - 0.52), 0.0, 1.0))
	if beta > PI * 0.5: best = lerpf(0.45, 0.25, clampf((beta - PI * 0.5) / (PI * 0.5), 0.0, 1.0))
	return best

func sail_quality(beta: float, trim: float) -> float:
	return maxf(0.0, 1.0 - pow((trim - sail_best_trim(beta)) / 0.4, 2.0))

# The pull coefficient by the angle of the apparent wind (0 tail wind, PI head wind): the best on a
# run and a beam reach, falling away to nothing close to the wind, a little drag dead against it.
func sail_pull(beta: float) -> float:
	if beta <= 1.745: return 1.2 + 0.2 * sin(minf(beta, PI * 0.5))
	if beta <= 2.27: return 1.4 * (1.0 - (beta - 1.745) / (2.27 - 1.745))
	return -0.15

# The force of the sail along the route (route frame), and the numbers for the hud and the picture.
func sail_step(dt: float = 1.0 / 60.0) -> float:
	wind_ready()
	var w = wind_here()
	var forward_speed = float(state.v) * float(int(state.direction))
	var ua = w.x - forward_speed
	var uc = w.y
	var apparent = sqrt(ua * ua + uc * uc)
	var beta = atan2(absf(uc), ua)
	# the autopilot gadget trims the sheet made fast on the cleat by itself, a little slower than a good hand
	var gadgets = effects("sail")
	var autopilot = bool(gadgets.get("sail_autopilot", false))
	if autopilot and sail_cleated: sail_trim = move_toward(sail_trim, sail_best_trim(beta), 0.5 * dt)
	var quality = sail_quality(beta, sail_trim)
	# a boom swung to the windward side is backed by the wind: half the pull. Wind from ahead or behind does not mind the side.
	if absf(uc) > 0.5 and float(sail_side) * signf(uc) < 0.0: quality *= 0.5
	var area = SAIL_AREA_M2 * float(effects("sail").get("sail_area_multiplier", 1.0))
	var pulled = 0.5 * 1.2 * area * apparent * apparent * sail_pull(beta) * (quality if sail_pull(beta) > 0.0 else 1.0)
	# the corner held high or low twists the cloth and spills some of the wind
	pulled *= 1.0 - 0.5 * absf(sail_lift) / 0.9
	# the spinnaker: a huge sail for the tail wind (1.8 times the pull), no good across the wind, and it tears loose sooner
	var spinnaker = float(gadgets.get("sail_spinnaker", 0)) > 0.0
	if spinnaker: pulled *= 1.8 if beta < 0.7 else 0.85
	if autopilot and sail_cleated: pulled *= 0.8
	var engaged = sail_engaged()
	# a sail nobody holds flogs and gives no pull, only a little drag against the way the car goes
	var force = pulled if engaged else -0.05 * 0.5 * 1.2 * area * forward_speed * absf(forward_speed)
	# a gust the hand cannot hold tears the sheet away; the cleat gives way to a harder pull
	var limit = (SAIL_GRIP_N if sail_held else SAIL_CLEAT_N) * float(gadgets.get("sail_hold_multiplier", 1.0)) * (0.7 if spinnaker else 1.0) * wear().factor("sail", "rig")
	if engaged and absf(pulled) > limit:
		sail_over += dt
		if sail_over > (0.8 if sail_held else 0.4):
			sail_held = false
			sail_cleated = false
			sail_over = 0.0
			events.append("land")
			if wear_rules and not creative():
				var over = clampf((absf(pulled) - limit) / maxf(1.0, limit), 0.0, 1.0)
				wear().damage("sail", "rigging", 0.05 + 0.1 * over, "порыв сорвал шкот")
				wear().damage("sail", "sail", 0.03 + 0.06 * over, "порыв сорвал шкот")
	else:
		sail_over = maxf(0.0, sail_over - dt)
	sail_info = {"wind": w, "apparent": apparent, "beta": beta, "quality": quality, "force": force, "pulled": pulled, "engaged": sail_engaged(), "held": sail_held, "cleated": sail_cleated, "trim": sail_trim, "lift": sail_lift, "side": sail_side, "strain": clampf(sail_over / (0.8 if sail_held else 0.4), 0.0, 1.0), "gust": wind.gust_ahead(float(state.s), float(state.stats.seconds))}
	return force * float(int(state.direction))

# --- Pole truck (N12): the controls only aim, drop, lift and lean on a real pole ---
func pole_ground_at(s: float) -> Dictionary:
	pole.build(int(route.seed_value), float(route.length_m), route.station_s)
	return pole.ground_at(s)

func pole_aim(place_m: float) -> void:
	if vehicle_id() == "pole": pole.set_aim(place_m)

func pole_plant() -> bool:
	if vehicle_id() != "pole": return false
	if state.phase == "loading" and not try_depart_by_driving(): return false
	if state.phase != "route": return false
	pole.build(int(route.seed_value), float(route.length_m), route.station_s)
	return pole.plant(float(state.s), int(state.direction))

func pole_lift() -> void:
	if vehicle_id() == "pole": pole.lift(float(state.s), int(state.direction))

func pole_effort(value: float) -> void:
	if vehicle_id() == "pole": pole.set_effort(value)

# --- B5.4: the grip of the wheels. The brake holds only as much as the wheels grip the rail (the same number
# as the drive): a harder pull locks the wheels, which then slide and hold less. In rain it grips less.
const BRAKE_MU = 0.35
const SLIDE_RATIO = 0.7
var wheel_lock = false   # the wheels are locked and slide (the brake is pulled harder than the rail holds)
var wheel_slip = false   # the driving wheels spin (more pull than the rail holds)

# The most that all the wheels of the train can brake (the brake works through the whole train).
func brake_cap(total: float = -1.0) -> float:
	if total < 0.0: total = train_mass()
	return BRAKE_MU * total * G * cos(route.slope(float(state.s))) * grip_factor()

func brake_total() -> float:
	var sum = 0.0
	for id in body_ids(): sum += float(object_stats(id).brake)
	return sum

# What the lever asks for, before the grip decides (the pads weaken a little in the rain).
func brake_demand(max_brake: float) -> float:
	return float(state.brake) * max_brake * (1.0 - 0.2 * rain_effect())

# What the brake really does this moment: up to the grip in full, past it the wheels lock and slide.
func braking_force(max_brake: float, total: float) -> float:
	var demand = brake_demand(max_brake)
	var cap = brake_cap(total)
	var speed = absf(float(state.v))
	if wheel_lock:
		if demand < 0.8 * cap or speed < 0.5: wheel_lock = false
	elif demand > cap and speed > 1.0:
		wheel_lock = true
		events.append("skid")
		if junk_rules and not creative(): casino().trip_skid()
		wear_skid(speed)
	if wheel_lock: return minf(demand, cap * SLIDE_RATIO)
	return minf(demand, cap)

# The lever position (0..1) that brakes as hard as possible without locking the wheels.
func brake_safe() -> float:
	var full = brake_total() * (1.0 - 0.2 * rain_effect())
	if full <= 0.0: return 1.0
	return clampf(0.95 * brake_cap() / full, 0.0, 1.0)

# How far the train rolls with the best braking from a speed (m/s, the current one by default), on this grade.
func stopping_distance(speed: float = -1.0) -> float:
	if speed < 0.0: speed = absf(float(state.v))
	var total = train_mass()
	var force = minf(brake_total() * (1.0 - 0.2 * rain_effect()), 0.95 * brake_cap(total)) + total * 0.004 * G   # with a little margin before the wheels lock
	var along = G * sin(route.slope(float(state.s))) * float(state.direction) * signf(float(state.v))   # going uphill helps to stop
	var decel = force / maxf(1.0, total) + along
	if decel < 0.2: return 9999.0
	return speed * speed / (2.0 * decel)

func physics_step(dt: float) -> void:
	if state.is_empty() or dt<=0:
		return
	last_movement = 0.0
	update_station_dwell(dt)
	if state.phase == "depot" or state.phase == "loading":
		# The boiler can be prepared while the wagons are being loaded.
		if state.phase == "loading" and vehicle_id() == "steam": steam_step(dt, state.fleet_by_id.steam)
		if state.phase == "loading" and drive_command() and try_depart_by_driving():
			pass
		else:
			reset_input()
			pole.reset()
			if live.n != 0: live.reset()
			if vehicle_id() == "sail": sail_trim = 0.0
			return
	state.stats.seconds += dt
	shift_cut = maxf(0.0, shift_cut - dt)
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
	var brake_applied = braking_force(max_brake, total)
	wheel_slip = false
	var stats = object_stats(vehicle_id())
	var drive = 0.0
	regen_kw = 0.0
	var hand_result: Dictionary = {}
	if vehicle_id() == "handcar":
		hand_result=hand_drive.step(handcar,float(state.v),total,int(state.direction),0.21,dt,grade,rolling+float(vehicle_base().get("drag",0.0))*float(state.v)*float(state.v),brake_applied,minf(220.0,float(stats.power)),float(effects(vehicle_id()).get("work_multiplier",1.0))*wear().factor("handcar","power"),handcar_potential_at)
		pump_angle=handcar.pose().angle
		pump_work=maxf(0,float(hand_result.hand_work))
		output_power=pump_work/dt
	else:
		var fleet = state.fleet_by_id[vehicle_id()]
		if vehicle_id() == "locomotive" or vehicle_id() == "pneumatic":
			# Electric and pneumatic drives have no gearbox or start switch: traction is always
			# engaged and only the battery charge or the air pressure limits it.
			state.gear = 1
			state.engine = float(fleet.fuel) > 0
		thermal_step(dt, fleet)
		burst_step(dt)
		if vehicle_id() == "steam": drive = steam_step(dt, fleet)
		elif vehicle_id() == "sail":
			drive = sail_step(dt)
		elif vehicle_id() == "pole":
			pole.build(int(route.seed_value), float(route.length_m), route.station_s)
			pole.wet = rain_effect()
			pole.force_scale = float(effects("pole").get("pole_force_multiplier", 1.0)) * wear().factor("pole", "power")
			pole.grip_scale = float(effects("pole").get("pole_grip_multiplier", 1.0)) * wear().factor("pole", "rig")
			drive = pole.step(dt, float(state.s), float(state.v), int(state.direction))
		elif fleet.fuel <= 0: state.engine = false
		if vehicle_id() != "steam" and vehicle_id() != "zeppelin" and state.engine and fleet.fuel > 0:
			if fleet.fuel <= 0:
				state.engine = false
			if int(state.gear) > 0:
				var gear = int(state.gear) - 1
				var reverse_gear = vehicle_id() == "motorcar" and gear == 5
				if reverse_gear: gear = 0
				if vehicle_id() == "motorcar" and not reverse_gear: petrol_stall_check(gear, stats, dt)
				var traction = float(stats.traction[gear]) * maxf(0, 1 - pow(absf(float(state.v)) / float(stats.speeds[gear]), 2)) * charge_traction_factor() * petrol_lug(gear, stats) * pneumatic_factor() * thermal_factor()
				traction = minf(traction, power_limit_force(charge_traction_factor())) * burst_factor()
				if shift_cut > 0.0: traction = 0.0
				var adhesion = 0.35 * float(stats.mass) * G * cos(route.slope(float(state.s))) * grip_factor()
				wheel_slip = float(state.throttle) * traction > adhesion * 1.02 and absf(float(state.v)) < 12.0
				drive = float(drive_direction()) * (-1.0 if reverse_gear else 1.0) * float(state.throttle) * minf(traction, adhesion)
	if wear_rules and not creative() and wear().cannot_drive(vehicle_id()): drive = 0.0   # a dead node or a stop on the road: the machine does not pull
	var drag = drag_coefficient()
	var brake = brake_applied + engine_brake_force()
	if air_fly and not human_powered():
		# The wheels are off the rail: no drive, no brake, no rolling friction.
		drive = 0.0
		brake = 0.0
		rolling = 0.0
	var old_v = float(state.v)
	var new_v = old_v
	var movement=0.0
	if vehicle_id()=="zeppelin":
		new_v = zeppelin_step(dt, state.fleet_by_id.zeppelin, old_v)
		movement = (old_v + new_v) * 0.5 * dt
		if zep.crashed:
			zeppelin_crashed()
			return
	elif vehicle_id()=="handcar":
		new_v=hand_result.velocity
		movement=hand_result.delta_s
	else:
		var external = drive + grade
		var resist = rolling + brake + drag * old_v * old_v
		if absf(old_v) < 0.03 and absf(external) <= rolling + brake:
			new_v = 0.0
		else:
			var movement_sign = signf(old_v) if absf(old_v) >= 0.03 else signf(external)
			new_v = old_v + (external - movement_sign * resist) / total * dt
			if signf(new_v) != movement_sign and absf(external) <= rolling + brake: new_v = 0.0
		movement=(old_v+new_v)*0.5*dt
	if vehicle_id()!="handcar" and vehicle_id()!="zeppelin":
		# Settle energy against the distance actually integrated, including
		# the first accelerating step and the last stopping step.
		var shaft_work=absf(drive*movement)
		var kinetic_change=0.5*total*(new_v*new_v-old_v*old_v)
		var dissipated=maxf(0,drive*movement+grade*movement-kinetic_change)
		var resist=rolling+brake+drag*old_v*old_v
		var brake_work=minf(brake*absf(movement),dissipated*brake/maxf(0.000001,resist))
		var fleet=state.fleet_by_id[vehicle_id()]
		var before=float(fleet.fuel)
		var used=0.0
		var recovered=0.0
		if vehicle_id()=="locomotive":
			# No idle draw: an electric drive without a start switch must not
			# bleed the battery while parked.
			used=shaft_work/0.82
			recovered=float(vehicle_base().get("regen_fraction",0.25))*brake_work if float(state.throttle)<0.01 else 0.0
			recovered=minf(recovered,maxf(0,(float(stats.tank)-before)*3600000.0+used))
			fleet.fuel=clampf(before+(recovered-used)/3600000.0,0,float(stats.tank))
			regen_kw=recovered/dt/1000.0
		elif vehicle_id()=="steam":
			# Coal and water are spent by the boiler itself (steam_step); this is
			# only the shaft work for reports.
			used=shaft_work/0.07
		elif vehicle_id()=="pole" or vehicle_id()=="sail":
			# A person or the wind: the work only goes to the report, nothing is spent.
			used=shaft_work
		elif vehicle_id()=="pneumatic":
			# Air is spent by the work on the shaft; the pipes frost over while it runs.
			used=shaft_work/0.85 * (HEATING_AIR if bool(fleet.get("heating", false)) else 1.0)   # the heating of the pipes costs 15% more air
			fleet.fuel=maxf(0.0,before-used/air_joule_per_bar())
			update_frost(fleet,dt)
		else:
			# Game calibration: petrol 34 MJ/l burnt four times faster (N10: a tank lasts about one
			# round trip to the far station). Efficiency peaks mid-range and
			# falls when the engine lugs or screams; friction burn grows with rpm.
			var rpm_fraction=engine_rpm_fraction()
			var cfg_engine=vehicle_base().engine
			var efficiency=clampf(0.22-0.30*pow(rpm_fraction-float(cfg_engine.best_fraction),2),0.10,0.22)
			used=shaft_work/efficiency+(10200.0*(1.0+0.8*rpm_fraction)*dt if state.engine else 0.0)
			fleet.fuel=maxf(0,before-used/8500000.0)
		motor_energy={"shaft_work_j":shaft_work,"brake_work_j":brake_work,"used_j":used,"recovered_j":recovered,"delta_store":float(fleet.fuel)-before}
		if vehicle_id()!="steam" and fleet.fuel<=0: state.engine=false
	acceleration=(new_v-old_v)/dt
	state.v=new_v
	last_movement = movement
	state.s+=movement
	if vehicle_id() != "zeppelin": update_air(dt, float(state.s) - movement)   # the zeppelin has its own flight
	update_auto_hold()
	state.stats.distance += absf(movement)
	if wear_rules and not creative():
		wear().wear_road(absf(movement))
		wear().breakdown_step(dt)
	var travelled = state.fleet_by_id[vehicle_id()]
	travelled.km = float(travelled.get("km", 0.0)) + absf(movement) / 1000.0   # for the wheel, which favours the machine driven most
	rail_distance += absf(movement)
	if junk_rules and not creative() and state.active.has("trip"): casino().trip_tick(absf(movement))
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
	if live_effects: live_step(dt)
	if not state.active.is_empty() and state.active.phase == "return" and station_index() == 0 and stopped():
		settle()

# The couplers, the rocking and the cargo on its straps (live.gd). Only the fragile cargo feels it.
func live_step(dt: float) -> void:
	live.step(self, dt)
	if live.clank > 0.3:
		last_clank = live.clank
		events.append("clank")
		if live.clank > 1.0 and wear_rules and not creative():
			for k in range(1, body_ids().size()): wear().damage(body_ids()[k], "coupler", 0.004 * live.clank, "рывок сцепки")
	for hit in live.hits:
		if str(hit.kind) != "cargo" or float(hit.speed) < 0.35: continue
		last_cargo_hit = float(hit.speed)
		events.append("cargo_hit")
		for item in state.cargo:
			if str(item.id) == str(hit.id) and item.type == "fragile":
				var owner = str(item.slot).split(":")[0]
				item.health = maxf(0.0, float(item.health) - minf(0.5, (float(hit.speed) - 0.35) * 0.12) * float(object_stats(owner).shock))

# The train is not fastened to the rail. On a convex crest the rail falls away under it; when
# v^2 * curvature is more than gravity across the rail, the wheels lift and the train flies a true
# ballistic hop (absolute height under gravity against the rail's height), then lands: a hard
# landing hurts fragile cargo and bounces a little. Concave places only press it down.
func update_air(dt: float, old_s: float) -> void:
	if human_powered(): return
	var s = float(state.s)
	var rail_y = route.sample(s).y
	var rail_dy = (rail_y - route.sample(old_s).y) / dt
	if not air_fly:
		var convex = -(route.slope(s + 1.5) - route.slope(s - 1.5)) / 3.0
		if float(state.v) * float(state.v) * convex - G * cos(route.slope(s)) <= 0.0:
			air_z = 0.0
			return
		air_fly = true
		air_y = rail_y
		air_vy = rail_dy
	air_vy -= G * dt
	air_y += air_vy * dt
	var z = air_y - rail_y
	if z > 0.0:
		air_z = z
		return
	var impact = -(air_vy - rail_dy)
	air_z = 0.0
	air_fly = false
	if impact > 0.4:
		last_landing = impact
		events.append("land")
		landing_impact(impact)
		if live_effects: live.landed(impact)
		if impact > 1.2:
			air_fly = true
			air_y = rail_y
			air_vy = rail_dy + 0.3 * impact

func landing_impact(impact: float) -> void:
	if impact <= 1.0: return
	wear_landing(impact)
	for item in state.cargo:
		if item.type == "fragile" and item.slot != "" and not item.delivered:
			var owner = str(item.slot).split(":")[0]
			item.health = maxf(0, float(item.health) - minf(1.0, (impact - 1.0) * 0.25) * float(object_stats(owner).shock))

func buffer_impact(speed: float) -> bool:
	if speed<=BUFFER_SAFE_SPEED: return false
	wear_buffer(speed)
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
	casino().migrate()
	pump_angle = float(state.get("pump_angle", 0))
	handcar = HandcarMechanism.new()
	hand_drive = HandcarDrive.new()
	pole = Pole.new()
	air_z = 0.0
	air_fly = false
	if state.has("handcar_phase"):
		handcar.set_phase(float(state.handcar_phase))
	else:
		handcar.seek_rocker(lerpf(float(handcar.limits.minimum.angle),float(handcar.limits.maximum.angle),clampf((pump_angle+deg_to_rad(28))/deg_to_rad(56),0,1)))
	state.reverser = int(state.get("reverser", 1))
	# Saves from before the four-gear box used Н/1/2; the old high gear is now 4.
	var box = int(state.get("gearbox", 0))
	if box != 5:
		if vehicle_id() == "motorcar":
			# the four-gear box had reverse as 5, now it is 6; the three-gear one had N/1/2 only
			if box == 4: state.gear = 6 if int(state.gear) == 5 else int(state.gear)
			else: state.gear = {0: 0, 1: 1, 2: 4}.get(int(state.gear), 0)
		state.gearbox = 5
	migrate_boiler()
	migrate_deck_cargo()
	drop_temporary_wagon()
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

# Since 3.2 petrol and electric machines have no deck places. Cargo an older
# save keeps on such a deck moves to a free wagon place, or into the
# temporary wagon WT that exists only until that cargo is delivered.
func migrate_deck_cargo() -> void:
	for item in state.cargo:
		if item.delivered or str(item.slot) == "": continue
		var parts = str(item.slot).split(":")
		if parts[0].begins_with("W") or int(parts[1]) < int(object_stats(parts[0]).slots): continue
		var target = free_wagon_slot()
		if target == "":
			if not state.wagons_by_id.has(TEMP_WAGON):
				state.wagons_by_id[TEMP_WAGON] = {"levels": {}, "temporary": true}
				state.consist_ids.append(TEMP_WAGON)
			target = free_wagon_slot()
		item.slot = target

func free_wagon_slot() -> String:
	for slot in slots():
		if str(slot.owner).begins_with("W") and not slot_occupied(slot.key): return slot.key
	return ""

func drop_temporary_wagon() -> void:
	if not state.wagons_by_id.has(TEMP_WAGON): return
	for item in state.cargo:
		if not item.delivered: return
	state.wagons_by_id.erase(TEMP_WAGON)
	state.consist_ids.erase(TEMP_WAGON)
	for id in state.fleet_by_id: state.fleet_by_id[id].get("consist", []).erase(TEMP_WAGON)

func validate_save(saved: Dictionary) -> bool:
	var required = ["version", "route", "fleet_by_id", "wagons_by_id", "selected_vehicle_id", "consist_ids", "money", "chapter", "s", "v", "direction", "brake", "throttle", "gear", "engine", "phase", "cargo", "active", "paid_ids", "completed_ids", "stats", "finale", "visited_stations", "offer_serial", "tutorial"]
	for key in required:
		if not saved.has(key):
			return false
	if not numeric(saved.version) or int(saved.version) != 2 or not saved.route is Dictionary or not saved.fleet_by_id is Dictionary or not saved.wagons_by_id is Dictionary or not saved.cargo is Array:
		return false
	if saved.has("mode") and str(saved.mode) not in ["career", "creative"]: return false
	if not saved.active is Dictionary or not saved.stats is Dictionary or not saved.consist_ids is Array or not saved.paid_ids is Array or not saved.completed_ids is Array or not saved.visited_stations is Array:
		return false
	for key in ["money", "chapter", "s", "v", "direction", "brake", "throttle", "gear", "offer_serial"]:
		if not numeric(saved[key]): return false
	if saved.money < 0 or saved.chapter < 0 or saved.chapter > 10 or saved.brake < 0 or saved.brake > 1 or saved.throttle < 0 or saved.throttle > 1 or saved.gear < 0 or saved.gear > 6:
		return false
	if not saved.route.has_all(["points", "seed", "generator_version"]) or not saved.route.points is Array or saved.route.points.size() < 1700:
		return false
	if not saved.route.points[-1] is Array or saved.route.points[-1].size() != 3 or not numeric(saved.route.points[-1][2]): return false
	if absf(float(saved.v)) > 100 or float(saved.s) < -40 or float(saved.s) > float(saved.route.points[-1][2]) + 20.0:
		return false
	if not numeric(saved.route.generator_version) or int(saved.route.generator_version) not in [1, 2]: return false
	if int(saved.route.generator_version) >= 2:
		if not saved.route.get("station_x") is Array or saved.route.station_x.size() != data.stations.size(): return false
		for x in saved.route.station_x:
			if not numeric(x): return false
	var previous_s = -INF
	for point in saved.route.points:
		if not point is Array or point.size() != 3: return false
		for coordinate in point:
			if not numeric(coordinate): return false
		if float(point[2]) <= previous_s: return false
		previous_s = float(point[2])
	for group in [saved.fleet_by_id, saved.wagons_by_id]:
		for id in group:
			if id not in VEHICLE_IDS and id not in HIDDEN_VEHICLE_IDS and id not in WAGON_IDS and id != TEMP_WAGON: return false
			var object = group[id]
			if not object is Dictionary or not object.has("levels") or not object.levels is Dictionary: return false
			if (id in VEHICLE_IDS or id in HIDDEN_VEHICLE_IDS) and (not object.has("fuel") or not numeric(object.fuel) or object.fuel < 0): return false
			if object.has("water") and (not numeric(object.water) or object.water < 0): return false
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
	if saved.consist_ids.size() > max_wagons(str(saved.selected_vehicle_id)) + (1 if TEMP_WAGON in saved.consist_ids else 0): return false
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
