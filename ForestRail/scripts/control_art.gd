extends RefCounted
# Т7 (разбивка main.gd), шаг 1: кисть ручных органов пульта: кулиса передач, селектор автоматической КПП, штурвал, ползунок, рычаг.
# Рисует на холсте canvas (main.gd) его же методами; логика органов (положения, перетаскивание) осталась в main.gd.

const PAPER = Color("f5ecd6")
const GREEN = Color("466c51")
const GOLD = Color("bb964f")
const RED = Color("a64d3b")
const WHEEL_SWEEP = PI * 1.5

var canvas = null   # the node that draws (main.gd): it holds the font and the style cache

func _init(owner_canvas) -> void:
	canvas = owner_canvas

# where the grid position g of a gate (columns 0..2, rows -1..1) falls inside the gate rectangle
static func gate_local(rect: Rect2, g: Vector2) -> Vector2:
	return rect.position + Vector2(rect.size.x * (0.15 + 0.35 * g.x), rect.size.y * (0.5 + 0.38 * g.y))

func draw_selector(rect: Rect2, knob: Vector2, active: bool) -> void:
	canvas.draw_style_box(canvas.style(Color("1d2420"), Color("918363") if not active else PAPER, 4), rect.grow(4))
	var width = maxf(3.0, rect.size.x * 0.07)
	var top = gate_local(rect, Vector2(1, -1))
	var bottom = gate_local(rect, Vector2(1, 1))
	canvas.draw_line(top, bottom, Color("5e6b62"), width + 2, true)
	canvas.draw_line(top, bottom, Color("070a09"), width, true)
	var small = clampi(int(rect.size.x * 0.2), 12, 18)
	for item in [[-1.0, "Д", GREEN], [0.0, "Н", GOLD], [1.0, "З", RED]]:
		var at = gate_local(rect, Vector2(1, item[0]))
		canvas.draw_string(canvas.font, at + Vector2(width * 1.6, small * 0.35), item[1], HORIZONTAL_ALIGNMENT_LEFT, 20, small, item[2])
	var ball = gate_local(rect, Vector2(1, knob.y))
	var radius = maxf(4.5, rect.size.x * 0.10)
	canvas.draw_circle(ball + Vector2(1.5, 2.0), radius, Color(0, 0, 0, 0.45))
	canvas.draw_circle(ball, radius, Color("17120f"))
	canvas.draw_circle(ball + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.3, Color(1, 1, 1, 0.35))
	canvas.draw_arc(ball, radius, 0, TAU, 20, GOLD, 1.2, true)

func draw_gate(rect: Rect2, knob: Vector2, active: bool) -> void:
	canvas.draw_style_box(canvas.style(Color("1d2420"), Color("918363") if not active else PAPER, 4), rect.grow(4))
	var width = maxf(3.0, rect.size.x * 0.07)
	var channel = Color("070a09")
	var left = gate_local(rect, Vector2(0, 0))
	var right = gate_local(rect, Vector2(2, 0))
	canvas.draw_line(left, right, Color("5e6b62"), width + 2, true)
	for column in range(3):
		var top = gate_local(rect, Vector2(column, -1))
		canvas.draw_line(top, gate_local(rect, Vector2(column, 1)), Color("5e6b62"), width + 2, true)
	canvas.draw_line(left, right, channel, width, true)
	for column in range(3):
		var top = gate_local(rect, Vector2(column, -1))
		canvas.draw_line(top, gate_local(rect, Vector2(column, 1)), channel, width, true)
	var small = clampi(int(rect.size.x * 0.17), 11, 16)
	var labels = [[Vector2(0, -1), "1", PAPER], [Vector2(0, 1), "2", PAPER], [Vector2(1, -1), "3", PAPER], [Vector2(1, 1), "4", PAPER], [Vector2(2, -1), "5", PAPER], [Vector2(2, 1), "R", RED], [Vector2(1.52, 0), "N", GOLD]]
	for item in labels:
		var at = gate_local(rect, item[0])
		var offset = Vector2(-small * 0.4, -small * 0.9) if item[0].y < 0 else (Vector2(-small * 0.4, small * 1.35) if item[0].y > 0 else Vector2(-small * 0.3, -small * 0.55))
		canvas.draw_string(canvas.font, at + offset, item[1], HORIZONTAL_ALIGNMENT_LEFT, 20, small, item[2])
	var ball = gate_local(rect, knob)
	var radius = maxf(4.5, rect.size.x * 0.10)
	canvas.draw_circle(ball + Vector2(1.5, 2.0), radius, Color(0, 0, 0, 0.45))
	canvas.draw_circle(ball, radius, Color("17120f"))
	canvas.draw_circle(ball + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.3, Color(1, 1, 1, 0.35))
	canvas.draw_arc(ball, radius, 0, TAU, 20, GOLD, 1.2, true)

# A brass hand wheel; angle is the clockwise turn from the top.
func draw_handwheel(center: Vector2, radius: float, angle: float, color: Color, active: bool) -> void:
	canvas.draw_arc(center, radius + 5, -PI / 2, -PI / 2 + WHEEL_SWEEP, 28, Color("66796b"), 2, true)
	canvas.draw_circle(center + Vector2(1.5, 2.0), radius, Color(0, 0, 0, 0.35))
	canvas.draw_circle(center, radius, Color("2a2f2c"))
	canvas.draw_arc(center, radius - 1.5, 0, TAU, 36, color, maxf(2.0, radius * 0.16), true)
	for i in range(6):
		var spoke = Vector2(0, -1).rotated(angle + TAU * i / 6.0)
		canvas.draw_line(center + spoke * radius * 0.18, center + spoke * (radius - 2), Color("a8a38a"), maxf(1.5, radius * 0.1), true)
		canvas.draw_circle(center + spoke * (radius - 1), maxf(2.0, radius * 0.11), color)
	canvas.draw_circle(center, radius * 0.22, color)
	canvas.draw_circle(center, radius * 0.09, Color("2a2f2c"))
	var mark = center + Vector2(0, -1).rotated(angle) * (radius + 9)
	canvas.draw_circle(mark, 3.0, PAPER if active else GOLD)

# An aircraft-style handle: a slot with a scale, a coloured track up to a knurled knob.
# pivot is the bottom end of the slot, value 0..1 runs upward.
func draw_slider(base: Transform2D, pivot: Vector2, length: float, value: float, color: Color, active: bool) -> void:
	canvas.draw_set_transform_matrix(base)
	var w = clampf(length * 0.075, 4.0, 9.0)
	var plate = Rect2(pivot + Vector2(-w * 3.4, -length - w * 2.6), Vector2(w * 6.8, length + w * 5.2))
	canvas.draw_rect(plate, Color("1c2421"))
	canvas.draw_rect(plate, Color("918363"), false, 1.5)
	for corner in [plate.position + Vector2(4, 4), Vector2(plate.end.x - 4, plate.position.y + 4), Vector2(plate.position.x + 4, plate.end.y - 4), plate.end - Vector2(4, 4)]:
		canvas.draw_circle(corner, 1.8, Color("a98a4a"))
	var slot = Rect2(pivot + Vector2(-w * 0.55, -length), Vector2(w * 1.1, length))
	canvas.draw_rect(slot, Color("030504"))
	canvas.draw_rect(Rect2(slot.position + Vector2(w * 0.15, length * (1.0 - value)), Vector2(w * 0.8, length * value)), Color(color, 0.75))
	var small = clampi(roundi(length * 0.075), 7, 12)
	for i in range(11):
		var y = pivot.y - length * i / 10.0
		var major = i % 5 == 0
		canvas.draw_line(Vector2(pivot.x - w * 2.9, y), Vector2(pivot.x - w * (1.2 if major else 1.7), y), PAPER if major else Color(PAPER, 0.5), 1.6 if major else 1.0)
		canvas.draw_line(Vector2(pivot.x + w * (1.2 if major else 1.7), y), Vector2(pivot.x + w * 2.9, y), PAPER if major else Color(PAPER, 0.5), 1.6 if major else 1.0)
	canvas.draw_string(canvas.font, Vector2(pivot.x - w * 3.2, pivot.y + small + 3), "0", HORIZONTAL_ALIGNMENT_CENTER, w * 6.4, small, Color("c7c3a0"))
	canvas.draw_string(canvas.font, Vector2(pivot.x - w * 3.2, pivot.y - length - 5), "100", HORIZONTAL_ALIGNMENT_CENTER, w * 6.4, small, Color("c7c3a0"))
	var knob_y = pivot.y - length * value
	var kw = w * 2.4
	var kh = clampf(length * 0.28, 16.0, 36.0)
	var knob = Rect2(Vector2(pivot.x - kw * 0.5, knob_y - kh * 0.5), Vector2(kw, kh))
	canvas.draw_rect(Rect2(knob.position + Vector2(1.5, 2.0), knob.size), Color(0, 0, 0, 0.4))
	canvas.draw_rect(knob, Color("141917"))
	for groove in range(5):
		var gy = knob.position.y + kh * (groove + 1.0) / 6.0
		canvas.draw_line(Vector2(knob.position.x + 2, gy), Vector2(knob.end.x - 2, gy), Color(1, 1, 1, 0.16), 1.2)
	canvas.draw_rect(Rect2(knob.position, Vector2(kw, kh * 0.22)), color)
	canvas.draw_line(knob.position + Vector2(1.5, 1), Vector2(knob.position.x + 1.5, knob.end.y - 1), Color(1, 1, 1, 0.28), 1.5)
	canvas.draw_rect(knob, PAPER if active else Color("5c6660"), false, 1.5)
	canvas.draw_set_transform_matrix(base)

# A forged lever: mounting plate, brass pivot, tapered steel arm with a collar and
# an enamel ball grip. Drawn in the local frame of `base`, hinged at `pivot`.
func draw_lever(base: Transform2D, pivot: Vector2, length: float, angle: float, knob: Color, active: bool) -> void:
	var w = clampf(length * 0.06, 2.0, 5.0)
	canvas.draw_set_transform_matrix(base * Transform2D(0.0, pivot))
	var plate = Rect2(Vector2(-w * 2.6, -w * 0.6), Vector2(w * 5.2, w * 2.6))
	canvas.draw_rect(plate, Color("2b3430"))
	canvas.draw_rect(plate, Color("918363"), false, 1.0)
	canvas.draw_set_transform_matrix(base * Transform2D(angle, pivot))
	var arm = PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.55, -length), Vector2(-w * 0.55, -length)])
	canvas.draw_colored_polygon(arm, Color("8d9a98"))
	canvas.draw_line(Vector2(-w * 0.45, -2), Vector2(-w * 0.3, -length + 2), Color("d6dedb"), 1.2, true)
	canvas.draw_line(Vector2(w * 0.5, -2), Vector2(w * 0.3, -length + 2), Color("56635f"), 1.2, true)
	canvas.draw_rect(Rect2(Vector2(-w * 1.15, -length * 0.62), Vector2(w * 2.3, w * 0.9)), Color("c9af73"))
	var radius = clampf(length * 0.11, 4.0, 9.0)
	var ball = Vector2(0, -length - radius * 0.4)
	canvas.draw_circle(ball + Vector2(1.5, 1.5), radius, Color(0, 0, 0, 0.35))
	canvas.draw_circle(ball, radius, knob)
	canvas.draw_circle(ball + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.32, Color(1, 1, 1, 0.45))
	if active: canvas.draw_arc(ball, radius + 2, 0, TAU, 20, PAPER, 1.2, true)
	canvas.draw_circle(Vector2.ZERO, w * 1.1, Color("c9af73"))
	canvas.draw_circle(Vector2.ZERO, w * 0.45, Color("2a2f2c"))
	canvas.draw_set_transform_matrix(base)
