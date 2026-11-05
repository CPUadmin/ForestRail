extends RefCounted
# «Живой» состав (Веха 5): упругие сцепки (В5.2), подвеска и качание кузовов (В5.1), сдвиг груза (В5.3).
#
# Главная физика состава остаётся жёсткой (так считаются тяга, запас хода и все калибровки). Здесь поверх неё
# считается второй слой: каждый хвостовой кузов — масса на цепочке сцепок с люфтом и пружиной. Голова задана
# основной моделью, вагоны отстают и догоняют, сцепки бьют. Слой нужен для картинки, звука, сдвига груза
# и (потом, В5.6) для износа сцепки; на ход и расход он не влияет.
#
# Все величины в метрах, секундах и радианах. Сдвиги q положительны вперёд по ходу головы.

const G = 9.81
const PLAY = 0.06          # свободный ход сцепки в каждую сторону, м
const K_COUPLER = 60000.0  # жёсткость сцепки за люфтом, Н/м
const C_COUPLER = 1300.0   # демпфирование, Н·с/м
const LIMIT = 0.22         # дальше сцепка не растягивается и не сжимается (буфера), м
const SUBSTEPS = 4
const JOINT_SPACING = 12.0  # стыки рельсов, как в звуке
# Подвеска (переработана 05.11.2026, «выглядело грубо и криво»): колёса всегда стоят на рельсе, а кузов качается
# на пружинах НАД ними (колёсные пары и сам кузов рисуются отдельными преобразованиями). Ход небольшой, зато живой:
# колебания затухают быстро (нет резонанса, при котором вагон подпрыгивал на 6 см вместе с колёсами), у каждого
# стыка своя сила удара, у каждого кузова своя жёсткость, пределы мягкие (без «полок»), а на рельсе всегда есть
# мелкая неровность, поэтому кузов не стоит мёртво.
const BODY_OMEGA = 11.5     # подвеска: ~1,8 Гц
const BODY_ZETA = 0.5       # хорошо задемпфирована: стык даёт один-два качка, а не звон
const ROCK_OMEGA = 8.0
const ROCK_ZETA = 0.7
const ROCK_GAIN = 0.0028    # наклон кузова от ускорения, рад на м/с²: на разгоне нос поднимается, на торможении клюёт
const LIFT_LIMIT = 0.013    # мягкий предел хода кузова над колёсами, м (≈ 3 пикселя картинки)
const ROCK_LIMIT = 0.007    # мягкий предел наклона, рад (≈ 0,7 градуса)
const JOINT_KICK = 0.002   # удар стыка по подвеске, м/с на м/с скорости
const JOINT_ROCK_KICK = 0.0006
const RAIL_ROUGH = 0.10     # мелкая неровность пути, м/с² (тихое живое покачивание на ходу)
const LASH_OMEGA = 6.0      # крепление груза упругое: ремни
const LASH_ZETA = 0.4
const CARGO_PLAY = 0.2      # груз упирается в борт или соседа, м
const CARGO_BOUNCE = 0.35

var n = 0
var q: Array = []        # смещение кузова от жёсткого положения
var qd: Array = []
var ext: Array = []      # растяжение сцепки i (между i-1 и i); 0 неиспользуется
var tension: Array = []  # сила в сцепке, Н (+ тянет, − толкает)
var lift: Array = []     # вертикальный ход кузова на подвеске, м (+ вверх)
var lift_v: Array = []
var rock: Array = []     # наклон кузова, рад (+ нос вверх)
var rock_v: Array = []
var joint_at: Array = []
var body_k: Array = []     # у каждого кузова своя жёсткость подвески (0,88..1,14), чтобы вагоны не качались в унисон
var load_shift: Dictionary = {}   # id груза -> {p, v} положение вдоль кузова, м (+ вперёд по ходу)
var clank = 0.0          # самый сильный удар сцепки за последний шаг (скорость удара, м/с)
var peak_tension = 0.0   # самая большая сила в сцепках за последний шаг
var hit_speed = 0.0      # самый сильный удар груза о борт за последний шаг
var hits: Array = []     # события этого шага: {"body", "speed", "id"}

func reset(count: int = 0) -> void:
	n = count
	q.clear(); qd.clear(); ext.clear(); tension.clear(); lift.clear(); lift_v.clear(); rock.clear(); rock_v.clear(); joint_at.clear(); body_k.clear()
	for i in range(n):
		q.append(0.0); qd.append(0.0); ext.append(0.0); tension.append(0.0)
		lift.append(0.0); lift_v.append(0.0); rock.append(0.0); rock_v.append(0.0); joint_at.append([-99999, -99999])
		body_k.append(0.88 + 0.26 * hash01(float(i), 3.7))
	load_shift.clear()
	clank = 0.0
	peak_tension = 0.0
	hit_speed = 0.0
	hits.clear()

# --- reading (safe for any index: before the first step everything is zero)
func slack_m(i: int) -> float:
	return float(q[i]) if i >= 0 and i < q.size() else 0.0

# a smooth limit instead of a flat clamp: the body slows down near the stop and does not hit a "shelf"
static func soft(x: float, limit: float) -> float:
	return limit * tanh(x / limit)

static func hash01(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

func lift_m(i: int) -> float:
	return soft(float(lift[i]), LIFT_LIMIT) if i >= 0 and i < lift.size() else 0.0

func rock_rad(i: int) -> float:
	return soft(float(rock[i]), ROCK_LIMIT) if i >= 0 and i < rock.size() else 0.0

func extension(i: int) -> float:
	return float(ext[i]) if i >= 0 and i < ext.size() else 0.0

func cargo_p(item_id) -> float:
	return float(load_shift.get(str(item_id), {}).get("p", 0.0))

# --- a hard landing shakes every body, the nearer to the head the harder
func landed(impact: float) -> void:
	for i in range(n):
		lift_v[i] = float(lift_v[i]) - impact * 0.06 * pow(0.85, float(i))
		rock_v[i] = float(rock_v[i]) + impact * 0.02 * (1.0 if i % 2 == 0 else -1.0)

func step(m, dt: float) -> void:
	var ids: Array = m.body_ids()
	if ids.size() != n: reset(ids.size())
	clank = 0.0
	peak_tension = 0.0
	hit_speed = 0.0
	hits.clear()
	if n == 0 or dt <= 0.0: return
	var dirn = float(m.state.direction)
	var v = float(m.state.v)
	var speed = absf(v)
	var heading_v = v * dirn
	var a_head = float(m.acceleration) * dirn
	# The masses and the own accelerations of the bodies (gravity along the rail, rolling)
	var mass: Array = []
	var a_free: Array = []
	for i in range(n):
		mass.append(m.body_mass(ids[i]))
		var slope = m.route.slope(m.body_s(i))
		var roll = 0.004 * G * signf(heading_v) if absf(heading_v) > 0.03 else 0.0
		a_free.append(-G * sin(slope) * dirn - roll)
	# --- couplers: bodies on springs with free play, the head fixed by the main model
	var h = dt / float(SUBSTEPS)
	var a_abs: Array = []
	a_abs.resize(n)
	for step_index in range(SUBSTEPS):
		var forces: Array = []
		forces.resize(n)
		forces[0] = 0.0
		for i in range(1, n):
			var x = float(q[i - 1]) - float(q[i])
			var vx = float(qd[i - 1]) - float(qd[i])
			var t = 0.0
			if x > PLAY:
				t = maxf(0.0, K_COUPLER * (x - PLAY) + C_COUPLER * vx)
			elif x < -PLAY:
				t = minf(0.0, K_COUPLER * (x + PLAY) + C_COUPLER * vx)
			# an impact: the play has just been used up
			var was = float(ext[i])
			if (absf(x) > PLAY) != (absf(was) > PLAY) and absf(x) > absf(was):
				clank = maxf(clank, absf(vx))
				if absf(vx) > 0.15: hits.append({"kind": "coupler", "body": i, "speed": absf(vx)})
			ext[i] = x
			forces[i] = t
			tension[i] = t
			peak_tension = maxf(peak_tension, absf(t))
		a_abs[0] = a_head
		for i in range(1, n):
			var t_front = float(forces[i])
			var t_rear = float(forces[i + 1]) if i + 1 < n else 0.0
			var a_i = float(a_free[i]) + (t_front - t_rear) / maxf(1.0, float(mass[i]))
			a_abs[i] = a_i
			qd[i] = float(qd[i]) + (a_i - a_head) * h
			q[i] = float(q[i]) + float(qd[i]) * h
			if absf(float(q[i])) > LIMIT * float(i):
				q[i] = clampf(float(q[i]), -LIMIT * float(i), LIMIT * float(i))
				qd[i] = 0.0
	# --- suspension and rocking
	for i in range(n):
		var s = m.body_s(i)
		var k = float(body_k[i])
		var omega = BODY_OMEGA * k
		var kappa = -(m.route.slope(s + 1.5) - m.route.slope(s - 1.5)) / 3.0   # + on a crest
		var force_up = speed * speed * kappa
		# the rail is never perfectly even: a quiet slow unevenness, stronger with speed
		force_up += RAIL_ROUGH * minf(speed / 12.0, 1.0) * (sin(s * 0.9 + float(i) * 1.3) + 0.6 * sin(s * 2.31 + float(i) * 2.9))
		# the rail joints kick the wheels: the front and the rear axle one after another, every joint a little different
		var marks: Array = joint_at[i]
		for axle_index in range(2):
			var axle = -0.9 if axle_index == 0 else 0.9
			var j = floori((s + axle) / JOINT_SPACING)
			if int(marks[axle_index]) == -99999:
				marks[axle_index] = j
			elif j != int(marks[axle_index]):
				marks[axle_index] = j
				if speed > 0.25:
					var strength = 0.45 + 1.0 * hash01(float(j), 1.0 + float(axle_index))   # the joint is worn more or less
					var sp = minf(speed, 25.0)
					lift_v[i] = float(lift_v[i]) - JOINT_KICK * sp * strength
					rock_v[i] = float(rock_v[i]) + (JOINT_ROCK_KICK if axle_index == 0 else -JOINT_ROCK_KICK) * sp * strength
		lift_v[i] = float(lift_v[i]) + (force_up - 2.0 * BODY_ZETA * omega * float(lift_v[i]) - omega * omega * float(lift[i])) * dt
		lift[i] = clampf(float(lift[i]) + float(lift_v[i]) * dt, -3.0 * LIFT_LIMIT, 3.0 * LIFT_LIMIT)
		var drive_a = a_head if i == 0 else float(a_abs[i])
		var target_rock = ROCK_GAIN * drive_a
		var r_omega = ROCK_OMEGA * k
		rock_v[i] = float(rock_v[i]) + (r_omega * r_omega * (target_rock - float(rock[i])) - 2.0 * ROCK_ZETA * r_omega * float(rock_v[i])) * dt
		rock[i] = clampf(float(rock[i]) + float(rock_v[i]) * dt, -3.0 * ROCK_LIMIT, 3.0 * ROCK_LIMIT)
	# --- cargo on its straps
	for item in m.state.cargo:
		if str(item.slot) == "" or item.delivered: continue
		var owner = str(item.slot).split(":")[0]
		var i = ids.find(owner)
		if i < 0: continue
		var key = str(item.id)
		if not load_shift.has(key): load_shift[key] = {"p": 0.0, "v": 0.0}
		var entry: Dictionary = load_shift[key]
		var a_body = a_head if i == 0 else float(a_abs[i])
		var p = float(entry.p)
		var pv = float(entry.v)
		pv += (-a_body - 2.0 * LASH_ZETA * LASH_OMEGA * pv - LASH_OMEGA * LASH_OMEGA * p) * dt
		p += pv * dt
		if absf(p) > CARGO_PLAY:
			var impact = absf(pv)
			p = clampf(p, -CARGO_PLAY, CARGO_PLAY)
			if impact > 0.05:
				hit_speed = maxf(hit_speed, impact)
				hits.append({"kind": "cargo", "body": i, "speed": impact, "id": key})
			pv = -pv * CARGO_BOUNCE
		entry.p = p
		entry.v = pv
	# cargo that was delivered or removed leaves the table
	for key in load_shift.keys():
		var found = false
		for item in m.state.cargo:
			if str(item.id) == str(key) and str(item.slot) != "" and not item.delivered: found = true
		if not found: load_shift.erase(key)
