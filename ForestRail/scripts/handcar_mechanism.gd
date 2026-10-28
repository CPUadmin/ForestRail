extends RefCounted

# Geometry only. P3's temporary kinematic driver does not calculate effort,
# train inertia or useful work. P4 replaces it with the coupled drive.
static var shared_config: Dictionary = {}
static var shared_limits: Dictionary = {}
var config: Dictionary
var limits: Dictionary
var phase = 0.0
var last_phase_step = 0.0
var revision = 0
var cached_pose: Dictionary = {}
var cached_phase = INF

func _init() -> void:
	if shared_config.is_empty():
		shared_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/handcar_mechanism.json"))
	config = shared_config
	assert(full_rotation_valid(),"Handcar crank cannot complete a full turn")
	if shared_limits.is_empty(): shared_limits = calculate_limits()
	limits = shared_limits
	seek_rocker((float(limits.minimum.angle)+float(limits.maximum.angle))*0.5)
	last_phase_step = 0.0

func vec(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

func full_rotation_valid() -> bool:
	var distance = vec(config.rocker_pivot).distance_to(vec(config.crank_pivot))
	var a = float(config.rocker_pin_radius)
	var r = float(config.crank_radius)
	var length = float(config.rod_length)
	return distance-r>absf(length-a) and distance+r<length+a and int(config.assembly_branch) in [-1,1] and float(config.gear_ratio)>0

func solve(value: float) -> Dictionary:
	var o = vec(config.rocker_pivot)
	var c = vec(config.crank_pivot)
	var r = float(config.crank_radius)
	# Keep accumulated turns in state while reducing only the trig argument.
	var trig_phase = fposmod(value,TAU)
	var radial = Vector2(cos(trig_phase),sin(trig_phase))
	var b = c+radial*r
	var delta = b-o
	var distance = delta.length()
	var u = delta/distance
	var a = float(config.rocker_pin_radius)
	var length = float(config.rod_length)
	var along = (a*a-length*length+distance*distance)/(2*distance)
	var height = sqrt(maxf(0,a*a-along*along))
	var point = o+u*along+Vector2(u.y,-u.x)*height*int(config.assembly_branch)
	var rocker_vector = point-o
	var angle = rocker_vector.angle()
	var rod = point-b
	var rocker_tangent = Vector2(-rocker_vector.y,rocker_vector.x)
	var crank_tangent = Vector2(-radial.y,radial.x)*r
	var derivative = rod.dot(crank_tangent)/rod.dot(rocker_tangent)
	var grip = o+Vector2(cos(angle),sin(angle))*float(config.grip_radius)
	return {"phase":value,"angle":angle,"rocker":o,"rocker_pin":point,"crank":c,"crank_pin":b,"grip_right":grip,"grip_left":o-(grip-o),"dangle_dphase":derivative,"wheel_angle":value*float(config.gear_ratio)}

func pose() -> Dictionary:
	if cached_phase!=phase:
		cached_pose=solve(phase)
		cached_phase=phase
	return cached_pose

func set_phase(value: float) -> void:
	assert(is_finite(value))
	var step = value-phase
	if absf(step)>1e-10: last_phase_step=step
	phase=value
	revision+=1

func advance(angular_velocity: float, dt: float) -> void:
	set_phase(phase+angular_velocity*dt)

func calculate_limits() -> Dictionary:
	var o = vec(config.rocker_pivot)
	var c = vec(config.crank_pivot)
	var delta = c-o
	var distance = delta.length()
	var u = delta/distance
	var a = float(config.rocker_pin_radius)
	var extrema: Array = []
	for side in [-1,1]:
		var radius = float(config.rod_length)+side*float(config.crank_radius)
		var along = (a*a-radius*radius+distance*distance)/(2*distance)
		var height = sqrt(maxf(0,a*a-along*along))
		var point = o+u*along+Vector2(u.y,-u.x)*height*int(config.assembly_branch)
		var phi = (point-c).angle() if side>0 else (c-point).angle()
		extrema.append({"angle":(point-o).angle(),"phase":phi})
	extrema.sort_custom(func(a_value,b_value): return a_value.angle<b_value.angle)
	return {"minimum":extrema[0],"maximum":extrema[1],"stroke_m":float(config.grip_radius)*(sin(float(extrema[1].angle))-sin(float(extrema[0].angle)))}

func seek_rocker(target: float) -> void:
	# Temporary P3 compatibility driver for the old mouse input. Choose the
	# nearest continuation of the current phase, never a branch from the sign
	# of the mouse. At a true merged dead point, retain angular continuation.
	var angle = clampf(target,float(limits.minimum.angle),float(limits.maximum.angle))
	for edge in [limits.minimum,limits.maximum]:
		if absf(angle-float(edge.angle))<1e-8:
			set_phase(phase+wrapf(float(edge.phase)-phase,-PI,PI))
			return
	var c = vec(config.crank_pivot)
	var point = vec(config.rocker_pivot)+Vector2(cos(angle),sin(angle))*float(config.rocker_pin_radius)
	var delta = point-c
	var distance = delta.length()
	var u = delta/distance
	var r = float(config.crank_radius)
	var length = float(config.rod_length)
	var along = (r*r-length*length+distance*distance)/(2*distance)
	var height = sqrt(maxf(0,r*r-along*along))
	var base = c+u*along
	var candidates: Array = []
	for sign_value in [-1,1]:
		var b = base+Vector2(-u.y,u.x)*height*sign_value
		candidates.append(wrapf((b-c).angle()-phase,-PI,PI))
	var chosen = float(candidates[0]) if absf(candidates[0])<absf(candidates[1]) else float(candidates[1])
	if absf(absf(candidates[0])-absf(candidates[1]))<0.0001 and absf(last_phase_step)>1e-10:
		for step in candidates:
			if signf(step)==signf(last_phase_step): chosen=step
	set_phase(phase+chosen)
