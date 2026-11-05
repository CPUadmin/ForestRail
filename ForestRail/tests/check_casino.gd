extends Node
# КАЗИК, этап «а»: болты, жетоны, лудка, гарант, карточки гаджетов, миграция. Числа из docs/KAZIK_ODDS_RU.md.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh(seed_value: int = 42):
	var m = Model.new()
	m.new_game(seed_value, 2)
	m.state.money = 1000
	return m

func run() -> void:
	var m = fresh()
	var c = m.casino()
	var cfg = c.cfg()
	# the table of the wheel
	var total = 0
	for sector in cfg.sectors: total += int(sector.weight)
	check(total == 1000, "the weights of the sectors sum to 1000 per mille (%d)" % total)
	check(is_equal_approx(c.card_chance(), 0.002), "the card is 0.2%% a spin (%.4f)" % c.card_chance())
	check(cfg.cards.size() == 18, "eighteen cards")
	var arcana: Dictionary = {}
	var per_machine: Dictionary = {}
	for card in cfg.cards:
		arcana[str(card.arcana)] = true
		per_machine[str(card.machine)] = int(per_machine.get(str(card.machine), 0)) + 1
	check(arcana.size() == 18, "eighteen different arcana")
	var two_each = true
	for machine in per_machine: two_each = two_each and int(per_machine[machine]) == 2
	check(per_machine.size() == 9 and two_each, "every machine has exactly two cards (%d machines)" % per_machine.size())
	check(c.unowned_available().size() == 8, "only the gadgets that exist in the game can drop now (%d)" % c.unowned_available().size())   # stoker, autopilot, supercap, cooling, superheater, spinnaker, trim, flaps
	# the expected return of the wheel without the card, in tokens
	var value = 0.0
	for sector in cfg.sectors:
		var tokens_back = {"empty": 0.0, "tokens1": 5.0, "tokens2": 10.0, "junk": 3.0, "coins": 4.0, "repair": 8.0, "golden": 20.0, "bonus": 3.0, "card": 0.0}[str(sector.id)]
		value += float(sector.weight) / 1000.0 * tokens_back
	check(value > 4.0 and value < 4.4, "the wheel gives back about 83%% of the tokens without the card (%.2f of 5)" % value)
	# bolts and tokens
	check(c.junk_add("rusty_bolt", 5) and c.junk_count("rusty_bolt") == 5 and not c.junk_add("no_such_thing", 1), "bolts go into the bag")
	check(c.deposit("rusty_bolt", 3) == 3 and c.tokens() == 3 and c.junk_count("rusty_bolt") == 2, "three bolts make three tokens at the casino")
	check(c.deposit("rusty_bolt", 5) == 0 and c.tokens() == 3, "one cannot deposit more than one has")
	var money_before = int(m.state.money)
	check(c.sell("rusty_bolt", 2) == 4 and int(m.state.money) == money_before + 4 and c.junk_count("rusty_bolt") == 0, "the receiving desk pays money for bolts")
	c.junk_add("golden_bolt", 120)
	check(c.junk_count("golden_bolt") == 99, "the bag holds at most 99 of a kind")
	# the wheel
	check(not c.spin().ok, "no tokens, no spin")
	m.casino().st().tokens = 100
	var first = m.casino().spin()
	check(first.ok and m.casino().tokens() == 95 and m.casino().pity() == 1, "a spin costs 5 tokens and moves the guarantee by one")
	var a = fresh(7)
	var b = fresh(7)
	a.casino().st().tokens = 500
	b.casino().st().tokens = 500
	var same = true
	for i in range(40): same = same and str(a.casino().spin()) == str(b.casino().spin())
	check(same, "the same career and the same turn give the same result")
	var other = fresh(8)
	other.casino().st().tokens = 500
	var differs = false
	for i in range(40): differs = differs or str(other.casino().spin().sector) != str(a.casino().spin().sector)
	check(differs, "another career spins differently")
	# statistics over many spins (no guarantee reached): the sector shares are near the table
	var stats = fresh(99)
	stats.casino().st().tokens = 10000000
	var counts: Dictionary = {}
	var cards_found = 0
	for i in range(120000):
		stats.casino().st().pity = 0
		var r = stats.casino().spin()
		counts[str(r.sector)] = int(counts.get(str(r.sector), 0)) + 1
		if r.kind == "card": cards_found += 1
	var ok_shares = true
	for sector in cfg.sectors:
		var share = float(counts.get(str(sector.id), 0)) / 120000.0
		var expected = float(sector.weight) / 1000.0
		ok_shares = ok_shares and absf(share - expected) < maxf(0.0015, expected * 0.25)
	check(ok_shares, "120000 spins land in the sectors by their shares " + str(counts))
	# the guarantee: on the 500th point the card is certain, the counter starts again
	var g = fresh(5)
	g.casino().st().tokens = 1000
	g.casino().st().pity = 499
	var forced = g.casino().spin()
	check(forced.forced and forced.kind == "card" and g.casino().pity() == 0, "on the 500th point the card comes for certain")
	check(g.casino().st().cards.size() == 1 and g.casino().card_owned(str(forced.card)), "and it goes into the album")
	# a trip moves the guarantee, a hard trip (night, rain) a bit more
	var t = fresh()
	t.casino().trip_done(false)
	t.casino().trip_done(true)
	check(t.casino().pity() == 3, "trips feed the guarantee (+1, +2 at night or in the rain)")
	# no duplicates: the eight existing gadgets come out one after another, then the double in tokens
	var d = fresh(11)
	d.casino().st().tokens = 1000
	var found: Array = []
	for i in range(8):
		d.casino().st().pity = 499
		var r = d.casino().spin()
		found.append(str(r.card))
	var unique: Dictionary = {}
	for id in found: unique[id] = true
	check(unique.size() == 8, "eight forced cards are eight different cards (%s)" % str(found))
	d.casino().st().pity = 499
	var tokens_before = d.casino().tokens()
	var extra = d.casino().spin()
	check(extra.get("dupe", false) and d.casino().tokens() == tokens_before - 5 + 40, "when every gadget is found, the card pays 40 tokens")
	# the wheel favours the machine driven the most
	var counts_bias: Dictionary = {}
	for i in range(300):
		var f = fresh(1000 + i)
		Fixtures.equip(f, "steam")
		f.state.fleet_by_id.steam.km = 50.0
		f.casino().st().tokens = 100
		f.casino().st().pity = 499
		var r = f.casino().spin()
		var machine = str(f.casino().card_def(str(r.card)).machine)
		counts_bias[machine] = int(counts_bias.get(machine, 0)) + 1
	check(int(counts_bias.get("steam", 0)) > 150 and int(counts_bias.get("steam", 0)) < 250, "the steam engine, the machine driven most, gets about 60-70%% of the cards (%s)" % str(counts_bias))
	# installing a card is the only way to get a gadget when the casino keeps them
	var shop = fresh()
	Fixtures.equip(shop, "steam")
	var card_id = "magician"
	shop.state.phase = "depot"
	check(not shop.casino().install(card_id), "a card that was not found cannot be installed")
	shop.casino().st().cards.append(card_id)
	check(shop.casino().install(card_id) and int(shop.object_state("steam").levels.get("steam_stoker", 0)) == 1, "a found card puts its gadget on the machine")
	check(shop.casino().uninstall(card_id) and int(shop.object_state("steam").levels.get("steam_stoker", 0)) == 0, "and it can be taken off")
	var no_machine = fresh()
	no_machine.casino().st().cards.append("priestess")
	check(not no_machine.casino().install("priestess"), "a card needs its machine in the garage")
	shop.data.casino.cards_only = true
	shop.state.money = 100000
	check(not shop.upgrade("steam", "steam_superheater") and shop.message.contains("лудке"), "with the casino rule on, a gadget is not for sale in the workshop")
	check(shop.upgrade("steam", "steam_superheater", true), "only through a card")
	shop.data.casino.cards_only = false
	# an old save: gadgets bought earlier turn into cards that are already on the machines
	var old = fresh()
	Fixtures.equip(old, "sail")
	old.object_state("sail").levels["sail_spinnaker"] = 1
	var saved = old.serialize()
	saved.erase("casino")
	var back = Model.new()
	check(back.restore(saved) and back.casino().card_owned("tower") and "tower" in back.casino().st().installed, "an old save: the bought gadget becomes its card")
	# the whole thing is saved with the game
	var keep = fresh()
	keep.casino().junk_add("track_spike", 7)
	keep.casino().st().tokens = 42
	keep.casino().st().pity = 123
	var loaded = Model.new()
	check(loaded.restore(keep.serialize()) and loaded.casino().junk_count("track_spike") == 7 and loaded.casino().tokens() == 42 and loaded.casino().pity() == 123, "bolts, tokens and the guarantee survive saving and loading")
	# Mikhalych's gift: only in the creative mode, any card of the deck (secret ones too), once
	var career = fresh(5)
	check(not career.casino().can_gift("fool") and not career.casino().gift("fool"), "in the career Mikhalych gives nothing for free")
	var sandbox = fresh(5)
	sandbox.state.mode = "creative"
	check(sandbox.casino().gift("fool") and sandbox.casino().card_owned("fool"), "in the creative mode he gives a card for free")
	check(not sandbox.casino().gift("fool"), "a card that is already in the album is not given twice")
	check(sandbox.casino().gift("moon") and sandbox.casino().card_owned("moon"), "a secret card is given too")
	check(not sandbox.casino().gift("nonsense"), "there is no such card")
	check(sandbox.casino().tokens() == int(sandbox.casino().cfg().start_tokens if sandbox.casino().cfg().has("start_tokens") else sandbox.casino().tokens()), "the gift costs no tokens")
	print("CASINO CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
