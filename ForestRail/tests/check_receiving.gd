extends Node
# Веха 6, В6.11 этап «в»: приёмка болтов (продажа за монеты в депо и на станциях A и F) и оплата половины цены
# улучшения болтами (docs/KAZIK_ECONOMY_RU.md, раздел 2).
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	Model.legacy_tanks = true
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh():
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 1000
	return m

func run() -> void:
	var m = fresh()
	var c = m.casino()
	check(c.bag().is_empty() and c.bolt_total() == 0, "the bag is empty at the start")
	c.junk_add("rusty_bolt", 10)
	c.junk_add("track_spike", 4)
	c.junk_add("golden_bolt", 1)
	check(c.bolt_total() == 15 and c.bag().size() == 3, "the bag lists the kinds with their counts (%d)" % c.bolt_total())
	check(str(c.bag()[0].id) == "rusty_bolt" and int(c.bag()[0].coins) == 2, "in the order of the table, with the price")
	# --- the desk works in the depot, and at A and F with the train at the platform
	check(m.state.phase == "depot" and c.receiving_possible(), "the desk works in the depot")
	var money = int(m.state.money)
	check(c.sell_here("rusty_bolt", 3) == 6 and int(m.state.money) == money + 6 and c.junk_count("rusty_bolt") == 7, "three rusty bolts are 6 coins")
	check(c.sell_here("rusty_bolt", 99) == 0 and c.junk_count("rusty_bolt") == 7, "more than there is: nothing sold")
	check(c.sell_here("nothing", 1) == 0, "an unknown kind: nothing sold")
	Fixtures.equip(m, "motorcar")
	m.state.phase = "route"
	m.state.direction = 1
	m.state.reverser = 1
	m.state.s = m.service_stop(1)
	m.state.v = 0.0
	m.state.brake = 1.0
	check(not c.receiving_possible() and c.sell_here("rusty_bolt", 1) == 0 and m.message.begins_with("Приёмка болтов работает"), "no desk at the way station B")
	m.state.s = m.service_stop(5)
	m.update_station_dwell(0.3)
	check(c.receiving_possible(), "there is one at the far station F")
	m.state.v = 5.0
	check(not c.receiving_possible(), "but not while the train is moving")
	m.state.v = 0.0
	m.update_station_dwell(0.3)
	var before = int(m.state.money)
	check(c.sell_common_here() == 7 * 2 + 4 * 4 and int(m.state.money) == before + 30, "'sell all the common' pays for every kind (%d)" % (int(m.state.money) - before))
	check(c.junk_count("golden_bolt") == 1 and c.junk_count("rusty_bolt") == 0, "the rare find stays in the bag")
	check(c.sell_here("golden_bolt", 1) == 40, "a rare find can still be sold one by one (40 coins)")
	# --- the plan of paying with bolts: the cheapest in tokens first, the rare never, at most a half of the price
	var p = fresh()
	var pc = p.casino()
	pc.junk_add("rusty_bolt", 2)
	pc.junk_add("track_spike", 5)
	pc.junk_add("brake_shoe", 3)
	pc.junk_add("golden_bolt", 2)
	var plan = pc.bolt_plan(60)
	check(int(plan.count) == 10 and int(plan.coins) == 30, "a price of 60 takes at most 10 bolts for 30 coins (%d bolts)" % int(plan.count))
	check(plan.bolts[0][0] == "rusty_bolt" and plan.bolts[1][0] == "track_spike" and plan.bolts[2][0] == "brake_shoe", "the cheapest in tokens go first")
	var used_rare = false
	for pair in plan.bolts: used_rare = used_rare or pair[0] == "golden_bolt"
	check(not used_rare, "the golden bolts are never spent")
	check(int(pc.bolt_plan(20).count) == 3 and int(pc.bolt_plan(20).coins) == 9, "a price of 20: three bolts, 9 coins (under the half of 10)")
	check(int(pc.bolt_plan(2).count) == 0, "a tiny price takes none")
	check(int(fresh().casino().bolt_plan(100).count) == 0, "an empty bag pays nothing")
	# --- an upgrade paid with bolts
	var u = fresh()
	u.state.money = 100
	var uc = u.casino()
	uc.junk_add("rusty_bolt", 30)
	var cost = int(u.data.upgrade_catalog[0].level_costs[0])   # handcar_lever, 35
	var branch = str(u.data.upgrade_catalog[0].id)
	var bolts_plan = uc.bolt_plan(cost)
	check(int(bolts_plan.count) == int(floor(float(cost) * 0.5 / 3.0)), "the plan of the first upgrade (%d bolts of %d coins)" % [int(bolts_plan.count), cost])
	check(u.upgrade("handcar", branch, false, true), "the upgrade is bought with bolts (%s)" % u.message)
	check(int(u.state.money) == 100 - (cost - int(bolts_plan.coins)) and uc.junk_count("rusty_bolt") == 30 - int(bolts_plan.count), "less money and fewer bolts: %d coins, %d bolts" % [int(u.state.money), uc.junk_count("rusty_bolt")])
	check(int(u.object_state("handcar").levels.get(branch, 0)) == 1, "and the level is up")
	# not enough money for the other half
	var poor = fresh()
	poor.state.money = 5
	poor.casino().junk_add("rusty_bolt", 30)
	check(not poor.upgrade("handcar", branch, false, true) and poor.message.begins_with("Не хватает") and poor.casino().junk_count("rusty_bolt") == 30, "no money for the other half: nothing is spent")
	# no bolts: refused
	var none = fresh()
	check(not none.upgrade("handcar", branch, false, true) and none.message.begins_with("В мешке нет болтов"), "an empty bag cannot pay")
	# the plain way stays as it was
	var plain = fresh()
	check(plain.upgrade("handcar", branch) and int(plain.state.money) == 1000 - cost, "the old way with coins only is unchanged")
	# gadgets are not paid with bolts
	var g = fresh()
	var gadget_branch = ""
	for b in g.data.upgrade_catalog:
		if b.get("gadget", false):
			gadget_branch = str(b.id)
			g.state.money = 100000
			g.casino().junk_add("rusty_bolt", 99)
			var target = str(b.target_type)
			if target != "wagon": Fixtures.equip(g, target)
			g.state.phase = "depot"
			g.state.brake = 1.0
			g.state.v = 0.0
			check(not g.upgrade(target if target != "wagon" else "W01", gadget_branch, false, true) and g.message.begins_with("Гаджеты болтами"), "a gadget cannot be paid with bolts (%s)" % g.message)
			break
	check(gadget_branch != "", "there is a gadget in the catalog to check")
	# saving: the bag stays
	var keep = fresh()
	keep.casino().junk_add("fishplate", 3)
	var loaded = Model.new()
	check(loaded.restore(keep.serialize()) and loaded.casino().junk_count("fishplate") == 3, "the bag is saved with the game")
	print("RECEIVING CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
