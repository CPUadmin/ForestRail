extends RefCounted
# Гаджет «Кошка с лебёдкой» шестовой (В6.8, требование владельца 05.11.2026: физический объект, не кнопка).
# Крюк на тросе настоящий: бросок идёт по дуге с тяжестью, цепляется за опору только если пролетает у её верха (иначе падает на землю и возвращается),
# трос натягивается, лебёдка мотает его и тянет дрезину вверх по линии с силой ≈ четверти веса дрезины, но лебёдка рвёт слабую опору:
# куст и пень не держат полный вес состава, столб, дерево и скала держат. Всё в метрах и секундах, в системе линии (s вперёд по пути).
#
# Опоры стоят вдоль линии на своих местах для одного зерна маршрута (как грунт у шеста). Игрок видит их тип: толщину и цвет подсказывают, какая крепче.

const G = 9.81
const HAND_H = 1.2          # откуда летит крюк: высота лебёдки над землёй у дрезины
const RANGE = 22.0          # дальше не добросить
const MIN_RANGE = 3.0       # ближе этого разброс нулевой, и опору рядом автоприцел не берёт
const MIN_THROW = 1.5       # мышью можно бросить и почти под ноги
const SPREAD = 0.04         # разброс скорости броска на предельной дальности (±4%)
const ANGLE = 0.8           # рад, угол броска (≈ 46°)
const WINCH_SHARE = 0.9      # тяга лебёдки как доля веса дрезины (очень сильная лебёдка)
const WINCH_SPEED = 2.0     # м/с: так быстро барабан выбирает трос
const ROPE_K = 12000.0      # Н/м: жёсткость натянутого троса
const HOLD_N = 30000.0      # Н: держит эталонная опора (столб): столб, дерево и скала держат любой состав, пень средний, куст рвётся
const REACHED_M = 1.2       # подъехали под опору ближе этого: крюк снимается сам
const LAND_RETURN_S = 1.2   # сколько лежит промахнувшийся крюк, пока его не смотали
const ANCHORS = {
	"post": {"hold": 1.0, "h": 2.6, "name": "столб", "weight": 4},
	"tree": {"hold": 0.85, "h": 6.0, "name": "дерево", "weight": 4},
	"rock": {"hold": 1.3, "h": 1.1, "name": "скала", "weight": 2},
	"stump": {"hold": 0.15, "h": 0.6, "name": "пень", "weight": 3},
	"bush": {"hold": 0.02, "h": 1.3, "name": "куст", "weight": 3}}

var anchors: Array = []      # [{s, type}] по возрастанию s
var built_for = ""
var mode = "stowed"          # stowed (в скобе) / flying / hooked / dropped (упал и лежит) / torn (сорвался: лежит ненадолго)
var target = -1              # номер опоры, к которой летит или на которой висит крюк
var throws = 0               # счётчик бросков: разные броски дают разный разброс
var clock = 0.0              # время в полёте или лежания
var throw_dir = 1
var origin_s = 0.0           # откуда брошено (s дрезины в момент броска)
var origin_h = 0.0           # высота руки над уровнем моря линии
var v0 = 0.0                 # начальная скорость броска
var catch_t = -1.0           # когда крюк долетит до опоры (если зацепится), иначе -1
var land_t = 0.0             # когда упадёт
var land_x = 0.0             # где упадёт (м впереди точки броска)
var rope = 0.0               # длина троса от лебёдки до крюка
var tension = 0.0            # Н
var prev_dist = -1.0          # расстояние до опоры на прошлом шаге (для демпфера троса)
var reeling = false
var force = 0.0              # последняя сила на дрезину вдоль пути (знак s)
var events: Array = []       # "throw", "hook", "miss", "tear", "reached", "release"

func hash01(x: float) -> float:
	return fposmod(sin(x * 12.9898 + 78.233) * 43758.5453, 1.0)

# Опоры вдоль линии: одни и те же для одного зерна. У станций опор нет (там платформа).
func build(seed_value: int, length_m: float, station_s: Array) -> void:
	var key = "%d:%d:%d" % [seed_value, int(length_m), station_s.size()]
	if key == built_for: return
	built_for = key
	anchors.clear()
	var total_weight = 0
	for type in ANCHORS: total_weight += int(ANCHORS[type].weight)
	var s = 30.0
	var i = 0
	while s < length_m - 30.0:
		s += 12.0 + hash01(float(seed_value) * 0.37 + float(i) * 3.1) * 30.0
		i += 1
		var near_station = false
		for st in station_s:
			if absf(s - float(st)) < 30.0: near_station = true
		if near_station: continue
		var pick = int(hash01(float(seed_value) * 0.11 + float(i) * 7.7) * float(total_weight))
		var chosen = "post"
		for type in ANCHORS:
			pick -= int(ANCHORS[type].weight)
			if pick < 0:
				chosen = str(type)
				break
		anchors.append({"s": s, "type": chosen})

func reset() -> void:
	mode = "stowed"
	target = -1
	clock = 0.0
	rope = 0.0
	tension = 0.0
	reeling = false
	force = 0.0
	events.clear()

# номер ближайшей опоры впереди в пределах броска, -1 если нет
func anchor_ahead(s: float, direction: int) -> int:
	var best = -1
	var best_d = INF
	for i in range(anchors.size()):
		var d = (float(anchors[i].s) - s) * float(direction)
		if d >= MIN_RANGE and d <= RANGE and d < best_d:
			best_d = d
			best = i
	return best

func anchor_top(i: int, ground_y: Callable) -> float:
	return float(ground_y.call(float(anchors[i].s))) + float(ANCHORS[anchors[i].type].h)

func hold_n(i: int) -> float:
	return HOLD_N * float(ANCHORS[anchors[i].type].hold)

func busy() -> bool:
	return mode != "stowed"

# Скорость броска под углом ANGLE так, чтобы дуга прошла через точку на d метров вперёд и dy метров выше руки.
func speed_for(d: float, dy: float) -> float:
	var c = cos(ANGLE)
	var denominator = 2.0 * c * c * (d * tan(ANGLE) - dy)
	return sqrt(G * d * d / maxf(denominator, 0.5))

# Высота дуги над рукой на расстоянии x вперёд при скорости v.
func arc_y(v: float, x: float) -> float:
	var c = cos(ANGLE)
	return x * tan(ANGLE) - G * x * x / (2.0 * v * v * c * c)

# Куда упадёт крюк (метров вперёд) при скорости v: дуга возвращается на землю у лебёдки (плоско): y(x) = -HAND_H
func landing_x(v: float) -> float:
	var c = cos(ANGLE)
	var a = G / (2.0 * v * v * c * c)
	var disc = sqrt(tan(ANGLE) * tan(ANGLE) + 4.0 * a * HAND_H)
	return (tan(ANGLE) + disc) / (2.0 * a)

# Какую опору зацепит дуга со скоростью v (первую по ходу, у которой она проходит между серединой ствола и ладонью над верхом): [номер, расстояние] или [-1, 0].
func catch_on_arc(s: float, direction: int, hand_world_y: float, ground_y: Callable, v: float) -> Array:
	var reach = landing_x(v)
	var best = -1
	var best_d = INF
	for i in range(anchors.size()):
		var da = (float(anchors[i].s) - s) * float(direction)
		if da < 0.5 or da > reach or da >= best_d: continue
		var top_rel = anchor_top(i, ground_y) - hand_world_y
		var h = float(ANCHORS[anchors[i].type].h)
		var y_at = arc_y(v, da)
		if y_at >= top_rel - h * 0.8 - 0.1 and y_at <= top_rel + 0.5:
			best = i
			best_d = da
	return [best, best_d if best >= 0 else 0.0]

# Бросок по точке: d метров вперёд, dy метров выше руки (мышью целятся прямо в опору). Скорость подбирается так, чтобы дуга прошла через точку, потом небольшой разброс от дальности и номера броска.
# Зацепится первая опора, у верха которой пролетит дуга, хоть бы это была не та, в которую целились; иначе крюк упадёт на землю.
func throw_at(s: float, direction: int, hand_world_y: float, ground_y: Callable, d: float, dy: float) -> bool:
	if mode != "stowed": return false
	throws += 1
	throw_dir = direction
	origin_s = s
	origin_h = hand_world_y
	clock = 0.0
	d = clampf(d, MIN_THROW, RANGE)
	v0 = speed_for(d, dy)
	var spread = (hash01(float(throws) * 1.7 + s * 0.013) * 2.0 - 1.0) * SPREAD * clampf((d - MIN_RANGE) / (RANGE - MIN_RANGE), 0.0, 1.0)
	v0 *= 1.0 + spread
	land_x = landing_x(v0)
	land_t = land_x / (v0 * cos(ANGLE))
	var hit = catch_on_arc(s, direction, hand_world_y, ground_y, v0)
	target = int(hit[0])
	catch_t = float(hit[1]) / (v0 * cos(ANGLE)) if target >= 0 else -1.0
	mode = "flying"
	events.append("throw")
	return true

# Бросок на ближайшую опору впереди (кнопка и клавиша без мыши): метим чуть ниже верха, крюк цепляется за ствол.
# Если опоры в пределах броска нет, крюк летит на 10 м и падает.
func throw(s: float, direction: int, hand_world_y: float, ground_y: Callable) -> bool:
	if mode != "stowed": return false
	var i = anchor_ahead(s, direction)
	var d = 10.0
	var dy = -HAND_H   # куда метим по высоте относительно руки (в землю)
	if i >= 0:
		d = (float(anchors[i].s) - s) * float(direction)
		dy = anchor_top(i, ground_y) - hand_world_y - 0.15 * float(ANCHORS[anchors[i].type].h)
	return throw_at(s, direction, hand_world_y, ground_y, d, dy)

# Дуга для прицела: точки (x вперёд, y над рельсом у дрезины) от руки до точки прицела и опора, которую она зацепит (-1: ни одной). Без разброса.
func aim_preview(s: float, direction: int, hand_world_y: float, ground_y: Callable, d: float, dy: float) -> Dictionary:
	d = clampf(d, MIN_THROW, RANGE)
	var v = speed_for(d, dy)
	var points: Array = []
	var steps = 16
	var end_x = minf(landing_x(v), d * 1.25 + 1.0)
	for k in range(steps + 1):
		var x = end_x * float(k) / float(steps)
		points.append(Vector2(x, HAND_H + arc_y(v, x)))
	var hit = catch_on_arc(s, direction, hand_world_y, ground_y, v)
	return {"points": points, "catch": int(hit[0])}

func release() -> void:
	if mode == "hooked":
		mode = "dropped"
		clock = 0.0
		reeling = false
		tension = 0.0
		events.append("release")

# положение крюка относительно дрезины: x вперёд по ходу (м), y над землёй у дрезины (0 = рельс) для рисования; null-подобный Vector2.ZERO в скобе
func hook_offset(s: float, direction: int, hand_world_y: float, ground_y: Callable) -> Vector2:
	if mode == "stowed": return Vector2(0.9, HAND_H - 0.3)
	if mode == "flying":
		var c = cos(ANGLE)
		var x = v0 * c * clock
		var y = v0 * sin(ANGLE) * clock - 0.5 * G * clock * clock
		return Vector2(((origin_s + x * float(throw_dir)) - s) * float(direction), HAND_H + y)   # x как на экране: вперёд по ходу положительно
	if mode == "hooked":
		var i = target
		return Vector2((float(anchors[i].s) - s) * float(direction), anchor_top(i, ground_y) - 0.15 * float(ANCHORS[anchors[i].type].h) - (hand_world_y - HAND_H))   # высота над землёй у дрезины
	# лежит там, где упал
	var landing_s = origin_s + land_x * float(throw_dir)
	if target >= 0 and mode == "torn": landing_s = float(anchors[target].s)
	return Vector2((landing_s - s) * float(direction), 0.0)

# Один шаг. Возвращает силу на дрезину вдоль пути (знак s). mass_kg: масса всего состава.
func step(dt: float, s: float, direction: int, hand_world_y: float, mass_kg: float, ground_y: Callable) -> float:
	force = 0.0
	if mode == "stowed": return 0.0
	clock += dt
	if mode == "flying":
		if catch_t >= 0.0 and clock >= catch_t:
			mode = "hooked"
			clock = 0.0
			reeling = true
			var i = target
			var dx = (float(anchors[i].s) - s) * float(direction)
			var dy = anchor_top(i, ground_y) - 0.15 * float(ANCHORS[anchors[i].type].h) - hand_world_y
			rope = sqrt(dx * dx + dy * dy)
			prev_dist = -1.0
			events.append("hook")
		elif clock >= land_t:
			mode = "dropped"
			clock = 0.0
			events.append("miss")
		return 0.0
	if mode == "dropped" or mode == "torn":
		tension = 0.0
		if clock >= LAND_RETURN_S: mode = "stowed"
		return 0.0
	# hooked
	var i2 = target
	var ax = (float(anchors[i2].s) - s) * float(direction)
	var ay = anchor_top(i2, ground_y) - 0.15 * float(ANCHORS[anchors[i2].type].h) - hand_world_y
	var dist = sqrt(ax * ax + ay * ay)
	if ax <= REACHED_M:
		mode = "dropped"
		clock = 0.0
		reeling = false
		tension = 0.0
		events.append("reached")
		return 0.0
	var reel = WINCH_SPEED * clampf((ax - REACHED_M) / 8.0, 0.2, 1.0) if reeling else 0.0   # near the support the drum slows down: the truck comes up gently
	if reeling: rope = maxf(0.5, rope - reel * dt)
	var winch_max = WINCH_SHARE * mass_kg * G
	# the rope is a spring with a damper: the truck follows the drum without swinging past it
	var stretch_rate = ((dist - prev_dist) / dt + reel) if prev_dist >= 0.0 else 0.0
	prev_dist = dist
	tension = clampf(ROPE_K * (dist - rope) + 1.2 * sqrt(ROPE_K * maxf(mass_kg, 1.0)) * stretch_rate, 0.0, winch_max)
	if tension > hold_n(i2):
		# лебёдка вырвала слабую опору: крюк срывается и падает под опору
		mode = "torn"
		clock = 0.0
		reeling = false
		tension = 0.0
		events.append("tear")
		return 0.0
	force = tension * (ax / dist) * float(direction)
	return force

func status_text() -> String:
	match mode:
		"flying": return "Кошка летит"
		"hooked": return "Трос на опоре: %s" % str(ANCHORS[anchors[target].type].name)
		"dropped": return "Кошка на земле"
		"torn": return "Опора не удержала"
	return "Кошка в скобе"
