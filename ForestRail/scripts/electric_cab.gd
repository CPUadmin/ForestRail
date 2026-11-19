extends RefCounted
# Помощник main.gd: новая кабина электровоза (просьба владельца 19.11: «за основу бери как у паровоза»; и сразу же:
# «каждая кабина должна быть уникальной»). Подход паровоза: стена с окнами в одной раме, рисованная доска из трёх
# секций, рисованный капот впереди. Но рама и доска у электровоза СВОИ (пакет GPT П32), не паровозные.
# Слева «ПИТАНИЕ»: вольтметр, амперметр, ящик КОНТАКТОР («Скрутка») и аварийный тормоз; посередине «УПРАВЛЕНИЕ»:
# тормоз и тяга (ручки в прорезях), направление, лампы, часы; справа «ПРИБОРЫ»: скорость, заряд и нагрев мотора.
# Пока своих картинок нет, электровоз остаётся в прежней кабине (revised() ложно). Прежнюю кабину и потом можно
# открыть запуском с --classic-electric-cab.

var canvas = null   # main.gd
var classic = "--classic-electric-cab" in OS.get_cmdline_user_args()
const WALL_PATH = "res://assets/art_cab/electric_window_wall.png"   # П32
const BOARD_PATH = "res://assets/art_cab/electric_board.png"         # П32

func art_ready() -> bool:
	return ResourceLoader.exists(WALL_PATH) and ResourceLoader.exists(BOARD_PATH)

const POWER_X = 0.164
const CONTROL_X = 0.486
const INSTRUMENTS_X = 0.824
const LABEL_Y = 0.145

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func revised() -> bool:
	return not classic and art_ready() and canvas.cab_active() and canvas.model.vehicle_id() == "locomotive"

# a point of the board: x across the screen, y from the top of the board (0) to the bottom of the screen (1)
func at(size: Vector2, top: float, x: float, y: float) -> Vector2:
	return Vector2(size.x * x, lerpf(top, size.y, y))

func gauge_radius(size: Vector2, top: float) -> float:
	return minf(size.x * 0.055, (size.y - top) * 0.166)

func fleet() -> Dictionary:
	return canvas.model.state.fleet_by_id.locomotive

func charge() -> float:
	return float(fleet().fuel) / maxf(0.001, float(canvas.model.object_stats("locomotive").tank))

func centered(text: String, point: Vector2, width: float, pixels: int, color: Color) -> void:
	canvas.draw_string(canvas.font, point - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, width, pixels, color)

# the whole board except the pult in the middle (the levers are drawn by main.gd in the pult) and the round gauges
func draw_board(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	for group in [[POWER_X, "ПИТАНИЕ"], [CONTROL_X, "УПРАВЛЕНИЕ"], [INSTRUMENTS_X, "ПРИБОРЫ"]]:
		var pos = at(size, top, group[0], LABEL_Y)
		centered(group[1], pos, 210, 21, Color("f1dfaf"))
		canvas.draw_line(pos + Vector2(-43, 9), pos + Vector2(43, 9), Color("aa8854"), 1.5)
	draw_power(size, top)
	draw_lamps(size, top)
	draw_motor_bar(size, top)

# Left: the contactor box with its pilot lamp, the high-voltage plate and the red mushroom of the emergency brake.
func draw_power(size: Vector2, top: float) -> void:
	var brass = Color("c9a85a")
	var s = clampf((size.y - top) / 480.0, 0.7, 1.3)
	# the contactor hatch: a click opens the box «Скрутка» (1.4.10)
	var hatch_size = Vector2(96, 106) * s
	var hatch = Rect2(at(size, top, POWER_X - 0.072, 0.72) - hatch_size * 0.5, hatch_size)
	canvas.draw_texture_rect(canvas.CONTACTOR_HATCH, hatch, false)
	var pilot = hatch.position + Vector2(hatch.size.x * 0.46, hatch.size.y * 0.2)
	var energized = bool(canvas.model.state.engine) and canvas.sound.contactor_on
	canvas.draw_circle(pilot, 6.5 * s, Color("382819"))
	canvas.draw_circle(pilot, 4.2 * s, canvas.GOLD if energized else Color("695732"))
	if energized: canvas.draw_circle(pilot, 11.0 * s, Color(canvas.GOLD, 0.25))
	centered("Контактор", Vector2(hatch.get_center().x, hatch.end.y + 20 * s), 160, 17, canvas.PAPER)
	if canvas.model.contactor_rules: canvas.cab_hits.append({"id": "contactor", "rect": hatch})
	# the emergency brake: drops traction and pulls the brake
	var button = at(size, top, POWER_X + 0.072, 0.70)
	var r = 27.0 * s
	canvas.draw_circle(button + Vector2(2, 3) * s, r + 5 * s, Color(0, 0, 0, 0.35))
	canvas.draw_circle(button, r + 4 * s, Color("3a1512"))
	canvas.draw_circle(button, r, Color("c23b2e"))
	canvas.draw_circle(button + Vector2(-0.3, -0.33) * r, r * 0.3, Color(1, 1, 1, 0.3))
	canvas.draw_arc(button, r + 4 * s, 0, TAU, 28, brass, 2.5, true)
	centered("Аварийный тормоз", button + Vector2(0, r + 30 * s), 200, 17, canvas.PAPER)
	canvas.cab_hits.append({"id": "emergency", "rect": Rect2(button - Vector2.ONE * (r + 6 * s), Vector2.ONE * (r + 6 * s) * 2.0)})
	# the high-voltage plate beside the name of the section
	var tri = at(size, top, POWER_X - 0.1, LABEL_Y) + Vector2(0, -6 * s)
	var t = 15.0 * s
	canvas.draw_colored_polygon(PackedVector2Array([tri + Vector2(0, -t), tri + Vector2(t * 1.1, t), tri + Vector2(-t * 1.1, t)]), Color("e6c13a"))
	canvas.draw_polyline(PackedVector2Array([tri + Vector2(0, -t), tri + Vector2(t * 1.1, t), tri + Vector2(-t * 1.1, t), tri + Vector2(0, -t)]), Color("2a2218"), 2.0, true)
	var bolt = PackedVector2Array([Vector2(2, -9), Vector2(-5, 3), Vector2(0, 3), Vector2(-3, 10), Vector2(5, -2), Vector2(1, -2)])
	for i in range(bolt.size()): bolt[i] = tri + bolt[i] * s * 0.95
	canvas.draw_colored_polygon(bolt, Color("1a1612"))

# Middle, under the levers: ХОД, ПИТАНИЕ, ТОРМОЗ, НИЗКИЙ ЗАРЯД, РЕКУП.; the start of the engine runs along them as a flash.
func draw_lamps(size: Vector2, top: float) -> void:
	var regen = canvas.model.regen_kw > 0.01
	var lamps = [["ХОД", absf(float(canvas.model.state.v)) > 0.1, Color("5cc17f")],
		["ПИТАНИЕ", bool(canvas.model.state.engine) and float(fleet().fuel) > 0.0, Color("e6b34a")],
		["ТОРМОЗ", float(canvas.model.state.brake) > 0.1, Color("e0564a")],
		["МАЛО ЗАРЯДА", charge() < 0.25, Color("e0564a")],
		["РЕКУП.", regen, Color("6cc4e0")]]
	var spacing = size.x * 0.057
	var origin = at(size, top, 0.372, 0.865)
	for i in range(lamps.size()):
		var lamp_at = origin + Vector2(i * spacing, 0)
		var sweep = 0.0
		if canvas.electric_start_flash > 0.0 and canvas.light_flicker_enabled():
			sweep = clampf(1.0 - absf((1.0 - canvas.electric_start_flash / canvas.ELECTRIC_START_FLASH) * 5.0 - float(i)), 0.0, 1.0)
		canvas.draw_circle(lamp_at, 9, Color("0c100e"))
		canvas.draw_circle(lamp_at, 7, lamps[i][2] if lamps[i][1] else lamps[i][2].darkened(0.75))
		if lamps[i][1]: canvas.draw_circle(lamp_at, 16, Color(lamps[i][2], 0.22))
		if sweep > 0.0: canvas.draw_circle(lamp_at, 12, Color(0.8, 0.93, 1.0, sweep * 0.6))
		centered(lamps[i][0], lamp_at + Vector2(0, 25), spacing, 12, Color("dfceb0"))

# Right, under the gauges: the warmth of the motor as one bar (as the water of the steam engine); over 85% the pull weakens.
func draw_motor_bar(size: Vector2, top: float) -> void:
	var temp = clampf(canvas.model.engine_temp(), 0.0, 1.0)
	var glass = Rect2(at(size, top, INSTRUMENTS_X, 0.74) - Vector2(100, 0), Vector2(200, 13))
	canvas.draw_style_box(canvas.style(Color("142022"), Color("a38a55"), 5), glass.grow(3))
	var color = Color("5cc17f") if temp < 0.7 else (Color("e6b34a") if temp < 0.85 else Color("e0564a"))
	canvas.draw_rect(Rect2(glass.position, Vector2(glass.size.x * temp, glass.size.y)), color.darkened(0.15))
	for mark in [0.7, 0.85]:
		var x = glass.position.x + glass.size.x * mark
		canvas.draw_line(Vector2(x, glass.position.y), Vector2(x, glass.end.y + 5), Color("f5e9c9"), 1.5)
	centered("Мотор  ·  %d°" % roundi(20.0 + temp * 100.0), glass.get_center() + Vector2(0, 36), 260, 18, canvas.PAPER)

# The round gauges: speed and charge on the right (as the speed and the pressure of the steam engine), the voltmeter and
# the ammeter on the left, a little smaller, above the contactor.
func draw_gauges(size: Vector2, layout: Dictionary, speed_args: Array, art) -> void:
	var top = float(layout.dash_top)
	var r = gauge_radius(size, top)
	var y = top + (size.y - top) * 0.46
	var right = size.x * INSTRUMENTS_X
	art.draw_round_gauge(Vector2(right - r * 1.1, y), r, speed_args[0], "СКОРОСТЬ", speed_args[1], speed_args[2], 10, speed_args[3])
	var low_bad = [[0.15, Color("e0564a")], [0.35, Color("e6b34a")], [1.0, Color("5cc17f")]]
	art.draw_round_gauge(Vector2(right + r * 1.1, y), r, charge(), "ЗАРЯД", "%d%%" % roundi(charge() * 100), low_bad, 10, [0, 25, 50, 75, 100])
	var stats = canvas.model.object_stats("locomotive")
	var volts = clampf(40.0 + 9.0 * charge() - 4.0 * float(canvas.model.state.throttle), 0.0, 60.0)
	var speed_share = clampf(absf(float(canvas.model.state.v)) / float(stats.speeds[0]), 0.0, 1.0)
	var amps = float(canvas.model.state.throttle) * 260.0 * (1.0 - 0.5 * speed_share) * (1.0 if float(fleet().fuel) > 0.0 else 0.0) - canvas.model.regen_kw * 1000.0 / maxf(volts, 1.0)
	var small = r * 0.86
	var left = size.x * POWER_X
	var gy = top + (size.y - top) * 0.38
	art.draw_round_gauge(Vector2(left - small * 1.18, gy), small, volts / 60.0, "ВОЛЬТЫ", "%.0f В" % volts, [[0.7, Color("e0564a")], [0.9, Color("5cc17f")], [1.0, Color("e6b34a")]], 6, [0, 20, 40, 60])
	art.draw_round_gauge(Vector2(left + small * 1.18, gy), small, clampf((amps + 100.0) / 400.0, 0.0, 1.0), "АМПЕРЫ", "%.0f А" % amps, [[0.25, Color("78b8d8")], [0.75, Color("5cc17f")], [0.9, Color("e6b34a")], [1.0, Color("e0564a")]], 8, [-100, 0, 100, 200, 300])
