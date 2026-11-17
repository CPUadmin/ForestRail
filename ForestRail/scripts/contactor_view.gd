extends RefCounted
# 1.4.10 «Скрутка» в кабине электровоза: ящик КОНТАКТОР крупно поверх доски (картинки П21 и кнопка с лампой из П17;
# провода, скрутка, искра и дым рисуются кодом). Работает через canvas (main.gd), как depot_ui.gd.
#
# Мышь: клик по крышке ящика открывает его, клик по откинутой крышке закрывает. Конец провода тащится мышью и прилипает
# к клемме. Зажав мышь на стыке, обведи его курсором два раза — медь скручивается. Красная кнопка — ПУСК/СТОП.
# Клавиатура (ящик открыт): цифра выбирает провод, вторая цифра — клемму; пробел, пока держишь, крутит выбранный стык;
# Enter — ПУСК/СТОП; Esc закрывает ящик.

const BOX = preload("res://assets/art_electric/contactor/box_open.png")
const LID_OPEN = preload("res://assets/art_electric/contactor/lid_open.png")
const FUSE = preload("res://assets/art_electric/contactor/fuse.png")
const FUSE_BURNT = preload("res://assets/art_electric/contactor/fuse_burnt.png")
const TORN = preload("res://assets/art_electric/contactor/torn_ends.png")
const BUTTON_DARK = preload("res://assets/art_electric/contactor/button_dark.png")
const BUTTON_LIT = preload("res://assets/art_electric/contactor/button_lit.png")
const LAMP_OFF = preload("res://assets/art_electric/contactor/lamp_off.png")
const LAMP_READY = preload("res://assets/art_electric/contactor/lamp_ready.png")

# places in the picture of the open box (638 × 343 px)
const BOX_PX = Vector2(638, 343)
const ROWS_Y = [78.0, 125.0, 170.0, 213.0, 256.0]
const LEFT_X = 105.0
const RIGHT_X = 533.0
const LAMP_AT = Vector2(320, 82)
const FUSES_AT = [Vector2(208, 272), Vector2(320, 272), Vector2(432, 272)]
# five wires, each its colour AND its pattern, so they differ without colour too (owner 14.11)
const COLORS = [Color("c8402f"), Color("3a6fb5"), Color("e0b33a"), Color("4f9a4f"), Color("e8e2d0")]
const PATTERNS = ["solid", "stripe", "dots", "check", "double"]
const COPPER = Color("d08a4a")
const GRAB_R = 26.0        # px of the screen: how near the end must be pressed
const SNAP_R = 34.0        # px: how near a terminal the end sticks
const TWIST_LEAVE = 80.0   # px: dragged this far from the joint, the end comes off instead of twisting

var canvas = null
var open = false
var mode = ""              # "" | "wire" (dragging an end) | "twist" (circling a joint)
var wire = -1              # the wire in hand or being twisted
var hand = Vector2.ZERO    # where the dragged end is
var last_angle = 0.0
var twist_sum = 0.0        # turns counted in the current circling
var selected = -1          # keyboard: the chosen wire
var spark_t = 0.0          # seconds of the flash and smoke after a wrong pair
var spark_at: Array = []   # screen points of the spark
var lid_t = 0.0            # 0..1 the lid swings open
var hits: Dictionary = {}

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
		canvas.sound.play("gear", 0.5, 0.6)   # the hinges
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
	var w = minf(620.0, size.x * 0.44)
	var h = w * BOX_PX.y / BOX_PX.x
	# in the middle of the screen, a little left to leave room for the button; low enough for the lid above it
	return Rect2(Vector2(size.x * 0.5 - w * 0.5 - 50.0, size.y * 0.5 - h * 0.5 + 10.0), Vector2(w, h))

func k() -> float:
	return box_rect().size.x / BOX_PX.x

func at_px(p: Vector2) -> Vector2:
	return box_rect().position + p * k()

func first_row() -> int:
	return (ROWS_Y.size() - c().count()) / 2

func root(i: int) -> Vector2:
	return at_px(Vector2(LEFT_X + 22.0, ROWS_Y[first_row() + i]))

func terminal(t: int) -> Vector2:
	return at_px(Vector2(RIGHT_X - 22.0, ROWS_Y[first_row() + t]))

func rest(i: int) -> Vector2:   # a free end hangs down in the middle of the box
	return at_px(Vector2(200.0 + 26.0 * float(i), ROWS_Y[first_row() + i] + 34.0))

func end_of(i: int) -> Vector2:
	if mode == "wire" and wire == i: return hand
	if c().joined(i):
		var p = terminal(c().at(i))
		if (c().st().popped as Array).has(i): p += Vector2(-16, 12) * k()   # popped: off the screw
		return p
	return rest(i)

func button_rect() -> Rect2:
	var plate = button_plate()
	var side = plate.size.x - 24.0
	return Rect2(plate.position + Vector2(12.0, 14.0), Vector2(side, side))

# the button sits on its own riveted plate fixed to the right side of the box (it covers what is under it in the cab)
func button_plate() -> Rect2:
	var box = box_rect()
	var w = 104.0 * k() * 1.1 + 24.0
	var h = w + 30.0
	return Rect2(Vector2(box.end.x - 6.0, box.position.y + box.size.y * 0.5 - h * 0.5), Vector2(w, h))

func lid_rect() -> Rect2:
	var box = box_rect()
	var w = box.size.x * 0.92
	var h = w * float(LID_OPEN.get_height()) / float(LID_OPEN.get_width())
	return Rect2(Vector2(box.position.x + (box.size.x - w) * 0.5, box.position.y - h + 8.0), Vector2(w, h))

# --- drawing (called after the cab is drawn, so the box lies on top)
func draw(dt: float) -> void:
	if not open or not usable(): return
	lid_t = minf(1.0, lid_t + dt * 5.0)
	spark_t = maxf(0.0, spark_t - dt)
	var box = box_rect()
	var reduce = bool(canvas.settings.reduce_motion)
	# the lid swung open on its hinges, with a little bounce
	var bounce = 0.0 if reduce else sin(lid_t * PI * 2.0) * (1.0 - lid_t) * 8.0
	var lid = lid_rect()
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.get_viewport_rect().size), Color(0, 0, 0, 0.38))   # the cab dims a little: the box is what matters now
	canvas.draw_texture_rect(LID_OPEN, Rect2(lid.position + Vector2(0, bounce), lid.size), false)
	canvas.draw_texture_rect(BOX, box, false)
	var kk = k()
	# the fuses in their sockets; the middle one burnt for a moment after a spark
	for f in range(FUSES_AT.size()):
		var tex = FUSE_BURNT if (f == 1 and spark_t > 0.0) else FUSE
		var w = 92.0 * kk
		var h = w * float(tex.get_height()) / float(tex.get_width())
		canvas.draw_texture_rect(tex, Rect2(at_px(FUSES_AT[f]) - Vector2(w, h) * 0.5, Vector2(w, h)), false)
	# the lamp ГОТОВ in the top socket
	var lamp = LAMP_READY if c().ready() else LAMP_OFF
	var lw = 104.0 * kk
	var lh = lw * float(lamp.get_height()) / float(lamp.get_width())
	canvas.draw_texture_rect(lamp, Rect2(at_px(LAMP_AT) - Vector2(lw, lh) * 0.5, Vector2(lw, lh)), false)
	canvas.draw_string(canvas.font, at_px(LAMP_AT) + Vector2(-lw * 0.5, lh * 0.5 + 14.0 * kk), "ГОТОВ", HORIZONTAL_ALIGNMENT_CENTER, lw, int(13.0 * kk + 3.0), Color("c7c3a0"))
	# the coloured tags by the right terminals: here goes the wire of this colour and pattern
	var n = c().count()
	for w in range(n):
		var t = c().terminal_of(w)
		var tag = Rect2(terminal(t) + Vector2(-46, -9) * kk, Vector2(26, 18) * kk)
		draw_band(tag, w)
	# the wires: from the harness on the left, with a soft sag; the bare copper end; the twist as a little spiral
	for i in range(n):
		draw_wire(i)
	# the spark and the smoke after a wrong pair (procedural)
	if spark_t > 0.0: draw_spark(reduce)
	# the button ПУСК/СТОП
	var btn = button_rect()
	var btn_plate = button_plate()
	canvas.draw_style_box(canvas.style(Color("1f2620"), Color("b08a46"), 8), btn_plate)
	for corner in [Vector2(7, 7), Vector2(btn_plate.size.x - 7, 7), Vector2(7, btn_plate.size.y - 7), Vector2(btn_plate.size.x - 7, btn_plate.size.y - 7)]:
		canvas.draw_circle(btn_plate.position + corner, 3.0, Color("c9a85a"))
	canvas.draw_texture_rect(BUTTON_LIT if c().is_on() else BUTTON_DARK, btn, false)
	canvas.draw_string(canvas.font, Vector2(btn_plate.position.x, btn_plate.end.y - 9.0), "СТОП" if c().is_on() else "ПУСК", HORIZONTAL_ALIGNMENT_CENTER, btn_plate.size.x, 16, canvas.PAPER)
	# one short line of help, only while it is not ready
	if not c().is_on():
		var line = "Подведи каждый провод к клемме с его цветом и обведи стык курсором два раза" if not c().ready() else "Готово: жми ПУСК"
		var width = canvas.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 28.0
		var plate = Rect2(Vector2(box.position.x + box.size.x * 0.5 - width * 0.5, box.end.y + 10.0), Vector2(width, 28.0))
		canvas.draw_style_box(canvas.style(Color(0.08, 0.07, 0.05, 0.92), Color("8a6a3a"), 6), plate)
		canvas.draw_string(canvas.font, plate.position + Vector2(0, 19), line, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 15, Color("e8dcb4"))
	hits = {"button": btn, "lid": lid}

func draw_band(rect: Rect2, w: int) -> void:
	var col: Color = COLORS[w % COLORS.size()]
	canvas.draw_rect(rect.grow(1.5), Color("1a1410"))
	canvas.draw_rect(rect, col)
	var dark = col.darkened(0.55)
	match PATTERNS[w % PATTERNS.size()]:
		"stripe":
			canvas.draw_line(rect.position + Vector2(0, rect.size.y * 0.5), rect.end - Vector2(0, rect.size.y * 0.5), dark, maxf(2.0, rect.size.y * 0.25))
		"dots":
			for d in range(3): canvas.draw_circle(rect.position + Vector2(rect.size.x * (0.2 + 0.3 * d), rect.size.y * 0.5), rect.size.y * 0.18, dark)
		"check":
			for d in range(4):
				if d % 2 == 0: canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.25 * d, 0), Vector2(rect.size.x * 0.25, rect.size.y * 0.5)), dark)
				else: canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.25 * d, rect.size.y * 0.5), Vector2(rect.size.x * 0.25, rect.size.y * 0.5)), dark)
		"double":
			canvas.draw_line(rect.position + Vector2(0, rect.size.y * 0.3), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.3), dark, 2.0)
			canvas.draw_line(rect.position + Vector2(0, rect.size.y * 0.7), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.7), dark, 2.0)

func wire_points(i: int) -> PackedVector2Array:
	var a = root(i)
	var b = end_of(i)
	var sway = 0.0 if bool(canvas.settings.reduce_motion) else sin(float(canvas.time) * 2.3 + float(i) * 1.7) * 3.0
	var sag = Vector2(sway, 30.0 + a.distance_to(b) * 0.12) * k()
	var ctrl1 = a + (b - a) * 0.33 + sag
	var ctrl2 = a + (b - a) * 0.66 + sag
	var pts = PackedVector2Array()
	for s in range(25):
		var t = float(s) / 24.0
		var u = 1.0 - t
		pts.append(a * u * u * u + ctrl1 * 3.0 * u * u * t + ctrl2 * 3.0 * u * t * t + b * t * t * t)
	return pts

func draw_wire(i: int) -> void:
	var pts = wire_points(i)
	var col: Color = COLORS[i % COLORS.size()]
	var dark = col.darkened(0.55)
	var kk = k()
	var body = pts.slice(0, pts.size() - 3)
	canvas.draw_polyline(body, Color("140f0b"), 11.0 * kk + 1.0, true)
	canvas.draw_polyline(body, col, 8.0 * kk, true)
	match PATTERNS[i % PATTERNS.size()]:
		"stripe":
			for s in range(0, body.size() - 1, 2): canvas.draw_line(body[s], body[s + 1], dark, 3.0 * kk)
		"dots":
			for s in range(1, body.size(), 3): canvas.draw_circle(body[s], 2.4 * kk, dark)
		"check":
			for s in range(0, body.size() - 1, 2):
				var along = (body[s + 1] - body[s]).normalized()
				var across = Vector2(-along.y, along.x) * 3.2 * kk
				canvas.draw_line(body[s] - across, body[s] + across, dark, 2.0 * kk)
		"double":
			for s in range(body.size() - 1):
				var along = (body[s + 1] - body[s]).normalized()
				var across = Vector2(-along.y, along.x) * 2.2 * kk
				canvas.draw_line(body[s] + across, body[s + 1] + across, dark, 1.4)
				canvas.draw_line(body[s] - across, body[s + 1] - across, dark, 1.4)
	# the bare copper end
	canvas.draw_polyline(pts.slice(pts.size() - 4, pts.size()), COPPER, 4.0 * kk, true)
	var tip = pts[pts.size() - 1]
	var st = c().st()
	if (st.torn as Array).has(i) and not c().joined(i):
		var tw = 46.0 * kk
		canvas.draw_texture_rect(TORN, Rect2(tip - Vector2(tw * 0.5, tw * 0.35), Vector2(tw, tw * 0.7)), false)
	if c().joined(i):
		# the twist: a little copper spiral, one coil per half turn; a green dot when it holds
		var coils = int(c().turns(i) * 2.0)
		for coil in range(coils):
			var cx = tip + Vector2(-4.0 - 3.0 * coil, 0) * kk
			canvas.draw_arc(cx, 4.5 * kk, 0.0, TAU, 12, COPPER.lightened(0.15 if coil % 2 == 0 else 0.0), 1.8 * kk, true)
		if c().twisted(i):
			canvas.draw_circle(tip + Vector2(0, -14) * kk, 4.0 * kk, Color("5cc17f"))
		if (st.popped as Array).has(i) and fmod(float(canvas.time) * 3.0, 1.0) < 0.5:
			canvas.draw_circle(tip + Vector2(0, -14) * kk, 4.0 * kk, Color("e0564a"))
	if selected == i:
		canvas.draw_arc(tip, 12.0 * kk, 0.0, TAU, 20, Color("f3d27a"), 2.0, true)

func draw_spark(reduce: bool) -> void:
	var age = 0.9 - spark_t
	for p in spark_at:
		var flash = clampf(1.0 - age / 0.25, 0.0, 1.0)
		if flash > 0.0:
			canvas.draw_circle(p, 22.0 * k() * flash, Color(0.85, 0.92, 1.0, 0.55 * flash))
			for r in range(8):
				var a = float(r) * TAU / 8.0 + (0.0 if reduce else age * 9.0)
				canvas.draw_line(p, p + Vector2(cos(a), sin(a)) * (14.0 + 26.0 * flash) * k(), Color(1.0, 0.95, 0.7, flash), 2.0)
		# a grey puff rising from the joint
		for puff in range(3):
			var up = age * 40.0 + float(puff) * 12.0
			var alpha = clampf(0.45 - age * 0.45, 0.0, 0.45)
			canvas.draw_circle(p + Vector2(float(puff - 1) * 8.0, -up) * k(), (8.0 + age * 14.0) * k(), Color(0.55, 0.55, 0.52, alpha))

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

# true when the press was the box's
func press(mouse: Vector2) -> bool:
	if not open or not usable(): return false
	if hits.has("button") and (hits.button as Rect2).has_point(mouse):
		push_button()
		return true
	if hits.has("lid") and (hits.lid as Rect2).has_point(mouse):
		close()
		return true
	var i = nearest_end(mouse)
	if i >= 0:
		wire = i
		if c().joined(i) and not c().is_on():
			mode = "twist"
			twist_sum = 0.0
			last_angle = (mouse - terminal(c().at(i))).angle()
		elif not c().is_on():
			mode = "wire"
			hand = mouse
		else:
			canvas.notify("Контактор включён. Чтобы перекрутить провода, сначала СТОП")
			mode = ""
		return true
	return box_rect().has_point(mouse) or button_rect().has_point(mouse)

func motion(mouse: Vector2) -> void:
	if mode == "wire":
		hand = mouse
	elif mode == "twist":
		var joint = terminal(c().at(wire))
		if mouse.distance_to(joint) > TWIST_LEAVE * k() * 1.4:
			# pulled away: the end comes off the terminal and is in hand
			c().unjoin(wire)
			mode = "wire"
			hand = mouse
			return
		if mouse.distance_to(joint) < 6.0: return
		var angle = (mouse - joint).angle()
		var delta = wrapf(angle - last_angle, -PI, PI)
		last_angle = angle
		var before = absf(twist_sum)
		twist_sum += delta / TAU
		var gained = absf(twist_sum) - before
		if gained > 0.0:
			var turns_before = c().turns(wire)
			var after = c().twist(wire, gained)
			if floori(after * 2.0) > floori(turns_before * 2.0):
				canvas.sound.play("rail_tick_a", 0.3, 1.9 + 0.1 * after)   # the copper creaks a little on every half turn

func release(mouse: Vector2) -> void:
	if mode == "wire":
		var t = nearest_terminal(mouse)
		if t >= 0:
			c().join(wire, t)
			canvas.sound.play("gear", 0.4, 1.6)
	mode = ""
	wire = -1

func push_button() -> void:
	var m = canvas.model
	var was_on = c().is_on()
	# where a wrong pair would spark: the joints as they are before the press (a spark tears those wires off)
	var joints: Array = []
	for i in range(c().count()):
		if c().joined(i) and c().at(i) != c().terminal_of(i): joints.append(terminal(c().at(i)))
	var ok = c().press()
	if ok:
		canvas.sound.play("contactor", 0.9, 0.85 if not was_on else 0.7)
		canvas.notify(m.message if not was_on else "Контактор выключен, провода разведены")
	else:
		if m.message.begins_with("Искра"):
			spark_t = 0.9
			spark_at = joints
			canvas.sound.play("contactor", 1.0, 1.7)
		canvas.notify(m.message)
	canvas.save_game()

# --- the keyboard: true when the key was the box's
func key(event: InputEventKey) -> bool:
	if not open or not usable(): return false
	if event.keycode == KEY_ESCAPE and event.pressed:
		close()
		return true
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and event.pressed and not event.echo:
		push_button()
		return true
	if event.keycode == KEY_SPACE:
		if event.pressed and selected >= 0 and c().joined(selected) and not c().is_on():
			c().twist(selected, 0.08)   # held: about a turn every 0.2 s of key repeat
		return true
	var digit = event.keycode - KEY_1
	if event.pressed and not event.echo and digit >= 0 and digit < c().count():
		if selected < 0 or c().joined(selected):
			selected = digit
		elif not c().is_on():
			c().join(selected, digit)
			canvas.sound.play("gear", 0.4, 1.6)
		return true
	return false
