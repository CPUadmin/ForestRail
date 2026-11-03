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

# ---- the cards

func card_def(id: String) -> Dictionary:
	for card in cfg().cards:
		if str(card.id) == id: return card
	return {}

# A card can drop only when its gadget really exists in the game (the others come with later updates).
func card_available(card: Dictionary) -> bool:
	for branch in m.data.upgrade_catalog:
		if str(branch.id) == str(card.upgrade): return true
	return false

func card_owned(id: String) -> bool:
	return id in st().cards

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
func sector_weights() -> Array:
	var result: Array = []
	for sector in cfg().sectors: result.append([str(sector.id), int(sector.weight)])
	return result

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

# ---- putting a card on the machine (the only way to get a gadget)

func install(card_id: String) -> bool:
	var card = card_def(card_id)
	if card.is_empty() or not card_owned(card_id) or not card_available(card): return false
	var machine = str(card.machine)
	if not m.state.fleet_by_id.has(machine): return false
	m.object_state(machine).levels[str(card.upgrade)] = 1
	if not card_id in st().installed: st().installed.append(card_id)
	return true

func uninstall(card_id: String) -> bool:
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
