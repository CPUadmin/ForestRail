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
# The parts of the start panel painted by GPT (P15): the cap, the toggles, the lamps, the button in three states.
const PARTS = {
	"cap": preload("res://assets/art_jet/panel_cap_closed.png"), "up": preload("res://assets/art_jet/toggle_up.png"), "down": preload("res://assets/art_jet/toggle_down.png"),
	"lamp_off": preload("res://assets/art_jet/lamp_off.png"), "lamp_on": preload("res://assets/art_jet/lamp_on.png"),
	"locked": preload("res://assets/art_jet/button_locked.png"), "armed": preload("res://assets/art_jet/button_armed.png"), "burning": preload("res://assets/art_jet/button_burning.png")}

# The ring of the chute (plan В6.6в, owner 14.11): pulled down with the mouse, the chute goes out at the bottom of the pull;
# let go earlier and the ring springs back. Painted by GPT (P17 pult_buttons: the plate and the ring), the rope is drawn.
const RING_PARTS = {"plate": preload("res://assets/art_jet/chute_plate.png"), "ring": preload("res://assets/art_jet/chute_ring.png")}
const RING_PULL = 38.0   # how far down the ring goes, units
var ring_pull = 0.0      # 0..1, where the ring is now
var ring_grab_y = 0.0
var ring_fired = false
var ring_tick = 0

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

func plate_rect() -> Rect2:
	return rect(554.0, 38.0, 54.0, 56.0)

# no chute left in the pack: the ring hangs pulled out
func ring_spent() -> bool:
	return int(model.jet.chutes_left) <= 0

func ring_rect() -> Rect2:
	var pull = 1.0 if ring_spent() and active != "ring" else ring_pull
	return rect(561.0, 92.0 + RING_PULL * pull, 40.0, 37.4)

func burner_button() -> Rect2:
	return rect(640.0, 162.0, 98.0, 24.0)

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
	if not ring_spent() and ring_rect().grow(8.0 * k).has_point(pos):
		active = "ring"
		ring_grab_y = pos.y - ring_pull * RING_PULL * k
		ring_fired = false
		return true
	if start_rect().has_point(pos):
		if model.jet.started or model.jet.counting: model.jet_stop()   # the lit button puts the engine out, the counting one cancels the start
		else: model.jet_start()
		return true
	if model.jet.afterburner_gadget and burner_button().has_point(pos):
		model.fire_jet_afterburner()
		return true
	return true

func motion(pos: Vector2) -> void:
	if active == "" or model == null: return
	if active == "ring":
		ring_pull = clampf((pos.y - ring_grab_y) / (RING_PULL * k), 0.0, 1.0)
		if ring_pull >= 0.97 and not ring_fired:
			ring_fired = true
			model.pull_jet_chute(1)   # one chute a pull; with the gadget the ring comes back for the second one
		return
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
	draw_buttons(canvas, jet, mouse)
	draw_speed(canvas, jet)
	draw_bars(canvas, jet)
	if bool(model.state.get("tutorial", false)):
		var lesson = hint(jet, float(model.state.brake), float(model.state.throttle))
		if lesson != "":
			# ui-v2: the lesson stands above the pult on its own backing and wraps to two lines (it was cut and lay over «Газ»)
			var lesson_rect = Rect2(origin + Vector2(0.0, -58.0) * k, Vector2(760.0, 52.0) * k)
			canvas.draw_style_box(canvas.style(Color(0.07, 0.06, 0.04, 0.88), Color("8a6a2c"), 6), lesson_rect)
			canvas.draw_multiline_string(font, lesson_rect.position + Vector2(12.0, 20.0) * k, lesson, HORIZONTAL_ALIGNMENT_LEFT, (760.0 - 24.0) * k, int(round(15.0 * k)), 2, Color("e9ce83"))

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
		var tex: Texture2D = PARTS["up" if on else "down"]
		var spot_size = Vector2(r.size.y * float(tex.get_width()) / float(tex.get_height()), r.size.y)
		var spot = Rect2(r.get_center() - spot_size * 0.5, spot_size)
		canvas.draw_texture_rect(tex, spot, false, Color(0.7, 0.7, 0.7) if locked else Color.WHITE)
		var lamp = origin + Vector2(180.0 + 50.0 * i + 20.0, 120.0) * k
		var lamp_tex: Texture2D = PARTS["lamp_on" if bool(jet.fuses[i]) else "lamp_off"]
		canvas.draw_texture_rect(lamp_tex, Rect2(lamp - Vector2(7.5, 7.5) * k, Vector2(15.0, 15.0) * k), false)

# the cap over the toggles (closed: a plate with a hinge) and the start button (locked until every toggle has been flipped)
func draw_cover(canvas, jet) -> void:
	var r = cover_rect()
	if not bool(jet.cover_open):
		canvas.draw_texture_rect(PARTS["cap"], r, false)   # the painted cap with its latch covers the toggles
	var b = start_rect()
	var lit = bool(jet.started)
	var counting = bool(jet.counting)
	var unlocked = jet.start_unlocked() and bool(jet.cover_open)
	var state = "burning" if lit else ("armed" if (counting or unlocked) else "locked")
	var tex: Texture2D = PARTS[state]
	var side = b.size.y * float(tex.get_width()) / float(tex.get_height())
	canvas.draw_texture_rect(tex, Rect2(b.position + Vector2(4.0 * k, 0.0), Vector2(side, b.size.y)), false)
	var label_at = b.position + Vector2(side + 10.0 * k, 0.0)
	var label_w = b.size.x - side - 10.0 * k
	if lit or counting or unlocked:
		canvas.draw_string(font, label_at + Vector2(0.0, b.size.y * 0.66), "СТОП" if lit else ("ОТМЕНА" if counting else "ПУСК"), HORIZONTAL_ALIGNMENT_CENTER, label_w, int(round(18.0 * k)), PAPER)
	else:
		var why = "ЗАБЛОКИРОВАНО"
		if bool(jet.cover_open): why = "ТУМБЛЕРЫ %d/4" % int(jet.fuses_on())
		canvas.draw_string(font, label_at + Vector2(0.0, b.size.y * 0.62), why, HORIZONTAL_ALIGNMENT_CENTER, label_w, int(round(13.0 * k)), Color("a4b0a9"))

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

func draw_buttons(canvas, jet, mouse: Vector2) -> void:
	# the ring springs back when it is let go before the end of the pull
	var now = Time.get_ticks_msec()
	var dt = clampf(float(now - ring_tick) / 1000.0, 0.0, 0.1)
	ring_tick = now
	if active != "ring" and ring_pull > 0.0: ring_pull = maxf(0.0, ring_pull - dt * 6.0)
	var plate = plate_rect()
	var ring = ring_rect()
	var top = plate.position + Vector2(plate.size.x * 0.5, plate.size.y * 0.92)
	var bottom = ring.position + Vector2(ring.size.x * 0.5, 5.0 * k)
	if bottom.y > top.y:
		canvas.draw_line(top, bottom, Color("6e5f45"), 5.0 * k)
		canvas.draw_line(top, bottom, Color("d8c79d"), 3.2 * k)
	canvas.draw_texture_rect(RING_PARTS.plate, plate, false)
	var hot = active == "ring" or (not ring_spent() and ring.grow(8.0 * k).has_point(mouse))
	canvas.draw_texture_rect(RING_PARTS.ring, ring, false, Color(1.18, 1.12, 1.0) if hot else Color.WHITE)
	var status = "тяни вниз"
	if int(jet.chutes_open) > 0: status = "раскрыт" if ring_spent() else "раскрыт · ещё %d" % int(jet.chutes_left)
	elif int(jet.chutes_left) > 1: status = "тяни вниз · %d шт." % int(jet.chutes_left)
	elif ring_spent(): status = "уложат в депо"
	text(canvas, Vector2(522.0, 36.0), "Парашют", 13, Color("a8b3a3"), 118.0)
	text(canvas, Vector2(510.0, 186.0 if ring_spent() or active == "ring" else 152.0), status, 12, GOLD, 142.0)
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
