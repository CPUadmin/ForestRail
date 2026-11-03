extends Node
# B4.4: the deadlines and the bonuses of the orders. Early pays extra, on time is 100%, late costs a fine and the
# free order burns; a story order is only cancelled (nothing paid, no progress, to be done again).
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
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	m.state.money = 5000
	return m

# Accepts a mission, loads everything, leaves, and comes back after `fraction` of the time budget.
func run_order(m, mission: Dictionary, fraction: float, night: bool = false) -> Dictionary:
	check(m.accept_mission(mission), "the order is accepted (%s)" % m.message)
	for i in range(mini(m.state.cargo.size(), m.slots().size())): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	if night: m.state.stats.seconds = 18.0 * 60.0
	check(m.depart(), "the train leaves")
	var budget = float(m.state.active.budget_s)
	check(budget > 60.0 and float(m.state.active.t_start) >= 0.0, "the order has a time budget (%.0f s) and the clock is running" % budget)
	for item in m.state.cargo: item.delivered = true
	m.evaluate_delivery()
	m.state.stats.seconds = float(m.state.stats.seconds) + budget * fraction
	m.state.s = float(m.route.station_s[0])
	m.state.v = 0.0
	m.state.brake = 1.0
	m.state.active.pending_reward = int(m.state.active.reward)
	var money_before = int(m.state.money)
	var reward_listed = int(m.state.active.reward)
	check(m.settle(), "the order is settled")
	return {"paid": int(m.state.money) - money_before, "listed": reward_listed, "m": m}

func free_mission(m) -> Dictionary:
	return m.free_offers()[0]

func run() -> void:
	Model.order_rules = true
	# early: +25% under 75% of the time
	var a = fresh()
	var early = run_order(a, free_mission(a), 0.6)
	check(early.paid == roundi(float(early.listed) * 1.25), "early under 75%% of the time pays +25%% (%d of %d)" % [early.paid, early.listed])
	var b = fresh()
	var mid = run_order(b, free_mission(b), 0.85)
	check(mid.paid == roundi(float(mid.listed) * 1.10), "a bit early pays +10%% (%d of %d)" % [mid.paid, mid.listed])
	var c = fresh()
	var on_time = run_order(c, free_mission(c), 1.0)
	check(on_time.paid == on_time.listed, "on time is 100%% (%d of %d)" % [on_time.paid, on_time.listed])
	# late: a free order burns with a fine
	var d = fresh()
	var late = run_order(d, free_mission(d), 1.3)
	check(late.paid < 0 and late.paid == -roundi(0.25 * float(late.listed)), "a late free order costs the fine (%d)" % late.paid)
	check(d.state.last_result.late and d.state.active.is_empty(), "and it is gone")
	# late: a story order is cancelled, nothing is paid, there is no progress and it can be taken again
	var e = fresh()
	var story = e.current_mission()
	var chapter = int(e.state.chapter)
	var cancelled = run_order(e, story, 1.4)
	check(cancelled.paid == 0 and int(e.state.chapter) == chapter and not (str(story.id) in e.state.paid_ids) and not (str(story.id) in e.state.completed_ids), "a late story order is only cancelled: no pay, no progress")
	check(e.accept_mission(e.current_mission()), "and it can be taken again")
	# the night and the heavy load
	var f = fresh()
	var night = run_order(f, free_mission(f), 1.0, true)
	check(night.paid == roundi(float(night.listed) * 1.30), "a night run pays +30%% (%d of %d)" % [night.paid, night.listed])
	check(is_equal_approx(f.cargo_bonus([{"type": "logs"}, {"type": "logs"}, {"type": "logs"}]), 0.1) and is_equal_approx(f.cargo_bonus([{"type": "logs"}, {"type": "logs"}, {"type": "logs"}, {"type": "logs"}, {"type": "logs"}, {"type": "logs"}]), 0.3), "heavy cargo +10%% from 300 kg, +20%% from 600 kg, five places +10%%")
	# the creative mode and the tests have no deadlines
	var g = Model.new()
	g.new_game(42, 2, "creative")
	g.state.money = 1000000
	check(g.accept_mission(g.free_offers()[0]) and not g.state.active.has("budget_s"), "the creative mode has no deadlines")
	Model.order_rules = false
	var h = fresh()
	check(h.accept_mission(free_mission(h)) and not h.state.active.has("budget_s"), "with the rules off an order has no deadline")
	print("DEADLINE CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
