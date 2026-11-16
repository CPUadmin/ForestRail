extends RefCounted
# Помощник main.gd: живые эффекты в мире (дым трубы, пар клапана, облако цилиндров, выхлоп).
# Частицы живут в метрах пути, а не в кадре кузова: поезд уезжает, дым остаётся позади и
# уходит с ветром. Работает через canvas (main.gd), как train_art.gd и yard_ui.gd.

var canvas = null   # main.gd: the model, the screen, world_point and view_scale

const CAP = 400
const CAP_REDUCED = 160
const FX_STEP_MAX = 0.05
const KEEP_SPEED = 0.15      # a new puff keeps this part of the machine's velocity
const AIR_TAU = 0.7          # seconds for a puff to take the speed of the air around it
const PUFF_PX = 96           # side of the generated puff picture
var painted_puffs = false    # true: the puffs use a crop of the painted jet smoke (assets/art_jet/smoke_light.png)

# one particle = one index in these arrays
var p_s = PackedFloat64Array()     # metres along the line
var p_h = PackedFloat32Array()     # metres above the rail
var p_vs = PackedFloat32Array()    # m/s along the line, world frame
var p_vh = PackedFloat32Array()    # m/s up
var p_age = PackedFloat32Array()
var p_life = PackedFloat32Array()
var p_r0 = PackedFloat32Array()    # radius at birth, metres
var p_r1 = PackedFloat32Array()    # radius at the end of life, metres
var p_a0 = PackedFloat32Array()    # alpha at birth
var p_lift = PackedFloat32Array()  # buoyancy, m/s² (steam rises faster than smoke)
var p_seed = PackedInt32Array()
var p_col = PackedColorArray()
var p_kind = PackedByteArray()     # 0 a soft puff, 1 a spark (a short bright streak)

var clock = 0.0
var next_seed = 1
var wind_scale = 1.0       # the tests set 0 for calm air
var emitting = true
var last_screen = ""
var last_model = null
var last_body_s = {}       # id -> body s at the last update (the velocity of the machine is measured from it)
var body_vel = {}          # id -> smoothed world velocity, m/s
var acc = {}               # emitter -> fractional puffs carried to the next frame
var chuff_phase = 0.0
var cloud_index = -1
var wind_cache = {}
var puff_tex: Array = []
var knock_phase = 0.0
var signs = {}             # what the wear showed since the last clear: sign -> count (the tests read it)

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func count() -> int:
	return p_s.size()

func cap() -> int:
	return CAP_REDUCED if bool(canvas.settings.get("reduce_motion", false)) else CAP

func clear() -> void:
	for a in [p_s, p_h, p_vs, p_vh, p_age, p_life, p_r0, p_r1, p_a0, p_lift, p_seed, p_col, p_kind]: a.resize(0)
	last_body_s = {}
	body_vel = {}
	acc = {}
	cloud_index = -1
	knock_phase = 0.0
	signs = {}

# --- deterministic noise (no textures): a hash of two integers and a smooth value noise in time ---
static func hash01(a: int, b: int) -> float:
	var n = (a * 73856093) ^ (b * 19349663)
	n = (n << 13) ^ n
	n = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff
	return float(n) / 2147483647.0

static func noise(seed: int, t: float) -> float:
	var i = floori(t)
	var f = t - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(hash01(seed, i), hash01(seed, i + 1), f) * 2.0 - 1.0

# --- where things are ---
func screen_ok() -> bool:
	return canvas.screen == "game" or canvas.screen == "depot"

func facing() -> int:
	return int(canvas.model.state.direction) if canvas.screen != "depot" else 1

func body_s_of(id: String) -> float:
	var index = canvas.model.body_ids().find(id)
	if index < 0: return NAN
	return canvas.model.body_s_render(index) if canvas.screen != "depot" else -canvas.model.body_offset(index)

# body-local pixels (the frame of draw_vehicle, y down, origin on the rail) -> metres of the world
func to_world(body_s: float, local: Vector2) -> Vector2:
	var air = float(canvas.model.air_z) if canvas.screen == "game" else 0.0
	return Vector2(body_s + float(facing()) * local.x / canvas.ArtV3.PX, -local.y / canvas.ArtV3.PX + air)

# the wind along the line in the world frame (model.wind_here is in the machine-forward frame)
func wind_at(s: float) -> float:
	if canvas.screen != "game" or wind_scale == 0.0: return 0.0
	var key = floori(s / 25.0)
	if not wind_cache.has(key):
		wind_cache[key] = float(canvas.model.wind_here(float(key) * 25.0 + 12.5).x) * float(int(canvas.model.state.direction)) * wind_scale
	return wind_cache[key]

# --- particles ---
func spawn(s: float, h: float, vs: float, vh: float, life: float, r0: float, r1: float, alpha: float, color: Color, lift: float, kind: int = 0) -> void:
	if p_s.size() >= cap():
		# the oldest puff makes room (it is the faintest)
		for a in [p_s, p_h, p_vs, p_vh, p_age, p_life, p_r0, p_r1, p_a0, p_lift, p_seed, p_col, p_kind]: a.remove_at(0)
	p_s.append(s); p_h.append(h); p_vs.append(vs); p_vh.append(vh)
	p_age.append(0.0); p_life.append(life); p_r0.append(r0); p_r1.append(r1); p_a0.append(alpha)
	p_lift.append(lift); p_seed.append(next_seed); p_col.append(color); p_kind.append(kind)
	next_seed += 1

func update(dt: float) -> void:
	if canvas.model == null or canvas.model.state.is_empty(): return
	if canvas.screen != last_screen or canvas.model != last_model:
		clear()
		last_screen = canvas.screen
		last_model = canvas.model
	if not screen_ok(): return
	dt = clampf(dt, 0.0, FX_STEP_MAX)
	if dt <= 0.0: return
	clock += dt
	wind_cache = {}
	if emitting:
		emit_steam(dt)
		emit_petrol(dt)
		emit_wear(dt)
	var calm = 0.4 if bool(canvas.settings.get("reduce_motion", false)) else 1.0
	var keep = exp(-dt / AIR_TAU)
	var i = 0
	while i < p_s.size():
		var age = p_age[i] + dt
		if age >= p_life[i]:
			for a in [p_s, p_h, p_vs, p_vh, p_age, p_life, p_r0, p_r1, p_a0, p_lift, p_seed, p_col, p_kind]: a.remove_at(i)
			continue
		p_age[i] = age
		var seed = p_seed[i]
		# the puff takes the speed of the air; buoyancy lifts it and the air brakes the rise; a little swirl
		var air = wind_at(p_s[i])
		var swirl = 0.35 * calm * minf(1.0, age * 2.0)
		var vs = air + (p_vs[i] - air) * keep + noise(seed, clock * 1.1) * swirl * dt * 3.0
		var vh = p_vh[i] + (p_lift[i] - 1.6 * p_vh[i]) * dt + noise(seed + 7919, clock * 0.9) * swirl * dt * 2.0
		p_vs[i] = vs
		p_vh[i] = vh
		p_s[i] += vs * dt
		p_h[i] = maxf(0.15, p_h[i] + vh * dt)
		i += 1

# the measured velocity of a body in the world (smoothed; a jump of the camera or a new trip is not a speed)
func velocity_of(id: String, s: float, dt: float) -> float:
	var v = 0.0
	if last_body_s.has(id):
		var step = s - float(last_body_s[id])
		if absf(step) < 5.0: v = step / dt
	last_body_s[id] = s
	var smooth = lerpf(float(body_vel.get(id, v)), v, 1.0 - exp(-dt / 0.15))
	body_vel[id] = smooth
	return smooth

func take(key: String, amount: float) -> int:
	var total = float(acc.get(key, 0.0)) + amount
	var n = floori(total)
	acc[key] = total - float(n)
	return n

func emit_steam(dt: float) -> void:
	var model = canvas.model
	if not model.state.fleet_by_id.has("steam"): return
	var body_s = body_s_of("steam")
	if is_nan(body_s): return
	var art = canvas.art
	var vel = velocity_of("steam", body_s, dt)
	var boiler = model.state.fleet_by_id.steam
	var heat = clampf(float(boiler.get("heat", 0.0)), 0.0, 1.0)
	# the safety valve: a white jet of steam straight up, quick to vanish
	if art.steam_plain() and bool(boiler.get("venting", false)):
		var valve = to_world(body_s, art.steam_valve_local())
		for k in range(take("valve", 16.0 * dt)):
			var r = hash01(next_seed, 3)
			spawn(valve.x, valve.y, vel * KEEP_SPEED + (r - 0.5) * 0.4, 2.6 + r, 1.1 + 0.4 * r, 0.05, 0.42, 0.55, Color(1, 1, 1), 2.4)
	if not model.state.get("engine", false): return
	var throttle = clampf(float(model.state.get("throttle", 0)), 0.0, 1.0)
	var stack = to_world(body_s, art.steam_stack_local())
	var grey = soot(Color(0.86, 0.86, 0.82).lerp(Color(0.52, 0.52, 0.52), 0.45 * throttle), "steam")
	var alpha = (0.30 + 0.35 * throttle) * (0.5 + 0.5 * heat)
	# the fire keeps a lazy column going even at rest
	for k in range(take("stack", (2.5 + 3.0 * heat) * dt)):
		var r = hash01(next_seed, 5)
		spawn(stack.x - vel * dt * r, stack.y, vel * KEEP_SPEED, 0.7 + 0.4 * r, 2.6 + 0.8 * r, 0.16, 0.55 + 0.2 * r, alpha * 0.85, grey, 0.9)
	# on the move the exhaust beats in step with the wheels: four chuffs a turn
	var wheel = float(canvas.Geometry.body("steam").wheel_diameter_m)
	if absf(vel) > 0.2 and throttle > 0.02:
		chuff_phase += absf(vel) * dt / (PI * wheel) * 4.0
		var chuffs = floori(chuff_phase)
		chuff_phase -= float(chuffs)
		for c in range(mini(chuffs, 3)):
			for k in range(2 if throttle > 0.4 else 1):
				var r = hash01(next_seed, 9)
				spawn(stack.x - vel * dt * float(c + 1) / float(mini(chuffs, 3) + 1), stack.y, vel * KEEP_SPEED + (r - 0.5) * 0.5, 1.6 + 2.2 * throttle + r * 0.5, 2.4 + 1.0 * r, 0.22, 0.8 + 0.3 * r, alpha, grey, 0.8)   # spread along the step of the frame: no gaps at speed
	# every 85 m the cylinder cocks blow: a white cloud bursts out
	var travelled = float(model.state.stats.distance)
	var index = floori(travelled / 85.0)
	if travelled >= 85.0 and absf(vel) >= 1.0 and index != cloud_index and fposmod(travelled, 85.0) < 4.0:
		cloud_index = index
		for k in range(10):
			var a = TAU * float(k) / 10.0
			spawn(stack.x, stack.y + 0.15, vel * KEEP_SPEED + cos(a) * 1.4, 1.0 + sin(a) * 0.9, 1.8, 0.12, 0.55, 0.7, Color(0.95, 0.96, 0.92), 1.4)
	elif absf(vel) < 1.0:
		cloud_index = index

func emit_petrol(dt: float) -> void:
	var model = canvas.model
	if not model.state.get("engine", false): return
	var body_s = body_s_of("motorcar")
	if is_nan(body_s): return
	var vel = velocity_of("motorcar", body_s, dt)
	var load = clampf(float(model.state.get("throttle", 0)), 0.0, 1.0)
	var pipe = to_world(body_s, canvas.art.petrol_stack_local())
	for k in range(take("petrol", (5.0 + 9.0 * load) * dt)):
		var r = hash01(next_seed, 11)
		spawn(pipe.x, pipe.y, vel * KEEP_SPEED, 0.5 + 0.6 * load, 1.3 + 0.5 * r, 0.05, 0.38 + 0.12 * r, 0.22 + 0.3 * load, soot(Color(0.70, 0.72, 0.74), "motorcar"), 0.6)

# --- wear signs (step 1.4.2): what a tired machine looks and sounds like ---
const SOOT = Color(0.34, 0.33, 0.32)   # a worn engine smokes darker, never black
const SPARK = Color(1.0, 0.82, 0.3)
const MOTORS = ["steam", "motorcar", "jet", "zeppelin", "locomotive", "pneumatic"]

func mark(name: String) -> void:
	signs[name] = int(signs.get(name, 0)) + 1

func play(clip: String, gain: float, pitch: float) -> void:
	if canvas.sound != null: canvas.sound.play(clip, gain, pitch)

# 0 for a healthy engine, up to 1 for a dead one: how much soot goes into the exhaust
func soot_amount(id: String) -> float:
	if canvas.screen != "game": return 0.0
	var wear = canvas.model.wear()
	return clampf((wear.WORN_BELOW - wear.effect_condition(id, "power")) / wear.WORN_BELOW, 0.0, 1.0)

func soot(color: Color, id: String) -> Color:
	return color.lerp(SOOT, 0.8 * soot_amount(id))

# where a tired engine coughs from: the chimney, the pipe, the jet nozzle, or the roof
func exhaust_local(id: String) -> Vector2:
	var art = canvas.art
	if id == "steam": return art.steam_stack_local()
	if id == "motorcar": return art.petrol_stack_local()
	var box: Rect2 = art.body_bounds(id)
	if id == "jet": return Vector2(box.position.x, box.position.y + box.size.y * 0.55)
	return Vector2(box.position.x + box.size.x * 0.5, box.position.y + box.size.y * 0.2)

func emit_wear(dt: float) -> void:
	if canvas.screen != "game": return
	var model = canvas.model
	var id = model.vehicle_id()
	var body_s = body_s_of(id)
	if is_nan(body_s): return
	var wear = model.wear()
	var vel = float(model.state.get("v", 0.0))
	var speed = absf(vel)
	var dir = float(facing())
	# the brake: worn it smokes at the wheels, critical it throws sparks onto the rail
	var brake = clampf(float(model.state.get("brake", 0.0)), 0.0, 1.0)
	var pads = wear.effect_condition(id, "brake")
	if brake > 0.15 and speed > 1.5 and pads < wear.WORN_BELOW:
		var wheels: Array = canvas.art.wheel_positions(id)
		if not wheels.is_empty():
			var hard = brake * minf(1.0, speed / 8.0)
			var tired = clampf((wear.WORN_BELOW - pads) / wear.WORN_BELOW, 0.0, 1.0)
			var rim = 0.5 * float(canvas.Geometry.body(id).wheel_diameter_m)
			for k in range(take("brake_smoke", (5.0 + 16.0 * tired) * hard * dt)):
				var r = hash01(next_seed, 31)
				var at = to_world(body_s, wheels[next_seed % wheels.size()])
				spawn(at.x - dir * rim, at.y, vel * 0.7, 0.3 + 0.4 * r, 1.0 + 0.5 * r, 0.08, 0.36 + 0.14 * r, 0.3 + 0.35 * tired, Color(0.66, 0.63, 0.60), 0.5)
				mark("brake_smoke")
			if pads < wear.WARN_BELOW:
				var shower = 220.0 if pads < wear.BREAKDOWN_BELOW else 120.0
				for k in range(take("sparks", shower * hard * dt)):
					var r = hash01(next_seed, 33)
					var q = hash01(next_seed, 34)
					var at = to_world(body_s, wheels[next_seed % wheels.size()])
					# the shoe grinds the rim behind the wheel: a fan of sparks out of it, up and back, falling to the rail
					var low = hash01(next_seed, 35) * 0.6
					spawn(at.x - dir * rim * 0.95, at.y - rim * low, vel * (0.75 + 0.2 * r) - signf(vel) * 1.5 * q, 0.5 + 3.0 * q, 0.3 + 0.3 * r, 0.03, 0.02, 1.0, SPARK.lerp(Color(1.0, 0.95, 0.75), q), -9.0, 1)
					mark("sparks")
	# the engine: critical it coughs a dark puff now and then, failing it also bangs (a backfire with a flash)
	var power = wear.effect_condition(id, "power")
	var running = bool(model.state.get("engine", true)) and float(model.state.get("throttle", 0.0)) > 0.1
	if id in MOTORS and running and power < wear.WARN_BELOW:
		var often = 0.6 if power < wear.BREAKDOWN_BELOW else 0.22   # coughs a second
		if take("cough", often * dt) > 0:
			var bang = power < wear.BREAKDOWN_BELOW and hash01(next_seed, 41) < 0.5
			var at = to_world(body_s, exhaust_local(id))
			var dark = SOOT if id != "pneumatic" else Color(0.92, 0.93, 0.92)   # the air motor hisses white
			for k in range(7 if bang else 4):
				var r = hash01(next_seed, 43)
				var side = hash01(next_seed, 44) - 0.5
				spawn(at.x, at.y, vel * KEEP_SPEED + side * 1.2, 0.8 + 0.9 * r, 1.2 + 0.6 * r, 0.08, (0.5 if bang else 0.35) * (0.7 + 0.5 * r), 0.55, dark, 0.5)
			if bang:
				for k in range(10):
					var r = hash01(next_seed, 45)
					spawn(at.x, at.y, vel * KEEP_SPEED + (r - 0.5) * 4.0, 1.0 + 2.0 * hash01(next_seed, 46), 0.18 + 0.15 * r, 0.03, 0.02, 1.0, SPARK, -6.0, 1)
				play("land_thud", 0.55, 1.6)
				mark("bang")
			elif id == "pneumatic":
				play("steam_blow", 0.25, 1.5)
				mark("cough")
			elif id == "locomotive" or id == "zeppelin":
				play("contactor", 0.4, 0.8)
				mark("cough")
			else:
				play("petrol_stall", 0.3, 1.5)
				mark("cough")
	# the bearings: critical they knock once a wheel turn, failing twice
	var bearings = 1.0
	for body in model.body_ids(): bearings = minf(bearings, wear.effect_condition(body, "roll"))
	if bearings < wear.WARN_BELOW and speed > 0.5:
		var wheel = maxf(0.3, float(canvas.Geometry.body(id).wheel_diameter_m))
		knock_phase += speed * dt / (PI * wheel) * (2.0 if bearings < wear.BREAKDOWN_BELOW else 1.0)
		if knock_phase >= 1.0:
			knock_phase = fposmod(knock_phase, 1.0)
			play("rail_tick_b", clampf(0.25 + speed / 30.0, 0.25, 0.6), 0.6)
			mark("knock")

# The petrol engine catches: one light grey puff out of the stack (no black smoke, the owner 14.11). A cough: a wisp.
func petrol_catch_puff() -> void:
	petrol_burst(9, 0.55, 0.45)

func petrol_cough_puff() -> void:
	petrol_burst(3, 0.3, 0.25)

func petrol_burst(count: int, size: float, alpha: float) -> void:
	if canvas.model.vehicle_id() != "motorcar": return
	var body_s = body_s_of("motorcar")
	if is_nan(body_s): return
	var pipe = to_world(body_s, canvas.art.petrol_stack_local())
	for k in range(count):
		var r = hash01(next_seed, 13)
		var side = hash01(next_seed, 14) - 0.5
		spawn(pipe.x, pipe.y, side * 0.8, 0.9 + 0.8 * r, 1.4 + 0.6 * r, 0.08, size * (0.7 + 0.5 * r), alpha, Color(0.74, 0.75, 0.76), 0.5)

# --- picture ---
# A soft puff made by code once: a few overlapping blobs with a ragged edge, lit from above.
func make_puff(variant: int) -> Texture2D:
	var image = Image.create(PUFF_PX, PUFF_PX, false, Image.FORMAT_RGBA8)
	var blobs: Array = []
	for b in range(6):
		var a = TAU * hash01(variant * 31 + b, 1)
		var d = 0.16 * hash01(variant * 31 + b, 2)
		blobs.append(Vector3(0.5 + cos(a) * d, 0.52 + sin(a) * d * 0.8, 0.20 + 0.10 * hash01(variant * 31 + b, 3)))
	for y in range(PUFF_PX):
		for x in range(PUFF_PX):
			var u = (float(x) + 0.5) / PUFF_PX
			var v = (float(y) + 0.5) / PUFF_PX
			var density = 0.0
			for blob in blobs:
				var q = Vector2(u - blob.x, v - blob.y).length() / blob.z
				density += maxf(0.0, 1.0 - q * q) * 0.55
			# a ragged rim: the density is broken a little by a value noise of the place
			var grain = noise(variant * 977 + y, float(x) * 0.18) * 0.12
			density = clampf(density + grain * density, 0.0, 1.0)
			var alpha = smoothstep(0.05, 0.75, density)
			var light = lerpf(1.0, 0.7, smoothstep(0.25, 0.85, v)) # the top is lit, the belly is in shade
			image.set_pixel(x, y, Color(light, light, light * 0.98, alpha))
	return ImageTexture.create_from_image(image)

func textures() -> Array:
	if puff_tex.is_empty():
		for variant in range(3): puff_tex.append(make_puff(variant))
	return puff_tex

func draw() -> void:
	if p_s.is_empty() or not screen_ok() or canvas.model == null or canvas.model.state.is_empty(): return
	var scale = canvas.view_scale()
	var px = canvas.ArtV3.PX * scale
	var tex = textures()
	var painted: Texture2D = canvas.ArtV3.JET_FX["smoke_light"] if painted_puffs else null
	# world_point is sampled once a metre and interpolated: hundreds of puffs cost a few route samples
	var line = {}
	for i in range(p_s.size()):
		var life = p_life[i]
		var u = p_age[i] / life
		var s = p_s[i]
		var k = floori(s)
		if not line.has(k): line[k] = canvas.world_point(float(k))
		if not line.has(k + 1): line[k + 1] = canvas.world_point(float(k + 1))
		var base: Vector2 = (line[k] as Vector2).lerp(line[k + 1], s - float(k))
		var centre = base + Vector2(0, -p_h[i] * px)
		var radius = lerpf(p_r0[i], p_r1[i], sqrt(u)) * px
		var fade = minf(1.0, 0.5 + p_age[i] / 0.08) * (1.0 - smoothstep(0.35, 1.0, u))   # seen at once: a fast train must not leave a gap at the chimney
		var color: Color = p_col[i]
		color.a = p_a0[i] * fade
		if color.a < 0.01: continue
		var seed = p_seed[i]
		if p_kind[i] == 1:
			# a spark: a short streak along its flight, a soft glow around a white-hot core
			var tail = Vector2(-(p_vs[i] - float(canvas.model.state.get("v", 0.0))), p_vh[i]) * 0.045 * px   # the streak as the eye sees it: against the camera that rides with the train
			if tail.length() < 2.0: tail = Vector2(0, 2.0)
			var glow = Color(1.0, 0.42, 0.08, color.a * 0.7)   # a hot orange halo, the core is yellow-white
			canvas.draw_set_transform_matrix(Transform2D.IDENTITY)   # the puff before it left its turn and stretch
			canvas.draw_line(centre, centre + tail, glow, maxf(3.0, 0.06 * px), true)
			canvas.draw_line(centre, centre + tail * 0.6, Color(color.r, color.g, color.b, color.a), maxf(1.4, 0.025 * px), true)
			continue
		var turn = (hash01(seed, 21) - 0.5) * 0.7 + (hash01(seed, 22) - 0.5) * p_age[i] * 0.4   # a little only: the light stays on top
		var stretch = 1.0 + 0.25 * hash01(seed, 23)
		canvas.draw_set_transform(centre, turn, Vector2(stretch, 1.0 / stretch))
		if painted != null:
			# the right end of the painted plume is one round puff
			var region = Rect2(painted.get_width() * 0.58, 0, painted.get_width() * 0.42, painted.get_height())
			canvas.draw_texture_rect_region(painted, Rect2(-radius * 1.1, -radius * 1.1, radius * 2.2, radius * 2.2), region, color)
		else:
			canvas.draw_texture_rect(tex[seed % tex.size()], Rect2(-radius * 1.3, -radius * 1.3, radius * 2.6, radius * 2.6), false, color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
