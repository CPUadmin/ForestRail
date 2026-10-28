extends RefCounted

static var shared_config: Dictionary = {}
var config: Dictionary
var held = false
var target_angle = 0.0
var capture_age = 0.0
var hand_work = 0.0
var losses = 0.0
var external_work = 0.0
var nudge_work = 0.0
var last: Dictionary = {}
var push_used = 0.0
var push_displacement = 0.0
var push_active = false
var clock = 0.0
var samples: Array = []

func _init() -> void:
	if shared_config.is_empty(): shared_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/handcar_drive.json"))
	config=shared_config

func grab(angle: float) -> void:
	held=true
	target_angle=angle
	capture_age=0.0
	samples=[{"time":clock,"angle":angle}]

func release() -> void:
	held=false
	capture_age=0.0
	samples=[]
	push_active=false

func set_target(angle: float, at_time: float = -1) -> void:
	if not held or not is_finite(angle): return
	if at_time<0: at_time=clock
	target_angle=angle
	if samples.is_empty(): samples.append({"time":at_time,"angle":angle});return
	if at_time<=float(samples[-1].time)+1e-9:
		samples[-1].angle=angle
	else:
		if at_time-float(samples[-1].time)>0.1: samples.append({"time":at_time-0.000001,"angle":samples[-1].angle})
		samples.append({"time":at_time,"angle":angle})

func sampled_target(at_time: float) -> float:
	while samples.size()>2 and float(samples[1].time)<at_time: samples.pop_front()
	if samples.is_empty(): return target_angle
	if at_time<=float(samples[0].time): return float(samples[0].angle)
	for i in range(samples.size()-1):
		if at_time<=float(samples[i+1].time):
			return lerpf(float(samples[i].angle),float(samples[i+1].angle),clampf((at_time-float(samples[i].time))/maxf(1e-9,float(samples[i+1].time)-float(samples[i].time)),0,1))
	return float(samples[-1].angle)

func inertia(mass: float, radius: float, ratio: float) -> float:
	return mass*pow(radius*ratio,2)+float(config.flywheel_inertia_kg_m2)+float(config.crank_inertia_kg_m2)+float(config.wheel_count)*float(config.wheel_inertia_kg_m2)*ratio*ratio

func step(mechanism, velocity: float, mass: float, facing: int, radius: float, dt: float, grade_force: float, rolling_force: float, brake_force: float, power_limit: float, torque_multiplier: float, potential: Callable) -> Dictionary:
	var ratio=float(mechanism.config.gear_ratio)
	var k=radius*ratio*facing
	var moment=inertia(mass,radius,ratio)
	var omega=velocity/k
	var total_phase=0.0
	var work=0.0
	var dissipated=0.0
	var potential_change=0.0
	var max_power=0.0
	var peak_torque=0.0
	var start_energy=0.5*moment*omega*omega
	var count=maxi(1,ceili(dt/float(config.max_substep_s)))
	var h=dt/count
	for substep in range(count):
		clock+=h
		if held: capture_age+=h
		var desired=sampled_target(clock-float(config.input_delay_s)) if held else 0.0
		var old_omega=omega
		var phase=mechanism.phase
		var pose=mechanism.pose()
		var alpha=float(pose.angle)
		var offset=total_phase*k
		var old_u=float(potential.call(offset))
		var d=omega*h
		var torque=0.0
		var delta_alpha=0.0
		var delta_u=0.0
		var active=0.0
		var dry=0.0
		# Constant-inertia midpoint iteration. A secant Jacobian makes the
		# hand's generalized work equal to torque * actual rocker travel.
		for iteration in range(7):
			var next=mechanism.solve(phase+d)
			delta_alpha=float(next.angle)-alpha
			var jacobian=delta_alpha/d if absf(d)>1e-8 else float(pose.dangle_dphase)
			var mean_omega=d/h
			torque=0.0
			if held:
				var error=desired-(alpha+float(next.angle))*0.5
				if absf(error)<0.00001: error=0.0
				var damping=float(config.damping_nms_per_rad)*minf(1,capture_age/0.12)
				torque=clampf(float(config.spring_nm_per_rad)*error-damping*delta_alpha/h,-float(config.max_hand_torque_nm)*torque_multiplier,float(config.max_hand_torque_nm)*torque_multiplier)
				var positive=torque*delta_alpha
				var cap=minf(float(config.max_hand_power_w),power_limit)*h
				if positive>cap and absf(delta_alpha)>1e-12: torque*=cap/positive
			delta_u=float(potential.call(offset+k*d))-old_u
			var gravity=-delta_u/d if absf(d)>1e-8 else grade_force*k
			active=torque*jacobian+gravity
			var air=float(config.air_drag_n_per_mps2)*pow(k*mean_omega,2)
			dry=(rolling_force+brake_force+air)*absf(k)
			var sign_value=signf(mean_omega) if absf(mean_omega)>1e-9 else signf(active)
			var visc=float(config.viscous_loss_nms)
			omega=((moment-h*visc*0.5)*old_omega+h*(active-sign_value*dry))/(moment+h*visc*0.5)
			if (absf(old_omega)<1e-8 and absf(active)<=dry) or (signf(omega)!=signf(old_omega) and absf(active)<=dry): omega=0.0
			var next_d=(old_omega+omega)*0.5*h
			if absf(next_d-d)<1e-10: d=next_d;break
			d=next_d
		# Evaluate the final displacement once for the energy ledger.
		var next_pose=mechanism.solve(phase+d)
		delta_alpha=float(next_pose.angle)-alpha
		delta_u=float(potential.call(offset+k*d))-old_u
		var mean=d/h
		var viscous=float(config.viscous_loss_nms)*mean*mean*h
		var hand=torque*delta_alpha
		var cap=minf(float(config.max_hand_power_w),power_limit)*h
		if hand>cap: torque*=cap/hand;hand=cap
		var gravity=-delta_u/d if absf(d)>1e-8 else grade_force*k
		var jac=delta_alpha/d if absf(d)>1e-8 else float(pose.dangle_dphase)
		dry=(rolling_force+brake_force+float(config.air_drag_n_per_mps2)*pow(k*mean,2))*absf(k)
		var used_dry=signf(d)*dry
		if omega==0.0:
			used_dry=clampf(torque*jac+gravity-float(config.viscous_loss_nms)*mean-moment*(omega-old_omega)/h,-dry,dry)
		var dry_loss=maxf(0,used_dry*d)
		work+=hand
		dissipated+=viscous+dry_loss
		potential_change+=delta_u
		max_power=maxf(max_power,maxf(0,hand/h))
		peak_torque=maxf(peak_torque,absf(torque))
		total_phase+=d
		mechanism.set_phase(phase+d)
	var energy=0.5*moment*omega*omega
	last={"delta_s":total_phase*k,"velocity":omega*k,"omega":omega,"hand_work":work,"losses":dissipated,"potential_change":potential_change,"kinetic":energy,"flywheel_energy":0.5*float(config.flywheel_inertia_kg_m2)*omega*omega,"start_kinetic":start_energy,"max_positive_power":max_power,"peak_hand_torque":peak_torque,"balance_error":energy-start_energy+potential_change-work+dissipated,"inertia":moment}
	hand_work+=work
	losses+=dissipated
	external_work-=potential_change
	return last
