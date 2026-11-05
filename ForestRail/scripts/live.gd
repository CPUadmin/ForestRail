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
const BODY_OMEGA = 10.0     # подвеска: ~1,6 Гц
const BODY_ZETA = 0.28
const ROCK_OMEGA = 7.5
const ROCK_ZETA = 0.75
const ROCK_GAIN = 0.002     # subtle suspension pitch, rad per m/s²; wheelsets share the rendered transform
const LIFT_LIMIT = 0.06
const ROCK_LIMIT = 0.006    # at most 0.34 degrees relative to the rail
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
var load_shift: Dictionary = {}   # id груза -> {p, v} положение вдоль кузова, м (+ вперёд по ходу)
var clank = 0.0          # самый сильный удар сцепки за последний шаг (скорость удара, м/с)
var peak_tension = 0.0   # самая большая сила в сцепках за последний шаг
var hit_speed = 0.0      # самый сильный удар груза о борт за последний шаг
var hits: Array = []     # события этого шага: {"body", "speed", "id"}

func reset(count: int = 0) -> void:
	n = count
	q.clear(); qd.clear(); ext.clear(); tension.clear(); lift.clear(); lift_v.clear(); rock.clear(); rock_v.clear(); joint_at.clear()
	for i in range(n):
		q.append(0.0); qd.append(0.0); ext.append(0.0); tension.append(0.0)
		lift.append(0.0); lift_v.append(0.0); rock.append(0.0); rock_v.append(0.0); joint_at.append([-99999, -99999])
	load_shift.clear()
	clank = 0.0
	peak_tension = 0.0
	hit_speed = 0.0
	hits.clear()

# --- reading (safe for any index: before the first step everything is zero)
func slack_m(i: int) -> float:
	return float(q[i]) if i >= 0 and i < q.size() else 0.0

func lift_m(i: int) -> float:
	return float(lift[i]) if i >= 0 and i < lift.size() else 0.0

func rock_rad(i: int) -> float:
	return float(rock[i]) if i >= 0 and i < rock.size() else 0.0

func extension(i: int) -> float:
	return float(ext[i]) if i >= 0 and i < ext.size() else 0.0

func cargo_p(item_id) -> float:
	return float(load_shift.get(str(item_id), {}).get("p", 0.0))

# --- a hard landing shakes every body, the nearer to the head the harder
func landed(impact: float) -> void:
	for i in range(n):
		lift_v[i] = float(lift_v[i]) - impact * 0.12 * pow(0.85, float(i))
		rock_v[i] = float(rock_v[i]) + impact * 0.05 * (1.0 if i % 2 == 0 else -1.0)

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
		var kappa = -(m.route.slope(s + 1.5) - m.route.slope(s - 1.5)) / 3.0   # + on a crest
		var force_up = speed * speed * kappa
		# the rail joints kick the wheels: the front and the rear axle one after another
		var marks: Array = joint_at[i]
		for k in range(2):
			var axle = -0.9 if k == 0 else 0.9
			var j = floori((s + axle) / JOINT_SPACING)
			if int(marks[k]) == -99999:
				marks[k] = j
			elif j != int(marks[k]):
				marks[k] = j
				if speed > 0.25:
					lift_v[i] = float(lift_v[i]) - 0.005 * minf(speed, 25.0)
					rock_v[i] = float(rock_v[i]) + (0.004 if k == 0 else -0.004) * minf(speed, 25.0)
		lift_v[i] = float(lift_v[i]) + (force_up - 2.0 * BODY_ZETA * BODY_OMEGA * float(lift_v[i]) - BODY_OMEGA * BODY_OMEGA * float(lift[i])) * dt
		lift[i] = clampf(float(lift[i]) + float(lift_v[i]) * dt, -LIFT_LIMIT, LIFT_LIMIT)
		var drive_a = a_head if i == 0 else float(a_abs[i])
		var target_rock = clampf(ROCK_GAIN * drive_a, -ROCK_LIMIT, ROCK_LIMIT)
		rock_v[i] = float(rock_v[i]) + (ROCK_OMEGA * ROCK_OMEGA * (target_rock - float(rock[i])) - 2.0 * ROCK_ZETA * ROCK_OMEGA * float(rock_v[i])) * dt
		rock[i] = clampf(float(rock[i]) + float(rock_v[i]) * dt, -ROCK_LIMIT, ROCK_LIMIT)
		if absf(float(rock[i])) >= ROCK_LIMIT and float(rock[i]) * float(rock_v[i]) > 0.0:
			rock_v[i] = 0.0
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
