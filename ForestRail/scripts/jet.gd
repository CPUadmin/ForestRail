extends RefCounted
# В6.6б (заготовка, 06.11.2026): ходовая модель реактивного (ракетного) поезда по docs/JET_PROPOSAL_RU.md с решениями владельца того же дня:
# дорого, самый мощный и тянет тяжёлый состав, парашют одноразовый (гаджет даёт второй: выпустить один или оба сразу),
# запуск как у ракеты: крышка, ПРЕДОХРАНИТЕЛИ (их положения как тайные коды), обратный отсчёт, зажигание, дальше мощность регулируется.
# Чистая физика без картинки и ввода, в игру не подключена (машины в гараже нет): числа лежат в DEFAULTS и CODES.
#
# Рычаги: газ, крышка, четыре предохранителя, пуск, кольцо парашюта, колодки, форсаж (гаджет). Единицы: метры, секунды, ньютоны, литры.

const G = 9.81

const DEFAULTS = {
	"mass_kg": 1500.0, "thrust_max_n": 12000.0, "rho": 1.225, "cda_m2": 6.2, "rolling": 0.004,
	"wagon_mass_kg": 900.0, "wagon_cda_m2": 0.6, "max_wagons": 4,
	"spool_up_nps": 3000.0, "spool_down_nps": 7000.0, "countdown_s": 10.0,
	"sfc_kg_per_ns": 0.00012, "kerosene_kg_per_l": 0.8, "fuel_l": 600.0,
	"chute_cda_m2": 6.0, "chute_deploy_s": 1.2, "chutes_per_trip": 1, "chutes_with_gadget": 2, "chute_cut_speed_mps": 0.6,
	"pad_brake_n": 6000.0,
	"afterburner_thrust": 4.0, "afterburner_fuel": 5.0, "afterburner_s": 3.0, "afterburner_charges": 2,
	"heat": 0.12, "cooling": 0.05, "cooling_per_mps": 0.004, "ambient": 0.1,
}

# The fuses (the owner, 06.11.2026, the final version): to start, all four toggles must be on; the ORDER in which they are switched on chooses
# one of three official modes. A secret: if the first thing done is to switch a toggle on and at once off again (a blink), the engine starts with
# only THREE toggles on, and which toggle is left off chooses one of two secret modes. Every mode is a rule in data/jet_modes.json (add, change, delete
# there, see docs/JET_CODES_RU.md); this file only reads the rules. In the game none of it is shown (Mikhalych only hints).
const MODES_PATH = "res://data/jet_modes.json"
const PLAIN = {"name": "Обычный", "thrust": 1.0, "fuel": 1.0, "countdown": 10.0}

var cfg: Dictionary = DEFAULTS.duplicate()
var modes_data: Dictionary = {}   # the rules of the modes (data/jet_modes.json)

# --- levers
var throttle = 0.0          # 0..1
var cover_open = false      # the cover of the start button
var fuses = [false, false, false, false]   # the four safety fuses
var order: Array = []   # the order in which the toggles were switched on (indices 0..3); the code of the start
var history: Array = []   # every flip since the last reset: +n a toggle on, -n off (n from 1)
var pad_brake = 0.0         # 0..1
var afterburner_gadget = false   # the gadget is installed (it comes from a card)
var double_chute_gadget = false  # the gadget: a second chute

# --- state
var v = 0.0                 # speed along the rail, m/s
var thrust = 0.0
var counting = false        # the countdown is running
var countdown = 0.0         # seconds left
var started = false         # the engine is lit
var fuel = 600.0
var chute = 0.0             # 0 packed .. 1 fully open
var chutes_open = 0         # how many chutes are out (0, 1 or 2)
var chutes_left = 1         # chutes in the pack
var afterburner_time = 0.0
var afterburner_charges = 2
var temp = 0.1
var wagons = 0              # coupled wagons: mass and drag
var wagon_load_kg = 0.0     # the cargo in them
var mass_override = -1.0    # the model sets the real mass of the whole train (the cargo included); negative: count from the wagons
var mode: Dictionary = PLAIN   # the mode that the fuses had when the countdown began
var events: Array = []      # "countdown", "abort", "ignition", "misfire", "chute", "chute_cut", "afterburner", "empty", "overheat"

func _init(config: Dictionary = {}) -> void:
	for key in config: cfg[key] = config[key]
	modes_data = load_modes(str(cfg.get("modes_path", MODES_PATH)))
	reset()

func c(key: String) -> float:
	return float(cfg[key])

func reset(fuel_liters: float = -1.0) -> void:
	v = 0.0
	thrust = 0.0
	counting = false
	countdown = 0.0
	started = false
	fuel = c("fuel_l") if fuel_liters < 0.0 else fuel_liters
	chute = 0.0
	chutes_open = 0
	chutes_left = chutes_total()
	afterburner_time = 0.0
	afterburner_charges = afterburner_total()
	temp = c("ambient")
	throttle = 0.0
	cover_open = false
	fuses = [false, false, false, false]
	order.clear()
	history.clear()
	pad_brake = 0.0
	mode = PLAIN
	events.clear()

func chutes_total() -> int:
	return int(c("chutes_with_gadget")) if double_chute_gadget else int(c("chutes_per_trip"))

func afterburner_total() -> int:
	return int(c("afterburner_charges")) + (int(fuse_code_mode().get("extra_afterburner", 0)) if started or counting else 0)

# the packing of the chutes and the refill of the afterburner at the depot
func new_trip() -> void:
	chute = 0.0
	chutes_open = 0
	chutes_left = chutes_total()
	afterburner_charges = int(c("afterburner_charges"))
	afterburner_time = 0.0
	counting = false
	started = false
	fuses = [false, false, false, false]   # the ritual is done again before every start
	order.clear()

# --- the train: the wagons add weight and drag; the loaded rocket tows a lot
func set_train(count: int, load_kg: float = 0.0) -> void:
	wagons = clampi(count, 0, int(c("max_wagons")))
	wagon_load_kg = maxf(0.0, load_kg)

func total_mass() -> float:
	if mass_override >= 0.0: return mass_override
	return c("mass_kg") + float(wagons) * c("wagon_mass_kg") + wagon_load_kg

func total_cda() -> float:
	return c("cda_m2") + float(wagons) * c("wagon_cda_m2")

# --- the levers
func set_throttle(value: float) -> void: throttle = clampf(value, 0.0, 1.0)
func set_pad_brake(value: float) -> void: pad_brake = clampf(value, 0.0, 1.0)
func open_cover(on: bool) -> void: cover_open = on

# a fuse is flipped by hand; during the countdown that cancels it
func flip_fuse(index: int) -> void:
	if index < 0 or index >= fuses.size() or started: return
	fuses[index] = not fuses[index]
	if fuses[index]:
		order.append(index)
		history.append(index + 1)
	else:
		order.erase(index)
		history.append(-(index + 1))
	if counting:
		counting = false
		countdown = 0.0
		events.append("abort")

func fuse_code() -> String:
	var s = ""
	for index in order: s += str(int(index) + 1)
	return s

# The rules of the modes from the data file (a missing or broken file leaves only the plain mode).
static func load_modes(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"plain": PLAIN, "modes": [], "blink_unlocks_on": 3}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary): return {"plain": PLAIN, "modes": [], "blink_unlocks_on": 3}
	return parsed

# Checks the rules of a data file: returns the list of problems (empty: all right). Used by the test, so that a mistake in the file is found at once.
static func validate_modes(data: Dictionary) -> Array:
	var problems: Array = []
	var seen_ids: Dictionary = {}
	var seen_when: Dictionary = {}
	if not data.has("plain"): problems.append("no plain mode")
	for rule in data.get("modes", []):
		var id = str(rule.get("id", ""))
		if id == "" or seen_ids.has(id): problems.append("a mode without an id or a repeated id: " + id)
		seen_ids[id] = true
		var when = rule.get("when", {})
		if not (when is Dictionary) or when.is_empty(): problems.append("mode %s has no condition" % id)
		if str(when) in seen_when: problems.append("mode %s has the same condition as %s" % [id, seen_when[str(when)]])
		seen_when[str(when)] = id
		if when.has("order"):
			var digits = str(when.order)
			var ok = digits.length() == 4
			for ch in digits:
				if ch not in ["1", "2", "3", "4"] or digits.count(ch) != 1: ok = false
			if not ok: problems.append("mode %s: the order must be the four digits 1 to 4 once each (%s)" % [id, digits])
		if when.has("off"):
			for n in when.off:
				if int(n) < 1 or int(n) > 4: problems.append("mode %s: a toggle number outside 1 to 4" % id)
		for key in ["thrust", "fuel", "countdown"]:
			if rule.has(key) and float(rule[key]) <= 0.0: problems.append("mode %s: %s must be above zero" % [id, key])
		if not str(rule.get("name", "")).length() > 0: problems.append("mode %s has no name" % id)
	return problems

# the toggles that are off now, as numbers 1 to 4
func off_toggles() -> Array:
	var result: Array = []
	for i in range(4):
		if not fuses[i]: result.append(i + 1)
	return result

# does one rule fit the toggles as they stand now?
func rule_fits(rule: Dictionary) -> bool:
	var when = rule.get("when", {})
	if when.has("order") and (fuses_on() != 4 or fuse_code() != str(when.order)): return false
	if when.has("blink") and bool(when.blink) != secret_open(): return false
	if when.has("on_count") and fuses_on() != int(when.on_count): return false
	if when.has("off"):
		var wanted: Array = []
		for n in when.off: wanted.append(int(n))
		wanted.sort()
		if off_toggles() != wanted: return false
	return true

# the mode of the start: the first rule that fits, else the plain one (the numbers the rule does not give are those of the plain mode)
func fuse_code_mode() -> Dictionary:
	var plain: Dictionary = modes_data.get("plain", PLAIN)
	for rule in modes_data.get("modes", []):
		if rule_fits(rule):
			var merged = plain.duplicate()
			for key in rule: merged[key] = rule[key]
			return merged
	return plain

# the secret: the first flip switched a toggle on and the second switched the same toggle off (a blink)
func secret_open() -> bool:
	return history.size() >= 2 and int(history[0]) > 0 and int(history[1]) == -int(history[0])

# every toggle is on: only then the start button opens
func start_unlocked() -> bool:
	if fuses_on() == 4: return true
	return secret_open() and fuses_on() == int(modes_data.get("blink_unlocks_on", 3))

func fuses_on() -> int:
	var n = 0
	for flag in fuses:
		if flag: n += 1
	return n

# the start button opens when the cap is open and every toggle is on: the countdown begins in the mode of the fuses at that moment
func start() -> bool:
	if started or counting or not cover_open or not start_unlocked() or fuel <= 0.0: return false
	mode = fuse_code_mode()
	counting = true
	countdown = float(mode.countdown)
	events.append("countdown")
	return true

func abort_countdown() -> void:
	if counting:
		counting = false
		countdown = 0.0
		events.append("abort")

func shut_down() -> void:
	started = false
	counting = false
	fuses = [false, false, false, false]
	order.clear()
	history.clear()

# one chute (or both with the gadget) goes out; the pulled ones are used for the trip
func pull_chute(count: int = 1) -> bool:
	count = clampi(count, 1, 2)
	if count > chutes_left: return false
	chutes_left -= count
	chutes_open += count
	events.append("chute")
	return true

func fire_afterburner() -> bool:
	if not afterburner_gadget or afterburner_charges <= 0 or afterburner_time > 0.0 or not started: return false
	afterburner_charges -= 1
	afterburner_time = c("afterburner_s")
	events.append("afterburner")
	return true

# --- the numbers
func weight() -> float:
	return total_mass() * G

func drag_force(v_air: float) -> float:
	var area = total_cda() + c("chute_cda_m2") * float(chutes_open) * chute
	return 0.5 * c("rho") * v_air * absf(v_air) * area

func thrust_scale() -> float:
	return float(mode.thrust) if started else 1.0

# the thrust the engine tries to reach now
func target_thrust() -> float:
	if not started or fuel <= 0.0: return 0.0
	var value = throttle * c("thrust_max_n") * thrust_scale()
	if afterburner_time > 0.0: value *= c("afterburner_thrust")
	return value

# the burn in litres per second at the thrust now (the afterburner burns more at the same lever)
func fuel_rate() -> float:
	var base = c("sfc_kg_per_ns") * thrust / c("kerosene_kg_per_l") * (float(mode.fuel) if started else 1.0)
	if afterburner_time > 0.0: base *= c("afterburner_fuel") / c("afterburner_thrust")
	return base

# the g-load for the instrument: the acceleration along the rail over g
func g_load(acceleration: float) -> float:
	return acceleration / G

# --- one step; slope in radians (+ uphill), wind along the rail in m/s (+ tail wind)
func step(dt: float, slope: float = 0.0, wind_along: float = 0.0) -> void:
	events.clear()
	if dt <= 0.0: return
	if counting:
		countdown = maxf(0.0, countdown - dt)
		if countdown <= 0.0:
			counting = false
			if bool(mode.get("misfire", false)):
				fuses = [false, false, false, false]
				order.clear()
				events.append("misfire")   # the fuses were set to a bad position: the engine coughs, the start must be done again
			else:
				started = true
				afterburner_charges = int(c("afterburner_charges")) + int(mode.get("extra_afterburner", 0))
				events.append("ignition")
	if afterburner_time > 0.0: afterburner_time = maxf(0.0, afterburner_time - dt)
	# the chutes open over a second or so
	chute = move_toward(chute, 1.0 if chutes_open > 0 else 0.0, dt / c("chute_deploy_s"))
	var wanted = target_thrust()
	var rate = c("spool_up_nps") if wanted > thrust else c("spool_down_nps")
	if afterburner_time > 0.0 and wanted > thrust: rate *= c("afterburner_thrust")   # the afterburner kicks in at once
	thrust = move_toward(thrust, wanted, rate * dt)
	if not started: thrust = move_toward(thrust, 0.0, c("spool_down_nps") * dt)
	var burn = fuel_rate() * dt
	if fuel > 0.0 and burn > 0.0:
		fuel = maxf(0.0, fuel - burn)
		if fuel <= 0.0: events.append("empty")
	# the heat: a full thrust standing still heats the engine, the air over it cools it
	var v_air = v - wind_along
	temp = clampf(temp + (c("heat") * pow(thrust / c("thrust_max_n"), 2.0) - (c("cooling") + c("cooling_per_mps") * absf(v_air)) * (temp - c("ambient"))) * dt, c("ambient"), 1.2)
	if temp >= 1.0 and started:
		shut_down()
		events.append("overheat")
	var rolling = c("rolling") * weight() * cos(slope) * signf(v) if absf(v) > 0.05 else 0.0
	var pads = pad_brake * c("pad_brake_n") * (1.0 + 0.25 * float(wagons)) * signf(v) if absf(v) > 0.05 else 0.0
	var force = thrust - drag_force(v_air) * signf(v_air) - weight() * sin(slope) - rolling - pads
	var new_v = v + force / total_mass() * dt
	# the brakes and the rolling resistance only stop, they never push backwards
	if v > 0.0 and new_v < 0.0 and (pads + rolling) > 0.0: new_v = 0.0
	v = new_v
	# when the train has stopped the open chutes are cut away and are gone (they were used for this trip)
	if chutes_open > 0 and v < c("chute_cut_speed_mps") and chute > 0.5:
		chutes_open = 0
		chute = 0.0
		events.append("chute_cut")

func status() -> Dictionary:
	return {"speed": v, "thrust": thrust, "fuel": fuel, "temp": temp, "chute": chute, "chutes_open": chutes_open, "started": started, "counting": counting,
		"countdown": countdown, "chutes_left": chutes_left, "afterburner_left": afterburner_charges, "afterburner_on": afterburner_time > 0.0,
		"fuses": fuse_code(), "fuses_on": fuses_on(), "wagons": wagons}
