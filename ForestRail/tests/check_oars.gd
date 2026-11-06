extends Node
# В6.9: вёсла парусной на штиле (scripts/oars.gd и model.set_oars): гребок даёт ход, возврат не даёт, потолок около 6 км/ч, усталость, парус с вёслами молчит,
# ветер возвращает к парусу, вёсла только у парусной.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Oars = preload("res://scripts/oars.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

class FixedWind extends RefCounted:
	var station_s: Array = []
	var vector = Vector2.ZERO
	func _init(a: float, c: float, stations: Array) -> void:
		vector = Vector2(a, c)
		station_s = stations.duplicate()
	func at(_s: float, _t: float) -> Vector2: return vector
	func gust_ahead(_s: float, _t: float, _within: float = 4.0) -> float: return -1.0

# a stretch of the line without a grade, so that a standing car stays where it is
func flat_s(m) -> float:
	var best = 600.0
	var best_grade = 1.0
	var s = 300.0
	while s < 3000.0:
		var grade = absf(m.route.slope(s)) + absf(m.route.slope(s + 40.0)) + absf(m.route.slope(s - 40.0))
		if grade < best_grade:
			best_grade = grade
			best = s
		s += 10.0
	return best

func sail_game(along: float = 0.0):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	Fixtures.equip(m, "sail")
	m.state.phase = "route"
	m.state.s = flat_s(m)
	m.state.v = 0.0
	m.state.brake = 0.0
	m.object_state("sail").levels.sail_oars = 1   # the oars are bought in the workshop (cheap)
	m.wind.build(42, m.route.station_s)
	m.wind = FixedWind.new(along, 0.0, m.route.station_s)
	return m

# a rower: the hand pulls 1 m/s for the half of the time and returns in the air for the other half
func row(m, seconds: float, hand_speed: float = 1.0) -> void:
	for i in range(int(seconds * 60.0)):
		var phase = (i / 36) % 2
		m.oars_hand(hand_speed / 60.0 if phase == 0 else -hand_speed / 60.0)
		m.physics_step(1.0 / 60.0)

func run() -> void:
	# the pure model
	var o = Oars.new()
	check(o.force(0.0) == 0.0, "no stroke, no thrust")
	for i in range(60):
		o.hand(1.2 / 60.0)
		o.step(1.0 / 60.0)
	check(o.force(0.0) > 100.0, "a steady stroke gives thrust (%.0f N)" % o.force(0.0))
	check(o.force(1.67) < 1.0 and o.force(0.8) < o.force(0.0), "and less with the speed, none at the top speed")
	var returned = Oars.new()
	for i in range(60):
		returned.hand(-1.2 / 60.0)
		returned.step(1.0 / 60.0)
	check(returned.force(0.0) == 0.0, "the return of the oar in the air gives nothing")
	var tired = Oars.new()
	for i in range(60 * 60):
		tired.hand(1.2 / 60.0)
		tired.step(1.0 / 60.0)
	check(tired.fatigue > 0.8 and tired.force(0.0) < o.force(0.0) * 0.6, "a minute of hard rowing tires the rower (fatigue %.2f)" % tired.fatigue)
	for i in range(60 * 60):
		tired.step(1.0 / 60.0)
	check(tired.fatigue < 0.3, "a rest brings the strength back (%.2f)" % tired.fatigue)
	# in the game: a calm, the car stands, with the oars it goes slowly
	var m = sail_game()
	for i in range(600): m.physics_step(1.0 / 60.0)
	check(absf(float(m.state.v)) < 0.05, "in a calm the car stands")
	check(m.set_oars(true) and m.oars_out(), "the oars are taken")
	var start_s = float(m.state.s)
	row(m, 30.0)
	var distance = float(m.state.s) - start_s
	check(distance > 15.0, "thirty seconds of rowing carry it %.0f m" % distance)
	check(float(m.state.v) * 3.6 < 6.5, "never faster than about 6 km/h (%.1f)" % (float(m.state.v) * 3.6))
	var idle = sail_game()
	idle.set_oars(true)
	for i in range(600): idle.physics_step(1.0 / 60.0)
	check(absf(float(idle.state.v)) < 0.05, "with the oars in the hands and no stroke it stands")
	# the sail is stowed while the oars are out: a good wind gives no pull until the oars are put away
	var windy = sail_game(8.0)
	windy.set_sail_trim(0.7)
	windy.sail_held = true
	check(windy.sail_engaged(), "with the hand on the sheet the sail is engaged")
	windy.set_oars(true)
	windy.sail_trim = windy.sail_best_trim(0.0)
	check(not windy.sail_engaged(), "taking the oars stows the sail")
	for i in range(120): windy.physics_step(1.0 / 60.0)
	check(not windy.oars_out(), "a strong wind puts the oars away by itself")
	check(not windy.sail_engaged() and "Ветер вернулся" in windy.message, "and the car is told so")
	# without the upgrade there are no oars; the upgrade is cheap
	var bare = sail_game()
	bare.object_state("sail").levels.erase("sail_oars")
	check(not bare.oars_owned() and not bare.set_oars(true) and "мастерской" in bare.message, "the oars must be bought first (%s)" % bare.message)
	var shop = Model.new()
	shop.new_game(42, 2)
	shop.state.money = 1000
	Fixtures.equip(shop, "sail")
	shop.state.money = 1000
	var before_money = int(shop.state.money)
	check(shop.upgrade("sail", "sail_oars") and before_money - int(shop.state.money) <= 150 and shop.oars_owned(), "the oars are a cheap upgrade of the workshop (%d coins)" % (before_money - int(shop.state.money)))
	# the other machines have no oars
	var hand = Model.new()
	hand.new_game(42, 2)
	check(not hand.set_oars(true) and not hand.oars_out(), "only the sail car has oars")
	# no oars at speed
	var fast = sail_game(8.0)
	fast.state.v = 6.0
	check(not fast.set_oars(true), "the oars cannot be taken at speed")
	print("OARS CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
