extends Node

var root: Window:
	get: return get_tree().root

func quit(code: int = 0) -> void:
	get_tree().quit(code)



const Model = preload("res://scripts/model.gd")
var failures: Array = []
var stats: Array = []
var steps = 0
# 1 is the original 1.7 km line; drive_long.gd runs the same campaign on the long line.
var line = 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Model.legacy_tanks = (line == 1)  # the old 1.7 km line keeps the old tanks; the long line runs on the real ones
	var m = Model.new()
	m.new_game(42, line)
	var partial="--partial-first" in OS.get_cmdline_user_args()
	var trips=1 if partial else 13
	for chapter in range(trips):
		# This suite drives; the economy and its free runs are checked in
		# check_model. Purchases follow ECONOMY_v3_2_RU.md with the money
		# the free runs would have earned.
		var purchase = {2: "steam", 4: "motorcar", 8: "locomotive"}.get(chapter, "")
		if purchase != "":
			m.state.money += int(m.vehicle_base(purchase).cost)
			m.buy_vehicle(purchase)
			# The stock tank is small on purpose (B2.2): a player who goes far buys the tank upgrade.
			if line == 2:
				for branch in m.data.upgrade_catalog:
					if str(branch.id) == purchase + "_tank": m.state.fleet_by_id[purchase].levels[branch.id] = 2
				m.refuel()
		if chapter == 4 or chapter == 9:
			m.state.money += m.wagon_price(m.next_wagon_id())
			m.buy_wagon()
		m.refuel()
		var mission = m.current_mission() if chapter < 10 else m.free_offers()[chapter - 10]
		if not m.accept_mission(mission): failures.append("accept " + str(mission.id)); break
		for i in range(1 if partial else m.state.cargo.size()): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
		m.depart()
		var timer = 0.0
		var phase_time = 0.0
		var last_stop = ""
		while m.state.phase != "depot" and timer < 9000:
			var real_destination = m.next_destination()
			var destination = real_destination
			# B2.2: the tanks are half of what they were. A driver stops where the road sells fuel when
			# the tank is going down, as a player must.
			if m.vehicle_id() not in ["handcar", "pole"]:
				var stats_now = m.object_stats(m.vehicle_id())
				if float(m.state.fleet_by_id[m.vehicle_id()].fuel) < 0.75 * float(stats_now.tank):
					var here_s = float(m.state.s)
					var end_s = m.service_stop(station_index(m, real_destination))
					for i in range(m.data.stations.size()):
						var spot = m.service_stop(i)
						var services = m.data.stations[i].get("services", {})
						if m.fuel_service_mult(services) < 0.0: continue
						var ahead = (spot - here_s) * int(m.state.direction)
						var before_end = (end_s - spot) * int(m.state.direction)
						if ahead > 20.0 and before_end > 20.0:
							destination = str(m.data.stations[i].id)
							break
			var target_s = m.service_stop(station_index(m,destination))
			var remaining = (target_s - float(m.state.s)) * int(m.state.direction)
			var speed = absf(float(m.state.v))
			# The controller only manipulates the same inputs as a human. It never moves s.
			var brake_force = 0.0
			for id in m.body_ids(): brake_force += float(m.object_stats(id).brake)
			var braking_distance = speed * speed / (2 * brake_force / m.train_mass()) + 0.3
			var stopping = remaining < maxf(0.5, braking_distance)
			# Standing short of the platform: let the brake off and go on, as a person would.
			if speed < 0.05 and remaining > 0.6: stopping = false
			if stopping:
				m.state.throttle = 0
				m.state.brake = 1.0
			else:
				m.state.brake = 0
				if m.vehicle_id() == "handcar":
					preload("res://tests/handcar_input.gd").pull(m,int(m.state.direction))
				else:
					if m.vehicle_id() == "steam":
						# The boiler needs a fire and coal; stoke again when it runs low.
						if not m.state.engine:
							preload("res://tests/fixtures.gd").fire_up(m)
						elif float(m.boiler().firebox) < 4.0:
							m.set_door(true)
							while float(m.boiler().firebox) < 9.0 and m.stoke(): pass
							m.set_door(false)
					elif not m.state.engine:
						m.state.throttle = 0
						m.set_gear(0)
						m.start_engine(true)
						m.set_gear(2)
					if m.vehicle_id() == "motorcar":
						var want = 2 if speed < 4.0 else (3 if speed < 10.0 else (4 if speed < 20.0 else 5))
						if int(m.state.gear) != want:
							m.state.throttle = 0.0
							m.set_gear(want)
					m.state.throttle = 0.95
					if m.vehicle_id() == "steam":
						# Ease the regulator when the pressure runs down, as a driver does.
						var pressure = float(m.boiler().pressure)
						m.state.throttle = 0.95 if pressure > 0.7 else (0.5 if pressure > 0.45 else 0.15)
			m.physics_step(1.0 / 60)
			timer += 1.0 / 60
			steps += 1
			if m.station_index() == station_index(m, destination) and m.station_interaction().can_transfer:
				# a driver tops up where the station sells fuel (B2.2: the tanks are half of what they were)
				if not m.service_offer().is_empty() and m.refill_cost() > 0:
					print("REFUEL ", mission.id, " at ", destination, " s=", int(m.state.s), " fuel was ", snappedf(float(m.state.fleet_by_id[m.vehicle_id()].fuel) / maxf(0.0001, float(m.object_stats(m.vehicle_id()).tank)), 0.01))
					m.refuel()
				if destination != real_destination:
					m.state.brake = 0.0
					continue
				if destination == "A" and m.state.active.is_empty(): break
				for item in m.state.cargo.duplicate(true):
					if item.destination == destination and not item.delivered: m.transfer(item.id, "")
				if m.state.active.get("phase", "") == "return":
					m.turn()
					# No engine restart required when changing the consist direction.
					m.state.brake = 1
			if steps % 18000 == 0:
				print("DRIVE ", mission.id, " t=", int(timer), " s=", int(m.state.s), " v=", snappedf(m.state.v, 0.01), " dest=", destination, " idx=", m.station_index(), " can=", m.station_interaction().can_transfer, " phase=", m.state.phase, " cargo=", m.state.cargo.size(), " brake=", m.state.brake, " dir=", m.state.direction, " held=", m.hand_drive.held, " canpush=", m.can_push_handcar(), " dang=", snappedf(float(m.handcar.pose().dangle_dphase), 0.001), " active=", m.state.active.get("phase", ""), " fuel=", snappedf(float(m.state.fleet_by_id[m.vehicle_id()].fuel) / maxf(0.0001, float(m.object_stats(m.vehicle_id()).tank)), 0.01), " thr=", snappedf(float(m.state.throttle), 0.01))
				await get_tree().process_frame
		if m.state.phase != "depot":
			failures.append("Could not finish " + str(mission.id) + " s=" + str(m.state.s))
			break
		stats.append({"mission": mission.id, "seconds": timer, "money": m.state.money, "energy_remaining": m.state.fleet_by_id[m.vehicle_id()].fuel})
		print("COMPLETED ", mission.id, " ", int(timer), " seconds; money ", m.state.money)
		await get_tree().process_frame
	var output = FileAccess.open("user://qa_model/drive_partial.json" if partial else "user://qa_model/drive_campaign.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures": failures, "missions": stats, "steps": steps}, "\t"))
	output.close()
	print("DRIVE CAMPAIGN: ", stats.size(), "/",trips," (partial first trip)" if partial else " (10 career + 3 free)"," steps ", steps, ", failures ", failures)
	if partial and line == 1 and (stats.is_empty() or stats[0].money!=50): failures.append("partial payment must be 50")
	quit(0 if failures.is_empty() and stats.size() == trips else 1)

func station_index(m, id: String) -> int:
	for i in range(m.data.stations.size()):
		if m.data.stations[i].id == id: return i
	return 0
