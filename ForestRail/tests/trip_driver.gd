extends RefCounted
# Drives a whole trip A -> station -> A with the same inputs a player has (no moving s),
# and reports what it cost. Used to check the trip forecast against the real model.

static func index_of(m, id: String) -> int:
	for i in range(m.data.stations.size()):
		if m.data.stations[i].id == id: return i
	return 0

# Returns {ok, seconds, used, distance}. `used` is the store spent in the model's own
# unit (litres, kWh net of regeneration, kg of coal burnt from the bucket and firebox).
static func round_trip(m, station: String, count: int, cargo_type: String = "sack") -> Dictionary:
	var mission = {"id": "TRIP", "title": "trip", "tier": m.vehicle_id(), "reward": 0, "free": true,
		"dropoffs": [{"station": station, "cargo": [[cargo_type, count]]}]}
	if not m.accept_mission(mission): return {"ok": false, "why": m.message}
	var slots = m.slots()
	for i in range(mini(m.state.cargo.size(), slots.size())): m.transfer(m.state.cargo[i].id, slots[i].key)
	if not m.depart(): return {"ok": false, "why": "depart " + m.message}
	var fleet = m.state.fleet_by_id[m.vehicle_id()]
	var steam = m.vehicle_id() == "steam"
	if steam: preload("res://tests/fixtures.gd").fire_up(m)
	var start_store = float(fleet.fuel) + (float(m.boiler().firebox) if steam else 0.0)
	var water_start = float(fleet.get("water", 0))
	var timer = 0.0
	var burnt_extra = 0.0
	while m.state.phase != "depot" and timer < 2400:
		var destination = m.next_destination()
		var target_s = m.service_stop(index_of(m, destination))
		var remaining = (target_s - float(m.state.s)) * int(m.state.direction)
		var speed = absf(float(m.state.v))
		var brake_force = 0.0
		for id in m.body_ids(): brake_force += float(m.object_stats(id).brake)
		var braking_distance = speed * speed / (2 * brake_force / m.train_mass()) + 0.3
		if remaining < maxf(0.5, braking_distance):
			m.state.throttle = 0
			m.state.brake = 1.0
		else:
			m.state.brake = 0
			if steam:
				if not m.state.engine or float(m.boiler().firebox) < 1.5:
					var before = float(fleet.fuel)
					preload("res://tests/fixtures.gd").fire_up(m)
					burnt_extra += 0.0 * before
			elif not m.state.engine:
				m.state.throttle = 0
				m.set_gear(0)
				m.start_engine(true)
				m.set_gear(2)
			if m.vehicle_id() == "motorcar":
				var want = 2 if speed < 2.5 else 4
				if int(m.state.gear) != want:
					m.state.throttle = 0.0
					m.set_gear(want)
			m.state.throttle = 0.95
		m.physics_step(1.0 / 60)
		timer += 1.0 / 60
		if m.station_index() == index_of(m, destination) and m.station_interaction().can_transfer:
			if destination == "A" and m.state.active.is_empty(): break
			for item in m.state.cargo.duplicate(true):
				if item.destination == destination and not item.delivered: m.transfer(item.id, "")
			if m.state.active.get("phase", "") == "return":
				m.turn()
				m.state.brake = 1
	var end_store = float(fleet.fuel) + (float(m.boiler().firebox) if steam else 0.0)
	return {"ok": m.state.phase == "depot", "seconds": timer, "used": start_store - end_store, "water_used": water_start - float(fleet.get("water", 0)), "distance": 2.0 * float(m.route.station_s[index_of(m, station)])}
