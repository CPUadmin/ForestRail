extends RefCounted
# Т7 (разбивка main.gd), шаг 2: кисть кабины: вид вперёд, нос машины, рама, приборная панель, указатель поворота, приборы.
# Рисует на холсте canvas (main.gd) его же методами; состояние (кабина, подсказки нажатий, стрелки) осталось в main.gd.

# the colours of the view forward, parsed once (1.3.5) and named by their hex code
const C_2c2a27 = Color("2c2a27")
const C_3a5e3c = Color("3a5e3c")
const C_4a3b2e = Color("4a3b2e")
const C_4b3a2c = Color("4b3a2c")
const C_554d43 = Color("554d43")
const C_5f7f54 = Color("5f7f54")
const C_6a5646 = Color("6a5646")
const C_77a06a = Color("77a06a")
const C_8a8174 = Color("8a8174")
const C_b7ab94 = Color("b7ab94")
const C_b8b4a9 = Color("b8b4a9")
const C_e2dfd6 = Color("e2dfd6")
const C_e6d9a8 = Color("e6d9a8")
const C_e8e4d4 = Color("e8e4d4")

var canvas = null   # the node that draws (main.gd): it holds the font, the model and the shared state

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func draw_cab_scene(size: Vector2) -> void:
	var layout = canvas.cab_layout(size)
	var top = float(layout.dash_top)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var view = Rect2(0, 0, size.x, top)
	# The view and the machine's nose shake with the track and the engine; the frame
	# and the dashboard stay put, so the controls keep their places under the mouse.
	canvas.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, canvas.cab_shake()))
	var perf = canvas.perf_on   # 1.3.5: the parts of the cab are counted apart in check_perf_budget
	var t0 = Time.get_ticks_usec() if perf else 0
	var look = draw_cab_forward(view)
	if perf: canvas.perf_add("cab_forward", t0); t0 = Time.get_ticks_usec()
	draw_cab_nose(view, look)
	if perf: canvas.perf_add("cab_nose", t0); t0 = Time.get_ticks_usec()
	# B4.1: the glass at night and at dawn
	var night = canvas.model.night_amount()
	if canvas.model.twilight() > 0.01: canvas.draw_rect(view, Color(1.0, 0.5, 0.25, 0.16 * minf(1.0, canvas.model.twilight())))
	var glass_weather = canvas.shown_weather()
	if canvas.wiper_on and dash_v2(): glass_weather = {"cloud": float(glass_weather.cloud), "rain": float(glass_weather.rain) * 0.35, "fog": float(glass_weather.fog)}
	canvas.art_world.draw_weather(canvas, view, glass_weather, canvas.time, bool(canvas.settings.reduce_motion))
	if night > 0.01:
		canvas.draw_rect(view, Color(0.02, 0.04, 0.12, canvas.night_shade() * 0.97))
		if canvas.lights_lit():
			var beam = Color(1.0, 0.88, 0.55, 0.22 * clampf(0.5 + night * 0.5, 0.0, 1.0))
			var track_center = Vector2(float(look.cx), view.end.y)
			var vanishing_point = Vector2(track_center.x, float(look.horizon))
			var spread = Vector2(view.size.y * 0.24, 0.0)
			var clear_beam = Color(beam, 0.0)
			canvas.draw_polygon(PackedVector2Array([vanishing_point, track_center - spread, track_center]), PackedColorArray([clear_beam, clear_beam, beam]))
			canvas.draw_polygon(PackedVector2Array([vanishing_point, track_center, track_center + spread]), PackedColorArray([clear_beam, beam, clear_beam]))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	if perf: canvas.perf_add("cab_glass", t0); t0 = Time.get_ticks_usec()
	draw_cab_frame(size, top)
	if perf: canvas.perf_add("cab_frame", t0); t0 = Time.get_ticks_usec()
	if canvas.model.vehicle_id() == "jet" and bool(canvas.model.jet.counting):
		# the countdown: a red lamp pulses at the top of the frame
		var pulse = 0.5 + 0.5 * sin(canvas.time * 8.0)
		canvas.draw_circle(Vector2(size.x * 0.5, 30.0), 16.0, Color(0.9, 0.15, 0.1, 0.25 + 0.55 * pulse))
		canvas.draw_circle(Vector2(size.x * 0.5, 30.0), 8.0, Color(1.0, 0.5, 0.4, 0.5 + 0.5 * pulse))
	if canvas.has_own_pult():
		canvas.draw_zeppelin_pult(Rect2(layout.rect).position, float(layout.k))
	else:
		draw_cab_dash_details(size, layout)
		if perf: canvas.perf_add("cab_dash", t0); t0 = Time.get_ticks_usec()
		draw_cab_gauges(size, layout)
		if perf: canvas.perf_add("cab_gauges", t0); t0 = Time.get_ticks_usec()
		canvas.draw_control_zoom()
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	canvas.cab_exit_rect = Rect2(size.x - 206, 14, 190, 40)
	canvas.draw_style_box(canvas.style(Color(0.08, 0.12, 0.10, 0.86), canvas.GOLD, 8), canvas.cab_exit_rect)
	canvas.draw_string(canvas.font, canvas.cab_exit_rect.position + Vector2(0, 27), "Выйти [E]", HORIZONTAL_ALIGNMENT_CENTER, canvas.cab_exit_rect.size.x, 19, canvas.PAPER)
	var ahead = canvas.instruments.climb_ahead(canvas.model.sight_m()) if canvas.instruments != null else {}
	var text = "Впереди без крутых подъёмов" if ahead.is_empty() else ("Подъём +%.1f%% — сейчас" % ahead.grade if ahead.distance < 10 else "Подъём +%.1f%% через %d м" % [ahead.grade, ahead.distance])
	if perf: canvas.perf_add("cab_rest", t0)
	canvas.draw_string(canvas.font, Vector2(0, 44), canvas.model.journey_heading() + "  ·  " + text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 240, 18, Color(canvas.PAPER, 0.92))

# The view forward along the track. Returns the horizon line and focal length so the
# nose of the machine can be placed against it.
# 1.3.5: the projection of the view forward. One call of depth(z) gives the scale and the screen line of a distance z;
# the points of one distance share it (a row of the ground, both ends of a sleeper), so the heights of the track are looked up once per distance.
var p_cx = 0.0
var p_focal = 1.0
var p_horizon = 0.0
var p_camera = 0.0
var p_origin = 0.0
var p_facing = 1
var p_rail = 0.0
var p_elevations := {}

func depth(z: float) -> Vector2:
	var e = p_elevations.get(z)
	if e == null:
		e = canvas.model.route.sample(p_origin + p_facing * z).y - p_rail
		p_elevations[z] = e
	var k = p_focal / z
	return Vector2(k, p_horizon + (p_camera - float(e)) * k)

func proj(x: float, z: float) -> Vector2:
	var d = depth(z)
	return Vector2(p_cx + x * d.x, d.y)

# 1.3.5: the quads of one layer (the ground, the bed, the rails) go to the screen in one batch of triangles instead of one polygon each
var b_points := PackedVector2Array()
var b_colors := PackedColorArray()
var b_uvs := PackedVector2Array()
var b_indices := PackedInt32Array()

func quad(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, c0: Color, c1: Color, c2: Color, c3: Color, uv: PackedVector2Array = PackedVector2Array()) -> void:
	var n = b_points.size()
	b_points.append_array(PackedVector2Array([p0, p1, p2, p3]))
	b_colors.append_array(PackedColorArray([c0, c1, c2, c3]))
	if not uv.is_empty(): b_uvs.append_array(uv)
	b_indices.append_array(PackedInt32Array([n, n + 1, n + 2, n, n + 2, n + 3]))

func flush(texture: Texture2D = null) -> void:
	if not b_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), b_indices, b_points, b_colors, b_uvs if texture != null else PackedVector2Array(), PackedInt32Array(), PackedFloat32Array(), texture.get_rid() if texture != null else RID())
	b_points.clear()
	b_colors.clear()
	b_uvs.clear()
	b_indices.clear()

func draw_cab_ground(travelled: float) -> void:
	# Use the grass above the exposed cross-section in the existing roadside tile.
	const TILE_LENGTH = 3.0
	const TILE_WIDTH = 8.0
	const GRASS_TOP = 0.08
	const GRASS_BOTTOM = 0.18
	const ROW_LENGTH = TILE_LENGTH / 2.0
	# Mirror alternate tiles so the grass strip has no hard edge as it passes the cab.
	var phase = fposmod(travelled, TILE_LENGTH * 2.0)
	for row in range(24, -1, -1):
		var start = float(row) * ROW_LENGTH - phase
		var end = start + ROW_LENGTH
		if end <= 1.3: continue
		var near = maxf(start, 1.3)
		var v_near = lerpf(GRASS_BOTTOM, GRASS_TOP, pingpong((near + phase) / TILE_LENGTH, 1.0))
		var v_far = lerpf(GRASS_BOTTOM, GRASS_TOP, pingpong((end + phase) / TILE_LENGTH, 1.0))
		var tint_near = Color(0.83, 0.96, 0.83, 0.34 * (1.0 - smoothstep(9.0, 29.0, near)))
		var tint_far = Color(tint_near, 0.34 * (1.0 - smoothstep(9.0, 29.0, end)))
		if tint_near.a <= 0.0: continue
		var dn = depth(near)
		var de = depth(end)
		var uvs = PackedVector2Array([Vector2(0, v_near), Vector2(1, v_near), Vector2(1, v_far), Vector2(0, v_far)])
		for col in range(-4, 4):
			var left = float(col) * TILE_WIDTH
			var right = left + TILE_WIDTH
			quad(Vector2(p_cx + left * dn.x, dn.y), Vector2(p_cx + right * dn.x, dn.y), Vector2(p_cx + right * de.x, de.y), Vector2(p_cx + left * de.x, de.y), tint_near, tint_near, tint_far, tint_far, uvs)
	flush(canvas.ArtWorld.ROAD_GROUND)

func draw_cab_forward(view: Rect2) -> Dictionary:
	var facing = int(canvas.model.state.direction)
	var travelled = canvas.model.render_s() * facing
	var speed = absf(float(canvas.model.state.v))
	var origin = canvas.model.render_s()
	var rail_height: float = canvas.model.route.sample(origin).y
	var pitch = (canvas.model.route.sample(origin + facing * 6.0).y - rail_height) / 6.0
	var bob = sin(canvas.time * 9.0) * minf(1.6, speed * 0.25)
	var focal = view.size.y * 0.95
	var horizon = view.position.y + view.size.y * 0.47 + clampf(pitch, -0.08, 0.08) * focal + bob
	# Look through the driver's pane so the centre pillar leaves the track visible.
	var cx = view.size.x * 0.40
	var camera_height = 1.7 + (float(canvas.model.air_z) if canvas.model.vehicle_id() == "zeppelin" and canvas.model.air_fly else 0.0)   # in flight the eye rises with the machine
	p_cx = cx
	p_focal = focal
	p_horizon = horizon
	p_camera = camera_height
	p_origin = origin
	p_facing = facing
	p_rail = rail_height
	p_elevations.clear()
	var look = {"horizon": horizon, "focal": focal, "cx": cx, "speed": speed, "travelled": travelled}
	# C1: the sky and the three layers of the forest are the same painted pictures as outside the window
	var sky: Texture2D = canvas.art.textures["parallax/sky"]
	var sky_h = horizon - view.position.y + view.size.y * 0.04
	var sky_k = maxf(view.size.x / float(sky.get_width()), sky_h / float(sky.get_height()))
	canvas.draw_texture_rect_region(sky, Rect2(view.position.x, view.position.y, view.size.x, sky_h), Rect2(0.0, 0.0, view.size.x / sky_k, sky_h / sky_k))
	for layer in [["parallax/far_hills", 0.36, 4.0, Color(0.78, 0.87, 0.86)], ["parallax/far_forest", 0.29, 9.0, Color(0.86, 0.93, 0.91)], ["parallax/mid_forest", 0.23, 15.0, Color.WHITE]]:
		var tex: Texture2D = canvas.art.textures[str(layer[0])]
		var layer_h = view.size.y * float(layer[1])
		var layer_w = layer_h * float(tex.get_width()) / float(tex.get_height())
		var layer_x = -layer_w * 0.37
		while layer_x < view.size.x:
			canvas.draw_texture_rect(tex, Rect2(layer_x, horizon + float(layer[2]) - layer_h, layer_w + 1.0, layer_h), false, layer[3])
			layer_x += layer_w
	canvas.draw_polygon(PackedVector2Array([Vector2(0, horizon - 3), Vector2(view.size.x, horizon - 3), Vector2(view.size.x, horizon + 28), Vector2(0, horizon + 28)]), PackedColorArray([Color(0.85, 0.92, 0.9, 0.0), Color(0.85, 0.92, 0.9, 0.0), Color(0.85, 0.92, 0.9, 0.5), Color(0.85, 0.92, 0.9, 0.5)]))
	canvas.draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(view.size.x, horizon), view.end, Vector2(0, view.end.y)]), PackedColorArray([C_77a06a, C_77a06a, C_3a5e3c, C_3a5e3c]))
	draw_cab_ground(travelled)
	var near = 1.3
	var far = 170.0
	var steps = [near, 2.0, 3.0, 4.5, 7.0, 11.0, 18.0, 25.0, 33.0, 44.0, 55.0, 70.0, 85.0, 100.0, 125.0, 150.0, far]
	for bed in [[2.6, C_5f7f54], [1.9, C_8a8174]]:
		var half: float = bed[0]
		for i in range(steps.size() - 1):
			var a: float = steps[i]
			var b: float = steps[i + 1]
			var da = depth(a)
			var db = depth(b)
			var c: Color = bed[1]
			quad(Vector2(p_cx - half * da.x, da.y), Vector2(p_cx + half * da.x, da.y), Vector2(p_cx + half * db.x, db.y), Vector2(p_cx - half * db.x, db.y), c, c, c, c)
	flush()
	# ballast speckle close to the train
	for i in range(60):
		var z = near + 0.4 + fposmod(canvas.cab_hash(i, 6.0) * 14.0 - travelled, 14.0)
		var spot = proj((canvas.cab_hash(i, 7.0) - 0.5) * 3.4, z)
		canvas.draw_rect(Rect2(spot, Vector2(clampf(0.06 * focal / z, 1, 5), clampf(0.03 * focal / z, 1, 3))), Color(0.35, 0.32, 0.28, 0.6))
	var phase = fposmod(-travelled, 0.9)
	for k in range(0, 150):
		var z = near + phase + k * 0.9
		if z > 120.0: break
		var d = depth(z)
		var a = Vector2(p_cx - 1.15 * d.x, d.y)
		var b = Vector2(p_cx + 1.15 * d.x, d.y)
		canvas.draw_line(a, b, canvas.cab_fog(C_4a3b2e, z), clampf(0.2 * focal / z, 1.0, 20.0), true)
		canvas.draw_line(a + Vector2(0, -clampf(0.07 * focal / z, 0, 6)), b + Vector2(0, -clampf(0.07 * focal / z, 0, 6)), canvas.cab_fog(C_6a5646, z), clampf(0.05 * focal / z, 0.5, 5.0), true)
	var glints: Array = []
	for rail_x in [-0.55, 0.55]:
		for i in range(steps.size() - 1):
			var z0: float = steps[i]
			var z1: float = steps[i + 1]
			var a: Vector2 = proj(rail_x, z0)
			var b: Vector2 = proj(rail_x, z1)
			var head_a = a - Vector2(0, 0.14 * focal / z0)
			var head_b = b - Vector2(0, 0.14 * focal / z1)
			var body = canvas.cab_fog(C_554d43, z0)
			quad(a, b, head_b, head_a, body, body, body, body)
			var width_a = Vector2(0.035 * focal / z0, 0)
			var width_b = Vector2(0.035 * focal / z1, 0)
			if absf(head_a.y - head_b.y) >= 0.1:
				var head = canvas.cab_fog(C_b8b4a9, z0)
				quad(head_a - width_a, head_a + width_a, head_b + width_b, head_b - width_b, head, head, head, head)
			glints.append([head_a - width_a, head_b - width_b, canvas.cab_fog(C_e2dfd6, z0), clampf(0.015 * focal / z0, 0.4, 2.0)])
	flush()
	# the bright edge of the rail head goes on top of the batch, as before
	for g in glints: canvas.draw_line(g[0], g[1], g[2], g[3], true)
	# rail joints every 12 m
	var joint_phase = fposmod(-travelled, 12.0)
	for j in range(0, 12):
		var z = near + joint_phase + j * 12.0
		if z > 110.0: break
		for rail_x in [-0.55, 0.55]:
			var p: Vector2 = proj(rail_x, z) - Vector2(0, 0.14 * focal / z)
			canvas.draw_rect(Rect2(p + Vector2(-clampf(0.08 * focal / z, 1, 9), -1), Vector2(clampf(0.16 * focal / z, 2, 18), clampf(0.03 * focal / z, 1, 3))), canvas.cab_fog(C_2c2a27, z))
	# stations ahead: platform, building, sign
	for i in range(canvas.model.route.station_s.size()):
		var z = (float(canvas.model.route.station_s[i]) - canvas.model.render_s()) * facing
		if z < 6.0 or z > 190.0: continue
		var z0 = maxf(near + 0.5, z - 9.0)
		var z1 = z + 9.0
		canvas.draw_colored_polygon(PackedVector2Array([proj(1.5, z0), proj(3.4, z0), proj(3.4, z1), proj(1.5, z1)]), canvas.cab_fog(C_b7ab94, z))
		var edge_a = proj(1.5, z0)
		var edge_b = proj(1.5, z1)
		canvas.draw_line(edge_a, edge_b, canvas.cab_fog(C_e6d9a8, z), clampf(0.06 * focal / z, 1, 5), true)
		var station = canvas.model.data.stations[i]
		var building_id = canvas.art_world.station_building_id(i)
		var facade: Array = canvas.ArtWorld.STATION_ART.get(station.id, [])
		var texture: Texture2D = canvas.art.textures[building_id] if facade.is_empty() else facade[0]
		var height_m = texture.get_height() * canvas.art.scale_for(building_id) / canvas.ArtV3.PX if facade.is_empty() else float(facade[1])
		var height = height_m * focal / z
		var width = height * float(texture.get_width()) / float(texture.get_height())
		var foot: Vector2 = proj(10.5, z)
		canvas.draw_texture_rect(texture, Rect2(foot - Vector2(width * 0.5, height), Vector2(width, height)), false, canvas.cab_fog(Color.WHITE, z))
		if z < 70.0:
			var label_size = clampi(roundi(600.0 / z), 9, 18)
			var label_width = canvas.font.get_string_size(station.name, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x + 14.0
			var label_at = foot + Vector2(-label_width * 0.5, 8)
			canvas.draw_rect(Rect2(label_at, Vector2(label_width, label_size + 6.0)), Color("20392e", 0.9))
			canvas.draw_string(canvas.font, label_at + Vector2(0, label_size), station.name, HORIZONTAL_ALIGNMENT_CENTER, label_width, label_size, canvas.PAPER)
	# telegraph poles on the left with sagging wires, mileposts on the right
	var pole_first = floori((travelled + 4.0) / 40.0)
	var pole_last = floori((travelled + 160.0) / 40.0)
	var previous_top = []
	for i in range(pole_last, pole_first - 1, -1):
		var z = i * 40.0 - travelled
		if z < 5.0 or z > 160.0: continue
		var base = proj(-4.6, z)
		var tall = 7.0 * focal / z
		canvas.draw_line(base, base + Vector2(0, -tall), canvas.cab_fog(C_4b3a2c, z), clampf(0.2 * focal / z, 1, 9), true)
		canvas.draw_line(base + Vector2(-tall * 0.16, -tall * 0.92), base + Vector2(tall * 0.16, -tall * 0.92), canvas.cab_fog(C_4b3a2c, z), clampf(0.1 * focal / z, 1, 5), true)
		var tops = [base + Vector2(-tall * 0.14, -tall * 0.92), base + Vector2(tall * 0.14, -tall * 0.92)]
		for wire in range(2):
			if previous_top.size() == 2:
				var a = tops[wire]
				var b = previous_top[wire]
				canvas.draw_polyline(PackedVector2Array([a, a.lerp(b, 0.5) + Vector2(0, tall * 0.05), b]), canvas.cab_fog(C_2c2a27, z), clampf(0.03 * focal / z, 0.7, 2.0), true)
		previous_top = tops
	var post_first = floori((travelled + 4.0) / 100.0)
	for i in range(post_first + 2, post_first - 1, -1):
		var z = i * 100.0 - travelled
		if z < 6.0 or z > 160.0: continue
		var base = proj(2.6, z)
		var tall = 1.1 * focal / z
		canvas.draw_rect(Rect2(base.x - 0.16 * focal / z, base.y - tall, 0.32 * focal / z, tall), canvas.cab_fog(C_e8e4d4, z))
		canvas.draw_string(canvas.font, Vector2(base.x - 0.2 * focal / z, base.y - tall * 0.45), str(i), HORIZONTAL_ALIGNMENT_CENTER, 0.4 * focal / z, clampi(roundi(0.35 * focal / z), 6, 20), C_2c2a27)
	# C1: near the track the old flat trees give way to the painted things of the side view (rocks, grass, ferns,
	# flowers, stumps) that stand as pictures in the perspective; the forest behind them is painted too
	var first = floori((travelled + 5.0) / 2.2)
	var last = floori((travelled + 150.0) / 2.2)
	for i in range(last, first - 1, -1):
		var distance = i * 2.2 + canvas.cab_hash(i) * 1.6
		var z = distance - travelled
		if z < 5.0 or z > 148.0: continue
		var side = -1.0 if canvas.cab_hash(i, 1.0) < 0.5 else 1.0
		var lateral = side * (2.4 + canvas.cab_hash(i, 2.0) * 10.0)
		var kind = int(canvas.cab_hash(i, 5.0) * 6.0) % 6
		var thing: Texture2D = canvas.art_world.TRACKSIDE[kind]
		var thing_m = float(canvas.art_world.TRACKSIDE_M[kind]) * (1.7 + canvas.cab_hash(i, 3.0) * 1.3)
		if i % 7 == 0:
			thing = canvas.textures["birch" if canvas.cab_hash(i, 4.0) > 0.65 else "pine"]
			thing_m = lerpf(2.8, 4.5, canvas.cab_hash(i, 3.0))
			lateral = side * (7.0 + canvas.cab_hash(i, 2.0) * 13.0)
		var base = proj(lateral, z)
		var h = thing_m * focal / z
		var w = h * float(thing.get_width()) / float(thing.get_height())
		canvas.draw_texture_rect(thing, Rect2(base.x - w * 0.5, base.y - h, w, h), false, canvas.cab_fog(Color(0.95, 0.96, 0.9), z))
	# speed streaks at the edges and a soft vignette
	if speed > 3.0:
		for streak in range(14):
			var y = view.position.y + view.size.y * (0.35 + canvas.cab_hash(streak, 12.0) * 0.65)
			var side_x = 1.0 if streak % 2 == 0 else -1.0
			var start_x = cx + side_x * view.size.x * (0.3 + 0.2 * canvas.cab_hash(streak, 13.0))
			canvas.draw_line(Vector2(start_x, y), Vector2(start_x + side_x * view.size.x * 0.2, y + (y - horizon) * 0.2), Color(1, 1, 1, clampf((speed - 3.0) * 0.02, 0.0, 0.14)), 2.0, true)
	canvas.draw_polygon(PackedVector2Array([view.position, Vector2(view.end.x, view.position.y), Vector2(view.end.x, view.end.y), Vector2(view.position.x, view.end.y)]), PackedColorArray([Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
	return look

# The front of the machine seen over the dashboard: hood, boiler or battery box.
func draw_cab_nose(view: Rect2, look: Dictionary) -> void:
	var kind = canvas.model.vehicle_id()
	var cx = float(look.cx)
	var bottom = view.end.y
	var vh = view.size.y
	var running = bool(canvas.model.state.engine)
	var steel = Color("1d2427")
	var brass = Color("c9a85a")
	if kind == "motorcar":
		var hood = PackedVector2Array([Vector2(cx - vh * 0.52, bottom), Vector2(cx + vh * 0.52, bottom), Vector2(cx + vh * 0.30, bottom - vh * 0.30), Vector2(cx - vh * 0.30, bottom - vh * 0.30)])
		canvas.draw_polygon(hood, PackedColorArray([Color("2b3438"), Color("2b3438"), Color("11171a"), Color("11171a")]))
		canvas.draw_line(Vector2(cx, bottom), Vector2(cx, bottom - vh * 0.30), Color(1, 1, 1, 0.08), 3.0, true)
		for slat in range(5):
			var f = 0.15 + slat * 0.16
			var y = bottom - vh * 0.30 * f
			canvas.draw_line(Vector2(cx - vh * (0.52 - 0.22 * f) * 0.78, y), Vector2(cx + vh * (0.52 - 0.22 * f) * 0.78, y), Color(0, 0, 0, 0.55), 3.0, true)
		for band in [0.2, 0.62]:
			var y = bottom - vh * 0.30 * band
			canvas.draw_line(Vector2(cx - vh * (0.52 - 0.22 * band), y), Vector2(cx + vh * (0.52 - 0.22 * band), y), brass, 4.0, true)
		var cap = Vector2(cx + vh * 0.17, bottom - vh * 0.22)
		canvas.draw_circle(cap, vh * 0.026, brass)
		canvas.draw_circle(cap, vh * 0.019, Color("8a6d33"))
		canvas.draw_line(cap + Vector2(-vh * 0.014, 0), cap + Vector2(vh * 0.014, 0), Color("2a2218"), 2.5)
		canvas.draw_line(cap + Vector2(0, -vh * 0.014), cap + Vector2(0, vh * 0.014), Color("2a2218"), 2.5)
		canvas.draw_rect(Rect2(cx - 9, bottom - vh * 0.30, 18, vh * 0.30), Color("4b3321"))
		canvas.draw_rect(Rect2(cx - 14, bottom - vh * 0.30 - 3, 28, 8), brass)
		var lamp = Vector2(cx, bottom - vh * 0.33)
		canvas.draw_circle(lamp, vh * 0.035, brass)
		canvas.draw_circle(lamp, vh * 0.026, Color("fff0b4") if running else Color("8a8466"))
		if running:
			for ring in range(4): canvas.draw_circle(lamp, vh * (0.05 + ring * 0.03), Color(1.0, 0.9, 0.5, 0.07 - ring * 0.015))
		var stack = Vector2(cx - vh * 0.16, bottom - vh * 0.26)
		canvas.draw_rect(Rect2(stack.x - 7, stack.y - vh * 0.16, 14, vh * 0.16), brass)
		canvas.draw_rect(Rect2(stack.x - 11, stack.y - vh * 0.17, 22, 8), steel)
		if running:
			for puff in range(5):
				var age = fposmod(canvas.time * 0.9 + puff / 5.0, 1.0)
				canvas.draw_circle(Vector2(stack.x - age * vh * 0.1, stack.y - vh * 0.19 - age * vh * 0.22), 7 + age * 24, Color(0.85, 0.85, 0.82, 0.4 * (1.0 - age)))
	elif kind == "jet":
		# the flat deck ahead of the cab with the brass rail and the lamp (the engine and its nozzle are behind us)
		canvas.draw_rect(Rect2(cx - vh * 0.6, bottom - vh * 0.10, vh * 1.2, vh * 0.10), steel)
		canvas.draw_rect(Rect2(cx - vh * 0.6, bottom - vh * 0.112, vh * 1.2, 5), brass)
		var jet_lamp = Vector2(cx, bottom - vh * 0.16)
		canvas.draw_circle(jet_lamp, vh * 0.035, brass)
		canvas.draw_circle(jet_lamp, vh * 0.026, Color("fff0b4") if (bool(canvas.model.jet.started) or bool(canvas.model.jet.counting)) else Color("8a8466"))
		if bool(canvas.model.jet.started):
			for ring in range(4): canvas.draw_circle(jet_lamp, vh * (0.05 + ring * 0.03), Color(1.0, 0.9, 0.5, 0.07 - ring * 0.015))
	elif kind == "steam":
		var barrel = Rect2(cx - vh * 0.42, bottom - vh * 0.30, vh * 0.84, vh * 0.30)
		canvas.draw_rect(barrel, Color("1b2224"))
		canvas.draw_polygon(PackedVector2Array([barrel.position, Vector2(barrel.end.x, barrel.position.y), Vector2(barrel.end.x, barrel.position.y + barrel.size.y * 0.35), Vector2(barrel.position.x, barrel.position.y + barrel.size.y * 0.35)]), PackedColorArray([Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
		canvas.draw_line(barrel.position, Vector2(barrel.end.x, barrel.position.y), brass, 4.0, true)
		for band in [0.2, 0.5, 0.8]:
			canvas.draw_line(Vector2(barrel.position.x + barrel.size.x * band, barrel.position.y), Vector2(barrel.position.x + barrel.size.x * band, bottom), brass, 5.0, true)
		for rivet in range(14):
			canvas.draw_circle(Vector2(barrel.position.x + 20 + rivet * barrel.size.x / 14.0, barrel.position.y + 14), 3.0, brass)
		var dome = Vector2(cx - vh * 0.20, barrel.position.y)
		canvas.draw_circle(dome + Vector2(0, -vh * 0.012), vh * 0.045, brass)
		canvas.draw_rect(Rect2(dome.x - vh * 0.05, dome.y - vh * 0.012, vh * 0.1, vh * 0.012), Color("8a6d33"))
		var chimney = Vector2(cx + vh * 0.12, barrel.position.y)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(chimney.x - 15, chimney.y), Vector2(chimney.x + 15, chimney.y), Vector2(chimney.x + 12, chimney.y - vh * 0.20), Vector2(chimney.x - 12, chimney.y - vh * 0.20)]), steel)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(chimney.x - 12, chimney.y - vh * 0.20), Vector2(chimney.x + 12, chimney.y - vh * 0.20), Vector2(chimney.x + 28, chimney.y - vh * 0.27), Vector2(chimney.x - 28, chimney.y - vh * 0.27)]), Color("2a3438"))
		canvas.draw_rect(Rect2(chimney.x - 30, chimney.y - vh * 0.28, 60, 7), brass)
		if running:
			for puff in range(7):
				var age = fposmod(canvas.time * (0.7 + float(canvas.model.state.throttle)) + puff / 7.0, 1.0)
				canvas.draw_circle(Vector2(chimney.x + sin(puff * 2.0 + canvas.time) * 10 - age * 30, chimney.y - vh * 0.30 - age * vh * 0.34), 12 + age * 38, Color(0.9, 0.9, 0.88, 0.5 * (1.0 - age)))
		var lamp = Vector2(cx - vh * 0.02, barrel.position.y - vh * 0.012)
		canvas.draw_circle(lamp, vh * 0.026, brass)
		canvas.draw_circle(lamp, vh * 0.018, Color("fff0b4") if running else Color("8a8466"))
	else:
		var deck = PackedVector2Array([Vector2(cx - vh * 0.56, bottom), Vector2(cx + vh * 0.56, bottom), Vector2(cx + vh * 0.38, bottom - vh * 0.24), Vector2(cx - vh * 0.38, bottom - vh * 0.24)])
		canvas.draw_polygon(deck, PackedColorArray([Color("2d3a33"), Color("2d3a33"), Color("172019"), Color("172019")]))
		for lid in range(3):
			var f0 = lid / 3.0
			var f1 = (lid + 0.9) / 3.0
			var left0 = lerpf(cx - vh * 0.50, cx + vh * 0.50, f0)
			var left1 = lerpf(cx - vh * 0.50, cx + vh * 0.50, f1)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(left0, bottom - vh * 0.02), Vector2(left1, bottom - vh * 0.02), Vector2(lerpf(cx - vh * 0.34, cx + vh * 0.34, f1), bottom - vh * 0.21), Vector2(lerpf(cx - vh * 0.34, cx + vh * 0.34, f0), bottom - vh * 0.21)]), Color("33463a"))
			canvas.draw_line(Vector2((left0 + left1) * 0.5, bottom - vh * 0.1), Vector2((left0 + left1) * 0.5 + 6, bottom - vh * 0.1), brass, 6.0, true)
		for stripe in range(8):
			var x = cx - vh * 0.5 + stripe * vh * 0.125
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, bottom), Vector2(x + vh * 0.05, bottom), Vector2(x + vh * 0.05 - 6, bottom - vh * 0.025), Vector2(x - 6, bottom - vh * 0.025)]), Color("d9b43e") if stripe % 2 == 0 else Color("1f2623"))
		var lamp = Vector2(cx, bottom - vh * 0.25)
		canvas.draw_circle(lamp, vh * 0.024, brass)
		canvas.draw_circle(lamp, vh * 0.017, Color("fff0b4") if running else Color("8a8466"))

# The cab around the view: roof lining, pillars, window rubber, wipers, lamps and the
# dashboard ledge.
func draw_cab_frame(size: Vector2, top: float) -> void:
	var green = Color("2f4a3b")
	var dark = Color("1f2f27")
	var brass = Color("c9a85a")
	var running_engine = bool(canvas.model.state.engine) and canvas.model.vehicle_id() != "locomotive"
	var lamp_flicker = 1.0 - (0.22 * (0.5 + 0.5 * sin(canvas.time * 27.0)) if running_engine and canvas.light_flicker_enabled() else 0.0)
	var roof = size.y * 0.075
	canvas.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, roof), Vector2(0, roof)]), PackedColorArray([dark, dark, green, green]))
	var planks := PackedVector2Array()   # 1.3.5: the many thin lines of the frame go in one call each
	for plank in range(1, 24):
		planks.append(Vector2(size.x * plank / 24.0, 0))
		planks.append(Vector2(size.x * plank / 24.0, roof))
	canvas.draw_multiline(planks, Color(0, 0, 0, 0.22), 2.0)
	canvas.draw_line(Vector2(0, roof), Vector2(size.x, roof), brass, 3.0)
	canvas.draw_line(Vector2(0, roof + 3), Vector2(size.x, roof + 3), Color(0, 0, 0, 0.4), 3.0)
	var pillar = size.x * 0.12
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(pillar, 0), Vector2(pillar * 0.45, top), Vector2(0, top)]), green)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(size.x, 0), Vector2(size.x - pillar, 0), Vector2(size.x - pillar * 0.45, top), Vector2(size.x, top)]), green)
	var grains := PackedVector2Array()
	for grain in range(7):
		var gx = pillar * (0.1 + grain * 0.1)
		grains.append_array(PackedVector2Array([Vector2(gx, 0), Vector2(gx * 0.55, top), Vector2(size.x - gx, 0), Vector2(size.x - gx * 0.55, top)]))
	canvas.draw_multiline(grains, Color(0, 0, 0, 0.12), 1.5)
	for side in [-1.0, 1.0]:
		var edge_x = pillar if side < 0 else size.x - pillar
		var low_x = pillar * 0.45 if side < 0 else size.x - pillar * 0.45
		canvas.draw_line(Vector2(edge_x, roof), Vector2(low_x, top), brass, 3.0)
		canvas.draw_line(Vector2(edge_x + side * 5, roof), Vector2(low_x + side * 5, top), Color(0, 0, 0, 0.45), 4.0)
		for bolt in range(8):
			var f = (bolt + 0.5) / 8.0
			canvas.draw_circle(Vector2(lerpf(edge_x, low_x, f) + side * 14, lerpf(roof, top, f)), 3.5, brass)
	# Crop out the exterior roof and keep the keyed apertures over the live view.
	var windshield = Rect2(size.x * 0.075, roof - 3, size.x * 0.85, top - roof + 3)
	canvas.draw_texture_rect_region(canvas.CAB_WINDSHIELD, windshield, Rect2(40, 216, 1420, 728), Color(0.68, 0.70, 0.65))
	for window_side in [-1.0, 1.0]:
		var frame = canvas.cab_window_rect(size, top, window_side).grow(7.0)
		canvas.draw_rect(frame, Color("0f1512"))
		canvas.draw_rect(frame, brass, false, 3.0)
		canvas.draw_rect(frame.grow(-3.0), Color("2a2218"), false, 2.0)
		for bolt in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
			canvas.draw_circle(bolt, 3.5, brass)
	# a brass lantern on a hook at the left pillar, under the side window
	var hook = Vector2(pillar * 0.4 + sin(canvas.time * 1.8) * minf(absf(float(canvas.model.state.v)), 6.0) * 0.7, size.y * 0.29)
	canvas.draw_line(Vector2(hook.x, roof), hook, brass, 2.0)
	canvas.draw_rect(Rect2(hook.x - 12, hook.y, 24, 34), Color("a98a4a"))
	canvas.draw_rect(Rect2(hook.x - 8, hook.y + 5, 16, 24), Color("ffe9a6") if bool(canvas.model.state.engine) else Color("6f6a52"))
	canvas.draw_circle(hook + Vector2(0, 17), 36.0, Color(1.0, 0.85, 0.45, 0.07 if bool(canvas.model.state.engine) else 0.0))
	# two ceiling lamps with a warm glow
	for lamp_x in [0.27, 0.73]:
		var p = Vector2(size.x * lamp_x, roof + 6)
		canvas.draw_line(Vector2(p.x, roof), p, Color("6a5a3a"), 3.0)
		canvas.draw_circle(p + Vector2(0, 9), 11, brass)
		canvas.draw_circle(p + Vector2(0, 11), 7, Color("fff1c4"))
		for ring in range(5): canvas.draw_circle(p + Vector2(0, 11), 20.0 + ring * 16.0, Color(1.0, 0.9, 0.55, (0.06 - ring * 0.01) * lamp_flicker))
	# Curtains hang in front of the painted frame.
	for side in [-1.0, 1.0]:
		var corner_x = pillar * 1.05 if side < 0 else size.x - pillar * 1.05
		for fold in range(4):
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(corner_x, roof + 3), Vector2(corner_x - side * (12 + fold * 9), roof + 3), Vector2(corner_x - side * (6 + fold * 9), roof + 50 + fold * 6)]), Color("6f3a34") if fold % 2 == 0 else Color("55292a"))
	canvas.draw_line(Vector2(pillar + 6, roof + 6), Vector2(size.x - pillar - 6, roof + 6), Color("171c19"), 6.0)
	# windscreen wipers resting at the bottom of the glass
	var sweep = 0.95 * (0.5 - 0.5 * cos(canvas.wiper_phase * TAU)) if dash_v2() and not canvas.settings.reduce_motion else 0.0
	for side in [-1.0, 1.0]:
		var pivot = Vector2(size.x * (0.5 + side * 0.14), top - 24)
		var arm = Vector2(side * size.x * 0.10, -size.y * 0.06).rotated(-side * sweep)
		var tip = pivot + arm
		canvas.draw_line(pivot, tip, Color("101412"), 5.0, true)
		canvas.draw_line(pivot + arm * 0.24, tip, Color("050605"), 7.0, true)
		canvas.draw_circle(pivot, 6, brass)
	# glass: sheen, reflections and a few specks of dust
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(pillar * 1.6, roof), Vector2(pillar * 2.6, roof), Vector2(pillar * 1.6, top), Vector2(pillar * 0.7, top)]), Color(1, 1, 1, 0.05))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.64, roof), Vector2(size.x * 0.7, roof), Vector2(size.x * 0.59, top), Vector2(size.x * 0.53, top)]), Color(1, 1, 1, 0.04))
	for speck in range(26):
		canvas.draw_circle(Vector2(size.x * (0.1 + 0.8 * canvas.cab_hash(speck, 20.0)), roof + (top - roof) * canvas.cab_hash(speck, 21.0)), 1.0 + canvas.cab_hash(speck, 22.0) * 1.5, Color(1, 1, 1, 0.1))
	# dashboard ledge in wood, then the steel panel
	canvas.draw_texture_rect_region(canvas.CAB_WOOD, Rect2(0, top - 22, size.x, 18), Rect2(54, 790, 1428, 128), Color(0.68, 0.68, 0.64))
	if dash_v2():
		draw_dash_panel_v2(size, top)
	else:
		# Use the painted lower panel, leaving the live gauges free to vary by cab.
		# the painted panel in two parts: the green steel plate over the whole dashboard and the brass strip with its rivets only as a
		# thin edge at the bottom (stretched over everything it put huge rivets under the gauges)
		var strip_h = clampf(size.y * 0.028, 22.0, 30.0)
		canvas.draw_texture_rect_region(canvas.CAB_STEEL, Rect2(0, top - 4, size.x, size.y - top + 4 - strip_h), Rect2(330, 812, 840, 52), Color(0.66, 0.69, 0.64))   # a plain piece of the plate without rivets: stretched, a rivet became an oval
		canvas.draw_texture_rect_region(canvas.CAB_STEEL, Rect2(0, size.y - strip_h, size.x, strip_h), Rect2(0, 905, 1536, 110), Color(0.7, 0.7, 0.66))
		canvas.draw_line(Vector2(0, top - 4), Vector2(size.x, top - 4), Color(0, 0, 0, 0.55), 3.0)
		for rivet in range(int(size.x / 50.0)):
			canvas.draw_circle(Vector2(25 + rivet * 50.0, top + 8), 2.5, Color("a98a4a"))
		for screw in range(int(size.x / 50.0)):
			canvas.draw_circle(Vector2(25 + screw * 50.0, size.y - 10), 3.0, Color("0c100e"))
			canvas.draw_line(Vector2(25 + screw * 50.0 - 2, size.y - 12), Vector2(25 + screw * 50.0 + 2, size.y - 8), Color("55645a"), 1.2)

func draw_plain_header(size: Vector2, top: float, kind: String, brass: Color) -> void:
	# nameplate
	var plate = Rect2(size.x * 0.5 - 150, top + 12, 300, 26)
	canvas.draw_style_box(canvas.style(Color("2a2218"), brass, 4), plate)
	var title = {"steam": "ЛЕСНАЯ КОЛЕЯ · ПАРОВОЗ", "motorcar": "ЛЕСНАЯ КОЛЕЯ · БЕНЗИНОВАЯ", "locomotive": "ЛЕСНАЯ КОЛЕЯ · ЭЛЕКТРОВОЗ", "pneumatic": "ЛЕСНАЯ КОЛЕЯ · ПНЕВМОВОЗ", "zeppelin": "ЛЕСНАЯ КОЛЕЯ · ЦЕППЕЛИН", "jet": "ЛЕСНАЯ КОЛЕЯ · РЕАКТИВНЫЙ"}.get(kind, "ЛЕСНАЯ КОЛЕЯ")
	canvas.draw_string(canvas.font, plate.position + Vector2(0, 19), title, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 14, Color("e6cf8b"))
	canvas.draw_circle(plate.position + Vector2(8, 13), 2.5, brass)
	canvas.draw_circle(plate.position + Vector2(plate.size.x - 8, 13), 2.5, brass)
	# indicator lamps
	var amount = float(canvas.model.state.fleet_by_id[kind].fuel)
	var tank = float(canvas.model.object_stats(kind).tank)
	var lamps = [["ХОД", absf(float(canvas.model.state.v)) > 0.1, Color("5cc17f")], ["ДВИГАТЕЛЬ", bool(canvas.model.state.engine), Color("e6b34a")], ["ТОРМОЗ", float(canvas.model.state.brake) > 0.1, Color("e0564a")], ["ЗАПАС", amount / maxf(0.001, tank) < 0.15, Color("e0564a")]]
	for i in range(lamps.size()):
		var at = Vector2(60 + i * 86, top + 22)
		canvas.draw_circle(at, 9, Color("0c100e"))
		canvas.draw_circle(at, 7, lamps[i][2] if lamps[i][1] else lamps[i][2].darkened(0.75))
		if lamps[i][1]: canvas.draw_circle(at, 16, Color(lamps[i][2], 0.22))
		canvas.draw_string(canvas.font, at + Vector2(-40, 25), lamps[i][0], HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color("a9a589"))


# ===== Petrol cab dashboard, dark gunmetal with copper trim (the owner's reference picture) =====
func dash_v2() -> bool:
	return canvas.model.vehicle_id() == "motorcar" and canvas.cab_active()

var panel_key = null
var panel_streaks := PackedVector2Array()
var panel_streak_colors := PackedColorArray()
var panel_wear := PackedVector2Array()

func draw_dash_panel_v2(size: Vector2, top: float) -> void:
	var copper = Color("b9793a")
	var copper_light = Color("e0a15f")
	canvas.draw_polygon(PackedVector2Array([Vector2(0, top - 4), Vector2(size.x, top - 4), Vector2(size.x, size.y), Vector2(0, size.y)]), PackedColorArray([Color("1d1c1a"), Color("1d1c1a"), Color("080808"), Color("080808")]))
	# brushed metal: faint vertical streaks
	var key = [size, top]
	if panel_key != key:
		# the streaks and the worn marks hang on the size only: built once, drawn in two calls
		panel_key = key
		panel_streaks = PackedVector2Array()
		panel_streak_colors = PackedColorArray()
		for streak in range(120):
			var x = size.x * canvas.cab_hash(streak, 31.0)
			panel_streaks.append_array(PackedVector2Array([Vector2(x, top + 6), Vector2(x + 2.0, size.y - 8)]))
			panel_streak_colors.append(Color(1, 1, 1, 0.012 + 0.02 * canvas.cab_hash(streak, 32.0)))
		var rim = Rect2(10, top + 2, size.x - 20, size.y - top - 14)
		panel_wear = PackedVector2Array()
		for wear in range(70):
			var along = canvas.cab_hash(wear, 33.0)
			var on_top = canvas.cab_hash(wear, 34.0) < 0.5
			var at = Vector2(lerpf(rim.position.x, rim.end.x, along), rim.position.y if on_top else rim.end.y)
			panel_wear.append_array(PackedVector2Array([at, at + Vector2(6.0 + 10.0 * canvas.cab_hash(wear, 35.0), 0)]))
	canvas.draw_multiline_colors(panel_streaks, panel_streak_colors, 1.0)
	# the worn copper rim of the panel and an inner line
	var frame = Rect2(10, top + 2, size.x - 20, size.y - top - 14)
	canvas.draw_rect(frame, copper, false, 4.0)
	canvas.draw_rect(frame.grow(-5.0), Color(0, 0, 0, 0.65), false, 2.0)
	canvas.draw_line(frame.position + Vector2(6, 2), Vector2(frame.end.x - 6, frame.position.y + 2), copper_light, 1.5)
	canvas.draw_multiline(panel_wear, Color("1d1c1a"), 3.0)
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
		canvas.draw_circle(corner, 5.0, copper_light)
		canvas.draw_circle(corner, 2.0, Color("2a1a0c"))

# A recessed module in the dashboard: dark inset with a thin copper edge.
func draw_dash_module(rect: Rect2) -> void:
	canvas.draw_rect(rect, Color("0b0b0a"))
	canvas.draw_rect(rect, Color("8a5a2c"), false, 2.0)
	canvas.draw_rect(rect.grow(-3.0), Color(0, 0, 0, 0.6), false, 1.0)

func draw_petrol_header_v2(size: Vector2, top: float) -> void:
	var copper = Color("b9793a")
	var gold = Color("e6cf8b")
	# the box of lamps, left: power, work, engine, overheating, alarm
	var box = Rect2(30, top + 12, 340, 70)
	draw_dash_module(box)
	var fleet = canvas.model.state.fleet_by_id.motorcar
	var tank = float(canvas.model.object_stats("motorcar").tank)
	var low_fuel = float(fleet.fuel) / maxf(0.001, tank) < 0.15
	var lamps = [["ПИТАНИЕ", float(fleet.fuel) > 0.0, Color("5cc17f")], ["РАБОТА", bool(canvas.model.state.engine) and float(canvas.model.state.throttle) > 0.02, Color("e6b34a")], ["ДВИГАТЕЛЬ", bool(canvas.model.state.engine), Color("f0eed0")], ["ПЕРЕГРЕВ", canvas.model.engine_temp() > canvas.Model.TEMP_HOT, Color("e0564a")], ["АВАРИЯ", low_fuel or (canvas.model.engine_temp() >= 0.98), Color("e0564a")]]
	for i in range(lamps.size()):
		var at = Vector2(box.position.x + 36 + i * 66, box.position.y + 26)
		canvas.draw_circle(at, 12, Color("1a1a18"))
		canvas.draw_arc(at, 12, 0, TAU, 20, Color("8a5a2c"), 1.5, true)
		canvas.draw_circle(at, 9, lamps[i][2] if lamps[i][1] else lamps[i][2].darkened(0.8))
		if lamps[i][1]:
			canvas.draw_circle(at, 20, Color(lamps[i][2], 0.2))
			canvas.draw_circle(at + Vector2(-3, -3), 3, Color(1, 1, 1, 0.5))
		canvas.draw_string(canvas.font, at + Vector2(-32, 31), lamps[i][0], HORIZONTAL_ALIGNMENT_CENTER, 64, 10, Color("c7c3a0"))
	# the nameplate with chevrons on both sides
	var plate = Rect2(size.x * 0.5 - 205, top + 10, 410, 30)
	canvas.draw_polygon(PackedVector2Array([plate.position + Vector2(14, 0), Vector2(plate.end.x - 14, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]), PackedColorArray([Color("141413"), Color("141413"), Color("0a0a09"), Color("0a0a09")]))
	canvas.draw_polyline(PackedVector2Array([plate.position + Vector2(0, plate.size.y), plate.position + Vector2(14, 0), Vector2(plate.end.x - 14, plate.position.y), plate.end]), copper, 2.0, true)
	for side in [-1.0, 1.0]:
		for k in range(3):
			var cx = size.x * 0.5 + side * (162.0 + k * 9.0)
			canvas.draw_line(Vector2(cx, plate.position.y + 8 + k * 3), Vector2(cx + side * 16.0, plate.position.y + 8 + k * 3), gold, 1.6)
	canvas.draw_string(canvas.font, plate.position + Vector2(0, 21), "ЛЕСНАЯ КОЛЕЯ — БЕНЗИНОВАЯ", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 16, gold)
	# the three working buttons, bottom right: headlamp, wipers, horn
	var specs = [["light", canvas.lights_lit()], ["wiper", canvas.wiper_on], ["whistle", false]]
	for i in range(specs.size()):
		var rect = Rect2(size.x - 330 + i * 80, size.y - 96, 64, 64)
		var lit = bool(specs[i][1])
		canvas.draw_rect(rect, Color("0d0d0c"))
		canvas.draw_rect(rect, Color("e0a15f") if lit else Color("6a4524"), false, 3.0)
		canvas.draw_rect(rect.grow(-4.0), Color(0, 0, 0, 0.55), false, 1.0)
		var c = rect.get_center()
		var ink = Color("ffd98a") if lit else Color("9a8a6a")
		match str(specs[i][0]):
			"light":
				canvas.draw_arc(c + Vector2(-6, 0), 14, -PI * 0.5, PI * 0.5, 14, ink, 3.0, true)
				for r in range(3): canvas.draw_line(c + Vector2(10, -10 + r * 10), c + Vector2(24, -12 + r * 12), ink, 2.0)
			"wiper":
				canvas.draw_arc(c + Vector2(0, 14), 24, -PI * 0.85, -PI * 0.15, 14, ink, 2.0, true)
				canvas.draw_line(c + Vector2(0, 14), c + Vector2(14, -10), ink, 3.5, true)
			"whistle":
				canvas.draw_rect(Rect2(c + Vector2(-14, -4), Vector2(18, 12)), ink)
				canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(4, -4), c + Vector2(18, -12), c + Vector2(18, 16), c + Vector2(4, 8)]), ink)
		canvas.cab_hits.append({"id": str(specs[i][0]), "rect": rect})
		canvas.draw_string(canvas.font, rect.position + Vector2(-8, 82), {"light": "ФАРА", "wiper": "ДВОРНИКИ", "whistle": "СИГНАЛ"}[str(specs[i][0])], HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color("a9a589"))

# Small dashboard details: nameplate, indicator lamps, clock, vents, cables, and the
# vehicle-specific bits (water glass and whistle cord on the steam engine).
func draw_cab_dash_details(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var pult: Rect2 = layout.rect
	var brass = Color("c9a85a")
	var kind = canvas.model.vehicle_id()
	if kind == "motorcar": draw_petrol_header_v2(size, top)
	else: draw_plain_header(size, top, kind, brass)
	# brass clock on the right of the ledge
	var clock = Vector2(size.x - 70, top + 26)
	canvas.draw_circle(clock, 22, brass)
	canvas.draw_circle(clock, 19, Color("f1ead2"))
	for hour in range(12):
		var a = TAU * hour / 12.0 - PI / 2
		canvas.draw_line(clock + Vector2(cos(a), sin(a)) * 15, clock + Vector2(cos(a), sin(a)) * 18, Color("2a2218"), 1.5)
	var minutes = fposmod(canvas.model.world_hours() * 60.0, 60.0)
	var hours = fposmod(canvas.model.world_hours(), 12.0)
	var am = TAU * minutes / 60.0 - PI / 2
	var ah = TAU * hours / 12.0 - PI / 2
	canvas.draw_line(clock, clock + Vector2(cos(am), sin(am)) * 15, Color("2a2218"), 1.5, true)
	canvas.draw_line(clock, clock + Vector2(cos(ah), sin(ah)) * 10, Color("2a2218"), 2.5, true)
	canvas.draw_circle(clock, 2, Color("a8231c"))
	# hanging cables
	canvas.draw_polyline(PackedVector2Array([Vector2(size.x * 0.30, top + 6), Vector2(size.x * 0.34, top + 42), Vector2(size.x * 0.38, top + 8)]), Color("0b0e0c"), 4.0, true)
	if kind == "motorcar": draw_petrol_cab_extras(size, layout)
	if kind in ["steam", "locomotive", "pneumatic"]: draw_cab_reverser(size, layout)
	if kind == "locomotive": draw_electric_cab_extras(size, layout)
	if kind == "pneumatic": draw_pneumatic_cab_extras(size, layout)
	if kind == "steam":
		# water glass on the right: tube with the level, brass fittings
		var tube = Rect2(size.x - 150, top + 70, 16, 120)
		canvas.draw_rect(tube, Color("a9d1d6", 0.35))
		var level = clampf(float(canvas.model.state.fleet_by_id.steam.get("water", 0)) / float(canvas.model.object_stats("steam").water), 0.0, 1.0)
		canvas.draw_rect(Rect2(tube.position.x + 2, tube.end.y - tube.size.y * level, tube.size.x - 4, tube.size.y * level), Color("4f8fbf", 0.85))
		canvas.draw_rect(Rect2(tube.position.x - 6, tube.position.y - 8, tube.size.x + 12, 8), brass)
		canvas.draw_rect(Rect2(tube.position.x - 6, tube.end.y, tube.size.x + 12, 8), brass)
		canvas.draw_string(canvas.font, tube.position + Vector2(-20, tube.size.y + 26), "уровень", HORIZONTAL_ALIGNMENT_CENTER, 56, 11, Color("a9a589"))
		# whistle cord with a ring, swaying a little with the speed
		var sway = sin(canvas.time * 3.0) * minf(6.0, absf(float(canvas.model.state.v))) if not canvas.settings.reduce_motion else 0.0
		var cord_top = Vector2(size.x * 0.5 + 220, 0.0)
		var ring_at = Vector2(size.x * 0.5 + 224 + sway, top - 60 + 12.0 * canvas.whistle_pull)
		canvas.draw_line(Vector2(cord_top.x, size.y * 0.075), ring_at, Color("a58b57"), 3.0, true)
		var ring = ring_at + Vector2(0, 8)
		var hit = Rect2(ring - Vector2(20, 20), Vector2(40, 40))
		var hovered = hit.has_point(canvas.get_global_mouse_position())
		canvas.draw_arc(ring, 8, 0, TAU, 16, canvas.GOLD if hovered else brass, 3.0, true)
		canvas.cab_hits.append({"id": "whistle", "rect": hit})

# Direction switch in the top strip of the dashboard: two buttons, the engaged one lit.
func draw_cab_reverser(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var strip_x = size.x * 0.5 + 190.0
	var brass = Color("c9a85a")
	var panel = Rect2(strip_x, top + 10, 190, 60)
	canvas.draw_style_box(canvas.style(Color("1d2320"), brass, 6), panel)
	canvas.draw_string(canvas.font, panel.position + Vector2(0, 54), "НАПРАВЛЕНИЕ", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 10, Color("c7c3a0"))
	var forward = int(canvas.model.state.get("reverser", 1)) >= 0
	for index in range(2):
		var button = Rect2(panel.position + Vector2(8 + index * 88, 8), Vector2(86, 30))
		var lit = (index == 1) == forward
		canvas.draw_rect(button, Color("2c3a30") if lit else Color("151b18"))
		canvas.draw_rect(button, brass if lit else Color("4b564e"), false, 2.0)
		canvas.draw_circle(button.position + Vector2(12, 15), 5, Color("5cc17f") if lit else Color("1e3326"))
		canvas.draw_string(canvas.font, button.position + Vector2(20, 21), "ВПЕРЁД" if index == 1 else "НАЗАД", HORIZONTAL_ALIGNMENT_CENTER, 62, 13, canvas.PAPER if lit else Color("8a8466"))
		canvas.cab_hits.append({"id": "forward" if index == 1 else "back", "rect": button})

# Electric cab: warning plate, regeneration lamps and the emergency stop button, the
# voltmeter and ammeter live in draw_cab_gauges.
func draw_electric_cab_extras(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var pult: Rect2 = layout.rect
	var brass = Color("c9a85a")
	var cx = size.x * 0.5
	var hatch = Rect2(cx + 77, top + 128, 80, 88)
	canvas.draw_texture_rect(canvas.CONTACTOR_HATCH, hatch, false, Color("9d9f8c"))
	var pilot = hatch.position + Vector2(37, 18)
	var energized = bool(canvas.model.state.engine) and canvas.sound.contactor_on
	canvas.draw_circle(pilot, 5.5, Color("382819"))
	canvas.draw_circle(pilot, 3.5, canvas.GOLD if energized else Color("695732"))
	canvas.draw_string(canvas.font, hatch.end + Vector2(-105, 15), "КОНТАКТОР", HORIZONTAL_ALIGNMENT_CENTER, 130, 12, Color("c7c3a0"))
	# warning plate with a lightning bolt
	var tri = Vector2(400, top + 38)
	canvas.draw_colored_polygon(PackedVector2Array([tri + Vector2(0, -22), tri + Vector2(25, 22), tri + Vector2(-25, 22)]), Color("e6c13a"))
	canvas.draw_polyline(PackedVector2Array([tri + Vector2(0, -22), tri + Vector2(25, 22), tri + Vector2(-25, 22), tri + Vector2(0, -22)]), Color("2a2218"), 2.5, true)
	canvas.draw_colored_polygon(PackedVector2Array([tri + Vector2(3, -12), tri + Vector2(-7, 4), tri + Vector2(-1, 4), tri + Vector2(-4, 14), tri + Vector2(7, -2), tri + Vector2(1, -2)]), Color("1a1612"))
	canvas.draw_string(canvas.font, tri + Vector2(-60, 40), "ВЫСОКОЕ НАПРЯЖЕНИЕ", HORIZONTAL_ALIGNMENT_CENTER, 120, 9, Color("a9a589"))
	# regeneration and charge lamps under the nameplate
	var regen = canvas.model.regen_kw > 0.01
	var lamps = [["РЕКУП.", regen, Color("6cc4e0")], ["ПИТАНИЕ", float(canvas.model.state.fleet_by_id.locomotive.fuel) > 0.0, Color("5cc17f")], ["НИЗКИЙ ЗАРЯД", float(canvas.model.state.fleet_by_id.locomotive.fuel) / float(canvas.model.object_stats("locomotive").tank) < 0.25, Color("e0564a")]]
	for lamp in range(lamps.size()):
		var at = Vector2(cx - 60 + lamp * 60, top + 54)
		var sweep = clampf(1.0 - absf((1.0 - canvas.electric_start_flash / canvas.ELECTRIC_START_FLASH) * 3.0 - float(lamp)), 0.0, 1.0) if canvas.electric_start_flash > 0.0 and canvas.light_flicker_enabled() else 0.0
		canvas.draw_circle(at, 9, Color("0c100e"))
		canvas.draw_circle(at, 7, lamps[lamp][2] if lamps[lamp][1] else lamps[lamp][2].darkened(0.78))
		if lamps[lamp][1]: canvas.draw_circle(at, 15, Color(lamps[lamp][2], 0.2))
		if sweep > 0.0: canvas.draw_circle(at, 11, Color(0.8, 0.93, 1.0, sweep * 0.6))
		canvas.draw_string(canvas.font, at + Vector2(-30, 24), lamps[lamp][0], HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color("a9a589"))
	# motor temperature: over 85% the pull weakens
	var motor_temp = canvas.model.engine_temp()
	draw_round_gauge(Vector2(cx + 190.0 + 190.0 + 52.0 + 112.0, top + 56.0), clampf((layout.rect.position.x - 70.0) * 0.22, 46.0, 92.0) * 0.42, motor_temp, "МОТОР", "%d°" % roundi(20.0 + motor_temp * 100.0), [[0.7, Color("5cc17f")], [0.85, Color("e6b34a")], [1.0, Color("e0564a")]], 4)
	# the red mushroom emergency stop: a real button, it drops traction and pulls the brake
	var button = Vector2(cx + 190 + 190 + 52, top + 38)
	canvas.draw_circle(button, 28, Color("3a1512"))
	canvas.draw_circle(button, 24, Color("c23b2e"))
	canvas.draw_circle(button + Vector2(-8, -9), 8, Color(1, 1, 1, 0.3))
	canvas.draw_arc(button, 28, 0, TAU, 24, brass, 2.5, true)
	canvas.draw_string(canvas.font, button + Vector2(-50, 46), "АВАРИЙНЫЙ ТОРМОЗ", HORIZONTAL_ALIGNMENT_CENTER, 100, 9, Color("a9a589"))
	canvas.cab_hits.append({"id": "emergency", "rect": Rect2(button - Vector2(30, 30), Vector2(60, 60))})

# Pneumatic cab: lamps for low reserve air and for frost on the pipes, under the nameplate.
func draw_pneumatic_cab_extras(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var cx = size.x * 0.5
	var low_air = float(canvas.model.state.fleet_by_id.pneumatic.fuel) / maxf(0.001, float(canvas.model.object_stats("pneumatic").tank)) < 0.25
	var lamps = [["ВОЗДУХ", float(canvas.model.state.fleet_by_id.pneumatic.fuel) > 0.0, Color("6cc4e0")], ["НИЗКОЕ ДАВЛ.", low_air, Color("e0564a")], ["ИНЕЙ", canvas.model.frost() > 0.35, Color("e6b34a")]]
	for lamp in range(lamps.size()):
		var at = Vector2(cx - 60 + lamp * 60, top + 54)
		canvas.draw_circle(at, 9, Color("0c100e"))
		canvas.draw_circle(at, 7, lamps[lamp][2] if lamps[lamp][1] else lamps[lamp][2].darkened(0.78))
		if lamps[lamp][1]: canvas.draw_circle(at, 15, Color(lamps[lamp][2], 0.2))
		canvas.draw_string(canvas.font, at + Vector2(-30, 24), lamps[lamp][0], HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color("a9a589"))

	# B6.2: four valves that let the condensate out of the pipes; a ring blinks when it is time (60 s of running without a press)
	var valves_at = Vector2(size.x - 350.0, top + 52.0)
	canvas.draw_string(canvas.font, valves_at + Vector2(-8, -16), "КОНДЕНСАТ", HORIZONTAL_ALIGNMENT_LEFT, 120, 9, Color("a9a589"))
	for spot in range(4):
		var valve = valves_at + Vector2(spot * 34.0 + 12.0, 6.0)
		var due = canvas.model.drain_due(spot)
		var plug = canvas.model.plugged(spot)
		var pulse = (0.5 + 0.5 * sin(canvas.time * 6.0)) if due and not canvas.settings.reduce_motion else (1.0 if due else 0.0)
		if due: canvas.draw_circle(valve, 17.0, Color(0.9, 0.35 if plug else 0.7, 0.2, 0.18 + 0.3 * pulse))
		canvas.draw_circle(valve, 12.0, Color("c9a85a"))
		canvas.draw_circle(valve, 9.5, Color("1d2320"))
		for spoke in range(3):
			var a = TAU * float(spoke) / 3.0 + (1.0 - clampf(canvas.model.drain_age(spot) / 60.0, 0.0, 1.0)) * 1.2
			canvas.draw_line(valve, valve + Vector2.from_angle(a) * 9.0, Color("e6cf8b") if not plug else Color("e0564a"), 2.0, true)
		canvas.draw_string(canvas.font, valve + Vector2(-5, 26), str(spot + 1), HORIZONTAL_ALIGNMENT_CENTER, 10, 10, Color("a9a589"))
		canvas.cab_hits.append({"id": "drain%d" % spot, "rect": Rect2(valve - Vector2(16, 16), Vector2(32, 32))})

# Petrol cab: ignition lock, choke, fuse box, oil and temperature gauges, gear lamps,
# a rear-view mirror and pedal pads. The two small gauges are live.
func draw_petrol_cab_extras(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var pult: Rect2 = layout.rect
	var brass = Color("c9a85a")
	var cx = size.x * 0.5
	var small = Color("c7c3a0")
	var radius = clampf((pult.position.x - 70.0) * 0.22, 46.0, 92.0)
	var gauge_y = top + (size.y - top) * 0.46
	# switches in the top strip, right of the nameplate: ignition, choke, fuses
	var strip_x = cx + 190.0
	var lock = Rect2(strip_x, top + 10, 84, 60)
	canvas.draw_style_box(canvas.style(Color("1d2320"), brass, 6), lock)
	canvas.draw_circle(lock.position + Vector2(30, 28), 14, Color("0a0c0b"))
	canvas.draw_circle(lock.position + Vector2(30, 28), 12, Color("3b3f3a"))
	canvas.draw_line(lock.position + Vector2(30, 22), lock.position + Vector2(30, 34), Color("050605"), 3.0)
	var key_on = bool(canvas.model.state.engine)
	canvas.draw_line(lock.position + Vector2(30, 28), lock.position + Vector2(30 + (16 if key_on else 9), 28 - (6 if key_on else 14)), Color("d9c27a"), 4.0, true)
	canvas.draw_circle(lock.position + Vector2(30 + (18 if key_on else 11), 28 - (7 if key_on else 16)), 6, Color("d9c27a"))
	canvas.draw_string(canvas.font, lock.position + Vector2(0, 54), "ЗАЖИГАН.", HORIZONTAL_ALIGNMENT_CENTER, lock.size.x, 10, small)
	canvas.draw_circle(lock.position + Vector2(8, 8), 2.2, brass)
	canvas.draw_circle(lock.position + Vector2(lock.size.x - 8, 8), 2.2, brass)
	var choke = Vector2(strip_x + 132, top + 24)
	canvas.draw_line(choke, choke + Vector2(0, 30), Color("8d9a98"), 5.0, true)
	canvas.draw_circle(choke, 12, Color("1a1a1a"))
	canvas.draw_circle(choke, 9, Color("2d2d2d"))
	canvas.draw_circle(choke + Vector2(-3, -3), 3, Color(1, 1, 1, 0.3))
	canvas.draw_string(canvas.font, choke + Vector2(-30, 46), "ПОДСОС", HORIZONTAL_ALIGNMENT_CENTER, 60, 10, small)
	var box = Rect2(strip_x + 178, top + 20, 124, 44)
	canvas.draw_style_box(canvas.style(Color("20261f"), Color("6c6f66"), 4), box)
	for fuse in range(6):
		var colour = [Color("e6b34a"), Color("5cc17f"), Color("e0564a"), Color("5cc17f"), Color("e6b34a"), Color("5cc17f")][fuse]
		var fx = box.position.x + 9 + fuse * 18
		canvas.draw_rect(Rect2(fx, box.position.y + 6, 12, 18), colour.darkened(0.55) if fuse == 2 else colour)
		canvas.draw_line(Vector2(fx + 6, box.position.y + 9), Vector2(fx + 6, box.position.y + 21), Color("101412"), 1.5)
	canvas.draw_string(canvas.font, box.position + Vector2(0, 38), "ПРЕДОХРАНИТЕЛИ", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 9, small)
	# the fuel gauge and the two small live ones stand in one row on the right
	var running = bool(canvas.model.state.engine)
	var small_r = radius * 0.42
	var fuel_x = pult.end.x + 36.0 + radius + 8.0
	var oil_x = fuel_x + radius + 8.0 + 22.0 + small_r
	var temp_x = oil_x + small_r * 2.0 + 16.0
	var oil = clampf(0.12 + canvas.model.engine_rpm_fraction() * 0.75, 0.0, 1.0) if running else 0.0
	draw_round_gauge(Vector2(oil_x, gauge_y), small_r, oil, "МАСЛО", "%.1f" % (oil * 5.0), [[0.2, Color("e0564a")], [0.9, Color("5cc17f")], [1.0, Color("e6b34a")]], 4)
	draw_round_gauge(Vector2(temp_x, gauge_y), small_r, canvas.cab_temp, "ТЕМП.", "%d°" % roundi(20.0 + canvas.cab_temp * 100.0), [[0.7, Color("5cc17f")], [0.85, Color("e6b34a")], [1.0, Color("e0564a")]], 4)
	# gear lamps under the nameplate: the engaged gear is lit
	var labels = ["1", "2", "3", "4", "5", "N", "R"]
	var gears = [1, 2, 3, 4, 5, 0, 6]
	for lamp in range(7):
		var at = Vector2(cx - 84 + lamp * 28, top + 54)
		var lit = int(canvas.model.state.gear) == gears[lamp]
		var lamp_colour = Color("e0564a") if lamp == 6 else (Color("e6b34a") if lamp == 5 else Color("5cc17f"))
		canvas.draw_circle(at, 9, Color("0c100e"))
		canvas.draw_circle(at, 7, lamp_colour if lit else lamp_colour.darkened(0.78))
		if lit: canvas.draw_circle(at, 15, Color(lamp_colour, 0.2))
		canvas.draw_string(canvas.font, at + Vector2(-8, 4), labels[lamp], HORIZONTAL_ALIGNMENT_CENTER, 16, 10, Color("0c100e") if lit else Color("8a8466"))
	# rear-view mirror on a stalk over the glass: the track and train behind, receding
	var mirror = Rect2(cx + 150, size.y * 0.075 + 40, 118, 46)
	canvas.draw_line(Vector2(cx + 209, size.y * 0.075), Vector2(cx + 209, mirror.position.y), Color("0f1512"), 5.0)
	canvas.draw_rect(mirror.grow(5), Color("101512"))
	canvas.draw_polygon(PackedVector2Array([mirror.position, Vector2(mirror.end.x, mirror.position.y), Vector2(mirror.end.x, mirror.get_center().y), Vector2(mirror.position.x, mirror.get_center().y)]), PackedColorArray([Color("86b3d6"), Color("86b3d6"), Color("d9e8e0"), Color("d9e8e0")]))
	canvas.draw_rect(Rect2(mirror.position.x, mirror.get_center().y, mirror.size.x, mirror.size.y * 0.5), Color("5f8756"))
	var vanishing = Vector2(mirror.get_center().x, mirror.get_center().y)
	canvas.draw_line(vanishing + Vector2(-3, 0), Vector2(mirror.position.x + 34, mirror.end.y), Color("c7c3b4"), 2.0, true)
	canvas.draw_line(vanishing + Vector2(3, 0), Vector2(mirror.end.x - 34, mirror.end.y), Color("c7c3b4"), 2.0, true)
	for wagon in range(2):
		var wagon_y = vanishing.y + 7 + wagon * 9
		var wagon_w = 16 + wagon * 14
		canvas.draw_rect(Rect2(vanishing.x - wagon_w * 0.5, wagon_y - 6 - wagon * 2, wagon_w, 8 + wagon * 2), Color("7a4a2a") if wagon == 0 else Color("8a5a34"))
	canvas.draw_colored_polygon(PackedVector2Array([mirror.position + Vector2(10, 0), mirror.position + Vector2(40, 0), mirror.position + Vector2(20, mirror.size.y), mirror.position + Vector2(-8, mirror.size.y)]), Color(1, 1, 1, 0.16))
	# pedal pads under the left gauges: clutch, brake, gas (not controls)
	var left = pult.position.x * 0.5
	for pedal in range(3):
		var px = left - 80.0 + pedal * 56.0
		var py = size.y - 70.0
		var tilt = 6 if pedal == 2 else 0
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(px, py + tilt), Vector2(px + 40, py + tilt), Vector2(px + 44, size.y), Vector2(px - 4, size.y)]), Color("171b19"))
		for tread in range(5):
			var ty = py + tilt + 8 + tread * 11
			canvas.draw_line(Vector2(px + 3, ty), Vector2(px + 37, ty), Color(1, 1, 1, 0.12), 2.0)
		canvas.draw_line(Vector2(px, py + tilt), Vector2(px + 40, py + tilt), brass, 2.0)

func draw_round_gauge(center: Vector2, radius: float, fraction: float, title: String, readout: String, zones: Array, ticks: int = 10, scale_text: Array = []) -> void:
	fraction = canvas.cab_needle(title, fraction)
	var v2 = dash_v2()
	canvas.draw_circle(center + Vector2(2, 3), radius + 8, Color(0, 0, 0, 0.4))
	canvas.draw_circle(center, radius + 8, Color("b9793a") if v2 else Color("a98a4a"))
	canvas.draw_arc(center, radius + 8, PI * 1.1, PI * 1.6, 12, Color("f0c088") if v2 else Color("e6cf8b"), 2.0, true)
	canvas.draw_circle(center, radius + 6, Color("2a1a0c") if v2 else Color("2a2218"))
	canvas.draw_circle(center, radius + 4, Color("08090a") if v2 else Color("0f1a1c"))
	for screw in range(4):
		var screw_at = center + Vector2.from_angle(PI / 4 + screw * PI / 2) * (radius + 6.5)
		canvas.draw_circle(screw_at, 2.2, Color("d9bb6a"))
	var start = deg_to_rad(150)
	var span = deg_to_rad(240)
	var from = 0.0
	for zone in zones:
		canvas.draw_arc(center, radius - 3, start + span * from, start + span * float(zone[0]), 16, zone[1], maxf(4.0, radius * 0.07), true)
		from = float(zone[0])
	for i in range(ticks * 2 + 1):
		var angle = start + span * i / float(ticks * 2)
		var radial = Vector2(cos(angle), sin(angle))
		var major = i % 2 == 0
		canvas.draw_line(center + radial * (radius - (radius * 0.2 if major else radius * 0.12)), center + radial * (radius - 7), canvas.PAPER if major else Color(canvas.PAPER, 0.6), 2.0 if major else 1.0, true)
	for i in range(scale_text.size()):
		var angle = start + span * i / float(maxi(1, scale_text.size() - 1))
		var radial = Vector2(cos(angle), sin(angle))
		canvas.draw_string(canvas.font, center + radial * (radius - radius * 0.27) + Vector2(-14, 5), str(scale_text[i]), HORIZONTAL_ALIGNMENT_CENTER, 28, clampi(roundi(radius * 0.15), 9, 14), Color("e8e0c4"))
	var angle = start + span * clampf(fraction, 0.0, 1.0)
	var needle = Vector2(cos(angle), sin(angle))
	canvas.draw_line(center + Vector2(1.5, 2), center + needle * (radius - 8) + Vector2(1.5, 2), Color(0, 0, 0, 0.45), 4.0, true)
	canvas.draw_line(center - needle * (radius * 0.18), center + needle * (radius - 8), Color("f3ead2"), 3.5, true)
	canvas.draw_line(center + needle * (radius - 22), center + needle * (radius - 8), Color("e0564a"), 3.5, true)
	canvas.draw_circle(center, radius * 0.1, Color("c9af73"))
	canvas.draw_circle(center, radius * 0.04, Color("1a1612"))
	# glare on the glass
	canvas.draw_arc(center, radius - 2, PI * 1.12, PI * 1.45, 10, Color(1, 1, 1, 0.14), radius * 0.16, true)
	canvas.draw_string(canvas.font, center + Vector2(-radius, radius * (0.34 if v2 else 0.38)), title, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, clampi(roundi(radius * 0.15), 9, 14), Color("c7c3a0"))
	if v2:
		# the readout stands in its own box, as on the reference dashboard
		var box = Rect2(center + Vector2(-radius * 0.6, radius * 0.45), Vector2(radius * 1.2, radius * 0.42))
		canvas.draw_rect(box, Color("0e0e0d"))
		canvas.draw_rect(box, Color("b9793a"), false, 1.5)
		canvas.draw_string(canvas.font, box.position + Vector2(0, box.size.y * 0.72), readout, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, clampi(roundi(radius * 0.2), 11, 18), canvas.GOLD)
	else:
		canvas.draw_string(canvas.font, center + Vector2(-radius, radius * 0.66), readout, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, clampi(roundi(radius * 0.21), 12, 20), canvas.GOLD)

func draw_cab_gauges(size: Vector2, layout: Dictionary) -> void:
	var pult: Rect2 = layout.rect
	var radius = clampf((pult.position.x - 70.0) * 0.22, 46.0, 92.0)
	var y = float(layout.dash_top) + (size.y - float(layout.dash_top)) * 0.46
	var kind = canvas.model.vehicle_id()
	var speed = absf(float(canvas.model.state.v)) * 3.6
	var maximum = canvas.instruments.dial_maximum() if canvas.instruments != null else 30.0
	var nominal = canvas.instruments.nominal_speed() / maximum if canvas.instruments != null else 0.8
	var speed_zones = [[nominal * 0.72, Color("5cc17f")], [nominal, Color("e6b34a")], [1.0, Color("e0564a")]]
	var left = pult.position.x * 0.5
	draw_round_gauge(Vector2(left - radius * 1.1, y), radius, speed / maximum, "СКОРОСТЬ", "%.1f км/ч" % speed, speed_zones, 10, [0, roundi(maximum * 0.25), roundi(maximum * 0.5), roundi(maximum * 0.75), roundi(maximum)])
	var right = pult.end.x + (size.x - pult.end.x) * 0.5
	var stats = canvas.model.object_stats(kind)
	var amount = float(canvas.model.state.fleet_by_id[kind].fuel)
	var low_bad = [[0.15, Color("e0564a")], [0.35, Color("e6b34a")], [1.0, Color("5cc17f")]]
	if kind == "motorcar":
		draw_round_gauge(Vector2(left + radius * 1.1, y), radius, canvas.model.engine_rpm() / 6000.0, "ОБОРОТЫ", "%.1f тыс" % (canvas.model.engine_rpm() / 1000.0), [[0.7, Color("5cc17f")], [0.88, Color("e6b34a")], [1.0, Color("e0564a")]], 6, [0, 1, 2, 3, 4, 5, 6])
		draw_round_gauge(Vector2(pult.end.x + 36.0 + radius + 8.0, y), radius, amount / float(stats.tank), "БЕНЗИН", "%.2f л" % amount, low_bad, 4, ["0", "", "1/2", "", "П"])
	elif kind == "pneumatic":
		draw_round_gauge(Vector2(left + radius * 1.1, y), radius, amount / float(stats.tank), "ДАВЛЕНИЕ", "%.0f бар" % amount, [[0.4, Color("e0564a")], [0.7, Color("e6b34a")], [1.0, Color("5cc17f")]], 10, [0, int(stats.tank * 0.2), int(stats.tank * 0.4), int(stats.tank * 0.6), int(stats.tank * 0.8), int(stats.tank)])
		draw_round_gauge(Vector2(right - radius * 0.9, y), radius, canvas.model.frost(), "ИНЕЙ", "%d%%" % roundi(canvas.model.frost() * 100.0), [[0.3, Color("5cc17f")], [0.6, Color("e6b34a")], [1.0, Color("e0564a")]], 4, ["0", "", "50", "", "100"])
		draw_round_gauge(Vector2(right + radius * 1.1 + 28.0, y), radius, canvas.model.working_pressure() / float(stats.tank), "РАБОЧЕЕ", "%.0f бар" % canvas.model.working_pressure(), [[0.2, Color("e6b34a")], [0.7, Color("5cc17f")], [1.0, Color("e6b34a")]], 10, [0, 10, 20, 30, 40, 50])
	elif kind == "steam":
		var work = float(canvas.model.boiler_cfg().work_pressure_bar) / float(canvas.model.boiler_cfg().max_pressure_bar)
		draw_round_gauge(Vector2(left + radius * 1.1, y), radius, float(canvas.model.boiler().pressure), "ДАВЛЕНИЕ", "%.1f бар" % canvas.model.pressure_bar(), [[work, Color("e6b34a")], [0.9, Color("5cc17f")], [1.0, Color("e0564a")]], 10, [0, 2, 4, 6, 8, 10])
		var water = float(canvas.model.state.fleet_by_id.steam.get("water", 0))
		draw_round_gauge(Vector2(right - radius * 0.9, y), radius, water / float(stats.water), "ВОДА", "%.0f л" % water, low_bad, 4, ["0", "", "1/2", "", "П"])
	else:
		draw_round_gauge(Vector2(left + radius * 1.1, y), radius, amount / float(stats.tank), "ЗАРЯД", "%d%%" % roundi(amount / float(stats.tank) * 100), low_bad, 10, [0, 25, 50, 75, 100])
		var charge = amount / float(stats.tank)
		var volts = clampf(40.0 + 9.0 * charge - 4.0 * float(canvas.model.state.throttle), 0.0, 60.0)
		var speed_share = clampf(absf(float(canvas.model.state.v)) / float(stats.speeds[0]), 0.0, 1.0)
		var amps = float(canvas.model.state.throttle) * 260.0 * (1.0 - 0.5 * speed_share) * (1.0 if amount > 0.0 else 0.0) - canvas.model.regen_kw * 1000.0 / maxf(volts, 1.0)
		var first = pult.end.x + 36.0 + radius + 8.0
		draw_round_gauge(Vector2(first, y), radius, volts / 60.0, "ВОЛЬТМЕТР", "%.0f В" % volts, [[0.7, Color("e0564a")], [0.9, Color("5cc17f")], [1.0, Color("e6b34a")]], 6, [0, 10, 20, 30, 40, 50, 60])
		draw_round_gauge(Vector2(first + radius * 2.0 + 28.0, y), radius, clampf((amps + 100.0) / 400.0, 0.0, 1.0), "АМПЕРМЕТР", "%.0f А" % amps, [[0.25, Color("78b8d8")], [0.75, Color("5cc17f")], [0.9, Color("e6b34a")], [1.0, Color("e0564a")]], 8, [-100, 0, 100, 200, 300])
