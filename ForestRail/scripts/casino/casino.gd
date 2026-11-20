extends RefCounted
# КАЗИК и «лудка» (docs/KAZIK_RU.md, KAZIK_ECONOMY_RU.md, KAZIK_ODDS_RU.md): болты, жетоны, колесо, гарант,
# карточки гаджетов. Логика без экрана; состояние лежит в state.casino и сохраняется вместе с игрой.
# Гаджеты выбиваются только здесь: карточка выпадает из лудки, потом её ставят на машину.

var m   # the model

func _init(model) -> void:
	m = model

func cfg() -> Dictionary:
	return m.data.casino

# The casino part of the save, made on first use (old saves have none).
func st() -> Dictionary:
	if not m.state.has("casino"):
		m.state.casino = {"tokens": 0, "junk": {}, "pity": 0, "cards": [], "installed": [], "spins": 0, "streak": 0, "bonuses": [], "repair_kits": 0}
	return m.state.casino

# ---- bolts (junk) and tokens

func junk_def(id: String) -> Dictionary:
	for item in cfg().junk:
		if str(item.id) == id: return item
	return {}

func junk_count(id: String) -> int:
	return int(st().junk.get(id, 0))

func junk_add(id: String, count: int = 1) -> bool:
	if junk_def(id).is_empty() or count <= 0: return false
	st().junk[id] = mini(99, junk_count(id) + count)
	return true

# Sell bolts at the receiving desk for money (the safe way, pays little).
func sell(id: String, count: int) -> int:
	var def = junk_def(id)
	if def.is_empty() or count <= 0 or junk_count(id) < count: return 0
	st().junk[id] = junk_count(id) - count
	var coins = int(def.coins) * count
	m.state.money += coins
	return coins

# Deposit bolts at the casino for tokens ("деп").
func deposit(id: String, count: int) -> int:
	var def = junk_def(id)
	if def.is_empty() or count <= 0 or junk_count(id) < count: return 0
	st().junk[id] = junk_count(id) - count
	var tokens = int(def.tokens) * count
	st().tokens = int(st().tokens) + tokens
	return tokens

func tokens() -> int:
	return int(st().tokens)

# ---- the receiving desk (B6.11 stage c): bolts for coins at the depot and at the stations A and F, and a half of the
# price of a workshop upgrade paid with bolts (1 bolt = 3 coins, never more than the half; the rare finds are kept out)

# What is in the bag: [{id, name, count, coins, tokens, kind}] in the order of the table.
func bag() -> Array:
	var result: Array = []
	for def in cfg().junk:
		var count = junk_count(str(def.id))
		if count > 0: result.append({"id": str(def.id), "name": str(def.name), "count": count, "coins": int(def.coins), "tokens": int(def.tokens), "kind": str(def.kind)})
	return result

func bolt_total() -> int:
	var sum = 0
	for entry in bag(): sum += int(entry.count)
	return sum

# The desk works in the depot and at the stations with a receiving point, with the train standing at the platform.
func receiving_possible() -> bool:
	if m.state.phase == "depot": return true
	if m.state.phase != "route": return false
	var interaction = m.station_interaction()
	return bool(interaction.can_transfer) and str(interaction.station_id) in cfg().receiving_stations

func receiving_why() -> String:
	return "" if receiving_possible() else "Приёмка болтов работает в депо и на станциях Лесная и Дальний бор: остановись у платформы"

# Sells here: the same as sell(), but only where the desk is. Returns the coins.
func sell_here(id: String, count: int) -> int:
	if not receiving_possible():
		m.message = receiving_why()
		return 0
	return sell(id, count)

# Everything of the common kinds (track and machine junk) in one go; the rare finds stay. Returns the coins.
func sell_common_here() -> int:
	if not receiving_possible():
		m.message = receiving_why()
		return 0
	var sum = 0
	for entry in bag():
		if str(entry.kind) != "rare": sum += sell(str(entry.id), int(entry.count))
	return sum

# How the bolts of the bag would pay a part of a price: {"bolts": [[id, count]], "count": n, "coins": coins saved}.
# The cheapest in tokens go first and the rare finds never; at most the share of the price (a half).
func bolt_plan(cost: int) -> Dictionary:
	var rate = int(cfg().bolt_rate)
	var room = int(floor(float(cost) * float(cfg().bolt_share) / float(rate) + 0.0001))
	var order: Array = []
	for entry in bag():
		if str(entry.kind) != "rare": order.append(entry)
	order.sort_custom(func(a, b): return int(a.tokens) < int(b.tokens))
	var plan: Array = []
	var used = 0
	for entry in order:
		if used >= room: break
		var take = mini(int(entry.count), room - used)
		plan.append([str(entry.id), take])
		used += take
	return {"bolts": plan, "count": used, "coins": used * rate}

func pay_bolts(plan: Dictionary) -> void:
	for pair in plan.bolts:
		st().junk[str(pair[0])] = junk_count(str(pair[0])) - int(pair[1])

# ---- the cards

func card_def(id: String) -> Dictionary:
	for card in cfg().cards:
		if str(card.id) == id: return card
	return {}

# A card can drop only when its gadget really exists in the game (the others come with later updates).
func card_available(card: Dictionary) -> bool:
	if str(card.machine) in m.HIDDEN_VEHICLE_IDS: return false   # the machine is not in the game yet
	for branch in m.data.upgrade_catalog:
		if str(branch.id) == str(card.upgrade): return true
	return false

func card_owned(id: String) -> bool:
	return id in st().cards

func card_for_upgrade(upgrade_id: String) -> Dictionary:
	for card in cfg().cards:
		if str(card.upgrade) == upgrade_id: return card
	return {}

func unowned_available() -> Array:
	var result: Array = []
	for card in cfg().cards:
		if card_available(card) and not card_owned(str(card.id)): result.append(card)
	return result

# The machine the player has driven the most (the wheel favours its gadgets).
func favourite_machine() -> String:
	var best = ""
	var best_km = -1.0
	for id in m.state.fleet_by_id:
		var km = float(m.state.fleet_by_id[id].get("km", 0.0))
		if km > best_km:
			best_km = km
			best = str(id)
	return best

# ---- the wheel

# Where the sector of a given kind is, by weights (per mille).
func card_chance() -> float:
	var base = 0.0
	for sector in cfg().sectors:
		if str(sector.kind) == "card": base = float(sector.weight) / 1000.0
	return base + minf(float(st().streak) * float(cfg().streak_step), float(cfg().streak_cap))

func pity() -> int:
	return int(st().pity)

# A trip is done: the guarantee grows with the road (and a little more in the night or the rain).
func trip_done(hard_conditions: bool) -> void:
	st().pity = int(st().pity) + int(cfg().pity_per_trip) + (int(cfg().pity_per_trip_hard) if hard_conditions else 0)

# One turn of the wheel. The same career and the same number of the turn always give the same result.
func spin() -> Dictionary:
	var cost = int(cfg().spin_cost)
	if tokens() < cost: return {"ok": false, "why": "not enough tokens"}
	var s = st()
	s.tokens = int(s.tokens) - cost
	s.spins = int(s.spins) + 1
	s.pity = int(s.pity) + int(cfg().pity_per_spin)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(m.route.seed_value) * 1000003 + int(s.spins) * 7919
	var forced = int(s.pity) >= int(cfg().pity_max)
	var kind = ""
	var sector_id = ""
	if forced or rng.randf() < card_chance():
		kind = "card"
		sector_id = "card"
	else:
		# the other sectors by their weights (the card sector is not among them)
		var total = 0
		for sector in cfg().sectors:
			if str(sector.kind) != "card": total += int(sector.weight)
		var x = rng.randi_range(0, total - 1)
		var acc = 0
		for sector in cfg().sectors:
			if str(sector.kind) == "card": continue
			acc += int(sector.weight)
			if x < acc:
				kind = str(sector.kind)
				sector_id = str(sector.id)
				break
	var result = {"ok": true, "sector": sector_id, "kind": kind, "forced": forced, "spin": int(s.spins)}
	var sector_def = {}
	for sector in cfg().sectors:
		if str(sector.id) == sector_id: sector_def = sector
	match kind:
		"tokens":
			s.tokens = int(s.tokens) + int(sector_def.tokens)
			result.tokens = int(sector_def.tokens)
		"junk":
			var commons: Array = []
			for item in cfg().junk:
				if str(item.kind) == "track": commons.append(str(item.id))
			var gained: Array = []
			for i in range(rng.randi_range(2, 4)):
				var pick = commons[rng.randi_range(0, commons.size() - 1)]
				junk_add(pick, 1)
				gained.append(pick)
			result.junk = gained
		"coins":
			var coins = rng.randi_range(int(cfg().coin_min), int(cfg().coin_max))
			m.state.money += coins
			result.coins = coins
		"repair":
			s.repair_kits = int(s.repair_kits) + 1
		"golden":
			junk_add("golden_bolt", 1)
		"bonus":
			var kinds = ["spin", "x2", "junk", "tea"]
			var bonus = kinds[rng.randi_range(0, kinds.size() - 1)]
			s.bonuses.append(bonus)
			result.bonus = bonus
		"card":
			var pool = unowned_available()
			if pool.is_empty():
				# every gadget of the game is already found: the croupier pays the double in tokens
				s.tokens = int(s.tokens) + int(cfg().dupe_tokens)
				result.dupe = true
				result.tokens = int(cfg().dupe_tokens)
			else:
				var favourite = favourite_machine()
				var preferred: Array = []
				for card in pool:
					if str(card.machine) == favourite: preferred.append(card)
				var chosen = pool[rng.randi_range(0, pool.size() - 1)]
				if not preferred.is_empty() and rng.randf() < float(cfg().card_bias): chosen = preferred[rng.randi_range(0, preferred.size() - 1)]
				s.cards.append(str(chosen.id))
				result.card = str(chosen.id)
			s.pity = 0
	return result

# ---- Mikhalych's gift (the owner's request, 05.11.2026): in the creative mode he gives any card of the deck for free, no tokens, no wheel.
# The career is not touched: the card of a career comes only from the wheel. A card whose gadget is not in the game yet is given too
# (it lies in the album), it can be put on the machine when the gadget appears.
const SECRET_IDS = ["moon", "sun", "judgement", "world"]

func card_ids() -> Array:
	var ids: Array = []
	for card in cfg().cards: ids.append(str(card.id))
	return ids + SECRET_IDS

func can_gift(card_id: String) -> bool:
	return m.creative() and card_id in card_ids() and not card_owned(card_id)

func gift(card_id: String) -> bool:
	if not can_gift(card_id): return false
	st().cards.append(card_id)
	return true

# ---- putting a card on the machine (the only way to get a gadget)

func install(card_id: String) -> bool:
	if not m.depot_editable(): return false
	var card = card_def(card_id)
	if card.is_empty() or not card_owned(card_id) or not card_available(card): return false
	var machine = str(card.machine)
	if not m.state.fleet_by_id.has(machine): return false
	if int(m.object_state(machine).levels.get(str(card.upgrade), 0)) > 0: return false
	m.object_state(machine).levels[str(card.upgrade)] = 1
	if not card_id in st().installed: st().installed.append(card_id)
	return true

func uninstall(card_id: String) -> bool:
	if not m.depot_editable(): return false
	var card = card_def(card_id)
	if card.is_empty() or not card_id in st().installed: return false
	var machine = str(card.machine)
	if m.state.fleet_by_id.has(machine): m.object_state(machine).levels.erase(str(card.upgrade))
	st().installed.erase(card_id)
	return true

# Saves from before the casino: a gadget bought earlier becomes a card that is already on the machine.
func migrate() -> void:
	for card in cfg().cards:
		var machine = str(card.machine)
		if not m.state.fleet_by_id.has(machine): continue
		if int(m.object_state(machine).levels.get(str(card.upgrade), 0)) > 0:
			if not card_owned(str(card.id)): st().cards.append(str(card.id))
			if not str(card.id) in st().installed: st().installed.append(str(card.id))

# ---- the road gives bolts (B6.11 stage b, KAZIK_ECONOMY_RU.md): the log of a trip, the drops at the end, the glints
# The log lives in state.active.trip, so it is saved with the game and dies with the order.

func src() -> Dictionary:
	return cfg().sources

func trip() -> Dictionary:
	return m.state.active.get("trip", {}) if not m.state.active.is_empty() else {}

func has_trip() -> bool:
	return not m.state.active.is_empty() and m.state.active.has("trip")

# The first departure of an order: the log starts and the glints are laid along the line (the same for the same career and order).
func trip_start() -> void:
	if m.state.active.is_empty() or m.state.active.has("trip"): return
	var cargo_kg = 0.0
	for item in m.state.cargo:
		if str(item.slot) != "": cargo_kg += float(item.get("weight_kg", 0.0))
	var rng = RandomNumberGenerator.new()
	rng.seed = int(m.route.seed_value) * 7919 + int(m.state.offer_serial) * 31 + 5
	var glints: Array = []
	var count = int(src().glint_min) + (1 if rng.randf() < float(src().glint_extra_chance) else 0)
	var margin = float(src().glint_margin_m)
	for i in range(count):
		var at = rng.randf_range(margin, maxf(margin + 1.0, float(m.route.length_m) - margin))
		glints.append({"s": snappedf(at, 0.1), "golden": rng.randf() < float(src().glint_golden_chance), "taken": false})
	m.state.active.trip = {"dist0": float(m.state.stats.distance), "steep_m": 0.0, "skids": 0, "visited": [], "damage": 0.0, "cargo_kg": cargo_kg, "glints": glints, "found": {}}

# Every step of the road: how much of it was steep, which stations the train stood at.
func trip_tick(meters: float) -> void:
	var t = trip()
	if t.is_empty(): return
	if meters > 0.0 and absf(tan(m.route.slope(float(m.state.s)))) >= float(src().steep_grade): t.steep_m = float(t.steep_m) + meters
	var index = m.station_index()
	if index >= 0 and m.stopped():
		var id = str(m.data.stations[index].id)
		if not id in t.visited: t.visited.append(id)

func trip_skid() -> void:
	var t = trip()
	if not t.is_empty(): t.skids = int(t.skids) + 1

# Damage dealt to the machine itself (heat, frost, a torn sheet, a landing) shakes its parts loose.
func trip_damage(id: String, amount: float) -> void:
	var t = trip()
	if t.is_empty() or id != m.vehicle_id(): return
	t.damage = float(t.damage) + amount

func note_found(t: Dictionary, junk_id: String, count: int = 1) -> void:
	if count <= 0 or not junk_add(junk_id, count): return
	t.found[junk_id] = int(t.found.get(junk_id, 0)) + count

# The junk of the machine that is driven (its own spare parts).
func machine_junk(vehicle: String) -> String:
	for item in cfg().junk:
		if str(item.kind) == "machine" and str(item.machine) == vehicle: return str(item.id)
	return ""

func roll(rng: RandomNumberGenerator, expected: float) -> int:
	var whole = floori(expected)
	return whole + (1 if rng.randf() < expected - float(whole) else 0)

# The end of the order (the train is home): the drops by what happened on the road. Returns [{id, name, count}] of everything
# the trip brought, the glints picked on the way included. "exact" is a trip within 5% of the time, "late" brings no premium finds.
func trip_finds(exact: bool, late: bool) -> Array:
	var t = trip()
	if t.is_empty(): return []
	var s = src()
	var rng = RandomNumberGenerator.new()
	rng.seed = int(m.route.seed_value) * 1000003 + m.state.paid_ids.size() * 7919 + int(m.state.offer_serial) * 13 + 13
	var km = maxf(0.0, float(m.state.stats.distance) - float(t.dist0)) / 1000.0
	note_found(t, "rusty_bolt", roll(rng, km * float(s.rusty_per_km)))
	note_found(t, "tie_plate", mini(int(s.tie_plate_cap), roll(rng, float(t.steep_m) * float(s.tie_plate_per_m))))
	var heavy = float(s.heavy_kg)
	if float(t.cargo_kg) >= heavy: note_found(t, "fishplate", mini(int(s.fishplate_cap), 1 + int((float(t.cargo_kg) - heavy) / heavy)))
	note_found(t, "brake_shoe", mini(int(s.skid_cap), int(t.skids)))
	var clips = 0
	for id in t.visited:
		if id in s.clip_stations: clips += 1
	note_found(t, "rail_clip", mini(int(s.clip_cap), clips))
	# the machine's own parts: by distance (the lever, the pole tip) or by what hurt it on the road
	var vehicle = m.vehicle_id()
	var own = machine_junk(vehicle)
	if own != "":
		var expected = km * float(s.per_km.get(vehicle, 0.0)) + float(t.damage) * float(s.per_damage)
		note_found(t, own, mini(int(s.machine_cap), roll(rng, expected)))
	if not late:
		if exact:
			note_found(t, "bearing_cover", 1)
			if int(st().streak) >= int(s.watch_streak): note_found(t, "stationmaster_watch", 1)
		if bool(m.state.active.get("night_start", false)) and rng.randf() < float(s.lantern_chance): note_found(t, "cracked_lantern", 1)
	var result: Array = []
	for id in t.found:
		result.append({"id": str(id), "name": str(junk_def(str(id)).get("name", id)), "count": int(t.found[id])})
	return result

# ---- the glints by the rail: a click on one, with the train near and not racing, picks it up
func glints() -> Array:
	return trip().get("glints", [])

func glint_pickable(index: int) -> String:
	var list = glints()
	if index < 0 or index >= list.size() or bool(list[index].taken): return "Здесь уже пусто"
	if absf(float(m.state.v)) > float(src().glint_max_speed): return "Слишком быстро, чтобы нагнуться"
	var near = 1.0e9
	for i in range(m.body_ids().size()): near = minf(near, absf(m.body_s(i) - float(list[index].s)))
	if near > float(src().glint_reach_m): return "Далеко от состава"
	return ""

func pick_glint(index: int) -> String:
	var why = glint_pickable(index)
	if why != "":
		m.message = why
		return ""
	var g = glints()[index]
	g.taken = true
	var id = "golden_bolt" if bool(g.golden) else str(src().glint_spike)
	note_found(trip(), id, 1)
	m.events.append("glint")
	m.message = "Нашёл у рельса: " + str(junk_def(id).name).to_lower()
	return id
