extends RefCounted
# В6.6б (заготовка, 06.11.2026): ходовая модель реактивного поезда по предложению docs/JET_PROPOSAL_RU.md. Чистая физика без картинки и ввода,
# в игру не подключена (машины в гараже нет): числа лежат в DEFAULTS и меняются одним местом, когда владелец решит.
#
# Рычаги: газ (цель тяги), крышка пуска и пуск, кольцо парашюта, колодки, форсаж (гаджет). Единицы: метры, секунды, ньютоны, литры.

const G = 9.81

const DEFAULTS = {
	"mass_kg": 1500.0, "thrust_max_n": 9000.0, "rho": 1.225, "cda_m2": 4.75, "rolling": 0.004,
	"spool_up_nps": 2500.0, "spool_down_nps": 6000.0, "start_delay_s": 3.0,
	"sfc_kg_per_ns": 0.00012, "kerosene_kg_per_l": 0.8, "fuel_l": 450.0,
	"chute_cda_m2": 6.0, "chute_deploy_s": 1.2, "chutes_per_trip": 1,
	"pad_brake_n": 6000.0,
	"afterburner_thrust": 4.0, "afterburner_fuel": 5.0, "afterburner_s": 3.0, "afterburner_charges": 2,
	"heat": 0.12, "cooling": 0.05, "cooling_per_mps": 0.004, "ambient": 0.1,
}

var cfg: Dictionary = DEFAULTS.duplicate()

# --- levers
var throttle = 0.0          # 0..1
var cover_open = false      # the cover of the start button
var pad_brake = 0.0         # 0..1
var afterburner_gadget = false   # the gadget is installed (it comes from a card)

# --- state
var v = 0.0                 # speed along the rail, m/s
var thrust = 0.0
var started = false
var start_timer = 0.0       # seconds since the start; the turbine gives thrust after start_delay_s
var fuel = 450.0
var chute = 0.0             # 0 packed .. 1 fully open
var chute_pulled = false
var chutes_left = 1
var afterburner_time = 0.0
var afterburner_charges = 2
var temp = 0.1
var events: Array = []      # "start", "chute", "afterburner", "empty", "overheat"

func _init(config: Dictionary = {}) -> void:
	for key in config: cfg[key] = config[key]
	reset()

func c(key: String) -> float:
	return float(cfg[key])

func reset(fuel_liters: float = -1.0) -> void:
	v = 0.0
	thrust = 0.0
	started = false
	start_timer = 0.0
	fuel = c("fuel_l") if fuel_liters < 0.0 else fuel_liters
	chute = 0.0
	chute_pulled = false
	chutes_left = int(c("chutes_per_trip"))
	afterburner_time = 0.0
	afterburner_charges = int(c("afterburner_charges"))
	temp = c("ambient")
	throttle = 0.0
	cover_open = false
	pad_brake = 0.0
	events.clear()

# the packing of the chute and the refill of the afterburner at the depot
func new_trip() -> void:
	chute = 0.0
	chute_pulled = false
	chutes_left = int(c("chutes_per_trip"))
	afterburner_charges = int(c("afterburner_charges"))
	afterburner_time = 0.0

# --- the levers
func set_throttle(value: float) -> void: throttle = clampf(value, 0.0, 1.0)
func set_pad_brake(value: float) -> void: pad_brake = clampf(value, 0.0, 1.0)
func open_cover(on: bool) -> void:
	cover_open = on

# the start works only under the open cover and with fuel
func start() -> bool:
	if started or not cover_open or fuel <= 0.0: return false
	started = true
	start_timer = 0.0
	events.append("start")
	return true

func shut_down() -> void:
	started = false
	start_timer = 0.0

func pull_chute() -> bool:
	if chutes_left <= 0: return false
	chutes_left -= 1
	chute_pulled = true
	events.append("chute")
	return true

func release_chute() -> void:
	chute_pulled = false

func fire_afterburner() -> bool:
	if not afterburner_gadget or afterburner_charges <= 0 or afterburner_time > 0.0 or not started: return false
	afterburner_charges -= 1
	afterburner_time = c("afterburner_s")
	events.append("afterburner")
	return true

# --- the numbers
func weight() -> float:
	return c("mass_kg") * G

func drag_force(v_air: float) -> float:
	var area = c("cda_m2") + c("chute_cda_m2") * chute
	return 0.5 * c("rho") * v_air * absf(v_air) * area

# the thrust the turbine tries to reach now
func target_thrust() -> float:
	if not started or start_timer < c("start_delay_s") or fuel <= 0.0: return 0.0
	var value = throttle * c("thrust_max_n")
	if afterburner_time > 0.0: value *= c("afterburner_thrust")
	return value

# the burn in litres per second at the thrust now (the afterburner burns more at the same lever)
func fuel_rate() -> float:
	var base = c("sfc_kg_per_ns") * thrust / c("kerosene_kg_per_l")
	if afterburner_time > 0.0: base *= c("afterburner_fuel") / c("afterburner_thrust")
	return base

# the g-load for the instrument: the acceleration along the rail over g
func g_load(acceleration: float) -> float:
	return acceleration / G

# --- one step; slope in radians (+ uphill), wind along the rail in m/s (+ tail wind)
func step(dt: float, slope: float = 0.0, wind_along: float = 0.0) -> void:
	events.clear()
	if dt <= 0.0: return
	if started: start_timer += dt
	if afterburner_time > 0.0: afterburner_time = maxf(0.0, afterburner_time - dt)
	# the chute opens over a second or so, as long as the ring is held
	chute = move_toward(chute, 1.0 if chute_pulled else 0.0, dt / c("chute_deploy_s"))
	var wanted = target_thrust()
	var rate = c("spool_up_nps") if wanted > thrust else c("spool_down_nps")
	if afterburner_time > 0.0 and wanted > thrust: rate *= c("afterburner_thrust")   # the afterburner kicks in at once
	thrust = move_toward(thrust, wanted, rate * dt)
	if not started: thrust = move_toward(thrust, 0.0, c("spool_down_nps") * dt)
	var burn = fuel_rate() * dt
	if fuel > 0.0 and burn > 0.0:
		fuel = maxf(0.0, fuel - burn)
		if fuel <= 0.0: events.append("empty")
	# the heat: a full thrust standing still heats the turbine, the air over it cools it
	var v_air = v - wind_along
	temp = clampf(temp + (c("heat") * pow(thrust / c("thrust_max_n"), 2.0) - (c("cooling") + c("cooling_per_mps") * absf(v_air)) * (temp - c("ambient"))) * dt, c("ambient"), 1.2)
	if temp >= 1.0 and started:
		shut_down()
		events.append("overheat")
	var rolling = c("rolling") * weight() * cos(slope) * signf(v) if absf(v) > 0.05 else 0.0
	var pads = pad_brake * c("pad_brake_n") * signf(v) if absf(v) > 0.05 else 0.0
	var force = thrust - drag_force(v_air) * signf(v_air) - weight() * sin(slope) - rolling - pads
	var new_v = v + force / c("mass_kg") * dt
	# the brakes and the rolling resistance only stop, they never push backwards
	if v > 0.0 and new_v < 0.0 and (pads + rolling) > 0.0: new_v = 0.0
	v = new_v

func status() -> Dictionary:
	return {"speed": v, "thrust": thrust, "fuel": fuel, "temp": temp, "chute": chute, "started": started, "chutes_left": chutes_left,
		"afterburner_left": afterburner_charges, "afterburner_on": afterburner_time > 0.0}
