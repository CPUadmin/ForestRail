extends RefCounted
# 1.4.14 Спичка у паровоза в кабине: коробок на месте «Розжига» (картинки П31), клик даёт спичку, и она ходит за
# курсором; крупно поверх доски тёрка: проведи по ней спичкой — скорость прохода решает (медленно царапает, в меру
# вспыхивает, рывком ломается). Горящей (пламя — код) щёлкни левой кнопкой по открытой топке с углём; рывок задувает.
# Двойной щелчок или Esc выбрасывают спичку, клик по коробку даёт новую. Ничего зажимать не нужно (тачпад, 17.11).
# Работает через canvas (main.gd), как contactor_view.gd.

const BOX_CLOSED = preload("res://assets/art_cab/matches/box_closed.png")
const BOX_OPEN = preload("res://assets/art_cab/matches/box_open.png")
const STRIKER = preload("res://assets/art_cab/matches/striker.png")
const MATCH = {"fresh": preload("res://assets/art_cab/matches/match_fresh.png"), "damp": preload("res://assets/art_cab/matches/match_damp.png"),
	"lit": preload("res://assets/art_cab/matches/match_fresh.png"), "broken": preload("res://assets/art_cab/matches/match_broken.png"),
	"burnt": preload("res://assets/art_cab/matches/match_burnt.png"), "rubbed": preload("res://assets/art_cab/matches/match_rubbed.png")}
const STROKE_LEN = 0.6    # a pass counts once it covers this share of the striker
const SPENT_S = 1.2       # a spent match stays in the hand this long, to be seen

var canvas = null
var pos = Vector2.ZERO    # the hand (the head of the match)
var last_pos = Vector2.ZERO
var speed = 0.0           # screen heights per second, smoothed
var stroking = false      # kept for main.gd: nothing is held any more
var in_strip = false
var stroke_dir = 0
var stroke_from = Vector2.ZERO
var stroke_t = 0.0
var spent_t = 0.0
var flare_t = 0.0         # the flash of the head catching

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func f():
	return canvas.model.matches()

func usable() -> bool:
	return canvas.model.vehicle_id() == "steam" and canvas.model.match_rules and canvas.cab_active()

func active() -> bool:
	return usable() and f().hand != ""

# --- the box on the pult: a click gives a match
func take(mouse: Vector2) -> void:
	if not canvas.cab_active():
		canvas.notify("Огонь разжигают в кабине: нажми E")
		return
	if bool(canvas.model.boiler().lit):
		canvas.notify("Огонь уже горит")
		return
	if f().in_hand(): f().drop()   # a new one instead of the one in hand
	if f().take():
		pos = mouse
		last_pos = mouse
		speed = 0.0
		spent_t = 0.0
		canvas.sound.play("cargo", 0.25, 1.9)   # the little drawer of the box
	else:
		canvas.notify(canvas.model.message)

# --- geometry
func striker_rect() -> Rect2:
	var size = canvas.get_viewport_rect().size
	var w = minf(560.0, size.x * 0.42)
	var h = w * float(STRIKER.get_height()) / float(STRIKER.get_width())
	return Rect2(Vector2(size.x * 0.5 - w * 0.5 + 70.0, size.y * 0.36 - h * 0.5), Vector2(w, h))

func open_box_rect() -> Rect2:
	var s = striker_rect()
	var h = s.size.y * 1.9
	var w = h * float(BOX_OPEN.get_width()) / float(BOX_OPEN.get_height())
	return Rect2(Vector2(s.position.x - w - 18.0, s.get_center().y - h * 0.5), Vector2(w, h))

func fire_rect() -> Rect2:
	var local = canvas.steam_fire_rect(canvas.control_zoom_rect())
	return Rect2(canvas.pult_t * local.position, local.size * canvas.pult_t.get_scale())

# --- every frame (main._process)
# 17.11 (owner, tested on a touchpad): nothing is held down. The match follows the cursor; drawn across the striker it is
# struck by itself (the speed of the pass decides); a click on the open firebox with the burning match lights the fire.
func process(dt: float) -> void:
	if not active():
		if f() != null and canvas.model.vehicle_id() == "steam" and f().in_hand() and not canvas.cab_active(): f().drop()
		in_strip = false
		return
	var h = maxf(1.0, canvas.get_viewport_rect().size.y)
	var v = pos.distance_to(last_pos) / maxf(dt, 0.001) / h
	speed = lerpf(speed, v, clampf(dt * 20.0, 0.0, 1.0))
	flare_t = maxf(0.0, flare_t - dt)
	if f().hand in ["fresh", "damp"]: track_stroke(dt)
	else: in_strip = false
	last_pos = pos
	if f().lit():
		f().step(dt)
		if f().jerk(speed): canvas.notify(canvas.model.message)
		elif f().hand == "burnt": canvas.notify(canvas.model.message)
	if f().hand in ["broken", "burnt", "rubbed"]:
		spent_t += dt
		if spent_t >= SPENT_S:
			f().drop()
			spent_t = 0.0

# A pass of the head along the striker: from where it came in (or turned back) until it has covered STROKE_LEN of it.
func track_stroke(dt: float) -> void:
	var s = striker_rect().grow(14.0)
	if not s.has_point(pos):
		in_strip = false
		return
	if not in_strip:
		in_strip = true
		stroke_from = pos
		stroke_t = 0.0
		stroke_dir = 0
		return
	stroke_t += dt
	var dx = pos.x - last_pos.x
	if absf(dx) > 0.5:
		var dir = 1 if dx > 0.0 else -1
		if stroke_dir != 0 and dir != stroke_dir:   # turned back: a new pass starts here
			stroke_from = last_pos
			stroke_t = dt
		stroke_dir = dir
	var covered = absf(pos.x - stroke_from.x) / striker_rect().size.x
	if covered < STROKE_LEN: return
	var result = f().strike(covered / maxf(stroke_t, 0.016))
	stroke_from = pos
	stroke_t = 0.0
	match result:
		"lit":
			flare_t = 0.35
			speed = 0.0   # the stroke itself is not a jerk: the flame is judged from here on
			canvas.sound.play("jet_ignite", 0.35, 2.2)
		"broken":
			canvas.sound.play("rail_tick_c", 0.5, 0.7)
		"scratch", "rubbed":
			canvas.sound.play("rail_tick_b", 0.35, 0.6)
	if result != "": canvas.notify(canvas.model.message)

# --- the mouse
func hover(mouse: Vector2) -> void:
	pos = mouse

# A double click (a double tap on a touchpad) throws the match away, whatever it is. A click of the left button on the
# firebox with a burning match lights it (owner 17.11): the door must be open and there must be coal. Any other single
# click passes on (the door, the bucket), so nothing is held and nothing is lost by a stray tap.
func press(mouse: Vector2, double: bool = false) -> bool:
	if not active(): return false
	pos = mouse
	if double:
		discard()
		return true
	if f().lit() and fire_rect().has_point(mouse):
		if f().to_fire():
			canvas.notify("Огонь разожжён. Давление растёт, подожди")
			canvas.sound.play("jet_ignite", 0.3, 0.6)
		else:
			canvas.notify(canvas.model.message)
		return true
	return false

# kept for the hooks in main.gd (nothing is dragged now): they only move the hand
func motion(mouse: Vector2, _dt: float) -> void:
	pos = mouse

func release(mouse: Vector2) -> void:
	pos = mouse

func discard() -> void:
	f().drop()
	spent_t = 0.0
	in_strip = false

func key(event: InputEventKey) -> bool:
	if not active() or not event.pressed: return false
	if event.keycode == KEY_ESCAPE:
		discard()
		return true
	return false

# --- drawing (after the cab)
func draw() -> void:
	if not active(): return
	var hand = str(f().hand)
	var reduce = bool(canvas.settings.reduce_motion)
	if hand in ["fresh", "damp"]:
		canvas.draw_rect(Rect2(Vector2.ZERO, canvas.get_viewport_rect().size), Color(0, 0, 0, 0.3))
		canvas.draw_texture_rect(BOX_OPEN, open_box_rect(), false)
		var s = striker_rect()
		canvas.draw_texture_rect(STRIKER, s, false)
		var line = "Проведи спичкой по тёрке: не медленно и не рывком. Двойной щелчок или Esc — выбросить"
		var width = canvas.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 28.0
		var plate = Rect2(Vector2(s.get_center().x - width * 0.5, s.end.y + 14.0), Vector2(width, 28.0))
		canvas.draw_style_box(canvas.style(Color(0.08, 0.07, 0.05, 0.92), Color("8a6a3a"), 6), plate)
		canvas.draw_string(canvas.font, plate.position + Vector2(0, 19), line, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 15, Color("e8dcb4"))
		if in_strip:   # the scratch the head leaves on the striker
			canvas.draw_line(stroke_from, Vector2(pos.x, clampf(pos.y, s.position.y, s.end.y)), Color(1.0, 0.85, 0.55, 0.5), 2.0)
	if f().lit():
		# the open firebox glows as the target
		var fire = fire_rect()
		var pulse = 0.5 if reduce else 0.5 + 0.5 * sin(float(canvas.time) * 6.0)
		canvas.draw_rect(fire.grow(4.0), Color(1.0, 0.6, 0.2, 0.25 + 0.25 * pulse), false, 3.0)
		var hint = "Щёлкни спичкой по топке" if bool(canvas.model.boiler().door) else "Сначала открой дверцу топки"
		var hint_w = canvas.font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24.0
		var hint_plate = Rect2(Vector2(fire.get_center().x - hint_w * 0.5, fire.position.y - 40.0), Vector2(hint_w, 26.0))
		canvas.draw_style_box(canvas.style(Color(0.08, 0.07, 0.05, 0.92), Color("8a6a3a"), 6), hint_plate)
		canvas.draw_string(canvas.font, hint_plate.position + Vector2(0, 18), hint, HORIZONTAL_ALIGNMENT_CENTER, hint_plate.size.x, 15, Color("f3d27a"))
	draw_match(hand, reduce)

# the match lies in the hand, head at the cursor, tilted up
func draw_match(hand: String, reduce: bool) -> void:
	var tex: Texture2D = MATCH.get(hand, MATCH.fresh)
	var len = 150.0
	var thick = len * float(tex.get_height()) / float(tex.get_width())
	var angle = -0.5
	canvas.draw_set_transform(pos, angle, Vector2.ONE)
	canvas.draw_texture_rect(tex, Rect2(Vector2(-len, -thick * 0.5), Vector2(len, thick)), false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hand == "lit": draw_flame(pos, reduce)

# the flame: a few soft layers, a flicker, it leans back against the motion; the flash when it catches
func draw_flame(at: Vector2, reduce: bool) -> void:
	var t = float(canvas.time)
	var flicker = 1.0 if reduce else 0.85 + 0.15 * sin(t * 23.0) + 0.08 * sin(t * 41.0)
	var life = clampf(f().burn / 1.5, 0.3, 1.0)   # it shrinks in the last moment
	var size = 16.0 * flicker * life + 22.0 * flare_t
	var lean = Vector2(-(pos.x - last_pos.x), 0) * 0.15
	canvas.draw_circle(at, size * 2.2, Color(1.0, 0.6, 0.2, 0.12))
	for layer in [[1.0, Color(1.0, 0.45, 0.1, 0.85)], [0.68, Color(1.0, 0.78, 0.25, 0.9)], [0.38, Color(1.0, 0.97, 0.8, 0.95)]]:
		var r = size * float(layer[0])
		var tip = at + Vector2(0, -r * 1.9) + lean * float(layer[0])
		var pts = PackedVector2Array()
		for i in range(14):
			var a = PI * float(i) / 13.0
			pts.append(at + Vector2(cos(a + PI) * r * 0.7, sin(a) * r * 0.55))
		pts.append(tip)
		canvas.draw_colored_polygon(pts, layer[1])
