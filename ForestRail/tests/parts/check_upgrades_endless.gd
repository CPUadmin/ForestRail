extends Node
# Owner 16.11: the simple upgrades are endless. Levels 1 and 2 keep the numbers of the data; from level 3 on a
# level adds (v2 - v1) * 0.7^(n - 2), so the gain shrinks every level and is nothing at level 100; the price
# grows by a factor every level. The discrete branches and the gadgets keep their levels; a save with level 7 loads.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/core/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func game(kind: String, mode: String = "career"):
	var m = Model.new()
	m.new_game(42, 2, mode)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, kind)
	return m

func branch(m, id: String) -> Dictionary:
	for b in m.data.upgrade_catalog:
		if b.id == id: return b
	return {}

func run() -> void:
	var m = game("motorcar")
	var q = m.endless_decay()
	check(is_equal_approx(q, 0.7), "the decay is one named number in the data (%s)" % q)
	var endless = 0
	for b in m.data.upgrade_catalog:
		if not m.branch_endless(b): continue
		endless += 1
		check(not b.get("gadget", false), "%s: a gadget is never endless" % b.id)
		check(not b.effects_at_level.has("add_slots"), "%s: a branch of places is never endless" % b.id)
		# levels 1 and 2 are the numbers of the data; the prices of levels 1 and 2 too
		for key in b.effects_at_level:
			var v = b.effects_at_level[key]
			check(is_equal_approx(float(m.level_value(b, key, 1)), float(v[0])) and is_equal_approx(float(m.level_value(b, key, 2)), float(v[1])), "%s.%s: levels 1 and 2 as today" % [b.id, key])
			var d = float(v[1]) - float(v[0])
			var rule = true
			var shrinks = true
			var previous_gain = absf(d)
			for n in range(3, 101):
				var gain = float(m.level_value(b, key, n)) - float(m.level_value(b, key, n - 1))
				rule = rule and absf(gain - d * pow(q, n - 2)) < 1e-9 * maxf(1.0, absf(d))
				if n <= 60: shrinks = shrinks and absf(gain) < previous_gain   # past that the gain is below the float precision
				previous_gain = absf(gain)
			check(rule, "%s.%s: level n adds d * 0.7^(n-2)" % [b.id, key])
			check(shrinks, "%s.%s: the gain shrinks every level" % [b.id, key])
			var at_100 = float(m.level_value(b, key, 100))
			var gain_100 = absf(at_100 - float(m.level_value(b, key, 99))) / absf(at_100)
			check(gain_100 < 0.0001, "%s.%s: level 100 adds below 0.01%% (%s)" % [b.id, key, gain_100])
			check(at_100 > 0.0, "%s.%s: a multiplier stays above zero (%s)" % [b.id, key, at_100])
		check(m.level_cost(b, 0) == int(b.level_costs[0]) and m.level_cost(b, 1) == int(b.level_costs[1]), "%s: the prices of levels 1 and 2 as today" % b.id)
		var g = clampf(float(b.level_costs[1]) / float(b.level_costs[0]), 1.6, 2.2)
		var grows = true
		for lv in range(2, 30):
			var price = m.level_cost(b, lv)
			var exact = float(b.level_costs[1]) * pow(g, lv - 1)
			grows = grows and price > m.level_cost(b, lv - 1) and absf(price - exact) <= 50.0 + exact * 1e-9
		check(grows, "%s: the price grows every level by the factor %.2f" % [b.id, g])
	check(endless >= 30, "the simple branches are endless (%d)" % endless)
	# the engine of the petrol car: buy levels 3..5 and pay the rule's prices
	var engine = branch(m, "motorcar_engine")
	m.state.phase = "depot"
	var paid: Array = []
	for i in range(5):
		var money = int(m.state.money)
		check(m.upgrade("motorcar", "motorcar_engine"), "the engine buys level %d (%s)" % [i + 1, m.message])
		paid.append(money - int(m.state.money))
	check(paid == [80, 150, 280, 530, 990], "the engine prices 80, 150, 280, 530, 990 (%s)" % str(paid))
	check(is_equal_approx(float(m.effects("motorcar").traction_multiplier), 1.3 + 0.15 * (0.7 + 0.49 + 0.343)), "level 5 traction by the rule (%s)" % m.effects("motorcar").traction_multiplier)
	var table: Array = []
	for lv in [1, 2, 3, 5, 10, 25, 100]: table.append("%d: %d coins, x%.4f" % [lv, m.level_cost(engine, lv - 1), float(m.level_value(engine, "traction_multiplier", lv))])
	print("ENGINE TABLE ", " | ".join(table))
	# the gearbox: level 3 opens nothing new, its multipliers keep growing
	var box = game("motorcar")
	box.object_state("motorcar").levels["motorcar_gearbox"] = 3
	check(box.gears_open() == 5, "the gearbox level 3 keeps five gears")
	check(float(box.effects("motorcar").low_gear_multiplier) > 1.2, "the gearbox level 3 pulls more on the low gears")
	# a discrete branch and a gadget stay capped
	var wagon = game("motorcar")
	wagon.state.phase = "depot"
	var w = wagon.state.wagons_by_id.keys()[0] if not wagon.state.wagons_by_id.is_empty() else ""
	if w == "":
		wagon.state.wagons_by_id["W01"] = {"levels": {}}
		w = "W01"
	check(wagon.upgrade(w, "wagon_platform") and wagon.upgrade(w, "wagon_platform") and not wagon.upgrade(w, "wagon_platform"), "the wagon platform keeps two levels (%s)" % wagon.message)
	var free = game("motorcar", "creative")
	free.state.phase = "depot"
	check(free.upgrade("motorcar", "motorcar_nitro") and not free.upgrade("motorcar", "motorcar_nitro") and free.message == "Уже установлено", "a gadget stays one level, even in the creative mode (%s)" % free.message)
	# creative: the endless branches go on there too
	var bought = true
	for i in range(4): bought = bought and free.upgrade("motorcar", "motorcar_brakes")
	check(bought and int(free.object_state("motorcar").levels.motorcar_brakes) == 4, "creative: the brakes reach level 4 (%s)" % free.message)
	# a save with level 7 loads (through JSON, as on the disk); a level 3 of a discrete branch does not
	var saved = game("motorcar")
	saved.object_state("motorcar").levels["motorcar_engine"] = 7
	var text = JSON.stringify(saved.serialize())
	var loaded = Model.new()
	check(loaded.restore(JSON.parse_string(text)) and int(loaded.object_state("motorcar").levels.motorcar_engine) == 7, "a save with the engine at level 7 loads")
	check(is_equal_approx(float(loaded.effects("motorcar").traction_multiplier), float(saved.effects("motorcar").traction_multiplier)), "and gives the same traction")
	var bad = JSON.parse_string(text)
	bad.fleet_by_id.motorcar.levels["motorcar_nitro"] = 3
	check(not Model.new().restore(bad), "a gadget at level 3 is refused")
	var half = JSON.parse_string(text)
	half.fleet_by_id.motorcar.levels["motorcar_engine"] = 2.5
	check(not Model.new().restore(half), "a broken level is refused")
	print("ENDLESS UPGRADES CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
