extends RefCounted
# В6.5, шаг 1: ходовая модель рельсового цеппелина (docs/ZEPPELIN_PROPOSAL_RU.md). Чистая физика без картинки и без ввода:
# рычаги задаются из вне (газ, шаг винта, джойстик, тормоза), step() считает мотор, винт, подъёмную силу, нагрузку на колёса,
# отрыв, полёт, посадку и крушение. Пока не подключена к игре как машина: подключение, вид и кабина следующими шагами.
#
# Единицы: метры, секунды, ньютоны, ватты, градусы только у угла атаки. Скорость v вдоль пути (+ вперёд), ветер вдоль пути
# (+ попутный), поэтому воздушная скорость v_air = v − ветер.

const G = 9.81

# the numbers of the owner's design (all in one place; the data file holds the same under "zeppelin")
const DEFAULTS = {
	"mass_kg": 400.0, "power_w": 40000.0, "prop_efficiency": 0.70, "rho": 1.225,
	"wing_area_m2": 12.0, "cl0": 0.15, "cl_per_deg": 0.075, "alpha_min": -6.0, "alpha_max": 12.0,
	"frontal_cd_area": 0.75, "induced": 0.05,
	"static_thrust_fine_n": 1800.0, "static_thrust_coarse_n": 700.0,
	"opt_speed_fine_mps": 10.0, "opt_speed_coarse_mps": 34.0, "pitch_range_mps": 22.0, "min_pitch_efficiency": 0.35,
	"rpm_idle": 700.0, "rpm_max": 2700.0, "rpm_stall": 450.0, "rpm_rate": 900.0,
	"overspeed_margin_mps": 6.0, "lug_margin_mps": 8.0,
	"rolling": 0.03, "pad_brake_n": 3000.0, "air_brake_area_m2": 4.0,
	"engine_efficiency": 0.25, "joule_per_liter": 8500000.0, "fuel_l": 40.0,
	"heat": 0.04, "cooling_base": 0.03, "cooling_per_mps": 0.003, "ambient": 0.1,
	"redline_wear": 0.20,
	"landing_max_vz": 5.0, "landing_max_alpha": 12.0, "landing_speed_loss": 0.20, "ceiling_m": 30.0,
	# the flight is harder than the run (05.11.2026): the propeller pulls less in the air and less still higher up, a climb costs speed
	"lift_boost": 1.0, "air_thrust": 0.62, "air_thrust_alt": 0.5, "climb_energy": 1.0,
	"crash_penalty_share": 0.5, "crash_penalty_min": 300,
}

var cfg: Dictionary = DEFAULTS.duplicate()

# --- levers (set by the player)
var throttle = 0.0        # 0..1
var pitch = 0.0           # 0 fine .. 1 coarse
var stick = 0.0           # the angle of attack in degrees: the joystick holds where it was left
var pad_brake = 0.0       # 0..1
var air_brake = false

# --- state
var v = 0.0               # speed along the rail, m/s
var rpm = 700.0
var temp = 0.1
var health = 1.0          # 1 sound .. 0 dead (overspeed of the propeller wears the engine)
var fuel = 40.0
var z = 0.0               # height over the rail, m
var vz = 0.0
var airborne = false
var stalled = false
var crashed = false
var crash_reason = ""
var load_fraction = 1.0   # the load on the wheels: 1 standing, 0 when the wing carries the whole weight
var thrust = 0.0
var drag = 0.0
var lift = 0.0
# --- what the picture shows (B6.5): the surfaces follow the levers smoothly, the propeller turns with the revs
var wing_angle = 0.0      # degrees on the picture, negative: the front edge up
var tail_angle = 0.0
var flaps = 0.0           # 0..1, the air brake opens the flaps
var prop_phase = 0.0
var land_vz = 0.0         # how fast the last landing was (for the cargo and the shake)
var events: Array = []    # "stall", "overheat", "takeoff", "land", "crash", "redline"

func _init(config: Dictionary = {}) -> void:
	for key in config: cfg[key] = config[key]
	reset()

func c(key: String) -> float:
	return float(cfg[key])

func reset(fuel_liters: float = -1.0) -> void:
	v = 0.0
	rpm = c("rpm_idle")
	temp = c("ambient")
	health = 1.0
	fuel = c("fuel_l") if fuel_liters < 0.0 else fuel_liters
	z = 0.0
	vz = 0.0
	airborne = false
	stalled = false
	crashed = false
	crash_reason = ""
	load_fraction = 1.0
	thrust = 0.0
	drag = 0.0
	lift = 0.0
	events.clear()
	wing_angle = 0.0   # the picture: the wings lie level again
	tail_angle = 0.0
	flaps = 0.0
	land_vz = 0.0
	throttle = 0.0
	pitch = 0.0
	stick = 0.0
	pad_brake = 0.0
	air_brake = false

# --- the levers
func set_throttle(value: float) -> void: throttle = clampf(value, 0.0, 1.0)
func set_pitch(value: float) -> void: pitch = clampf(value, 0.0, 1.0)
func set_stick(degrees: float) -> void: stick = clampf(degrees, c("alpha_min"), c("alpha_max"))
func set_pad_brake(value: float) -> void: pad_brake = clampf(value, 0.0, 1.0)
func set_air_brake(on: bool) -> void: air_brake = on

# the engine restarts only with the throttle closed
func restart() -> bool:
	if not stalled or throttle > 0.1 or health <= 0.0 or fuel <= 0.0 or temp >= 0.9: return false
	stalled = false
	rpm = c("rpm_idle")
	return true

# --- the numbers of the machine at this moment
func weight() -> float:
	return c("mass_kg") * G

func lift_coefficient(alpha_deg: float) -> float:
	return c("cl0") + c("cl_per_deg") * alpha_deg

func lift_force(v_air: float, alpha_deg: float) -> float:
	return 0.5 * c("rho") * c("wing_area_m2") * lift_coefficient(alpha_deg) * c("lift_boost") * v_air * absf(v_air)

func drag_force(v_air: float, alpha_deg: float) -> float:
	var cl = lift_coefficient(alpha_deg)
	var area = c("frontal_cd_area") + c("induced") * cl * cl * c("wing_area_m2")
	if air_brake: area += c("air_brake_area_m2")
	return 0.5 * c("rho") * v_air * v_air * area

# the speed at which the propeller works best at this pitch: fine 10 m/s .. coarse 34 m/s
func optimal_speed() -> float:
	return lerpf(c("opt_speed_fine_mps"), c("opt_speed_coarse_mps"), pitch)

# how well the pitch fits the speed: 1 at the optimum, falling to the floor away from it
func pitch_efficiency(v_air: float) -> float:
	var off = (v_air - optimal_speed()) / c("pitch_range_mps")
	return clampf(1.0 - off * off, c("min_pitch_efficiency"), 1.0)

# a pitch finer than the speed lets the propeller race (the revs run to the redline and beyond), a pitch coarser than the speed
# makes it heavy (the revs sink, the engine may stall)
func rpm_factor(v_air: float) -> float:
	var mismatch = v_air - optimal_speed()
	if mismatch > c("overspeed_margin_mps"): return 1.0 + clampf((mismatch - c("overspeed_margin_mps")) / 30.0, 0.0, 0.45)
	if mismatch < -c("lug_margin_mps"): return 1.0 - clampf((-mismatch - c("lug_margin_mps")) / 20.0, 0.0, 0.6)
	return 1.0

func target_rpm(v_air: float) -> float:
	if stalled or crashed or fuel <= 0.0: return 0.0
	return (c("rpm_idle") + (c("rpm_max") - c("rpm_idle")) * throttle) * rpm_factor(v_air)

# the power the engine really gives: the throttle, the revs, the health
func engine_power() -> float:
	if stalled or crashed or fuel <= 0.0: return 0.0
	return c("power_w") * pow(throttle, 0.9) * clampf(rpm / 2400.0, 0.0, 1.0) * (0.4 + 0.6 * health)

# the thrust of the propeller: the static limit of the pitch or the power over the speed, times how well the pitch fits
func propeller_thrust(v_air: float) -> float:
	var static_n = lerpf(c("static_thrust_fine_n"), c("static_thrust_coarse_n"), pitch)
	var by_power = c("prop_efficiency") * engine_power() / maxf(v_air, 4.0)
	return minf(static_n * throttle, by_power) * pitch_efficiency(v_air)

# the wheel load, as a fraction of the weight, 1 on the ground standing, 0 when the wing carries everything
func wheel_load(v_air: float, alpha_deg: float, slope: float = 0.0) -> float:
	return clampf(1.0 - lift_force(v_air, alpha_deg) / (weight() * cos(slope)), 0.0, 1.0)

# the airspeed at which the wing carries the whole weight at this angle of attack
func takeoff_speed(alpha_deg: float) -> float:
	var cl = lift_coefficient(alpha_deg)
	if cl <= 0.0: return INF
	return sqrt(2.0 * weight() / (c("rho") * c("wing_area_m2") * cl * c("lift_boost")))

# --- one step of the machine; slope in radians (+ uphill), wind along the rail in m/s (+ tail wind)
# the movable parts: the wing and the tail plane follow the stick, the flaps open with the air brake, the propeller turns
func animate(dt: float) -> void:
	flaps = move_toward(flaps, 1.0 if air_brake else 0.0, dt * 2.5)
	var wing_target = -stick * 1.0 - 38.0 * flaps
	var tail_target = -stick * 0.7
	wing_angle = move_toward(wing_angle, wing_target, 70.0 * dt)
	tail_angle = move_toward(tail_angle, tail_target, 50.0 * dt)
	prop_phase = fposmod(prop_phase + TAU * clampf(rpm, 0.0, 2700.0) / 60.0 * 0.06 * dt, TAU)

func step(dt: float, slope: float = 0.0, wind_along: float = 0.0) -> void:
	events.clear()
	animate(dt)
	if crashed or dt <= 0.0: return
	var v_air = v - wind_along
	# the revs follow the target
	var target = target_rpm(v_air)
	rpm = move_toward(rpm, target, c("rpm_rate") * dt)
	if not stalled and throttle > 0.05 and rpm < c("rpm_stall") and fuel > 0.0:
		stalled = true
		events.append("stall")
	if rpm > c("rpm_max"):
		health = maxf(0.0, health - c("redline_wear") * (rpm - c("rpm_max")) / c("rpm_max") * dt)
		if events.find("redline") < 0: events.append("redline")
	# the heat of the engine: the load and the revs heat it, the air over it cools it
	var heat = c("heat") * throttle * pow(rpm / c("rpm_max"), 2.0)
	var cooling = (c("cooling_base") + c("cooling_per_mps") * absf(v_air)) * (temp - c("ambient"))
	temp = clampf(temp + (heat - cooling) * dt, c("ambient"), 1.2)
	if temp >= 1.0 and not stalled:
		stalled = true
		events.append("overheat")
	# the fuel: the work of the engine
	var power = engine_power()
	fuel = maxf(0.0, fuel - power * dt / c("engine_efficiency") / c("joule_per_liter"))
	# the forces along the rail
	lift = lift_force(v_air, stick)
	thrust = propeller_thrust(v_air) if power > 0.0 else 0.0
	if airborne: thrust *= c("air_thrust") * (1.0 - c("air_thrust_alt") * clampf(z / c("ceiling_m"), 0.0, 1.0))
	drag = drag_force(v_air, stick)
	var normal_force = maxf(0.0, weight() * cos(slope) - lift)
	load_fraction = clampf(normal_force / maxf(1.0, weight() * cos(slope)), 0.0, 1.0)
	if not airborne:
		var rolling = c("rolling") * normal_force * signf(v) if absf(v) > 0.05 else 0.0
		var pads = pad_brake * c("pad_brake_n") * load_fraction * signf(v) if absf(v) > 0.05 else 0.0
		var along_slope = -weight() * sin(slope)
		var force = thrust - drag * signf(v_air) + along_slope - rolling - pads
		var new_v = v + force / c("mass_kg") * dt
		# the brakes and the rolling resistance only stop, they never push backwards
		if v > 0.0 and new_v < 0.0 and (pads + rolling) > 0.0 and absf(thrust) < pads + rolling: new_v = 0.0
		v = new_v
		z = 0.0
		vz = 0.0
		# the wing lifts the whole weight: the wheels leave the rail
		if lift > weight() * cos(slope) and v > 1.0:
			airborne = true
			vz = 0.3
			events.append("takeoff")
	else:
		# the flight: the vertical balance of the lift and the weight, the speed along the way follows the thrust and the drag
		var vertical = (lift - weight()) / c("mass_kg") - 0.02 * vz * absf(vz)
		vz += vertical * dt
		z += vz * dt
		var force_air = thrust - drag * signf(v_air) - weight() * sin(slope) * 0.0
		v = maxf(0.0, v + force_air / c("mass_kg") * dt)
		# the energy: a climb is paid with speed, a descent gives it back
		v = maxf(0.0, v - c("climb_energy") * G * vz / maxf(v, 12.0) * dt)
		if z > c("ceiling_m"):
			crash("врезался в кроны: слишком высоко")
			return
		if z <= 0.0:
			z = 0.0
			if absf(vz) <= c("landing_max_vz") and absf(stick) <= c("landing_max_alpha"):
				airborne = false
				v *= 1.0 - c("landing_speed_loss")
				land_vz = absf(vz)
				vz = 0.0
				events.append("land")
			else:
				crash("грубая посадка")
				return
	# an engine without fuel or a dead engine gives no thrust
	if health <= 0.0 and not stalled:
		stalled = true
		events.append("stall")

# The trim (the gadget, 06.11.2026): holds the height at which it was switched on: the stick follows a gentle rule of the height and the vertical speed.
# Returns the stick (degrees) the trim wants; the model moves the real stick towards it.
func trim_stick(hold_z: float) -> float:
	var speed = maxf(absf(v), 14.0)
	var cl_needed = weight() / (0.5 * c("rho") * c("wing_area_m2") * c("lift_boost") * speed * speed)
	var level_alpha = (cl_needed - c("cl0")) / c("cl_per_deg")   # the angle that carries the weight at this speed
	return clampf(level_alpha + (hold_z - z) * 0.5 - vz * 1.0, -2.0, c("alpha_max"))

func crash(reason: String) -> void:
	crashed = true
	crash_reason = reason
	airborne = false
	v = 0.0
	events.append("crash")

# the penalty of a crash: half of the money (the share is in the data), not less than the minimum, never more than the money
func crash_penalty(money: int) -> int:
	return mini(money, maxi(int(c("crash_penalty_min")), int(round(float(money) * c("crash_penalty_share")))))

# the numbers for the instruments
func status() -> Dictionary:
	return {"airspeed": v, "rpm": rpm, "temp": temp, "health": health, "fuel": fuel, "z": z, "wheel_load": load_fraction,
		"thrust": thrust, "drag": drag, "lift": lift, "optimal_speed": optimal_speed(), "pitch_efficiency": pitch_efficiency(v),
		"airborne": airborne, "stalled": stalled, "crashed": crashed}
