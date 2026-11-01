extends Node
# B1.1: loading without the rigid chain. A train that has come to rest on a platform holds itself, the
# brake is not a condition of loading, and giving traction is the departure (no button, no brake to release).
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func steps(m, n: int) -> void:
	for i in range(n): m.physics_step(1.0 / 60.0)

# A career in the loading phase with every item placed, the machine of the given class.
func loaded(id: String) -> Object:
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 0 if id in ["handcar", "pole"] else 6
	if id != "handcar": Fixtures.equip(m, id)
	var mission = m.state.get("offers", [])
	m.accept_mission(m.current_mission())
	for i in range(mini(m.state.cargo.size(), m.slots().size())): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	return m

func run() -> void:
	# handcar: gripping the lever departs
	var m = loaded("handcar")
	check(m.state.phase == "loading" and m.all_loaded(), "the handcar is loaded and waits at the depot")
	m.state.brake = 1.0
	steps(m, 5)
	check(m.state.phase == "loading", "standing still, nothing happens")
	m.grab_pump()
	steps(m, 2)
	check(m.state.phase == "route" and float(m.state.brake) == 0.0, "gripping the lever departs and lets the brake go")
	# an unfinished loading does not depart
	var half = Model.new()
	half.new_game(42, 2)
	half.accept_mission(half.current_mission())
	check(half.state.phase == "loading" and not half.all_loaded(), "a mission with the cargo not placed is waiting")
	half.grab_pump()
	steps(half, 3)
	check(half.state.phase == "loading" and half.message != "", "without the cargo placed it does not depart and says why (%s)" % half.message)
	# motor car: throttle in gear departs, throttle in neutral does not
	var car = loaded("motorcar")
	car.state.brake = 1.0
	car.state.engine = true
	car.state.throttle = 0.4
	car.state.gear = 0
	steps(car, 3)
	check(car.state.phase == "loading", "revving in neutral does not depart")
	car.state.gear = 1
	steps(car, 3)
	check(car.state.phase == "route" and float(car.state.brake) == 0.0, "throttle in gear departs, the brake is released for the player")
	# the platform holds a train that stands in the zone, with no brake from the player
	var train = loaded("motorcar")
	train.state.phase = "route"
	train.state.active.phase = "outbound"
	var index = 1
	train.state.s = train.service_stop(index) - 4.0
	train.state.v = 2.0
	train.state.brake = 0.6
	train.state.throttle = 0.0
	train.state.engine = true
	steps(train, 60 * 8)
	check(train.auto_brake and float(train.state.brake) >= 0.95, "standing in the platform zone holds the train by itself")
	steps(train, 30)
	check(train.station_interaction().can_transfer, "loading and unloading are open without the red brake")
	check(train.stopped(), "stopped() is true, so turning and returning work")
	train.state.gear = 1
	train.state.throttle = 0.4
	steps(train, 2)
	check(float(train.state.brake) == 0.0 and not train.auto_brake, "giving traction lets the platform's hold go")
	steps(train, 120)
	check(float(train.state.v) > 0.5 and not train.station_interaction().can_transfer, "and the train drives away")
	# outside the zone there is no automatic hold
	var open = loaded("motorcar")
	open.state.phase = "route"
	open.state.active.phase = "outbound"
	open.state.s = float(open.route.station_s[1]) + 140.0
	open.state.v = 0.0
	open.state.brake = 0.0
	open.state.throttle = 0.0
	steps(open, 5)
	check(not open.auto_brake and float(open.state.brake) == 0.0, "away from a platform the brake stays the player's")
	# the player's own lever wins over the automatic hold
	train.state.throttle = 0.0
	train.state.s = train.service_stop(index) - 4.0
	train.state.v = 2.0
	train.state.brake = 0.6
	steps(train, 60 * 8)
	check(train.auto_brake, "held again after stopping on the platform")
	train.state.brake = 0.5
	steps(train, 2)
	check(not train.auto_brake and absf(float(train.state.brake) - 0.5) < 0.001, "taking the lever turns the automatic hold off")
	# pole truck: planting a pole in the loading phase departs
	var pole = loaded("pole")
	check(pole.state.phase == "loading", "the pole truck waits loaded")
	pole.pole.set_aim(2.0)
	pole.pole.tip = 2.0
	check(pole.pole_plant() and pole.state.phase == "route", "planting the pole departs")
	print("LOADING FLOW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
