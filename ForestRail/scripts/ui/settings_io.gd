extends RefCounted
# Помощник main.gd: настройки игры: чтение, проверка, запись, размер окна (нарезка main.gd, 21.11). Работает через canvas (main.gd), как steam_cab.gd.

var canvas = null   # main.gd

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func load_settings() -> void:
	if FileAccess.file_exists(canvas.settings_path):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(canvas.settings_path))
		if saved is Dictionary:
			for key in canvas.DEFAULT_SETTINGS:
				if not saved.has(key): continue
				var value = saved[key]
				var fallback = canvas.DEFAULT_SETTINGS[key]
				if fallback is bool:
					if value is bool: canvas.settings[key] = value
				elif fallback is Dictionary:
					if value is Dictionary:
						for action in fallback:
							if value.has(action) and (value[action] is int or value[action] is float) and is_finite(float(value[action])):
								canvas.settings[key][action] = int(value[action])
				elif (value is int or value is float) and is_finite(float(value)):
					canvas.settings[key] = value
	canvas.apply_settings()
	canvas.apply_window_size.call_deferred(true)   # the first window fits the screen and its scaling

func apply_settings() -> void:
	if canvas.art != null: canvas.art.reduce_motion_flag = bool(canvas.settings.reduce_motion)
	for key in ["master", "mechanisms", "forest", "music", "interface"]:
		canvas.settings[key] = clampf(float(canvas.settings[key]), 0, 1)
	canvas.settings.fullscreen = canvas.settings.fullscreen is bool and canvas.settings.fullscreen
	canvas.settings.borderless = canvas.settings.borderless is bool and canvas.settings.borderless
	canvas.settings.vsync = canvas.settings.vsync is bool and canvas.settings.vsync
	canvas.settings.reduce_motion = canvas.settings.reduce_motion is bool and canvas.settings.reduce_motion
	canvas.settings.text_scale = clampf(float(canvas.settings.text_scale), 1, 1.5)
	canvas.settings.sensitivity = clampf(float(canvas.settings.sensitivity), 0.5, 2)
	canvas.settings.cab_shake = clampf(float(canvas.settings.cab_shake), 0, 1)
	canvas.settings.window_size = clampi(int(canvas.settings.window_size), 0, canvas.WINDOW_SIZES.size() - 1)
	canvas.settings.fps_cap = int(canvas.settings.fps_cap) if int(canvas.settings.fps_cap) in [0, 30, 60, 120, 144] else 0
	canvas.settings.msaa = int(canvas.settings.msaa) if int(canvas.settings.msaa) in [0, 2, 4] else 0
	canvas.settings.instrument_hz = 60 if int(canvas.settings.instrument_hz) >= 60 else 30
	canvas.settings.autosave = int(canvas.settings.autosave) if int(canvas.settings.autosave) in [0, 30, 60, 120, 300] else 60
	canvas.settings.night_light = clampf(float(canvas.settings.night_light), 0.0, 1.0)
	canvas.settings.light_flicker = canvas.settings.light_flicker is not bool or canvas.settings.light_flicker
	canvas.settings.weather = int(canvas.settings.weather) if int(canvas.settings.weather) in [0, 1, 2] else 0
	canvas.settings.weather_frequency = float(canvas.settings.weather_frequency) if float(canvas.settings.weather_frequency) in [0.5, 1.0, 2.0] else 1.0
	canvas.model.weather_frequency = float(canvas.settings.weather_frequency)
	# Hot keys: valid, never Escape (it always pauses), never twice; otherwise back to the defaults.
	var keys: Dictionary = canvas.settings.keys
	if not keys.has("burst"): keys["burst"] = KEY_B   # saves from before the supercapacitor keep their own keys
	if not keys.has("grapnel"): keys["grapnel"] = KEY_G
	if not keys.has("ignition"): keys["ignition"] = KEY_K   # the key of the petrol motorcar, added 16.11
	var seen: Array = []
	var valid = true
	for action in canvas.DEFAULT_SETTINGS.keys:
		var code = int(keys.get(action, 0))
		if code <= 0 or code == KEY_ESCAPE or code in seen: valid = false
		seen.append(code)
	if not valid:
		for action in canvas.DEFAULT_SETTINGS.keys: keys[action] = int(canvas.DEFAULT_SETTINGS.keys[action])
	else:
		for action in canvas.DEFAULT_SETTINGS.keys: keys[action] = int(keys[action])
	var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if canvas.settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode: DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, bool(canvas.settings.borderless) and not bool(canvas.settings.fullscreen))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if canvas.settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(canvas.settings.fps_cap)
	canvas.get_viewport().msaa_2d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}[int(canvas.settings.msaa)] if canvas.supports_2d_msaa() else Viewport.MSAA_DISABLED

func supports_2d_msaa() -> bool:
	return RenderingServer.get_current_rendering_method() in ["mobile", "forward_plus"]

func save_settings() -> bool:
	canvas.apply_settings()
	var temp = "%s.%d.tmp" % [canvas.settings_path, OS.get_process_id()]
	var file = FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	var data = JSON.stringify(canvas.settings).to_utf8_buffer()
	file.store_buffer(data)
	file.flush()
	var complete = file.get_error() == OK and file.get_length() == data.size()
	file.close()
	if complete and DirAccess.rename_absolute(temp, canvas.settings_path) == OK: return true
	DirAccess.remove_absolute(temp)
	return false

# Settings menu helpers: changes apply at once, "Применить" saves them, "Отменить" (or
# Esc) puts back what was there when the menu opened.
func copy_settings(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[key] = source[key].duplicate(true) if source[key] is Dictionary else source[key]

func settings_changed() -> bool:
	return JSON.stringify(canvas.settings) != JSON.stringify(canvas.settings_backup)

# The window sizes of the settings are in the points of the screen, not in its pixels: on a laptop with Windows scaling 200%
# (2880x1800) a window of 1600x900 pixels was a small box with tiny letters (owner 15.11). The size is multiplied by the
# scaling of the screen and kept inside the free area of the screen (16:9), and the window stands in its middle.
func window_pixels(index: int) -> Vector2i:
	var screen = DisplayServer.window_get_current_screen()
	var factor = maxf(1.0, maxf(DisplayServer.screen_get_scale(screen), float(DisplayServer.screen_get_dpi(screen)) / 96.0))
	var want = Vector2(canvas.WINDOW_SIZES[clampi(index, 0, canvas.WINDOW_SIZES.size() - 1)]) * factor
	var usable = Vector2(DisplayServer.screen_get_usable_rect(screen).size) * 0.94
	if usable.x > 0.0 and usable.y > 0.0:
		var fit = minf(1.0, minf(usable.x / want.x, usable.y / want.y))
		want *= fit
	return Vector2i(want.round())

func apply_window_size(at_start: bool = false) -> void:
	if bool(canvas.settings.fullscreen) or DisplayServer.get_name() == "headless": return
	if at_start and canvas.test_mode: return   # the checks set their own window
	var screen = DisplayServer.window_get_current_screen()
	var size = canvas.window_pixels(int(canvas.settings.window_size))
	DisplayServer.window_set_size(size)
	var usable = DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
