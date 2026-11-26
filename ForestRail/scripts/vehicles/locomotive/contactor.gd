extends RefCounted
# «Скрутка» электровоза: шкафчик в кабине (1.4.10, переделка 1.12 по решениям владельца 19–20.11,
# docs/ELECTRIC_CABINET_MECHANIC_RU.md).
#
# Пуск: в шкафчике цветные провода (от 3 до 5, растёт с прокачкой). Конец провода тащат мышью к клемме своего цвета
# и скручивают петлями вокруг стыка: 3 ровные петли — тугая скрутка, 1–2 или рыхлые — слабая (засчитана, но от тряски
# может отскочить). Каждый виток имеет качество (демка владельца «Мастерская двигателя», 21.11): мимо стыка — 0,
# слишком широкий — меньше. Тугая — 3 витка, из них 2 с контактом, сумма качества ≥ 3 × 0.6625. Петля в обратную
# сторону снимает последний виток. После ремонта сгоревшего мотора провода спутаны: каждый протягивают через его кольцо.
# Стык рвётся, если хорошенько подёргать провод (огрызок остаётся в шкафчике). Все стыки скручены — лампа ГОТОВ.
# Рубильник в кабине вверх — пуск (3% заряда на бросок тока). Неверная скрутка на пуске — искра: сгорает предохранитель,
# «осталось N попыток»; сгорел последний — искра уходит в мотор: мотор сгорел, только помощь депо.
# Рубильник вниз — стоп, провода разводятся заново (антиугонка).
#
# В пути предохранители горят от перегрева мотора и от тряски, сначала предупреждение (патрон светится и гудит).
# Сгоревший спас мотор: тяга −15% за каждый, заряд тратится на 10% быстрее. Целых нет — едешь без защиты: следующая
# искра сжигает мотор. Запасные (3, как спички) меняют на стоянке, депо пополняет. Секретки — см. документ.
#
# Состояние в fleet_by_id.locomotive.contactor (сохраняется):
#   on, to, at, popped, torn, serial — как в 1.4.10;
#   loops   — по проводу список качеств витков (0…1); dir — в какую сторону крутили (+1/−1, 0 — ещё нет);
#   knot    — провода, ещё спутанные после ремонта;
#   fuses   — три держателя: "ok" | "burnt" | "bug";
#   scraps  — огрызки проводов в шкафчике (для жучка);
#   order   — порядок, в котором скручивали провода (секрет «радужный порядок»);
#   golden  — провода, скрученные ровно 5 петлями одним движением (секрет «золотая скрутка»);
#   rainbow, soft_guard — флаги текущего пуска; motor_burnt — мотор сгорел; heat_t, shake, wink_t — риски в пути.
# Запасные предохранители — fleet_by_id.locomotive.spare_fuses.

const MIN_WIRES = 3
const MAX_WIRES = 5
const TWIST_NEEDED = 3.0        # петель на тугую скрутку
const TWIST_LOOSE = 1.0         # столько хватает, чтобы стык засчитался (слабая)
const TWIST_MAX = 5.0
const GOLDEN = 5.0              # секрет: ровно столько ровных петель одним движением
const GOOD = 0.6625             # средняя доля хорошего витка (порог демки владельца)
const TIGHT_GRIP = TWIST_NEEDED * GOOD
const START_CHARGE = 0.03       # бросок тока при обычном пуске
const SPARK_CHARGE = 0.05
const SPARK_WEAR = 0.025
const POP_PER_MIN = 0.6
const FUSE_POWER = 0.15         # −15% тяги за сгоревший предохранитель
const FUSE_DRAIN = 0.10         # +10% расхода за сгоревший
const HEAT_LIMIT = 0.85         # нагрев мотора, с которого патрон начинает греться
const HEAT_GRACE = 2.5          # секунд предупреждения до перегорания
const FUSE_COOLDOWN = 20.0      # секунд передышки после сгоревшего в пути: успеть сбавить
const SHAKE_TOP = 0.92          # доля высшей скорости, на которой начинает трясти
const RAINBOW_POWER = 1.15
const RAINBOW_DRAIN = 1.25
const RAINBOW_HEAT = 1.1
const WINK_S = 30.0
const WINK_GRADE = -0.015
const WINK_HOT = 0.7
const SPARES = 3
# цвета проводов в порядке радуги полоски заряда (красный … синий); белый вне радуги
const RAINBOW_RANK = [0, 3, 1, 2, 4]   # провод i (красный, синий, жёлтый, зелёный, белый) → место в радуге

var m = null

func _init(owner_model = null) -> void:
	m = owner_model

func fleet() -> Dictionary:
	return m.state.fleet_by_id.get("locomotive", {})

func st() -> Dictionary:
	var f: Dictionary = fleet()
	if not f.has("contactor") or not f.contactor is Dictionary:
		f.contactor = {"on": false, "to": [], "at": [], "loops": [], "dir": [], "popped": [], "torn": [], "serial": 0}
		scramble()
	var s: Dictionary = f.contactor
	# a save comes back from JSON with every number a float: the wire numbers are made whole again (once)
	if not (s.to as Array).is_empty() and typeof(s.to[0]) == TYPE_FLOAT:
		for key in ["to", "at", "popped", "torn", "order", "golden", "dir", "knot"]:
			var whole: Array = []
			for v in s.get(key, []): whole.append(int(v))
			s[key] = whole
	# 1.12: older saves have no fuses yet
	if not s.has("fuses"): s.fuses = ["ok", "ok", "ok"]
	for key in ["order", "golden", "knot"]:
		if not s.has(key): s[key] = []
	# older saves count turns as a number: each whole turn becomes a good loop
	if not s.has("loops"):
		s.loops = []
		s.dir = []
		for t in s.get("turns", []):
			var list: Array = []
			for n in range(floori(float(t))): list.append(1.0)
			s.loops.append(list)
			s.dir.append(0)
		s.erase("turns")
	if not s.has("scraps"): s.scraps = 1
	if not f.has("spare_fuses"): f.spare_fuses = SPARES
	if not bool(s.on) and (s.to as Array).size() != wires(): scramble()
	return s

# 3 провода у нового электровоза (владелец: «от 3х»), +1 за каждые два уровня улучшений, до пяти.
func wires() -> int:
	var levels = 0
	var object = m.object_state("locomotive")
	for branch in object.get("levels", {}):
		levels += int(object.levels[branch])
	return clampi(MIN_WIRES + levels / 2, MIN_WIRES, MAX_WIRES)

func count() -> int:
	return (st().to as Array).size()

func terminal_of(wire: int) -> int:
	return int(st().to[wire])

func at(wire: int) -> int:
	return int(st().at[wire])

func turns(wire: int) -> float:
	return float((st().loops[wire] as Array).size())

# сумма качества витков и сколько из них держат контакт
func grip(wire: int) -> float:
	var sum = 0.0
	for q in st().loops[wire]: sum += float(q)
	return sum

func contact(wire: int) -> int:
	var n = 0
	for q in st().loops[wire]: if float(q) > 0.0: n += 1
	return n

func loop_quality(wire: int) -> Array:
	return st().loops[wire]

# самый слабый виток рыхлой скрутки (его показывают игроку), -1 — нечего показать
func weakest(wire: int) -> int:
	var list: Array = st().loops[wire]
	if list.size() < int(TWIST_NEEDED) or tight(wire): return -1
	return list.find(list.min())

func is_on() -> bool:
	return bool(st().on)

func live() -> bool:
	var s = st()
	return bool(s.on) and (s.popped as Array).is_empty() and not bool(s.get("motor_burnt", false))

func joined(wire: int) -> bool:
	return at(wire) >= 0

# засчитан: хватает одного витка с контактом; тугой — 3 витка, 2 с контактом, сумма качества не меньше порога
func twisted(wire: int) -> bool:
	return joined(wire) and contact(wire) >= int(TWIST_LOOSE)

func tight(wire: int) -> bool:
	return joined(wire) and turns(wire) >= TWIST_NEEDED and contact(wire) >= 2 and grip(wire) >= TIGHT_GRIP - 0.0001

func knotted(wire: int) -> bool:
	return (st().knot as Array).has(wire)

func knot_left() -> int:
	var n = 0
	for w in st().knot: if int(w) < count(): n += 1
	return n

# провод протянули через его кольцо: он свободен
func unknot(wire: int) -> bool:
	var s = st()
	if not knotted(wire): return false
	s.knot.erase(wire)
	m.events.append("wire_unknotted")
	m.message = "Клубок распутан" if knot_left() == 0 else "Провод выпутан"
	return true

func all_joined() -> bool:
	for i in range(count()):
		if not joined(i): return false
	return true

func ready() -> bool:
	for i in range(count()):
		if not twisted(i): return false
	return true

# --- предохранители
func fuses() -> Array:
	return st().fuses

func fuse_count(kind: String) -> int:
	return (st().fuses as Array).count(kind)

func spares() -> int:
	return int(fleet().get("spare_fuses", SPARES))

func scraps() -> int:
	return int(st().get("scraps", 0))

func motor_burnt() -> bool:
	return bool(st().get("motor_burnt", false))

# --- новое разведение: свой порядок клемм, все провода свободны; в творческом скрутка готовая
func scramble() -> void:
	var s: Dictionary = fleet().contactor
	s.serial = int(s.get("serial", 0)) + 1
	var n = wires()
	var order: Array = []
	for i in range(n): order.append(i)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(m.route.seed_value) * 7919 + int(s.serial) * 104729 + 17
	for i in range(n - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	if n > 1 and order == range(n):
		var t = order[0]
		order[0] = order[1]
		order[1] = t
	s.to = order
	s.at = []
	s.loops = []
	s.dir = []
	for i in range(n):
		s.at.append(order[i] if m.creative() else -1)
		s.loops.append([1.0, 1.0, 1.0] if m.creative() else [])
		s.dir.append(0)
	s.popped = []
	s.torn = []
	s.order = []
	s.golden = []

func join(wire: int, terminal: int) -> bool:
	var s = st()
	if wire < 0 or wire >= count() or terminal < 0 or terminal >= count(): return false
	if knotted(wire): return m.fail("Провод спутан: протяни его через кольцо его цвета")
	for i in range(count()):
		if i != wire and int(s.at[i]) == terminal:
			s.at[i] = -1
			s.loops[i] = []
			s.dir[i] = 0
			s.order.erase(i)
			s.golden.erase(i)
	s.at[wire] = terminal
	s.loops[wire] = []
	s.dir[wire] = 0
	s.torn.erase(wire)
	s.golden.erase(wire)
	m.events.append("wire_join")
	return true

func unjoin(wire: int) -> void:
	var s = st()
	if wire < 0 or wire >= count(): return
	s.at[wire] = -1
	s.loops[wire] = []
	s.dir[wire] = 0
	s.order.erase(wire)
	s.golden.erase(wire)

# Стык порвали рывком: провод свободен, обрывок остаётся в шкафчике (огрызок для жучка).
func tear(wire: int) -> bool:
	if wire < 0 or wire >= count() or not joined(wire) or is_on(): return false
	unjoin(wire)
	var s = st()
	if not (s.torn as Array).has(wire): s.torn.append(wire)
	s.scraps = scraps() + 1
	m.events.append("wire_torn")
	m.message = "Скрутка порвана: провод свободен, обрывок остался в шкафчике"
	return true

# Накрутить на стык `loops` витков качества q (0…1). run — сколько витков накручено этим же движением без отпускания
# (для «золотой скрутки»: 5 ровных за одно движение). dir — сторона петли: петля против первой снимает последний виток.
func twist(wire: int, loops: float = 1.0, run: float = 0.0, q: float = 1.0, dir: int = 0) -> float:
	var s = st()
	if wire < 0 or wire >= count() or not joined(wire) or loops <= 0.0: return turns(wire)
	var list: Array = s.loops[wire]
	if dir != 0 and int(s.dir[wire]) != 0 and dir != int(s.dir[wire]):
		list.pop_back()
		if list.is_empty(): s.dir[wire] = 0
		s.golden.erase(wire)
		if not twisted(wire): s.order.erase(wire)
		m.events.append("untwist")
		return turns(wire)
	if dir != 0: s.dir[wire] = dir
	var was = twisted(wire)
	for n in range(roundi(loops)):
		if list.size() >= int(TWIST_MAX): break
		list.append(clampf(q, 0.0, 1.0))
		m.events.append("twist")
	if not was and twisted(wire) and not (s.order as Array).has(wire): s.order.append(wire)
	if twisted(wire): s.popped.erase(wire)
	if run >= GOLDEN - 0.05 and turns(wire) >= GOLDEN and grip(wire) >= GOLDEN * GOOD and not (s.golden as Array).has(wire):
		s.golden.append(wire)
		m.events.append("golden_twist")
	return turns(wire)

func golden_all() -> bool:
	var s = st()
	for i in range(count()):
		if not (s.golden as Array).has(i): return false
	return count() > 0

func rainbow_order() -> bool:
	var s = st()
	var order: Array = s.order
	if order.size() != count(): return false
	for k in range(order.size() - 1):
		if RAINBOW_RANK[int(order[k])] > RAINBOW_RANK[int(order[k + 1])]: return false
	return true

# --- рубильник вверх: пуск. soft — опущен медленно и ровно (секрет «мягкий пуск»).
func start(soft: bool = false) -> bool:
	var s = st()
	if bool(s.on): return true
	if motor_burnt(): return m.fail("Мотор сгорел. Только помощь депо")
	if float(fleet().fuel) <= 0.0: return m.fail("Аккумулятор пуст. Вызови помощь депо")
	if knot_left() > 0: return m.fail("Провода спутаны после ремонта: протяни каждый через его кольцо")
	if not all_joined():
		var done = 0
		for i in range(count()): if joined(i): done += 1
		return m.fail("Соедини все провода: %d из %d" % [done, count()])
	if not ready(): return m.fail("Скрути стыки: обведи каждый курсором петлями")
	var wrong: Array = []
	for i in range(count()):
		if at(i) != terminal_of(i): wrong.append(i)
	if not wrong.is_empty():
		spark(wrong)
		return false
	s.on = true
	s.popped = []
	s.rainbow = rainbow_order()
	s.soft_guard = soft
	s.heat_t = 0.0
	s.shake = 0.0
	if not soft and not m.creative():
		fleet().fuel = maxf(0.0, float(fleet().fuel) - START_CHARGE * float(m.object_stats("locomotive").tank))
	m.state.engine = true
	m.events.append("contactor_on")
	if soft: m.events.append("soft_start")
	if bool(s.rainbow): m.events.append("rainbow_start")
	var loose = 0
	for i in range(count()): if not tight(i): loose += 1
	m.message = "Пуск" + ("" if loose == 0 else ". Слабых скруток: %d, от тряски могут отскочить" % loose)
	return true

# старое имя (кнопка ПУСК/СТОП 1.4.10): переключить
func press() -> bool:
	if is_on():
		stop()
		return true
	return start(false)

# Неверная скрутка на пуске: искра. Сгорает предохранитель; последний — и мотор.
func spark(wrong: Array) -> void:
	var s = st()
	var tank = float(m.object_stats("locomotive").tank)
	fleet().fuel = maxf(0.0, float(fleet().fuel) - SPARK_CHARGE * tank)
	if m.wear_rules: m.wear().damage("locomotive", "controller", SPARK_WEAR, "неверная скрутка")
	for wire in wrong:
		unjoin(wire)
		if not (s.torn as Array).has(wire): s.torn.append(wire)
	m.events.append("spark")
	var slot = (s.fuses as Array).find("ok")
	if slot < 0:
		burn_motor("искра при пуске")
		return
	s.fuses[slot] = "burnt"
	m.events.append("fuse_burnt")
	var left = fuse_count("ok")
	if left == 0:
		burn_motor("искра при пуске")
		return
	m.message = "Искра! Сгорел предохранитель, осталось попыток: %d. Порви неверные скрутки и смотри на цвета" % left

func burn_motor(why: String) -> void:
	var s = st()
	s.motor_burnt = true
	s.on = false
	m.state.engine = false
	if m.wear_rules: m.wear().set_condition("locomotive", "motor", 0.0)
	m.events.append("motor_burnt")
	m.message = "Искра сожгла мотор (%s). Только помощь депо" % why

func stop() -> void:
	var s = st()
	var was_on = bool(s.on)
	s.on = false
	s.rainbow = false
	s.soft_guard = false
	s.wink_t = 0.0
	m.state.engine = false
	scramble()
	if was_on: m.events.append("contactor_off")

# --- в пути: перегрев и тряска жгут предохранители (сначала предупреждение), слабые скрутки отскакивают
func warning() -> bool:
	var s = st()
	return bool(s.on) and (float(s.get("heat_t", 0.0)) > 0.0 or float(s.get("shake", 0.0)) > 0.5 or float(s.get("wink_t", 0.0)) > 0.0)

func step(dt: float) -> void:
	var s = st()
	if not bool(s.on): return
	if float(fleet().fuel) <= 0.0:
		stop()
		return
	# after a fuse has burnt the player gets a breather to ease off (audit 21.11: else all three and the motor went in ~10 s)
	s.cool_t = maxf(0.0, float(s.get("cool_t", 0.0)) - dt)
	if float(s.get("wink_t", 0.0)) > 0.0:
		s.wink_t = maxf(0.0, float(s.wink_t) - dt)
		if m.engine_temp() > WINK_HOT:
			s.wink_t = 0.0   # the wink is over with the burnt fuse, not one fuse a frame
			burn_fuse("перегрев на рекуперации")
	# heat: over the limit the fuse warms; after the grace it burns
	if m.engine_temp() >= HEAT_LIMIT and float(s.cool_t) <= 0.0:
		s.heat_t = float(s.get("heat_t", 0.0)) + dt
		if float(s.heat_t) >= HEAT_GRACE:
			s.heat_t = 0.0
			burn_fuse("перегрев")
	else:
		s.heat_t = maxf(0.0, float(s.get("heat_t", 0.0)) - dt * 2.0)
	# shake: near the top speed only a weak twist rattles (audit 21.11: tight ones burnt a fuse every 12 s of a fast run)
	var speed = absf(float(m.state.v))
	var top = float(m.object_stats("locomotive").speeds[0])
	var loose = 0
	for i in range(count()): if not tight(i): loose += 1
	if speed > SHAKE_TOP * top and loose > 0 and float(s.cool_t) <= 0.0:
		s.shake = float(s.get("shake", 0.0)) + dt * 0.08
	else:
		s.shake = maxf(0.0, float(s.get("shake", 0.0)) - dt * 0.05)
	if float(s.shake) >= 1.0:
		s.shake = 0.0
		if not golden_all(): burn_fuse("тряска")
	if speed < 0.3: return
	var rng = RandomNumberGenerator.new()
	for i in range(count()):
		if tight(i) or (s.popped as Array).has(i) or (s.golden as Array).has(i): continue
		var looseness = clampf((TIGHT_GRIP - grip(i)) / TIGHT_GRIP, 0.0, 1.0)
		rng.seed = int(m.route.seed_value) * 31 + i * 977 + int(float(m.state.stats.seconds) * 60.0)
		if rng.randf() < POP_PER_MIN * looseness * dt / 60.0:
			s.popped.append(i)
			m.events.append("wire_popped")
			m.message = "Провод отскочил: тяги нет. Открой шкафчик и докрути стык"

# a hard knock (the emergency brake on the move, a hard coupling): adds to the shake
func jolt(amount: float) -> void:
	var s = st()
	if not bool(s.on): return
	var loose = 0
	for i in range(count()): if not tight(i): loose += 1
	s.shake = float(s.get("shake", 0.0)) + amount * (2.0 if loose > 0 else 1.0)

func burn_fuse(why: String) -> void:
	var s = st()
	if bool(s.get("soft_guard", false)) and why.begins_with("перегрев"):
		s.soft_guard = false
		m.events.append("fuse_held")
		m.message = "Предохранитель выдержал перегрев: мягкий пуск его сберёг"
		return
	var slot = (s.fuses as Array).find("ok")
	if slot < 0:
		burn_motor(why)
		return
	s.fuses[slot] = "burnt"
	s.cool_t = FUSE_COOLDOWN
	m.events.append("fuse_burnt")
	m.message = "Сгорел предохранитель (%s) и спас мотор: тяга −%d%%%s" % [why, roundi(FUSE_POWER * 100.0 * float(fuse_count("burnt"))), "" if fuse_count("ok") > 0 else ". Целых не осталось: следующая искра сожжёт мотор"]

# --- поправки к езде (model.gd): только при контакторных правилах
func power_factor() -> float:
	var s = st()
	return (1.0 - FUSE_POWER * float(fuse_count("burnt"))) * (RAINBOW_POWER if bool(s.get("rainbow", false)) else 1.0)

func drain_factor() -> float:
	var s = st()
	return (1.0 + FUSE_DRAIN * float(fuse_count("burnt"))) * (RAINBOW_DRAIN if bool(s.get("rainbow", false)) else 1.0)

func heat_factor() -> float:
	return RAINBOW_HEAT if bool(st().get("rainbow", false)) else 1.0

func regen_factor() -> float:
	return 2.0 if float(st().get("wink_t", 0.0)) > 0.0 else 1.0

# Подмигнуть рубильником на спуске: вниз и сразу вверх. Рекуперация ×2 на 30 с.
func wink() -> bool:
	var s = st()
	if not bool(s.on): return false
	if absf(float(m.state.v)) < 0.5 or m.route.slope(float(m.state.s)) * float(m.state.direction) > WINK_GRADE:
		m.events.append("wink_flat")
		return false
	if float(s.get("wink_t", 0.0)) > 0.0: return false
	s.wink_t = WINK_S
	m.events.append("wink")
	m.message = "Рекуперация усилена"
	return true

# --- руками в шкафчике, на стоянке
func replace_fuse(slot: int) -> bool:
	var s = st()
	if slot < 0 or slot >= 3: return false
	if str(s.fuses[slot]) == "ok": return false
	if absf(float(m.state.v)) > 0.3: return m.fail("Предохранитель меняют только на стоянке")
	if spares() <= 0 and not m.creative(): return m.fail("Запасных предохранителей нет: депо даст новые")
	if not m.creative(): fleet().spare_fuses = spares() - 1
	s.fuses[slot] = "ok"
	m.events.append("fuse_replaced")
	m.message = "Предохранитель заменён"
	return true

func bug(slot: int) -> bool:
	var s = st()
	if slot < 0 or slot >= 3 or str(s.fuses[slot]) != "burnt": return false
	if absf(float(m.state.v)) > 0.3: return m.fail("Мотать проволоку на ходу нельзя")
	if scraps() <= 0: return m.fail("Нечем мотать: обрывка провода нет")
	s.scraps = scraps() - 1
	s.fuses[slot] = "bug"
	m.events.append("fuse_bug")
	m.message = "Жучок поставлен: тяга вернулась, защиты нет"
	return true

# Депо: новые предохранители вместо сгоревших и жучков, запасные снова 3, огрызок в углу, мотор цел.
func refill() -> void:
	if not m.state.fleet_by_id.has("locomotive"): return
	var s = st()
	# owner 21.11: after the burnt motor is repaired the wires come back in a knot (not on every start)
	if bool(s.get("motor_burnt", false)) and not m.creative():
		s.knot = range(count())
		for i in range(count()): unjoin(i)
	s.fuses = ["ok", "ok", "ok"]
	s.scraps = maxi(1, scraps())
	s.motor_burnt = false
	fleet().spare_fuses = SPARES
