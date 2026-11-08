extends RefCounted
# Износ и повреждения (Веха 5, В5.6; docs/DAMAGE_RU.md). У каждой машины и вагона есть узлы с состоянием 0..1
# (1 новый). Износ растёт от езды, повреждения от ошибок, ремонт идёт болтами, деньгами и ремнаборами.
# Состояние лежит в object_state(id).wear = {узел: 0..1}; старые сохранения без износа читаются как 100%.
# Эффект узла: коэффициент floor + (1 - floor) * состояние; узлы одного действия перемножаются.
# Действия: brake (тормоз), roll (качение), power (тяга), capacity (запас), rig (парус, шест), shock (тряска, груз).

const BREAKDOWN_BELOW = 0.2     # ниже этого состояния узел может «встать» на ходу
const BREAKDOWN_PER_MINUTE = 0.03
const WARN_BELOW = 0.4          # лампа «АВАРИЯ»
const FREE_TOUCH_UP = 0.2       # депо бесплатно подправляет узел до этого состояния

const EFFECT_HINT = {"brake": "тормозной путь длиннее", "roll": "ход тяжелее", "power": "тяга слабее", "capacity": "запас меньше", "rig": "рвётся раньше", "shock": "груз бьётся"}

var m   # the model
var last_damage = ""            # последняя причина повреждения (для подсказки)
var journal: Array = []         # журнал рейса: последние причины урона [{why, node, name, amount}], новые в конце (не сохраняется)
const JOURNAL_MAX = 5

func _init(model) -> void:
	m = model

func cfg() -> Dictionary:
	return m.data.wear

# --- the nodes
func nodes_of(id: String) -> Array:
	var table: Dictionary = cfg().nodes
	return table.get("wagon", []) if id.begins_with("W") else table.get(id, [])

func node_def(id: String, node: String) -> Dictionary:
	for def in nodes_of(id):
		if str(def.id) == node: return def
	return {}

func condition(id: String, node: String) -> float:
	var object = m.object_state(id)
	if object.is_empty(): return 1.0
	return clampf(float(object.get("wear", {}).get(node, 1.0)), 0.0, 1.0)

func set_condition(id: String, node: String, value: float) -> void:
	var object = m.object_state(id)
	var def = node_def(id, node)
	if object.is_empty() or def.is_empty(): return
	var old = condition(id, node)
	if not object.has("wear"): object.wear = {}
	object.wear[node] = clampf(value, 0.0, 1.0)
	# a node falls below the lamp line or into the red: say so once, with what it means
	if value < old and m.state.phase == "route":
		var line = WARN_BELOW if old >= WARN_BELOW and value < WARN_BELOW else (BREAKDOWN_BELOW if old >= BREAKDOWN_BELOW and value < BREAKDOWN_BELOW else -1.0)
		if line > 0.0 and m.message == "":
			m.message = "%s%s: %d%%, %s. Лампа АВАРИЯ" % [str(def.name), (" " + id) if id.begins_with("W") else "", roundi(clampf(value, 0.0, 1.0) * 100.0), EFFECT_HINT.get(str(def.effect), "хуже")]
			m.events.append("wear_warn")

# The multiplier of one kind of action: 1.0 for a new machine, down to the floors of its worn nodes.
func factor(id: String, effect: String) -> float:
	var result = 1.0
	var object = m.object_state(id)
	if object.is_empty() or not object.has("wear"): return 1.0
	for def in nodes_of(id):
		if str(def.effect) != effect: continue
		var floor_value = float(def.get("floor", 0.6))
		result *= floor_value + (1.0 - floor_value) * condition(id, str(def.id))
	return result

# The weakest node of a machine: {"node", "name", "cond"}.
func worst(id: String) -> Dictionary:
	var best = {"node": "", "name": "", "cond": 1.0}
	for def in nodes_of(id):
		var value = condition(id, str(def.id))
		if value < float(best.cond): best = {"node": str(def.id), "name": str(def.name), "cond": value}
	return best

# The train's weakest: the lamp lights below WARN_BELOW on any body.
func train_worst() -> Dictionary:
	var best = {"id": "", "node": "", "name": "", "cond": 1.0}
	for id in m.body_ids():
		var w = worst(id)
		if float(w.cond) < float(best.cond): best = {"id": id, "node": w.node, "name": w.name, "cond": w.cond}
	return best

func warning() -> bool:
	return float(train_worst().cond) < WARN_BELOW

# --- wear: from the road (called with the metres of the step)
func wear_road(meters: float) -> void:
	if meters <= 0.0: return
	var km = meters / 1000.0
	var harsh = 1.0 + 0.2 * clampf(m.rain_effect() + m.cold(), 0.0, 1.0)   # rain and cold: +20% to the bearings and the brakes
	for id in m.body_ids():
		for def in nodes_of(id):
			var per_km = float(def.get("per_km", 0.0))
			if per_km <= 0.0: continue
			var weather = harsh if str(def.effect) in ["roll", "brake"] else 1.0
			set_condition(id, str(def.id), condition(id, str(def.id)) - per_km * km * weather)

# --- damage: from mistakes. Fractions of the node (0.05 = 5%). Returns the new state.
func damage(id: String, node: String, amount: float, why: String = "") -> float:
	if node_def(id, node).is_empty() or amount <= 0.0: return 1.0
	var value = condition(id, node) - amount
	set_condition(id, node, value)
	if why != "":
		last_damage = why
		note_journal(id, node, amount, why)
	if m.junk_rules: m.casino().trip_damage(id, amount)
	return clampf(value, 0.0, 1.0)

# The journal of the trip: the same cause on the same node adds up, the last five are kept.
func note_journal(id: String, node: String, amount: float, why: String) -> void:
	var name = str(node_def(id, node).get("name", node))
	if not journal.is_empty():
		var last = journal[journal.size() - 1]
		if str(last.why) == why and str(last.id) == id and str(last.node) == node:
			last.amount = float(last.amount) + amount
			return
	journal.append({"why": why, "id": id, "node": node, "name": name, "amount": amount})
	while journal.size() > JOURNAL_MAX: journal.pop_front()

# The lines for the pause window: "Юз: тормоз −7%", the newest first.
func journal_lines() -> Array:
	var lines: Array = []
	for i in range(journal.size() - 1, -1, -1):
		var e = journal[i]
		var who = "" if str(e.id) == m.vehicle_id() else " (%s)" % str(e.id)
		var why = str(e.why)
		lines.append("%s: %s%s −%d%%" % [why.substr(0, 1).to_upper() + why.substr(1), str(e.name).to_lower(), who, maxi(1, roundi(float(e.amount) * 100.0))])
	return lines

# The first node of a machine with the given effect (the damage goes to the real part: brake, bearings...).
func node_of(id: String, effect: String, preferred: String = "") -> String:
	if preferred != "" and not node_def(id, preferred).is_empty(): return preferred
	for def in nodes_of(id):
		if str(def.effect) == effect: return str(def.id)
	return ""

func damage_effect(id: String, effect: String, amount: float, why: String = "", preferred: String = "") -> void:
	var node = node_of(id, effect, preferred)
	if node != "": damage(id, node, amount, why)

# --- breakdown: below 20% a node may fail on the road (3% a minute); at 0 the machine does not go.
func broken(id: String) -> String:
	return str(m.object_state(id).get("broken", ""))

func dead_node(id: String) -> String:
	for def in nodes_of(id):
		if str(def.effect) in ["power", "rig"] and condition(id, str(def.id)) <= 0.0: return str(def.id)
	return ""

# True when the machine cannot drive now (a node is dead, or it stopped on the road and waits for help).
func cannot_drive(id: String) -> bool:
	return broken(id) != "" or dead_node(id) != ""

func breakdown_step(dt: float) -> void:
	var id = m.vehicle_id()
	if broken(id) != "" or m.creative(): return
	var weak = worst(id)
	if float(weak.cond) >= BREAKDOWN_BELOW: return
	if absf(float(m.state.v)) < 0.3 and float(m.state.throttle) < 0.05: return
	var rng = RandomNumberGenerator.new()
	rng.seed = int(m.route.seed_value) * 2654435761 + int(float(m.state.stats.seconds) * 60.0)
	if rng.randf() < BREAKDOWN_PER_MINUTE * dt / 60.0:
		m.object_state(id).broken = str(weak.node)
		m.state.throttle = 0.0
		m.events.append("breakdown")
		m.message = "Поломка: %s. Машина не едет. Вызови помощь депо или чинись на станции с мастерской" % str(weak.name).to_lower()

# --- repair
func junk_repair(junk_id: String, id: String, node: String) -> float:
	# Own machine's junk (a spark plug for the petrol car) mends its own nodes +5%, common junk +2% any node, rare finds +4%.
	var def = m.casino().junk_def(junk_id)
	if def.is_empty(): return 0.0
	var kind = str(def.kind)
	if kind == "machine":
		return 0.05 if str(def.machine) == id else 0.0
	if kind == "rare": return 0.04
	return 0.02

func repair_with_bolts(id: String, node: String, junk_id: String, count: int) -> float:
	var per = junk_repair(junk_id, id, node)
	var value = condition(id, node)
	if per <= 0.0 or count <= 0 or value >= 1.0: return 0.0
	var used = mini(count, m.casino().junk_count(junk_id))
	used = mini(used, int(ceil((1.0 - value) / per - 0.0001)))
	if used <= 0: return 0.0
	m.casino().st().junk[junk_id] = m.casino().junk_count(junk_id) - used
	var gained = minf(1.0 - value, per * float(used))
	set_condition(id, node, value + gained)
	clear_broken(id)
	return gained

# Bolts that can mend this node, the cheapest in tokens per percent first (the rare finds are kept for the casino).
func bolt_order(id: String, node: String) -> Array:
	var order: Array = []
	for def in m.casino().cfg().junk:
		var per = junk_repair(str(def.id), id, node)
		if per > 0.0 and m.casino().junk_count(str(def.id)) > 0:
			order.append([per / maxf(1.0, float(def.tokens)), str(def.id), per])
	order.sort_custom(func(a, b): return a[0] > b[0])
	return order

# How much the bolts in the bag could mend this node (a fraction).
func bolts_gain(id: String, node: String) -> float:
	var gain = 0.0
	for entry in bolt_order(id, node): gain += float(entry[2]) * float(m.casino().junk_count(str(entry[1])))
	return minf(gain, 1.0 - condition(id, node))

func repair_bolts_auto(id: String, node: String) -> float:
	var total = 0.0
	for entry in bolt_order(id, node):
		if condition(id, node) >= 1.0: break
		total += repair_with_bolts(id, node, str(entry[1]), 99)
	return total

func money_price(id: String, node: String, fraction: float) -> int:
	return int(ceil(fraction * 100.0 * float(cfg().repair.coins_per_pct)))

func repair_with_money(id: String, node: String, fraction: float = 1.0) -> float:
	var value = condition(id, node)
	var want = minf(fraction, 1.0 - value)
	if want <= 0.0: return 0.0
	var price = money_price(id, node, want)
	if not m.creative():
		if int(m.state.money) < price:
			# as much as the money buys
			want = float(int(m.state.money)) / (100.0 * float(cfg().repair.coins_per_pct))
			price = money_price(id, node, want)
			if want <= 0.0: return 0.0
		m.state.money -= price
	set_condition(id, node, value + want)
	clear_broken(id)
	return want

func repair_with_kit(id: String, node: String) -> float:
	var s = m.casino().st()
	var value = condition(id, node)
	if int(s.repair_kits) <= 0 or value >= 1.0: return 0.0
	s.repair_kits = int(s.repair_kits) - 1
	var gained = minf(1.0 - value, float(cfg().repair.kit_pct))
	set_condition(id, node, value + gained)
	clear_broken(id)
	return gained

# On the line only a station with a workshop mends, and only up to 50% of the node.
func emergency_possible() -> bool:
	var index = m.station_index()
	if index < 0 or not m.stopped(): return false
	return bool(m.data.stations[index].get("workshop", false)) or str(m.data.stations[index].id) in ["A", "F"]

func emergency_repair(id: String, node: String) -> float:
	if not emergency_possible(): return 0.0
	var limit = float(cfg().repair.emergency_limit)
	var value = condition(id, node)
	if value >= limit: return 0.0
	var gained = repair_with_money(id, node, limit - value)
	return gained

# Mends every node of the train (up to the limit of the line) for money: {"gained": the sum of fractions, "price": coins}.
func emergency_all() -> Dictionary:
	var gained = 0.0
	var before = int(m.state.money)
	for id in m.body_ids():
		for def in nodes_of(id): gained += emergency_repair(id, str(def.id))
	return {"gained": gained, "price": before - int(m.state.money)}

func clear_broken(id: String) -> void:
	var object = m.object_state(id)
	if object.is_empty() or not object.has("broken"): return
	if condition(id, str(object.broken)) >= BREAKDOWN_BELOW: object.erase("broken")

# The depot patches up any node that is below the line for free, so a beginner is never stuck.
func free_touch_up() -> void:
	for id in m.body_ids():
		for def in nodes_of(id):
			if condition(id, str(def.id)) < FREE_TOUCH_UP: set_condition(id, str(def.id), FREE_TOUCH_UP)
		clear_broken(id)

# After the help of the depot the nodes of the pull (the engine, the motor, the rig) of every body are as new.
func rescue_repair() -> void:
	for id in m.body_ids():
		for def in nodes_of(id):
			if str(def.effect) in ["power", "rig"]: set_condition(id, str(def.id), 1.0)
		clear_broken(id)

# The price of a full repair of one machine in coins (for the "Состояние" window).
func full_repair_price(id: String) -> int:
	var sum = 0
	for def in nodes_of(id): sum += money_price(id, str(def.id), 1.0 - condition(id, str(def.id)))
	return sum
