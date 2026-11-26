extends RefCounted
# Шкафчик электровоза крупно поверх кабины (1.12, картинки GPT П33 «Подстанция»; провода, искры и свет рисует код).
# Работает через canvas (main.gd), как depot_ui.gd. Модель — contactor.gd.
#
# Мышь: провода висят на верёвочной физике. Конец тащится к клемме своего цвета (и знака: ○ △ □ ◇ +) и прилипает.
# Зажав мышь на стыке, обводи его петлями (loop_stroke.gd, из демки владельца): 3 ровные петли — тугая скрутка,
# рыхлый виток краснеет, петля в обратную сторону снимает виток; 5 ровных одним движением — «золотая» (секрет).
# После ремонта мотора концы спутаны в клубок: каждый протягивают через кольцо своего цвета. Хорошенько подёргай
# зажатый стык — скрутка рвётся, обрывок остаётся в шкафчике. Щелчок по сгоревшему предохранителю ставит запасной;
# обрывок, донесённый до пустого держателя и обмотанный петлями, — «жучок» (секрет). Пуск — рубильник в кабине.
# Дверца слева закрывает шкафчик. Клавиатура: цифра — провод, вторая цифра — клемма; пробел крутит; Enter — рубильник;
# Esc закрывает.

const DIR = "res://assets/art_electric/cabinet/"
const INSIDE = preload("res://assets/art_electric/cabinet/inside.png")
const DOOR = preload("res://assets/art_cab/electric/cabinet_door.png")
const FUSE_TEX = {"ok": preload("res://assets/art_electric/cabinet/fuse_whole.png"), "burnt": preload("res://assets/art_electric/cabinet/fuse_burnt.png"), "bug": preload("res://assets/art_electric/cabinet/fuse_bug.png")}
const SCRAP = preload("res://assets/art_electric/cabinet/wire_scrap.png")
const SPARE_CLOSED = preload("res://assets/art_electric/cabinet/spare_closed.png")
const SPARE_OPEN = preload("res://assets/art_electric/cabinet/spare_open.png")

# places in inside.png (1265 × 714 px)
const PX = Vector2(1265, 714)
const ROWS_Y = [150.0, 238.0, 321.0, 404.0, 488.0]
const LEFT_X = 163.0
const RIGHT_X = 1103.0
const LAMP_AT = Vector2(633, 169)
const HOLDERS = [Vector2(345, 585), Vector2(568, 585), Vector2(791, 585)]
const HOLDER_W = 190.0
const POCKET = Vector2(970, 587)
const SCRAP_AT = Vector2(980, 470)
const COLORS = [Color("c8402f"), Color("3a6fb5"), Color("e0b33a"), Color("4f9a4f"), Color("e8e2d0")]
const PATTERNS = ["solid", "stripe", "dots", "check", "double"]
const COPPER = Color("d08a4a")
const GRAB_R = 28.0
const SNAP_R = 36.0
const TWIST_LEAVE = 90.0
const ROPE_N = 16
const TEAR_SPEED = 1800.0   # px/s: a yank this fast…
const TEAR_YANKS = 3        # …this many times back and forth within TEAR_WINDOW tears the joint
const TEAR_WINDOW = 0.8
const LoopStroke = preload("res://scripts/vehicles/locomotive/loop_stroke.gd")
const LOOP_R = 40.0         # px of inside.png: a comfortable loop round a joint; wider ones hold worse
const KNOT_AT = Vector2(610, 430)
const HOOKS = [Vector2(420, 290), Vector2(830, 290), Vector2(700, 515), Vector2(380, 470), Vector2(870, 430)]
const HOOK_R = 26.0
const MARKS = ["circle", "triangle", "square", "diamond", "plus"]   # the demo's marks by colour, for colour-blind players

var canvas = null
var open = false
var mode = ""              # "" | "wire" | "twist" | "scrap" | "bugwind"
var wire = -1
var hand = Vector2.ZERO
var stroke = null            # LoopStroke of the held twist or the bug winding
var run = 0                  # loops added in this one motion (the golden twist)
var key_spin = 0.0           # the held space bar: ten presses make a loop
var selected = -1
var spark_t = 0.0
var spark_at: Array = []
var lid_t = 0.0
var hits: Dictionary = {}
var ropes: Array = []      # per wire: {"p": PackedVector2Array, "o": PackedVector2Array}
var last_mouse = Vector2.ZERO
var last_mouse_t = 0.0
var last_dir = 0.0
var yanks: Array = []      # times of fast reversals while holding a joint
var bug_slot = -1

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func c():
	return canvas.model.contactor()

func usable() -> bool:
	return canvas.model.vehicle_id() == "locomotive" and canvas.model.contactor_rules and canvas.cab_active()

func toggle() -> void:
	if open: close()
	else:
		open = true
		lid_t = 0.0
		selected = -1
		ropes = []
		canvas.sound.play("gear", 0.5, 0.6)
		if canvas.model.state.fleet_by_id.has("locomotive"): c().st()

func close() -> void:
	if not open: return
	open = false
	mode = ""
	wire = -1
	canvas.sound.play("gear", 0.45, 0.75)

# --- geometry
func box_rect() -> Rect2:
	var size = canvas.get_viewport_rect().size
	var w = minf(940.0, size.x * 0.6)
	var h = w * PX.y / PX.x
	# to the right: the knife switch on the left of the board stays in sight and under the hand (it starts the engine)
	return Rect2(Vector2(size.x * 0.38, size.y * 0.5 - h * 0.5 - 6.0), Vector2(w, h))

func k() -> float:
	return box_rect().size.x / PX.x

func at_px(p: Vector2) -> Vector2:
	return box_rect().position + p * k()

func px(p: Vector2) -> Vector2:
	return (p - box_rect().position) / k()

func hook(i: int) -> Vector2:
	return at_px(HOOKS[i % HOOKS.size()])

func first_row() -> int:
	return (ROWS_Y.size() - c().count()) / 2

func root(i: int) -> Vector2:
	return at_px(Vector2(LEFT_X + 30.0, ROWS_Y[first_row() + i]))

func terminal(t: int) -> Vector2:
	return at_px(Vector2(RIGHT_X - 30.0, ROWS_Y[first_row() + t]))

func rest(i: int) -> Vector2:   # a free end lies low in the middle; the cable sags between it and its root
	return at_px(Vector2(420.0 + 90.0 * float(i), 455.0 - 14.0 * float(i)))

func end_of(i: int) -> Vector2:
	if mode == "wire" and wire == i: return hand
	if c().knotted(i): return at_px(KNOT_AT + Vector2(-40.0 + 40.0 * float(i % 3), 26.0 if i >= 3 else -6.0 * float(i % 2)))
	if c().joined(i):
		var p = terminal(c().at(i))
		if (c().st().popped as Array).has(i): p += Vector2(-20, 16) * k()
		return p
	return rest(i)

func holder(slot: int) -> Rect2:
	var centre = at_px(HOLDERS[slot])
	var w = HOLDER_W * k()
	return Rect2(centre - Vector2(w, w * 0.36) * 0.5, Vector2(w, w * 0.36))

func door_rect() -> Rect2:
	var box = box_rect()
	var h = box.size.y * 0.96
	var w = h * float(DOOR.get_width()) / float(DOOR.get_height()) * 0.42   # swung open towards us: narrow
	return Rect2(Vector2(box.position.x - w + 6.0, box.position.y + box.size.y * 0.02), Vector2(w, h))

func scrap_rect() -> Rect2:
	var w = 150.0 * k()
	return Rect2(at_px(SCRAP_AT) - Vector2(w, w * 0.19) * 0.5, Vector2(w, w * 0.19))

func pocket_rect() -> Rect2:
	var w = 120.0 * k()
	var tx = SPARE_CLOSED
	var h = w * float(tx.get_height()) / float(tx.get_width())
	return Rect2(at_px(POCKET) - Vector2(w, h) * 0.5, Vector2(w, h))

# --- the rope: Verlet points between the root and the end, gravity, fixed segment length
func rope(i: int, dt: float) -> PackedVector2Array:
	while ropes.size() <= i: ropes.append({})
	var a = root(i)
	var b = end_of(i)
	var r: Dictionary = ropes[i]
	# the end jumped (a tear, a spark, a new scheme): the cable is laid again instead of whipping across the box
	if r.has("p") and (r.p as PackedVector2Array).size() == ROPE_N and (r.p as PackedVector2Array)[ROPE_N - 1].distance_to(b) > 150.0 * k() and not (mode == "wire" and wire == i):
		r.erase("p")
	if not r.has("p") or (r.p as PackedVector2Array).size() != ROPE_N:
		var pts = PackedVector2Array()
		for s in range(ROPE_N): pts.append(a.lerp(b, float(s) / float(ROPE_N - 1)) + Vector2(0, sin(float(s) / float(ROPE_N - 1) * PI) * 120.0 * k()))
		r.p = pts
		r.o = pts.duplicate()
	var p: PackedVector2Array = r.p
	var o: PackedVector2Array = r.o
	# a springy cable: its length follows the span with some slack, so a free wire sags and does not pile up
	var seg = maxf(a.distance_to(b) * 1.12, 180.0 * k()) / float(ROPE_N - 1)
	var gravity = Vector2(0, 900.0 * k())
	var step = clampf(dt, 0.0, 1.0 / 30.0)
	var still = bool(canvas.settings.reduce_motion)
	for s in range(1, ROPE_N - 1):
		var v = (p[s] - o[s]) * (0.9 if not still else 0.0)
		o[s] = p[s]
		p[s] = p[s] + v + gravity * step * step
	p[0] = a
	p[ROPE_N - 1] = b
	for it in range(10):
		for s in range(ROPE_N - 1):
			var d = p[s + 1] - p[s]
			var len = d.length()
			if len < 0.001: continue
			var diff = (len - seg) / len
			if len < seg: continue   # a rope does not push, it only pulls
			if s == 0:
				p[s + 1] -= d * diff
			elif s + 1 == ROPE_N - 1:
				p[s] += d * diff
			else:
				p[s] += d * diff * 0.5
				p[s + 1] -= d * diff * 0.5
		p[0] = a
		p[ROPE_N - 1] = b
	r.p = p
	r.o = o
	return p

# --- drawing (after the cab, so the cabinet lies on top)
func draw(dt: float) -> void:
	if not open or not usable(): return
	lid_t = minf(1.0, lid_t + dt * 5.0)
	spark_t = maxf(0.0, spark_t - dt)
	var box = box_rect()
	var kk = k()
	var reduce = bool(canvas.settings.reduce_motion)
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.get_viewport_rect().size), Color(0, 0, 0, 0.42))
	canvas.electric_cab().draw_switch_lit()   # the knife switch stays bright: after the twist it is the next thing to pull
	var door = door_rect()
	canvas.draw_texture_rect(DOOR, door, false, Color(0.82, 0.82, 0.8))
	canvas.draw_texture_rect(INSIDE, box, false)
	# the lamp ГОТОВ in its socket
	var lamp = at_px(LAMP_AT)
	var ready = c().ready()
	if ready:
		canvas.draw_circle(lamp, 46.0 * kk, Color(1.0, 0.85, 0.35, 0.22), true, -1, true)
		canvas.draw_circle(lamp, 24.0 * kk, Color("f6cf5a"), true, -1, true)
		canvas.draw_circle(lamp + Vector2(-7, -8) * kk, 7.0 * kk, Color(1, 1, 1, 0.6), true, -1, true)
	canvas.draw_string(canvas.font, lamp + Vector2(-60.0, 104.0 * kk), "ГОТОВ", HORIZONTAL_ALIGNMENT_CENTER, 120.0, int(14.0 * kk + 4.0), Color("5a4630"))
	# the fuses in their holders; a hot one glows
	var st = c().st()
	for slot in range(3):
		var kind = str(st.fuses[slot])
		var tex: Texture2D = FUSE_TEX[kind]
		var rect = holder(slot)
		var w = rect.size.x * (1.0 if kind == "bug" else 0.92)
		var h = w * float(tex.get_height()) / float(tex.get_width())
		canvas.draw_texture_rect(tex, Rect2(rect.get_center() - Vector2(w, h) * 0.5, Vector2(w, h)), false)
		if kind == "ok" and c().warning() and slot == (st.fuses as Array).find("ok"):
			var pulse = 0.5 + 0.5 * sin(float(canvas.time) * 10.0) if not reduce else 0.6
			canvas.draw_rect(rect.grow(-rect.size.y * 0.2), Color(1.0, 0.55, 0.15, 0.25 + 0.3 * pulse))
		if mode == "bugwind" and bug_slot == slot:
			var done = (float(stroke.count) + absf(stroke.spin) / TAU) / 3.0 if stroke else 0.0
			canvas.draw_arc(rect.get_center(), rect.size.x * 0.32, 0.0, TAU * clampf(done, 0.0, 1.0), 24, Color("f3d27a"), 3.0, true)
	# the spare box in its pocket, and the scraps of wire in the corner
	var pocket = pocket_rect()
	canvas.draw_texture_rect(SPARE_OPEN if c().spares() > 0 else SPARE_CLOSED, pocket, false)
	for n in range(c().spares()): canvas.draw_circle(pocket.position + Vector2(pocket.size.x * (0.3 + 0.2 * n), pocket.end.y + 10.0 * kk), 4.0 * kk, Color("e8d9a8"))
	if c().scraps() > 0 and mode != "scrap":
		canvas.draw_texture_rect(SCRAP, scrap_rect(), false)
	if mode == "scrap":
		var sr = scrap_rect()
		canvas.draw_texture_rect(SCRAP, Rect2(hand - sr.size * 0.5, sr.size), false)
	# the coloured tags by the right terminals
	var n = c().count()
	for w in range(n):
		var tag = Rect2(terminal(c().terminal_of(w)) + Vector2(-58, -10) * kk, Vector2(30, 20) * kk)
		draw_band(tag, w)
		draw_mark(tag.position + Vector2(-12, 10) * kk, 7.0 * kk, w, Color("2a2018"))
	# the knot after a repair: a ring of each wire's colour to pull its end through
	if c().knot_left() > 0:
		for i in range(n):
			if not c().knotted(i): continue
			var ring = hook(i)
			var pulse = 0.0 if reduce else 0.15 * sin(float(canvas.time) * 4.0 + float(i))
			canvas.draw_arc(ring, HOOK_R * kk * (1.0 + pulse), 0.0, TAU, 28, Color("1a1410"), 6.0 * kk, true)
			canvas.draw_arc(ring, HOOK_R * kk * (1.0 + pulse), 0.0, TAU, 28, COLORS[i % COLORS.size()], 3.5 * kk, true)
			draw_mark(ring, 7.0 * kk, i, COLORS[i % COLORS.size()])
		var knot = at_px(KNOT_AT)
		for i in range(n):
			if not c().knotted(i): continue
			var at = knot + Vector2(14.0 * float(i) - 20.0, 6.0 * float(i % 2)) * kk
			canvas.draw_arc(at, 36.0 * kk, float(i) * 1.3, float(i) * 1.3 + 4.4, 20, Color("140f0b"), 12.0 * kk + 1.0, true)
			canvas.draw_arc(at, 36.0 * kk, float(i) * 1.3, float(i) * 1.3 + 4.4, 20, COLORS[i % COLORS.size()], 9.0 * kk, true)
	for i in range(n):
		draw_wire(i, rope(i, dt))
	if spark_t > 0.0: draw_spark(reduce)
	# one short line of help
	var line = ""
	if c().motor_burnt(): line = "Мотор сгорел: только помощь депо"
	elif c().is_on(): line = "Включено. Рубильник вниз — стоп (провода разведутся)"
	elif c().knot_left() > 0: line = "После ремонта провода спутаны: протяни каждый конец через кольцо его цвета"
	elif not c().all_joined(): line = "Подведи каждый провод к клемме его цвета и знака"
	elif not c().ready(): line = "Обведи каждый стык петлями: три ровные — тугая скрутка"
	elif weak_wire() >= 0: line = "Красный виток рыхлый: обведи стык плотнее или сними виток петлёй в обратную сторону"
	else: line = "Готово: рубильник в кабине вверх"
	var width = canvas.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 28.0
	var plate = Rect2(Vector2(box.position.x + box.size.x * 0.5 - width * 0.5, box.end.y + 8.0), Vector2(width, 28.0))
	canvas.draw_style_box(canvas.style(Color(0.08, 0.07, 0.05, 0.92), Color("8a6a3a"), 6), plate)
	canvas.draw_string(canvas.font, plate.position + Vector2(0, 19), line, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 15, Color("e8dcb4"))
	hits = {"lid": door}

func draw_band(rect: Rect2, w: int) -> void:
	var col: Color = COLORS[w % COLORS.size()]
	canvas.draw_rect(rect.grow(1.5), Color("1a1410"))
	canvas.draw_rect(rect, col)
	var dark = col.darkened(0.55)
	match PATTERNS[w % PATTERNS.size()]:
		"stripe": canvas.draw_line(rect.position + Vector2(0, rect.size.y * 0.5), rect.end - Vector2(0, rect.size.y * 0.5), dark, maxf(2.0, rect.size.y * 0.25))
		"dots":
			for d in range(3): canvas.draw_circle(rect.position + Vector2(rect.size.x * (0.2 + 0.3 * d), rect.size.y * 0.5), rect.size.y * 0.18, dark)
		"check":
			for d in range(4):
				var y = 0.0 if d % 2 == 0 else rect.size.y * 0.5
				canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.25 * d, y), Vector2(rect.size.x * 0.25, rect.size.y * 0.5)), dark)
		"double":
			canvas.draw_line(rect.position + Vector2(0, rect.size.y * 0.3), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.3), dark, 2.0)
			canvas.draw_line(rect.position + Vector2(0, rect.size.y * 0.7), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.7), dark, 2.0)

func draw_wire(i: int, pts: PackedVector2Array) -> void:
	var col: Color = COLORS[i % COLORS.size()]
	var dark = col.darkened(0.55)
	var kk = k()
	var body = pts.slice(0, pts.size() - 2)
	canvas.draw_polyline(body, Color("140f0b"), 13.0 * kk + 1.0, true)
	canvas.draw_polyline(body, col, 10.0 * kk, true)
	match PATTERNS[i % PATTERNS.size()]:
		"stripe":
			for s in range(0, body.size() - 1, 2): canvas.draw_line(body[s], body[s + 1], dark, 3.5 * kk)
		"dots":
			for s in range(1, body.size()): canvas.draw_circle(body[s], 2.8 * kk, dark)
		"check":
			for s in range(0, body.size() - 1):
				var along = (body[s + 1] - body[s]).normalized()
				var across = Vector2(-along.y, along.x) * 4.0 * kk
				canvas.draw_line(body[s] - across, body[s] + across, dark, 2.0 * kk)
		"double":
			for s in range(body.size() - 1):
				var along = (body[s + 1] - body[s]).normalized()
				var across = Vector2(-along.y, along.x) * 2.8 * kk
				canvas.draw_line(body[s] + across, body[s + 1] + across, dark, 1.4)
				canvas.draw_line(body[s] - across, body[s + 1] - across, dark, 1.4)
	canvas.draw_polyline(pts.slice(pts.size() - 3, pts.size()), COPPER, 5.0 * kk, true)
	var tip = pts[pts.size() - 1]
	var st = c().st()
	if (st.torn as Array).has(i) and not c().joined(i):
		for f in range(5): canvas.draw_line(tip, tip + Vector2.from_angle(-0.8 + 0.4 * f) * 12.0 * kk, COPPER.darkened(0.2), 1.6)
	if c().joined(i):
		# the twist: copper loops along the joint, one per loop turned; gold for the golden twist
		var gold = (st.golden as Array).has(i)
		var quality: Array = c().loop_quality(i)
		var weak = c().weakest(i)
		for loop in range(quality.size()):
			var q = float(quality[loop])
			# a good loop is copper (gold for the golden twist), a slack one dull, one past the joint grey; the weakest blinks red
			var ink = Color("f1c65a") if gold else (COPPER if q >= LoopStroke.GOOD else (COPPER.darkened(0.45) if q > 0.0 else Color("6a625a")))
			ink = ink.lightened(0.15 if loop % 2 == 0 else 0.0)
			if loop == weak and fmod(float(canvas.time) * 2.0, 1.0) < 0.6: ink = Color("e0564a")
			canvas.draw_arc(tip + Vector2(-9.0 - 4.0 * loop, 0) * kk, 8.0 * kk * (1.0 + 0.4 * (1.0 - q)), 0.0, TAU, 16, ink, 3.0 * kk, true)
		if gold and fmod(float(canvas.time) * 1.3 + float(i) * 0.3, 1.0) < 0.15:
			canvas.draw_circle(tip + Vector2(-12, -8) * kk, 4.0 * kk, Color(1, 1, 0.8, 0.8))
		var mark = Color("5cc17f") if c().tight(i) else (Color("e6b34a") if c().twisted(i) else Color(0, 0, 0, 0))
		if (st.popped as Array).has(i) and fmod(float(canvas.time) * 3.0, 1.0) < 0.5: mark = Color("e0564a")
		if mark.a > 0.0: canvas.draw_circle(tip + Vector2(0, -18) * kk, 5.0 * kk, mark)
	if not c().joined(i) and not c().knotted(i):
		canvas.draw_circle(tip + Vector2(0, -20) * kk, 9.0 * kk, Color(0.95, 0.92, 0.84, 0.9), true, -1, true)
		draw_mark(tip + Vector2(0, -20) * kk, 5.5 * kk, i, Color("2a2018"))
	if selected == i:
		canvas.draw_arc(tip, 14.0 * kk, 0.0, TAU, 20, Color("f3d27a"), 2.0, true)

# the shape mark of wire w (its colour's sign), drawn in ink
func draw_mark(at: Vector2, r: float, w: int, ink: Color) -> void:
	var width = maxf(1.5, r * 0.32)
	match MARKS[w % MARKS.size()]:
		"circle": canvas.draw_arc(at, r, 0.0, TAU, 16, ink, width, true)
		"triangle": canvas.draw_polyline(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 0.9, r * 0.6), at + Vector2(-r * 0.9, r * 0.6), at + Vector2(0, -r)]), ink, width, true)
		"square": canvas.draw_rect(Rect2(at - Vector2(r, r) * 0.75, Vector2(r, r) * 1.5), ink, false, width)
		"diamond": canvas.draw_polyline(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0), at + Vector2(0, -r)]), ink, width, true)
		"plus":
			canvas.draw_line(at + Vector2(-r, 0), at + Vector2(r, 0), ink, width)
			canvas.draw_line(at + Vector2(0, -r), at + Vector2(0, r), ink, width)

# a joined wire whose twist is slack enough to show its weakest loop
func weak_wire() -> int:
	for i in range(c().count()):
		if c().weakest(i) >= 0: return i
	return -1

func draw_spark(reduce: bool) -> void:
	var age = 0.9 - spark_t
	for p in spark_at:
		var flash = clampf(1.0 - age / 0.25, 0.0, 1.0)
		if flash > 0.0:
			canvas.draw_circle(p, 26.0 * k() * flash, Color(0.85, 0.92, 1.0, 0.55 * flash))
			for r in range(8):
				var a = float(r) * TAU / 8.0 + (0.0 if reduce else age * 9.0)
				canvas.draw_line(p, p + Vector2(cos(a), sin(a)) * (16.0 + 30.0 * flash) * k(), Color(1.0, 0.95, 0.7, flash), 2.0)
		for puff in range(3):
			var up = age * 40.0 + float(puff) * 12.0
			var alpha = clampf(0.45 - age * 0.45, 0.0, 0.45)
			canvas.draw_circle(p + Vector2(float(puff - 1) * 8.0, -up) * k(), (8.0 + age * 14.0) * k(), Color(0.55, 0.55, 0.52, alpha))

# a spark shown at the joints of the wrong pairs (the start from the cab switch failed)
func show_spark(joints: Array) -> void:
	spark_t = 0.9
	spark_at = joints

func wrong_joints() -> Array:
	var joints: Array = []
	for i in range(c().count()):
		if c().joined(i) and c().at(i) != c().terminal_of(i): joints.append(terminal(c().at(i)))
	return joints

# --- the mouse
func nearest_end(mouse: Vector2) -> int:
	var best = -1
	var best_d = GRAB_R
	for i in range(c().count()):
		var d = end_of(i).distance_to(mouse)
		if d < best_d:
			best_d = d
			best = i
	return best

func nearest_terminal(p: Vector2) -> int:
	var best = -1
	var best_d = SNAP_R
	for t in range(c().count()):
		var d = terminal(t).distance_to(p)
		if d < best_d:
			best_d = d
			best = t
	return best

func press(mouse: Vector2) -> bool:
	if not open or not usable(): return false
	last_mouse = mouse
	last_mouse_t = float(canvas.time)
	yanks = []
	if hits.has("lid") and (hits.lid as Rect2).has_point(mouse):
		close()
		return true
	if mode == "bugwind":
		if holder(bug_slot).grow(80.0 * k()).has_point(mouse):
			stroke.regrip(px(mouse))
			return true
		mode = ""   # pressed elsewhere: the winding is given up, the scrap goes back
	for slot in range(3):
		if holder(slot).has_point(mouse) and str(c().st().fuses[slot]) == "burnt":
			if c().replace_fuse(slot): canvas.sound.play("gear", 0.5, 1.8)
			canvas.notify(canvas.model.message)
			return true
	if c().scraps() > 0 and scrap_rect().grow(8.0).has_point(mouse) and not c().is_on():
		mode = "scrap"
		hand = mouse
		return true
	var i = nearest_end(mouse)
	if i >= 0:
		wire = i
		if c().is_on():
			canvas.notify("Включено. Чтобы перекрутить провода, сначала рубильник вниз")
			mode = ""
		elif c().joined(i):
			mode = "twist"
			stroke = LoopStroke.new(px(mouse))
			run = 0
		else:
			mode = "wire"
			hand = mouse
		return true
	return box_rect().has_point(mouse)

func motion(mouse: Vector2) -> void:
	var now = float(canvas.time)
	var dtm = maxf(now - last_mouse_t, 0.001)
	var vel = (mouse - last_mouse) / dtm
	last_mouse = mouse
	last_mouse_t = now
	if mode == "wire" or mode == "scrap":
		hand = mouse
		if mode == "wire" and c().knotted(wire) and mouse.distance_to(hook(wire)) < HOOK_R * k():
			c().unknot(wire)
			canvas.sound.play("gear", 0.45, 1.3)
			canvas.notify(canvas.model.message)
	elif mode == "twist":
		# yanking the held joint back and forth tears it (owner 19.11: «хорошенько подёргав»)
		if vel.length() > TEAR_SPEED * k():
			var dir = signf(vel.x if absf(vel.x) > absf(vel.y) else vel.y)
			if dir != 0.0 and dir != last_dir:
				yanks.append(now)
				last_dir = dir
			while not yanks.is_empty() and now - float(yanks[0]) > TEAR_WINDOW: yanks.pop_front()
			if yanks.size() >= TEAR_YANKS:
				var at_joint = terminal(c().at(wire))
				if c().tear(wire):
					canvas.sound.play("rail_tick_c", 0.6, 1.4)
					show_spark([])
					spark_at = [at_joint]
					spark_t = 0.25
					canvas.notify(canvas.model.message)
				mode = ""
				wire = -1
				return
		var joint = terminal(c().at(wire))
		if mouse.distance_to(joint) > TWIST_LEAVE * k() * 1.4:
			c().unjoin(wire)
			mode = "wire"
			hand = mouse
			return
		stroke.add(px(mouse))
		take_loops()
	elif mode == "bugwind":
		stroke.add(px(mouse))
		stroke.take()
		if stroke.count >= 3:
			if c().bug(bug_slot): canvas.sound.play("rail_tick_b", 0.5, 1.2)
			canvas.notify(canvas.model.message)
			mode = ""

# the loops the stroke has finished go onto the held joint; a loop the other way takes the last one off
func take_loops() -> void:
	var joint = px(terminal(c().at(wire)))
	for loop in stroke.take():
		var before = c().turns(wire)
		var after = c().twist(wire, 1.0, float(run + 1), LoopStroke.quality(loop, joint, LOOP_R), int(loop.dir))
		if after > before:
			run += 1
			canvas.sound.play("rail_tick_a", 0.3, 1.9 + 0.1 * after)
			if (c().st().golden as Array).has(wire): canvas.sound.play("coins", 0.35, 2.2)   # the golden twist rings
		elif after < before:
			run = 0
			canvas.sound.play("rail_tick_a", 0.3, 1.2)

func release(mouse: Vector2) -> void:
	if mode == "twist" and stroke:
		stroke.end()
		take_loops()
	if mode == "wire" and c().knotted(wire):
		canvas.notify("Сначала протяни конец через кольцо его цвета")
	elif mode == "wire":
		var t = nearest_terminal(mouse)
		if t >= 0:
			c().join(wire, t)
			canvas.sound.play("gear", 0.4, 1.6)
	elif mode == "scrap":
		for slot in range(3):
			if holder(slot).grow(10.0).has_point(mouse) and str(c().st().fuses[slot]) == "burnt":
				# the scrap is on the empty holder: now wind it with loops
				mode = "bugwind"
				bug_slot = slot
				stroke = LoopStroke.new(px(mouse))
				canvas.notify("Обмотай держатель проволокой: обведи его петлями")
				return
	if mode == "bugwind": return   # winding goes on with the next press too
	mode = ""
	wire = -1

# --- the keyboard
func key(event: InputEventKey) -> bool:
	if not open or not usable(): return false
	if event.keycode == KEY_ESCAPE and event.pressed:
		close()
		return true
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and event.pressed and not event.echo:
		canvas.electric_cab().flip_switch()
		return true
	if event.keycode == KEY_SPACE:
		if event.pressed and selected >= 0 and c().joined(selected) and not c().is_on():
			key_spin += 0.1
			if key_spin >= 0.999:
				key_spin = 0.0
				c().twist(selected, 1.0)
		return true
	var digit = event.keycode - KEY_1
	if event.pressed and not event.echo and digit >= 0 and digit < c().count():
		if selected < 0 or c().joined(selected):
			selected = digit
			key_spin = 0.0
		elif c().knotted(selected):
			c().unknot(selected)   # the keyboard pulls the end through its ring
			canvas.notify(canvas.model.message)
		elif not c().is_on():
			c().join(selected, digit)
			canvas.sound.play("gear", 0.4, 1.6)
		return true
	return false
