extends Node

# N8: layered ambience, machine sound per class, rail joints in step with the track,
# a muffled cab. All the audio is synthesised by tools/audio_sources/make_audio.py.
# Pause silences the machine; interface, payment and finale cues always play.
const MECHANISM_CLIPS = ["pump", "rail_clack", "rail_clack_a", "rail_clack_b", "gear", "cargo", "steam_chuff", "steam_blow", "petrol_start", "petrol_stall", "contactor", "coupler_clank"]
const CLIP_NAMES = ["pump", "rail_clack", "rail_clack_a", "rail_clack_b", "gear", "cargo", "coins", "finale", "ui_click", "sting_start", "steam_chuff", "steam_blow", "petrol_start", "petrol_stall", "contactor", "coupler_clank", "bird_1", "bird_2", "bird_3", "bird_4"]
const LOOP_NAMES = ["amb_wind", "amb_insects", "amb_water", "music_menu", "steam_hiss", "fire_crackle", "petrol_idle", "petrol_run", "electric_hum", "electric_whine", "brake"]
const MACHINE_LOOPS = ["steam_hiss", "fire_crackle", "petrol_idle", "petrol_run", "electric_hum", "electric_whine", "brake"]
const INTERFACE_CLIPS = ["coins", "finale", "ui_click", "sting_start"]
const JOINT_SPACING = 12.0
const CHUFF_SPACING = 0.43

var clips: Dictionary = {}
var loops: Dictionary = {}
var voices: Array = []
var settings: Dictionary = {}
var played: Dictionary = {}
var last_joint = -999999
var last_chuff = 0.0
var last_pump = 0.0
var bird_timer = 4.0
var blow_timer = 0.0
var cab_mix = 0.0
var was_menu = true
var engine_was_on = false
var last_throttle = 0.0
var last_gear = 0
var petrol_delay = 0.0
var contactor_on = false

func _ready() -> void:
	ensure_bus("Outside")
	ensure_bus("Machine")
	for name in CLIP_NAMES:
		clips[name] = load("res://assets/audio/" + name + ".wav")
	for i in range(12):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for name in LOOP_NAMES:
		loops[name] = loop_voice(name)

func ensure_bus(bus_name: String) -> int:
	var index = AudioServer.get_bus_index(bus_name)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.add_bus_effect(index, AudioEffectLowPassFilter.new())
	return index

func set_cutoff(bus_name: String, hertz: float) -> void:
	var index = AudioServer.get_bus_index(bus_name)
	if index == -1: return
	var effect = AudioServer.get_bus_effect(index, 0)
	if effect is AudioEffectLowPassFilter: effect.cutoff_hz = hertz

func loop_voice(name: String) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	var stream = load("res://assets/audio/" + name + ".wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.stream = stream
	player.bus = "Machine" if name in MACHINE_LOOPS else ("Outside" if name.begins_with("amb_") else "Master")
	add_child(player)
	return player

func bus_for(name: String) -> String:
	if name.begins_with("bird"): return "Outside"
	return "Machine" if name in MECHANISM_CLIPS else "Master"

func play(name: String, gain: float = 1.0, pitch: float = 1.0) -> void:
	if not clips.has(name):
		return
	var master = float(settings.get("master", 0.65))
	var level = master * gain
	if name in MECHANISM_CLIPS: level *= float(settings.get("mechanisms", 0.7))
	elif name.begins_with("bird"): level *= float(settings.get("forest", 0.6))
	elif name in INTERFACE_CLIPS: level *= float(settings.get("interface", 0.8))
	for voice in voices:
		if not voice.playing:
			voice.stream = clips[name]
			voice.bus = bus_for(name)
			voice.set_meta("clip", name)
			voice.pitch_scale = pitch
			voice.volume_db = linear_to_db(maxf(0.0001, level))
			voice.play()
			played[name] = int(played.get(name, 0)) + 1
			return

func run_loop(name: String, volume: float, active: bool, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = loops[name]
	if not active or volume < 0.0006:
		if player.playing: player.stop()
		return
	player.volume_db = linear_to_db(volume)
	player.pitch_scale = clampf(pitch, 0.2, 4.0)
	if not player.playing: player.play()

func stop_machine() -> void:
	for name in MACHINE_LOOPS: run_loop(name, 0.0, false)
	for voice in voices:
		if voice.get_meta("clip", "") in MECHANISM_CLIPS: voice.stop()

func update(model, paused: bool, in_menu: bool, dt: float, in_cab: bool = false) -> void:
	var master = float(settings.get("master", 0.65))
	var nature = master * float(settings.get("forest", 0.6))
	var machine = master * float(settings.get("mechanisms", 0.7))
	cab_mix = move_toward(cab_mix, 1.0 if in_cab else 0.0, dt * 3.0)
	set_cutoff("Outside", lerpf(20000.0, 1300.0, cab_mix))
	set_cutoff("Machine", lerpf(20000.0, 8000.0, cab_mix))
	var in_game = not in_menu and not model.state.is_empty()
	# music: the menu theme, and a short sting when the game starts
	run_loop("music_menu", master * float(settings.get("music", 0.25)) * 0.55, in_menu)
	if was_menu and not in_menu: play("sting_start", 0.55)
	was_menu = in_menu
	# ambience: wind always, insects and the lake where they belong, birds now and then
	var speed = 0.0 if not in_game else absf(float(model.state.v))
	run_loop("amb_wind", nature * (0.12 if in_menu else 0.34 * (1.0 - 0.55 * cab_mix)), true)
	run_loop("amb_insects", nature * 0.07 * (0.4 if speed > 4.0 else 1.0) * (1.0 - 0.7 * cab_mix), in_game)
	var lake = 0.0
	if in_game and model.route.station_s.size() > 3:
		lake = 1.0 - smoothstep(12.0, 65.0, absf(float(model.state.s) - float(model.route.station_s[3])))
	run_loop("amb_water", nature * 0.3 * lake * (1.0 - 0.5 * cab_mix), in_game and lake > 0.02)
	bird_timer -= dt
	if bird_timer <= 0.0:
		bird_timer = randf_range(2.5, 7.5)
		if not paused and not in_menu: play("bird_%d" % randi_range(1, 4), randf_range(0.5, 1.0) * (0.35 if speed > 5.0 else 1.0), randf_range(0.93, 1.07))
	if not in_game or paused:
		stop_machine()
		engine_was_on = false
		return
	var kind = model.vehicle_id()
	var throttle = float(model.state.throttle)
	var brake = float(model.state.brake)
	var loud = 1.0 + 0.35 * cab_mix
	# rail joints: a double clack at every joint, in step with the track under the wheels
	var joint = floori(float(model.state.s) / JOINT_SPACING)
	if joint != last_joint:
		if last_joint != -999999 and speed > 0.25:
			play("rail_clack_a" if joint % 2 == 0 else "rail_clack_b", (0.16 + 0.05 * minf(speed, 8.0)) * loud, 0.9 + minf(speed, 10.0) * 0.02)
		last_joint = joint
	run_loop("brake", machine * 0.3 * brake * minf(1.0, speed / 5.0), brake > 0.1 and speed > 0.8, 0.9 + speed * 0.03)
	last_pump -= dt
	if model.pump_work > 0.1 and last_pump <= 0:
		play("pump", 0.35)
		last_pump = 0.45
	var engine_on = bool(model.state.engine)
	for name in ["steam_hiss", "fire_crackle"]: if kind != "steam" and not (kind == "pneumatic" and name == "steam_hiss"): run_loop(name, 0.0, false)
	for name in ["petrol_idle", "petrol_run"]: if kind != "motorcar": run_loop(name, 0.0, false)
	for name in ["electric_hum", "electric_whine"]: if kind != "locomotive": run_loop(name, 0.0, false)
	if kind == "steam":
		var boiler = model.boiler()
		var pressure = float(boiler.pressure)
		# at speed the exhaust beats are thinned to at most 8 a second
		if model.rail_distance - last_chuff >= maxf(CHUFF_SPACING, speed / 8.0):
			last_chuff = model.rail_distance
			if throttle > 0.03 and pressure > 0.2 and speed > 0.05:
				play("steam_chuff", (0.3 + 0.5 * throttle) * loud, randf_range(0.94, 1.06) * (0.85 + minf(speed, 6.0) * 0.03))
		run_loop("steam_hiss", machine * 0.22 * pressure * (0.3 + throttle) * loud, pressure > 0.05)
		run_loop("fire_crackle", machine * 0.4 * float(boiler.heat) * loud, bool(boiler.lit) and float(boiler.heat) > 0.03)
		blow_timer -= dt
		if bool(boiler.venting) and blow_timer <= 0.0:
			play("steam_blow", 0.5 * loud)
			blow_timer = 2.4
	elif kind == "pneumatic":
		# A quiet hiss by the valve and a puff of air for every beat, thinned at speed.
		var air = float(model.state.fleet_by_id.pneumatic.fuel) / 150.0
		if model.rail_distance - last_chuff >= maxf(CHUFF_SPACING * 1.4, speed / 7.0):
			last_chuff = model.rail_distance
			if throttle > 0.03 and air > 0.02 and speed > 0.05:
				play("steam_chuff", (0.12 + 0.25 * throttle) * loud, randf_range(1.15, 1.3))
		run_loop("steam_hiss", machine * 0.1 * minf(1.0, air * 2.0) * (0.2 + throttle) * loud, air > 0.02)
	elif kind == "motorcar":
		if engine_on and not engine_was_on: petrol_delay = 2.0; play("petrol_start", 0.6 * loud)
		if engine_was_on and not engine_on and last_throttle > 0.3 and last_gear > 0: play("petrol_stall", 0.55 * loud)
		petrol_delay = maxf(0.0, petrol_delay - dt)
		var ready = smoothstep(0.0, 0.6, 2.0 - petrol_delay)
		var rpm = lerpf(800.0, 6000.0, model.engine_rpm_fraction())
		var idle_share = 1.0 - smoothstep(1400.0, 2300.0, rpm)
		var run_share = smoothstep(1200.0, 2300.0, rpm)
		run_loop("petrol_idle", machine * 0.55 * idle_share * ready * loud, engine_on, clampf(rpm / 800.0, 1.0, 2.2))
		run_loop("petrol_run", machine * 0.5 * run_share * ready * loud, engine_on, clampf(rpm / 4200.0, 0.45, 1.5))
	elif kind == "locomotive":
		var powered = float(model.state.fleet_by_id.locomotive.fuel) > 0.0
		var regen = clampf(model.regen_kw * 0.4, 0.0, 0.15)
		run_loop("electric_hum", machine * (0.14 + 0.2 * throttle + 0.03 * minf(speed, 8.0)) * loud, powered, 0.75 + minf(speed, 12.0) * 0.07)
		run_loop("electric_whine", machine * (0.02 + 0.14 * throttle + regen) * loud, powered and (throttle > 0.02 or regen > 0.01 or speed > 0.5), 0.8 + minf(speed, 12.0) * 0.1)
		var contact = throttle > 0.03 or brake > 0.05
		if contact != contactor_on:
			contactor_on = contact
			play("contactor", 0.45 * loud)
	engine_was_on = engine_on
	last_throttle = throttle
	last_gear = int(model.state.gear)
