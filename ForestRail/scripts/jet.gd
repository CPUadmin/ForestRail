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
	"wagon_mass_kg": 900.0, "wagon_cda_m2": 0.6, "max_wagons": 3,
	"spool_up_nps": 3000.0, "spool_down_nps": 7000.0, "countdown_s": 10.0,
	"sfc_kg_per_ns": 0.00012, "kerosene_kg_per_l": 0.8, "fuel_l": 600.0,
	"chute_cda_m2": 6.0, "chute_deploy_s": 1.2, "chutes_per_trip": 1, "chutes_with_gadget": 2, "chute_cut_speed_mps": 0.6,
	"pad_brake_n": 6000.0,
	"afterburner_thrust": 4.0, "afterburner_fuel": 5.0, "afterburner_s": 3.0, "afterburner_charges": 2,
	"heat": 0.12, "cooling": 0.05, "cooling_per_mps": 0.004, "ambient": 0.1,
}

# The secret of the fuses: four toggles, 16 positions. Written as a string of 0 and 1 in the order of the fuses from left to right.
# What a position does is not shown in the game; Mikhalych only hints (the table is the owner's and the players' secret).
# thrust and fuel are multipliers, countdown in seconds, extra_afterburner adds charges, misfire: the ignition fails at the end of the countdown.
const CODES = {
	"0000": {"name": "Обычный", "thrust": 1.0, "fuel": 1.0, "countdown": 10.0},
	"1010": {"name": "Экономный", "thrust": 0.85, "fuel": 0.6, "countdown": 10.0},
	"0101": {"name": "Тяжёлый", "thrust": 1.2, "fuel": 1.3, "countdown": 10.0},
	"1100": {"name": "Быстрый старт", "thrust": 1.0, "fuel": 1.1, "countdown": 5.0},
	"0110": {"name": "Рекордный", "thrust": 1.05, "fuel": 1.5, "countdown": 10.0},
	"1111": {"name": "Всё включено", "thrust": 1.0, "fuel": 1.0, "countdown": 15.0, "extra_afterburner": 1},
	"1001": {"name": "Осечка", "thrust": 1.0, "fuel": 1.0, "countdown": 6.0, "misfire": true},
}
const PLAIN = {"name": "Обычный", "thrust": 1.0, "fuel": 1.0, "countdown": 10.0}

var cfg: Dictionary = DEFAULTS.duplicate()

# --- levers
var throttle = 0.0          # 0..1
var cover_open = false      # the cover of the start button
var fuses = [false, false, false, false]   # the four safety fuses
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
	if counting:
		counting = false
		countdown = 0.0
		events.append("abort")

func fuse_code() -> String:
	var s = ""
	for f in fuses: s += "1" if f else "0"
	return s

func fuse_code_mode() -> Dictionary:
	return CODES.get(fuse_code(), PLAIN)

# the start button under the open cover: the countdown begins in the mode of the fuses at that moment
func start() -> bool:
	if started or counting or not cover_open or fuel <= 0.0: return false
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
		"fuses": fuse_code(), "wagons": wagons}
