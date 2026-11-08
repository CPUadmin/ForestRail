extends Node
# N9: the settings menu. Every control is real: it changes a value the game reads, applies at
# once, is kept by "Применить", undone by "Отменить" or Esc, and a damaged settings file
# cannot break the start. Tabs are driven through the real buttons.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var checks = 0
var failures: Array = []
var out_dir = ""

func _ready() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func frame(count: int = 2) -> void:
	for i in range(count):
		game.update_hud(); game.art_world.update_view(); game.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func find_button(text_part: String):
	for b in game.overlay.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text.contains(text_part): return b
	return null

func press(text_part: String) -> bool:
	var b = find_button(text_part)
	if b == null or b.disabled: return false
	b.pressed.emit()
	await frame(2)
	return true

func key_event(code: int) -> InputEventKey:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e

func run() -> void:
	out_dir = ProjectSettings.globalize_path("res://../qa/v3_p7")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://main.tscn").instantiate(); game.test_mode = true
	get_tree().root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.saves.directory = out_dir.path_join("isolated_profile_settings"); DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.settings_path = game.saves.directory.path_join("settings.json")
	if FileAccess.file_exists(game.settings_path): DirAccess.remove_absolute(game.settings_path)
	game.copy_settings(game.settings, game.DEFAULT_SETTINGS)
	game.apply_settings()
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.2).timeout
	# the menu opens from the main menu and shows every tab
	game.screen = "menu"; game.rebuild()
	game.show_modal("settings")
	await frame(3)
	check(game.modal_kind == "settings", "the menu opens the settings")
	for tab in game.SETTINGS_TABS:
		check(await press(tab) or game.settings_tab == tab, "tab " + tab + " can be opened")
		await frame(2)
		check(game.settings_tab == tab and find_button("Применить") != null and find_button("Отменить") != null and find_button("По умолчанию") != null, tab + ": apply, cancel and default are there")
		await shot("settings_" + tab)
	# sound: sliders reach the sound system
	game.settings_tab = "Звук"; game.rebuild(); await frame(2)
	var sliders = game.overlay.find_children("*", "HSlider", true, false)
	check(sliders.size() == 5, "five volume sliders on the sound tab (%d)" % sliders.size())
	sliders[4].value = 0.5
	check(is_equal_approx(float(game.settings.interface), 0.5) and game.sound.settings == game.settings, "the interface slider changes the live setting the sound reads")
	game.sound.play("coins", 1.0)
	var coin_level = -999.0
	for voice in game.sound.voices:
		if voice.get_meta("clip", "") == "coins" and voice.playing: coin_level = voice.volume_db
	check(absf(coin_level - linear_to_db(float(game.settings.master) * 0.5)) < 0.1, "interface volume scales the coin sound (%.1f dB)" % coin_level)
	check(await press("Интерфейс"), "a sound test button plays")
	# graphics: each choice changes what it says it changes
	game.settings_tab = "Экран"; game.settings_fold["screen_more"] = true; game.rebuild(); await frame(2)
	check(await press("Мерцание ламп и искры") and not game.light_flicker_enabled(), "graphics can disable light flicker separately")
	check(await press("Мерцание ламп и искры") and game.light_flicker_enabled(), "graphics can restore light flicker")
	var weather_reference = game.model.weather_at(1800.0)
	check(await press("Быстрее"), "graphics can speed up weather changes")
	await frame(2)
	var faster_weather = game.model.weather_at(900.0)
	check(game.model.weather_frequency == 2.0 and is_equal_approx(float(faster_weather.rain), float(weather_reference.rain)) and is_equal_approx(float(faster_weather.cloud), float(weather_reference.cloud)), "weather changes twice as fast without changing the clock")
	await press("Обычно")
	await press("60 Гц")
	check(int(game.settings.instrument_hz) == 60, "instrument refresh 60 Hz is stored")
	await press("120")
	check(Engine.max_fps == 120, "the frame cap reaches the engine")
	await press("Без ограничения")
	check(Engine.max_fps == 0, "and can be lifted")
	await press("4×")
	check(get_viewport().msaa_2d == Viewport.MSAA_4X, "anti-aliasing reaches the viewport")
	await press("Выкл.")
	check(get_viewport().msaa_2d == Viewport.MSAA_DISABLED, "and can be turned off")
	await press("Вертикальная синхронизация")
	check(not bool(game.settings.vsync) and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "vsync turns off")
	await press("Вертикальная синхронизация")
	check(bool(game.settings.vsync) and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED, "and on")
	await press("Окно без рамки")
	check(bool(game.settings.borderless) and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), "borderless window")
	await press("Окно без рамки")
	check(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), "and with a frame again")
	await press("1280")
	check(int(game.settings.window_size) == 0 and DisplayServer.window_get_size() == Vector2i(1280, 720), "window size 1280x720")
	await press("1600")
	check(DisplayServer.window_get_size() == Vector2i(1600, 900), "and back to 1600x900")
	# controls: sensitivity and key rebinding with real key events
	game.settings_tab = "Игра"; game.settings_fold["keys_more"] = true; game.rebuild(); await frame(2)
	check(await press("Кабина"), "the cab key can be chosen for rebinding")
	check(game.awaiting_key == "cab", "the menu waits for a key")
	get_tree().root.push_input(key_event(KEY_T), true)
	await frame(2)
	check(int(game.settings.keys.cab) == KEY_T and game.awaiting_key == "", "the cab key is T now")
	await press("Карта")
	get_tree().root.push_input(key_event(KEY_T), true)
	await frame(2)
	check(int(game.settings.keys.map) == KEY_T and int(game.settings.keys.cab) == KEY_M, "taking a key from another action swaps them")
	await press("Карта")
	get_tree().root.push_input(key_event(KEY_ESCAPE), true)
	await frame(2)
	check(game.awaiting_key == "" and int(game.settings.keys.map) == KEY_T and game.modal_kind == "settings", "Esc while choosing a key only cancels the choice")
	# game and accessibility tabs
	game.settings_tab = "Игра"; game.rebuild(); await frame(2)
	await press("5 мин")
	check(int(game.settings.autosave) == 300, "the autosave interval is stored")
	game.settings_tab = "Экран"; game.rebuild(); await frame(2)
	await press("Без тряски и мерцания")
	check(bool(game.settings.reduce_motion), "reduced motion on")
	# cancel puts everything back
	await press("Отменить")
	check(game.modal_kind == "", "the menu closes")
	check(int(game.settings.keys.cab) == KEY_E and int(game.settings.keys.map) == KEY_M and not bool(game.settings.reduce_motion) and int(game.settings.autosave) == 60 and int(game.settings.instrument_hz) == 30, "cancel restores every value")
	check(not FileAccess.file_exists(game.settings_path), "and nothing was written to the file")
	# apply keeps and saves
	game.show_modal("settings")
	await frame(2)
	game.settings.text_scale = 1.25
	game.settings.reduce_motion = true
	game.settings.keys.cab = KEY_V
	game.settings.autosave = 30
	game.apply_settings()
	await press("Применить")
	check(game.modal_kind == "" and FileAccess.file_exists(game.settings_path), "apply closes the menu and writes the file")
	game.copy_settings(game.settings, game.DEFAULT_SETTINGS)
	game.load_settings()
	check(is_equal_approx(float(game.settings.text_scale), 1.25) and bool(game.settings.reduce_motion) and int(game.settings.keys.cab) == KEY_V and int(game.settings.autosave) == 30, "the saved values load back")
	# Esc closes without saving too
	game.show_modal("settings")
	await frame(2)
	game.settings.master = 0.1
	game.apply_settings()
	get_tree().root.push_input(key_event(KEY_ESCAPE), true)
	await frame(2)
	check(game.modal_kind == "" and not is_equal_approx(float(game.settings.master), 0.1), "Esc puts the old volume back")
	# defaults
	game.show_modal("settings")
	await frame(2)
	await press("По умолчанию")
	check(is_equal_approx(float(game.settings.text_scale), 1.0) and not bool(game.settings.reduce_motion) and int(game.settings.keys.cab) == KEY_E and game.modal_kind == "settings", "defaults come back live")
	await press("Отменить")
	check(is_equal_approx(float(game.settings.text_scale), 1.25), "and cancelling after defaults returns to the saved values")
	# the effects themselves
	game.copy_settings(game.settings, game.DEFAULT_SETTINGS)
	game.apply_settings()
	game.model.new_game(42, 1)
	game.model.state.money = 5000
	Fixtures.equip(game.model, "motorcar")
	game.model.state.v = 5.0
	game.model.state.engine = true
	game.cab_jolt = 1.0
	game.time = 1.234
	game.settings.reduce_motion = true
	check(game.cab_shake() == Vector2.ZERO, "reduced motion stills the cab")
	game.settings.reduce_motion = false
	game.settings.cab_shake = 0.0
	check(game.cab_shake() == Vector2.ZERO, "shake 0 stills the cab")
	game.settings.cab_shake = 1.0
	check(game.cab_shake() != Vector2.ZERO, "and full shake moves it")
	# hot keys follow the setting
	game.settings.keys.cab = KEY_V
	game.screen = "game"
	game.paused = false
	game.model.state.phase = "route"
	game.model.state.engine = false
	get_tree().root.push_input(key_event(KEY_E), true)
	await frame(2)
	check(not game.cab_view, "the old cab key does nothing")
	get_tree().root.push_input(key_event(KEY_V), true)
	await frame(2)
	check(game.cab_view, "the new cab key opens the cab")
	game.cab_view = false
	game.copy_settings(game.settings, game.DEFAULT_SETTINGS)
	game.apply_settings()
	# the instruments redraw at the chosen rate
	game.model.new_game(42, 1)
	game.model.state.money = 5000
	Fixtures.equip(game.model, "motorcar")
	game.screen = "game"
	game.rebuild()
	await frame(3)
	check(game.instruments != null, "the instruments exist in the game")
	if game.instruments != null:
		game.settings.instrument_hz = 60
		game.instruments.redraw_clock = 0.0
		game.instruments._process(1.0 / 40.0)
		var fast = game.instruments.redraw_clock == 0.0
		game.settings.instrument_hz = 30
		game.instruments.redraw_clock = 0.0
		game.instruments._process(1.0 / 40.0)
		check(fast and game.instruments.redraw_clock > 0.0, "60 Hz redraws at 40 fps, 30 Hz waits")
	game.copy_settings(game.settings, game.DEFAULT_SETTINGS)
	# a damaged file
	var file = FileAccess.open(game.settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"master": "loud", "music": 7, "text_scale": 99, "fps_cap": 17, "msaa": 3, "window_size": 9, "autosave": 5, "instrument_hz": 1000, "fullscreen": "yes", "vsync": 3, "night_light": 5, "weather": 9, "keys": {"map": 27, "ice": 0, "cab": "x"}, "sensitivity": null}))
	file.close()
	game.copy_settings(game.settings, game.DEFAULT_SETTINGS)
	game.load_settings()
	check(is_equal_approx(float(game.settings.master), 0.65) and is_equal_approx(float(game.settings.music), 1.0) and is_equal_approx(float(game.settings.text_scale), 1.5), "bad and out of range numbers are replaced or clamped")
	check(int(game.settings.fps_cap) == 0 and int(game.settings.msaa) == 0 and int(game.settings.window_size) == 2 and int(game.settings.autosave) == 60 and int(game.settings.instrument_hz) == 60, "choices outside the list fall back")
	check(is_equal_approx(float(game.settings.night_light), 1.0) and int(game.settings.weather) == 0, "night brightness is clamped and an unknown weather choice falls back to normal")
	check(not bool(game.settings.fullscreen) and int(game.settings.keys.map) == KEY_M and int(game.settings.keys.cab) == KEY_E, "wrong types and bad hot keys fall back to the defaults")
	file = FileAccess.open(game.settings_path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	game.copy_settings(game.settings, game.DEFAULT_SETTINGS)
	game.load_settings()
	check(is_equal_approx(float(game.settings.master), 0.65), "a file that is not JSON is ignored")
	# text at 150% still fits the box
	game.settings.text_scale = 1.5
	game.screen = "menu"; game.rebuild()
	game.settings_fold = {"screen_more": true, "keys_more": true}   # the worst case: everything unfolded
	for tab in game.SETTINGS_TABS:
		game.settings_tab = tab
		game.show_modal("settings")
		await frame(3)
		var fits = true
		for b in game.overlay.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and b.get_global_rect().end.x > 1600.0 + 1.0: fits = false
		check(fits, tab + " at 150% text keeps its buttons inside the window")
		if tab == "Экран" or tab == "Игра": await shot("settings150_" + tab)
		game.close_modal()
	game.copy_settings(game.settings, game.DEFAULT_SETTINGS)
	game.apply_settings()
	if FileAccess.file_exists(game.settings_path): DirAccess.remove_absolute(game.settings_path)
	print("SETTINGS CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
