extends Node

const Model=preload("res://scripts/model.gd")
const InputDriver=preload("res://tests/handcar_input.gd")
var checks=0
var failures: Array=[]
var cases: Array=[]
var fps_cases: Array=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL: ",label)

func _ready() -> void:
	call_deferred("run")

func setup(loaded: bool = true):
	var model=Model.new()
	model.new_game(42)
	model.accept_mission(model.current_mission())
	for i in range(2): model.transfer(model.state.cargo[i].id,model.slots()[i].key)
	model.depart()
	if not loaded: model.state.cargo=[]
	for point in model.route.points: point[1]=0.0
	model.state.s=40.0
	model.state.brake=0.0
	return model

func energy(model) -> float:
	var k=0.21*float(model.handcar.config.gear_ratio)
	return 0.5*model.hand_drive.inertia(model.train_mass(),0.21,float(model.handcar.config.gear_ratio))*pow(float(model.state.v)/k,2)+model.handcar_potential_at(0)

func record_trace() -> Array:
	var m=setup()
	var trace: Array=[]
	for i in range(2401):
		InputDriver.pull(m)
		trace.append(float(m.hand_drive.target_angle))
		m.physics_step(1.0/120)
	return trace

func replay(trace: Array, fps: int, event_hz: int = 120) -> Dictionary:
	var m=setup()
	m.grab_pump()
	var event_index=0
	var next_frame=0
	# OS events keep their sampling times even when multiple arrive in one
	# rendering frame; physics resamples the local target at its fixed clock.
	for tick in range(1200):
		var time=tick/60.0
		while next_frame/float(fps)<=time+0.0000001:
			var frame_end=next_frame/float(fps)
			while event_index/float(event_hz)<=frame_end+0.0000001:
				var t=event_index/float(event_hz)
				var index=minf(t*120,trace.size()-1)
				var lo=floori(index)
				var angle=lerpf(trace[lo],trace[mini(lo+1,trace.size()-1)],index-lo)
				m.set_pump_target(angle,t)
				event_index+=1
			next_frame+=1
		m.physics_step(1.0/60)
	return {"fps":fps,"event_hz":event_hz,"distance":float(m.state.s)-40,"hand_work":m.hand_drive.hand_work,"energy":energy(m),"speed":m.state.v}

func run() -> void:
	for loaded in [false,true]:
		for direction in [-1,1]:
			var m=setup(loaded)
			var initial=energy(m)
			var original_s=float(m.state.s)
			var original_phase=m.handcar.phase
			var residual=0.0
			var positive_work=0.0
			var peak=0.0
			for i in range(1200):
				InputDriver.pull(m,direction)
				m.physics_step(1.0/60)
				residual+=m.hand_drive.last.balance_error
				positive_work+=maxf(0,m.hand_drive.last.hand_work)
				peak=maxf(peak,m.hand_drive.last.max_positive_power)
				check(m.hand_drive.last.max_positive_power<=220.001,"positive power cap")
				check(absf((float(m.state.s)-original_s)-(m.handcar.phase-original_phase)*0.21*float(m.handcar.config.gear_ratio)*int(m.state.direction))<1e-7,"position and phase coupled")
			check(float(m.state.v)*direction>1.0,"pulling accelerates correct direction")
			var balance=energy(m)-initial-m.hand_drive.hand_work+m.hand_drive.losses-m.hand_drive.nudge_work
			check(absf(balance)<maxf(0.02,positive_work*0.02),"independent energy balance")
			var before_phase=m.handcar.phase
			m.reset_input()
			var previous=energy(m)
			for i in range(180):
				m.physics_step(1.0/60)
				check(energy(m)<=previous+0.001,"no-input energy cannot increase")
				previous=energy(m)
			check(absf(m.handcar.phase-before_phase)>0.1,"coasting rotates mechanism")
			cases.append({"loaded":loaded,"direction":direction,"speed_after_coast":m.state.v,"balance_j":balance,"work_j":positive_work,"peak_w":peak,"phase":m.handcar.phase})
	# Same actual target impulse produces a different acceleration under load.
	var light=setup(false)
	var heavy=setup(true)
	for m in [light,heavy]: m.grab_pump();m.set_pump_target(m.handcar.pose().angle+0.30)
	for i in range(30):
		light.physics_step(1.0/60);heavy.physics_step(1.0/60)
	check(light.state.v>heavy.state.v+0.03,"identical cursor target accelerates lighter machine faster")
	check(light.handcar.phase>heavy.handcar.phase,"load changes visible mechanism response")
	for brake in [0.0,0.5,1.0]:
		var m=setup()
		m.state.brake=brake
		m.grab_pump()
		for i in range(240):
			m.set_pump_target(m.handcar.pose().angle)
			m.physics_step(1.0/60)
		check(absf(m.state.v)<1e-6,"stationary clicks and held unchanged target create no motion")
		if brake==1.0:
			var phase=m.handcar.phase
			m.set_pump_target(m.handcar.pose().angle+0.5)
			for i in range(120): m.physics_step(1.0/60)
			check(m.handcar.phase==phase and m.state.v==0,"full brake holds coupled mechanism")
	# Restoring a moving drive must preserve its phase, speed and kinetic energy.
	var moving=setup()
	for i in range(360): InputDriver.pull(moving);moving.physics_step(1.0/60)
	var copy=Model.new()
	check(copy.restore(moving.serialize()),"moving coupled drive restores")
	check(copy.handcar.phase==moving.handcar.phase and copy.state.v==moving.state.v and absf(energy(copy)-energy(moving))<1e-8,"restore has no phase or energy jump")
	var before=energy(moving)
	moving.reset_input();moving.grab_pump()
	check(energy(moving)==before,"regrab has no impulse")
	for i in range(120): moving.physics_step(1.0/60);check(energy(moving)<=before+0.01,"stationary regrab cannot increase original energy")
	# Both dead points require an explicit, separately metered push from rest.
	for edge in [moving.handcar.limits.minimum,moving.handcar.limits.maximum]:
		var m=setup()
		m.handcar.set_phase(edge.phase)
		m.grab_pump();m.set_pump_target(m.handcar.pose().angle+0.3)
		for i in range(60): m.physics_step(1.0/60)
		check(absf(m.state.v)<0.0001,"exact dead point receives no hidden drive kick")
		m.reset_input();m.begin_push()
		check(not m.push_handcar(0.0) and m.state.v==0,"zero push cannot create energy")
		m.state.brake=1
		check(not m.push_handcar(0.2),"push unavailable with brake")
		m.state.brake=0
		check(m.push_handcar(0.2) and m.hand_drive.nudge_work>0 and m.hand_drive.push_used<=20,"explicit push contributes bounded separate work")
		var phase=m.handcar.phase
		for i in range(60): InputDriver.pull(m);m.physics_step(1.0/60)
		check(absf(m.handcar.phase-phase)>0.1,"nudge lets inertia carry dead point")
	# A reverse effort is allowed to do negative work; it must decelerate first.
	var reverse=setup()
	reverse.state.v=2.0
	var initial_v=reverse.state.v
	var saw_negative=false
	for i in range(90): InputDriver.pull(reverse,-1);reverse.physics_step(1.0/60);saw_negative=saw_negative or reverse.hand_drive.last.hand_work<0
	check(saw_negative and reverse.state.v<initial_v,"opposing effort brakes instead of adding forward drive")
	for i in range(360): InputDriver.pull(reverse,-1);reverse.physics_step(1.0/60)
	check(reverse.state.v< -0.1,"sustained reverse effort reverses after slowing")
	# Heights and friction independently account for downhill/uphill energy.
	for slope in [-0.04,0.04]:
		var m=setup()
		for point in m.route.points: point[1]=float(point[0])*slope
		m.state.v=2.0
		var e=energy(m)
		var error=0.0
		for i in range(300):
			m.physics_step(1.0/60)
			error=maxf(error,absf(energy(m)-e+m.hand_drive.losses))
		check(error<0.05,"no-input gravity/kinetic/loss energy balance")
	var pushes: Array=[]
	for events in [30,1000]:
		var m=setup()
		m.handcar.set_phase(m.handcar.limits.maximum.phase)
		m.begin_push()
		for i in range(events): m.push_handcar(0.30/events)
		pushes.append(m.hand_drive.nudge_work)
	check(absf(pushes[0]-pushes[1])<0.000001 and pushes[0]<=20.000001,"push work depends on gesture distance, not event count")
	# A physical flywheel adds I*omega^2/2 and prolongs coasting. It is not a
	# stored work budget that can remain charged after the shaft stops.
	var rotor_speeds: Array=[]
	for inertia in [0.0,3.0]:
		var m=setup(false)
		m.hand_drive.config=m.hand_drive.config.duplicate(true)
		m.hand_drive.config.flywheel_inertia_kg_m2=inertia
		m.state.v=2.0
		for i in range(240): m.physics_step(1.0/60)
		check(absf(m.hand_drive.last.flywheel_energy-0.5*inertia*pow(m.hand_drive.last.omega,2))<1e-8,"flywheel energy follows angular speed")
		rotor_speeds.append(m.state.v)
	check(rotor_speeds[1]>rotor_speeds[0],"larger flywheel inertia carries coasting further")
	var trace=record_trace()
	for fps in [30,60,120,144]: fps_cases.append(replay(trace,fps))
	for hz in [30,240,1000]: fps_cases.append(replay(trace,60,hz))
	var reference=fps_cases[1]
	for row in fps_cases:
		check(absf(row.distance-reference.distance)/maxf(1,absf(reference.distance))<=0.02,"recorded input travel <=2% FPS/event difference")
		check(absf(row.hand_work-reference.hand_work)/maxf(1,absf(reference.hand_work))<=0.02,"recorded input work <=2% FPS/event difference")
	var out_dir=ProjectSettings.globalize_path("res://../qa/v3_p4")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--drive-output="): out_dir=arg.trim_prefix("--drive-output=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file=FileAccess.open(out_dir.path_join("drive_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"fps_replay":fps_cases,"push_work_by_event_hz":pushes},"\t"));file.close()
	print("HANDCAR DRIVE CHECKS ",checks,"; FAILURES ",failures,"; CASES ",cases)
	get_tree().quit(0 if failures.is_empty() else 1)
