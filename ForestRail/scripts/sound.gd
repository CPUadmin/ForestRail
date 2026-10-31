extends Node

# Pause silences the machine; interface, payment and finale cues still play.
const MECHANISM_CLIPS = ["brake", "pump", "rail_clack", "gear", "cargo"]

var clips: Dictionary = {}
var voices: Array = []
var forest: AudioStreamPlayer
var engine: AudioStreamPlayer
var music: AudioStreamPlayer
var settings: Dictionary = {}
var last_rail = 0.0
var last_pump = 0.0
var pump_direction = 0
var brake_cooldown = 0.0

func _ready() -> void:
	for name in ["brake", "cargo", "coins", "finale", "gear", "pump", "rail_clack", "ui_click", "forest_loop", "engine_loop", "music_loop"]:
		clips[name] = load("res://assets/audio/" + name + ".wav")
	for i in range(6):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	forest = loop_voice("forest_loop")
	engine = loop_voice("engine_loop")
	music = loop_voice("music_loop")

func loop_voice(name: String) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	var stream = clips[name].duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.stream = stream
	add_child(player)
	return player

func play(name: String, gain: float = 1.0) -> void:
	if not clips.has(name):
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = clips[name]
			voice.set_meta("clip", name)
			voice.volume_db = linear_to_db(maxf(0.0001, float(settings.get("master", 0.65)) * float(settings.get("mechanisms", 0.7)) * gain))
			voice.play()
			return

func update(model, paused: bool, in_menu: bool, dt: float, in_cab: bool = false) -> void:
	var master = float(settings.get("master", 0.65))
	forest.volume_db = linear_to_db(maxf(0.0001, master * float(settings.get("forest", 0.6)) * (0.1 if in_cab else 0.25)))
	if not forest.playing:
		forest.play()
	music.volume_db = linear_to_db(maxf(0.0001, master * float(settings.get("music", 0.25)) * 0.18))
	if in_menu and not music.playing:
		music.play()
	elif not in_menu:
		music.stop()
	if model.state.is_empty() or paused or in_menu:
		engine.stop()
		for voice in voices:
			if voice.get_meta("clip", "") in MECHANISM_CLIPS:
				voice.stop()
		return
	if model.state.engine:
		engine.pitch_scale = 0.7 + float(model.state.throttle) * 0.55 + absf(float(model.state.v)) * 0.02
		engine.volume_db = linear_to_db(maxf(0.0001, master * float(settings.get("mechanisms", 0.7)) * (0.05 + 0.12 * float(model.state.throttle)) * (1.5 if in_cab else 1.0)))
		if not engine.playing:
			engine.play()
	else:
		engine.stop()
	if model.rail_distance - last_rail > 5.5:
		last_rail = model.rail_distance
		play("rail_clack", 0.5 if in_cab else 0.35)
	brake_cooldown -= dt
	if float(model.state.brake) > 0.15 and absf(float(model.state.v)) > 0.5 and brake_cooldown <= 0:
		play("brake", minf(0.25, float(model.state.brake) * 0.2))
		brake_cooldown = 0.65
	last_pump -= dt
	if model.pump_work > 0.1 and last_pump <= 0:
		play("pump", 0.35)
		last_pump = 0.45
