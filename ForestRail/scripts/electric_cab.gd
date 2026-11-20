extends RefCounted
# Помощник main.gd: своя кабина электровоза «Подстанция» (выпуск 1.12, решения владельца 19–20.11).
# Устройство как у паровоза (стена с окнами в одной раме, рисованная доска, рисованный капот), но рисунок свой:
# картинки GPT П34 (кабина) и П33 (шкафчик), нарезаны tools/cut_electric_cab.py. Раскладка — эскиз 6 владельца:
#   слева «Питание»: дверца шкафчика с окошком, табличка-молния, рубильник, аварийный тормоз;
#   посередине «Управление»: полоска заряда, часы, тумблер направления, ручки тормоза и тяги, пять ламп,
#   гудок, тумблеры фары и дворников;
#   справа «Приборы»: спидометр, амперметр с нулём посередине, неоновый термометр мотора.
# Стрелки, столбик, огоньки, дворники рисует код. Пока электровоз не запущен, приборы мёртвые (слово владельца).
# Прежнюю кабину можно открыть запуском с --classic-electric-cab.

var canvas = null   # main.gd
var classic = "--classic-electric-cab" in OS.get_cmdline_user_args()
const DIR = "res://assets/art_cab/electric/"
const WALL_PATH = DIR + "window_wall.png"
const BOARD_PATH = DIR + "board.png"
var tex = {}
# the wall picture: the whole canvas; the side openings with a little of their frame (pixels of window_wall.png)
const WALL_ART = Rect2(0, 0, 2172, 724)
const LEFT_LIGHT = Rect2(52, 160, 163, 498)
const RIGHT_LIGHT = Rect2(1955, 160, 164, 498)
const FRONT_HOLES = [Rect2(297, 170, 742, 478), Rect2(1134, 170, 739, 478)]
const SELFTEST_S = 1.2   # after the start the needle sweeps and the charge bar fills, as in a car
var was_live = false
var selftest_t = 0.0

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func art_ready() -> bool:
	return ResourceLoader.exists(WALL_PATH) and ResourceLoader.exists(BOARD_PATH)

func t(name: String) -> Texture2D:
	if not tex.has(name): tex[name] = load(DIR + name + ".png") if ResourceLoader.exists(DIR + name + ".png") else load("res://assets/art_electric/cabinet/" + name + ".png")
	return tex[name]

func revised() -> bool:
	return not classic and art_ready() and canvas.cab_active() and canvas.model.vehicle_id() == "locomotive"

# --- the wall (shared interface with steam_cab.gd: main.wall_cab())
var WINDOW_WALL: Texture2D:
	get:
		return t("window_wall")

func side_art(side: float) -> Rect2:
	return LEFT_LIGHT if side < 0.0 else RIGHT_LIGHT

func side_rect(size: Vector2, top: float, side: float) -> Rect2:
	var region = side_art(side)
	var k = Vector2(size.x, top) / WALL_ART.size
	return Rect2((region.position - WALL_ART.position) * k, region.size * k)

func wall_tint() -> Color:
	return Color.WHITE.darkened(canvas.model.night_amount() * 0.26)

func draw_window_wall(size: Vector2, top: float) -> void:
	var k = Vector2(size.x, top) / WALL_ART.size
	# the picture has rounded outer corners: fill them with the wall's own dark green
	for corner in [Vector2(0, 0), Vector2(size.x - 50 * k.x, 0), Vector2(0, top - 50 * k.y), Vector2(size.x - 50 * k.x, top - 50 * k.y)]:
		canvas.draw_rect(Rect2(corner, Vector2(50 * k.x, 50 * k.y)), Color("1d3324").darkened(canvas.model.night_amount() * 0.26))
	canvas.draw_texture_rect(t("window_wall"), Rect2(0, 0, size.x, top), false, wall_tint())
	draw_wipers(k)
	var board = Rect2(0, top, size.x, size.y - top)
	canvas.draw_rect(board, Color("1d3324"))
	canvas.draw_texture_rect(t("board"), board, false, Color.WHITE.darkened(canvas.model.night_amount() * 0.22))

# parked at the bottom left of each front window; they sweep while switched on (main.wiper_phase)
func draw_wipers(k: Vector2) -> void:
	var swing = 0.5 - 0.5 * cos(canvas.wiper_phase * TAU)   # 0 parked at the start and the end of a sweep
	for hole in FRONT_HOLES:
		var pivot = Vector2(hole.position.x + hole.size.x * 0.22, hole.end.y - 6) * k
		var length = hole.size.y * 0.86 * k.y
		var angle = lerpf(-0.06, -PI * 0.72, swing)   # 0 = lying along the bottom to the right
		var tip = pivot + Vector2.from_angle(angle) * length
		canvas.draw_line(pivot, tip, Color("2a2a27"), maxf(2.0, 5.0 * k.y), true)
		canvas.draw_line(pivot + (tip - pivot) * 0.18, tip, Color("0f0f0e"), maxf(3.0, 8.0 * k.y), true)
		canvas.draw_circle(pivot, maxf(4.0, 9.0 * k.y), Color("b08a3e"))

# --- the hood ahead, in place of the steam boiler (cab_art.draw_cab_nose)
func draw_hood_ahead(cx: float, view: Rect2) -> void:
	var height = view.size.y * 0.52
	var hood = Rect2(cx - 0.75 * height, view.end.y - height, 1.5 * height, height)
	canvas.draw_texture_rect(t("hood_forward"), hood, false)
	if canvas.lights_lit():
		# the brass lamp at the far end of the hood shines (its glass in the picture: 50% across, 15% down)
		var lamp = hood.position + hood.size * Vector2(0.5, 0.15)
		var glow = clampf(0.35 + canvas.model.night_amount() * 0.65, 0.0, 1.0)
		for ring in range(4): canvas.draw_circle(lamp, height * (0.025 + ring * 0.03), Color(1.0, 0.9, 0.55, (0.5 - ring * 0.11) * glow), true, -1, true)

# --- the board
func at(size: Vector2, top: float, x: float, y: float) -> Vector2:
	return Vector2(size.x * x, lerpf(top, size.y, y))

# 20.11 (owner: «всё неровно»): every part is placed on a grid inside the marble of its panel. PANELS are the marble
# edges across the screen and MARBLE_Y its top and bottom on the board, measured on board.png; u and v run 0..1 inside.
const PANELS = [[0.0272, 0.3117], [0.3370, 0.6588], [0.6842, 0.9751]]
const MARBLE_Y = [0.06, 0.92]

func pat(size: Vector2, top: float, panel: int, u: float, v: float) -> Vector2:
	return Vector2(size.x * lerpf(PANELS[panel][0], PANELS[panel][1], u), lerpf(top, size.y, lerpf(MARBLE_Y[0], MARBLE_Y[1], v)))

func marble_h(size: Vector2, top: float) -> float:
	return (size.y - top) * (MARBLE_Y[1] - MARBLE_Y[0])

# a picture centred on a point, sized by its height
func put(name: String, centre: Vector2, height: float, color: Color = Color.WHITE) -> Rect2:
	var tx = t(name)
	var w = height * float(tx.get_width()) / float(tx.get_height())
	var rect = Rect2(centre - Vector2(w, height) * 0.5, Vector2(w, height))
	canvas.draw_texture_rect(tx, rect, false, color)
	return rect

func live() -> bool:
	return bool(canvas.model.state.engine)

func fleet() -> Dictionary:
	return canvas.model.state.fleet_by_id.locomotive

func charge() -> float:
	return clampf(float(fleet().fuel) / maxf(0.001, float(canvas.model.object_stats("locomotive").tank)), 0.0, 1.0)

func amps() -> float:
	if not live(): return 0.0
	var stats = canvas.model.object_stats("locomotive")
	var volts = clampf(40.0 + 9.0 * charge() - 4.0 * float(canvas.model.state.throttle), 0.0, 60.0)
	var speed_share = clampf(absf(float(canvas.model.state.v)) / float(stats.speeds[0]), 0.0, 1.0)
	return float(canvas.model.state.throttle) * 260.0 * (1.0 - 0.5 * speed_share) * (1.0 if float(fleet().fuel) > 0.0 else 0.0) - canvas.model.regen_kw * 1000.0 / maxf(volts, 1.0)

func draw_board(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var hb = size.y - top
	if live() and not was_live: selftest_t = SELFTEST_S
	was_live = live()
	selftest_t = maxf(0.0, selftest_t - canvas.get_process_delta_time())
	draw_power(size, top, hb)
	draw_middle(size, top, hb)

func draw_power(size: Vector2, top: float, hb: float) -> void:
	var mh = marble_h(size, top)
	var door = put("cabinet_door", pat(size, top, 0, 0.31, 0.5), mh * 0.8)
	if canvas.model.contactor_rules: canvas.cab_hits.append({"id": "contactor", "rect": door})
	put("hv_plate", pat(size, top, 0, 0.79, 0.165), mh * 0.13)
	put("switch_on" if live() else "switch_off", pat(size, top, 0, 0.79, 0.455), mh * 0.40)
	var button = put("emergency_button", pat(size, top, 0, 0.79, 0.79), mh * 0.22)
	canvas.cab_hits.append({"id": "emergency", "rect": button})

func draw_middle(size: Vector2, top: float, hb: float) -> void:
	# the charge bar: twelve segments, red on the left to green on the right; dark until the start
	var mh = marble_h(size, top)
	var bar = put("charge_bar", pat(size, top, 1, (COL_BRAKE + COL_TRACTION) * 0.5, 0.12), mh * 0.11)
	var inner = Rect2(bar.position + bar.size * Vector2(0.075, 0.27), bar.size * Vector2(0.85, 0.46))
	var shown = charge() * (1.0 - selftest_t / SELFTEST_S)   # after the start it fills up to the real charge
	var lit = roundi(shown * 12.0) if live() else 0
	for i in range(12):
		var seg = Rect2(inner.position + Vector2(inner.size.x * i / 12.0 + 1.0, 0), Vector2(inner.size.x / 12.0 - 2.0, inner.size.y))
		if i < lit:
			var hue = Color.from_hsv(lerpf(0.0, 0.33, i / 11.0), 0.85, 0.95)
			canvas.draw_rect(seg, hue)
			canvas.draw_rect(seg.grow(2.0), Color(hue, 0.18))
	# the clock
	var clock = put("clock", pat(size, top, 1, COL_RIGHT, 0.12), mh * 0.2)
	var c = clock.get_center()
	var r = clock.size.x * 0.36
	var minutes = fposmod(canvas.model.world_hours() * 60.0, 60.0)
	var hours = fposmod(canvas.model.world_hours(), 12.0)
	canvas.draw_line(c, c + Vector2.from_angle(TAU * minutes / 60.0 - PI / 2) * r, Color("2a2218"), 1.5, true)
	canvas.draw_line(c, c + Vector2.from_angle(TAU * hours / 12.0 - PI / 2) * r * 0.62, Color("2a2218"), 2.5, true)
	canvas.draw_circle(c, 2.0, Color("a8231c"))
	# the direction toggle: left = back, right = forward; a click flips it
	var forward = int(canvas.model.state.get("reverser", 1)) >= 0
	var toggle = put("toggle_right" if forward else "toggle_left", pat(size, top, 1, COL_RIGHT, 0.5), mh * 0.12)   # under the clock, level with the middle of the slots
	draw_arrow(toggle, -1.0, not forward)
	draw_arrow(toggle, 1.0, forward)
	canvas.cab_hits.append({"id": "back" if forward else "forward", "rect": toggle.grow(6.0)})
	# the five lamps: ход, питание, тормоз, мало заряда, рекуперация
	var lamps = [absf(float(canvas.model.state.v)) > 0.1, live() and float(fleet().fuel) > 0.0, float(canvas.model.state.brake) > 0.1, charge() < 0.25, canvas.model.regen_kw > 0.01]
	var colors = [Color("5cc17f"), Color("e6b34a"), Color("e0564a"), Color("e0564a"), Color("6cc4e0")]
	for i in range(5):
		var sweep = 0.0
		if canvas.electric_start_flash > 0.0 and canvas.light_flicker_enabled():
			sweep = clampf(1.0 - absf((1.0 - canvas.electric_start_flash / canvas.ELECTRIC_START_FLASH) * 5.0 - float(i)), 0.0, 1.0)
		var socket = put("lamp_socket", pat(size, top, 1, 0.14 + i * 0.18, 0.745), mh * 0.085)
		var on = live() and bool(lamps[i])
		var glass = socket.get_center()
		var gr = socket.size.x * 0.3
		if on:
			canvas.draw_circle(glass, gr * 2.3, Color(colors[i], 0.22), true, -1, true)
			canvas.draw_circle(glass, gr * 1.15, colors[i].lightened(0.15), true, -1, true)
			canvas.draw_circle(glass, gr * 0.6, colors[i].lightened(0.55), true, -1, true)
			canvas.draw_circle(glass + Vector2(-gr * 0.35, -gr * 0.4), gr * 0.25, Color(1, 1, 1, 0.6), true, -1, true)
		else:
			canvas.draw_circle(glass, gr, Color(colors[i].darkened(0.7), 0.55), true, -1, true)
		if sweep > 0.0: canvas.draw_circle(glass, gr * 1.4, Color(0.8, 0.93, 1.0, sweep * 0.6), true, -1, true)
	# the horn, the headlamp toggle and the wiper toggle, with little pictures above them
	var specs = [["whistle", COL_BRAKE], ["light", 0.5], ["wiper", COL_RIGHT]]
	for spec in specs:
		var centre = pat(size, top, 1, spec[1], 0.935)
		var rect: Rect2
		if spec[0] == "whistle": rect = put("horn_button", centre, mh * 0.095)
		else:
			var on = canvas.lights_lit() if spec[0] == "light" else canvas.wiper_on
			rect = put("toggle_up" if on else "toggle_down", centre, mh * 0.11)
		draw_pictogram(str(spec[0]), pat(size, top, 1, spec[1], 0.835), mh * 0.033)
		canvas.cab_hits.append({"id": spec[0], "rect": rect.grow(4.0)})

func draw_arrow(toggle: Rect2, side: float, lit: bool) -> void:
	var c = toggle.get_center() + Vector2(side * (toggle.size.x * 0.5 + 14.0), 0)
	var ink = canvas.GOLD if lit else Color("6f6656")
	canvas.draw_line(c - Vector2(side * 8, 0), c + Vector2(side * 6, 0), ink, 2.5, true)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(side * 10, 0), c + Vector2(side * 2, -6), c + Vector2(side * 2, 6)]), ink)

func draw_pictogram(id: String, c: Vector2, r: float) -> void:
	var ink = Color("3a2c1c")
	match id:
		"whistle":
			canvas.draw_rect(Rect2(c + Vector2(-r, -r * 0.35), Vector2(r * 0.9, r * 0.7)), ink)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.1, -r * 0.35), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r * 0.1, r * 0.35)]), ink)
		"light":
			canvas.draw_arc(c + Vector2(-r * 0.3, 0), r * 0.7, -PI * 0.5, PI * 0.5, 12, ink, 2.0, true)
			for k in range(3): canvas.draw_line(c + Vector2(r * 0.55, -r * 0.6 + k * r * 0.6), c + Vector2(r * 1.3, -r * 0.75 + k * r * 0.75), ink, 1.8, true)
		"wiper":
			canvas.draw_arc(c + Vector2(0, r * 0.8), r * 1.3, -PI * 0.85, -PI * 0.15, 12, ink, 1.8, true)
			canvas.draw_line(c + Vector2(0, r * 0.8), c + Vector2(r * 0.7, -r * 0.4), ink, 2.5, true)

# --- the right panel: the speedometer, the centre-zero ammeter, the neon thermometer of the motor
func draw_gauges(size: Vector2, layout: Dictionary, speed_args: Array, _art) -> void:
	var top = float(layout.dash_top)
	var hb = size.y - top
	var test = sin(clampf(1.0 - selftest_t / SELFTEST_S, 0.0, 1.0) * PI) if selftest_t > 0.0 else 0.0
	var speed = clampf(float(speed_args[0]), 0.0, 1.0) if live() else 0.0
	speed = maxf(speed, test)
	var mh = marble_h(size, top)
	var dial = put("speedometer", pat(size, top, 2, 0.38, 0.36), mh * 0.56)
	needle(dial.position + dial.size * Vector2(0.5, 0.86), dial.size.x * 0.37, PI - speed * PI)
	var a = amps()
	var share = clampf(a / 300.0, 0.0, 1.0) if a >= 0.0 else -clampf(-a / 100.0, 0.0, 1.0)
	var am = put("ammeter", pat(size, top, 2, 0.38, 0.80), mh * 0.24)
	needle(am.position + am.size * Vector2(0.5, 0.78), am.size.x * 0.36, PI * 0.5 - share * PI * 0.5)
	var th = put("thermometer", pat(size, top, 2, 0.84, 0.5), mh * 0.84)
	if live() or test > 0.0:
		var temp = maxf(clampf(canvas.model.engine_temp(), 0.0, 1.0), test * 0.9)
		var tube = Rect2(th.position + th.size * Vector2(0.17, 0.12), th.size * Vector2(0.33, 0.76))
		var column = Rect2(Vector2(tube.position.x, tube.end.y - tube.size.y * temp), Vector2(tube.size.x, tube.size.y * temp))
		var low = Color("49d8e6")
		var high = Color("b45ae0") if temp < 0.85 else Color("e04a8a")
		canvas.draw_rect(column.grow(3.0), Color(low.lerp(high, 0.5), 0.16))
		canvas.draw_polygon(PackedVector2Array([column.position, Vector2(column.end.x, column.position.y), column.end, Vector2(column.position.x, column.end.y)]), PackedColorArray([high, high, low, low]))
		if temp >= 0.85 and canvas.light_flicker_enabled() and fmod(canvas.time, 0.5) < 0.25:
			canvas.draw_rect(column.grow(5.0), Color(high, 0.25))

func needle(pivot: Vector2, length: float, angle: float) -> void:
	var tip = pivot + Vector2(cos(angle), -sin(angle)) * length
	canvas.draw_line(pivot + (pivot - tip) * 0.12, tip, Color("1c1a17"), 3.0, true)
	canvas.draw_circle(pivot, 5.0, Color("b08a3e"))

# --- the brake and traction handles slide in their slot plates (main.draw_control_zoom, pult coordinates)
const COL_BRAKE = 0.2
const COL_TRACTION = 0.5
const COL_RIGHT = 0.8
const SLIDER_U = {"brake": COL_BRAKE, "throttle": COL_TRACTION}
const SLOT_TOP = 0.38   # panel v: the knob at 100% rises above, clear of the charge bar
const SLOT_BOTTOM = 0.6

func slider_geometry(id: String) -> Dictionary:
	var size = canvas.get_viewport_rect().size
	var top = float(canvas.cab_layout(size).dash_top)
	var back = canvas.pult_t.affine_inverse()
	var bottom = back * pat(size, top, 1, SLIDER_U[id], SLOT_BOTTOM)
	var upper = back * pat(size, top, 1, SLIDER_U[id], SLOT_TOP)
	return {"pivot": bottom, "length": bottom.y - upper.y}

func draw_slider(id: String, geo: Dictionary) -> void:
	var size = canvas.get_viewport_rect().size
	var top = float(canvas.cab_layout(size).dash_top)
	var hb = size.y - top
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	put("slot_plate", pat(size, top, 1, SLIDER_U[id], (SLOT_TOP + SLOT_BOTTOM) * 0.5), marble_h(size, top) * 0.36)
	var grip = canvas.pult_t * Vector2(geo.grip)
	var handle = t("brake_handle" if id == "brake" else "traction_handle")
	var h = hb * (0.17 if id == "brake" else 0.2)
	var w = h * float(handle.get_width()) / float(handle.get_height())
	# the handle's tongue sits in the slot: the grip point is near the bottom of the picture
	canvas.draw_texture_rect(handle, Rect2(grip - Vector2(w * 0.5, h * 0.82), Vector2(w, h)), false)
	canvas.draw_set_transform_matrix(canvas.pult_t)
