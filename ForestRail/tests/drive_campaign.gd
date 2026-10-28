extends Node

var root: Window:
	get: return get_tree().root

func quit(code: int = 0) -> void:
	get_tree().quit(code)



const Model = preload("res://scripts/model.gd")
var failures: Array = []
var stats: Array = []
var steps = 0

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var m = Model.new()
	m.new_game(42)
	for chapter in range(13):
		if chapter == 2: m.buy_vehicle("motorcar")
		if chapter == 6: m.buy_vehicle("locomotive")
		if chapter == 9: m.buy_wagon()
		m.refuel()
		var mission = m.current_mission() if chapter < 10 else m.free_offers()[chapter - 10]
		if not m.accept_mission(mission): failures.append("accept " + str(mission.id)); break
		for i in range(m.state.cargo.size()): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
		m.depart()
		var timer = 0.0
		var phase_time = 0.0
		var last_stop = ""
		while m.state.phase != "depot" and timer < 2400:
			var destination = m.next_destination()
			var target_s = m.service_stop(station_index(m,destination))
			var remaining = (target_s - float(m.state.s)) * int(m.state.direction)
			var speed = absf(float(m.state.v))
			# The controller only manipulates the same inputs as a human. It never moves s.
			var brake_force = 0.0
			for id in m.body_ids(): brake_force += float(m.object_stats(id).brake)
			var braking_distance = speed * speed / (2 * brake_force / m.train_mass()) + 0.3
			var stopping = remaining < maxf(0.5, braking_distance)
			if stopping:
				m.state.throttle = 0
				m.state.brake = 1.0
			else:
				m.state.brake = 0
				if m.vehicle_id() == "handcar":
					preload("res://tests/handcar_input.gd").pull(m,int(m.state.direction))
				else:
					if not m.state.engine:
						m.state.throttle = 0
						m.set_gear(0)
						m.start_engine(true)
						m.set_gear(2)
					m.state.throttle = 0.95
			m.physics_step(1.0 / 60)
			timer += 1.0 / 60
			steps += 1
			if m.station_index() == station_index(m, destination) and m.station_interaction().can_transfer:
				if destination == "A" and m.state.active.is_empty(): break
				for item in m.state.cargo.duplicate(true):
					if item.destination == destination and not item.delivered: m.transfer(item.id, "")
				if m.state.active.get("phase", "") == "return":
					m.turn()
					# No engine restart required when changing the consist direction.
					m.state.brake = 1
			if steps % 18000 == 0:
				print("DRIVE ", mission.id, " t=", int(timer), " s=", int(m.state.s), " v=", snappedf(m.state.v, 0.01))
				await get_tree().process_frame
		if m.state.phase != "depot":
			failures.append("Could not finish " + str(mission.id) + " s=" + str(m.state.s))
			break
		stats.append({"mission": mission.id, "seconds": timer, "money": m.state.money, "energy_remaining": m.state.fleet_by_id[m.vehicle_id()].fuel})
		print("COMPLETED ", mission.id, " ", int(timer), " seconds; money ", m.state.money)
		await get_tree().process_frame
	var output = FileAccess.open("user://qa_model/drive_campaign.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures": failures, "missions": stats, "steps": steps}, "\t"))
	output.close()
	print("DRIVE CAMPAIGN: ", stats.size(), "/13 (10 career + 3 free), steps ", steps, ", failures ", failures)
	quit(0 if failures.is_empty() and stats.size() == 13 else 1)

func station_index(m, id: String) -> int:
	for i in range(m.data.stations.size()):
		if m.data.stations[i].id == id: return i
	return 0
