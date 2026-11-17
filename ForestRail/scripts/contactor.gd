extends RefCounted
# 1.4.10 «Скрутка» (идея владельца 14.11, решения приняты, docs/ELECTRIC_START_PROPOSAL_RU.md): электровоз
# запускается в ящике КОНТАКТОР. Внутри разведённые провода (антиугонка): каждый провод надо подвести к своей клемме
# (по цвету и рисунку изоляции), скрутить двумя оборотами и нажать ПУСК. Та же кнопка потом СТОП, и провода сами
# разводятся в новом порядке. Неверная пара на ПУСК: искра, −5% заряда, урон контроллеру, провода этой пары рвутся.
# Недокрученный провод (меньше двух оборотов) может отскочить на ходу: тяга пропадает, пока его не докрутишь.
# Число проводов растёт с прокачкой электровоза: от 1 до 5.
#
# Состояние живёт в fleet_by_id.locomotive.contactor (сохраняется вместе с игрой):
#   on        — контактор включён
#   to        — для провода i его клемма (порядок разведения)
#   at        — для провода i клемма, к которой он сейчас подведён (-1: свободен)
#   turns     — обороты скрутки провода i
#   popped    — провода, отскочившие на ходу
#   torn      — провода, порванные искрой (для картинки: обгорелые концы, пока их не подведут снова)
#   serial    — номер разведения (чтобы каждое было новым и повторялось при той же игре)

const MAX_WIRES = 5
const TWIST_NEEDED = 2.0
const TWIST_MAX = 3.0
const SPARK_CHARGE = 0.05       # доля полного заряда, которую съедает искра
const SPARK_WEAR = 0.025        # урон узлу «контроллер»
const POP_PER_MIN = 0.6         # шанс в минуту, что совсем не скрученный провод отскочит (недокрут на 1 оборот — вдвое реже)

var m = null

func _init(owner_model = null) -> void:
	m = owner_model

func st() -> Dictionary:
	var fleet: Dictionary = m.state.fleet_by_id.get("locomotive", {})
	if not fleet.has("contactor") or not fleet.contactor is Dictionary:
		fleet.contactor = {"on": false, "to": [], "at": [], "turns": [], "popped": [], "torn": [], "serial": 0}
		scramble()
	var s: Dictionary = fleet.contactor
	# a save comes back from JSON with every number a float: the wire numbers are made whole again (once)
	if not (s.to as Array).is_empty() and typeof(s.to[0]) == TYPE_FLOAT:
		for key in ["to", "at", "popped", "torn"]:
			var whole: Array = []
			for v in s.get(key, []): whole.append(int(v))
			s[key] = whole
	# the upgrades changed the number of wires while it was off: a new scheme of the right size
	if not bool(s.on) and (s.to as Array).size() != wires(): scramble()
	return s

# 1 провод у нового электровоза, по одному за каждый купленный уровень улучшений, до пяти.
func wires() -> int:
	var levels = 0
	var object = m.object_state("locomotive")
	for branch in object.get("levels", {}):
		levels += int(object.levels[branch])
	return clampi(1 + levels, 1, MAX_WIRES)

func count() -> int:
	return (st().to as Array).size()

func terminal_of(wire: int) -> int:
	return int(st().to[wire])

func at(wire: int) -> int:
	return int(st().at[wire])

func turns(wire: int) -> float:
	return float(st().turns[wire])

func is_on() -> bool:
	return bool(st().on)

# Тянет ли машина: контактор включён и ни один провод не отскочил.
func live() -> bool:
	var s = st()
	return bool(s.on) and (s.popped as Array).is_empty()

func joined(wire: int) -> bool:
	return at(wire) >= 0

func twisted(wire: int) -> bool:
	return joined(wire) and turns(wire) >= TWIST_NEEDED

func all_joined() -> bool:
	for i in range(count()):
		if not joined(i): return false
	return true

# Лампа ГОТОВ: все провода подведены и скручены.
func ready() -> bool:
	for i in range(count()):
		if not twisted(i): return false
	return true

# Новое разведение: свой порядок клемм, все провода свободны. В творческом режиме скрутка готовая.
func scramble() -> void:
	var s: Dictionary = m.state.fleet_by_id.locomotive.contactor
	s.serial = int(s.get("serial", 0)) + 1
	var n = wires()
	var order: Array = []
	for i in range(n): order.append(i)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(m.route.seed_value) * 7919 + int(s.serial) * 104729 + 17
	for i in range(n - 1, 0, -1):   # Fisher-Yates
		var j = rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	if n > 1 and order == range(n):   # never the plain order: the wires must look scrambled
		var t = order[0]
		order[0] = order[1]
		order[1] = t
	s.to = order
	s.at = []
	s.turns = []
	for i in range(n):
		s.at.append(order[i] if m.creative() else -1)
		s.turns.append(TWIST_NEEDED if m.creative() else 0.0)
	s.popped = []
	s.torn = []

# Подвести конец провода к клемме. Если там уже чей-то провод, тот соскакивает.
func join(wire: int, terminal: int) -> bool:
	var s = st()
	if wire < 0 or wire >= count() or terminal < 0 or terminal >= count(): return false
	for i in range(count()):
		if i != wire and int(s.at[i]) == terminal:
			s.at[i] = -1
			s.turns[i] = 0.0
	s.at[wire] = terminal
	s.turns[wire] = 0.0
	s.torn.erase(wire)
	m.events.append("wire_join")
	return true

func unjoin(wire: int) -> void:
	var s = st()
	if wire < 0 or wire >= count(): return
	s.at[wire] = -1
	s.turns[wire] = 0.0

# Покрутить стык: delta — доля оборота (круг курсором вокруг стыка = 1). Каждый полный оборот поскрипывает.
func twist(wire: int, delta: float) -> float:
	var s = st()
	if wire < 0 or wire >= count() or not joined(wire) or delta <= 0.0: return turns(wire)
	var before = turns(wire)
	var after = minf(TWIST_MAX, before + delta)
	s.turns[wire] = after
	if floori(after) > floori(before): m.events.append("twist")
	if after >= TWIST_NEEDED: s.popped.erase(wire)
	return after

# Кнопка ПУСК/СТОП.
func press() -> bool:
	var s = st()
	if bool(s.on):
		stop()
		return true
	if float(m.state.fleet_by_id.locomotive.fuel) <= 0.0:
		return m.fail("Аккумулятор пуст. Вызови помощь депо")
	if not all_joined():
		var done = 0
		for i in range(count()): if joined(i): done += 1
		return m.fail("Соедини все провода: %d из %d" % [done, count()])
	var wrong: Array = []
	for i in range(count()):
		if at(i) != terminal_of(i): wrong.append(i)
	if not wrong.is_empty():
		spark(wrong)
		return false
	s.on = true
	s.popped = []
	m.state.engine = true
	m.events.append("contactor_on")
	var loose = 0
	for i in range(count()): if not twisted(i): loose += 1
	m.message = "Контактор включён" + ("" if loose == 0 else ". Недокручено проводов: %d, на ходу могут отскочить" % loose)
	return true

# Неверная пара: искра, аккумулятор проседает, контроллеру достаётся, провода рвутся и их надо подвести заново.
func spark(wrong: Array) -> void:
	var s = st()
	var fleet = m.state.fleet_by_id.locomotive
	var tank = float(m.object_stats("locomotive").tank)
	fleet.fuel = maxf(0.0, float(fleet.fuel) - SPARK_CHARGE * tank)
	if m.wear_rules: m.wear().damage("locomotive", "controller", SPARK_WEAR, "неверная скрутка")
	for wire in wrong:
		unjoin(wire)
		if not (s.torn as Array).has(wire): s.torn.append(wire)
	m.events.append("spark")
	m.message = "Искра! Неверная пара: аккумулятор просел, провода порвались. Смотри на цвета"

func stop() -> void:
	var s = st()
	var was_on = bool(s.on)
	s.on = false
	m.state.engine = false
	scramble()
	if was_on: m.events.append("contactor_off")

# На ходу: недокрученный провод может отскочить, тяга пропадает, пока его не докрутишь. Пустой аккумулятор глушит.
func step(dt: float) -> void:
	var s = st()
	if not bool(s.on): return
	if float(m.state.fleet_by_id.locomotive.fuel) <= 0.0:
		stop()
		return
	if absf(float(m.state.v)) < 0.3: return   # it shakes loose only on the move
	var rng = RandomNumberGenerator.new()
	for i in range(count()):
		if twisted(i) or (s.popped as Array).has(i): continue
		var looseness = clampf((TWIST_NEEDED - turns(i)) / TWIST_NEEDED, 0.0, 1.0)
		rng.seed = int(m.route.seed_value) * 31 + i * 977 + int(float(m.state.stats.seconds) * 60.0)
		if rng.randf() < POP_PER_MIN * looseness * dt / 60.0:
			s.popped.append(i)
			m.events.append("wire_popped")
			m.message = "Провод отскочил: тяги нет. Открой КОНТАКТОР и докрути стык"
