extends RefCounted
# В6.6: пульт реактивного (ракетного) поезда. Нарисован кодом, живёт отдельно от общих рычагов (как у цеппелина). Запуск как у ракеты:
# крышка, ЧЕТЫРЕ ПРЕДОХРАНИТЕЛЯ (их положения тайные коды, таблица в jet.gd), кнопка «Пуск», табло обратного отсчёта, зажигание,
# потом рычаг тяги. Парашют (кольцо, одно; с гаджетом ещё «оба сразу»), форсаж (гаджет). Приборы: скорость, тяга, керосин, нагрев.
# Размеры в условных единицах W x H, масштаб k и начало origin задаёт main.gd.

const W = 840.0
const H = 190.0
const PAPER = Color("efe8cf")
const GOLD = Color("d9b95b")
const RED = Color("c23b2e")
const GREEN = Color("5fae6a")
const PANEL = Color(0.07, 0.10, 0.12, 0.93)
const EDGE = Color("6f7f78")
const SPEED_MAX_KMH = 220.0

var origin = Vector2.ZERO
var k = 1.0
var active = ""
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

func fuse_rect(index: int) -> Rect2:
	return rect(180.0 + 50.0 * index, 52.0, 40.0, 62.0)

# the cap over the toggles (closed it hides them; open it shows them and a small tab to close it again)
func cover_rect() -> Rect2:
	return rect(176.0, 48.0, 208.0, 70.0)

func cover_tab() -> Rect2:
	return rect(262.0, 30.0, 122.0, 16.0)

# the start button under the toggles: locked until every toggle has been flipped
func start_rect() -> Rect2:
	return rect(180.0, 126.0, 190.0, 50.0)

func chute_button(two: bool) -> Rect2:
	return rect(535.0, 52.0 if not two else 100.0, 92.0, 44.0)

func burner_button() -> Rect2:
	return rect(535.0, 148.0, 92.0, 28.0)

func slider_value(id: String) -> float:
	if id == "throttle": return clampf(float(model.state.throttle), 0.0, 1.0)
	return clampf(float(model.state.brake), 0.0, 1.0)

func set_slider(id: String, level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	if level < 0.02: level = 0.0
	elif level > 0.98: level = 1.0
	if id == "throttle": model.state.throttle = level
	else:
		model.state.brake = level
		model.auto_brake = false

func level_at(index: int, pos: Vector2) -> float:
	var t = track(index)
	return 1.0 - (pos.y - t.position.y) / t.size.y

# --- the mouse: returns true when the pult took the click
func press(pos: Vector2) -> bool:
	if model == null or not bounds().has_point(pos): return false
	var ids = ["throttle", "brake"]
	for i in range(ids.size()):
		if track(i).grow(12.0 * k).has_point(pos):
			active = ids[i]
			set_slider(active, level_at(i, pos))
			return true
	if not model.jet.cover_open:
		if cover_rect().has_point(pos):
			model.set_jet_cover(true)
			return true
	else:
		if cover_tab().has_point(pos):
			model.set_jet_cover(false)
			return true
		for i in range(4):
			if fuse_rect(i).has_point(pos):
				model.flip_jet_fuse(i)
				return true
	if start_rect().has_point(pos):
		model.jet_start()
		return true
	if chute_button(false).has_point(pos):
		model.pull_jet_chute(1)
		return true
	if model.jet.double_chute_gadget and chute_button(true).has_point(pos):
		model.pull_jet_chute(2)
		return true
	if model.jet.afterburner_gadget and burner_button().has_point(pos):
		model.fire_jet_afterburner()
		return true
	return true

func motion(pos: Vector2) -> void:
	if active == "" or model == null: return
	set_slider(active, level_at(["throttle", "brake"].find(active), pos))

func release() -> void:
	active = ""

# the lesson line: one sentence that says what to do now (shown while the hints of the game are on)
static func hint(jet, brake: float, throttle: float) -> String:
	if bool(jet.started):
		if float(jet.fuel) <= 0.0: return "Керосин кончился: тормози парашютом."
		if float(jet.temp) > 0.8: return "Двигатель перегрет: убавь тягу."
		if float(jet.v) * 3.6 > 150.0 and int(jet.chutes_open) == 0 and throttle < 0.05: return "Скорость большая: до станции тормози парашютом (кольцо) и колодками."
		if throttle < 0.05 and float(jet.v) < 1.0: return "Двигатель горит. Подними рычаг тяги, она растёт плавно."
		return "Мощность держи рычагом. Парашют один, он обрежется после остановки."
	if bool(jet.counting): return "Идёт отсчёт: тумблеры трогать нельзя (отсчёт собьётся)."
	if not bool(jet.cover_open): return "Открой колпачок, под ним четыре тумблера-предохранителя. Их положения секретные коды."
	if not jet.start_unlocked(): return "Включи все четыре тумблера (горят %d): тогда откроется «Пуск». От порядка включения зависит режим." % jet.fuses_on()
	return "Тумблеры стоят как надо? Нажми «Пуск»: десять секунд отсчёта, потом зажигание."

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
	var jet = model.jet
	box(canvas, bounds(), PANEL, EDGE, 8, 2)
	draw_slider(canvas, 0, "throttle", "Тяга", Color("e0743c"), mouse)
	draw_slider(canvas, 1, "brake", "Тормоз", RED, mouse)
	draw_fuses(canvas, jet)
	draw_cover(canvas, jet)
	draw_display(canvas, jet)
	draw_buttons(canvas, jet)
	draw_speed(canvas, jet)
	draw_bars(canvas, jet)
	if bool(model.state.get("tutorial", false)):
		var lesson = hint(jet, float(model.state.brake), float(model.state.throttle))
		if lesson != "": text(canvas, Vector2(20.0, 22.0), lesson, 14, Color("e9ce83"), 640.0, HORIZONTAL_ALIGNMENT_LEFT)

func draw_slider(canvas, index: int, id: String, title: String, color: Color, mouse: Vector2) -> void:
	var t = track(index)
	var level = slider_value(id)
	text(canvas, Vector2(22.0 + 72.0 * index - 14.0, 40.0), title, 15, PAPER, 60.0)
	box(canvas, Rect2(t.position + Vector2(t.size.x * 0.38, 0.0), Vector2(t.size.x * 0.24, t.size.y)), Color("0d1412"), Color("56635f"), 3)
	for tick in range(6):
		var y = t.end.y - t.size.y * tick / 5.0
		canvas.draw_line(Vector2(t.position.x, y), Vector2(t.position.x + t.size.x * 0.3, y), Color("56635f"), 1.0)
	var knob = Rect2(Vector2(t.position.x - 3.0 * k, t.end.y - t.size.y * level - 8.0 * k), Vector2(t.size.x + 6.0 * k, 16.0 * k))
	box(canvas, knob, color, PAPER if active == id or knob.grow(6.0).has_point(mouse) else Color("1b2320"), 4, 1)
	canvas.draw_line(knob.position + Vector2(5.0 * k, knob.size.y * 0.5), knob.position + Vector2(knob.size.x - 5.0 * k, knob.size.y * 0.5), Color(1, 1, 1, 0.45), 1.5 * k)
	text(canvas, Vector2(22.0 + 72.0 * index - 14.0, 178.0), "%d%%" % roundi(level * 100.0), 14, GOLD, 60.0)

# the four fuses: toggles; up is on; each has a lamp that lights when the toggle is on
func draw_fuses(canvas, jet) -> void:
	text(canvas, Vector2(180.0, 42.0), "Предохранители", 13, Color("a8b3a3"), 120.0, HORIZONTAL_ALIGNMENT_LEFT)
	if bool(jet.cover_open):
		var tab = cover_tab()
		box(canvas, tab, Color("46504c"), Color("98a39e"), 4, 1)
		canvas.draw_string(font, tab.position + Vector2(0.0, tab.size.y * 0.8), "закрыть колпачок", HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, int(round(10.0 * k)), PAPER)
	else:
		return
	for i in range(4):
		var r = fuse_rect(i)
		var on = bool(jet.fuses[i])
		var locked = bool(jet.started)
		box(canvas, r, Color("1e2826") if not locked else Color("16201e"), EDGE, 5, 1)
		var slot = Rect2(r.position + Vector2(r.size.x * 0.4, 6.0 * k), Vector2(r.size.x * 0.2, r.size.y - 12.0 * k))
		box(canvas, slot, Color("0d1412"), Color("56635f"), 3)
		var lever_y = slot.position.y + (4.0 * k if on else slot.size.y - 16.0 * k)
		var lever = Rect2(Vector2(r.position.x + r.size.x * 0.25, lever_y), Vector2(r.size.x * 0.5, 12.0 * k))
		box(canvas, lever, GOLD if on else Color("8d9a98"), Color("1b2320"), 3, 1)
		var lamp = origin + Vector2(180.0 + 50.0 * i + 20.0, 120.0) * k
		canvas.draw_circle(lamp, 5.0 * k, GREEN if bool(jet.fuses[i]) else Color("2a332f"))
		canvas.draw_arc(lamp, 5.0 * k, 0.0, TAU, 16, Color("98a39e"), 1.0 * k, true)

# the cap over the toggles (closed: a plate with a hinge) and the start button (locked until every toggle has been flipped)
func draw_cover(canvas, jet) -> void:
	var r = cover_rect()
	if not bool(jet.cover_open):
		box(canvas, r, Color("46504c"), Color("98a39e"), 8, 2)
		canvas.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.1, 4.0 * k), Vector2(r.size.x * 0.8, 6.0 * k)), Color("8d9a98"))
		canvas.draw_string(font, r.position + Vector2(0.0, r.size.y * 0.62), "КОЛПАЧОК", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(round(17.0 * k)), PAPER)
	var b = start_rect()
	var lit = bool(jet.started)
	var counting = bool(jet.counting)
	var unlocked = jet.start_unlocked() and bool(jet.cover_open)
	if lit or counting or unlocked:
		box(canvas, b, Color("2f7d44") if lit else (Color("b8862c") if counting else Color("8a2f26")), PAPER, 6, 2)
		canvas.draw_string(font, b.position + Vector2(0.0, b.size.y * 0.66), "ГОРИТ" if lit else ("ОТСЧЁТ" if counting else "ПУСК"), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, int(round(18.0 * k)), PAPER)
	else:
		box(canvas, b, Color("1b2320"), Color("46504c"), 6, 1)
		var why = "ЗАБЛОКИРОВАНО"
		if bool(jet.cover_open): why = "ТУМБЛЕРЫ %d/4" % int(jet.fuses_on())
		canvas.draw_string(font, b.position + Vector2(0.0, b.size.y * 0.62), why, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, int(round(15.0 * k)), Color("6b7770"))

# the board of the countdown
func draw_display(canvas, jet) -> void:
	var r = rect(398.0, 52.0, 122.0, 124.0)
	box(canvas, r, Color("0b100f"), EDGE, 6, 2)
	var title = "ОТСЧЁТ"
	var value = "--"
	var color = Color("59605c")
	if bool(jet.started):
		title = "ЗАЖИГАНИЕ"
		value = "%dкН" % roundi(float(jet.thrust) / 1000.0)
		color = GREEN
	elif bool(jet.counting):
		value = "%02d" % int(ceil(float(jet.countdown)))
		color = RED if float(jet.countdown) <= 3.0 else Color("e9b84a")
	elif bool(jet.cover_open):
		title = "ГОТОВ"
		value = "00"
		color = Color("7a8a82")
	canvas.draw_string(font, r.position + Vector2(0.0, 26.0 * k), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(round(14.0 * k)), Color("a8b3a3"))
	canvas.draw_string(font, r.position + Vector2(0.0, 84.0 * k), value, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(round(46.0 * k)), color)
	var mode = ""
	if bool(jet.started) or bool(jet.counting): mode = str(jet.mode.name) if bool(jet.started) else ""
	canvas.draw_string(font, r.position + Vector2(0.0, 112.0 * k), mode, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(round(13.0 * k)), GOLD)

func draw_buttons(canvas, jet) -> void:
	var one = chute_button(false)
	var out = int(jet.chutes_open) > 0
	box(canvas, one, Color("2a3d6e") if out else Color("26312d"), PAPER if out else EDGE, 6, 2)
	canvas.draw_string(font, one.position + Vector2(0.0, one.size.y * 0.42), "Парашют", HORIZONTAL_ALIGNMENT_CENTER, one.size.x, int(round(15.0 * k)), PAPER)
	canvas.draw_string(font, one.position + Vector2(0.0, one.size.y * 0.82), ("раскрыт" if out else ("в укладке: %d" % int(jet.chutes_left))), HORIZONTAL_ALIGNMENT_CENTER, one.size.x, int(round(12.0 * k)), GOLD)
	if bool(jet.double_chute_gadget):
		var two = chute_button(true)
		box(canvas, two, Color("26312d"), EDGE, 6, 2)
		canvas.draw_string(font, two.position + Vector2(0.0, two.size.y * 0.42), "Оба сразу", HORIZONTAL_ALIGNMENT_CENTER, two.size.x, int(round(15.0 * k)), PAPER)
	if bool(jet.afterburner_gadget):
		var b = burner_button()
		box(canvas, b, Color("8a3a1a") if float(jet.afterburner_time) > 0.0 else Color("26312d"), GOLD if float(jet.afterburner_time) > 0.0 else EDGE, 5, 2)
		canvas.draw_string(font, b.position + Vector2(0.0, b.size.y * 0.72), "Форсаж ×%d" % int(jet.afterburner_charges), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, int(round(13.0 * k)), PAPER)

func draw_speed(canvas, jet) -> void:
	var r = 52.0 * k
	var c = origin + Vector2(690.0, 98.0) * k
	var kmh = absf(float(jet.v)) * 3.6
	canvas.draw_circle(c, r + 6.0 * k, Color("121816"))
	canvas.draw_arc(c, r + 6.0 * k, 0.0, TAU, 40, EDGE, 2.0 * k, true)
	canvas.draw_arc(c, r - 3.0 * k, deg_to_rad(135.0), deg_to_rad(405.0), 32, Color("2a332f"), 5.0 * k, true)
	canvas.draw_arc(c, r - 3.0 * k, deg_to_rad(135.0 + 270.0 * 180.0 / SPEED_MAX_KMH), deg_to_rad(135.0 + 270.0 * 205.0 / SPEED_MAX_KMH), 12, GREEN, 5.0 * k, true)
	for i in range(0, 12):
		var a = deg_to_rad(135.0 + 270.0 * float(i) / 11.0)
		canvas.draw_line(c + Vector2(cos(a), sin(a)) * (r - 4.0 * k), c + Vector2(cos(a), sin(a)) * (r + 2.0 * k), Color("8d9a98"), 1.0 * k)
	var angle = deg_to_rad(135.0 + 270.0 * clampf(kmh / SPEED_MAX_KMH, 0.0, 1.0))
	canvas.draw_line(c, c + Vector2(cos(angle), sin(angle)) * (r - 8.0 * k), PAPER, 2.5 * k, true)
	canvas.draw_circle(c, 4.0 * k, GOLD)
	canvas.draw_string(font, c + Vector2(-r, r * 0.62), "км/ч", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(round(13.0 * k)), Color("a8b3a3"))
	canvas.draw_string(font, c + Vector2(-r, r * 0.95), "%d" % roundi(kmh), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(round(15.0 * k)), GOLD)

func draw_bars(canvas, jet) -> void:
	var tank = maxf(1.0, float(jet.c("fuel_l")))
	var bars = [
		["Тяга", clampf(float(jet.thrust) / float(jet.c("thrust_max_n")), 0.0, 1.0), Color("e0743c"), 2.0, 2.0],
		["Керосин", clampf(float(jet.fuel) / tank, 0.0, 1.0), Color("c9af73") if float(jet.fuel) > 0.12 * tank else RED, 0.0, 0.12],
		["Нагрев", clampf(float(jet.temp), 0.0, 1.0), Color("d0813c") if float(jet.temp) < 0.8 else RED, 0.8, 1.0],
	]
	for i in range(bars.size()):
		var b = bars[i]
		var y = 46.0 + 44.0 * i
		text(canvas, Vector2(752.0, y - 2.0), str(b[0]), 12, Color("a8b3a3"), 86.0, HORIZONTAL_ALIGNMENT_LEFT)
		var bar = rect(752.0, y + 4.0, 80.0, 13.0)
		box(canvas, bar, Color("0d1412"), Color("56635f"), 3)
		if float(b[3]) < 1.5: canvas.draw_rect(Rect2(bar.position + Vector2(bar.size.x * float(b[3]), 1.0), Vector2(bar.size.x * (float(b[4]) - float(b[3])), bar.size.y - 2.0)), Color(RED, 0.45))
		canvas.draw_rect(Rect2(bar.position + Vector2(1.0, 2.0), Vector2((bar.size.x - 2.0) * float(b[1]), bar.size.y - 4.0)), b[2])
	text(canvas, Vector2(752.0, 182.0), "%d л · %d ваг." % [roundi(float(jet.fuel)), int(jet.wagons)], 12, GOLD, 86.0, HORIZONTAL_ALIGNMENT_LEFT)
