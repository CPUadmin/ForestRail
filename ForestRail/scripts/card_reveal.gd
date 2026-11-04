extends Control
# Получение карточки Таро (docs/KAZIK_CARDS_RU.md, этап «д»): экран темнеет, за картой разгораются вращающиеся лучи,
# карта вылетает из колеса рубашкой вверх и кружится, замирает с пульсирующим свечением, переворачивается со вспышкой,
# волной и россыпью золотых искр; Михалыч говорит свою реплику. Щелчок во время показа пропускает к концу, потом забирает карту.

const CardView = preload("res://scripts/card_view.gd")

signal closed

const RISE = 1.1              # вылет и кручение
const HOLD = 0.7              # рубашка замерла, свечение дышит
const FLIP_AT = 1.8           # RISE + HOLD: начало переворота
const BURST_AT = 2.075        # середина переворота: вспышка, волна, искры
const END = 3.0               # всё показано, можно забрать

var game
var card_id = "fool"
var origin = Vector2(800, 400)   # откуда вылетает карта (центр колеса)
var quick = false                # без тряски и мерцания: сразу готовая карта
var said = ""
var card: Control
var line_label: Label
var take_label: Label
var t = 0.0
var flipped_started = false
var burst_done = false
var sparks: Array = []
var rng = RandomNumberGenerator.new()
var glow: Texture2D
var ring = -1.0                  # волна после переворота, секунд с начала, -1: нет

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.seed = 7
	glow = load("res://assets/art_kazik/glow.png")
	card = CardView.new()
	card.game = game
	card.card_id = card_id
	card.show_back = true
	var h = size.y * 0.72
	card.size = Vector2(h / 1.59, h)
	card.pivot_offset = card.size * 0.5
	add_child(card)
	said = card.found_line()
	line_label = Label.new()
	line_label.text = "«%s»\n— Михалыч" % said
	line_label.add_theme_font_size_override("font_size", 26)
	line_label.add_theme_color_override("font_color", Color("fff1cc"))
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_label.size = Vector2(size.x * 0.62, 90)
	line_label.position = Vector2(size.x * 0.19, size.y * 0.08 + h + 8.0)
	line_label.modulate.a = 0.0
	add_child(line_label)
	take_label = Label.new()
	take_label.text = "Нажми, чтобы забрать"
	take_label.add_theme_font_size_override("font_size", 18)
	take_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.58, 0.85))
	take_label.size = Vector2(size.x, 26)
	take_label.position = Vector2(0, size.y - 34.0)
	take_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	take_label.modulate.a = 0.0
	add_child(take_label)
	if quick: skip()
	else:
		game.sound.play("ui_click", 0.4, 0.8)
		layout_card()

func home() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.08 + card.size.y * 0.5)

# the card on its way: it grows out of the wheel while it spins on its back and slows down to a stop
func layout_card() -> void:
	var s = 1.0
	var width = 1.0
	var center = home()
	if t < RISE:
		var p = clampf(t / RISE, 0.0, 1.0)
		var e = 1.0 - pow(1.0 - p, 3.0)
		center = origin.lerp(home(), e)
		s = lerpf(0.18, 1.0, e)
		width = maxf(0.04, absf(cos(3.0 * PI * (1.0 - e))))
	else:
		center.y += sin(t * 3.2) * 4.0 * clampf((FLIP_AT - t) / HOLD + 0.2, 0.0, 1.0)
		if t >= FLIP_AT and t < FLIP_AT + 0.7:
			s = 1.0 + 0.06 * sin(PI * clampf((t - FLIP_AT) / 0.7, 0.0, 1.0))
	card.scale = Vector2(s * width, s)
	card.position = center - card.size * 0.5

func skip() -> void:
	t = END
	card.show_back = false
	card.flip_p = -1.0
	burst_done = true
	flipped_started = true
	ring = -1.0
	sparks.clear()
	line_label.modulate.a = 1.0
	take_label.modulate.a = 1.0
	layout_card()
	queue_redraw()

func burst() -> void:
	burst_done = true
	ring = 0.0
	game.sound.play("coins", 0.7, 0.9)
	var c = home()
	for i in range(60):
		var a = rng.randf() * TAU
		var sp = rng.randf_range(160.0, 620.0)
		sparks.append({"pos": c + Vector2.from_angle(a) * rng.randf_range(0.0, card.size.x * 0.3), "vel": Vector2.from_angle(a) * sp, "life": rng.randf_range(0.6, 1.5), "max": 1.5, "size": rng.randf_range(2.5, 7.0)})

func _process(dt: float) -> void:
	if quick and t >= END:
		return
	t += dt
	if t >= FLIP_AT and not flipped_started:
		flipped_started = true
		card.flip()
	if t >= BURST_AT and not burst_done: burst()
	if ring >= 0.0:
		ring += dt
		if ring > 1.2: ring = -1.0
	# a little glitter rises from the card while it waits
	if t > RISE * 0.8 and t < FLIP_AT and rng.randf() < 0.55:
		var c = home() + Vector2(rng.randf_range(-0.5, 0.5) * card.size.x, rng.randf_range(-0.5, 0.5) * card.size.y)
		sparks.append({"pos": c, "vel": Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-90.0, -30.0)), "life": rng.randf_range(0.7, 1.3), "max": 1.3, "size": rng.randf_range(2.0, 4.5)})
	var alive: Array = []
	for sp in sparks:
		sp.life -= dt
		sp.pos += sp.vel * dt
		sp.vel.y += 90.0 * dt
		sp.vel *= 1.0 - 0.9 * dt
		if sp.life > 0.0: alive.append(sp)
	sparks = alive
	line_label.modulate.a = clampf((t - BURST_AT - 0.2) / 0.5, 0.0, 1.0)
	take_label.modulate.a = clampf((t - END + 0.4) / 0.4, 0.0, 1.0)
	layout_card()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if t < END: skip()
		else: closed.emit()
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE):
		if t < END: skip()
		else: closed.emit()

func _draw() -> void:
	var dim = clampf(t / 0.35, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.01, 0.9 * dim))
	var c = home()
	var glow_k = clampf((t - 0.2) / 0.8, 0.0, 1.0)
	if t >= FLIP_AT: glow_k = 1.0 + 0.6 * maxf(0.0, 1.0 - (t - FLIP_AT) / 1.2)
	elif t >= RISE: glow_k = 0.9 + 0.1 * sin(t * 6.0)
	# the rays turn slowly behind the card
	var spin = t * 0.5
	var reach = size.y * 0.95
	for i in range(18):
		var a = spin + TAU * float(i) / 18.0
		var half = 0.055 + 0.015 * sin(t * 2.0 + float(i))
		var pts = PackedVector2Array([c, c + Vector2.from_angle(a - half) * reach, c + Vector2.from_angle(a + half) * reach])
		draw_colored_polygon(pts, Color(1.0, 0.82, 0.40, 0.11 * glow_k))
	var g = card.size.y * (1.35 + 0.2 * glow_k)
	draw_texture_rect(glow, Rect2(c - Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(1, 0.9, 0.6, clampf(0.55 * glow_k, 0.0, 1.0)))
	# the shock wave and the flash of the turn
	if ring >= 0.0:
		var rr = card.size.y * (0.3 + 1.1 * ring / 1.2)
		draw_arc(c, rr, 0.0, TAU, 96, Color(1.0, 0.9, 0.55, clampf(1.0 - ring / 1.2, 0.0, 1.0)), 8.0, true)
		draw_arc(c, rr * 0.82, 0.0, TAU, 96, Color(1.0, 0.95, 0.8, clampf(0.7 - ring / 1.2, 0.0, 1.0)), 4.0, true)
	if burst_done and t < BURST_AT + 0.4 and t >= BURST_AT:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.96, 0.85, 0.42 * (1.0 - (t - BURST_AT) / 0.4)))
	for sp in sparks:
		var al = clampf(float(sp.life) / float(sp.max), 0.0, 1.0)
		var r = float(sp.size) * (0.5 + 0.5 * al)
		var p = sp.pos
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 1.6), p + Vector2(r, 0), p + Vector2(0, r * 1.6), p + Vector2(-r, 0)]), Color(1.0, 0.88, 0.45, al))
