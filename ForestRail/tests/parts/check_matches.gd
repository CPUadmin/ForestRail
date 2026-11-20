extends Node
# 1.4.14 Спичка у паровоза (модель): коробок на 10, медленно — царапает, в меру — вспыхивает, резко — ломается,
# сырая только царапает, горит ~6 с, рывок задувает, к открытой топке с углём — огонь; коробок в депо бесплатно.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/core/model.gd")
const Matches = preload("res://scripts/vehicles/steam/matches.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh(mode: String = "career"):
	Model.match_rules = true
	var m = Model.new()
	m.new_game(42, 2, mode)
	m.state.money = 100000
	Fixtures.equip(m, "steam")
	m.state.phase = "route"
	m.state.s = 100.0
	m.state.v = 0.0
	return m

# a fresh (not damp) match in hand, whatever the dice
func fresh_match(m) -> void:
	var f = m.matches()
	for i in range(40):
		f.take()
		if f.hand == "fresh": return
		f.put_back()

func coal_in(m) -> void:
	var b = m.boiler()
	b.firebox = float(m.boiler_cfg().min_fire_kg) + 2.0
	b.lit = false
	m.state.engine = false

func run() -> void:
	var m = fresh()
	var f = m.matches()
	check(f.count() == Matches.BOX, "a box of ten matches (%d)" % f.count())
	check(f.take() and f.in_hand() and f.count() == 9, "a match is taken from the box (9 left)")
	f.put_back()
	check(not f.in_hand() and f.count() == 10, "an unused match goes back into the box")
	# the stroke: slow scratches, three slow strokes rub the head off
	fresh_match(m)
	check(f.strike(0.4) == "scratch" and f.hand == "fresh" and m.message.contains("царапает"), "a slow stroke only scratches")
	f.strike(0.4)
	check(f.strike(0.4) == "rubbed" and not f.in_hand(), "the third slow stroke rubs the head off")
	# too sharp: it breaks
	fresh_match(m)
	check(f.strike(6.0) == "broken" and not f.in_hand() and m.message.contains("сломалась"), "a too sharp stroke breaks it")
	# just right: it lights and burns about six seconds
	fresh_match(m)
	check(f.strike(2.0) == "lit" and f.lit(), "a stroke in measure lights it")
	f.step(5.0)
	check(f.lit() and f.burn > 0.9, "after five seconds it still burns (%.1f s left)" % f.burn)
	f.step(1.1)
	check(f.hand == "burnt" and m.message.contains("догорела"), "after six it has burnt down")
	# a jerk blows it out; a calm hand does not
	fresh_match(m)
	f.strike(2.0)
	check(not f.jerk(1.0) and f.lit(), "a calm hand keeps the flame")
	check(f.jerk(3.5) and f.hand == "burnt" and m.message.contains("задуло"), "a jerk blows it out")
	# a damp match only scratches, whatever the speed in measure
	var damp_found = false
	for i in range(80):
		f.take()
		if f.hand == "damp":
			damp_found = true
			break
		f.put_back()
	check(damp_found, "now and then a match is damp")
	check(f.strike(2.0) == "scratch" and m.message.contains("Отсырела"), "a damp one only scratches")
	check(f.strike(6.0) == "scratch" and f.strike(0.4) == "rubbed", "a damp head scratches even on a fast stroke, and wears out on the third")
	f.drop()
	# about one in ten is damp
	var counter = fresh()
	var dampness = 0
	for i in range(400):
		counter.matches().take()
		if counter.matches().hand == "damp": dampness += 1
		counter.matches().put_back()
	check(dampness >= 20 and dampness <= 70, "about one in ten is damp (%d of 400)" % dampness)
	# to the fire: the door must be open, then the fire is lit and the match is gone
	var fire = fresh()
	coal_in(fire)
	fresh_match(fire)
	fire.matches().strike(2.0)
	fire.set_door(false)
	check(not fire.matches().to_fire() and fire.message.contains("Дверца") and fire.matches().lit(), "a closed door: the match still burns in the hand")
	fire.set_door(true)
	var water = fire.state.fleet_by_id.steam.water
	fire.state.fleet_by_id.steam.water = 0.0
	check(not fire.matches().to_fire() and fire.message.contains("воды") and fire.matches().lit() and not fire.boiler().lit, "an empty boiler refuses ignition and leaves the match lit")
	fire.state.fleet_by_id.steam.water = water
	check(fire.matches().to_fire() and bool(fire.boiler().lit) and not fire.matches().in_hand(), "to the open firebox with coal: the fire is lit")
	# no coal: the match does not light it
	var cold = fresh()
	cold.boiler().firebox = 0.0
	cold.boiler().lit = false
	fresh_match(cold)
	cold.matches().strike(2.0)
	cold.set_door(true)
	check(not cold.matches().to_fire() and not bool(cold.boiler().lit), "no coal in the firebox: no fire")
	# the box runs out; the depot gives a new one for nothing; the creative box never runs out
	var empty = fresh()
	empty.state.fleet_by_id.steam.matches = 0
	check(not empty.matches().take() and empty.message.contains("помощь депо"), "an empty box: call the help of the depot")
	empty.matches().refill()
	check(empty.matches().count() == 10, "the depot refills the box to ten")
	var cr = fresh("creative")
	cr.state.fleet_by_id.steam.matches = 0
	check(cr.matches().take() and cr.matches().count() == 0, "in the creative mode the box never runs out")
	# the help of the depot refills it too
	var rescue = fresh()
	rescue.state.fleet_by_id.steam.matches = 2
	rescue.rescue()
	check(rescue.matches().count() == 10, "after the help of the depot the box is full (%d)" % rescue.matches().count())
	# the count is saved
	var sv = fresh()
	sv.matches().take()
	var back = Model.new()
	check(back.restore(JSON.parse_string(JSON.stringify(sv.serialize()))) and back.matches().count() == 9, "the number of matches is saved")
	Model.match_rules = false
	print("MATCHES CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
