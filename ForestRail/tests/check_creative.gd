extends Node
# Creative mode: everything is open, money and fuel do not run out, any order can be taken
# again and again, nothing counts as progress; the career is untouched.
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func load_and_go(m, mission: Dictionary) -> bool:
	if not m.accept_mission(mission): return false
	var slots = m.slots()
	for i in range(mini(m.state.cargo.size(), slots.size())): m.transfer(m.state.cargo[i].id, slots[i].key)
	return m.depart()

func come_home(m, reward: int) -> void:
	m.state.phase = "route"
	m.state.s = float(m.route.station_s[0])
	m.state.v = 0.0
	m.state.brake = 1.0
	m.state.active.phase = "return"
	m.state.active.pending_reward = reward

func run() -> void:
	var m = Model.new()
	m.new_game(42, 2, "creative")
	check(m.creative() and m.state.mode == "creative", "the mode is creative")
	check(int(m.state.money) >= 1000000, "money is practically unlimited")
	for id in ["handcar", "steam", "motorcar", "pneumatic", "locomotive"]:
		check(m.state.fleet_by_id.has(id), "the garage has " + id)
	check(m.state.wagons_by_id.has("W01") and m.state.wagons_by_id.has("W02") and m.state.wagons_by_id.has("W03"), "all three wagons are owned")
	check(m.state.selected_vehicle_id == "handcar" and not bool(m.state.tutorial), "starts on the handcar without the tutorial")
	# any order, any machine, not in order, as many times as you like
	m.select_vehicle("locomotive")
	var last = m.scaled_mission(m.data.missions[9])
	check(m.refill_cost() == 0, "fuel costs nothing")
	m.state.fleet_by_id.locomotive.fuel = 0.01
	m.state.fleet_by_id.locomotive.fuel = 0.2
	check(m.refill_cost() == 0 and m.tank_missing() > 0.5, "in the creative mode the refill costs nothing, but the tank is not full (so the button must work)")
	check(m.refuel() and float(m.state.fleet_by_id.locomotive.fuel) >= float(m.object_stats("locomotive").tank) - 0.0001 and int(m.state.money) >= 1000000, "refuelling fills the tank for nothing")
	check(load_and_go(m, last), "the last career order can be taken first, with a machine of its own class")
	come_home(m, 1000)
	check(m.settle() and m.state.phase == "depot", "the trip is paid at home")
	check(m.state.paid_ids.is_empty() and m.state.completed_ids.is_empty() and int(m.state.chapter) == 0 and not bool(m.state.finale), "nothing counts as progress, not even the final order")
	check(int(m.state.money) >= 1000000, "money is topped up again")
	check(load_and_go(m, last), "the same order can be taken again")
	# a weaker machine may take a heavier order
	m.state.active = {}
	m.state.cargo = []
	m.state.phase = "depot"
	m.select_vehicle("handcar")
	check(m.accept_mission(m.scaled_mission(m.data.missions[4])), "a handcar may take an order meant for a motorcar")
	# saving keeps the mode
	m.state.active = {}
	m.state.cargo = []
	m.state.phase = "depot"
	var other = Model.new()
	check(other.restore(m.serialize()) and other.creative(), "the mode survives saving and loading")
	var bad = m.serialize()
	bad.mode = "dream"
	check(not Model.new().restore(bad), "an unknown mode is refused")
	# the career is untouched
	var career = Model.new()
	career.new_game(42, 2)
	check(not career.creative() and int(career.state.money) == 0 and career.state.fleet_by_id.size() == 1, "a new career still starts with the handcar and no money")
	check(not career.accept_mission(career.scaled_mission(career.data.missions[4])), "and orders still go in order")
	var old = Model.new()
	old.new_game(42)
	check(Model.new().restore(old.serialize()), "an old career save still loads")
	print("CREATIVE CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
