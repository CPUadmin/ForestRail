extends RefCounted
# Пламя реактивного, нарисованное кодом (вместо четырёх готовых картинок): слои языков от красного к белому,
# рваный край, который дышит со временем, ядро с «алмазами» ударных волн и свечение у сопла.
# Длина и яркость плавно растут с тягой, форсаж длиннее и белее. Пламя летит влево от сопла (поезд идёт вправо).

const LAYERS = [
	{"width": 1.00, "length": 1.00, "color": Color(0.86, 0.20, 0.05, 0.78)},
	{"width": 0.74, "length": 0.84, "color": Color(1.00, 0.46, 0.08, 0.88)},
	{"width": 0.50, "length": 0.64, "color": Color(1.00, 0.76, 0.18, 0.92)},
	{"width": 0.27, "length": 0.42, "color": Color(1.00, 0.96, 0.66, 0.96)}]
const LAYERS_AFTER = [
	{"width": 1.00, "length": 1.00, "color": Color(0.80, 0.26, 0.10, 0.70)},
	{"width": 0.74, "length": 0.86, "color": Color(1.00, 0.55, 0.20, 0.86)},
	{"width": 0.50, "length": 0.68, "color": Color(1.00, 0.88, 0.62, 0.92)},
	{"width": 0.27, "length": 0.48, "color": Color(0.78, 0.90, 1.00, 0.97)}]
const SAMPLES = 18
# length of the flame in metres of the picture (1774 px wide body) by the thrust share: idle, middle, full
const LENGTH_BY_THRUST = [[0.0, 220.0], [0.2, 420.0], [0.55, 780.0], [1.0, 920.0]]
const AFTERBURNER_LENGTH = 1500.0

static func length_for(frac: float, afterburner: bool) -> float:
	if afterburner: return AFTERBURNER_LENGTH
	var points = LENGTH_BY_THRUST
	for i in range(points.size() - 1):
		var a = points[i]
		var b = points[i + 1]
		if frac <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (frac - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
	return float(points[points.size() - 1][1])

static func wobble(u: float, side: float, layer: int, t: float, seed: float) -> float:
	var open = smoothstep(0.0, 0.3, u)   # the root of the flame is calm, the tail is ragged
	return 1.0 + open * (0.20 * sin(u * 23.0 - t * 31.0 + float(layer) * 1.7 + side * 2.1 + seed) + 0.11 * sin(u * 41.0 - t * 47.0 + float(layer) * 0.9 - side * 1.3 + seed * 2.0))

# One tongue of the flame as a polygon: the upper edge from the nozzle to the tip, the lower edge back.
static func tongue(mouth: Vector2, length: float, radius: float, layer: int, t: float, seed: float) -> PackedVector2Array:
	var spec = LAYERS[layer]
	var span = length * float(spec.length)
	var half = radius * float(spec.width)
	var top = PackedVector2Array()
	var bottom = PackedVector2Array()
	for j in range(SAMPLES + 1):
		var u = float(j) / float(SAMPLES)
		var taper = pow(maxf(1.0 - u, 0.0), 0.9) * (0.78 + 0.22 * smoothstep(0.0, 0.18, u))
		var centre = Vector2(-span * u, sin(t * 13.0 + u * 6.0 + seed + float(layer)) * radius * 0.10 * u)
		var up = half * taper * wobble(u, 1.0, layer, t, seed)
		var down = half * taper * wobble(u, -1.0, layer, t, seed)
		top.append(mouth + centre + Vector2(0, -up))
		bottom.append(mouth + centre + Vector2(0, down))
	bottom.reverse()
	top.append_array(bottom)
	return top

# canvas: the node that draws; mouth: the middle of the nozzle opening; length and radius in screen units.
# frac: thrust share 0..1 (brightness of the core), afterburner: the long white-blue flame.
static func draw(canvas: Node2D, mouth: Vector2, length: float, radius: float, frac: float, afterburner: bool, t: float, seed: float = 0.0) -> void:
	var flicker = 1.0 + 0.06 * sin(t * 9.0 + seed) + 0.03 * sin(t * 23.0 + seed * 1.7)
	length *= flicker
	var strength = clampf(0.55 + frac * 0.45, 0.0, 1.0)
	var layers = LAYERS_AFTER if afterburner else LAYERS
	# the glow around the nozzle
	for k in range(3):
		var r = radius * (1.9 - 0.45 * float(k))
		canvas.draw_circle(mouth + Vector2(-radius * 0.35, 0), r, Color(1.0, 0.62 if not afterburner else 0.74, 0.22, 0.07 * strength))
	for i in range(layers.size()):
		var tone: Color = layers[i].color
		tone.a *= strength if i < 3 else 1.0
		var shape = tongue(mouth, length, radius, i, t, seed)
		# the root fades in: the flame grows out of the dark of the nozzle instead of starting with a hard edge
		var colors = PackedColorArray()
		for k in range(shape.size()):
			var j = k if k <= SAMPLES else 2 * SAMPLES + 1 - k
			var fade = smoothstep(0.0, 0.14, float(j) / float(SAMPLES))
			colors.append(Color(tone, tone.a * fade))
		canvas.draw_polygon(shape, colors)
	# the shock diamonds of the hot core
	if frac > 0.45 or afterburner:
		var diamonds = 5 if afterburner else 3
		for m in range(diamonds):
			var u = 0.16 + 0.15 * float(m)
			var span = length * 0.55 * (1.0 if not afterburner else 1.2)
			var at = mouth + Vector2(-span * u, sin(t * 13.0 + u * 6.0 + seed + 3.0) * radius * 0.10 * u)
			var hl = length * 0.05 * (1.0 - u)
			var hw = radius * 0.30 * (1.0 - u * 0.8)
			var pale = Color(0.86, 0.94, 1.0, 0.62) if afterburner else Color(1.0, 0.98, 0.84, 0.55)
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(hl, 0), at + Vector2(0, -hw), at + Vector2(-hl, 0), at + Vector2(0, hw)]), pale)
