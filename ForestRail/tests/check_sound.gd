extends Node
# Sound system checks (N8): every clip loads, the buses exist, joints clack in step
# with the track, each class sounds like itself, the cab muffles the outside, pause
# silences the machine. Whether it SOUNDS good is for the owner's ears, not for tests.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Sound = preload("res://scripts/sound.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func vehicle(kind: String):
	var m = Model.new()
	m.new_game(42)
	m.state.money = 10000
	if kind != "handcar": Fixtures.equip(m, kind)
	m.state.phase = "route"
	m.state.s = 100.0
	m.state.brake = 0.0
	return m

# The dummy audio driver of the test never finishes a clip, so free the voices by hand.
func run_frames(sound, m, frames: int, speed: float, in_cab: bool = false) -> void:
	for i in range(frames):
		if i % 20 == 0:
			for voice in sound.voices: voice.stop()
		m.state.s += speed * 0.016 * float(m.state.direction)
		m.rail_distance += speed * 0.016
		m.state.v = speed
		sound.update(m, false, false, 0.016, in_cab)

func run() -> void:
	var sound = Sound.new()
	add_child(sound)
	sound.settings = {"master": 0.65, "mechanisms": 0.7, "forest": 0.6, "music": 0.25}
	await get_tree().process_frame
	for name in Sound.CLIP_NAMES:
		check(sound.clips.get(name) != null and sound.clips[name].get_length() > 0.04, "clip loads: " + name)
	for name in Sound.LOOP_NAMES:
		var stream = sound.loops[name].stream
		check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.get_length() > 0.5, "loop is set up: " + name)
	check(AudioServer.get_bus_index("Outside") != -1 and AudioServer.get_bus_index("Machine") != -1, "outside and machine buses exist")
	# menu music, then the sting when the game starts
	var m = vehicle("motorcar")
	sound.update(m, false, true, 0.016)
	check(sound.loops["music_menu"].playing, "menu plays its theme")
	sound.update(m, false, false, 0.016)
	check(int(sound.played.get("sting_start", 0)) == 1 and not sound.loops["music_menu"].playing, "starting the game plays the sting and stops the theme")
	# joints clack every 12 m
	run_frames(sound, m, 1200, 4.0)
	var clacks = int(sound.played.get("rail_tick_a", 0)) + int(sound.played.get("rail_tick_b", 0)) + int(sound.played.get("rail_tick_c", 0))
	var axle_count = sound.axle_places(m).size()
	check(clacks >= axle_count * 5 and clacks <= axle_count * 8, "every axle knocks on every joint (%d knocks, %d axles, about 6 joints in 77 m)" % [clacks, axle_count])
	# B1.4: more bodies, more axles, more knocks; the rhythm comes from the wheelbase
	var long = m
	var solo = vehicle("handcar")
	var axles = sound.axle_places(long)
	check(axles.size() == 2 * long.body_ids().size() and long.body_ids().size() >= 3, "every body brings two axles (%d axles)" % axles.size())
	check(sound.axle_places(solo).size() == 2, "a lone handcar has two axles")
	var gaps_ok = true
	for k in range(1, axles.size()): if absf(float(axles[k].s) - float(axles[k - 1].s)) < 0.3: gaps_ok = false
	check(gaps_ok, "no two axles share a place")
	var before = int(sound.played.get("rail_tick_a", 0)) + int(sound.played.get("rail_tick_b", 0)) + int(sound.played.get("rail_tick_c", 0))
	sound.axle_joints.clear()
	run_frames(sound, solo, 1200, 4.0)
	var solo_clacks = int(sound.played.get("rail_tick_a", 0)) + int(sound.played.get("rail_tick_b", 0)) + int(sound.played.get("rail_tick_c", 0)) - before
	check(solo_clacks > 0 and solo_clacks < clacks / 2, "a lone car knocks much less than a train (%d against %d)" % [solo_clacks, clacks])
	var creaks = int(sound.played.get("pump", 0))
	solo.handcar.set_phase(0.1)
	sound.update(solo, false, false, 0.25)
	solo.pump_work = 1.0
	for phase in [0.4, PI + 0.1, PI + 0.6, TAU + 0.1]:
		for voice in sound.voices: voice.stop()
		solo.handcar.set_phase(phase)
		sound.update(solo, false, false, 0.25)
	check(int(sound.played.get("pump", 0)) - creaks == 2, "each powered half turn plays one creak")
	solo.pump_work = 0.0
	solo.handcar.set_phase(TAU + PI + 0.1)
	sound.update(solo, false, false, 0.25)
	check(int(sound.played.get("pump", 0)) - creaks == 2, "coasting does not play a lever creak")
	var train_clacks = solo_clacks
	before = int(sound.played.get("rail_tick_a", 0)) + int(sound.played.get("rail_tick_b", 0)) + int(sound.played.get("rail_tick_c", 0))
	sound.axle_joints.clear()
	run_frames(sound, long, 60, 0.0)
	check(int(sound.played.get("rail_tick_a", 0)) + int(sound.played.get("rail_tick_b", 0)) + int(sound.played.get("rail_tick_c", 0)) == before, "standing still it is silent")
	# petrol: idle at low revs, the run loop takes over at high revs, start and stall cues
	m = vehicle("motorcar")
	m.start_engine(true)
	sound.update(m, false, false, 0.016)
	check(int(sound.played.get("petrol_start", 0)) >= 1, "starting the petrol engine plays the starter")
	run_frames(sound, m, 200, 0.0)
	check(sound.loops["petrol_idle"].playing and sound.loops["petrol_idle"].volume_db > sound.loops["petrol_run"].volume_db or not sound.loops["petrol_run"].playing, "idle loop dominates at low revs")
	m.set_gear(3)
	m.state.throttle = 0.9
	run_frames(sound, m, 400, 6.0)
	check(sound.loops["petrol_run"].playing and sound.loops["petrol_run"].volume_db > sound.loops["petrol_idle"].volume_db or not sound.loops["petrol_idle"].playing, "run loop dominates at high revs")
	m.state.engine = false
	sound.update(m, false, false, 0.016)
	check(int(sound.played.get("petrol_stall", 0)) >= 1, "losing the engine under load plays the stall")
	# steam: chuffs with the regulator open, fire and hiss
	m = vehicle("steam")
	var boiler = m.boiler()
	boiler.pressure = 0.9
	boiler.heat = 1.0
	boiler.lit = true
	m.state.engine = true
	m.state.throttle = 0.6
	run_frames(sound, m, 600, 4.0)
	check(int(sound.played.get("steam_chuff", 0)) >= 8, "steam chuffs follow the wheels (%d)" % int(sound.played.get("steam_chuff", 0)))
	check(sound.loops["steam_hiss"].playing and sound.loops["fire_crackle"].playing, "steam engine hisses and the fire crackles")
	var chuffs = int(sound.played.get("steam_chuff", 0))
	m.state.throttle = 0.0
	run_frames(sound, m, 300, 4.0)
	check(int(sound.played.get("steam_chuff", 0)) == chuffs, "no chuffs with the regulator closed")
	# electric: hum while powered, contactor on throttle
	m = vehicle("locomotive")
	m.state.throttle = 0.5
	run_frames(sound, m, 120, 3.0)
	check(sound.loops["electric_hum"].playing and int(sound.played.get("contactor", 0)) >= 1, "electric hum and the contactor click")
	m.state.v = 0.0
	sound.update(m, false, false, 0.016)
	var calm_level = sound.loops["amb_wind"].volume_db
	m.state.v = 30.0
	sound.update(m, false, false, 0.016)
	check(sound.loops["amb_wind"].volume_db > calm_level, "apparent wind gets louder with speed")
	m.weather_force = {"cloud": 1.0, "rain": 1.0, "fog": 0.0}
	sound.update(m, false, false, 0.016)
	check(sound.loops["amb_rain"].playing and sound.loops["amb_rain"].bus == "Outside", "rain plays through the outside bus")
	m.weather_effect = 0.0
	sound.update(m, false, false, 0.016)
	check(not sound.loops["amb_rain"].playing, "disabling weather silences rain")
	m.weather_effect = 1.0
	m.weather_force.clear()
	# the cab muffles the outside and keeps the machine
	var index = AudioServer.get_bus_index("Outside")
	var open_cutoff = AudioServer.get_bus_effect(index, 0).cutoff_hz
	run_frames(sound, m, 120, 3.0, true)
	check(AudioServer.get_bus_effect(index, 0).cutoff_hz < open_cutoff * 0.3 and sound.cab_mix > 0.99, "the cab low-passes the outside")
	run_frames(sound, m, 120, 3.0, false)
	check(AudioServer.get_bus_effect(index, 0).cutoff_hz > 10000.0, "leaving the cab opens the outside again")
	# pause: the machine is silent, ambience stays
	sound.update(m, true, false, 0.016)
	check(not sound.loops["electric_hum"].playing and sound.loops["amb_wind"].playing, "pause silences the machine, ambience stays")
	# B6.1: the pole truck has its own knock for every kind of ground, and the clips are different from each other
	for clip in ["pole_plant_dense", "pole_plant_clay", "pole_plant_stones", "pole_plant_roots", "pole_lift"]:
		check(sound.clips.has(clip) and sound.clips[clip] != null, "the clip %s is loaded" % clip)
	var lengths: Dictionary = {}
	for clip in ["pole_plant_dense", "pole_plant_clay", "pole_plant_stones", "pole_plant_roots"]:
		lengths[snappedf(float(sound.clips[clip].get_length()), 0.01)] = true
	check(lengths.size() >= 3, "the four knocks of the pole differ (%d lengths)" % lengths.size())
	var pole_model = vehicle("pole")
	pole_model.pole.build(int(pole_model.route.seed_value), float(pole_model.route.length_m), pole_model.route.station_s)
	var grounds: Dictionary = {}
	for seg in pole_model.pole.segments: grounds[str(seg[2])] = true
	check(grounds.size() >= 3, "the line has several grounds for the pole to knock on (%d)" % grounds.size())
	print("SOUND CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
