extends SceneTree

const Model=preload("res://scripts/model.gd")

func fixture(id: String):
	var m=Model.new()
	m.new_game(42);m.state.money=10000
	if id!="handcar": m.buy_vehicle("motorcar")
	if id=="locomotive": m.buy_vehicle("locomotive")
	m.select_vehicle(id)
	m.state.phase="route";m.state.s=100;m.state.brake=0
	for p in m.route.points: p[1]=0.0
	return m

func _initialize() -> void:
	var result={"scope":"read-only model probes, synthetic flat fixtures, no career save writes","vehicles":Model.VEHICLE_IDS,"electric":[],"slots":{}}
	for id in Model.VEHICLE_IDS:
		var m=fixture(id)
		result.slots[id]=m.object_stats(id).slots
	for fraction in [1.0,0.75,0.5,0.25,0.15,0.0]:
		var m=fixture("locomotive")
		m.state.fleet_by_id.locomotive.fuel=m.object_stats("locomotive").tank*fraction
		m.state.gear=1;m.state.throttle=1;m.state.engine=true
		m.physics_step(1.0/60)
		result.electric.append({"fraction":fraction,"acceleration_mps2":m.acceleration,"speed_mps":m.state.v})
	var petrol=fixture("motorcar")
	petrol.set_gear(4)
	result.petrol_requested_gear_4_actual=petrol.state.gear
	var hand=fixture("handcar")
	hand.handcar.set_phase(hand.handcar.limits.maximum.phase)
	result.manual_dead_point_push_available=hand.can_push_handcar()
	hand.grab_pump()
	for i in range(120):
		hand.set_pump_target(hand.handcar.pose().angle-0.3)
		hand.physics_step(1.0/60)
	result.manual_dead_point_speed_after_2s=hand.state.v
	var out=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): out=arg.trim_prefix("--report=")
	if out!="":
		var f=FileAccess.open(out,FileAccess.WRITE)
		f.store_string(JSON.stringify(result,"\t"));f.close()
	print(JSON.stringify(result))
	quit()
