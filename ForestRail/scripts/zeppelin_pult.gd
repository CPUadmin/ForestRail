extends RefCounted
# В6.5, шаг 3: кабина рельсового цеппелина. Пульт нарисован кодом и живёт отдельно от общих рычагов: у цеппелина другие органы
# (газ, шаг винта, джойстик, тормоз, воздушный тормоз, пуск) и все они ДЕРЖАТ положение, как в самолёте. Приборы: воздушная
# скорость, обороты (зелёная дуга и красная зона), температура мотора, нагрузка на колёса (зелёная зона 10-20%), высота, топливо.
# Размеры в условных единицах W x H, масштаб k и начало origin задаёт main.gd (в мире меньше, в кабине крупнее).

const W = 840.0
const H = 190.0
const SLIDER_IDS = ["throttle", "pitch", "stick", "brake"]
const SLIDER_TITLES = {"throttle": "Газ", "pitch": "Шаг", "stick": "Ручка", "brake": "Тормоз"}
const SLIDER_COLORS = {"throttle": Color("4f9a5f"), "pitch": Color("d0a23c"), "stick": Color("5f8fc4"), "brake": Color("c23b2e")}
const PAPER = Color("efe8cf")
const GOLD = Color("d9b95b")
const RED = Color("c23b2e")
const GREEN = Color("5fae6a")
const PANEL = Color(0.07, 0.11, 0.10, 0.93)
const EDGE = Color("6f7f64")
const SPEED_MAX_KMH = 160.0
const RPM_MAX_SHOWN = 3200.0

var origin = Vector2.ZERO
var k = 1.0
var active = ""          # the slider that is dragged now
var model = null
var font = null

func place(new_origin: Vector2, scale: float) -> void:
	origin = new_origin
	k = scale

func rect(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(origin + Vector2(x, y) * k, Vector2(w, h) * k)

func bounds() -> Rect2:
	return rect(0.0, 0.0, W, H)

func track(index: int) -> Rect2:
	return rect(22.0 + 72.0 * index, 50.0, 32.0, 108.0)

func start_button() -> Rect2:
	return rect(312.0, 52.0, 78.0, 44.0)

func air_button() -> Rect2:
	return rect(312.0, 106.0, 78.0, 44.0)

func trim_button() -> Rect2:
	return rect(312.0, 154.0, 78.0, 22.0)

# the value of a slider 0..1 (the stick is the angle of attack mapped onto its travel)
func slider_value(id: String) -> float:
	match id:
		"throttle": return clampf(float(model.state.throttle), 0.0, 1.0)
		"pitch": return model.zeppelin_pitch()
		"stick": return clampf((model.zeppelin_stick() + 6.0) / 18.0, 0.0, 1.0)
		"brake": return clampf(float(model.state.brake), 0.0, 1.0)
	return 0.0

func set_slider(id: String, level: float) -> void:
	if id == "stick": model.state.zep_trim = false   # the hand takes the stick back from the trim
	level = clampf(level, 0.0, 1.0)
	if level < 0.02: level = 0.0
	elif level > 0.98: level = 1.0
	match id:
		"throttle": model.state.throttle = level
		"pitch": model.set_zeppelin_pitch(level)
		"stick":
			model.set_zeppelin_stick(level * 18.0 - 6.0)
			if absf(model.zeppelin_stick()) < 0.35: model.set_zeppelin_stick(0.0)   # a click at the level flight
		"brake":
			model.state.brake = level
			model.auto_brake = false

func level_at(index: int, pos: Vector2) -> float:
	var t = track(index)
	return 1.0 - (pos.y - t.position.y) / t.size.y

# --- the mouse: returns true when the pult took the click
func press(pos: Vector2) -> bool:
	if model == null or not bounds().has_point(pos): return false
	for i in range(SLIDER_IDS.size()):
		if track(i).grow(12.0 * k).has_point(pos):
			active = SLIDER_IDS[i]
			set_slider(active, level_at(i, pos))
			return true
	if start_button().has_point(pos):
		if bool(model.zep.stalled) or not bool(model.state.engine): model.zeppelin_restart()
		return true
	if model.zeppelin_trim_installed() and trim_button().has_point(pos):
		model.set_zeppelin_trim(not bool(model.state.get("zep_trim", false)))
		return true
	if air_button().has_point(pos):
		model.set_zeppelin_air_brake(not bool(model.state.get("zep_air_brake", false)))
		return true
	return true   # the panel itself: the click does not fall through to the world

func motion(pos: Vector2) -> void:
	if active == "" or model == null: return
	set_slider(active, level_at(SLIDER_IDS.find(active), pos))

func release() -> void:
	active = ""

# --- drawing
func box(canvas, r: Rect2, fill: Color, border: Color, radius: int = 6, width: int = 1) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	canvas.draw_style_box(s, r)

func text(canvas, pos: Vector2, value: String, size: int, color: Color, width: float = 100.0, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	canvas.draw_string(font, origin + pos * k, value, align, width * k, int(round(size * k)), color)

func draw(canvas, mouse: Vector2) -> void:
	if model == null or font == null: return
	var zep = model.zep
	box(canvas, bounds(), PANEL, EDGE, 8, 2)
	for i in range(SLIDER_IDS.size()):
		draw_slider(canvas, i, mouse)
	draw_buttons(canvas)
	draw_trim(canvas)
	draw_airspeed(canvas, zep)
	draw_revs(canvas, zep)
	draw_bars(canvas, zep)
	draw_warning(canvas, zep)

func draw_slider(canvas, index: int, mouse: Vector2) -> void:
	var id = SLIDER_IDS[index]
	var t = track(index)
	var color = SLIDER_COLORS[id]
	var level = slider_value(id)
	text(canvas, Vector2(22.0 + 72.0 * index - 14.0, 40.0), SLIDER_TITLES[id], 15, PAPER, 60.0)
	box(canvas, Rect2(t.position + Vector2(t.size.x * 0.38, 0.0), Vector2(t.size.x * 0.24, t.size.y)), Color("0d1412"), Color("56635f"), 3)
	# ticks every fifth of the travel, the level flight of the stick is marked
	for tick in range(6):
		var y = t.end.y - t.size.y * tick / 5.0
		canvas.draw_line(Vector2(t.position.x, y), Vector2(t.position.x + t.size.x * 0.3, y), Color("56635f"), 1.0)
	if id == "stick":
		var zero_y = t.end.y - t.size.y * (6.0 / 18.0)
		canvas.draw_line(Vector2(t.position.x - 4.0 * k, zero_y), Vector2(t.end.x + 4.0 * k, zero_y), GOLD, 1.5 * k)
		var takeoff_y = t.end.y - t.size.y * ((float(model.vehicle_base("zeppelin").zeppelin.takeoff_alpha) + 6.0) / 18.0)
		canvas.draw_line(Vector2(t.position.x - 4.0 * k, takeoff_y), Vector2(t.end.x + 4.0 * k, takeoff_y), GREEN, 1.5 * k)
	# the pitch that fits the speed now: a mark beside the lever
	if id == "pitch":
		var fit = clampf((absf(model.zep.v) + 2.0 - 10.0) / 24.0, 0.0, 1.0)
		var fy = t.end.y - t.size.y * fit
		var tri = PackedVector2Array([Vector2(t.end.x + 6.0 * k, fy), Vector2(t.end.x + 15.0 * k, fy - 6.0 * k), Vector2(t.end.x + 15.0 * k, fy + 6.0 * k)])
		canvas.draw_colored_polygon(tri, GREEN)
	var knob = Rect2(Vector2(t.position.x - 3.0 * k, t.end.y - t.size.y * level - 8.0 * k), Vector2(t.size.x + 6.0 * k, 16.0 * k))
	box(canvas, knob, color, PAPER if active == id or knob.grow(6.0).has_point(mouse) else Color("1b2320"), 4, 1)
	canvas.draw_line(knob.position + Vector2(5.0 * k, knob.size.y * 0.5), knob.position + Vector2(knob.size.x - 5.0 * k, knob.size.y * 0.5), Color(1, 1, 1, 0.45), 1.5 * k)
	var label = "%d%%" % roundi(level * 100.0)
	if id == "stick": label = "%+.1f°" % model.zeppelin_stick()
	text(canvas, Vector2(22.0 + 72.0 * index - 14.0, 178.0), label, 14, GOLD, 60.0)

func draw_buttons(canvas) -> void:
	var stalled = bool(model.zep.stalled) or not bool(model.state.engine)
	var s = start_button()
	box(canvas, s, Color("2f5d3e") if not stalled else Color("7a3a2a"), PAPER if stalled else EDGE, 6, 2)
	canvas.draw_string(font, s.position + Vector2(0.0, s.size.y * 0.64), "Пуск" if stalled else "Мотор", HORIZONTAL_ALIGNMENT_CENTER, s.size.x, int(round(17.0 * k)), PAPER)
	var air_on = bool(model.state.get("zep_air_brake", false))
	var a = air_button()
	box(canvas, a, Color("8a5a2a") if air_on else Color("26312d"), GOLD if air_on else EDGE, 6, 2)
	canvas.draw_string(font, a.position + Vector2(0.0, a.size.y * 0.64), "Щитки", HORIZONTAL_ALIGNMENT_CENTER, a.size.x, int(round(17.0 * k)), PAPER)

func draw_trim(canvas) -> void:
	if not model.zeppelin_trim_installed(): return
	var on = bool(model.state.get("zep_trim", false))
	var b = trim_button()
	box(canvas, b, Color("2f5d6a") if on else Color("26312d"), Color("8fd0e0") if on else EDGE, 5, 2)
	canvas.draw_string(font, b.position + Vector2(0.0, b.size.y * 0.74), "Триммер", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, int(round(13.0 * k)), PAPER)

func gauge_arc(canvas, centre: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> void:
	# a share of the dial from..to (0..1) over 270 degrees starting at the lower left
	var a0 = deg_to_rad(135.0 + 270.0 * from)
	var a1 = deg_to_rad(135.0 + 270.0 * to)
	canvas.draw_arc(centre, radius, a0, a1, 32, color, width, true)

func dial(canvas, centre: Vector2, radius: float, value: float, title: String, readout: String, zones: Array = [], numbers: Array = []) -> void:
	canvas.draw_circle(centre, radius + 6.0 * k, Color("121816"))
	canvas.draw_arc(centre, radius + 6.0 * k, 0.0, TAU, 40, EDGE, 2.0 * k, true)
	gauge_arc(canvas, centre, radius - 3.0 * k, 0.0, 1.0, Color("2a332f"), 5.0 * k)
	for zone in zones: gauge_arc(canvas, centre, radius - 3.0 * k, float(zone[0]), float(zone[1]), zone[2], 5.0 * k)
	for i in range(numbers.size()):
		var na = deg_to_rad(135.0 + 270.0 * float(i) / float(numbers.size() - 1))
		canvas.draw_string(font, centre + Vector2(cos(na), sin(na)) * (radius - 15.0 * k) + Vector2(-10.0 * k, 4.0 * k), str(numbers[i]), HORIZONTAL_ALIGNMENT_CENTER, 20.0 * k, int(round(10.0 * k)), Color("a8b3a3"))
	for i in range(0, 11):
		var a = deg_to_rad(135.0 + 27.0 * i)
		canvas.draw_line(centre + Vector2(cos(a), sin(a)) * (radius - 4.0 * k), centre + Vector2(cos(a), sin(a)) * (radius + 2.0 * k), Color("8d9a98"), 1.0 * k)
	var angle = deg_to_rad(135.0 + 270.0 * clampf(value, 0.0, 1.0))
	canvas.draw_line(centre, centre + Vector2(cos(angle), sin(angle)) * (radius - 8.0 * k), PAPER, 2.5 * k, true)
	canvas.draw_circle(centre, 4.0 * k, GOLD)
	canvas.draw_string(font, centre + Vector2(-radius, radius * 0.62), title, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(round(13.0 * k)), Color("a8b3a3"))
	canvas.draw_string(font, centre + Vector2(-radius, radius * 0.95), readout, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(round(15.0 * k)), GOLD)

func draw_airspeed(canvas, zep) -> void:
	var r = 62.0 * k
	var c = origin + Vector2(472.0, 98.0) * k
	var kmh = absf(zep.v) * 3.6
	var takeoff = float(model.vehicle_base("zeppelin").zeppelin.takeoff_kmh)
	dial(canvas, c, r, kmh / SPEED_MAX_KMH, "км/ч", "%d" % roundi(kmh), [[(takeoff - 8.0) / SPEED_MAX_KMH, (takeoff + 6.0) / SPEED_MAX_KMH, GREEN]], [0, 40, 80, 120, 160])   # the green mark: the takeoff speed

func draw_revs(canvas, zep) -> void:
	var r = 54.0 * k
	var c = origin + Vector2(618.0, 98.0) * k
	var red_from = float(zep.c("rpm_max")) / RPM_MAX_SHOWN
	dial(canvas, c, r, float(zep.rpm) / RPM_MAX_SHOWN, "об/мин", "%d" % (roundi(float(zep.rpm) / 10.0) * 10), [[0.55, red_from - 0.02, GREEN], [red_from, 1.0, RED]], [0, 1, 2, 3])

func draw_bars(canvas, zep) -> void:
	var bars = [
		["Мотор t", clampf(float(zep.temp), 0.0, 1.0), Color("d0813c") if float(zep.temp) < 0.85 else RED, 0.85, 1.0],
		["Колёса", clampf(float(zep.load_fraction), 0.0, 1.0), Color("5f8fc4"), 0.10, 0.20],
		["Высота", clampf(float(zep.z) / float(zep.c("ceiling_m")), 0.0, 1.0), Color("a8b3a3") if float(zep.z) < 0.8 * float(zep.c("ceiling_m")) else RED, 0.8, 1.0],
		["Бензин", clampf(float(zep.fuel) / maxf(1.0, float(zep.c("fuel_l"))), 0.0, 1.0), Color("c9af73") if float(zep.fuel) > 5.0 else RED, 0.0, 0.12],
	]
	for i in range(bars.size()):
		var b = bars[i]
		var y = 36.0 + 36.0 * i
		text(canvas, Vector2(690.0, y), str(b[0]), 12, Color("a8b3a3"), 140.0, HORIZONTAL_ALIGNMENT_LEFT)
		var bar = rect(690.0, y + 5.0, 132.0, 13.0)
		box(canvas, bar, Color("0d1412"), Color("56635f"), 3)
		var zone_color = Color(GREEN, 0.5) if i == 1 else Color(RED, 0.45)
		canvas.draw_rect(Rect2(bar.position + Vector2(bar.size.x * float(b[3]), 1.0), Vector2(bar.size.x * (float(b[4]) - float(b[3])), bar.size.y - 2.0)), zone_color)
		canvas.draw_rect(Rect2(bar.position + Vector2(1.0, 2.0), Vector2((bar.size.x - 2.0) * float(b[1]), bar.size.y - 4.0)), b[2])
	var shown = "%.1f м" % float(zep.z) if bool(zep.airborne) else "на рельсах"
	text(canvas, Vector2(690.0, 183.0), shown, 13, GOLD, 132.0, HORIZONTAL_ALIGNMENT_LEFT)

# The lesson of the flight (the owner found the control not clear, 05.11.2026): one line that says what to do now, by the state of the machine.
# Shown while the hints of the game are on. Pure: it only reads the state of the model.
static func hint(zep, takeoff_kmh: float, brake: float, throttle: float) -> String:
	var kmh = absf(float(zep.v)) * 3.6
	if bool(zep.crashed): return ""
	if bool(zep.stalled): return "Мотор заглох: газ в ноль, подожди, нажми «Пуск»."
	if bool(zep.airborne):
		if float(zep.z) > 0.6 * float(zep.c("ceiling_m")): return "Высоко: ручку вниз, иначе потеряешь скорость и упадёшь."
		if kmh < 85.0: return "Скорость падает: ручку вниз, пусть самолёт разгонится."
		if float(zep.vz) < -3.5: return "Падаешь быстро: ручку на себя, но не резко."
		return "В воздухе винт слабее: ручка вниз даёт скорость. Садись плавно: газ меньше."
	if brake > 0.5 and throttle < 0.05: return "Тормоз затянут. Отпусти красный ползунок, потом газ."
	if throttle < 0.05 and kmh < 3.0: return "Отпусти тормоз, дай газ и поставь шаг мелким (ползунок «Шаг» вниз)."
	if float(zep.rpm) > float(zep.c("rpm_max")): return "Красная зона: шаг крупнее (ползунок «Шаг» вверх), следи за зелёной меткой."
	if float(zep.rpm) < float(zep.c("rpm_idle")) * 1.3 and throttle > 0.3: return "Винт тяжёлый: шаг мельче (ползунок «Шаг» вниз)."
	if kmh >= takeoff_kmh - 8.0: return "Скорость взлёта: потяни ручку до зелёной черты (+3,5°)."
	if kmh > 10.0: return "Разгоняйся: шаг крупнее по мере скорости, держи его у зелёной метки."
	return "Газ вперёд: поехали."

func draw_warning(canvas, zep) -> void:
	var line = ""
	var color = GOLD
	if bool(zep.crashed): line = "КРУШЕНИЕ"; color = RED
	elif bool(zep.stalled): line = "МОТОР ГЛОХ: газ в ноль и «Пуск»"; color = RED
	elif float(zep.temp) > 0.85: line = "ПЕРЕГРЕВ: убавь газ"; color = RED
	elif float(zep.rpm) > float(zep.c("rpm_max")): line = "КРАСНАЯ ЗОНА: шаг крупнее"; color = RED
	elif float(zep.rpm) < float(zep.c("rpm_idle")) * 1.3 and float(model.state.throttle) > 0.3 and not bool(zep.airborne): line = "ВИНТ ТЯЖЁЛЫЙ: шаг мельче"
	elif bool(zep.airborne): line = "ПОЛЁТ: держи ручку, садись плавно"
	if line != "": text(canvas, Vector2(300.0, 187.0), line, 13, color, 290.0)
	if bool(model.state.get("tutorial", false)):
		var lesson = hint(zep, float(model.vehicle_base("zeppelin").zeppelin.takeoff_kmh), float(model.state.brake), float(model.state.throttle))
		if lesson != "": text(canvas, Vector2(20.0, 22.0), lesson, 14, Color("e9ce83"), 640.0, HORIZONTAL_ALIGNMENT_LEFT)
