extends RefCounted
# The ignition key of the petrol motorcar (owner 14.11, 16.11): a painted lock, the key the player turns with the
# mouse or holds with a key of the keyboard, the leather fob on its chain (a small damped pendulum) and the choke knob.
# Three positions: ВЫКЛ -> ЗАЖИГАНИЕ -> СТАРТЕР (on a spring). Held about a second on СТАРТЕР the starter has turned
# enough and the engine catches or coughs (Model.key_crank). main.gd keeps one of these, calls update() every frame,
# press/drag_to/release from the mouse and the keyboard, and draws it in the cab pult and on the machine outside.

const LOCK = preload("res://assets/art_cab/ignition_lock.png")
const CORE = preload("res://assets/art_cab/ignition_lock_core.png")   # the turning cylinder, cut from the lock
const CORE_CENTRE = Vector2(77.5, 77.0)
const HEAD = preload("res://assets/art_cab/ignition_key_head.png")
const FOB = preload("res://assets/art_cab/key_fob.png")
const CHOKE_IN = preload("res://assets/art_cab/choke_knob_in.png")
const CHOKE_OUT = preload("res://assets/art_cab/choke_knob_out.png")

const OFF = 0
const ON = 1
const START = 2
const ANGLES = [0.0, 0.62, 1.12]          # radians, clockwise from upright: the three marks of the painted lock
const NAMES = ["Выкл.", "Зажигание", "Стартер"]
const HOLD_TO_START = 0.3                 # a press held this long goes on past ЗАЖИГАНИЕ to СТАРТЕР
const CRANK_S = 1.0                       # the starter turns this long before the engine catches or coughs
# picture anchors, pixels of the cut PNGs
const LOCK_CENTRE = Vector2(180.5, 180.0)
const HEAD_CENTRE = Vector2(98.6, 90.3)   # the hole of the head: the fob hangs in it
const HEAD_HOLE_R = 34.0
const KEY_ROOT = Vector2(98.6, 206.0)     # the bottom of the collar: here the blade goes into the keyhole
const KEY_SCALE = 0.95                    # the key against the lock
const FOB_TOP = Vector2(66.0, 0.0)
const FOB_SCALE = 0.72                    # the fob against the lock: a little smaller than painted, so it fits the pult
const CHOKE_ANCHOR = Vector2(0.0, 84.0)   # the left edge of the panel, its middle

var model = null
var reduce_motion = false
var pos = OFF
var angle = 0.0           # the drawn angle of the key
var angle_v = 0.0
var held = false
var dragging = false
var drag_angle = 0.0
var hold_t = 0.0
var press_pos = OFF
var crank_t = 0.0
var crank_ok = false      # the rules (neutral, throttle 0, fuel) allowed this turn of the starter
var rolled = false        # this turn of the starter has had its dice
var cough_t = 9.0         # seconds since the last cough: the key twitches once
var clock = 0.0
var events: Array = []    # for main.gd: click, refused, crank_tick, caught, coughed
var tick_t = 0.0
# the fob: angle from the vertical of the screen, its speed, and what pushes it
var fob_theta = 0.0
var fob_omega = 0.0
var pivot_screen = Vector2.ZERO   # where the fob hangs, screen pixels (set by draw)
var fob_length_screen = 60.0
var prev_pivot = Vector2.ZERO
var prev_pivot_v = Vector2.ZERO
var prev_mouse = Vector2.ZERO
var has_prev = false

func _init(owner_model = null) -> void:
	model = owner_model

func cranking() -> bool:
	return pos == START and crank_ok and not rolled

# The key shows ЗАЖИГАНИЕ whenever the engine runs (it may have been started by a save or a test).
func sync() -> void:
	if model == null or model.state.is_empty(): return
	if bool(model.state.engine) and pos == OFF: pos = ON

func set_pos(value: int) -> void:
	if value == pos: return
	pos = value
	events.append("click")
	crank_t = 0.0
	rolled = false
	crank_ok = false
	if pos == OFF and bool(model.state.engine):
		model.start_engine(false)
	if pos == START and not bool(model.state.engine):
		crank_ok = model.can_start()
		if not crank_ok: events.append("refused")

func press() -> void:
	sync()
	held = true
	dragging = false
	hold_t = 0.0
	press_pos = pos
	if pos == OFF: set_pos(ON)

# Turning by dragging round the lock: the key follows the cursor between its stops, the nearest position counts.
func drag_to(target: float) -> void:
	dragging = true
	drag_angle = clampf(target, ANGLES[OFF] - 0.06, ANGLES[START] + 0.06)
	if drag_angle < ANGLES[ON] * 0.5: set_pos(OFF)
	elif drag_angle < (ANGLES[ON] + ANGLES[START]) * 0.5 + 0.08: set_pos(ON)
	else: set_pos(START)

func release() -> void:
	if not held: return
	held = false
	# a short click on ЗАЖИГАНИЕ turns the key back to ВЫКЛ (the engine stops)
	if not dragging and hold_t < HOLD_TO_START and press_pos == ON and pos == ON: set_pos(OFF)
	if pos == START: set_pos(ON)   # the spring
	dragging = false

func update(dt: float, mouse: Vector2) -> void:
	if model == null or model.state.is_empty(): return
	dt = minf(dt, 0.05)
	clock += dt
	sync()
	if held and not dragging:
		hold_t += dt
		if hold_t >= HOLD_TO_START and pos == ON and not bool(model.state.engine): set_pos(START)
	if cranking():
		crank_t += dt
		tick_t -= dt
		if tick_t <= 0.0:
			tick_t = 0.17
			events.append("crank_tick")
		if crank_t >= CRANK_S:
			rolled = true
			if model.key_crank(): events.append("caught")
			else:
				events.append("coughed")
				cough_t = 0.0
	cough_t += dt
	# the key: a stiff spring towards its position, it overshoots a hair when it snaps back from the starter
	var target = drag_angle if dragging else float(ANGLES[pos])
	var old_v = angle_v
	var w = 26.0
	angle_v += ((target - angle) * w * w - 2.0 * 0.55 * w * angle_v) * dt
	angle += angle_v * dt
	var angle_acc = (angle_v - old_v) / maxf(dt, 0.001)
	update_fob(dt, mouse, angle_acc)

# The fob is a pendulum hanging from the hole of the key: theta'' = -(g/L) sin(theta) - c theta' + pushes.
# It is pushed by the key turning (the ring drags it round), by the shake of the machine (the acceleration of the
# point it hangs from) and a little by the cursor passing over it.
func update_fob(dt: float, mouse: Vector2, key_acc: float) -> void:
	if reduce_motion:
		fob_theta = 0.0
		fob_omega = 0.0
		has_prev = false
		return
	var push = -0.15 * clampf(key_acc, -500.0, 500.0)
	if has_prev and dt > 0.0:
		var v = (pivot_screen - prev_pivot) / dt
		var a = (v - prev_pivot_v) / dt
		prev_pivot_v = v
		# the frame accelerates one way, the fob swings the other (in pendulum lengths per second squared)
		push += -clampf(a.x, -3000.0, 3000.0) / maxf(20.0, fob_length_screen) * cos(fob_theta) * 0.6
		var mouse_v = (mouse - prev_mouse) / dt
		var bob = pivot_screen + Vector2(sin(fob_theta), cos(fob_theta)) * fob_length_screen * 0.7
		var near = 1.0 - clampf(mouse.distance_to(bob) / maxf(18.0, fob_length_screen * 0.6), 0.0, 1.0)
		push += clampf(mouse_v.x, -1500.0, 1500.0) * near * 0.03
	prev_pivot = pivot_screen
	prev_mouse = mouse
	has_prev = true
	if cranking(): push += sin(clock * 55.0) * 6.0
	var w0 = 9.0   # about 1.4 swings a second: a small fob on a short chain
	fob_omega += (-w0 * w0 * sin(fob_theta) - 1.6 * fob_omega + push) * dt
	fob_theta = clampf(fob_theta + fob_omega * dt, -1.2, 1.2)

# The small trembling of the key while the starter turns and the twitch of a cough.
func shake_offset() -> Vector2:
	if reduce_motion: return Vector2.ZERO
	var s = Vector2.ZERO
	if cranking(): s += Vector2(sin(clock * 61.0), cos(clock * 47.0)) * 0.9
	if cough_t < 0.25: s += Vector2(sin(cough_t * 90.0), 0.0) * 2.0 * (1.0 - cough_t / 0.25)
	return s

func shake_angle() -> float:
	if reduce_motion: return 0.0
	return sin(clock * 53.0) * 0.035 if cranking() else 0.0

# Draws the lock with the key and the fob, centred on `centre` of the current draw transform, `side` pixels wide.
# `xform` is the transform the canvas draws with (for the fob to hang straight down on the screen and for the shake).
func draw(canvas, centre: Vector2, side: float, xform: Transform2D, hovered: bool) -> void:
	var scale = side / float(LOCK.get_width())
	var shake = xform.affine_inverse().basis_xform(shake_offset()) if xform.determinant() != 0.0 else Vector2.ZERO
	canvas.draw_set_transform_matrix(xform)
	canvas.draw_texture_rect(LOCK, Rect2(centre - LOCK_CENTRE * scale, LOCK.get_size() * scale), false)
	if hovered: canvas.draw_arc(centre, side * 0.5, 0, TAU, 40, Color(1.0, 0.86, 0.5, 0.55), maxf(1.0, side * 0.025), true)
	# the key stands out of the keyhole (its blade is in the lock) and turns about the keyhole; a soft shadow under it
	var key_scale = scale * KEY_SCALE
	var root = centre + shake
	var turn = angle + shake_angle()
	# the cylinder of the lock (with its keyhole) turns with the key
	canvas.draw_set_transform_matrix(xform * Transform2D(angle, centre))
	canvas.draw_texture_rect(CORE, Rect2(-CORE_CENTRE * scale, CORE.get_size() * scale), false)
	canvas.draw_set_transform_matrix(xform * Transform2D(turn, root + Vector2(0.03, 0.045) * side))
	canvas.draw_texture_rect(HEAD, Rect2(-KEY_ROOT * key_scale, HEAD.get_size() * key_scale), false, Color(0, 0, 0, 0.45))
	canvas.draw_set_transform_matrix(xform * Transform2D(turn, root))
	canvas.draw_texture_rect(HEAD, Rect2(-KEY_ROOT * key_scale, HEAD.get_size() * key_scale), false)
	# the fob hangs from the top of the hole in the head, straight down on the screen whatever the tilt of the machine
	var hole = root + ((HEAD_CENTRE - KEY_ROOT) * key_scale).rotated(turn)
	var hang = hole + Vector2(0, -HEAD_HOLE_R * 0.6 * key_scale).rotated(-xform.get_rotation())
	var fob_scale = scale * FOB_SCALE
	pivot_screen = xform * hang
	fob_length_screen = FOB.get_height() * fob_scale * xform.get_scale().x
	canvas.draw_set_transform_matrix(xform * Transform2D(fob_theta - xform.get_rotation(), hang))
	canvas.draw_texture_rect(FOB, Rect2(-FOB_TOP * fob_scale, FOB.get_size() * fob_scale), false)
	canvas.draw_set_transform_matrix(xform)

# The choke knob: `at` is the left edge of its panel (middle), `height` its drawn height.
func choke_rect(at: Vector2, height: float) -> Rect2:
	var scale = height / float(CHOKE_OUT.get_height())
	return Rect2(at - CHOKE_ANCHOR * scale, CHOKE_OUT.get_size() * scale)

func draw_choke(canvas, at: Vector2, height: float, hovered: bool) -> void:
	var out = model != null and not model.state.is_empty() and model.choke_out()
	var tex = CHOKE_OUT if out else CHOKE_IN
	var scale = height / float(tex.get_height())
	var rect = Rect2(at - CHOKE_ANCHOR * scale, tex.get_size() * scale)
	if hovered: canvas.draw_rect(rect.grow(2.0), Color(1.0, 0.86, 0.5, 0.35), false, 1.5)
	canvas.draw_texture_rect(tex, rect, false)
