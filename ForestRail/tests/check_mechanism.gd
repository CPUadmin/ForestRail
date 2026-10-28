extends Node

const Mechanism = preload("res://scripts/handcar_mechanism.gd")
const Art = preload("res://scripts/art_v3.gd")
const Model = preload("res://scripts/model.gd")
var checks = 0
var failures: Array = []
var max_rod_error_m = 0.0
var max_sprite_error_px = 0.0
var max_seek_reversal_step = 0.0
var out_dir = ""

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		if failures.size()<60: failures.append(label);print("FAIL: ",label)

func _ready() -> void:
	call_deferred("run")

func sprite_point(art, part: Dictionary, source: Array) -> Vector2:
	return part.position+((art.vec(source)-art.pivot(part.id))*float(part.scale)).rotated(float(part.angle))

func run() -> void:
	out_dir=ProjectSettings.globalize_path("res://../qa/v3_p3")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mechanism-output="): out_dir=arg.trim_prefix("--mechanism-output=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var mechanism=Mechanism.new()
	var art=Art.new()
	check(mechanism.full_rotation_valid(),"full crank rotation on fixed assembly branch")
	check(mechanism.limits.stroke_m>=0.45 and mechanism.limits.stroke_m<=0.65,"real grip stroke 0.45..0.65 m")
	var start=mechanism.phase
	var previous=mechanism.pose()
	for direction in [1,-1]:
		for i in range(36000):
			mechanism.advance(direction*TAU/6.0,1.0/60)
			var pose=mechanism.pose()
			var error=absf(pose.rocker_pin.distance_to(pose.crank_pin)-float(mechanism.config.rod_length))
			max_rod_error_m=maxf(max_rod_error_m,error)
			check(error<=0.0005,"rigid rod across 100 full turns and reverse")
			check(absf(pose.rocker.distance_to(pose.rocker_pin)-float(mechanism.config.rocker_pin_radius))<0.00001,"rigid rocker")
			check(absf(pose.crank.distance_to(pose.crank_pin)-float(mechanism.config.crank_radius))<0.00001,"rigid crank")
			check(absf(pose.phase-previous.phase-direction*TAU/360)<1e-8,"phase remains unwrapped and continuous")
			check(absf(pose.wheel_angle/float(mechanism.config.gear_ratio)-pose.phase)<1e-10,"fixed wheel ratio")
			previous=pose
	check(absf(mechanism.phase-start)<1e-8,"100 forward and reverse turns return to original phase")
	var driven=Mechanism.new()
	var driven_start=driven.phase
	var middle=(float(driven.limits.minimum.angle)+float(driven.limits.maximum.angle))*0.5
	var amplitude=(float(driven.limits.maximum.angle)-float(driven.limits.minimum.angle))*0.5
	for i in range(1,36001):
		var before_phase=driven.phase
		driven.seek_rocker(middle+amplitude*sin(i*TAU/360))
		check(absf(driven.phase-before_phase)<0.10,"legacy target follows a local phase through dead points")
	check(absf(absf(driven.phase-driven_start)-100*TAU)<0.01,"100 complete rocking cycles retain accumulated crank turns")
	for edge in [mechanism.limits.minimum,mechanism.limits.maximum]:
		var pose=mechanism.solve(edge.phase)
		check(absf(pose.angle-float(edge.angle))<0.00001,"analytic rocker extreme")
		check(absf(pose.dangle_dphase)<0.00001,"dead-point derivative is zero")
	for i in range(721):
		var pose=mechanism.solve(i*TAU/720)
		for part in art.mechanism_parts(pose):
			var pins=art.assets[part.id].get("pins_px",{})
			var targets={}
			if part.id=="mechanism/lever": targets={"pivot":pose.rocker,"link":pose.rocker_pin}
			if part.id=="mechanism/crank": targets={"start":pose.crank,"end":pose.crank_pin}
			if part.id=="mechanism/connecting_rod": targets={"start":pose.rocker_pin,"end":pose.crank_pin}
			if part.id=="mechanism/support": targets={"pivot":pose.rocker}
			for pin in targets:
				for facing in [-1,1]:
					for zoom in [0.75,1.0,1.5]:
						var outer=Transform2D(0.10,Vector2(zoom*facing,zoom),0,Vector2(712,500))
						var error=(outer*sprite_point(art,part,pins[pin])).distance_to(outer*(targets[pin]*96))
						max_sprite_error_px=maxf(max_sprite_error_px,error)
						check(error<=1.0,"transformed sprite pin "+part.id+" "+pin)
	# Reversing the target midstroke must retrace a nearby phase, rather than
	# switching to the remote inverse solution. Test both phase directions.
	for direction in [-1,1]:
		for i in range(180):
			mechanism.set_phase(i*TAU/180+0.007)
			var pose=mechanism.pose()
			if absf(pose.dangle_dphase)<0.03: continue
			var phi=mechanism.phase
			var alpha=pose.angle
			mechanism.seek_rocker(alpha+direction*0.00001)
			mechanism.seek_rocker(alpha)
			var error=absf(mechanism.phase-phi)
			max_seek_reversal_step=maxf(max_seek_reversal_step,error)
			check(error<0.002,"midstroke input reversal has no phase jump")
	# A stationary repeated target and repeated render reads have no side effects.
	mechanism.set_phase(0.39)
	var phase=mechanism.phase
	var alpha=mechanism.pose().angle
	for i in range(100):
		mechanism.seek_rocker(alpha)
		var pose=mechanism.pose()
		check(absf(mechanism.phase-phase)<0.0001,"held target does not drift")
		check(pose==mechanism.pose(),"same phase produces one cached pose")
	var model=Model.new()
	# Check actual supplied alpha silhouettes over the whole rocker sweep.
	# Cargo must not hide the moving wooden grip, even at the lowest stroke.
	var beam_image=art.textures["mechanism/lever"].atlas.get_image()
	var sack_image=load("res://assets/art_p2/sack.png").get_image()
	if beam_image.is_compressed(): beam_image.decompress()
	if sack_image.is_compressed(): sack_image.decompress()
	var beam_meta=art.assets["mechanism/lever"]
	var region=beam_meta.region_px
	var sack_spec=art.Geometry.data().cargo.sack
	var sr=sack_spec.region_px
	var sack_size=art.cargo_size("sack",float(sr[2])/float(sr[3]))
	var max_overlap_samples=0
	for i in range(73):
		var pose=mechanism.solve(i*TAU/72)
		var beam={}
		for part in art.mechanism_parts(pose):
			if part.id=="mechanism/lever": beam=part
		var overlap=0
		for y in range(int(region[1]),int(region[1]+region[3]),4):
			for x in range(int(region[0]),int(region[0]+region[2]),4):
				var color=beam_image.get_pixel(x,y)
				if color.a<0.5 or (color.r>0.90 and color.g<0.12 and color.b<0.12): continue
				var point=sprite_point(art,beam,[x,y])
				for index in range(2):
					var foot=art.slot_position("handcar",index,2,"sack")+Vector2(0,19)
					var rect=Rect2(foot-Vector2(sack_size.x*0.5,sack_size.y),sack_size)
					if not rect.has_point(point): continue
					var uv=(point-rect.position)/rect.size
					if sack_image.get_pixel(int(sr[0]+uv.x*sr[2]),int(sr[1]+uv.y*sr[3])).a>=0.5: overlap+=1
		max_overlap_samples=maxi(max_overlap_samples,overlap)
		check(overlap==0,"cargo alpha leaves moving beam visible through full turn")
	model.new_game(42)
	model.handcar.set_phase(123*TAU+0.39)
	var saved=model.serialize()
	var copy=Model.new()
	check(copy.restore(saved) and copy.handcar.phase==model.handcar.phase,"phase persists without losing turns")
	saved.erase("handcar_phase")
	check(copy.restore(saved) and is_finite(copy.handcar.phase),"legacy save receives geometric phase")
	saved.handcar_phase=INF
	check(not copy.restore(saved),"non-finite phase is rejected before restoring state")
	model.pump_last_direction=-1
	var before=art.mechanism_pose(model)
	model.pump_last_direction=1
	check(art.mechanism_pose(model)==before,"render ignores old mouse direction")
	model.state.money=10000
	model.buy_vehicle("motorcar")
	model.state.v=3.0
	model.state.throttle=0.0
	check(model.set_gear(1) and model.set_gear(2) and model.state.v==3.0,"motor gears change while moving with no teleport or speed reset")
	model.state.throttle=0.5
	check(not model.set_gear(1) and model.state.gear==2,"loaded motor transmission rejects shift under throttle")
	var report={"checks":checks,"failures":failures,"turns_each_direction":100,"max_rod_length_error_m":max_rod_error_m,"max_transformed_sprite_pin_error_px":max_sprite_error_px,"max_midstroke_return_phase_error_rad":max_seek_reversal_step,"max_beam_cargo_overlap_samples":max_overlap_samples,"stroke_m":mechanism.limits.stroke_m,"rocker_limits":mechanism.limits,"config":mechanism.config,"scope":"P3 kinematics only; hand force and train/wheel coupling remain P4"}
	var file=FileAccess.open(out_dir.path_join("mechanism_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MECHANISM CHECKS ",checks,"; FAILURES ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
