extends Node
# Кошка с лебёдкой, чистая модель (scripts/grapnel.gd): опоры на местах, бросок по дуге цепляет у верха опоры или падает, лебёдка тянет дрезину силой ≈ четверти веса,
# слабая опора (куст, пень под тяжёлым составом) вырывается, крюк снимается под опорой, назад (направление −1) тоже работает.
const Grapnel = preload("res://scripts/grapnel.gd")

var failures: Array = []
var checks = 0
var flat = func(_s): return 0.0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

# a lone anchor at the given place
func with_anchor(s_anchor: float, type: String):
	var g = Grapnel.new()
	g.anchors = [{"s": s_anchor, "type": type}]
	return g

# a truck on a flat line: returns {events, s, hooked_seconds, max_force}
func play(g, s0: float, direction: int, mass: float, seconds: float) -> Dictionary:
	var s = s0
	var v = 0.0
	var all_events: Array = []
	var max_force = 0.0
	var hooked_time = 0.0
	g.events.clear()
	for i in range(int(seconds * 60.0)):
		var f = g.step(1.0 / 60.0, s, direction, 1.2, mass, flat)
		max_force = maxf(max_force, absf(f))
		if g.mode == "hooked": hooked_time += 1.0 / 60.0
		v += f / mass / 60.0
		v = move_toward(v, 0.0, 0.4 / 60.0)   # the rolling resistance of the truck
		s += v / 60.0
		all_events.append_array(g.events)
		g.events.clear()
	return {"events": all_events, "s": s, "hooked": hooked_time, "max_force": max_force}

func run() -> void:
	# --- the anchors of a line
	var a = Grapnel.new()
	a.build(42, 6800.0, [30.0, 1400.0, 3000.0, 6700.0])
	var b = Grapnel.new()
	b.build(42, 6800.0, [30.0, 1400.0, 3000.0, 6700.0])
	check(a.anchors.size() > 100 and a.anchors.size() == b.anchors.size() and a.anchors[10].s == b.anchors[10].s and a.anchors[10].type == b.anchors[10].type, "the anchors are the same for the same seed (%d of them)" % a.anchors.size())
	var kinds: Dictionary = {}
	var sorted = true
	var near_station = false
	for i in range(a.anchors.size()):
		kinds[a.anchors[i].type] = true
		if i > 0 and float(a.anchors[i].s) <= float(a.anchors[i - 1].s): sorted = false
		if absf(float(a.anchors[i].s) - 1400.0) < 30.0: near_station = true
	check(kinds.size() == 5 and sorted and not near_station, "five kinds of anchors, in order, none at the platforms")
	var c = Grapnel.new()
	c.build(7, 6800.0, [30.0, 1400.0])
	check(c.anchors.size() != a.anchors.size() or c.anchors[5].s != a.anchors[5].s, "another seed gives another line of anchors")

	# --- a throw at a post ten metres ahead
	var g = with_anchor(110.0, "post")
	check(g.anchor_ahead(100.0, 1) == 0 and g.anchor_ahead(100.0, -1) == -1 and g.anchor_ahead(108.0, 1) == -1, "the anchor ahead is found, behind and too close are not")
	check(g.throw(100.0, 1, 1.2, flat) and g.mode == "flying" and not g.throw(100.0, 1, 1.2, flat), "the hook goes once")
	var r = play(g, 100.0, 1, 600.0, 14.0)
	check("hook" in r.events and "reached" in r.events and not ("tear" in r.events), "the hook catches the post and the truck is pulled to it (%s)" % str(r.events))
	check(r.s > 108.0 and r.s < 113.0, "the truck came under the post (%.1f)" % r.s)
	check(r.max_force > 100.0 and r.max_force <= 0.25 * 600.0 * 9.81 + 1.0, "the pull is up to a quarter of the weight (%.0f N of %.0f)" % [r.max_force, 0.25 * 600.0 * 9.81])
	check(g.mode == "dropped" or g.mode == "stowed", "after the stop the hook is let go (%s)" % g.mode)
	# the hook comes back to its clip
	play(g, 110.0, 1, 600.0, 2.0)
	check(g.mode == "stowed", "and goes back into the clip")

	# --- the weak anchors
	var bush = with_anchor(110.0, "bush")
	bush.throw(100.0, 1, 1.2, flat)
	check("tear" in play(bush, 100.0, 1, 600.0, 10.0).events, "a bush does not hold the winch: the hook tears out")
	var stump_heavy = with_anchor(110.0, "stump")
	stump_heavy.throw(100.0, 1, 1.2, flat)
	check("tear" in play(stump_heavy, 100.0, 1, 600.0, 10.0).events, "a stump does not hold a heavy train")
	var stump_light = with_anchor(110.0, "stump")
	stump_light.throw(100.0, 1, 1.2, flat)
	var light = play(stump_light, 100.0, 1, 150.0, 14.0)
	check("reached" in light.events and not ("tear" in light.events), "but a stump holds a light truck")
	for type in ["tree", "rock"]:
		var strong = with_anchor(110.0, type)
		strong.throw(100.0, 1, 1.2, flat)
		var res = play(strong, 100.0, 1, 600.0, 14.0)
		check("hook" in res.events and "reached" in res.events and not ("tear" in res.events), "a %s holds (%s)" % [type, str(res.events)])

	# --- a miss and the range
	var far = with_anchor(130.0, "post")
	check(far.anchor_ahead(100.0, 1) == -1, "an anchor 30 m away is out of reach")
	far.throw(100.0, 1, 1.2, flat)
	var miss = play(far, 100.0, 1, 600.0, 4.0)
	check("miss" in miss.events and not ("hook" in miss.events) and miss.max_force == 0.0 and far.mode == "stowed", "with nothing in reach the hook falls and comes back, no pull (%s)" % str(miss.events))

	# --- the other way
	var back = with_anchor(190.0, "post")
	back.throw(200.0, -1, 1.2, flat)
	var rb = play(back, 200.0, -1, 600.0, 14.0)
	check("hook" in rb.events and "reached" in rb.events and rb.s < 192.0 and rb.s > 186.5, "backwards the same (%.1f, %s)" % [rb.s, str(rb.events)])

	# --- the scatter: close throws never miss, far ones sometimes do
	var close_hits = 0
	var far_hits = 0
	for k in range(40):
		var near = with_anchor(100.0 + 4.0, "post")
		near.throws = k * 7
		near.throw(100.0, 1, 1.2, flat)
		if near.catch_t >= 0.0: close_hits += 1
		var distant = with_anchor(100.0 + 14.5, "post")
		distant.throws = k * 7
		distant.throw(100.0, 1, 1.2, flat)
		if distant.catch_t >= 0.0: far_hits += 1
	check(close_hits == 40, "a throw of 4 m always catches (%d of 40)" % close_hits)
	check(far_hits >= 8 and far_hits <= 38, "a throw of 14.5 m sometimes misses (%d of 40)" % far_hits)
	var mid_hits = 0
	for k in range(40):
		var mid = with_anchor(100.0 + 11.0, "post")
		mid.throws = k * 7
		mid.throw(100.0, 1, 1.2, flat)
		if mid.catch_t >= 0.0: mid_hits += 1
	print("GRAPNEL mid hits ", mid_hits)
	check(mid_hits >= 22, "a throw of 11 m catches a post most of the time (%d of 40)" % mid_hits)
	print("GRAPNEL CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
