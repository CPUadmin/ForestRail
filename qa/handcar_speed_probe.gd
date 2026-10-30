extends SceneTree
const Model=preload("res://scripts/model.gd")
func _initialize():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../qa/handcar30"))
	var results=[]
	for ratio in [6.3]:
		for loaded in [false,true]:
			var m=Model.new();m.new_game(42)
			if loaded:
				m.accept_mission(m.current_mission())
				for c in m.state.cargo: c.slot="handcar:"+str(m.state.cargo.find(c))
			m.state.phase="route";m.state.s=100;m.state.brake=0
			for p in m.route.points:p[1]=0.0
			assert(m.handcar.config.gear_ratio==ratio)
			assert(m.hand_drive.config.air_drag_n_per_mps2==0.05)
			var phase=m.handcar.phase
			m.grab_pump()
			var samples=[]
			for i in range(7200):
				m.set_pump_target(m.handcar.pose().angle+signf(m.handcar.pose().dangle_dphase)*0.32)
				m.physics_step(1.0/60)
				if i in [599,1799,3599,7199]:samples.append(m.state.v*3.6)
			print("TUNE ",ratio," loaded=",loaded," speeds10/30/60/120=",samples)
			assert(0<samples[0] and samples[0]<samples[1] and samples[1]<samples[2] and samples[2]<samples[3])
			if loaded: assert(samples[3]<results[0].speeds_kmh[3])
			else: assert(samples[3]>=30 and samples[1]<30)
			results.append({"loaded":loaded,"mass_kg":m.train_mass(),"seconds":[10,30,60,120],"speeds_kmh":samples,"cadence_at_30_hz":(30.0/3.6)/(TAU*0.21*ratio)})
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../qa/handcar30/speed_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases":results,"success":true,"controller":"phase-following target, 60 Hz, flat road; not a human trial"},"\t"));file.close()
	quit()


