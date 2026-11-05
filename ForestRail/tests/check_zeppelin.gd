extends Node
# В6.5, шаг 1: ходовая модель цеппелина (scripts/zeppelin.gd): числа проекта владельца. Взлёт на 130 км/ч, потолок 135 км/ч,
# шаг винта (крупнее скорости: обороты падают и мотор глохнет, мельче: обороты в красную зону и износ), тормоза слабеют
# при разгрузке колёс, мягкая посадка не крушение, грубая посадка и кроны это крушение, штраф 50% монет.
const Zeppelin = preload("res://scripts/zeppelin.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func run_steps(z, seconds: float, dt: float = 1.0 / 60.0, slope: float = 0.0, wind: float = 0.0) -> void:
	for i in range(int(seconds / dt)): z.step(dt, slope, wind)

# a driver who keeps the pitch fitted to the speed, as the player must
func accelerate(z, seconds: float) -> void:
	for i in range(int(seconds * 60.0)):
		z.set_pitch(clampf((z.v + 3.0 - 10.0) / 24.0, 0.0, 1.0))
		z.step(1.0 / 60.0)

# Takes off, holds about 4 m for eight seconds, then comes down with the given stick and throttle. Returns what happened.
func scripted_flight(descent_stick: float, descent_throttle: float) -> String:
	var z = Zeppelin.new()
	z.set_throttle(1.0)
	accelerate(z, 100.0)
	z.set_stick(4.0)
	var seconds = 0.0
	var phase = "climb"
	for i in range(60 * 90):
		seconds += 1.0 / 60.0
		z.set_pitch(clampf((z.v + 3.0 - 10.0) / 24.0, 0.0, 1.0))
		if phase == "climb" and z.z > 4.0: phase = "cruise"
		if phase == "cruise":
			z.set_stick(clampf(3.5 + (4.0 - z.z) * 0.6 - z.vz * 0.8, -2.0, 12.0))
			if seconds > 8.0: phase = "descend"
		if phase == "descend":
			z.set_throttle(descent_throttle)
			z.set_stick(descent_stick)
		z.step(1.0 / 60.0)
		if z.events.has("land"): return "LANDED vz=%.2f" % z.land_vz
		if z.crashed: return "CRASH " + z.crash_reason
	return "still flying"

func run() -> void:
	var z = Zeppelin.new()
	# the takeoff speed of the owner: 130 km/h at +3.5 degrees, the wheels carry nothing there
	var takeoff = z.takeoff_speed(3.5)
	check(absf(takeoff * 3.6 - 130.0) < 2.0, "the takeoff speed at +3.5 degrees is 130 km/h (%.1f)" % (takeoff * 3.6))
	check(z.wheel_load(takeoff, 3.5) < 0.02, "at the takeoff speed the wheels carry nothing (%.3f)" % z.wheel_load(takeoff, 3.5))
	check(z.wheel_load(0.0, 12.0) == 1.0 and z.wheel_load(20.0, 0.0) > 0.7, "standing: the full load; slowly with the nose level: still heavy on the wheels")
	check(z.wheel_load(takeoff * 0.9, 3.5) > 0.15, "below the takeoff speed the nose up does not help")
	# the top speed on the rail: 135 km/h with the pitch kept right, the nose level
	z.reset()
	z.set_throttle(1.0)
	z.set_stick(0.0)
	accelerate(z, 150.0)
	check(z.v * 3.6 > 128.0 and z.v * 3.6 < 142.0, "the top speed on the rail is about 135 km/h (%.1f)" % (z.v * 3.6))
	check(not z.airborne and not z.crashed, "with the nose level the zeppelin stays on the rail")
	check(z.rpm <= z.c("rpm_max") + 1.0 and z.health > 0.99, "with the pitch right the revs stay below the redline and the engine is sound (%d rpm)" % int(z.rpm))
	# the pitch: a coarse pitch at a standstill is heavy: the revs sink, the throttle half closed: the engine stalls
	var heavy = Zeppelin.new()
	heavy.set_pitch(1.0)
	heavy.set_throttle(0.2)
	run_steps(heavy, 4.0)
	check(heavy.stalled, "a coarse pitch at a standstill and a low throttle stall the engine (%d rpm)" % int(heavy.rpm))
	heavy.set_throttle(0.0)
	check(heavy.restart() and not heavy.stalled, "the engine restarts with the throttle closed")
	var weak = Zeppelin.new()
	weak.set_pitch(1.0)
	weak.set_throttle(1.0)
	run_steps(weak, 3.0)
	var fitted = Zeppelin.new()
	fitted.set_pitch(0.0)
	fitted.set_throttle(1.0)
	run_steps(fitted, 3.0)
	check(fitted.thrust > weak.thrust * 3.0, "from a standstill the fine pitch pulls far harder than the coarse one (%.0f against %.0f N)" % [fitted.thrust, weak.thrust])
	# a fine pitch at speed: the propeller races, the revs go over the redline, the engine wears
	var racing = Zeppelin.new()
	racing.set_pitch(0.0)
	racing.set_throttle(1.0)
	for i in range(60 * 6):
		racing.v = 30.0
		racing.step(1.0 / 60.0)
	check(racing.rpm > racing.c("rpm_max") * 1.1 and racing.health < 0.98, "a fine pitch at speed: the revs over the redline (%d) and the engine wears (%.2f)" % [int(racing.rpm), racing.health])
	check(racing.pitch_efficiency(30.0) < 0.5, "and the thrust is small (%.2f of the best)" % racing.pitch_efficiency(30.0))
	# the heat: at a standstill at full throttle the engine overheats, the air over it cools it
	var hot = Zeppelin.new()
	hot.set_pitch(0.0)
	hot.set_throttle(1.0)
	hot.set_pad_brake(1.0)
	run_steps(hot, 90.0)
	check(hot.stalled or hot.temp > 0.95, "full throttle at a standstill overheats the engine (%.2f)" % hot.temp)
	var cool = Zeppelin.new()
	cool.set_throttle(1.0)
	accelerate(cool, 60.0)
	check(cool.temp < 0.9 and not cool.stalled, "running, the air cools it (%.2f)" % cool.temp)
	# the fuel: the work of the engine
	var burn = Zeppelin.new()
	burn.set_throttle(1.0)
	burn.set_pitch(0.0)
	var before = burn.fuel
	run_steps(burn, 30.0)
	check(burn.fuel < before and before - burn.fuel < 3.0, "the engine burns petrol by its work (%.2f l in 30 s)" % (before - burn.fuel))
	# the brakes: the pads weaken when the wing unloads the wheels, the air brake adds drag
	var braked = Zeppelin.new()
	braked.v = 25.0
	braked.set_pad_brake(1.0)
	braked.step(1.0 / 60.0)
	var heavy_brake = 25.0 - braked.v
	var unloaded = Zeppelin.new()
	unloaded.v = 36.0
	unloaded.set_stick(3.4)
	unloaded.set_pad_brake(1.0)
	unloaded.step(1.0 / 60.0)
	check(unloaded.load_fraction < 0.2, "at the takeoff speed the wheels are nearly unloaded (%.2f)" % unloaded.load_fraction)
	check(heavy_brake > 0.0 and (36.0 - unloaded.v) < heavy_brake * 1.2, "the pad brake weakens when the wheels are unloaded")
	var flaps = Zeppelin.new()
	var plain_drag = flaps.drag_force(30.0, 0.0)
	flaps.set_air_brake(true)
	check(flaps.drag_force(30.0, 0.0) > plain_drag * 4.0, "the air brake adds a lot of drag")
	# the takeoff: at the speed of takeoff the nose up lifts the wheels off the rail
	var plane = Zeppelin.new()
	plane.set_throttle(1.0)
	accelerate(plane, 100.0)
	check(plane.v * 3.6 > 125.0 and not plane.airborne, "on the rail at about 130 km/h (%.1f)" % (plane.v * 3.6))
	plane.set_stick(4.0)
	var took_off = false
	for i in range(60 * 3):
		plane.step(1.0 / 60.0)
		if plane.events.has("takeoff"): took_off = true
	check(took_off, "the nose up at 130 km/h: the zeppelin takes off")
	# a careful landing: the nose down, a soft touch: no crash, the speed loses a fifth
	var soft = Zeppelin.new()
	soft.set_throttle(1.0)
	accelerate(soft, 100.0)
	soft.set_stick(3.6)
	var air_time = 0
	while not soft.airborne and air_time < 180:
		soft.step(1.0 / 60.0)
		air_time += 1
	check(soft.airborne and soft.z < 1.0, "just off the rail")
	var speed_before = soft.v
	soft.set_throttle(0.4)
	soft.set_stick(0.0)
	var landed = false
	for i in range(60 * 6):
		soft.step(1.0 / 60.0)
		if soft.events.has("land"): landed = true
	check(landed and not soft.crashed and not soft.airborne, "a careful landing is not a crash: the wheels are back on the rail")
	check(soft.v < speed_before and soft.v > speed_before * 0.5, "the landing takes a fifth of the speed (%.1f of %.1f m/s)" % [soft.v, speed_before])
	# a hard landing from a height: a crash
	var drop = Zeppelin.new()
	drop.set_throttle(1.0)
	accelerate(drop, 100.0)
	drop.set_stick(7.0)
	var steps = 0
	while drop.z < 5.0 and not drop.crashed and steps < 900:
		drop.step(1.0 / 60.0)
		steps += 1
	check(drop.airborne and drop.z >= 5.0 and not drop.crashed, "climbing to a few metres (%.1f)" % drop.z)
	drop.set_stick(0.0)
	drop.set_throttle(0.0)
	run_steps(drop, 8.0)
	check(drop.crashed and drop.crash_reason == "грубая посадка", "a fall from a height is a crash (%s)" % drop.crash_reason)
	# too high: into the treetops (the ceiling is 30 m now; the flight itself is hard, so the test puts the zeppelin high up)
	var rocket = Zeppelin.new()
	rocket.set_throttle(1.0)
	rocket.airborne = true
	rocket.v = 30.0
	rocket.z = 29.5
	rocket.vz = 4.0
	rocket.set_stick(6.0)
	run_steps(rocket, 1.0)
	check(rocket.crashed and rocket.crash_reason.begins_with("врезался"), "climbing above 30 m is a crash into the treetops (%s)" % rocket.crash_reason)
	# the flight is harder than the run: the propeller pulls less in the air, a climb costs speed
	var ground = Zeppelin.new()
	ground.v = 36.0
	ground.set_throttle(1.0)
	ground.set_pitch(0.9)
	ground.step(1.0 / 60.0)
	var on_rail = ground.thrust
	var up = Zeppelin.new()
	up.airborne = true
	up.v = 36.0
	up.z = 2.0
	up.vz = 0.0
	up.set_throttle(1.0)
	up.set_pitch(0.9)
	up.set_stick(3.5)
	up.step(1.0 / 60.0)
	check(up.thrust < on_rail * 0.7, "in the air the propeller pulls much less than on the rail (%.0f against %.0f N)" % [up.thrust, on_rail])
	var climbing = Zeppelin.new()
	climbing.airborne = true
	climbing.v = 36.0
	climbing.z = 3.0
	climbing.vz = 5.0
	climbing.set_stick(3.5)
	var v0 = climbing.v
	climbing.step(1.0 / 60.0)
	var level = Zeppelin.new()
	level.airborne = true
	level.v = 36.0
	level.z = 3.0
	level.vz = 0.0
	level.set_stick(3.5)
	level.step(1.0 / 60.0)
	check(climbing.v < level.v, "a climb costs speed (%.3f against %.3f m/s)" % [climbing.v, level.v])
	# the penalty: half of the money, not less than 300, never more than the money
	check(z.crash_penalty(1000) == 500 and z.crash_penalty(400) == 300 and z.crash_penalty(250) == 250 and z.crash_penalty(0) == 0, "the penalty is half of the money, at least 300, never above the money")
	# the wind: a head wind raises the airspeed, so the wheels are unloaded more
	var windy = Zeppelin.new()
	windy.v = 30.0
	windy.set_stick(3.5)
	windy.step(1.0 / 60.0, 0.0, 0.0)
	var load_calm = windy.load_fraction
	windy.v = 30.0
	windy.step(1.0 / 60.0, 0.0, -6.0)
	check(windy.load_fraction < load_calm, "a head wind raises the airspeed and unloads the wheels more")
	# the picture: the surfaces follow the stick smoothly, the flaps open with the air brake, the propeller turns with the revs
	var pic = Zeppelin.new()
	pic.set_stick(8.0)
	pic.step(1.0 / 60.0)
	check(pic.wing_angle < 0.0 and pic.wing_angle > -3.0, "the wing starts to turn at once, but not in a jump (%.2f)" % pic.wing_angle)
	run_steps(pic, 2.0)
	check(absf(pic.wing_angle + 8.0) < 0.5 and absf(pic.tail_angle + 5.6) < 0.5, "the wing and the tail plane follow the stick (%.1f, %.1f)" % [pic.wing_angle, pic.tail_angle])
	pic.set_air_brake(true)
	run_steps(pic, 1.0)
	check(pic.flaps > 0.3 and pic.wing_angle < -20.0, "the air brake opens the flaps on the wing (%.2f, %.1f)" % [pic.flaps, pic.wing_angle])
	run_steps(pic, 2.0)
	check(pic.flaps == 1.0, "and they open fully")
	var spin = Zeppelin.new()
	spin.set_throttle(1.0)
	var phase0 = spin.prop_phase
	run_steps(spin, 0.5)
	check(spin.prop_phase != phase0, "the propeller turns when the engine runs")
	# a playable flight: a pilot takes off, flies a few seconds at 4 m and comes down. With a little nose up the touch is soft, in a dive it is a crash.
	check(scripted_flight(3.5, 0.2).begins_with("LANDED"), "a landing with the nose a little up is soft (%s)" % scripted_flight(3.5, 0.2))
	check(scripted_flight(5.0, 0.0).begins_with("LANDED"), "a landing with the nose up and no throttle is soft too (%s)" % scripted_flight(5.0, 0.0))
	check(scripted_flight(-2.0, 0.5).begins_with("CRASH"), "a dive into the rail is a crash (%s)" % scripted_flight(-2.0, 0.5))
	print("ZEPPELIN CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
