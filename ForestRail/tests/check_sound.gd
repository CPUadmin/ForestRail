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
	var clacks = int(sound.played.get("rail_clack_a", 0)) + int(sound.played.get("rail_clack_b", 0))
	check(clacks >= 3 and clacks <= 8, "joints clack in step with the track (%d for about 77 m)" % clacks)
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
	print("SOUND CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
