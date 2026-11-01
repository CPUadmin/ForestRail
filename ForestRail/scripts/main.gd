extends Node2D

const Model = preload("res://scripts/model.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const Sound = preload("res://scripts/sound.gd")
const ArtV3 = preload("res://scripts/art_v3.gd")
const ArtWorld = preload("res://scripts/art_world.gd")
const Geometry = preload("res://scripts/world_geometry.gd")
const Instruments = preload("res://scripts/instruments.gd")
const CabSide = preload("res://scripts/cab_side.gd")
const PAPER = Color("f5ecd6")
const MUTED_INK = Color("5c6b62")
const CARD_EDGE = Color("dccfae")
const INK = Color("29383b")
const GREEN = Color("466c51")
const GOLD = Color("bb964f")
const RED = Color("a64d3b")
var model = Model.new()
var menu_preview = Model.new()
var styles: Dictionary = {}
var resume_prompt = false
var saves = SaveGame.new()
var sound
var textures: Dictionary = {}
var art
var art_world
var instruments
var map_button: Button
var visual_layout: Dictionary = {}
var font: Font
var ui: Control
var overlay: Control
var hud: Label
var order_label: Label
var hint_label: Label
var action_bar: HBoxContainer
var cargo_actions: HBoxContainer
var unload_selected_button: Button
var cargo_action_key = ""
var selected_cargo = ""
var drag_cursor = Vector2.ZERO
var drag_source = Vector2.ZERO
var drag_offset = Vector2.ZERO
var drag_size = Vector2.ZERO
var cargo_visuals: Dictionary = {}
var delivery_ghost: Dictionary = {}
var screen = "menu"
var tab = "Рейсы"
var selected_object = "handcar"
var pole_press_rel = 0.0
var sail_cleat_point = Vector2.ZERO   # the screen place of the cleat, where the sheet is made fast
var sail_hold = 0.0   # how far behind the mast the boom end is held, metres
var sail_rect = Rect2()   # where the sail can be taken (B6.4)
var workshop_hits: Array = []   # B1.2c: the parts of the machine in the workshop that can be pointed at
var workshop_branch = ""
var paused = false
var modal_kind = ""
# Every key here is read by the game; the settings menu (N9) edits exactly these.
const DEFAULT_SETTINGS = {"master": 0.65, "mechanisms": 0.7, "forest": 0.6, "music": 0.25, "interface": 0.8,
	"sensitivity": 1.0, "text_scale": 1.0, "fullscreen": false, "borderless": false, "window_size": 1,
	"vsync": true, "fps_cap": 0, "msaa": 0, "instrument_hz": 30, "reduce_motion": false, "cab_shake": 1.0,
	"autosave": 60, "keys": {"map": KEY_M, "cab": KEY_E, "ice": KEY_I, "brake": KEY_SPACE}}
const WINDOW_SIZES = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const SETTINGS_TABS = ["Звук", "Графика", "Управление", "Игра", "Доступность", "Служебное"]
var settings = DEFAULT_SETTINGS.duplicate(true)
var settings_backup: Dictionary = {}
var settings_tab = "Звук"
var awaiting_key = ""
var camera_s = 0.0
var camera_y = 0.0
var camera_x = 0.0
var zoom_level = 1.0
# B1.2a: driving into the depot is a short scene, not a button that swaps the screen
const DEPOT_MOVE_S = 1.6
const DEPOT_FADE_S = 0.5
var depot_anim = ""            # "", "in" (rolling in and fading out), "out" (fading in inside)
var depot_anim_t = 0.0
var depot_anim_from = 0.0
var depot_anim_zoom = 1.0
var depot_exit_action = Callable()
var animate_in_tests = false
var fade_rect: ColorRect = null
# Cab view (E): the camera closes in on the cab and every control of the machine is
# drawn and grabbed in the world at human scale. cab_blend animates 0..1.
var cab_view = false
var cab_blend = 0.0
# B3.1: arriving at a platform in the cab lowers it so that the platform and the load are in view;
# moving off again raises it back. Pressing E by hand cancels the automatic return.
var cab_resume = false
var mini_button: Button   # the invisible button over the minimap; the cab dashboard has its own gauges there
var was_docked = false
var cab_hits: Array = []
# The pult drawn full size inside the cab scene is the same pult scaled and moved:
# pult_t maps its own coordinates to the screen (identity for the panel on C).
var pult_t = Transform2D.IDENTITY
var cab_exit_rect = Rect2()
var cab_sides: Array = []
# Visual-only engine temperature of the petrol car, 0..1: warms up while it runs.
var cab_temp = 0.05
# Cab liveliness: a jolt at every rail joint, spring-driven needles, frame time.
var cab_jolt = 0.0
var cab_joint = -999999
var needle_state: Dictionary = {}
var cab_dt = 0.016
var drag = ""
var drag_item = ""
var drag_total = 0.0
var drag_horizontal = 0.0
var drag_initial = 0.0
var drag_closeup = false
var lever_target_point = Vector2.ZERO
var lever_pending_gear = 0
# Petrol gear gate position (gate units: x 0..2 columns, y -1 up .. 1 down) and the
# running angle of a dragged steam hand wheel.
var gate_pos = Vector2(1, 0)
var wheel_last = 0.0
var wheel_acc = 0.0
const WHEEL_SWEEP = PI * 1.5
const GATE_SLOTS = {1: Vector2(0, -1), 2: Vector2(0, 1), 3: Vector2(1, -1), 4: Vector2(1, 1), 5: Vector2(2, -1), 6: Vector2(2, 1), 0: Vector2(1, 0)}
# Petrol gearbox on the lever arc: R, N, 1, 2, 3, 4, 5 (gear numbers as in the model, R is 6).
const GEAR_ORDER = [6, 0, 1, 2, 3, 4, 5]
const GEAR_LABELS = {0: "N", 1: "1", 2: "2", 3: "3", 4: "4", 5: "5", 6: "R"}
var lever_travel = 0.0
var lever_click_origin = Vector2.ZERO
var pump_grab_offset = Vector2.ZERO
var pump_target_point = Vector2.ZERO
var pump_grip_side = 1.0
var push_cursor = Vector2.ZERO
var grip_hits: Array = []
var ice_hits: Array = []   # the four frosted places on the pneumatic train's pipes (B1.3)
var steam_hits: Array = []
var slot_hits: Array = []
var cargo_hits: Array = []
var body_hits: Array = []
var toast = ""
var toast_seconds = 0.0
var charge_strip_rect = Rect2()
# Depot shunting: the wagon rolling to or from the train and its progress.
var coupling_anim: Dictionary = {}
var coupler_hits: Array = []
var latch_flash: Dictionary = {}
# The last wagon left behind stands nearest to the train.
var parked_order: Array = []
const COUPLE_SECONDS = 0.8
const PARK_GAP_M = 1.4
var depot_header_bottom = 127.0
var depot_info_rect = Rect2(22, 151, 708, 195)
var charge_band = 0
var autosave = 0.0
var refresh_seconds = 0.0
var last_action_key = ""
var last_phase = ""
var last_paid_count = 0
var pending_action: Callable
var tooltip = ""
var time = 0.0
var test_mode = false
var smoke_frames = -1
var screenshot_path = ""
var settings_path = "user://settings.json"

func _ready() -> void:
	Input.use_accumulated_input=false
	font = ThemeDB.fallback_font
	var edge_material = ShaderMaterial.new()
	material = edge_material
	var qa_args = OS.get_cmdline_user_args()
	if "--handcar-drive-bench" in qa_args and not get_tree().root.has_meta("drive_bench_running"):
		set_process(false);set_physics_process(false);set_process_input(false);set_process_unhandled_input(false)
		get_tree().root.add_child.call_deferred(load("res://dev/handcar_drive_bench.gd").new())
		return
	if "--mechanism-bench" in qa_args:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		get_tree().root.add_child.call_deferred(load("res://dev/mechanism_bench.gd").new())
		return
	if not get_tree().root.has_meta("qa_running"):
		for arg in qa_args:
			if arg.begins_with("--qa-suite="):
				# Tests and debugging runs are silent: nobody listens to the clicks and the engine.
				AudioServer.set_bus_mute(0, true)
				var suite = arg.trim_prefix("--qa-suite=")
				if suite not in ["check_model", "check_physics", "check_interaction", "drive_campaign", "check_presentation", "check_handcar_revision", "check_art_v3", "check_instruments", "check_station_service", "check_world_geometry", "check_mechanism", "check_mechanism_bench", "check_handcar_drive", "check_handcar_input", "check_motor_controls", "check_loading_selection", "check_layout_p7", "check_steam", "check_steam_view", "check_gearbox", "check_petrol_view", "check_skins", "check_perf", "check_cab", "check_sound", "check_forecast", "check_line_v2", "check_line_spread", "check_thermal", "check_speeds", "check_creative", "check_settings", "check_pneumatic", "check_pneumatic_view", "check_pole", "check_pole_view", "check_air", "check_sail", "check_sail_view", "check_loading_flow", "check_depot_entry", "check_forecast_long", "drive_long", "check_forecast_view", "check_soak_p8", "check_save_p8"]: get_tree().quit(2); return
				get_tree().root.set_meta("qa_running", true)
				set_process(false)
				set_physics_process(false)
				set_process_input(false)
				set_process_unhandled_input(false)
				get_tree().root.add_child.call_deferred(load("res://tests/" + suite + ".gd").new())
				return
	get_tree().auto_accept_quit = false
	menu_preview.new_game(42)
	saves.validator=model
	load_textures()
	art = ArtV3.new()
	edge_material.shader = load(ArtV3.ROOT + "materials/edge_clean.gdshader")
	art_world = ArtWorld.new()
	art_world.game = self
	art_world.art = art
	add_child(art_world)
	for argument in qa_args:
		if argument.begins_with("--profile-dir="):
			saves.directory=argument.trim_prefix("--profile-dir=")
			DirAccess.make_dir_recursive_absolute(saves.directory)
			settings_path=saves.directory.path_join("settings.json")
	load_settings()
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	# Side windows of the cab clip their own picture, so they are separate nodes.
	for window_side in [-1.0, 1.0]:
		var window = CabSide.new()
		window.game = self
		window.side = window_side
		window.clip_contents = true
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.visible = false
		add_child(window)
		cab_sides.append(window)
	sound = Sound.new()
	add_child(sound)
	sound.settings = settings
	get_viewport().size_changed.connect(rebuild)
	get_window().focus_exited.connect(on_window_focus_exited)
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--qa-dir="):
			saves.directory = arg.trim_prefix("--qa-dir=")
			DirAccess.make_dir_recursive_absolute(saves.directory)
			test_mode = true
	# A debug build (run from the editor) is silent; the exported game keeps its sound.
	if OS.is_debug_build(): AudioServer.set_bus_mute(0, true)
	for arg in args:
		if arg.begins_with("--qa-") or arg.begins_with("--screenshot="): AudioServer.set_bus_mute(0, true)
		if arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
			smoke_frames = 40
		if arg == "--qa-new":
			test_mode = true
			model.new_game(42)
			screen = "depot"
		if arg == "--qa-load":
			test_mode = true
			var saved = saves.read_valid("save_v2.json")
			if model.restore(saved):
				screen = "depot" if model.state.phase == "depot" else "game"
				selected_object = model.vehicle_id()
				camera_s = float(model.state.s)
				camera_y = model.route.sample(camera_s).y
	rebuild()

func load_textures() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets_manifest.json"))
	visual_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_layout.json"))
	for sprite in manifest.sprites:
		var atlas = AtlasTexture.new()
		atlas.atlas = load("res://" + str(manifest.sheets[sprite.sheet].file))
		var r = sprite.region_px
		atlas.region = Rect2(r[0], r[1], r[2], r[3])
		if sprite.id in ["pine", "birch", "bush", "fern", "rocks", "depot", "station_hut", "fuel_pump", "log_pile"]:
			var visible = visual_layout[sprite.id]
			atlas.region = Rect2(r[0] + visible[0], r[1] + visible[1], visible[2] - visible[0], visible[3] - visible[1])
			visual_layout[sprite.id] = [0, 0, visible[2] - visible[0], visible[3] - visible[1]]
		atlas.filter_clip = true
		textures[sprite.id] = atlas
	textures.background = load("res://assets/forest_background.png")
	for name in ["control_pump", "control_brake", "control_gear", "control_throttle", "control_start", "control_mount", "gauge_face", "gauge_needle"]:
		textures[name] = load("res://assets/ui/" + name + ".svg")
	for name in ["sack","log_bundle"]:
		var source = load("res://assets/art_p2/"+name+".png")
		var bounds = Geometry.data().cargo[name].region_px
		var rect = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
		var atlas = AtlasTexture.new()
		atlas.atlas = source
		atlas.region = rect
		atlas.filter_clip = true
		textures[name] = atlas
		visual_layout[name] = [0,0,rect.size.x,rect.size.y]

func load_settings() -> void:
	if FileAccess.file_exists(settings_path):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if saved is Dictionary:
			for key in DEFAULT_SETTINGS:
				if not saved.has(key): continue
				var value = saved[key]
				var fallback = DEFAULT_SETTINGS[key]
				if fallback is bool:
					if value is bool: settings[key] = value
				elif fallback is Dictionary:
					if value is Dictionary:
						for action in fallback:
							if value.has(action) and (value[action] is int or value[action] is float) and is_finite(float(value[action])):
								settings[key][action] = int(value[action])
				elif (value is int or value is float) and is_finite(float(value)):
					settings[key] = value
	apply_settings()

func apply_settings() -> void:
	for key in ["master", "mechanisms", "forest", "music", "interface"]:
		settings[key] = clampf(float(settings[key]), 0, 1)
	settings.fullscreen = settings.fullscreen is bool and settings.fullscreen
	settings.borderless = settings.borderless is bool and settings.borderless
	settings.vsync = settings.vsync is bool and settings.vsync
	settings.reduce_motion = settings.reduce_motion is bool and settings.reduce_motion
	settings.text_scale = clampf(float(settings.text_scale), 1, 1.5)
	settings.sensitivity = clampf(float(settings.sensitivity), 0.5, 2)
	settings.cab_shake = clampf(float(settings.cab_shake), 0, 1)
	settings.window_size = clampi(int(settings.window_size), 0, WINDOW_SIZES.size() - 1)
	settings.fps_cap = int(settings.fps_cap) if int(settings.fps_cap) in [0, 30, 60, 120, 144] else 0
	settings.msaa = int(settings.msaa) if int(settings.msaa) in [0, 2, 4] else 0
	settings.instrument_hz = 60 if int(settings.instrument_hz) >= 60 else 30
	settings.autosave = int(settings.autosave) if int(settings.autosave) in [0, 30, 60, 120, 300] else 60
	# Hot keys: valid, never Escape (it always pauses), never twice; otherwise back to the defaults.
	var keys: Dictionary = settings.keys
	var seen: Array = []
	var valid = true
	for action in DEFAULT_SETTINGS.keys:
		var code = int(keys.get(action, 0))
		if code <= 0 or code == KEY_ESCAPE or code in seen: valid = false
		seen.append(code)
	if not valid:
		for action in DEFAULT_SETTINGS.keys: keys[action] = int(DEFAULT_SETTINGS.keys[action])
	else:
		for action in DEFAULT_SETTINGS.keys: keys[action] = int(keys[action])
	var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode: DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, bool(settings.borderless) and not bool(settings.fullscreen))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(settings.fps_cap)
	get_viewport().msaa_2d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}[int(settings.msaa)]

func save_settings() -> void:
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
	apply_settings()

# Settings menu helpers: changes apply at once, "Применить" saves them, "Отменить" (or
# Esc) puts back what was there when the menu opened.
func copy_settings(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[key] = source[key].duplicate(true) if source[key] is Dictionary else source[key]

func settings_changed() -> bool:
	return JSON.stringify(settings) != JSON.stringify(settings_backup)

func apply_window_size() -> void:
	if not bool(settings.fullscreen): DisplayServer.window_set_size(WINDOW_SIZES[int(settings.window_size)])

func key_name(action: String) -> String:
	return OS.get_keycode_string(int(settings.keys[action]))

# Frost on the pipes of the pneumatic train: one press knocks a quarter off every frosted spot.
func chip_all_ice() -> void:
	var chipped = 0
	for spot in range(4):
		if model.chip_ice(spot): chipped += 1
	if chipped > 0: notify("Иней сбит: %d%%" % roundi(model.frost() * 100.0))

func key_is(event: InputEvent, action: String) -> bool:
	var code = int(settings.keys[action])
	return event is InputEventKey and (event.physical_keycode == code or event.keycode == code)

func bind_key(code: int) -> void:
	var action = awaiting_key
	awaiting_key = ""
	if code != KEY_ESCAPE and action != "":
		for other in settings.keys:
			if other != action and int(settings.keys[other]) == code: settings.keys[other] = int(settings.keys[action])
		settings.keys[action] = code
		apply_settings()
	rebuild()

func setting_matches(current, option) -> bool:
	if current is bool or option is bool: return current == option
	return is_equal_approx(float(current), float(option))

func settings_slider(box: VBoxContainer, key: String, title: String, low: float, high: float, step: float) -> void:
	var value_label = add_label(box, "", 20)
	var slider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(settings[key])
	slider.custom_minimum_size.y = 28
	box.add_child(slider)
	var refresh = func(): value_label.text = "%s: %d%%" % [title, roundi(float(settings[key]) * 100.0)]
	refresh.call()
	slider.value_changed.connect(func(value):
		settings[key] = value
		apply_settings()
		refresh.call())

func settings_choice(box: VBoxContainer, key: String, title: String, options: Array, after: Callable = Callable()) -> void:
	add_label(box, title, 20)
	var row = HBoxContainer.new()
	box.add_child(row)
	for option in options:
		var button = add_button(row, str(option[1]), func():
			settings[key] = option[0]
			apply_settings()
			if after.is_valid(): after.call()
			rebuild(), false, setting_matches(settings[key], option[0]))
		button.add_theme_font_size_override("font_size", int(18 * float(settings.text_scale)))

func settings_toggle(box: VBoxContainer, key: String, title: String) -> void:
	add_button(box, "%s: %s" % [title, "вкл." if settings[key] else "выкл."], func():
		settings[key] = not settings[key]
		apply_settings()
		rebuild())

func settings_key(box: VBoxContainer, action: String, title: String) -> void:
	var waiting = awaiting_key == action
	add_button(box, "%s: %s" % [title, "нажми новую клавишу (Esc отмена)" if waiting else key_name(action)], func():
		awaiting_key = action
		rebuild())

func build_settings(box: VBoxContainer) -> void:
	add_label(box, "Настройки", 32)
	var actions = HBoxContainer.new()
	box.add_child(actions)
	add_button(actions, "Применить", func():
		save_settings()
		settings_backup = settings.duplicate(true)
		notify("Настройки сохранены")
		close_modal())
	add_button(actions, "Отменить", close_modal)
	add_button(actions, "По умолчанию", func():
		copy_settings(settings, DEFAULT_SETTINGS)
		apply_settings()
		apply_window_size()
		rebuild())
	var tabs = GridContainer.new()
	tabs.columns = 3
	box.add_child(tabs)
	for tab_name in SETTINGS_TABS:
		var tab_button = add_button(tabs, tab_name, func():
			settings_tab = tab_name
			awaiting_key = ""
			rebuild(), false, tab_name == settings_tab)
		tab_button.add_theme_font_size_override("font_size", int(18 * float(settings.text_scale)))
	if settings_tab == "Звук":
		settings_slider(box, "master", "Общая громкость", 0, 1, 0.05)
		settings_slider(box, "music", "Музыка", 0, 1, 0.05)
		settings_slider(box, "forest", "Эмбиент (лес, ветер, вода, птицы)", 0, 1, 0.05)
		settings_slider(box, "mechanisms", "Машины и рельсы", 0, 1, 0.05)
		settings_slider(box, "interface", "Интерфейс (клики, монеты)", 0, 1, 0.05)
		add_label(box, "Проверить звук:", 20)
		var row = HBoxContainer.new()
		box.add_child(row)
		add_button(row, "Музыка", func(): sound.play("sting_start", 0.55))
		add_button(row, "Эмбиент", func(): sound.play("bird_%d" % randi_range(1, 4), 0.8))
		add_button(row, "Машины", func(): sound.play("rail_clack_a", 0.6))
		add_button(row, "Интерфейс", func(): sound.play("coins", 0.6))
	elif settings_tab == "Графика":
		settings_toggle(box, "fullscreen", "Полный экран")
		settings_toggle(box, "borderless", "Окно без рамки")
		settings_choice(box, "window_size", "Размер окна (если не на весь экран)", [[0, "1280×720"], [1, "1600×900"], [2, "1920×1080"]], apply_window_size)
		settings_toggle(box, "vsync", "Вертикальная синхронизация")
		settings_choice(box, "fps_cap", "Ограничение кадров", [[0, "Без ограничения"], [30, "30"], [60, "60"], [120, "120"], [144, "144"]])
		settings_choice(box, "msaa", "Сглаживание краёв", [[0, "Выкл."], [2, "2×"], [4, "4×"]])
		settings_choice(box, "instrument_hz", "Частота обновления приборов", [[30, "30 Гц"], [60, "60 Гц"]])
	elif settings_tab == "Управление":
		settings_slider(box, "sensitivity", "Чувствительность ручной дрезины", 0.5, 2, 0.05)
		add_label(box, "Клавиши (Esc всегда пауза):", 20)
		settings_key(box, "map", "Карта")
		settings_key(box, "cab", "Кабина")
		settings_key(box, "ice", "Сбить иней (пневматический)")
		settings_key(box, "brake", "Тормоз: затянуть или отпустить")
	elif settings_tab == "Игра":
		settings_choice(box, "autosave", "Автосохранение раз в", [[0, "Выкл."], [30, "30 с"], [60, "60 с"], [120, "2 мин"], [300, "5 мин"]])
		if screen != "menu" and not model.state.is_empty():
			add_button(box, "Подсказки: " + ("вкл." if model.state.tutorial else "выкл."), func():
				model.state.tutorial = not model.state.tutorial
				save_game()
				rebuild())
		else:
			add_label(box, "Подсказки включаются в паузе во время игры.", 18, MUTED_INK)
	elif settings_tab == "Доступность":
		settings_choice(box, "text_scale", "Размер текста", [[1.0, "100%"], [1.25, "125%"], [1.5, "150%"]])
		settings_toggle(box, "reduce_motion", "Без тряски и мерцания")
		settings_slider(box, "cab_shake", "Тряска кабины", 0, 1, 0.05)
	else:
		add_label(box, "Версия игры %s" % ProjectSettings.get_setting("application/config/version"), 20)
		add_label(box, "Сохранения и настройки: %s" % ProjectSettings.globalize_path(saves.directory), 17, MUTED_INK)
		add_button(box, "Открыть папку сохранений", func(): OS.shell_open(ProjectSettings.globalize_path(saves.directory)))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if screen != "menu" and not model.state.is_empty():
			save_game()
		get_tree().quit()

# Automated tests run in windows that other processes can take focus from; a person's game cannot.
func on_window_focus_exited() -> void:
	if not test_mode: focus_lost()

func focus_lost() -> void:
	if screen == "game" and not test_mode:
		pause_game()
	else:
		cancel_drag()

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func style(bg: Color, border: Color = GOLD, radius: int = 12) -> StyleBoxFlat:
	var key="%s|%s|%d" % [bg.to_html(),border.to_html(),radius]
	if styles.has(key): return styles[key]
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	styles[key]=box
	return box

func setup_theme() -> void:
	var theme = Theme.new()
	theme.default_font_size = int(20 * float(settings.text_scale))
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("a9b5a8"))
	theme.set_stylebox("normal", "Button", style(GREEN, GREEN, 8))
	theme.set_stylebox("hover", "Button", style(Color("5b8060"), GOLD, 8))
	theme.set_stylebox("pressed", "Button", style(INK, GOLD, 8))
	theme.set_stylebox("disabled", "Button", style(Color(0.16, 0.24, 0.2, 0.55), Color(0.62, 0.68, 0.58, 0.25), 8))
	theme.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), GOLD, 8))
	theme.set_stylebox("panel", "PanelContainer", style(PAPER))
	ui.theme = theme
	overlay.theme = theme

func add_label(parent: Node, text: String, size: int = 20, color: Color = INK) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(size * float(settings.text_scale)))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

# selected marks the current choice in a group (tab, vehicle, direction): it is
# inert like a disabled button but must read as active, not unavailable.
func add_button(parent: Node, text: String, action: Callable, disabled: bool = false, selected: bool = false) -> Button:
	var button = Button.new()
	button.text = text
	button.disabled = disabled or selected
	if selected:
		button.add_theme_stylebox_override("disabled", style(INK, GOLD, 8))
		button.add_theme_color_override("font_disabled_color", Color("e2c27a"))
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func():
		sound.play("ui_click", 0.5)
		action.call())
	parent.add_child(button)
	return button

# A bordered block inside a paper panel; the accent edge marks the current choice.
func card(parent: Node, edge: Color = CARD_EDGE) -> VBoxContainer:
	var panel = PanelContainer.new()
	var box = style(Color("fbf6ea"), edge, 10).duplicate()
	box.set_content_margin_all(14)
	if edge != CARD_EDGE: box.border_width_left = 5
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	return content

func panel_at(parent: Control, rect: Rect2, scroll: bool = false) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	parent.add_child(panel)
	var container_parent: Node = panel
	if scroll:
		var scroller = ScrollContainer.new()
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroller)
		container_parent = scroller
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container_parent.add_child(vbox)
	return vbox

func positioned_label(text: String, rect: Rect2, size: int = 20, color: Color = PAPER) -> Label:
	var label = add_label(ui, text, size, color)
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func rebuild() -> void:
	if ui == null:
		return
	if drag!="": cancel_drag()
	clear_children(ui)
	clear_children(overlay)
	setup_theme()
	var size = get_viewport_rect().size
	if screen == "depot":
		camera_s = 0.0
		camera_y = 0.0
		camera_x = size.x * 0.31 if model.state.consist_ids.is_empty() else size.x * 0.46 - 136
	ui.size = size
	overlay.size = size
	if screen == "menu":
		build_menu(size)
	elif screen == "depot":
		build_depot(size)
	else:
		build_hud(size)
	if modal_kind != "":
		build_modal(size)
	queue_redraw()

func menu_layout_scale(size: Vector2) -> float:
	return clampf(size.y / 900.0, 0.75, 1.15)

func build_menu(size: Vector2) -> void:
	var k = menu_layout_scale(size)
	# One stacked column: a wrapped subtitle or larger text pushes the
	# buttons down instead of running into them.
	var column = VBoxContainer.new()
	column.position = Vector2(86, 88 * k)
	column.size = Vector2(minf(620, size.x * 0.5), 0)
	column.add_theme_constant_override("separation", int(10 * k))
	ui.add_child(column)
	add_label(column, "ЛЕСНАЯ ЖЕЛЕЗНАЯ ДОРОГА", 17, Color("e2c27a"))
	var title = add_label(column, "Лесная\nколея", 96, PAPER)
	title.add_theme_font_size_override("font_size", int(96 * k))
	title.add_theme_constant_override("line_spacing", int(-22 * k))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_label(column, "Начни с рычага. Верни поезда в Дальний бор.", 22, Color(PAPER, 0.82))
	var gap = Control.new()
	gap.custom_minimum_size.y = 18 * k
	column.add_child(gap)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.custom_minimum_size.x = 330
	box.add_theme_constant_override("separation", int(6 * k))
	column.add_child(box)
	var has_save = saves.has_any()
	if has_save: menu_button(box, "Продолжить", continue_game, true)
	menu_button(box, "Новая игра", func():
		if has_save:
			confirm("Начать новую карьеру? Текущая будет сохранена в файл %s рядом с сохранениями." % SaveGame.PREVIOUS_CAREER, func(): begin_new())
		else:
			begin_new(), not has_save)
	menu_button(box, "Творческий режим", func():
		if has_save:
			confirm("Начать творческий режим? Текущая карьера будет сохранена в файл %s рядом с сохранениями." % SaveGame.PREVIOUS_CAREER, func(): begin_new(-1, true))
		else:
			begin_new(-1, true))
	menu_button(box, "Настройки", func(): show_modal("settings"))
	menu_button(box, "Как играть", func(): show_modal("help"))
	menu_button(box, "Об игре", func(): show_modal("credits"))
	menu_button(box, "Выход", func(): get_tree().quit())
	# The footer needs the room the column leaves at small windows with large text.
	if size.y / float(settings.text_scale) > 640:
		positioned_label("От ручной дрезины до электровоза  ·  версия %s" % ProjectSettings.get_setting("application/config/version"), Rect2(86, size.y - 52, 700, 30), 15, Color(PAPER, 0.55))

# Menu entries are a plain list on the scrim; only the main action is filled.
func menu_button(parent: Node, text: String, action: Callable, primary: bool = false) -> Button:
	var button = add_button(parent, text, action)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 46
	if not primary:
		var ghost = style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8)
		button.add_theme_stylebox_override("normal", ghost)
		button.add_theme_stylebox_override("hover", style(Color(1, 1, 1, 0.08), Color(0.89, 0.76, 0.48, 0.5), 8))
		button.add_theme_stylebox_override("pressed", style(Color(0, 0, 0, 0.25), Color(0.89, 0.76, 0.48, 0.5), 8))
		button.add_theme_color_override("font_color", Color(PAPER, 0.88))
	else:
		button.add_theme_stylebox_override("normal", style(Color("3f6b4c"), Color("e2c27a"), 8))
	return button

func begin_new(seed_number: int = -1, creative_mode: bool = false) -> void:
	if not saves.archive_career():
		notify(saves.error)
		return
	if seed_number < 0:
		seed_number = int(Time.get_unix_time_from_system()) % 100000
	model.new_game(seed_number, 2, "creative" if creative_mode else "career", true, "pole")
	selected_object = model.vehicle_id()
	screen = "depot"
	tab = "Рейсы"
	paused = false
	modal_kind = ""
	camera_s = 0
	camera_y = 0
	last_paid_count = 0
	if not saves.write(model):
		notify(saves.error)
	rebuild()

func continue_game() -> void:
	var saved = saves.read_valid("save_v2.json")
	if saved.is_empty():
		if not saves.read_valid("save_v2.backup.json").is_empty():
			confirm("Основное сохранение повреждено. Восстановить резервную копию?", func(): load_career(saves.read_valid("save_v2.backup.json")))
		else:
			notify("Сохранение не читается. Начни новую игру отдельно; старые файлы сохранены")
		return
	load_career(saved)

func load_career(saved: Dictionary) -> void:
	if not model.restore(saved):
		notify("Сохранение несовместимо или повреждено")
		return
	screen = "depot" if model.state.phase == "depot" else "game"
	selected_object = model.vehicle_id()
	camera_s = float(model.state.s)
	camera_y = model.route.sample(camera_s).y
	last_paid_count = model.state.paid_ids.size()
	paused = screen == "game"
	modal_kind = "pause" if paused else ""
	resume_prompt = paused
	model.message = ""
	rebuild()

# Line height of the fallback font at a size before text scaling.
func line_height(font_size: int) -> float:
	return font_size * float(settings.text_scale) * 1.4

# Lines a text takes in a box of this width, counting the wraps (with a little slack).
func wrapped_lines(text: String, width: float, font_size: int) -> int:
	var lines = 0
	var pixels = int(font_size * float(settings.text_scale))
	for line in text.split("\n"):
		lines += maxi(1, ceili(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x * 1.08 / maxf(1.0, width)))
	return lines

func build_depot(size: Vector2) -> void:
	# Header and info box grow with the text scale; at 150 % the fixed boxes
	# let the money line touch the title and the details spill out.
	var money_y = maxf(87, 30 + line_height(32) + 6)
	depot_header_bottom = maxf(127, money_y + line_height(20) + 8)
	positioned_label("ДЕПО  /  ЛЕСНАЯ", Rect2(44, 30, 1000, 50), 32)
	positioned_label("Творческий режим  ·  деньги и топливо без ограничений" if model.creative() else "%d монет  ·  %d / 10 основных рейсов" % [model.state.money, model.state.chapter], Rect2(46, money_y, 1000, 45), 20)
	var menu_row = HBoxContainer.new()
	menu_row.position = Vector2(size.x - 285, 28)
	menu_row.size = Vector2(245, 50)
	ui.add_child(menu_row)
	add_button(menu_row, "☰  Меню", func(): pause_game())
	var left_width = size.x * 0.46
	var panel_rect = Rect2(left_width + 30, depot_header_bottom + 28, size.x - left_width - 70, size.y - depot_header_bottom - 58)
	var right = panel_at(ui, panel_rect, true)
	# B1.2b: the four places of the depot are pictures to choose from, not a row of words
	var tiles = HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	right.add_child(tiles)
	for entry in [["Гараж", "Гараж", "garage"], ["Состав", "Состав", "wagons"], ["Улучшения", "Мастерская", "bench"], ["Рейсы", "Доска заказов", "board"]]:
		depot_tile(tiles, entry[0], entry[1], entry[2])
	add_label(right, tab, 28)
	if not model.state.active.is_empty():
		add_label(right, "Активный рейс: " + str(model.state.active.title), 23)
		add_label(right, "Груз и отметки доставки сохранены. Продолжи рейс или отмени его без оплаты.")
		add_button(right, "Продолжить рейс →", func():
			model.resume_mission()
			screen = "game"
			zoom_level = fit_train_zoom()
			save_game()
			rebuild())
		add_button(right, "Отменить рейс", func(): confirm("Вернуть груз на склад и отменить рейс без оплаты?", func(): model.cancel_mission(); save_game(); rebuild()))
	elif tab == "Гараж":
		for id in Model.VEHICLE_IDS:
			var owned = model.state.fleet_by_id.has(id)
			var base = model.vehicle_base(id)
			var label = str(base.name)
			var c = picture_card(right, id, owned, GOLD if model.vehicle_id() == id else CARD_EDGE)
			add_label(c, label, 23)
			add_label(c, "до %d км/ч  ·  %s" % [roundi(model.top_speed_kmh(id)), VEHICLE_ROLE.get(id, "")], 16, INK)
			add_label(c, vehicle_summary(id), 15, MUTED_INK)
			if owned:
				add_button(c, "Выбрана" if model.vehicle_id() == id else "Выбрать", func():
					if model.select_vehicle(id):
						selected_object = id
						save_game()
						rebuild()
					else: notify(model.message), false, model.vehicle_id() == id)
			else:
				add_button(c, "Купить · %d монет" % base.cost, func():
					confirm("Купить %s за %d? Останется %d монет. Предыдущая машина останется в гараже." % [label, base.cost, maxi(0, int(model.state.money) - int(base.cost))], func():
						if model.buy_vehicle(id):
							selected_object = id
							save_game()
							rebuild()
						else: notify(model.message)))
	elif tab == "Состав":
		consist_strip(right)
		add_label(right, "Вагоны твои: их улучшения сохраняются при перестановке. %s допускает вагонов: %d." % [vehicle_display_name(), model.max_wagons(model.vehicle_id())])
		for id in model.state.wagons_by_id:
			if id == Model.TEMP_WAGON: continue
			var stats = model.object_stats(id)
			var coupled = id in model.state.consist_ids
			var c = picture_card(right, id, coupled, GOLD if coupled else CARD_EDGE)
			add_label(c, "%s  ·  %d мест  ·  %d кг%s" % [id, stats.slots, stats.mass, "  ·  в составе" if coupled else ""], 21)
			add_button(c, "Отцепить " + id if id in model.state.consist_ids else "Прицепить " + id, func():
				if model.toggle_wagon(id): save_game(); rebuild()
				else: notify(model.message))
		var next_wagon = model.next_wagon_id()
		if next_wagon != "":
			var price = model.wagon_price(next_wagon)
			add_button(right, "Купить %s · %d монет" % [next_wagon, price], func(): confirm("Купить вагон %s за %d? Останется %d монет." % [next_wagon, price, maxi(0, int(model.state.money) - price)], func():
				if model.buy_wagon(): save_game(); rebuild()
				else: notify(model.message)))
		add_label(right, "Мест в составе: %d. Для финала нужно шесть." % model.capacity(), 21)
	elif tab == "Улучшения":
		build_upgrades(right)
	else:
		build_missions(right)
	var info_top = depot_header_bottom + 24
	depot_info_rect = Rect2()
	if tab != "Улучшения":
		positioned_label(vehicle_display_name(), Rect2(44, info_top + 7, left_width - 20, 70), 32)
		var stats = model.object_stats(model.vehicle_id())
		var details = "%d кг  ·  %d мест" % [model.train_mass(), model.capacity()]
		if model.vehicle_id() == "sail":
			details += "\nПарус · без топлива\nВетер задаёт ход: штиль — стоим"
		elif model.vehicle_id() == "pole":
			details += "\nШест · без топлива\nГрунт решает: глина вязнет, камни скользят"
		elif model.vehicle_id() == "handcar":
			details += "\nРучной привод · без топлива\nМаховик сохраняет накат"
		else:
			details += "\nПередачи R / N / 1–5 · до %.0f км/ч\n" % model.top_speed_kmh() + energy_text() + "\n" + forecast_line(model.current_mission())
		var details_y = maxf(info_top + 88, info_top + 7 + line_height(32) + 6)
		var details_lines = wrapped_lines(details, left_width - 20, 19)
		positioned_label(details, Rect2(46, details_y, left_width - 20, maxf(105, details_lines * line_height(19))), 19)
		depot_info_rect = Rect2(22, info_top, left_width - 28, maxf(195, details_y + details_lines * line_height(19) + 12 - info_top))
	var service = HBoxContainer.new()
	service.position = Vector2(44, size.y - 150)
	service.size = Vector2(left_width - 25, 50)
	ui.add_child(service)
	var refill = model.refill_cost() if not model.human_powered() else 0
	var refill_text = ({"locomotive": "Зарядить", "pneumatic": "Накачать"}.get(model.vehicle_id(), "Заправить")) + (" · %d монет" % refill if refill > 0 else " · полон")
	add_button(service, refill_text, func():
		if model.refuel(): save_game(); rebuild(); notify(model.message if model.message != "" else "Запас пополнен"); model.message = ""
		else: notify(model.message), model.human_powered() or refill <= 0)
	add_button(service, "Улучшить", func(): selected_object = model.vehicle_id(); tab = "Улучшения"; rebuild())
	if model.state.active.is_empty(): add_button(service, "Просто поехать →", take_free_ride)
	positioned_label("Нажми на машину или вагон, чтобы выбрать его улучшения.", Rect2(46, size.y - 83, left_width - 30, 60), 17)

# A big picture button for one place of the depot: the picture and its name are drawn on top of an
# ordinary button, which keeps the click, the hover and the keyboard focus.
func depot_tile(parent: Node, tab_name: String, caption: String, icon: String) -> Button:
	var selected = tab == tab_name
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 96.0 * float(settings.text_scale))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = caption
	button.disabled = selected
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var edge = GOLD if (selected or state == "hover") else CARD_EDGE
		button.add_theme_stylebox_override(state, style(INK if selected else Color("33463f"), edge, 8))
	button.pressed.connect(func():
		sound.play("ui_click", 0.5)
		tab = tab_name
		rebuild())
	var picture = Control.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.draw.connect(func(): draw_depot_icon(picture, icon, caption, selected, button.is_hovered()))
	button.mouse_entered.connect(picture.queue_redraw)
	button.mouse_exited.connect(picture.queue_redraw)
	button.add_child(picture)
	parent.add_child(button)
	return button

func draw_depot_icon(canvas: Control, icon: String, caption: String, selected: bool, hovered: bool) -> void:
	var size = canvas.size
	var color = GOLD if selected else (Color("fff2c8") if hovered else PAPER)
	var dark = Color("1a2622")
	var unit = minf(size.x, size.y) / 96.0
	var centre = Vector2(size.x * 0.5, size.y * 0.40)
	var line = maxf(1.5, 2.2 * unit)
	if icon == "bench":
		# a gear and a spanner
		var gear = centre + Vector2(-10, 2) * unit
		for i in range(8):
			var a = TAU * float(i) / 8.0
			canvas.draw_line(gear + Vector2.from_angle(a) * 12.0 * unit, gear + Vector2.from_angle(a) * 17.0 * unit, color, 5.0 * unit)
		canvas.draw_arc(gear, 12.0 * unit, 0, TAU, 28, color, line * 1.4, true)
		canvas.draw_circle(gear, 4.5 * unit, color)
		canvas.draw_line(centre + Vector2(4, 22) * unit, centre + Vector2(26, -8) * unit, color, 5.0 * unit)
		canvas.draw_arc(centre + Vector2(27, -10) * unit, 7.0 * unit, deg_to_rad(40), deg_to_rad(320), 16, color, 4.0 * unit, true)
	elif icon == "board":
		var board = Rect2(centre + Vector2(-26, -20) * unit, Vector2(52, 40) * unit)
		canvas.draw_rect(board, color, false, line * 1.4)
		for note in [Rect2(-20, -14, 14, 15), Rect2(-2, -15, 14, 12), Rect2(-12, 4, 18, 11), Rect2(14, -12, 9, 22)]:
			canvas.draw_rect(Rect2(centre + note.position * unit, note.size * unit), color)
			canvas.draw_circle(centre + (note.position + Vector2(note.size.x * 0.5, 2.0)) * unit, 1.6 * unit, dark)
	elif icon == "garage":
		canvas.draw_rect(Rect2(centre + Vector2(-26, -4) * unit, Vector2(40, 16) * unit), color)
		canvas.draw_rect(Rect2(centre + Vector2(-26, -20) * unit, Vector2(16, 16) * unit), color)
		canvas.draw_rect(Rect2(centre + Vector2(6, -16) * unit, Vector2(7, 12) * unit), color)
		canvas.draw_rect(Rect2(centre + Vector2(-23, -16) * unit, Vector2(10, 7) * unit), dark)
		for x in [-17.0, 4.0]:
			canvas.draw_circle(centre + Vector2(x, 15) * unit, 7.0 * unit, color)
			canvas.draw_circle(centre + Vector2(x, 15) * unit, 2.5 * unit, dark)
	elif icon == "wagons":
		for x in [-30.0, 3.0]:
			canvas.draw_rect(Rect2(centre + Vector2(x, -6) * unit, Vector2(27, 14) * unit), color)
			canvas.draw_circle(centre + Vector2(x + 6, 14) * unit, 5.0 * unit, color)
			canvas.draw_circle(centre + Vector2(x + 21, 14) * unit, 5.0 * unit, color)
		canvas.draw_line(centre + Vector2(-3, 2) * unit, centre + Vector2(3, 2) * unit, color, line * 1.6)
	var caption_size = int(round(15.0 * float(settings.text_scale)))
	canvas.draw_string(font, Vector2(0, size.y - 11.0 * unit), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, caption_size, color)

# The inside of the depot behind the machine: a plank wall in lamplight, rafters, hanging lamps.
func draw_depot_interior(size: Vector2) -> void:
	var floor_y = rail_baseline()
	var bands = 24
	for i in range(bands):
		var t = float(i) / float(bands - 1)
		draw_rect(Rect2(0, floor_y * float(i) / float(bands), size.x, floor_y / float(bands) + 1.0), Color("1b1510").lerp(Color("4d3924"), t))
	var x = 0.0
	var plank = 0
	while x < size.x:
		var width = 58.0 + 10.0 * float((plank * 7) % 3)
		draw_rect(Rect2(x, 0, 2.0, floor_y), Color(0, 0, 0, 0.30))
		draw_rect(Rect2(x + 2.0, 0, width - 2.0, floor_y), Color(1.0, 0.85, 0.6, 0.015 * float((plank * 5) % 4)))
		x += width
		plank += 1
	# rafters and a crossbeam
	draw_rect(Rect2(0, 0, size.x, 42), Color("110c08"))
	draw_rect(Rect2(0, 42, size.x, 5), Color(0, 0, 0, 0.35))
	for beam_x in [0.12, 0.38, 0.64, 0.90]:
		var bx = size.x * beam_x
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 8, 47), Vector2(bx + 8, 47), Vector2(bx + 44, 140), Vector2(bx + 30, 140)]), Color("1f160f"))
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 8, 47), Vector2(bx + 8, 47), Vector2(bx - 30, 140), Vector2(bx - 44, 140)]), Color("1f160f"))
	# hanging lamps with a warm pool of light, hung below the info box so that they are seen
	var lamp_y = maxf(depot_info_rect.end.y + 38.0, 240.0)
	for lamp_x in [0.12, 0.36]:
		var lx = size.x * lamp_x
		draw_line(Vector2(lx, 47), Vector2(lx, lamp_y - 22), Color("0c0906"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(lx - 10, lamp_y - 22), Vector2(lx + 10, lamp_y - 22), Vector2(lx + 22, lamp_y), Vector2(lx - 22, lamp_y)]), Color("2a2a22"))
		for k in range(8):
			draw_circle(Vector2(lx, lamp_y + 4.0), 170.0 - 19.0 * float(k), Color(1.0, 0.76, 0.38, 0.03))
		draw_circle(Vector2(lx, lamp_y + 2.0), 8.0, Color("ffe9b0"))
	# the floor line and a shadow under the wall
	draw_rect(Rect2(0, floor_y - 10, size.x, 10), Color(0, 0, 0, 0.30))

func build_upgrades(right: VBoxContainer) -> void:
	var row = HBoxContainer.new()
	right.add_child(row)
	var objects = [model.vehicle_id()] + model.state.wagons_by_id.keys().filter(func(id): return id != Model.TEMP_WAGON)
	if not selected_object in objects:
		selected_object = model.vehicle_id()
	for id in objects:
		add_button(row, "Машина" if not id.begins_with("W") else id, func(): selected_object = id; rebuild(), false, id == selected_object)
	var before = model.object_stats(selected_object)
	add_label(right, "Выбран: " + (selected_object if selected_object.begins_with("W") else vehicle_display_name()), 22)
	add_label(right, "%d мест · %d кг · тормоз %d Н" % [before.slots, before.mass, before.brake], 18)
	if selected_object.begins_with("W"):
		add_label(right, "Качение: %.4f · защита посуды: %d%%" % [before.rolling, roundi((1.0 - float(before.shock)) * 100)], 18)
	var branches: Array = []
	for branch in model.data.upgrade_catalog:
		if branch.target_type != ("wagon" if selected_object.begins_with("W") else selected_object):
			continue
		if str(branch.id) == workshop_branch: branches.push_front(branch)
		else: branches.append(branch)
	if not branches.is_empty(): add_label(right, "Укажи деталь на машине слева или выбери здесь.", 16, MUTED_INK)
	for branch in branches:
		var lv = int(model.object_state(selected_object).levels.get(branch.id, 0))
		var name = upgrade_branch_name(selected_object, branch)
		var c = card(right, GOLD if str(branch.id) == workshop_branch else (GREEN if lv >= 2 else CARD_EDGE))
		add_label(c, "%s  ·  %s" % [name, ["○ ○", "● ○", "● ●"][lv]], 22)
		if lv < 2:
			var preview = upgrade_preview(selected_object, branch)
			add_label(c, preview, 17, MUTED_INK)
			var cost = int(branch.level_costs[lv])
			add_button(c, "Улучшить до %s · %d монет" % ["I" if lv == 0 else "II", cost], func():
				var id = selected_object
				confirm("%s: %s\nЦена %d. Останется %d монет." % [id, preview, cost, maxi(0, int(model.state.money) - cost)], func():
					if model.upgrade(id, branch.id): save_game(); rebuild()
					else: notify(model.message)))
		else:
			add_label(c, "Максимальный уровень", 17, GREEN)

func upgrade_branch_name(id: String, branch: Dictionary) -> String:
	if id == "locomotive":
		return {"locomotive_engine": "Электромотор", "locomotive_gearbox": "Контроллер тяги", "locomotive_tank": "Аккумулятор"}.get(branch.id, str(branch.name))
	return str(branch.name)

# Where a part sits on the machine, in metres along the body from its centre and above the rail.
func workshop_spot_place(part: String, length: float, axles: Array) -> Vector2:
	var rear = float(axles[0]) if axles.size() > 0 else -length * 0.3
	var front = float(axles[axles.size() - 1]) if axles.size() > 1 else length * 0.3
	match part:
		"bearings": return Vector2(rear, 0.12)
		"brakes": return Vector2(front, 0.12)
		"lever": return Vector2(0.0, 1.35)
		"platform": return Vector2(0.0, 0.5)
		"engine": return Vector2(length * 0.25, 0.95)
		"gearbox": return Vector2(-length * 0.02, 0.95)
		"tank": return Vector2(-length * 0.30, 0.95)
		"suspension": return Vector2(length * 0.22, 0.42)
	return Vector2(0.0, 0.8)

# B1.2c: pulsing markers on the machine, one for each part that can be improved, with its level.
func draw_workshop_spots(id: String, transform: Transform2D) -> void:
	var spec = Geometry.body(id)
	var length = float(spec.length_m)
	var centre = float(spec.region_px[0]) + float(spec.region_px[2]) * 0.5
	var axles: Array = []
	for axle in spec.axles_px: axles.append((float(axle[0]) - centre) / float(spec.region_px[2]) * length)
	var radius = float(spec.wheel_diameter_m) * 0.5
	var target = "wagon" if id.begins_with("W") else id
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var spot_index = 0
	for branch in model.data.upgrade_catalog:
		if branch.target_type != target: continue
		spot_index += 1
		var part = str(branch.id).get_slice("_", 1)
		var place = workshop_spot_place(part, length, axles)
		var pos = transform * (Vector2(place.x, -(place.y - radius)) * ArtV3.PX)
		var level = int(model.object_state(id).levels.get(branch.id, 0))
		var picked = str(branch.id) == workshop_branch
		var pulse = 0.5 + 0.5 * sin(time * 3.0 + place.x)
		draw_circle(pos, 13.0, Color(INK, 0.9))
		draw_arc(pos, 15.0 + 2.5 * pulse, 0, TAU, 28, GOLD if picked else Color(PAPER, 0.85), 2.2 if picked else 1.6, true)
		for k in range(2):
			draw_circle(pos + Vector2(-5.0 + 10.0 * float(k), 0), 3.4, GOLD if k < level else Color(PAPER, 0.35))
		var label = upgrade_branch_name(id, branch)
		var width = 150.0
		draw_string(font, pos + Vector2(-width * 0.5, -24.0 if spot_index % 2 == 1 else 36.0), label, HORIZONTAL_ALIGNMENT_CENTER, width, 15, GOLD if picked else PAPER)
		workshop_hits.append({"branch": str(branch.id), "position": pos})
	draw_set_transform_matrix(Transform2D.IDENTITY)

func upgrade_preview(id: String, branch: Dictionary) -> String:
	var object = model.object_state(id)
	var lv = int(object.levels.get(branch.id, 0))
	var before = model.object_stats(id)
	object.levels[branch.id] = lv + 1
	var after = model.object_stats(id)
	object.levels[branch.id] = lv
	var parts: Array = []
	for key in ["slots", "mass", "brake", "tank", "power", "rolling", "shock", "traction", "speeds"]:
		if not before.has(key) or before[key] == after[key]: continue
		var label = {"slots": "Места", "mass": "Масса, кг", "brake": "Тормоз, Н", "tank": "Батарея, кВт·ч" if id == "locomotive" else "Бак, л", "power": "Мощность, Вт", "rolling": "Качение", "shock": "Повреждение посуды", "traction": "Тяга, Н", "speeds": "Скорость, м/с"}[key]
		parts.append("%s: %s → %s" % [label, str(before[key]), str(after[key])])
	return "\n".join(parts)

func build_missions(right: VBoxContainer) -> void:
	if model.creative():
		# Sandbox: every order of the career is open at any time, and as often as you like.
		add_label(right, "Любые рейсы, любые машины", 22)
		for index in range(model.data.missions.size()):
			var open_mission = model.scaled_mission(model.data.missions[index])
			mission_notice(right, open_mission, "ОТКРЫТЫЙ РЕЙС  ·  %s" % open_mission.id, "К погрузке →", index == 0)
		add_label(right, "Свободные рейсы", 22)
		for offer in model.free_offers():
			mission_notice(right, offer, "СВОБОДНЫЙ РЕЙС", "Взять")
		return
	var mission = model.current_mission()
	if not mission.is_empty():
		mission_notice(right, mission, "ОСНОВНОЙ РЕЙС  ·  %s" % mission.id, "К погрузке →", true)
	else:
		add_label(right, "Линия работает. Выбирай следующую перевозку.", 23)
	add_label(right, "Свободные рейсы", 22)
	for offer in model.free_offers():
		mission_notice(right, offer, "СВОБОДНЫЙ РЕЙС", "Взять · %d монет" % offer.reward)

# B1.2d: an order is a notice pinned to the board: where it goes, what it carries, what it pays, how
# hard the road is, and the button that takes it.
func mission_notice(parent: Node, mission: Dictionary, kind: String, take_text: String, highlighted: bool = false) -> void:
	var problem = model.mission_error(mission)
	var notice = card(parent, GOLD if highlighted else CARD_EDGE)
	var top = HBoxContainer.new()
	notice.add_child(top)
	add_label(top, kind, 14, Color("9a7a3c"))
	var far = model.mission_far_s(mission)
	var distance = add_label(top, "%.1f км" % (far / 1000.0), 15, MUTED_INK)
	distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_label(notice, str(mission.title), 22)
	var places: Array = [model.station_name("A")]
	for stop in mission.dropoffs:
		var name = model.station_name(stop.station)
		if places[places.size() - 1] != name: places.append(name)
	add_label(notice, " → ".join(places), 16, INK)
	var goods: Array = []
	for stop in mission.dropoffs:
		for pair in stop.cargo: goods.append("%s × %d" % [model.cargo_base(pair[0]).name, pair[1]])
	add_label(notice, "Груз: " + ", ".join(goods), 16, MUTED_INK)
	var grade = route_climb_to(far)
	var hard = grade > (0.03 if model.human_powered() else 0.045)
	var road_text = "Ровный путь" if grade <= 0.02 else ("Подъёмы до %.1f%%" % (grade * 100.0))
	if hard: road_text = "Крутой подъём %.1f%%" % (grade * 100.0)
	var bottom = HBoxContainer.new()
	notice.add_child(bottom)
	add_label(bottom, "Награда до %d" % int(mission.reward), 20, GOLD.darkened(0.25))
	var road = add_label(bottom, road_text, 16, RED if hard else (GREEN if grade <= 0.02 else MUTED_INK))
	road.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if problem != "": add_label(notice, problem, 16, RED)
	add_button(notice, take_text, func(): take_mission(mission), problem != "")

# The steepest climb of the road from the depot to distance s (as a grade, 0.03 is 3%), measured
# over 30 m so that a short springboard knoll is not mistaken for a hill.
func route_climb_to(distance: float) -> float:
	var worst = 0.0
	var s = 0.0
	while s <= distance:
		worst = maxf(worst, (model.route.sample(s + 30.0).y - model.route.sample(s).y) / 30.0)
		s += 10.0
	return worst

func mission_description(mission: Dictionary) -> String:
	var stops: Array = []
	for stop in mission.dropoffs:
		var goods: Array = []
		for pair in stop.cargo:
			goods.append("%s × %d" % [model.cargo_base(pair[0]).name, pair[1]])
		stops.append(model.station_name(stop.station) + ": " + ", ".join(goods))
	return "\n".join(stops) + "\nВозьми весь груз или часть. До %d монет за полный набор, оплата после возвращения." % mission.reward

func take_mission(mission: Dictionary) -> void:
	if model.accept_mission(mission):
		start_depot_exit(func(): enter_game_from_depot("loading"))
	else:
		notify(model.message)

# "Just drive": out of the depot without an order.
func take_free_ride() -> void:
	if model.start_free_ride():
		start_depot_exit(func(): enter_game_from_depot("route"))
	else:
		notify(model.message)

func enter_game_from_depot(phase: String) -> void:
	screen = "game"
	zoom_level = fit_train_zoom()
	camera_s = float(model.state.s)
	camera_y = model.route.sample(camera_s).y
	last_phase = phase
	save_game()
	rebuild()

# Leaving the depot: the screen fades to black, the action switches to the road, the road fades in.
func start_depot_exit(action: Callable) -> void:
	if test_mode and not animate_in_tests:
		action.call()
		return
	cancel_drag()
	depot_exit_action = action
	depot_anim = "leave"
	depot_anim_t = 0.0
	ensure_fade_rect()
	sound.play("gear", 0.5, 0.7)

func ensure_fade_rect() -> void:
	if fade_rect != null: return
	var layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade_rect)

func fit_train_zoom() -> float:
	return clampf(10.5 / maxf(10.5, model.train_length()), 0.75, 1.0)

func build_hud(size: Vector2) -> void:
	instruments = Instruments.new()
	instruments.game = self
	instruments.size = size
	ui.add_child(instruments)
	mini_button = Button.new()
	mini_button.position = instruments.mini_rect().position
	mini_button.size = instruments.mini_rect().size
	mini_button.flat = true
	mini_button.tooltip_text = "Открыть карту линии [M]"
	for state in ["normal","hover","pressed","focus"]: mini_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mini_button.pressed.connect(toggle_map)
	ui.add_child(mini_button)
	var buttons_width = (270 if model.human_powered() else 560)*float(settings.text_scale)
	hud = positioned_label("", Rect2(34, 12, size.x - buttons_width - 90, 42), 20)
	hud.autowrap_mode=TextServer.AUTOWRAP_OFF
	hud.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var pause_row = HBoxContainer.new()
	pause_row.position = Vector2(size.x - buttons_width - 34, 10)
	pause_row.size = Vector2(buttons_width, 46)
	pause_row.add_theme_constant_override("separation",10)
	ui.add_child(pause_row)
	map_button = add_button(pause_row, "Карта [%s]" % key_name("map"), toggle_map)
	if not model.human_powered(): add_button(pause_row,"Кабина [%s]" % key_name("cab"),toggle_cab_view)
	add_button(pause_row, "Пауза", pause_game)
	for button in pause_row.get_children():
		for state_name in ["normal","hover","pressed","disabled","focus"]:
			var padding=button.get_theme_stylebox(state_name).duplicate()
			padding.content_margin_top=2;padding.content_margin_bottom=2
			button.add_theme_stylebox_override(state_name,padding)
	order_label=positioned_label("",Rect2(34,64,size.x-68,28),16,Color("c7c3a0"))
	order_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	order_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	hint_label = positioned_label("", Rect2(34, 96, size.x - 68, 64), 17)
	hint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint_label.max_lines_visible=2
	hint_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	action_bar = HBoxContainer.new()
	action_bar.position = Vector2(34, 168)
	action_bar.size = Vector2(size.x - 68, 48)
	action_bar.add_theme_constant_override("separation", 12)
	ui.add_child(action_bar)
	cargo_actions=HBoxContainer.new()
	cargo_actions.position=Vector2(size.x-720,dock_rect().position.y+84)
	cargo_actions.size=Vector2(664,44)
	cargo_actions.alignment=BoxContainer.ALIGNMENT_END
	cargo_actions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(cargo_actions)
	cargo_action_key=""
	last_action_key = ""
	update_hud()

# Lowest edge of the visible top HUD; world signs are kept below it.
func hud_top_clearance() -> float:
	var bottom=56.0
	for label in [order_label,hint_label]:
		if label!=null and label.visible: bottom=maxf(bottom,label.get_rect().end.y+7)
	if action_bar!=null and action_bar.visible: bottom=maxf(bottom,action_bar.position.y+action_bar.size.y)
	return bottom+8

func draw_zone_label() -> void:
	var info=art_world.zone_label() if art_world!=null else {}
	if info.is_empty(): return
	var width=minf(font.get_string_size(info.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+28,maxf(120,info.width))
	var box=Rect2(info.anchor+Vector2(-12,-24),Vector2(width,32))
	draw_style_box(style(Color(INK,0.86),info.color,10),box)
	draw_string(font,box.position+Vector2(14,22),info.text,HORIZONTAL_ALIGNMENT_LEFT,width-20,16,info.color)

func update_hud() -> void:
	if screen != "game" or hud == null:
		return
	update_charge_warning()
	var state = model.state
	var destination = model.next_destination()
	var target_s = float(model.route.station_s[station_number(destination)])
	var order = "Свободное движение" if state.active.is_empty() else str(state.active.title)
	var returning = not state.active.is_empty() and state.active.phase == "return"
	var stop_index = model.station_index()
	var at_station = model.station_name(model.data.stations[stop_index].id) if stop_index >= 0 else ""
	hud.text = "%s · %d м · %s" % [model.journey_heading(),absf(target_s-float(state.s)),model.clock_text()]
	order_label.text=order
	var hint = ""
	if state.phase == "loading":
		if model.selectable_loading():
			var plan=model.loading_preview()
			hint="Выбери груз. Подъём через %d м, до +%.1f%% · %s. Лишнее можно снять." % [maxf(0,plan.first_hill_m),plan.max_grade*100,plan.difficulty]
		else: hint = "Сохранённый заказ: размести весь принятый груз. Его прежние условия сохранены."
	elif returning and model.stopped() and stop_index > 0:
		hint = "Груз доставлен. Разверни состав и возвращайся домой за оплатой."
	elif stop_index >= 0 and model.stopped():
		hint = "Станция «%s». Перетащи груз для этой станции на площадку внизу." % at_station
	elif model.vehicle_id() == "sail":
		hint = "Зажми нижний угол паруса мышью и держи: к мачте — парус раскрыт, назад — ребром. Отпустил — парус полощет и не тянет; отпусти над утёй у кормы (медная скоба) — шкот закреплён. Попутный ветер — раскрой, боковой — наполовину. Тормоз — красный рычаг у носа или клавиша %s."  % key_name("brake")
	elif model.vehicle_id() == "pole":
		hint = "Веди мышью — шест следует за ней. Щелчок втыкает его; держи и тяни мышь назад — едешь, вперёд — встаёшь на шест. Отпустил — шест поднят. Красный рычаг — тормоз."
	elif model.vehicle_id() == "handcar":
		hint = "Зажми деревянный хват и веди его по дуге рычага. Ровные полные ходы разгоняют лучше. Красный рычаг — тормоз."
	elif model.vehicle_id() == "steam":
		if not state.engine: hint = "Кабина [E]: открой дверцу, перетащи уголь из ведра в топку, закрой дверцу и нажми «Розжиг»."
		elif not model.steam_ready(): hint = "Давление растёт: жди %d бар. Вода в кране должна быть открыта." % int(model.boiler_cfg().work_pressure_bar)
		else: hint = "Вентиль — колесо: крути по кругу, отпустишь — закроется сам. Тормоз — красный рычаг."
	elif model.vehicle_id() == "pneumatic":
		hint = "Вентиль — зелёный рычаг, тормоз — красный. Трубки обмерзают: кликай по белому инею на трубках (или клавиша %s сбивает всё сразу). Воздух набирается у компрессора станции." % key_name("ice")
	elif model.vehicle_id() == "locomotive":
		hint = "Тяга — зелёный рычаг, тормоз — красный. Направление выбирается на стоянке кнопками «Тяга ←» и «Тяга →»."
	elif not state.engine:
		hint = "Запуск: подача 0%, передача N. Щёлкни тумблер, затем выбери передачу и подай газ."
	else:
		hint = "Подача — зелёный рычаг, тормоз — красный. Передача меняется при подаче ниже 15%."
	if float(state.brake) > 0.95 and not model.stopped():
		hint = "Торможение."
	if model.stopped() and state.phase == "route" and not returning and stop_index == 0:
		hint = "Переведи красную рукоять к 0%, затем начинай движение."
	if model.vehicle_id() == "locomotive" and model.regen_kw > 0.01:
		hint = "Рекуперация: +%.1f кВт. Часть энергии торможения возвращается в аккумулятор." % model.regen_kw
	var interaction=station_state()
	if mini_button != null and is_instance_valid(mini_button): mini_button.visible = not cab_active()
	order_label.visible=not cab_active() and state.phase=="loading"
	hint_label.visible=not cab_active() and (state.phase=="loading" or (drag!="" and state.tutorial and not interaction.visible))
	action_bar.position.y=168 if state.phase=="loading" else 70
	hint_label.text = hint if state.phase=="loading" else (interaction.reason if interaction.visible else (hint if state.tutorial else ""))
	update_cargo_actions(interaction)
	var key = "%s_%d_%s_%s_%s_%d" % [state.phase, stop_index, str(model.stopped()), str(model.all_loaded()), str(returning), model.drive_direction()]
	if state.phase=="loading": key+=str(model.loading_preview().signature)
	if key != last_action_key:
		last_action_key = key
		clear_children(action_bar)
		if state.phase == "loading":
			add_button(action_bar, "Отправиться →", func():
				if model.depart(): save_game(); rebuild()
				else: notify(model.message), not model.all_loaded())
			add_button(action_bar, "Заехать в депо →", start_depot_entry)
			var plan=model.loading_preview()
			var choice_label=add_label(action_bar,"Везём %d / %d · %d кг · %d монет" % [plan.loaded,plan.capacity,plan.mass_kg,plan.reward],19,PAPER)
			choice_label.add_theme_stylebox_override("normal",style(INK,Color("5d7561"),6))
			choice_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		elif model.stopped():
			if model.vehicle_id() not in ["handcar","pole","sail","motorcar"]:
				add_button(action_bar, "Тяга ←", func():
					if model.set_reverser(-int(state.direction)): save_game(); last_action_key = ""
					else: notify(model.message), false, model.drive_direction() < 0)
				add_button(action_bar, "Тяга →", func():
					if model.set_reverser(int(state.direction)): save_game(); last_action_key = ""
					else: notify(model.message), false, model.drive_direction() > 0)
			if stop_index >= 0:
				add_button(action_bar, "Развернуть", func():
					if model.turn(): save_game(); notify("Состав развёрнут"); last_action_key = ""
					else: notify(model.message), model.can_turn() != "")
			if stop_index == 0:
				add_button(action_bar, "Заехать в депо →", start_depot_entry)
			if model.vehicle_id() == "pneumatic": add_button(action_bar, "Сбить весь иней [%s]" % key_name("ice"), chip_all_ice)
			add_button(action_bar, "Сохранить", func(): save_game(); notify("Сохранено"))
		for child in action_bar.get_children():
			if child is Button: child.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	action_bar.visible=not cab_active() and action_bar.get_child_count()>0 and (state.phase=="loading" or model.stopped())

func energy_text() -> String:
	if model.vehicle_id() == "handcar": return "Ручной привод · %d Вт" % roundi(model.output_power)
	if model.vehicle_id() == "sail": return "Парус · ветер %.1f м/с" % model.wind_here().length()
	if model.vehicle_id() == "pole": return "Шест · опора: %s" % (str(model.pole_ground_at(float(model.pole.tip_s)).name) if model.pole.planted() else "в руках")
	var amount = float(model.state.fleet_by_id[model.vehicle_id()].fuel)
	var cap = float(model.object_stats(model.vehicle_id()).tank)
	if model.vehicle_id() == "locomotive":
		return "Заряд %d%% · %.2f / %.2f кВт·ч" % [roundi(amount / cap * 100), amount, cap]
	if model.vehicle_id() == "steam":
		var fleet = model.state.fleet_by_id.steam
		return "Давление %.1f бар · топка %.1f кг · ведро %.0f / %.0f кг · вода %.0f / %.0f л" % [model.pressure_bar(), float(model.boiler().firebox), amount, cap, float(fleet.get("water", 0)), float(model.object_stats("steam").water)]
	if model.vehicle_id() == "pneumatic":
		return "Давление %.0f / %.0f бар · иней %d%%" % [amount, cap, roundi(model.frost() * 100.0)]
	return "Бензин %.2f / %.1f л" % [amount, cap]

func vehicle_display_name() -> String:
	return str(model.vehicle_base().name)

# What each machine is for, in a few words (the court of the five vehicles and the speed table).
const VEHICLE_ROLE = {
	"handcar": "бесплатная, без топлива; подъём больше 3% ей не по силам",
	"pole": "берёт подъёмы медленно и точно; грунт решает, где упереться",
	"sail": "бесплатный ход по ветру; в штиль стоит, против ветра не идёт",
	"steam": "тянет много, но разгоняется медленнее всех; уголь и вода",
	"motorcar": "самая быстрая; бензин расходует быстро",
	"pneumatic": "сильная на подъёмах; воздух кончается, трубки обмерзают",
	"locomotive": "ровная тяга и рекуперация; батарея садится под нагрузкой"}

# A card with the picture of the machine or wagon on its left; returns the box for the text and buttons.
func picture_card(parent: Node, id: String, bright: bool, edge: Color) -> VBoxContainer:
	var outer = card(parent, edge)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	outer.add_child(row)
	var picture = TextureRect.new()
	picture.texture = art.textures[art.body_key(id)]
	picture.custom_minimum_size = Vector2(150.0, 78.0) * float(settings.text_scale)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.modulate = Color.WHITE if bright else Color(1, 1, 1, 0.55)
	row.add_child(picture)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	return info

# The train as it stands on the rails: the machine and its coupled wagons, then the wagons standing aside.
func consist_strip(parent: Node) -> void:
	var strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 6)
	parent.add_child(strip)
	var coupled: Array = [model.vehicle_id()] + model.state.consist_ids
	for id in coupled:
		var tile = TextureRect.new()
		tile.texture = art.textures[art.body_key(id)]
		tile.custom_minimum_size = Vector2(0, 54.0 * float(settings.text_scale))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.tooltip_text = vehicle_display_name() if id == model.vehicle_id() else str(id)
		strip.add_child(tile)
	add_label(parent, "В составе: %s. Сцепки на рельсах слева тоже нажимаются мышью." % ", ".join(coupled.map(func(id): return vehicle_display_name() if id == model.vehicle_id() else str(id))), 15, MUTED_INK)

func vehicle_summary(id: String) -> String:
	var base = model.vehicle_base(id)
	var places = "%d места на платформе" % int(base.deck_slots) if int(base.deck_slots) > 0 else "без мест на кузове"
	var wagons = "вагонов: до %d" % int(base.get("max_wagons", 0)) if int(base.get("max_wagons", 0)) > 0 else "без вагонов"
	var energy = {"handcar": "без топлива", "steam": "уголь и вода", "motorcar": "бензин", "pneumatic": "сжатый воздух", "pole": "мускулы и шест", "sail": "ветер", "locomotive": "аккумулятор"}.get(id, "")
	return "%s · %s · %s" % [places, wagons, energy]

func station_number(id: String) -> int:
	for i in range(model.data.stations.size()):
		if model.data.stations[i].id == id: return i
	return 0

func pause_game() -> void:
	paused = true
	cancel_drag()
	modal_kind = "pause"
	rebuild()

func toggle_map() -> void:
	if screen != "game": return
	if cab_view: toggle_cab_view()
	if modal_kind == "map": close_modal()
	elif modal_kind == "": show_modal("map")

# E: close in on the cab and work every control there, or step back out. Levers keep
# their positions; only the mouse grab is dropped.
func toggle_cab_view() -> void:
	if screen != "game" or paused or model.human_powered(): return
	cancel_drag()
	cab_view = not cab_view
	cab_resume = false
	update_pult_transform()
	update_hud()
	queue_redraw()

# Electric drive has no gearbox or start switch: only brake and traction levers.
func control_ids() -> Array:
	if model.vehicle_id() == "handcar": return ["pump", "brake"]
	if model.vehicle_id() in ["pole", "sail"]: return ["brake"]
	if model.vehicle_id() in ["locomotive", "pneumatic"]: return ["brake", "throttle"]
	return ["brake", "throttle", "gear", "start"]

func steam_fire_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position+Vector2(150,282),Vector2(130,64))

# In the cab the steam corner of the dashboard has real props: an iron plate, a bucket
# with coal in it and a firebox door that glows and flickers with the fire.
func draw_steam_cab_props(bucket: Rect2, fire: Rect2, door_button: Rect2, boiler: Dictionary, fleet: Dictionary) -> void:
	var plate = Rect2(bucket.position - Vector2(14, 14), Vector2(fire.end.x - bucket.position.x + 28, door_button.end.y - bucket.position.y + 30))
	draw_style_box(style(Color("232a28"), Color("6c6f66"), 6), plate)
	for rivet in [plate.position + Vector2(7, 7), Vector2(plate.end.x - 7, plate.position.y + 7), Vector2(plate.position.x + 7, plate.end.y - 7), plate.end - Vector2(7, 7)]:
		draw_circle(rivet, 3.0, Color("a98a4a"))
	# bucket: tapered, hooped, a handle and a heap of coal that shrinks with the stock
	var body = PackedVector2Array([bucket.position + Vector2(16, 26), Vector2(bucket.end.x - 16, bucket.position.y + 26), Vector2(bucket.end.x - 24, bucket.end.y - 4), bucket.position + Vector2(24, bucket.size.y - 4)])
	draw_colored_polygon(body, Color("2a2f2c"))
	draw_polyline(PackedVector2Array([bucket.position + Vector2(18, 28), bucket.position + Vector2(56, 4), Vector2(bucket.end.x - 18, bucket.position.y + 28)]), Color("8a8a7a"), 2.5, true)
	draw_line(bucket.position + Vector2(20, 40), Vector2(bucket.end.x - 20, bucket.position.y + 40), Color("6c6f66"), 3.0)
	var stock = clampf(float(fleet.fuel) / float(model.object_stats("steam").tank), 0.0, 1.0)
	for lump in range(int(8 + 10 * stock)):
		var lx = bucket.position.x + 24 + fposmod(lump * 23.0, bucket.size.x - 48)
		draw_circle(Vector2(lx, bucket.position.y + 26 - 2.0 * stock * (lump % 3)), 4.0 + (lump % 3), Color("141517") if lump % 2 == 0 else Color("2c2e33"))
	if drag == "coal": draw_arc(bucket.get_center(), 54, 0, TAU, 28, GOLD, 2.0, true)
	# firebox door: an iron arch with the fire behind it; the fire lights the dashboard
	var heat = float(boiler.heat)
	if heat > 0.05:
		var flicker = 1.0 if settings.reduce_motion else 0.7 + 0.3 * sin(time * 9.0) * sin(time * 3.7)
		for ring in range(5): draw_circle(fire.get_center(), 60.0 + ring * 38.0, Color(1.0, 0.5, 0.12, 0.05 * heat * flicker))
	var door_open = bool(boiler.door)
	draw_rect(fire, Color("0a0b0b"))
	if heat > 0.02:
		var inner = fire.grow(-6)
		draw_polygon(PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.end.x, inner.end.y), Vector2(inner.position.x, inner.end.y)]), PackedColorArray([Color(0.35 + 0.3 * heat, 0.1, 0.02), Color(0.35 + 0.3 * heat, 0.1, 0.02), Color(1.0, 0.55 + 0.3 * heat, 0.1), Color(1.0, 0.55 + 0.3 * heat, 0.1)]))
		for flame in range(6):
			var fx = inner.position.x + inner.size.x * (flame + 0.5) / 6.0
			var flick = 0.55 + 0.45 * sin(time * 8.0 + flame * 1.9)
			var fh = (6.0 + 26.0 * heat) * flick
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 9, inner.end.y), Vector2(fx + 9, inner.end.y), Vector2(fx + sin(time * 5.0 + flame) * 4.0, inner.end.y - fh)]), Color(1.0, 0.8 - 0.2 * flick, 0.2, 0.85))
	if not door_open:
		# closed leaf with slits the glow shows through
		var leaf = fire.grow(-3)
		draw_rect(leaf, Color("2d3230"))
		for slit in range(4):
			var sy = leaf.position.y + 9 + slit * 11
			draw_line(Vector2(leaf.position.x + 12, sy), Vector2(leaf.end.x - 12, sy), Color(1.0, 0.6, 0.15, 0.2 + 0.7 * heat) if heat > 0.02 else Color("0a0b0b"), 3.0)
		draw_circle(Vector2(leaf.end.x - 14, leaf.get_center().y), 5.0, Color("c9a85a"))
		draw_rect(leaf, Color("5c615a"), false, 2.0)
	else:
		draw_polygon(PackedVector2Array([fire.position + Vector2(-26, -4), fire.position + Vector2(-2, 6), fire.position + Vector2(-2, fire.size.y - 6), fire.position + Vector2(-26, fire.size.y + 4)]), PackedColorArray([Color("3a403d"), Color("2d3230"), Color("2d3230"), Color("3a403d")]))
		draw_rect(fire, GOLD if drag == "coal" else Color("a98a4a"), false, 2.5)
	draw_arc(Vector2(fire.get_center().x, fire.position.y), fire.size.x * 0.5, PI, TAU, 18, Color("5c615a"), 3.0, true)

# Boiler corner of the steam pult: coal bucket, firebox with door, manometer.
func draw_steam_panel(rect: Rect2) -> void:
	var b=model.boiler()
	var cfg=model.boiler_cfg()
	var fleet=model.state.fleet_by_id.steam
	var dim=Color("c7c3a0")
	var bucket=Rect2(rect.position+Vector2(16,282),Vector2(112,64))
	var fire=steam_fire_rect(rect)
	var door_button=Rect2(rect.position+Vector2(150,352),Vector2(130,28))
	var heat=float(b.heat)
	if cab_active(): draw_steam_cab_props(bucket,fire,door_button,b,fleet)
	else: draw_style_box(style(Color("3b2c1f"),GOLD if drag=="coal" else Color("66796b"),6),bucket)
	draw_string(font,bucket.position+Vector2(0,24),"ВЕДРО",HORIZONTAL_ALIGNMENT_CENTER,112,16,PAPER)
	draw_string(font,bucket.position+Vector2(0,50),"%.0f кг" % float(fleet.fuel),HORIZONTAL_ALIGNMENT_CENTER,112,18,GOLD)
	draw_string(font,bucket.position+Vector2(0,82),"тащи в топку",HORIZONTAL_ALIGNMENT_CENTER,112,13,dim)
	var fire_edge=GOLD if (bool(b.door) and drag=="coal") else (PAPER if bool(b.door) else Color("66796b"))
	var glow=roundf(heat*12.0)/12.0
	if not cab_active(): draw_style_box(style(Color(0.12+0.5*glow,0.07+0.2*glow,0.05),fire_edge,6),fire)
	draw_string(font,fire.position+Vector2(0,24),"ТОПКА",HORIZONTAL_ALIGNMENT_CENTER,130,16,PAPER)
	draw_string(font,fire.position+Vector2(0,50),"%.1f / %d кг" % [float(b.firebox),int(cfg.firebox_kg)],HORIZONTAL_ALIGNMENT_CENTER,130,17,GOLD)
	# B3.4: the fire is good between a third and 85% of the grate: thinner burns out, fuller chokes
	var fill=clampf(float(b.firebox)/float(cfg.firebox_kg),0.0,1.0)
	var bar=Rect2(fire.position+Vector2(12,56),Vector2(106,6))
	draw_rect(bar,Color("141a17"))
	draw_rect(Rect2(bar.position+Vector2(bar.size.x*float(cfg.thin_fire),0),Vector2(bar.size.x*(float(cfg.choke_from)-float(cfg.thin_fire)),bar.size.y)),Color("27402f"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*fill,bar.size.y)),Color("5cc17f") if fill>=float(cfg.thin_fire) and fill<=float(cfg.choke_from) else Color("e0564a"))
	draw_style_box(style(INK,GOLD if bool(b.door) else Color("66796b"),6),door_button)
	draw_string(font,door_button.position+Vector2(0,20),"Дверца: открыта" if bool(b.door) else "Дверца: закрыта",HORIZONTAL_ALIGNMENT_CENTER,130,14,PAPER)
	var center=rect.position+Vector2(360,322)
	var first=deg_to_rad(150)
	var sweep=deg_to_rad(240)
	draw_arc(center,40,first,first+sweep,40,Color("66796b"),3,true)
	var work=float(cfg.work_pressure_bar)/float(cfg.max_pressure_bar)
	var mark=Vector2.from_angle(first+sweep*work)
	draw_line(center+mark*34,center+mark*46,GREEN,3,true)
	var needle=Vector2.from_angle(first+sweep*float(b.pressure))
	draw_line(center,center+needle*34,RED if bool(b.venting) else PAPER,2.5,true)
	draw_circle(center,3,PAPER)
	draw_string(font,center+Vector2(-50,58),"%.1f бар" % model.pressure_bar(),HORIZONTAL_ALIGNMENT_CENTER,100,16,GOLD if model.steam_ready() else dim)
	draw_string(font,center+Vector2(-50,-48),"ДАВЛЕНИЕ",HORIZONTAL_ALIGNMENT_CENTER,100,13,dim)
	steam_hits.append({"id":"bucket","rect":Rect2(pult_t*bucket.position,bucket.size*pult_t.get_scale())})
	steam_hits.append({"id":"door","rect":Rect2(pult_t*door_button.position,door_button.size*pult_t.get_scale())})
	if drag=="coal":
		var piece=Rect2(pult_t.affine_inverse()*drag_cursor-Vector2(9,9),Vector2(18,18))
		draw_rect(piece,Color("1b1713"))
		draw_rect(piece,GOLD,false,2)

# Clicks on the dashboard buttons: the direction switch (steam, electric) and the
# emergency stop (electric). The direction rules are the same as the buttons outside.
func cab_button(id: String) -> void:
	if id == "forward" or id == "back":
		if model.set_reverser(1 if id == "forward" else -1): save_game()
		else: notify(model.message)
	elif id == "emergency":
		model.state.throttle = 0.0
		model.state.brake = 1.0
		notify("Аварийное торможение: тяга снята, тормоз затянут")

# What is drawn and grabbed on the machine itself: the main organs only. The
# rest (gearbox, tap, ignition, fire door, coal) live in the pult on C.
func world_control_ids() -> Array:
	if model.vehicle_id() == "handcar": return ["pump", "brake"]
	if model.vehicle_id() in ["pole", "sail"]: return ["brake"]
	return ["brake", "throttle"]

# A forged lever: mounting plate, brass pivot, tapered steel arm with a collar and
# an enamel ball grip. Drawn in the local frame of `base`, hinged at `pivot`.
func draw_lever(base: Transform2D, pivot: Vector2, length: float, angle: float, knob: Color, active: bool) -> void:
	draw_set_transform_matrix(base * Transform2D(angle, pivot))
	var w = clampf(length * 0.06, 2.0, 5.0)
	var plate = Rect2(Vector2(-w * 2.6, -w * 0.6), Vector2(w * 5.2, w * 2.6))
	draw_rect(plate, Color("2b3430"))
	draw_rect(plate, Color("918363"), false, 1.0)
	var arm = PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.55, -length), Vector2(-w * 0.55, -length)])
	draw_colored_polygon(arm, Color("8d9a98"))
	draw_line(Vector2(-w * 0.45, -2), Vector2(-w * 0.3, -length + 2), Color("d6dedb"), 1.2, true)
	draw_line(Vector2(w * 0.5, -2), Vector2(w * 0.3, -length + 2), Color("56635f"), 1.2, true)
	draw_rect(Rect2(Vector2(-w * 1.15, -length * 0.62), Vector2(w * 2.3, w * 0.9)), Color("c9af73"))
	var radius = clampf(length * 0.11, 4.0, 9.0)
	var ball = Vector2(0, -length - radius * 0.4)
	draw_circle(ball + Vector2(1.5, 1.5), radius, Color(0, 0, 0, 0.35))
	draw_circle(ball, radius, knob)
	draw_circle(ball + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.32, Color(1, 1, 1, 0.45))
	if active: draw_arc(ball, radius + 2, 0, TAU, 20, PAPER, 1.2, true)
	draw_circle(Vector2.ZERO, w * 1.1, Color("c9af73"))
	draw_circle(Vector2.ZERO, w * 0.45, Color("2a2f2c"))
	draw_set_transform_matrix(base)

func control_zoom_rect() -> Rect2:
	return Rect2(36,90,430,456 if model.vehicle_id()=="steam" else 320)

func control_zoom_transform() -> Transform2D:
	return Transform2D(0,Vector2.ONE*2.2,0,control_zoom_rect().position+Vector2(330,392))

func draw_control_zoom() -> void:
	var rect = control_zoom_rect()
	draw_set_transform_matrix(pult_t)
	var ids=control_ids()
	for i in range(ids.size()):
		var id=ids[i]
		var geo=control_geometry(id,true)
		var pivot=geo.pivot
		var angle=geo.angle
		var length=pivot.distance_to(geo.grip)
		var point=geo.grip
		var kind=control_kind(id)
		if kind=="gate":
			draw_gate(gate_rect(true),gate_pos if drag=="gear" else gate_slot_pos(int(model.state.gear)),drag==id)
		elif kind=="wheel":
			draw_handwheel(pivot,float(geo.radius),angle,GOLD if id=="gear" else GREEN,drag==id)
		elif kind=="slider":
			draw_slider(pult_t,pivot,float(geo.length),float(model.state.get(id,0)),Color("c23b2e") if id=="brake" else Color("4f9a5f"),drag==id)
		elif id in ["brake","throttle"]:
			draw_arc(pivot,length,-PI/2-0.55,-PI/2+0.55,32,Color("66796b"),2,true)
			for notch in range(11):
				var tick=pivot+Vector2(0,-length-5).rotated(lerpf(-0.55,0.55,notch/10.0))
				draw_line(pivot+(tick-pivot).normalized()*(length-3),tick,Color("66796b"),1,true)
			draw_lever(pult_t,pivot,length,angle,Color("c23b2e") if id=="brake" else Color("4f9a5f"),drag==id)
		else:
			if id!="start":
				draw_arc(pivot,length,-PI/2-0.55,-PI/2+0.55,32,Color("66796b"),2,true)
			var source_length=float({"brake":166,"throttle":165,"gear":166,"start":138}[id])
			var factor=length/source_length
			sprite("control_mount",Rect2(pivot-Vector2(8,8),Vector2(16,16)))
			draw_set_transform_matrix(pult_t*Transform2D(angle,pivot))
			sprite("control_"+id,Rect2(-Vector2(128,224)*factor,Vector2.ONE*256*factor))
			draw_set_transform_matrix(pult_t)
		grip_hits.append({"id":id,"position":pult_t*point,"closeup":true})
		var steam=model.vehicle_id()=="steam"
		var title={"brake":"Тормоз","throttle":{"locomotive":"Тяга","steam":"Вентиль","pneumatic":"Вентиль"}.get(model.vehicle_id(),"Газ"),"gear":"Вода" if steam else "Передача","start":"Розжиг" if steam else "Пуск"}[id]
		var shown_gear=lever_pending_gear if drag=="gear" else int(model.state.gear)
		var label={"brake":"%d%%" % (model.state.brake*100),"throttle":"%d%%" % (model.state.throttle*100),"gear":("%d%%" % (float(model.boiler().feed)*100)) if steam else GEAR_LABELS[shown_gear],"start":("Горит" if model.state.engine else "Разжечь") if steam else ("Вкл." if model.state.engine else "Выкл.")}[id]
		draw_string(font,rect.position+Vector2(15+100*i,78),title,HORIZONTAL_ALIGNMENT_CENTER,100,16,PAPER)
		draw_string(font,rect.position+Vector2(15+100*i,168 if id=="start" else (268 if kind=="slider" else 253)),label,HORIZONTAL_ALIGNMENT_CENTER,100,16,GOLD)
		if kind=="lever":
			for endpoint in range(2):
				var mark=pivot+Vector2(0,-length).rotated(lerpf(-0.55,0.55,float(endpoint)))
				# the ends of neighbouring levers stand close: "100" is set higher than "0" so that they never touch
				draw_string(font,mark+Vector2(-17,-27 if endpoint==1 else -12),["0","100"][endpoint],HORIZONTAL_ALIGNMENT_CENTER,34,13,PAPER)
		if drag==id or (pult_t*point).distance_to(get_global_mouse_position())<24: draw_arc(point,10,0,TAU,28,PAPER,1.5,true)
	if model.vehicle_id()=="steam": draw_steam_panel(rect)
	var feedback=toast if toast_seconds>0 else ("Крути вентиль по кругу, отпусти — закроется сам. Розжиг — щелчком." if model.vehicle_id()=="steam" else ("Веди шар рычага по кулисе: через N в нужный паз. Пуск — щелчком." if model.vehicle_id()=="motorcar" else ("Двигай ручки вверх и вниз по прорезям, они держат положение." if model.vehicle_id()=="locomotive" else "Веди рукоять по дуге: вентиль открывает воздух, тормоз держит состав.")))
	draw_multiline_string(font,rect.position+Vector2(16,rect.size.y-35),feedback,HORIZONTAL_ALIGNMENT_LEFT,310,15,2,GOLD if toast_seconds>0 else Color("c7c3a0"))

func show_modal(kind: String) -> void:
	cancel_drag()
	cab_view = false
	if screen != "menu": paused = true
	if kind == "settings":
		settings_backup = settings.duplicate(true)
		awaiting_key = ""
	modal_kind = kind
	rebuild()

func close_modal() -> void:
	if modal_kind == "settings" and settings_changed():
		# Closed without "Применить": put back what the menu found.
		copy_settings(settings, settings_backup)
		apply_settings()
		apply_window_size()
	awaiting_key = ""
	resume_prompt=false
	modal_kind = ""
	paused = false
	rebuild()

func confirm(text: String, action: Callable) -> void:
	toast = text
	pending_action = action
	show_modal("confirm")

func build_modal(size: Vector2) -> void:
	if modal_kind == "map":
		var map_view = Instruments.new()
		map_view.game = self
		map_view.full_map = true
		map_view.size = size
		overlay.add_child(map_view)
		var close_row = HBoxContainer.new()
		var close_width = 230*float(settings.text_scale)
		close_row.position = Vector2(size.x-close_width-50,38)
		close_row.size = Vector2(close_width,48)
		overlay.add_child(close_row)
		add_button(close_row,"Закрыть [%s / Esc]" % key_name("map"),close_modal)
		return
	var shade = ColorRect.new()
	shade.color = Color(0.08, 0.13, 0.11, 0.76)
	shade.size = size
	overlay.add_child(shade)
	var width = minf(940, size.x - 100)
	var box = panel_at(overlay, Rect2((size.x - width) / 2, 80, width, size.y - 160), true)
	if modal_kind == "confirm":
		add_label(box, "Подтверждение", 30)
		add_label(box, toast, 23)
		add_button(box, "Подтвердить", func():
			var action = pending_action
			modal_kind = ""
			paused = false
			toast = ""
			action.call()
			rebuild())
		add_button(box, "Отмена", close_modal)
	elif modal_kind == "pause":
		add_label(box, "Пауза", 34)
		if resume_prompt: add_label(box, "Готов продолжить поездку?", 23)
		add_button(box, "Продолжить", close_modal)
		add_button(box, "Сохранить", func(): save_game(); notify("Сохранено"))
		add_button(box, "Настройки", func(): show_modal("settings"))
		add_button(box, "Как играть", func(): show_modal("help"))
		add_button(box, "Помощь депо", func(): confirm("Вернуть состав домой? Груз, отметки доставки и покупки сохранятся. Запас энергии пополнится.", func():
			model.rescue()
			screen = "depot"
			camera_s = 0
			save_game()
			if model.state.paid_ids.size() > last_paid_count:
				last_paid_count = model.state.paid_ids.size()
				show_modal("result")
			else: rebuild()))
		add_button(box, "В главное меню", func(): save_game(); screen = "menu"; close_modal())
	elif modal_kind == "settings":
		build_settings(box)
	elif modal_kind == "help":
		add_label(box, "Как играть", 32)
		add_label(box, "1. В депо выбери рейс и нажми «К погрузке». Перетащи каждый предмет с площадки в свободное место на машине или вагоне. Когда всё погружено, просто тронься: дай ход, и рейс начался (кнопка «Отправиться» тоже есть).\n\n2. Тормоз ставить на станции не нужно: остановился на платформе, и состав стоит сам, он отпустится, когда дашь ход. В пути тормоз красной рукоятью, веди её по дуге к 0%. На ручной дрезине веди любой конец деревянного рычага по его дуге. На спуске можно катиться по инерции.\n\n3. Перед станцией плавно переведи тормоз к 100%. Остановись в пределах платформы, затяни тормоз до 100% и перетащи нужные грузы на площадку. У каждого предмета указана станция.\n\n4. После последней доставки убери подачу, разверни пустой состав кнопкой на станции и вернись в Лесную. Деньги выдаются в домашнем депо.\n\n5. Парк растёт так: ручная дрезина → паровоз (500) → бензиновая машина (1000) → электровоз (3000). У трёх последних нет мест на кузове: груз едет в вагонах. Первый вагон W01 входит в покупку, W02 и W03 покупаются отдельно. Не хватает денег — бери свободные рейсы: сильная машина платит за них больше. Скорости: ручная 25, паровоз 50, электровоз 75, бензиновая 100 км/ч. «Творческий режим» из меню: всё открыто, деньги и топливо без ограничений, любые рейсы.\n\n6. Паровоз: разожги котёл тумблером (режим Н, регулятор 0%), выбери отсечку 1 и открой регулятор. Он тратит уголь и воду. Бензиновая машина запускается так же и тратит бензин. Электровоз тратит заряд; ниже 75% заряда тяга слабеет, торможение возвращает часть энергии. Пополнение платное: в депо и на станции Дальний бор (там в полтора раза дороже), воду можно набрать ещё на Тихой заводи. Остановись у платформы, затяни тормоз и нажми «Заправить» в панели станции. Бака хватает примерно на один рейс туда и обратно: смотри строку «Рейс: нужно… есть…» в депо и на карте.\n\n7. Вагоны в депо стоят на пути. Щёлкни по сцепке между составом и вагоном: хвостовой вагон отъедет, ближайший стоящий подкатится и сцепится. Улучшения следуют за ID вагона. Для финального рейса нужны шесть мест.\n\nЗадний ход: остановись, затяни тормоз и выбери стрелку направления. На ручной дрезине направление задаётся усилием на рычаге с отпущенным тормозом. Обратное усилие сначала замедляет движение. В мёртвой точке потяни край платформы, чтобы подтолкнуть машину. Состав при этом сохраняет положение и груз.\n\nКолесо мыши — приблизить машину. Esc — пауза. Карта и кабина открываются клавишами из настроек (по умолчанию M и E). В кабине все органы и приборы машины; на станции кабина сама опускается, чтобы был виден груз, а когда тронешься, поднимается снова. При потере фокуса игра останавливается. Если застрял или кончилась энергия, вызови помощь депо из паузы.", 20)
		if screen != "menu":
			add_button(box, "Подсказки: " + ("вкл." if model.state.tutorial else "выкл."), func(): model.state.tutorial = not model.state.tutorial; save_game(); rebuild())
		add_button(box, "Понятно", close_modal)
	elif modal_kind == "result":
		var result = model.state.get("last_result", {})
		add_label(box, "Линия работает" if result.get("final", false) else "С возвращением", 38)
		add_label(box, "Линия работает. До Дальнего бора снова ходят поезда. А дома тебя ждёт следующий рейс." if result.get("final", false) else str(result.get("title", "Рейс окончен")), 25)
		add_label(box, "Оплата: %d монет\nВсего доставлено: %d предметов\nПройдено: %.1f км\nОсновные рейсы: %d / 10" % [result.get("reward", 0), model.state.stats.deliveries, float(model.state.stats.distance) / 1000, model.state.chapter], 23)
		add_button(box, "Продолжить перевозки", close_modal)
		add_button(box, "В главное меню", func(): screen = "menu"; close_modal())
	else:
		add_label(box, "Лесная колея", 36)
		add_label(box, "Небольшая игра о работе лесной железной дороги.\nРазработка: Codex совместно с владельцем проекта, 2026.\nГрафика: предоставленный комплект ForestRail, созданный с image_gen. Звуки синтезированы для этого комплекта.\nGodot Engine 4.7.2, лицензия MIT. Полные лицензии движка и его компонентов включены в поставку.\n\nВерсия игры %s · ТЗ 3.0 · проверка P8." % ProjectSettings.get_setting("application/config/version"), 22)
		add_button(box, "Назад", close_modal)

func save_game() -> bool:
	cancel_drag()
	if not saves.write(model):
		notify(saves.error)
		return false
	return true

func notify(text: String) -> void:
	toast = text
	toast_seconds = 5.0

func cancel_drag() -> void:
	drag = ""
	drag_item = ""
	drag_total = 0
	drag_horizontal = 0
	model.reset_input()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _process(dt: float) -> void:
	time += dt
	if depot_anim != "": advance_depot_anim(dt)
	if screen != "game" or model.human_powered(): cab_view = false
	if screen == "game" and not paused and not model.human_powered() and not model.state.is_empty():
		var docked = model.state.phase == "loading" or (model.state.phase == "route" and model.station_index() >= 0 and model.stopped())
		if docked and not was_docked and cab_view:
			cab_view = false
			cab_resume = true
			cancel_drag()
			update_pult_transform()
			update_hud()
		elif cab_resume and not docked and model.state.phase == "route" and absf(float(model.state.v)) > 0.5:
			cab_view = true
			cab_resume = false
			update_pult_transform()
			update_hud()
		was_docked = docked
	cab_blend = move_toward(cab_blend, 1.0 if cab_view else 0.0, dt * 4.0)
	cab_dt = minf(dt, 0.033)
	cab_jolt = move_toward(cab_jolt, 0.0, dt * 4.0)
	if cab_active() and not model.state.is_empty():
		var joint = floori(model.render_s() * float(model.state.direction) / 12.0)
		if joint != cab_joint:
			if cab_joint != -999999 and absf(float(model.state.v)) > 0.3: cab_jolt = minf(1.0, 0.35 + absf(float(model.state.v)) * 0.06)
			cab_joint = joint
	else:
		cab_joint = -999999
	if screen == "game" and not model.state.is_empty() and model.vehicle_id() == "motorcar":
		cab_temp = model.engine_temp()   # B3.4: the real engine temperature, not a picture of one
	if ui != null and ui.visible == cab_active(): ui.visible = not cab_active()
	if art_world != null and art_world.visible == cab_active(): art_world.visible = not cab_active()
	update_pult_transform()
	update_cab_sides()
	model.valve_held = drag == "throttle"
	advance_shunting(dt)
	if not delivery_ghost.is_empty():
		delivery_ghost.time+=dt
		if delivery_ghost.time>0.45: delivery_ghost={}
	toast_seconds = maxf(0, toast_seconds - dt)
	if screen != "menu" and not model.state.is_empty():
		var target_s = model.render_s()
		if screen == "depot": target_s = 0
		# The camera keeps following while a cab lever, the sail or the pole is held; lever input is read in
		# the machine's own frame, so the grip stays under the cursor instead of the
		# train driving away from a frozen camera.
		if drag in ["","pump","brake","throttle","gear","start","coal","sail","pole"]:
			camera_s = lerpf(camera_s, target_s, 1 - exp(-dt * 6))
			camera_y = lerpf(camera_y, model.route.sample(camera_s).y, 1 - exp(-dt * 4))
		var target_x = get_viewport_rect().size.x * (0.31 if screen == "depot" else (0.65 if model.state.direction > 0 else 0.35))
		if screen == "depot" and not model.state.consist_ids.is_empty(): target_x = get_viewport_rect().size.x * 0.46 - 136
		if drag in ["","pump","brake","throttle","gear","start","coal","sail","pole"]: camera_x = lerpf(camera_x if camera_x > 0 else target_x, target_x, 1 - exp(-dt * 3))
		refresh_seconds += dt
		if refresh_seconds >= 0.08:
			refresh_seconds = 0
			update_hud()
		if screen == "game" and model.state.phase == "depot":
			screen = "depot"
			if model.state.paid_ids.size() > last_paid_count:
				last_paid_count = model.state.paid_ids.size()
				save_game()
				show_modal("result")
			else:
				rebuild()
		if model.message != "" and model.message != "Готов продолжить поездку?":
			notify(model.message)
			model.message = ""
	while not model.events.is_empty():
		var event_name = str(model.events.pop_front())
		if event_name == "land":
			# The train comes down on the rail: a thud scaled by the hit, and the cab shakes.
			sound.play("cargo", clampf(0.3 + float(model.last_landing) * 0.2, 0.3, 1.0), 0.7)
			cab_jolt = 1.0
		else: sound.play(event_name, 0.6)
	sound.update(model, paused, screen == "menu", dt, cab_active())
	if art_world != null: art_world.update_view()
	queue_redraw()
	if smoke_frames >= 0:
		smoke_frames -= 1
		if smoke_frames == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(screenshot_path)
			get_tree().quit()

func _physics_process(dt: float) -> void:
	if screen != "game" or paused: model.last_movement = 0.0
	if screen == "game" and not paused:
		model.physics_step(dt)
		autosave += dt
		if float(settings.autosave) > 0.0 and autosave >= float(settings.autosave) and drag == "":
			autosave = 0
			save_game()

# --- Entering the depot (B1.2a): the train rolls to its mark, the view closes in, the screen fades to
# black, the depot opens and fades in. Any key or click skips the rolling part.
func start_depot_entry() -> void:
	if depot_anim != "" or screen != "game" or model.state.phase == "depot": return
	if not model.stopped():
		notify("Остановись у платформы, чтобы заехать в депо")
		return
	if model.station_index() != 0:
		notify(model.message if model.message != "" else "Заехать в депо можно на станции Лесная")
		return
	cancel_drag()
	depot_anim = "in"
	depot_anim_t = 0.0
	depot_anim_from = float(model.state.s)
	depot_anim_zoom = zoom_level
	ensure_fade_rect()
	sound.play("gear", 0.5, 0.7)

func skip_depot_anim() -> void:
	if depot_anim == "in": depot_anim_t = maxf(depot_anim_t, DEPOT_MOVE_S)
	elif depot_anim == "leave": depot_anim_t = DEPOT_FADE_S
	elif depot_anim == "out": depot_anim_t = DEPOT_FADE_S

func advance_depot_anim(dt: float) -> void:
	depot_anim_t += dt
	if depot_anim == "in":
		var mark = float(model.service_stop(0))
		var move = clampf(depot_anim_t / DEPOT_MOVE_S, 0.0, 1.0)
		model.state.s = lerpf(depot_anim_from, mark, smoothstep(0.0, 1.0, move))
		model.state.v = 0.0
		model.state.brake = 1.0
		zoom_level = lerpf(depot_anim_zoom, minf(1.5, depot_anim_zoom * 1.25), smoothstep(0.0, 1.0, move))
		if fade_rect != null: fade_rect.color.a = clampf((depot_anim_t - DEPOT_MOVE_S) / DEPOT_FADE_S, 0.0, 1.0)
		if depot_anim_t >= DEPOT_MOVE_S + DEPOT_FADE_S:
			zoom_level = depot_anim_zoom
			if model.back_to_depot():
				screen = "depot"
				save_game()
				rebuild()
				depot_anim = "out"
				depot_anim_t = 0.0
			else:
				notify(model.message)
				depot_anim = ""
				if fade_rect != null: fade_rect.color.a = 0.0
	elif depot_anim == "leave":
		if fade_rect != null: fade_rect.color.a = clampf(depot_anim_t / DEPOT_FADE_S, 0.0, 1.0)
		if depot_anim_t >= DEPOT_FADE_S:
			if depot_exit_action.is_valid(): depot_exit_action.call()
			depot_exit_action = Callable()
			depot_anim = "out"
			depot_anim_t = 0.0
	elif depot_anim == "out":
		if fade_rect != null: fade_rect.color.a = 1.0 - clampf(depot_anim_t / DEPOT_FADE_S, 0.0, 1.0)
		if depot_anim_t >= DEPOT_FADE_S:
			depot_anim = ""
			if fade_rect != null: fade_rect.color.a = 0.0

func _input(event: InputEvent) -> void:
	if depot_anim != "" and ((event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)):
		skip_depot_anim()
		get_viewport().set_input_as_handled()
		return
	if awaiting_key != "" and event is InputEventKey and event.pressed and not event.echo:
		bind_key(event.keycode)
		get_viewport().set_input_as_handled()
		return
	if key_is(event,"brake") and event.pressed and not event.echo and screen=="game" and not paused and model.state.phase=="route" and model.vehicle_id()!="handcar":
		# one key sets the brake fully or lets it go, so that the hands stay on the sail or the pole
		model.state.brake = 0.0 if float(model.state.brake) > 0.5 else 1.0
		model.auto_brake = false
		notify("Тормоз затянут" if float(model.state.brake) > 0.5 else "Тормоз отпущен")
		get_viewport().set_input_as_handled()
		return
	if key_is(event,"ice") and event.pressed and not event.echo and screen=="game" and not paused and model.vehicle_id()=="pneumatic":
		chip_all_ice()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and key_is(event,"cab") and screen=="game" and not paused:
		toggle_cab_view()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and key_is(event,"map") and screen=="game":
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if cab_view:
			toggle_cab_view()
			get_viewport().set_input_as_handled()
			return
		if modal_kind == "": pause_game()
		else: close_modal()
		get_viewport().set_input_as_handled()
		return
	if drag == "" and event is InputEventMouseMotion and screen == "game" and not paused and model.vehicle_id() == "pole" and model.state.phase == "route":
		model.pole_aim(pole_mouse_rel(event.position))
		return
	if drag == "": return
	if event is InputEventMouseMotion:
		if paused: cancel_drag(); return
		if drag == "sail":
			# relative motion in the machine's own frame, so that the car running away from the camera
			# does not drag the sail with it (the same lesson as with the brake lever)
			var outer_sail = body_transform(model.vehicle_id(), model.body_s_render(0))
			var moved = outer_sail.affine_inverse().basis_xform(event.relative * float(settings.sensitivity)).x / ArtV3.PX * float(int(model.state.direction))
			if not is_finite(moved): moved = 0.0
			sail_hold = clampf(sail_hold - moved, 0.0, ArtV3.SAIL_BOOM)
			model.set_sail_trim(acos(clampf(sail_hold / ArtV3.SAIL_BOOM, 0.0, 1.0)) * 2.0 / PI)
			get_viewport().set_input_as_handled()
			return
		if drag == "pole":
			# Free pushing: how far the hand is drawn back from where the pole was planted is how
			# hard the person leans on it; forward is leaning the other way (standing on the pole).
			var rel = pole_mouse_rel(event.position)
			model.pole_effort(clampf(-(rel - pole_press_rel) / 0.8, -1.0, 1.0))
			get_viewport().set_input_as_handled()
			return
		if drag=="cargo" or drag=="coal":
			drag_cursor=event.position
			get_viewport().set_input_as_handled()
			return
		if drag=="push":
			var outer=body_transform(model.vehicle_id(),model.body_s_render(0))
			var delta=(outer.affine_inverse()*event.position-outer.affine_inverse()*push_cursor).x/ArtV3.PX*int(model.state.direction)
			model.push_handcar(delta)
			push_cursor=event.position
			get_viewport().set_input_as_handled()
			return
		var delta_y = event.relative.y * float(settings.sensitivity)
		drag_total += delta_y
		if drag == "pump":
			if float(model.state.brake) > 0.9 and absf(delta_y) > 2: notify("Тормоз затянут. Переведи красную рукоять к 0%")
			var outer=body_transform(model.vehicle_id(),model.body_s_render(0))
			# Accumulate local cursor travel. Camera translation never changes
			# the target; capture offset is retained without snapping the grip.
			pump_target_point+=outer.affine_inverse().basis_xform(event.relative)*float(settings.sensitivity)/ArtV3.PX
			model.set_pump_target(((pump_target_point-model.handcar.pose().rocker)*pump_grip_side).angle(),model.hand_drive.clock+Engine.get_physics_interpolation_fraction()/60.0)
		elif drag in ["brake","throttle","gear","start"]:
			lever_travel+=event.relative.length()
			if drag!="start":
				var outer=pult_t if drag_closeup else body_transform(model.vehicle_id(),model.body_s_render(0))
				# Relative local travel excludes camera motion and preserves the grab offset.
				# Motor controls follow the visible arc one-to-one, independent of pump sensitivity.
				var local_move=outer.affine_inverse().basis_xform(event.relative)
				lever_target_point+=local_move
				var geo=control_geometry(drag,drag_closeup)
				var kind=control_kind(drag)
				if kind=="gate":
					var gate=gate_rect(drag_closeup)
					gate_pos=gate_move(gate_pos,local_move/Vector2(gate.size.x*0.35,gate.size.y*0.38))
					lever_pending_gear=gate_gear(gate_pos,lever_pending_gear)
				elif kind=="slider":
					var level=clampf((geo.pivot.y-lever_target_point.y)/float(geo.length),0.0,1.0)
					if level<0.001: level=0.0
					elif level>0.999: level=1.0
					model.state[drag]=level
				elif kind=="wheel":
					var turn=lever_target_point-geo.pivot
					var now=atan2(turn.x,-turn.y)
					wheel_acc=clampf(wheel_acc+wrapf(now-wheel_last,-PI,PI),0.0,WHEEL_SWEEP)
					wheel_last=now
					var spin=wheel_acc/WHEEL_SWEEP
					if spin<0.001: spin=0.0
					elif spin>0.999: spin=1.0
					if drag=="gear": model.set_feed(spin)
					else: model.state[drag]=spin
				else:
					var arm=lever_target_point-geo.pivot
					var angle=clampf(atan2(arm.x,-arm.y),-0.55,0.55)
					var value=clampf((angle+0.55)/1.1,0,1)
					if value<0.001: value=0.0
					elif value>0.999: value=1.0
					model.state[drag]=value
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		finish_drag(event.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if paused or screen == "menu": return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and drag == "" and screen == "game":
			zoom_level = clampf(zoom_level + (0.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1), 0.75, 1.5)
			return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		var mouse = event.position
		if screen == "depot":
			for hit in workshop_hits:
				if mouse.distance_to(hit.position) < 26:
					workshop_branch = str(hit.branch)
					tab = "Улучшения"
					sound.play("ui_click", 0.5)
					rebuild()
					return
			for hit in coupler_hits:
				if hit.position.distance_to(mouse) < 22: start_shunting(hit.id, hit.attach); return
			for hit in body_hits:
				if hit.rect.has_point(mouse): selected_object = hit.id; tab = "Улучшения"; rebuild(); return
			return
		var nearest: Dictionary = {}
		var distance = float(Geometry.data().controls.hit_diameter_px)*0.5
		if cab_active() and cab_exit_rect.has_point(mouse):
			toggle_cab_view()
			get_viewport().set_input_as_handled()
			return
		if cab_active():
			for hit in cab_hits:
				if hit.rect.has_point(mouse):
					cab_button(hit.id)
					get_viewport().set_input_as_handled()
					return
		var in_closeup = cab_active() and pult_screen_rect().has_point(mouse)
		if in_closeup and model.vehicle_id()=="steam":
			for hit in steam_hits:
				if not hit.rect.has_point(mouse): continue
				if hit.id=="door":
					model.set_door(not bool(model.boiler().door))
				else:
					drag="coal"
					drag_cursor=mouse
					Input.set_default_cursor_shape(Input.CURSOR_DRAG)
				get_viewport().set_input_as_handled()
				return
		if model.vehicle_id() == "pneumatic" and not in_closeup:
			# B1.3: a click on the white frost of a pipe knocks a quarter of the ice off that place
			var ice_radius = 0.18 * ArtV3.PX * view_scale()
			for hit in ice_hits:
				if mouse.distance_to(hit.position) < ice_radius and model.chip_ice(int(hit.spot)):
					notify("Иней сбит: %d%%" % roundi(model.frost() * 100.0))
					get_viewport().set_input_as_handled()
					return
		for hit in grip_hits:
			if in_closeup!=bool(hit.get("closeup",false)): continue
			var d = mouse.distance_to(hit.position)
			if d < distance:
				distance = d
				nearest = hit
		for hit in cargo_hits:
			if in_closeup: break
			# Visible cargo wins over the enlarged control hit circle. The actual
			# wooden grip still wins when the pointer is directly on it.
			if hit.rect.has_point(mouse) and distance>6:
				nearest = {}
		if not nearest.is_empty():
			drag = nearest.id
			drag_total = 0
			drag_horizontal = 0
			drag_initial = float(model.state.get(drag, 0))
			drag_closeup=bool(nearest.get("closeup",false))
			lever_travel=0
			lever_click_origin=mouse
			lever_pending_gear=int(model.state.gear)
			if drag in ["brake","throttle","gear","start"]:
				var press_geo=control_geometry(drag,drag_closeup)
				lever_target_point=press_geo.grip
				if control_kind(drag)=="gate": gate_pos=gate_slot_pos(int(model.state.gear))
				elif control_kind(drag)=="wheel":
					wheel_last=atan2(press_geo.grip.x-press_geo.pivot.x,-(press_geo.grip.y-press_geo.pivot.y))
					wheel_acc=float(press_geo.angle)
			model.reset_input()
			if drag=="pump":
				var outer=body_transform(model.vehicle_id(),model.body_s_render(0))
				pump_grip_side=float(nearest.get("side",1.0))
				var pose=model.handcar.pose()
				var grip=pose.rocker+(pose.grip_right-pose.rocker)*pump_grip_side
				pump_grab_offset=outer.affine_inverse()*mouse/ArtV3.PX-grip
				pump_target_point=outer.affine_inverse()*mouse/ArtV3.PX-pump_grab_offset
				model.grab_pump()
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			return
		if in_closeup:
			get_viewport().set_input_as_handled()
			return
		if model.can_push_handcar():
			var outer=body_transform(model.vehicle_id(),model.body_s_render(0))
			var local=outer.affine_inverse()*mouse/ArtV3.PX
			if absf(local.x)>0.85 and absf(local.x)<1.35 and local.y>-0.70 and local.y<0.05:
				drag="push"
				push_cursor=mouse
				model.begin_push()
				get_viewport().set_input_as_handled()
				return
		for hit in cargo_hits:
			if hit.rect.has_point(mouse):
				selected_cargo=hit.id
				cargo_action_key=""
				var interaction=station_state()
				if not interaction.can_transfer:
					notify(interaction.reason)
					return
				drag = "cargo"
				drag_item = hit.id
				drag_cursor=mouse
				drag_source=mouse
				drag_offset=mouse-hit.rect.position
				drag_size=hit.rect.size
				return
		if model.vehicle_id() == "sail" and model.state.phase == "route" and not in_closeup and not paused and sail_rect.has_point(mouse):
			drag = "sail"
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			# the hand takes the free end of the boom and holds it where it is; only the motion of the mouse moves it
			model.sail_grab()
			sail_hold = ArtV3.SAIL_BOOM * cos(float(model.sail_trim) * PI * 0.5)
			get_viewport().set_input_as_handled()
			return
		if model.vehicle_id() == "pole" and model.state.phase == "route" and not in_closeup and not paused:
			model.pole_aim(pole_mouse_rel(mouse))
			if model.pole_plant():
				drag = "pole"
				pole_press_rel = pole_mouse_rel(mouse)
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
				get_viewport().set_input_as_handled()

# The mouse place along the track in the pole truck's own frame: metres forward of the
# platform centre in the direction of travel.
func pole_mouse_rel(mouse: Vector2) -> float:
	var outer = body_transform(model.vehicle_id(), model.body_s_render(0))
	return (outer.affine_inverse() * mouse).x / ArtV3.PX * float(int(model.state.direction))

func finish_drag(mouse: Vector2) -> void:
	if drag == "cargo":
		if mouse.distance_to(drag_source)<5:
			cancel_drag()
			return
		var target = "invalid"
		for slot in slot_hits:
			if slot.rect.has_point(mouse): target = slot.key; break
		var size = get_viewport_rect().size
		if dock_visible() and (dock_rect().has_point(mouse) or world_platform_rect().has_point(mouse)): target = ""
		if target != "invalid":
			transfer_cargo(drag_item,target,mouse)
		else: notify("Перенеси груз в выделенную зону разгрузки или свободное место")
	elif drag == "sail":
		# let go over the cleat and the sheet is made fast; anywhere else and the sail flogs, free
		if sail_cleat_point != Vector2.ZERO and mouse.distance_to(sail_cleat_point) < 46.0: model.sail_cleat()
		else: model.sail_release()
	elif drag == "pole":
		model.pole_lift()
	elif drag == "coal":
		var fire_local = steam_fire_rect(control_zoom_rect())
		var fire_box = Rect2(pult_t * fire_local.position, fire_local.size * pult_t.get_scale())
		if fire_box.has_point(mouse):
			if not model.stoke(): notify(model.message)
		else:
			notify("Брось уголь в топку: перетащи ведро на красную топку")
	elif drag == "gear" and lever_pending_gear!=int(model.state.gear):
		if not model.set_gear(lever_pending_gear): notify(model.message)
	elif drag == "start" and lever_travel<8 and mouse.distance_to(lever_click_origin)<8:
		if not model.start_engine(not model.state.engine): notify(model.message)
	cancel_drag()

func world_point(s: float) -> Vector2:
	var size = get_viewport_rect().size
	var p = model.route.sample(s)
	var cam = model.route.sample(camera_s)
	var head_x = camera_x if camera_x > 0 else size.x * (0.31 if screen == "depot" else 0.65)
	var scale_value = ArtV3.PX * view_scale()
	return Vector2(head_x + (p.x - cam.x) * scale_value, rail_baseline() - (p.y - camera_y) * scale_value)

func dock_visible() -> bool:
	return screen=="game" and not cab_active() and (station_state().visible or drag=="cargo")

func station_state() -> Dictionary:
	var result=model.station_interaction()
	if drag=="cargo" and drag_item in result.eligible and result.can_transfer:
		result.phase="dragging"
		result.reason="Отпусти груз на подсвеченную платформу или в панель «Разгрузка»"
	return result

func world_platform_rect(index: int = -1) -> Rect2:
	if index<0: index=int(station_state().station_index)
	var center=float(model.route.station_s[index])
	var half=Model.StationInteraction.SERVICE_LENGTH*0.5
	var left=world_point(center-half)
	var right=world_point(center+half)
	var height = float(Geometry.data().reference.platform_height_m)*ArtV3.PX*view_scale()
	return Rect2(Vector2(left.x,left.y-height),Vector2(right.x-left.x,height))

func update_cargo_actions(interaction: Dictionary) -> void:
	if not is_instance_valid(cargo_actions): return
	cargo_actions.visible=dock_visible()
	var item={}
	for cargo in model.state.cargo:
		if cargo.id==selected_cargo and not cargo.delivered and cargo.slot!="": item=cargo
	var available=not item.is_empty() and interaction.can_transfer and (interaction.station_id=="A" or selected_cargo in interaction.eligible)
	var offer=model.service_offer()
	var key=selected_cargo+str(available)+str(item.is_empty())+str(offer.get("station",""))+str(model.refill_cost())+str(roundi(float(model.state.money)))
	if key==cargo_action_key: return
	cargo_action_key=key
	clear_children(cargo_actions)
	unload_selected_button=null
	if not item.is_empty():
		unload_selected_button=add_button(cargo_actions,"Выгрузить выбранный",func(): transfer_cargo(selected_cargo,"",world_platform_rect().get_center()),not available)
		unload_selected_button.add_theme_font_size_override("font_size",int(18*float(settings.text_scale)))
		unload_selected_button.tooltip_text="Этот груз ждут в "+model.station_name(item.destination) if selected_cargo not in interaction.eligible and interaction.station_id!="A" else interaction.reason
	# Fuel and water on the road: only where the station really has the service.
	if not offer.is_empty() and offer.station!="A":
		var cost=model.refill_cost()
		var water_short=float(model.object_stats(model.vehicle_id()).water)>0 and offer.services.has("water") and float(model.state.fleet_by_id[model.vehicle_id()].get("water",0))<float(model.object_stats(model.vehicle_id()).water)-0.0001
		var label=""
		if model.fuel_service_mult(offer.services)>=0.0: label=({"locomotive":"Зарядить","pneumatic":"Накачать"}.get(model.vehicle_id(),"Заправить"))+(" · %d монет" % cost if cost>0 else " · полон")
		if water_short: label+=(" + " if label!="" else "")+"вода"
		if label!="":
			var service_button=add_button(cargo_actions,label,use_station_service,cost<=0 and not water_short)
			service_button.add_theme_font_size_override("font_size",int(18*float(settings.text_scale)))

func use_station_service() -> void:
	if model.refuel():
		save_game()
		cargo_action_key=""
		notify(model.message if model.message!="" else "Запас пополнен")
		model.message=""
		update_hud()
	else: notify(model.message)

# One line for the depot panel and the map: what the next trip needs against what is on board.
func forecast_line(mission: Dictionary = {}) -> String:
	var f=model.trip_forecast(mission)
	if f.is_empty(): return ""
	var text="Рейс: нужно ~%.2f из %.2f %s" % [f.need,f.have,f.unit]
	if float(f.water_tank)>0: text+=" · вода ~%.0f из %.0f л" % [f.water_need,f.water_have]
	var enough=float(f.have)>=float(f.need) and (float(f.water_tank)<=0 or float(f.water_have)>=float(f.water_need))
	return text+(" · хватит" if enough else " · НЕ ХВАТИТ")

func service_text(id: String) -> String:
	var services=model.station_services(id)
	var parts: Array = []
	if services.has("fuel"): parts.append("заправка" + (" ×%s" % str(services.fuel).replace(".",",") if float(services.fuel)!=1.0 else ""))
	if services.has("water"): parts.append("вода")
	return " · ".join(parts)

func transfer_cargo(id: String, target: String, from: Vector2) -> bool:
	var interaction=station_state()
	if not interaction.can_transfer:
		notify(interaction.reason)
		return false
	var item={}
	for cargo in model.state.cargo:
		if cargo.id==id: item=cargo
	if item.is_empty() or item.delivered: return false
	var delivered_here=target=="" and item.destination==interaction.station_id
	var sprite_id=str(model.cargo_base(item.type).sprite)
	if not model.transfer(id,target):
		notify(model.message)
		return false
	if delivered_here:
		var platform=world_platform_rect()
		var landing=Vector2(clampf(from.x,platform.position.x+20,platform.end.x-20),platform.position.y)
		delivery_ghost={"sprite":sprite_id,"from":from,"to":landing,"time":0.0}
		selected_cargo=""
		notify("Доставлено в «%s». Выгружено %d из %d" % [interaction.station_name,interaction.delivered+1,interaction.total])
	model.message=""
	cargo_action_key=""
	save_game()
	update_hud()
	return true

func dock_rect() -> Rect2:
	var size = get_viewport_rect().size
	var hud = instruments.hud_top() if instruments != null and is_instance_valid(instruments) else size.y-174
	return Rect2(36,hud-156,size.x-72,144)

func rail_baseline() -> float:
	var height = get_viewport_rect().size.y
	# The compact bottom strip leaves room to set the track lower in the frame.
	return minf(height*0.66,dock_rect().position.y-20) if screen=="game" else height*0.63

func cab_active() -> bool:
	return screen == "game" and cab_view and not model.human_powered()

func view_scale() -> float:
	if screen != "depot": return zoom_level
	# the workshop shows the machine bigger, as far as the train still fits
	return minf(1.9 if tab == "Улучшения" else 0.94, (get_viewport_rect().size.x * 0.46 - 150) / (ArtV3.PX * depot_span_m()))

func _draw() -> void:
	if art == null: return
	var size = get_viewport_rect().size
	if art_world == null: draw_background(size)
	grip_hits.clear()
	ice_hits.clear()
	sail_rect = Rect2()
	sail_cleat_point = Vector2.ZERO
	workshop_hits.clear()
	steam_hits.clear()
	cab_hits.clear()
	slot_hits.clear()
	cargo_hits.clear()
	cargo_visuals.clear()
	body_hits.clear()
	if cab_active():
		update_pult_transform()
		draw_cab_scene(size)
		if toast_seconds > 0 and modal_kind != "confirm":
			var banner = Rect2(size.x * 0.5 - 420, 66, 840, 44)
			draw_style_box(style(INK, GOLD, 8), banner)
			draw_string(font, banner.position + Vector2(18, 29), toast, HORIZONTAL_ALIGNMENT_LEFT, banner.size.x - 30, 19, PAPER)
		return
	if screen == "menu":
		var scrim = Color(0.03, 0.08, 0.06, 0.9)
		draw_rect(Rect2(0, 0, size.x * 0.22, size.y), scrim)
		ArtWorld.horizontal_gradient(self, Rect2(size.x * 0.22, 0, size.x * 0.4, size.y), scrim, Color(scrim, 0.0))

		draw_menu_train(size)
	else:
		if screen == "depot": draw_depot_interior(size)
		draw_train()
		if screen == "depot":
			draw_style_box(style(Color(0.08,0.15,0.12,0.88),Color(0.5,0.57,0.39,0.45),8),Rect2(22,12,size.x-44,depot_header_bottom-12))
			draw_style_box(style(Color(0.08,0.15,0.12,0.88),Color(0.5,0.57,0.39,0.45),8),depot_info_rect)
		if screen == "game":
			draw_style_box(style(Color(0.08,0.15,0.12,0.88),Color(0.5,0.57,0.39,0.45),8),Rect2(22,10,size.x-44,46))
			draw_zone_label()
			# The order title and the hint share one backing; alone on the sky the
			# title was unreadable and the hint panel clipped it.
			var info=Rect2()
			for label in [order_label,hint_label]:
				if label!=null and label.visible: info=label.get_rect() if info.size==Vector2.ZERO else info.merge(label.get_rect())
			if info.size!=Vector2.ZERO:
				draw_style_box(style(Color(0.08,0.15,0.12,0.87),Color("526c59"),6),info.grow(7))
			if dock_visible(): draw_loading_dock(size)
			if drag == "sail" and sail_cleat_point != Vector2.ZERO:
				# while the sail is in the hand: let go over the cleat to make the sheet fast
				var pulse = 0.5 + 0.5 * sin(time * 6.0)
				draw_arc(sail_cleat_point, 34.0 + 4.0 * pulse, 0, TAU, 28, GOLD, 2.4, true)
				draw_string(font, sail_cleat_point + Vector2(-34, 52), "утка: отпусти тут", HORIZONTAL_ALIGNMENT_LEFT, 120, 14, GOLD)
			draw_cargo_feedback()
			draw_tooltip()
	if toast_seconds > 0 and modal_kind != "confirm":
		var width = minf(1100, size.x - 100)
		var rect = Rect2((size.x - width) / 2, 184 if screen=="game" else size.y - 65, width, 44)
		draw_style_box(style(INK, GOLD, 8), rect)
		draw_string(font, rect.position + Vector2(18, 29), toast, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 30, 19, PAPER)

# ===== Cab scene (E): looking ahead through the glass, the dashboard below ==========
# Everything is drawn here in code. The pult (levers, gate, wheels, coal, door) is the
# same pult as on C, scaled onto the dashboard; pult_t maps its coordinates to the screen.

func cab_layout(size: Vector2) -> Dictionary:
	var rect = control_zoom_rect()
	var k = minf(1.3, size.y * 0.5 / rect.size.y)
	var origin = Vector2(size.x * 0.5 - rect.size.x * k * 0.5, size.y - rect.size.y * k - 14.0)
	return {"k": k, "dash_top": origin.y - 26.0, "rect": Rect2(origin, rect.size * k),
		"xform": Transform2D(Vector2(k, 0), Vector2(0, k), origin - rect.position * k)}

func update_pult_transform() -> void:
	pult_t = cab_layout(get_viewport_rect().size).xform if cab_active() else Transform2D.IDENTITY

# The side windows sit in the cab pillars; they follow the layout every frame.
func cab_window_rect(size: Vector2, top: float, window_side: float) -> Rect2:
	var pillar = size.x * 0.12
	var roof = size.y * 0.075
	var width = pillar * 0.62
	var height = (top - roof) * 0.52
	var x = pillar * 0.10 if window_side < 0 else size.x - pillar * 0.10 - width
	return Rect2(x, roof + 26.0, width, height)

func update_cab_sides() -> void:
	var active = cab_active() and not model.state.is_empty()
	var size = get_viewport_rect().size
	var top = float(cab_layout(size).dash_top) if active else 0.0
	for window in cab_sides:
		if window.visible != active: window.visible = active
		if active:
			var rect = cab_window_rect(size, top, window.side)
			window.position = rect.position
			window.size = rect.size
			# the side windows follow the time of day
			var dark = model.night_amount()
			window.modulate = Color(lerpf(1.0, 0.36, dark), lerpf(1.0, 0.4, dark), lerpf(1.0, 0.55, dark))
			window.queue_redraw()

func pult_screen_rect() -> Rect2:
	if cab_active(): return cab_layout(get_viewport_rect().size).rect
	return Rect2()

func cab_shake() -> Vector2:
	var speed = absf(float(model.state.v))
	var vibrating = bool(model.state.engine) and model.vehicle_id() != "locomotive"
	var tremble = Vector2(sin(time * 61.0), sin(time * 53.0 + 1.3)) * ((0.5 + 0.7 * float(model.state.throttle)) if vibrating else 0.0)
	var clack = Vector2(0.0, sin(time * 38.0) * cab_jolt * 3.4)
	var sway = Vector2(sin(time * 1.3) * minf(speed * 0.18, 2.0), 0.0)
	return (tremble + clack + sway) * (0.0 if settings.reduce_motion else float(settings.cab_shake))

# Needles are springs: they overshoot a little and settle, and tremble while the
# machine runs, instead of jumping to the value.
func cab_needle(key: String, target: float) -> float:
	var state = needle_state.get(key, {"x": target, "v": 0.0})
	var accel = (target - float(state.x)) * 90.0 - float(state.v) * 11.0
	state.v = float(state.v) + accel * cab_dt
	state.x = float(state.x) + float(state.v) * cab_dt
	needle_state[key] = state
	var tremble = sin(time * 37.0 + key.length()) * 0.004 if bool(model.state.engine) and model.vehicle_id() != "locomotive" and key in ["СКОРОСТЬ", "ОБОРОТЫ", "ДАВЛЕНИЕ"] and not settings.reduce_motion else 0.0
	return clampf(float(state.x) + tremble, -0.05, 1.05)

func cab_hash(i: int, salt: float = 0.0) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

func cab_project(x: float, z: float, horizon: float, focal: float, cx: float, camera_height: float) -> Vector2:
	return Vector2(cx + x * focal / z, horizon + camera_height * focal / z)

func cab_fog(color: Color, z: float) -> Color:
	return color.lerp(Color("cfe0dc"), clampf(z / 170.0, 0.0, 0.85))

func draw_cab_scene(size: Vector2) -> void:
	var layout = cab_layout(size)
	var top = float(layout.dash_top)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var view = Rect2(0, 0, size.x, top)
	# The view and the machine's nose shake with the track and the engine; the frame
	# and the dashboard stay put, so the controls keep their places under the mouse.
	draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, cab_shake()))
	var look = draw_cab_forward(view)
	draw_cab_nose(view, look)
	# B4.1: the glass at night and at dawn
	var night = model.night_amount()
	if model.twilight() > 0.01: draw_rect(view, Color(1.0, 0.5, 0.25, 0.16 * minf(1.0, model.twilight())))
	if night > 0.01:
		draw_rect(view, Color(0.02, 0.04, 0.12, 0.6 * night))
		if night > 0.25:
			var beam = Color(1.0, 0.88, 0.55, 0.22 * clampf((night - 0.25) / 0.5, 0.0, 1.0))
			draw_polygon(PackedVector2Array([Vector2(view.size.x * 0.5, view.size.y), Vector2(view.size.x * 0.28, view.size.y * 0.62), Vector2(view.size.x * 0.72, view.size.y * 0.62)]), PackedColorArray([beam, Color(beam, 0.0), Color(beam, 0.0)]))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_cab_frame(size, top)
	draw_cab_dash_details(size, layout)
	draw_cab_gauges(size, layout)
	draw_control_zoom()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	cab_exit_rect = Rect2(size.x - 206, 14, 190, 40)
	draw_style_box(style(Color(0.08, 0.12, 0.10, 0.86), GOLD, 8), cab_exit_rect)
	draw_string(font, cab_exit_rect.position + Vector2(0, 27), "Выйти [E]", HORIZONTAL_ALIGNMENT_CENTER, cab_exit_rect.size.x, 19, PAPER)
	var ahead = instruments.climb_ahead(400.0) if instruments != null else {}
	var text = "Впереди без крутых подъёмов" if ahead.is_empty() else ("Подъём +%.1f%% — сейчас" % ahead.grade if ahead.distance < 10 else "Подъём +%.1f%% через %d м" % [ahead.grade, ahead.distance])
	draw_string(font, Vector2(0, 44), model.journey_heading() + "  ·  " + text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 240, 18, Color(PAPER, 0.92))

# The view forward along the track. Returns the horizon line and focal length so the
# nose of the machine can be placed against it.
func draw_cab_forward(view: Rect2) -> Dictionary:
	var facing = int(model.state.direction)
	var travelled = model.render_s() * facing
	var speed = absf(float(model.state.v))
	var slope = tan(model.route.slope(float(model.state.s) + facing * 40.0))
	var bob = sin(time * 9.0) * minf(1.6, speed * 0.25)
	var horizon = view.position.y + view.size.y * 0.47 - clampf(slope, -0.08, 0.08) * view.size.y * 2.0 + bob
	var focal = view.size.y * 0.95
	var cx = view.size.x * 0.5
	var camera_height = 1.7
	var look = {"horizon": horizon, "focal": focal, "cx": cx, "speed": speed, "travelled": travelled}
	# sky, sun and drifting clouds
	draw_polygon(PackedVector2Array([view.position, Vector2(view.end.x, view.position.y), Vector2(view.end.x, horizon), Vector2(view.position.x, horizon)]), PackedColorArray([Color("6ea6d4"), Color("6ea6d4"), Color("d9e8e0"), Color("d9e8e0")]))
	var sun = Vector2(view.size.x * 0.78, horizon - view.size.y * 0.30)
	for ring in range(6):
		draw_circle(sun, 120.0 - ring * 18.0, Color(1.0, 0.96, 0.78, 0.05 + ring * 0.025))
	for cloud in range(6):
		var base_x = fposmod(cab_hash(cloud, 9.0) * view.size.x * 1.4 + time * (4.0 + cloud) - travelled * 0.15, view.size.x * 1.4) - view.size.x * 0.2
		var base_y = view.position.y + view.size.y * (0.08 + cab_hash(cloud, 5.0) * 0.2)
		for puff in range(5):
			var offset = Vector2(puff * 34.0 - 68.0, sin(puff * 1.7) * 9.0)
			draw_circle(Vector2(base_x, base_y) + offset, 26.0 + cab_hash(cloud + puff, 3.0) * 14.0, Color(1, 1, 1, 0.55))
	# three ridges of hills, hazier the further away
	for layer in range(3):
		var ridge = PackedVector2Array([Vector2(0, horizon)])
		var height = view.size.y * (0.20 - layer * 0.05)
		for step in range(0, int(view.size.x) + 41, 40):
			var wave = 0.5 + 0.5 * sin(step * (0.005 + 0.003 * layer) + layer * 2.1 + travelled * 0.003 * (layer + 1))
			ridge.append(Vector2(step, horizon - height * (0.30 + 0.70 * wave)))
		ridge.append(Vector2(view.size.x + 40, horizon))
		draw_colored_polygon(ridge, [Color("9db6b4"), Color("82a29a"), Color("668b7e")][layer])
	draw_polygon(PackedVector2Array([Vector2(0, horizon - 3), Vector2(view.size.x, horizon - 3), Vector2(view.size.x, horizon + 28), Vector2(0, horizon + 28)]), PackedColorArray([Color(0.85, 0.92, 0.9, 0.0), Color(0.85, 0.92, 0.9, 0.0), Color(0.85, 0.92, 0.9, 0.5), Color(0.85, 0.92, 0.9, 0.5)]))
	draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(view.size.x, horizon), view.end, Vector2(0, view.end.y)]), PackedColorArray([Color("77a06a"), Color("77a06a"), Color("3a5e3c"), Color("3a5e3c")]))
	var near = 1.3
	var far = 170.0
	draw_colored_polygon(PackedVector2Array([cab_project(-2.6, near, horizon, focal, cx, camera_height), cab_project(2.6, near, horizon, focal, cx, camera_height), cab_project(2.6, far, horizon, focal, cx, camera_height), cab_project(-2.6, far, horizon, focal, cx, camera_height)]), Color("5f7f54"))
	draw_colored_polygon(PackedVector2Array([cab_project(-1.9, near, horizon, focal, cx, camera_height), cab_project(1.9, near, horizon, focal, cx, camera_height), cab_project(1.9, far, horizon, focal, cx, camera_height), cab_project(-1.9, far, horizon, focal, cx, camera_height)]), Color("8a8174"))
	# ballast speckle close to the train
	for i in range(60):
		var z = near + 0.4 + fposmod(cab_hash(i, 6.0) * 14.0 - travelled, 14.0)
		var spot = cab_project((cab_hash(i, 7.0) - 0.5) * 3.4, z, horizon, focal, cx, camera_height)
		draw_rect(Rect2(spot, Vector2(clampf(0.06 * focal / z, 1, 5), clampf(0.03 * focal / z, 1, 3))), Color(0.35, 0.32, 0.28, 0.6))
	var phase = fposmod(-travelled, 0.9)
	for k in range(0, 150):
		var z = near + phase + k * 0.9
		if z > 120.0: break
		var a = cab_project(-1.15, z, horizon, focal, cx, camera_height)
		var b = cab_project(1.15, z, horizon, focal, cx, camera_height)
		draw_line(a, b, cab_fog(Color("4a3b2e"), z), clampf(0.2 * focal / z, 1.0, 20.0), true)
		draw_line(a + Vector2(0, -clampf(0.07 * focal / z, 0, 6)), b + Vector2(0, -clampf(0.07 * focal / z, 0, 6)), cab_fog(Color("6a5646"), z), clampf(0.05 * focal / z, 0.5, 5.0), true)
	var steps = [near, 2.0, 3.0, 4.5, 7.0, 11.0, 18.0, 30.0, 55.0, 100.0, far]
	for rail_x in [-0.55, 0.55]:
		for i in range(steps.size() - 1):
			var a = cab_project(rail_x, steps[i], horizon, focal, cx, camera_height)
			var b = cab_project(rail_x, steps[i + 1], horizon, focal, cx, camera_height)
			draw_line(a, b, cab_fog(Color("8d8a84"), steps[i]), clampf(0.09 * focal / steps[i], 1.5, 12.0), true)
			draw_line(a + Vector2(0, -clampf(0.03 * focal / steps[i], 0, 4)), b + Vector2(0, -clampf(0.03 * focal / steps[i], 0, 4)), cab_fog(Color("e2dfd6"), steps[i]), clampf(0.03 * focal / steps[i], 0.5, 3.0), true)
	# rail joints every 12 m
	var joint_phase = fposmod(-travelled, 12.0)
	for j in range(0, 12):
		var z = near + joint_phase + j * 12.0
		if z > 110.0: break
		for rail_x in [-0.55, 0.55]:
			var p = cab_project(rail_x, z, horizon, focal, cx, camera_height)
			draw_rect(Rect2(p + Vector2(-clampf(0.08 * focal / z, 1, 9), -1), Vector2(clampf(0.16 * focal / z, 2, 18), clampf(0.03 * focal / z, 1, 3))), cab_fog(Color("2c2a27"), z))
	# stations ahead: platform, building, sign
	for i in range(model.route.station_s.size()):
		var z = (float(model.route.station_s[i]) - model.render_s()) * facing
		if z < 6.0 or z > 190.0: continue
		var z0 = maxf(near + 0.5, z - 9.0)
		var z1 = z + 9.0
		draw_colored_polygon(PackedVector2Array([cab_project(1.5, z0, horizon, focal, cx, camera_height), cab_project(3.4, z0, horizon, focal, cx, camera_height), cab_project(3.4, z1, horizon, focal, cx, camera_height), cab_project(1.5, z1, horizon, focal, cx, camera_height)]), cab_fog(Color("b7ab94"), z))
		var edge_a = cab_project(1.5, z0, horizon, focal, cx, camera_height)
		var edge_b = cab_project(1.5, z1, horizon, focal, cx, camera_height)
		draw_line(edge_a, edge_b, cab_fog(Color("e6d9a8"), z), clampf(0.06 * focal / z, 1, 5), true)
		var base_l = cab_project(4.2, z, horizon, focal, cx, camera_height)
		var base_r = cab_project(11.0, z, horizon, focal, cx, camera_height)
		var wall_h = 4.2 * focal / z
		draw_rect(Rect2(base_l.x, base_l.y - wall_h, base_r.x - base_l.x, wall_h), cab_fog(Color("7c4f34"), z))
		draw_colored_polygon(PackedVector2Array([Vector2(base_l.x - wall_h * 0.12, base_l.y - wall_h), Vector2((base_l.x + base_r.x) * 0.5, base_l.y - wall_h * 1.5), Vector2(base_r.x + wall_h * 0.12, base_l.y - wall_h)]), cab_fog(Color("8e3b2e"), z))
		for window in range(3):
			var wx = base_l.x + (base_r.x - base_l.x) * (0.15 + window * 0.3)
			draw_rect(Rect2(wx, base_l.y - wall_h * 0.7, (base_r.x - base_l.x) * 0.14, wall_h * 0.38), cab_fog(Color("f1d98a"), z))
		if z < 110.0:
			draw_string(font, Vector2(base_l.x, base_l.y - wall_h * 0.12), model.data.stations[i].name, HORIZONTAL_ALIGNMENT_CENTER, base_r.x - base_l.x, clampi(roundi(900.0 / z), 9, 26), Color("f1e6c8"))
	# telegraph poles on the left with sagging wires, mileposts on the right
	var pole_first = floori((travelled + 4.0) / 40.0)
	var pole_last = floori((travelled + 160.0) / 40.0)
	var previous_top = []
	for i in range(pole_last, pole_first - 1, -1):
		var z = i * 40.0 - travelled
		if z < 5.0 or z > 160.0: continue
		var base = cab_project(-4.6, z, horizon, focal, cx, camera_height)
		var tall = 7.0 * focal / z
		draw_line(base, base + Vector2(0, -tall), cab_fog(Color("4b3a2c"), z), clampf(0.2 * focal / z, 1, 9), true)
		draw_line(base + Vector2(-tall * 0.16, -tall * 0.92), base + Vector2(tall * 0.16, -tall * 0.92), cab_fog(Color("4b3a2c"), z), clampf(0.1 * focal / z, 1, 5), true)
		var tops = [base + Vector2(-tall * 0.14, -tall * 0.92), base + Vector2(tall * 0.14, -tall * 0.92)]
		for wire in range(2):
			if previous_top.size() == 2:
				var a = tops[wire]
				var b = previous_top[wire]
				draw_polyline(PackedVector2Array([a, a.lerp(b, 0.5) + Vector2(0, tall * 0.05), b]), cab_fog(Color("2c2a27"), z), clampf(0.03 * focal / z, 0.7, 2.0), true)
		previous_top = tops
	var post_first = floori((travelled + 4.0) / 100.0)
	for i in range(post_first + 2, post_first - 1, -1):
		var z = i * 100.0 - travelled
		if z < 6.0 or z > 160.0: continue
		var base = cab_project(2.6, z, horizon, focal, cx, camera_height)
		var tall = 1.1 * focal / z
		draw_rect(Rect2(base.x - 0.16 * focal / z, base.y - tall, 0.32 * focal / z, tall), cab_fog(Color("e8e4d4"), z))
		draw_string(font, Vector2(base.x - 0.2 * focal / z, base.y - tall * 0.45), str(i), HORIZONTAL_ALIGNMENT_CENTER, 0.4 * focal / z, clampi(roundi(0.35 * focal / z), 6, 20), Color("2c2a27"))
	# grass tufts, bushes, spruces and birches, far to near
	var first = floori((travelled + 5.0) / 4.0)
	var last = floori((travelled + 170.0) / 4.0)
	for i in range(last, first - 1, -1):
		var distance = i * 4.0 + cab_hash(i) * 3.0
		var z = distance - travelled
		if z < 7.0 or z > 168.0: continue
		var side = -1.0 if cab_hash(i, 1.0) < 0.5 else 1.0
		var lateral = side * (3.6 + cab_hash(i, 2.0) * 20.0)
		var tree_h = 7.0 + cab_hash(i, 3.0) * 8.0
		var base = cab_project(lateral, z, horizon, focal, cx, camera_height)
		var h = tree_h * focal / z
		var w = tree_h * 0.3 * focal / z
		var shade = 0.7 + cab_hash(i, 4.0) * 0.5
		if cab_hash(i, 8.0) > 0.78:
			draw_line(base, base + Vector2(0, -h * 0.55), cab_fog(Color("e6e2d4"), z), maxf(1.0, w * 0.12), true)
			for blob in range(4):
				draw_circle(base + Vector2((blob - 1.5) * w * 0.28, -h * (0.5 + 0.1 * (blob % 2))), w * 0.34, cab_fog(Color(0.45 * shade, 0.66 * shade, 0.30 * shade), z))
		else:
			var green = Color(0.12 * shade, 0.30 * shade, 0.16 * shade)
			draw_rect(Rect2(base.x - w * 0.07, base.y - h * 0.16, w * 0.14, h * 0.16), cab_fog(Color("3b2a1d"), z))
			for tier in range(3):
				var lift = h * (0.1 + tier * 0.27)
				var half = w * (1.0 - tier * 0.26)
				draw_colored_polygon(PackedVector2Array([Vector2(base.x - half, base.y - lift), Vector2(base.x + half, base.y - lift), Vector2(base.x, base.y - lift - h * 0.46)]), cab_fog(green.lightened(tier * 0.05), z))
		if cab_hash(i, 10.0) > 0.4 and z < 90.0:
			var bush = cab_project(side * (2.3 + cab_hash(i, 11.0) * 2.2), z, horizon, focal, cx, camera_height)
			draw_circle(bush + Vector2(0, -0.35 * focal / z), 0.55 * focal / z, cab_fog(Color(0.16, 0.34, 0.18), z))
			draw_circle(bush + Vector2(0.4 * focal / z, -0.25 * focal / z), 0.4 * focal / z, cab_fog(Color(0.2, 0.4, 0.22), z))
	# speed streaks at the edges and a soft vignette
	if speed > 3.0:
		for streak in range(14):
			var y = view.position.y + view.size.y * (0.35 + cab_hash(streak, 12.0) * 0.65)
			var side_x = 1.0 if streak % 2 == 0 else -1.0
			var start_x = cx + side_x * view.size.x * (0.3 + 0.2 * cab_hash(streak, 13.0))
			draw_line(Vector2(start_x, y), Vector2(start_x + side_x * view.size.x * 0.2, y + (y - horizon) * 0.2), Color(1, 1, 1, clampf((speed - 3.0) * 0.02, 0.0, 0.14)), 2.0, true)
	draw_polygon(PackedVector2Array([view.position, Vector2(view.end.x, view.position.y), Vector2(view.end.x, view.end.y), Vector2(view.position.x, view.end.y)]), PackedColorArray([Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
	return look

# The front of the machine seen over the dashboard: hood, boiler or battery box.
func draw_cab_nose(view: Rect2, look: Dictionary) -> void:
	var kind = model.vehicle_id()
	var cx = float(look.cx)
	var bottom = view.end.y
	var vh = view.size.y
	var running = bool(model.state.engine)
	var steel = Color("1d2427")
	var brass = Color("c9a85a")
	if kind == "motorcar":
		var hood = PackedVector2Array([Vector2(cx - vh * 0.52, bottom), Vector2(cx + vh * 0.52, bottom), Vector2(cx + vh * 0.30, bottom - vh * 0.30), Vector2(cx - vh * 0.30, bottom - vh * 0.30)])
		draw_polygon(hood, PackedColorArray([Color("2b3438"), Color("2b3438"), Color("11171a"), Color("11171a")]))
		draw_line(Vector2(cx, bottom), Vector2(cx, bottom - vh * 0.30), Color(1, 1, 1, 0.08), 3.0, true)
		for slat in range(5):
			var f = 0.15 + slat * 0.16
			var y = bottom - vh * 0.30 * f
			draw_line(Vector2(cx - vh * (0.52 - 0.22 * f) * 0.78, y), Vector2(cx + vh * (0.52 - 0.22 * f) * 0.78, y), Color(0, 0, 0, 0.55), 3.0, true)
		for band in [0.2, 0.62]:
			var y = bottom - vh * 0.30 * band
			draw_line(Vector2(cx - vh * (0.52 - 0.22 * band), y), Vector2(cx + vh * (0.52 - 0.22 * band), y), brass, 4.0, true)
		var cap = Vector2(cx + vh * 0.17, bottom - vh * 0.22)
		draw_circle(cap, vh * 0.026, brass)
		draw_circle(cap, vh * 0.019, Color("8a6d33"))
		draw_line(cap + Vector2(-vh * 0.014, 0), cap + Vector2(vh * 0.014, 0), Color("2a2218"), 2.5)
		draw_line(cap + Vector2(0, -vh * 0.014), cap + Vector2(0, vh * 0.014), Color("2a2218"), 2.5)
		draw_rect(Rect2(cx - 9, bottom - vh * 0.30, 18, vh * 0.30), Color("4b3321"))
		draw_rect(Rect2(cx - 14, bottom - vh * 0.30 - 3, 28, 8), brass)
		var lamp = Vector2(cx, bottom - vh * 0.33)
		draw_circle(lamp, vh * 0.035, brass)
		draw_circle(lamp, vh * 0.026, Color("fff0b4") if running else Color("8a8466"))
		if running:
			for ring in range(4): draw_circle(lamp, vh * (0.05 + ring * 0.03), Color(1.0, 0.9, 0.5, 0.07 - ring * 0.015))
		var stack = Vector2(cx - vh * 0.16, bottom - vh * 0.26)
		draw_rect(Rect2(stack.x - 7, stack.y - vh * 0.16, 14, vh * 0.16), brass)
		draw_rect(Rect2(stack.x - 11, stack.y - vh * 0.17, 22, 8), steel)
		if running:
			for puff in range(5):
				var age = fposmod(time * 0.9 + puff / 5.0, 1.0)
				draw_circle(Vector2(stack.x - age * vh * 0.1, stack.y - vh * 0.19 - age * vh * 0.22), 7 + age * 24, Color(0.85, 0.85, 0.82, 0.4 * (1.0 - age)))
	elif kind == "steam":
		var barrel = Rect2(cx - vh * 0.42, bottom - vh * 0.30, vh * 0.84, vh * 0.30)
		draw_rect(barrel, Color("1b2224"))
		draw_polygon(PackedVector2Array([barrel.position, Vector2(barrel.end.x, barrel.position.y), Vector2(barrel.end.x, barrel.position.y + barrel.size.y * 0.35), Vector2(barrel.position.x, barrel.position.y + barrel.size.y * 0.35)]), PackedColorArray([Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
		draw_line(barrel.position, Vector2(barrel.end.x, barrel.position.y), brass, 4.0, true)
		for band in [0.2, 0.5, 0.8]:
			draw_line(Vector2(barrel.position.x + barrel.size.x * band, barrel.position.y), Vector2(barrel.position.x + barrel.size.x * band, bottom), brass, 5.0, true)
		for rivet in range(14):
			draw_circle(Vector2(barrel.position.x + 20 + rivet * barrel.size.x / 14.0, barrel.position.y + 14), 3.0, brass)
		var dome = Vector2(cx - vh * 0.20, barrel.position.y)
		draw_circle(dome + Vector2(0, -vh * 0.012), vh * 0.045, brass)
		draw_rect(Rect2(dome.x - vh * 0.05, dome.y - vh * 0.012, vh * 0.1, vh * 0.012), Color("8a6d33"))
		var chimney = Vector2(cx + vh * 0.12, barrel.position.y)
		draw_colored_polygon(PackedVector2Array([Vector2(chimney.x - 15, chimney.y), Vector2(chimney.x + 15, chimney.y), Vector2(chimney.x + 12, chimney.y - vh * 0.20), Vector2(chimney.x - 12, chimney.y - vh * 0.20)]), steel)
		draw_colored_polygon(PackedVector2Array([Vector2(chimney.x - 12, chimney.y - vh * 0.20), Vector2(chimney.x + 12, chimney.y - vh * 0.20), Vector2(chimney.x + 28, chimney.y - vh * 0.27), Vector2(chimney.x - 28, chimney.y - vh * 0.27)]), Color("2a3438"))
		draw_rect(Rect2(chimney.x - 30, chimney.y - vh * 0.28, 60, 7), brass)
		if running:
			for puff in range(7):
				var age = fposmod(time * (0.7 + float(model.state.throttle)) + puff / 7.0, 1.0)
				draw_circle(Vector2(chimney.x + sin(puff * 2.0 + time) * 10 - age * 30, chimney.y - vh * 0.30 - age * vh * 0.34), 12 + age * 38, Color(0.9, 0.9, 0.88, 0.5 * (1.0 - age)))
		var lamp = Vector2(cx - vh * 0.02, barrel.position.y - vh * 0.012)
		draw_circle(lamp, vh * 0.026, brass)
		draw_circle(lamp, vh * 0.018, Color("fff0b4") if running else Color("8a8466"))
	else:
		var deck = PackedVector2Array([Vector2(cx - vh * 0.56, bottom), Vector2(cx + vh * 0.56, bottom), Vector2(cx + vh * 0.38, bottom - vh * 0.24), Vector2(cx - vh * 0.38, bottom - vh * 0.24)])
		draw_polygon(deck, PackedColorArray([Color("2d3a33"), Color("2d3a33"), Color("172019"), Color("172019")]))
		for lid in range(3):
			var f0 = lid / 3.0
			var f1 = (lid + 0.9) / 3.0
			var left0 = lerpf(cx - vh * 0.50, cx + vh * 0.50, f0)
			var left1 = lerpf(cx - vh * 0.50, cx + vh * 0.50, f1)
			draw_colored_polygon(PackedVector2Array([Vector2(left0, bottom - vh * 0.02), Vector2(left1, bottom - vh * 0.02), Vector2(lerpf(cx - vh * 0.34, cx + vh * 0.34, f1), bottom - vh * 0.21), Vector2(lerpf(cx - vh * 0.34, cx + vh * 0.34, f0), bottom - vh * 0.21)]), Color("33463a"))
			draw_line(Vector2((left0 + left1) * 0.5, bottom - vh * 0.1), Vector2((left0 + left1) * 0.5 + 6, bottom - vh * 0.1), brass, 6.0, true)
		for stripe in range(8):
			var x = cx - vh * 0.5 + stripe * vh * 0.125
			draw_colored_polygon(PackedVector2Array([Vector2(x, bottom), Vector2(x + vh * 0.05, bottom), Vector2(x + vh * 0.05 - 6, bottom - vh * 0.025), Vector2(x - 6, bottom - vh * 0.025)]), Color("d9b43e") if stripe % 2 == 0 else Color("1f2623"))
		var lamp = Vector2(cx, bottom - vh * 0.25)
		draw_circle(lamp, vh * 0.024, brass)
		draw_circle(lamp, vh * 0.017, Color("fff0b4") if running else Color("8a8466"))

# The cab around the view: roof lining, pillars, window rubber, wipers, lamps and the
# dashboard ledge.
func draw_cab_frame(size: Vector2, top: float) -> void:
	var green = Color("2f4a3b")
	var dark = Color("1f2f27")
	var brass = Color("c9a85a")
	var running_engine = bool(model.state.engine) and model.vehicle_id() != "locomotive"
	var lamp_flicker = 1.0 - (0.22 * (0.5 + 0.5 * sin(time * 27.0)) if running_engine and not settings.reduce_motion else 0.0)
	var roof = size.y * 0.075
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, roof), Vector2(0, roof)]), PackedColorArray([dark, dark, green, green]))
	for plank in range(1, 24):
		draw_line(Vector2(size.x * plank / 24.0, 0), Vector2(size.x * plank / 24.0, roof), Color(0, 0, 0, 0.22), 2.0)
	draw_line(Vector2(0, roof), Vector2(size.x, roof), brass, 3.0)
	draw_line(Vector2(0, roof + 3), Vector2(size.x, roof + 3), Color(0, 0, 0, 0.4), 3.0)
	var pillar = size.x * 0.12
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(pillar, 0), Vector2(pillar * 0.45, top), Vector2(0, top)]), green)
	draw_colored_polygon(PackedVector2Array([Vector2(size.x, 0), Vector2(size.x - pillar, 0), Vector2(size.x - pillar * 0.45, top), Vector2(size.x, top)]), green)
	for grain in range(7):
		var gx = pillar * (0.1 + grain * 0.1)
		draw_line(Vector2(gx, 0), Vector2(gx * 0.55, top), Color(0, 0, 0, 0.12), 1.5)
		draw_line(Vector2(size.x - gx, 0), Vector2(size.x - gx * 0.55, top), Color(0, 0, 0, 0.12), 1.5)
	for side in [-1.0, 1.0]:
		var edge_x = pillar if side < 0 else size.x - pillar
		var low_x = pillar * 0.45 if side < 0 else size.x - pillar * 0.45
		draw_line(Vector2(edge_x, roof), Vector2(low_x, top), brass, 3.0)
		draw_line(Vector2(edge_x + side * 5, roof), Vector2(low_x + side * 5, top), Color(0, 0, 0, 0.45), 4.0)
		for bolt in range(8):
			var f = (bolt + 0.5) / 8.0
			draw_circle(Vector2(lerpf(edge_x, low_x, f) + side * 14, lerpf(roof, top, f)), 3.5, brass)
	for window_side in [-1.0, 1.0]:
		var frame = cab_window_rect(size, top, window_side).grow(7.0)
		draw_rect(frame, Color("0f1512"))
		draw_rect(frame, brass, false, 3.0)
		draw_rect(frame.grow(-3.0), Color("2a2218"), false, 2.0)
		for bolt in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
			draw_circle(bolt, 3.5, brass)
	# a brass lantern on a hook at the left pillar, under the side window
	var hook = Vector2(pillar * 0.4 + sin(time * 1.8) * minf(absf(float(model.state.v)), 6.0) * 0.7, size.y * 0.29)
	draw_line(Vector2(hook.x, roof), hook, brass, 2.0)
	draw_rect(Rect2(hook.x - 12, hook.y, 24, 34), Color("a98a4a"))
	draw_rect(Rect2(hook.x - 8, hook.y + 5, 16, 24), Color("ffe9a6") if bool(model.state.engine) else Color("6f6a52"))
	draw_circle(hook + Vector2(0, 17), 36.0, Color(1.0, 0.85, 0.45, 0.07 if bool(model.state.engine) else 0.0))
	# two ceiling lamps with a warm glow
	for lamp_x in [0.27, 0.73]:
		var p = Vector2(size.x * lamp_x, roof + 6)
		draw_line(Vector2(p.x, roof), p, Color("6a5a3a"), 3.0)
		draw_circle(p + Vector2(0, 9), 11, brass)
		draw_circle(p + Vector2(0, 11), 7, Color("fff1c4"))
		for ring in range(5): draw_circle(p + Vector2(0, 11), 20.0 + ring * 16.0, Color(1.0, 0.9, 0.55, (0.06 - ring * 0.01) * lamp_flicker))
	# centre post, curtains, window rubber
	var post = Rect2(size.x * 0.5 - 9, roof, 18, top - roof)
	draw_rect(post, green)
	draw_line(post.position, Vector2(post.position.x, post.end.y), brass, 2.0)
	draw_line(Vector2(post.end.x, post.position.y), post.end, brass, 2.0)
	for rivet in range(7):
		draw_circle(Vector2(size.x * 0.5, roof + (top - roof) * (rivet + 0.5) / 7.0), 2.5, brass)
	for side in [-1.0, 1.0]:
		var corner_x = pillar * 1.05 if side < 0 else size.x - pillar * 1.05
		for fold in range(4):
			draw_colored_polygon(PackedVector2Array([Vector2(corner_x, roof + 3), Vector2(corner_x - side * (12 + fold * 9), roof + 3), Vector2(corner_x - side * (6 + fold * 9), roof + 50 + fold * 6)]), Color("6f3a34") if fold % 2 == 0 else Color("55292a"))
	draw_line(Vector2(pillar + 6, roof + 6), Vector2(size.x - pillar - 6, roof + 6), Color("171c19"), 6.0)
	# windscreen wipers resting at the bottom of the glass
	for wiper_x in [0.36, 0.64]:
		var pivot = Vector2(size.x * wiper_x, top - 6)
		draw_line(pivot, pivot + Vector2(size.x * 0.1, -size.y * 0.08), Color("101412"), 5.0, true)
		draw_line(pivot + Vector2(size.x * 0.02, -size.y * 0.016), pivot + Vector2(size.x * 0.1, -size.y * 0.08), Color("050605"), 7.0, true)
		draw_circle(pivot, 6, brass)
	# glass: sheen, reflections and a few specks of dust
	draw_colored_polygon(PackedVector2Array([Vector2(pillar * 1.6, roof), Vector2(pillar * 2.6, roof), Vector2(pillar * 1.6, top), Vector2(pillar * 0.7, top)]), Color(1, 1, 1, 0.05))
	draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.64, roof), Vector2(size.x * 0.7, roof), Vector2(size.x * 0.59, top), Vector2(size.x * 0.53, top)]), Color(1, 1, 1, 0.04))
	for speck in range(26):
		draw_circle(Vector2(size.x * (0.1 + 0.8 * cab_hash(speck, 20.0)), roof + (top - roof) * cab_hash(speck, 21.0)), 1.0 + cab_hash(speck, 22.0) * 1.5, Color(1, 1, 1, 0.1))
	# dashboard ledge in wood, then the steel panel
	draw_polygon(PackedVector2Array([Vector2(0, top - 22), Vector2(size.x, top - 22), Vector2(size.x, top - 4), Vector2(0, top - 4)]), PackedColorArray([Color("7b5732"), Color("7b5732"), Color("4a3320"), Color("4a3320")]))
	for grain in range(0, int(size.x), 70):
		draw_line(Vector2(grain, top - 20), Vector2(grain + 40, top - 7), Color(0, 0, 0, 0.18), 1.5)
	draw_line(Vector2(0, top - 22), Vector2(size.x, top - 22), brass, 3.0)
	draw_polygon(PackedVector2Array([Vector2(0, top - 4), Vector2(size.x, top - 4), Vector2(size.x, size.y), Vector2(0, size.y)]), PackedColorArray([Color("3a4a41"), Color("3a4a41"), Color("151d19"), Color("151d19")]))
	draw_line(Vector2(0, top - 4), Vector2(size.x, top - 4), Color(0, 0, 0, 0.55), 3.0)
	for rivet in range(int(size.x / 50.0)):
		draw_circle(Vector2(25 + rivet * 50.0, top + 8), 2.5, Color("a98a4a"))
	for screw in range(int(size.x / 50.0)):
		draw_circle(Vector2(25 + screw * 50.0, size.y - 10), 3.0, Color("0c100e"))
		draw_line(Vector2(25 + screw * 50.0 - 2, size.y - 12), Vector2(25 + screw * 50.0 + 2, size.y - 8), Color("55645a"), 1.2)

# Small dashboard details: nameplate, indicator lamps, clock, vents, cables, and the
# vehicle-specific bits (water glass and whistle cord on the steam engine).
func draw_cab_dash_details(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var pult: Rect2 = layout.rect
	var brass = Color("c9a85a")
	var kind = model.vehicle_id()
	# nameplate
	var plate = Rect2(size.x * 0.5 - 150, top + 12, 300, 26)
	draw_style_box(style(Color("2a2218"), brass, 4), plate)
	var title = {"steam": "ЛЕСНАЯ КОЛЕЯ · ПАРОВОЗ", "motorcar": "ЛЕСНАЯ КОЛЕЯ · БЕНЗИНОВАЯ", "locomotive": "ЛЕСНАЯ КОЛЕЯ · ЭЛЕКТРОВОЗ", "pneumatic": "ЛЕСНАЯ КОЛЕЯ · ПНЕВМОВОЗ"}.get(kind, "ЛЕСНАЯ КОЛЕЯ")
	draw_string(font, plate.position + Vector2(0, 19), title, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 14, Color("e6cf8b"))
	draw_circle(plate.position + Vector2(8, 13), 2.5, brass)
	draw_circle(plate.position + Vector2(plate.size.x - 8, 13), 2.5, brass)
	# indicator lamps
	var amount = float(model.state.fleet_by_id[kind].fuel)
	var tank = float(model.object_stats(kind).tank)
	var lamps = [["ХОД", absf(float(model.state.v)) > 0.1, Color("5cc17f")], ["ДВИГАТЕЛЬ", bool(model.state.engine), Color("e6b34a")], ["ТОРМОЗ", float(model.state.brake) > 0.1, Color("e0564a")], ["ЗАПАС", amount / maxf(0.001, tank) < 0.15, Color("e0564a")]]
	for i in range(lamps.size()):
		var at = Vector2(60 + i * 86, top + 22)
		draw_circle(at, 9, Color("0c100e"))
		draw_circle(at, 7, lamps[i][2] if lamps[i][1] else lamps[i][2].darkened(0.75))
		if lamps[i][1]: draw_circle(at, 16, Color(lamps[i][2], 0.22))
		draw_string(font, at + Vector2(-40, 25), lamps[i][0], HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color("a9a589"))
	# brass clock on the right of the ledge
	var clock = Vector2(size.x - 70, top + 26)
	draw_circle(clock, 22, brass)
	draw_circle(clock, 19, Color("f1ead2"))
	for hour in range(12):
		var a = TAU * hour / 12.0 - PI / 2
		draw_line(clock + Vector2(cos(a), sin(a)) * 15, clock + Vector2(cos(a), sin(a)) * 18, Color("2a2218"), 1.5)
	var minutes = fposmod(model.world_hours() * 60.0, 60.0)
	var hours = fposmod(model.world_hours(), 12.0)
	var am = TAU * minutes / 60.0 - PI / 2
	var ah = TAU * hours / 12.0 - PI / 2
	draw_line(clock, clock + Vector2(cos(am), sin(am)) * 15, Color("2a2218"), 1.5, true)
	draw_line(clock, clock + Vector2(cos(ah), sin(ah)) * 10, Color("2a2218"), 2.5, true)
	draw_circle(clock, 2, Color("a8231c"))
	# hanging cables
	draw_polyline(PackedVector2Array([Vector2(size.x * 0.30, top + 6), Vector2(size.x * 0.34, top + 42), Vector2(size.x * 0.38, top + 8)]), Color("0b0e0c"), 4.0, true)
	if kind == "motorcar": draw_petrol_cab_extras(size, layout)
	if kind in ["steam", "locomotive", "pneumatic"]: draw_cab_reverser(size, layout)
	if kind == "locomotive": draw_electric_cab_extras(size, layout)
	if kind == "pneumatic": draw_pneumatic_cab_extras(size, layout)
	if kind == "steam":
		# water glass on the right: tube with the level, brass fittings
		var tube = Rect2(size.x - 150, top + 70, 16, 120)
		draw_rect(tube, Color("a9d1d6", 0.35))
		var level = clampf(float(model.state.fleet_by_id.steam.get("water", 0)) / float(model.object_stats("steam").water), 0.0, 1.0)
		draw_rect(Rect2(tube.position.x + 2, tube.end.y - tube.size.y * level, tube.size.x - 4, tube.size.y * level), Color("4f8fbf", 0.85))
		draw_rect(Rect2(tube.position.x - 6, tube.position.y - 8, tube.size.x + 12, 8), brass)
		draw_rect(Rect2(tube.position.x - 6, tube.end.y, tube.size.x + 12, 8), brass)
		draw_string(font, tube.position + Vector2(-20, tube.size.y + 26), "уровень", HORIZONTAL_ALIGNMENT_CENTER, 56, 11, Color("a9a589"))
		# whistle cord with a ring, swaying a little with the speed
		var sway = sin(time * 3.0) * minf(6.0, absf(float(model.state.v)))
		var cord_top = Vector2(size.x * 0.5 + 220, 0.0)
		var ring_at = Vector2(size.x * 0.5 + 224 + sway, top - 60)
		draw_line(Vector2(cord_top.x, size.y * 0.075), ring_at, Color("a58b57"), 3.0, true)
		draw_arc(ring_at + Vector2(0, 8), 8, 0, TAU, 16, brass, 3.0, true)

# Direction switch in the top strip of the dashboard: two buttons, the engaged one lit.
func draw_cab_reverser(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var strip_x = size.x * 0.5 + 190.0
	var brass = Color("c9a85a")
	var panel = Rect2(strip_x, top + 10, 190, 60)
	draw_style_box(style(Color("1d2320"), brass, 6), panel)
	draw_string(font, panel.position + Vector2(0, 54), "НАПРАВЛЕНИЕ", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 10, Color("c7c3a0"))
	var forward = int(model.state.get("reverser", 1)) >= 0
	for index in range(2):
		var button = Rect2(panel.position + Vector2(8 + index * 88, 8), Vector2(86, 30))
		var lit = (index == 1) == forward
		draw_rect(button, Color("2c3a30") if lit else Color("151b18"))
		draw_rect(button, brass if lit else Color("4b564e"), false, 2.0)
		draw_circle(button.position + Vector2(12, 15), 5, Color("5cc17f") if lit else Color("1e3326"))
		draw_string(font, button.position + Vector2(20, 21), "ВПЕРЁД" if index == 1 else "НАЗАД", HORIZONTAL_ALIGNMENT_CENTER, 62, 13, PAPER if lit else Color("8a8466"))
		cab_hits.append({"id": "forward" if index == 1 else "back", "rect": button})

# Electric cab: warning plate, regeneration lamps and the emergency stop button, the
# voltmeter and ammeter live in draw_cab_gauges.
func draw_electric_cab_extras(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var pult: Rect2 = layout.rect
	var brass = Color("c9a85a")
	var cx = size.x * 0.5
	# warning plate with a lightning bolt
	var tri = Vector2(400, top + 38)
	draw_colored_polygon(PackedVector2Array([tri + Vector2(0, -22), tri + Vector2(25, 22), tri + Vector2(-25, 22)]), Color("e6c13a"))
	draw_polyline(PackedVector2Array([tri + Vector2(0, -22), tri + Vector2(25, 22), tri + Vector2(-25, 22), tri + Vector2(0, -22)]), Color("2a2218"), 2.5, true)
	draw_colored_polygon(PackedVector2Array([tri + Vector2(3, -12), tri + Vector2(-7, 4), tri + Vector2(-1, 4), tri + Vector2(-4, 14), tri + Vector2(7, -2), tri + Vector2(1, -2)]), Color("1a1612"))
	draw_string(font, tri + Vector2(-60, 40), "ВЫСОКОЕ НАПРЯЖЕНИЕ", HORIZONTAL_ALIGNMENT_CENTER, 120, 9, Color("a9a589"))
	# regeneration and charge lamps under the nameplate
	var regen = model.regen_kw > 0.01
	var lamps = [["РЕКУП.", regen, Color("6cc4e0")], ["ПИТАНИЕ", float(model.state.fleet_by_id.locomotive.fuel) > 0.0, Color("5cc17f")], ["НИЗКИЙ ЗАРЯД", float(model.state.fleet_by_id.locomotive.fuel) / float(model.object_stats("locomotive").tank) < 0.25, Color("e0564a")]]
	for lamp in range(lamps.size()):
		var at = Vector2(cx - 60 + lamp * 60, top + 54)
		draw_circle(at, 9, Color("0c100e"))
		draw_circle(at, 7, lamps[lamp][2] if lamps[lamp][1] else lamps[lamp][2].darkened(0.78))
		if lamps[lamp][1]: draw_circle(at, 15, Color(lamps[lamp][2], 0.2))
		draw_string(font, at + Vector2(-30, 24), lamps[lamp][0], HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color("a9a589"))
	# motor temperature: over 85% the pull weakens
	var motor_temp = model.engine_temp()
	draw_round_gauge(Vector2(cx + 190.0 + 190.0 + 52.0 + 112.0, top + 56.0), clampf((layout.rect.position.x - 70.0) * 0.22, 46.0, 92.0) * 0.42, motor_temp, "МОТОР", "%d°" % roundi(20.0 + motor_temp * 100.0), [[0.7, Color("5cc17f")], [0.85, Color("e6b34a")], [1.0, Color("e0564a")]], 4)
	# the red mushroom emergency stop: a real button, it drops traction and pulls the brake
	var button = Vector2(cx + 190 + 190 + 52, top + 38)
	draw_circle(button, 28, Color("3a1512"))
	draw_circle(button, 24, Color("c23b2e"))
	draw_circle(button + Vector2(-8, -9), 8, Color(1, 1, 1, 0.3))
	draw_arc(button, 28, 0, TAU, 24, brass, 2.5, true)
	draw_string(font, button + Vector2(-50, 46), "АВАРИЙНЫЙ ТОРМОЗ", HORIZONTAL_ALIGNMENT_CENTER, 100, 9, Color("a9a589"))
	cab_hits.append({"id": "emergency", "rect": Rect2(button - Vector2(30, 30), Vector2(60, 60))})

# Pneumatic cab: lamps for low reserve air and for frost on the pipes, under the nameplate.
func draw_pneumatic_cab_extras(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var cx = size.x * 0.5
	var low_air = float(model.state.fleet_by_id.pneumatic.fuel) / maxf(0.001, float(model.object_stats("pneumatic").tank)) < 0.25
	var lamps = [["ВОЗДУХ", float(model.state.fleet_by_id.pneumatic.fuel) > 0.0, Color("6cc4e0")], ["НИЗКОЕ ДАВЛ.", low_air, Color("e0564a")], ["ИНЕЙ", model.frost() > 0.35, Color("e6b34a")]]
	for lamp in range(lamps.size()):
		var at = Vector2(cx - 60 + lamp * 60, top + 54)
		draw_circle(at, 9, Color("0c100e"))
		draw_circle(at, 7, lamps[lamp][2] if lamps[lamp][1] else lamps[lamp][2].darkened(0.78))
		if lamps[lamp][1]: draw_circle(at, 15, Color(lamps[lamp][2], 0.2))
		draw_string(font, at + Vector2(-30, 24), lamps[lamp][0], HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color("a9a589"))

# Petrol cab: ignition lock, choke, fuse box, oil and temperature gauges, gear lamps,
# a rear-view mirror and pedal pads. The two small gauges are live.
func draw_petrol_cab_extras(size: Vector2, layout: Dictionary) -> void:
	var top = float(layout.dash_top)
	var pult: Rect2 = layout.rect
	var brass = Color("c9a85a")
	var cx = size.x * 0.5
	var small = Color("c7c3a0")
	var radius = clampf((pult.position.x - 70.0) * 0.22, 46.0, 92.0)
	var gauge_y = top + (size.y - top) * 0.46
	# switches in the top strip, right of the nameplate: ignition, choke, fuses
	var strip_x = cx + 190.0
	var lock = Rect2(strip_x, top + 10, 84, 60)
	draw_style_box(style(Color("1d2320"), brass, 6), lock)
	draw_circle(lock.position + Vector2(30, 28), 14, Color("0a0c0b"))
	draw_circle(lock.position + Vector2(30, 28), 12, Color("3b3f3a"))
	draw_line(lock.position + Vector2(30, 22), lock.position + Vector2(30, 34), Color("050605"), 3.0)
	var key_on = bool(model.state.engine)
	draw_line(lock.position + Vector2(30, 28), lock.position + Vector2(30 + (16 if key_on else 9), 28 - (6 if key_on else 14)), Color("d9c27a"), 4.0, true)
	draw_circle(lock.position + Vector2(30 + (18 if key_on else 11), 28 - (7 if key_on else 16)), 6, Color("d9c27a"))
	draw_string(font, lock.position + Vector2(0, 54), "ЗАЖИГАН.", HORIZONTAL_ALIGNMENT_CENTER, lock.size.x, 10, small)
	draw_circle(lock.position + Vector2(8, 8), 2.2, brass)
	draw_circle(lock.position + Vector2(lock.size.x - 8, 8), 2.2, brass)
	var choke = Vector2(strip_x + 132, top + 24)
	draw_line(choke, choke + Vector2(0, 30), Color("8d9a98"), 5.0, true)
	draw_circle(choke, 12, Color("1a1a1a"))
	draw_circle(choke, 9, Color("2d2d2d"))
	draw_circle(choke + Vector2(-3, -3), 3, Color(1, 1, 1, 0.3))
	draw_string(font, choke + Vector2(-30, 46), "ПОДСОС", HORIZONTAL_ALIGNMENT_CENTER, 60, 10, small)
	var box = Rect2(strip_x + 178, top + 20, 124, 44)
	draw_style_box(style(Color("20261f"), Color("6c6f66"), 4), box)
	for fuse in range(6):
		var colour = [Color("e6b34a"), Color("5cc17f"), Color("e0564a"), Color("5cc17f"), Color("e6b34a"), Color("5cc17f")][fuse]
		var fx = box.position.x + 9 + fuse * 18
		draw_rect(Rect2(fx, box.position.y + 6, 12, 18), colour.darkened(0.55) if fuse == 2 else colour)
		draw_line(Vector2(fx + 6, box.position.y + 9), Vector2(fx + 6, box.position.y + 21), Color("101412"), 1.5)
	draw_string(font, box.position + Vector2(0, 38), "ПРЕДОХРАНИТЕЛИ", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 9, small)
	# the fuel gauge and the two small live ones stand in one row on the right
	var running = bool(model.state.engine)
	var small_r = radius * 0.42
	var fuel_x = pult.end.x + 36.0 + radius + 8.0
	var oil_x = fuel_x + radius + 8.0 + 22.0 + small_r
	var temp_x = oil_x + small_r * 2.0 + 16.0
	var oil = clampf(0.12 + model.engine_rpm_fraction() * 0.75, 0.0, 1.0) if running else 0.0
	draw_round_gauge(Vector2(oil_x, gauge_y), small_r, oil, "МАСЛО", "%.1f" % (oil * 5.0), [[0.2, Color("e0564a")], [0.9, Color("5cc17f")], [1.0, Color("e6b34a")]], 4)
	draw_round_gauge(Vector2(temp_x, gauge_y), small_r, cab_temp, "ТЕМП.", "%d°" % roundi(20.0 + cab_temp * 100.0), [[0.7, Color("5cc17f")], [0.85, Color("e6b34a")], [1.0, Color("e0564a")]], 4)
	# gear lamps under the nameplate: the engaged gear is lit
	var labels = ["1", "2", "3", "4", "5", "N", "R"]
	var gears = [1, 2, 3, 4, 5, 0, 6]
	for lamp in range(7):
		var at = Vector2(cx - 84 + lamp * 28, top + 54)
		var lit = int(model.state.gear) == gears[lamp]
		var lamp_colour = Color("e0564a") if lamp == 6 else (Color("e6b34a") if lamp == 5 else Color("5cc17f"))
		draw_circle(at, 9, Color("0c100e"))
		draw_circle(at, 7, lamp_colour if lit else lamp_colour.darkened(0.78))
		if lit: draw_circle(at, 15, Color(lamp_colour, 0.2))
		draw_string(font, at + Vector2(-8, 4), labels[lamp], HORIZONTAL_ALIGNMENT_CENTER, 16, 10, Color("0c100e") if lit else Color("8a8466"))
	# rear-view mirror on a stalk over the glass: the track and train behind, receding
	var mirror = Rect2(cx + 150, size.y * 0.075 + 40, 118, 46)
	draw_line(Vector2(cx + 209, size.y * 0.075), Vector2(cx + 209, mirror.position.y), Color("0f1512"), 5.0)
	draw_rect(mirror.grow(5), Color("101512"))
	draw_polygon(PackedVector2Array([mirror.position, Vector2(mirror.end.x, mirror.position.y), Vector2(mirror.end.x, mirror.get_center().y), Vector2(mirror.position.x, mirror.get_center().y)]), PackedColorArray([Color("86b3d6"), Color("86b3d6"), Color("d9e8e0"), Color("d9e8e0")]))
	draw_rect(Rect2(mirror.position.x, mirror.get_center().y, mirror.size.x, mirror.size.y * 0.5), Color("5f8756"))
	var vanishing = Vector2(mirror.get_center().x, mirror.get_center().y)
	draw_line(vanishing + Vector2(-3, 0), Vector2(mirror.position.x + 34, mirror.end.y), Color("c7c3b4"), 2.0, true)
	draw_line(vanishing + Vector2(3, 0), Vector2(mirror.end.x - 34, mirror.end.y), Color("c7c3b4"), 2.0, true)
	for wagon in range(2):
		var wagon_y = vanishing.y + 7 + wagon * 9
		var wagon_w = 16 + wagon * 14
		draw_rect(Rect2(vanishing.x - wagon_w * 0.5, wagon_y - 6 - wagon * 2, wagon_w, 8 + wagon * 2), Color("7a4a2a") if wagon == 0 else Color("8a5a34"))
	draw_colored_polygon(PackedVector2Array([mirror.position + Vector2(10, 0), mirror.position + Vector2(40, 0), mirror.position + Vector2(20, mirror.size.y), mirror.position + Vector2(-8, mirror.size.y)]), Color(1, 1, 1, 0.16))
	# pedal pads under the left gauges: clutch, brake, gas (not controls)
	var left = pult.position.x * 0.5
	for pedal in range(3):
		var px = left - 80.0 + pedal * 56.0
		var py = size.y - 70.0
		var tilt = 6 if pedal == 2 else 0
		draw_colored_polygon(PackedVector2Array([Vector2(px, py + tilt), Vector2(px + 40, py + tilt), Vector2(px + 44, size.y), Vector2(px - 4, size.y)]), Color("171b19"))
		for tread in range(5):
			var ty = py + tilt + 8 + tread * 11
			draw_line(Vector2(px + 3, ty), Vector2(px + 37, ty), Color(1, 1, 1, 0.12), 2.0)
		draw_line(Vector2(px, py + tilt), Vector2(px + 40, py + tilt), brass, 2.0)

func draw_round_gauge(center: Vector2, radius: float, fraction: float, title: String, readout: String, zones: Array, ticks: int = 10, scale_text: Array = []) -> void:
	fraction = cab_needle(title, fraction)
	draw_circle(center + Vector2(2, 3), radius + 8, Color(0, 0, 0, 0.4))
	draw_circle(center, radius + 8, Color("a98a4a"))
	draw_arc(center, radius + 8, PI * 1.1, PI * 1.6, 12, Color("e6cf8b"), 2.0, true)
	draw_circle(center, radius + 6, Color("2a2218"))
	draw_circle(center, radius + 4, Color("0f1a1c"))
	for screw in range(4):
		var screw_at = center + Vector2.from_angle(PI / 4 + screw * PI / 2) * (radius + 6.5)
		draw_circle(screw_at, 2.2, Color("d9bb6a"))
	var start = deg_to_rad(150)
	var span = deg_to_rad(240)
	var from = 0.0
	for zone in zones:
		draw_arc(center, radius - 3, start + span * from, start + span * float(zone[0]), 16, zone[1], maxf(4.0, radius * 0.07), true)
		from = float(zone[0])
	for i in range(ticks * 2 + 1):
		var angle = start + span * i / float(ticks * 2)
		var radial = Vector2(cos(angle), sin(angle))
		var major = i % 2 == 0
		draw_line(center + radial * (radius - (radius * 0.2 if major else radius * 0.12)), center + radial * (radius - 7), PAPER if major else Color(PAPER, 0.6), 2.0 if major else 1.0, true)
	for i in range(scale_text.size()):
		var angle = start + span * i / float(maxi(1, scale_text.size() - 1))
		var radial = Vector2(cos(angle), sin(angle))
		draw_string(font, center + radial * (radius - radius * 0.27) + Vector2(-14, 5), str(scale_text[i]), HORIZONTAL_ALIGNMENT_CENTER, 28, clampi(roundi(radius * 0.15), 9, 14), Color("e8e0c4"))
	var angle = start + span * clampf(fraction, 0.0, 1.0)
	var needle = Vector2(cos(angle), sin(angle))
	draw_line(center + Vector2(1.5, 2), center + needle * (radius - 8) + Vector2(1.5, 2), Color(0, 0, 0, 0.45), 4.0, true)
	draw_line(center - needle * (radius * 0.18), center + needle * (radius - 8), Color("f3ead2"), 3.5, true)
	draw_line(center + needle * (radius - 22), center + needle * (radius - 8), Color("e0564a"), 3.5, true)
	draw_circle(center, radius * 0.1, Color("c9af73"))
	draw_circle(center, radius * 0.04, Color("1a1612"))
	# glare on the glass
	draw_arc(center, radius - 2, PI * 1.12, PI * 1.45, 10, Color(1, 1, 1, 0.14), radius * 0.16, true)
	draw_string(font, center + Vector2(-radius, radius * 0.38), title, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, clampi(roundi(radius * 0.15), 9, 14), Color("c7c3a0"))
	draw_string(font, center + Vector2(-radius, radius * 0.66), readout, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, clampi(roundi(radius * 0.21), 12, 20), GOLD)

func draw_cab_gauges(size: Vector2, layout: Dictionary) -> void:
	var pult: Rect2 = layout.rect
	var radius = clampf((pult.position.x - 70.0) * 0.22, 46.0, 92.0)
	var y = float(layout.dash_top) + (size.y - float(layout.dash_top)) * 0.46
	var kind = model.vehicle_id()
	var speed = absf(float(model.state.v)) * 3.6
	var maximum = instruments.dial_maximum() if instruments != null else 30.0
	var nominal = instruments.nominal_speed() / maximum if instruments != null else 0.8
	var speed_zones = [[nominal * 0.72, Color("5cc17f")], [nominal, Color("e6b34a")], [1.0, Color("e0564a")]]
	var left = pult.position.x * 0.5
	draw_round_gauge(Vector2(left - radius * 1.1, y), radius, speed / maximum, "СКОРОСТЬ", "%.1f км/ч" % speed, speed_zones, 10, [0, roundi(maximum * 0.25), roundi(maximum * 0.5), roundi(maximum * 0.75), roundi(maximum)])
	var right = pult.end.x + (size.x - pult.end.x) * 0.5
	var stats = model.object_stats(kind)
	var amount = float(model.state.fleet_by_id[kind].fuel)
	var low_bad = [[0.15, Color("e0564a")], [0.35, Color("e6b34a")], [1.0, Color("5cc17f")]]
	if kind == "motorcar":
		draw_round_gauge(Vector2(left + radius * 1.1, y), radius, model.engine_rpm() / 6000.0, "ОБОРОТЫ", "%.1f тыс" % (model.engine_rpm() / 1000.0), [[0.7, Color("5cc17f")], [0.88, Color("e6b34a")], [1.0, Color("e0564a")]], 6, [0, 1, 2, 3, 4, 5, 6])
		draw_round_gauge(Vector2(pult.end.x + 36.0 + radius + 8.0, y), radius, amount / float(stats.tank), "БЕНЗИН", "%.2f л" % amount, low_bad, 4, ["0", "", "1/2", "", "П"])
	elif kind == "pneumatic":
		draw_round_gauge(Vector2(left + radius * 1.1, y), radius, amount / float(stats.tank), "ДАВЛЕНИЕ", "%.0f бар" % amount, [[0.4, Color("e0564a")], [0.7, Color("e6b34a")], [1.0, Color("5cc17f")]], 10, [0, int(stats.tank * 0.2), int(stats.tank * 0.4), int(stats.tank * 0.6), int(stats.tank * 0.8), int(stats.tank)])
		draw_round_gauge(Vector2(right - radius * 0.9, y), radius, model.frost(), "ИНЕЙ", "%d%%" % roundi(model.frost() * 100.0), [[0.3, Color("5cc17f")], [0.6, Color("e6b34a")], [1.0, Color("e0564a")]], 4, ["0", "", "1/2", "", "П"])
	elif kind == "steam":
		var work = float(model.boiler_cfg().work_pressure_bar) / float(model.boiler_cfg().max_pressure_bar)
		draw_round_gauge(Vector2(left + radius * 1.1, y), radius, float(model.boiler().pressure), "ДАВЛЕНИЕ", "%.1f бар" % model.pressure_bar(), [[work, Color("e6b34a")], [0.9, Color("5cc17f")], [1.0, Color("e0564a")]], 10, [0, 2, 4, 6, 8, 10])
		var water = float(model.state.fleet_by_id.steam.get("water", 0))
		draw_round_gauge(Vector2(right - radius * 0.9, y), radius, water / float(stats.water), "ВОДА", "%.0f л" % water, low_bad, 4, ["0", "", "1/2", "", "П"])
	else:
		draw_round_gauge(Vector2(left + radius * 1.1, y), radius, amount / float(stats.tank), "ЗАРЯД", "%d%%" % roundi(amount / float(stats.tank) * 100), low_bad, 10, [0, 25, 50, 75, 100])
		var charge = amount / float(stats.tank)
		var volts = clampf(40.0 + 9.0 * charge - 4.0 * float(model.state.throttle), 0.0, 60.0)
		var speed_share = clampf(absf(float(model.state.v)) / float(stats.speeds[0]), 0.0, 1.0)
		var amps = float(model.state.throttle) * 260.0 * (1.0 - 0.5 * speed_share) * (1.0 if amount > 0.0 else 0.0) - model.regen_kw * 1000.0 / maxf(volts, 1.0)
		var first = pult.end.x + 36.0 + radius + 8.0
		draw_round_gauge(Vector2(first, y), radius, volts / 60.0, "ВОЛЬТМЕТР", "%.0f В" % volts, [[0.7, Color("e0564a")], [0.9, Color("5cc17f")], [1.0, Color("e6b34a")]], 6, [0, 10, 20, 30, 40, 50, 60])
		draw_round_gauge(Vector2(first + radius * 2.0 + 28.0, y), radius, clampf((amps + 100.0) / 400.0, 0.0, 1.0), "АМПЕРМЕТР", "%.0f А" % amps, [[0.25, Color("78b8d8")], [0.75, Color("5cc17f")], [0.9, Color("e6b34a")], [1.0, Color("e0564a")]], 8, [-100, 0, 100, 200, 300])

func draw_background(size: Vector2) -> void:
	if textures.has("background"):
		# One oversized image: no repeating seam in the distant forest.
		var shift = -fmod(camera_s * 1.8, 80.0)
		draw_texture_rect(textures.background, Rect2(shift - 80, -30, size.x + 240, size.y + 80), false, Color(0.78, 0.86, 0.78))
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.11, 0.22, 0.16, 0.12))

func sprite(id: String, rect: Rect2, color: Color = Color.WHITE) -> void:
	if textures.has(id): draw_texture_rect(textures[id], rect, false, color)

func ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var polygon = PackedVector2Array()
	for i in range(24): polygon.append(center + Vector2(cos(i * TAU / 24), sin(i * TAU / 24)) * radii)
	draw_colored_polygon(polygon, color)

func grounded_sprite(id: String, foot: Vector2, height: float, color: Color = Color.WHITE) -> void:
	if not textures.has(id): return
	var texture = textures[id]
	var bounds = visual_layout.get(id, [0, 0, texture.get_width(), texture.get_height()])
	var factor = height / maxf(1, float(bounds[3]) - float(bounds[1]))
	var anchor = Vector2((float(bounds[0]) + float(bounds[2])) * 0.5, float(bounds[3]))
	sprite(id, Rect2(foot - anchor * factor, texture.get_size() * factor), color)

func terrain_band(track: PackedVector2Array, top: float, bottom: float, color: Color) -> void:
	var polygon = PackedVector2Array()
	for p in track: polygon.append(p + Vector2(0, top))
	for i in range(track.size() - 1, -1, -1): polygon.append(track[i] + Vector2(0, bottom))
	draw_colored_polygon(polygon, color)

func draw_world(size: Vector2) -> void:
	var begin_s = camera_s - 38
	var end_s = camera_s + 38
	var sc = view_scale()
	var track = PackedVector2Array()
	for i in range(153):
		var s = begin_s + i * 0.5
		var p = world_point(s)
		track.append(p)
	terrain_band(track, -102 * sc, size.y, Color("9aa47b"))
	# A more distant tree row moves more slowly than the railway.
	for i in range(floori((camera_s - 55) / 3.6), ceili((camera_s + 55) / 3.6)):
		var s = i * 3.6 + sin(i * 2.71 + model.route.seed_value) * 0.9
		var p = world_point(s)
		p.x = get_viewport_rect().size.x * 0.5 + (p.x - get_viewport_rect().size.x * 0.5) * 0.62
		p.y -= 72 * sc
		if p.x < -300 or p.x > size.x + 300: continue
		var h = (155 + fposmod(sin(i * 13.1) * 3197, 100)) * sc
		grounded_sprite("pine" if posmod(i, 4) else "birch", p, h, Color(0.68, 0.77, 0.65, 0.72))
	terrain_band(track, -34 * sc, size.y, Color("728453"))
	for i in range(floori(begin_s / 5.2), ceili(end_s / 5.2)):
		var tree_s = i * 5.2 + sin(i * 4.3 + model.route.seed_value) * 1.25
		var p = world_point(tree_s) + Vector2(0, -13 * sc)
		if p.x < -400 or p.x > size.x + 400: continue
		var h = (255 + fposmod(sin(i * 62.3 + model.route.seed_value) * 43758, 200)) * sc
		ellipse(p + Vector2(12, 1) * sc, Vector2(h * 0.18, h * 0.025), Color(0.13, 0.22, 0.12, 0.22))
		grounded_sprite("pine" if posmod(i, 3) else "birch", p, h, Color(0.88, 0.94, 0.83))
		if posmod(i, 2) == 0:
			grounded_sprite("bush", p + Vector2(-45, 3) * sc, 43 * sc, Color(0.8, 0.91, 0.72))
	for station_index in range(model.data.stations.size()):
		var p = world_point(float(model.route.station_s[station_index]))
		if p.x < -500 or p.x > size.x + 500: continue
		var station = model.data.stations[station_index]
		ellipse(p + Vector2(290, -5), Vector2(155, 14), Color(0.12, 0.18, 0.1, 0.25))
		grounded_sprite("depot" if station_index == 0 else "station_hut", p + Vector2(295, -8), 240)
		if station_index == 2:
			sprite("loading_crane", Rect2(p.x - 430, p.y - 300, 220, 280))
			grounded_sprite("log_pile", p + Vector2(490, -4), 80)
		if station_index == 0:
			grounded_sprite("fuel_pump", p + Vector2(480, -5), 145)
			if model.state.finale: sprite("final_flags", Rect2(p.x + 100, p.y - 335, 320, 130))
		draw_line(Vector2(p.x - 420, p.y + 6), Vector2(p.x + 500, p.y + 6), Color("8f9970"), 15)
		draw_style_box(style(PAPER, GOLD, 5), Rect2(p.x + 185, p.y - 285, 310, 48))
		draw_string(font, Vector2(p.x + 195, p.y - 253), station.name, HORIZONTAL_ALIGNMENT_CENTER, 290, 22, INK)
	terrain_band(track, 21 * sc, size.y, Color("564733"))
	# The supplied soil has a grass lip and a shaded stone face. Its transparent
	# border is accounted for so adjacent pieces form one embankment.
	for i in range(floori(begin_s / 4), ceili(end_s / 4)):
		var s = i * 4.0 + 2.0
		var p = world_point(s)
		if p.x < -350 or p.x > size.x + 350: continue
		var width = 4 * 64 * sc * 400.0 / 371.0 + 3
		var height = width * 220 / 400
		draw_set_transform(p, -model.route.slope(s))
		sprite("soil_segment", Rect2(-width * 0.5, 25 * sc - height * 36 / 220, width, height), Color(0.83, 0.86, 0.73))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	terrain_band(track, -2 * sc, 25 * sc, Color("817a62"))
	for i in range(floori(begin_s * 2), ceili(end_s * 2)):
		var p = world_point(i * 0.5)
		if p.x < -40 or p.x > size.x + 40: continue
		var gravel = fposmod(sin(i * 52.31) * 41657, 1)
		ellipse(p + Vector2(12 * sin(i * 7.2), 9 + gravel * 14) * sc, Vector2(4 + gravel * 6, 2 + gravel * 2) * sc, Color("b3ab8e"))
		var sleeper = PackedVector2Array([p + Vector2(-14, -9) * sc, p + Vector2(9, -5) * sc, p + Vector2(17, 17) * sc, p + Vector2(-5, 15) * sc])
		draw_colored_polygon(sleeper, Color("4d4030"))
		draw_line(p + Vector2(-12, -8) * sc, p + Vector2(8, -4) * sc, Color("a08961"), 2 * sc, true)
	var far_rail = PackedVector2Array()
	var shine = PackedVector2Array()
	for p in track:
		far_rail.append(p + Vector2(0, -8 * sc))
		shine.append(p + Vector2(0, -3 * sc))
	draw_polyline(far_rail, Color("4b544f"), 5 * sc, true)
	draw_polyline(track, Color("303b37"), 9 * sc, true)
	draw_polyline(shine, Color("d1cfb6"), 2 * sc, true)

func draw_foreground() -> void:
	var sc = view_scale()
	for i in range(floori((camera_s - 35) / 3), ceili((camera_s + 35) / 3)):
		var p = world_point(i * 3.0 + sin(i * 3.7))
		if p.x < -200 or p.x > get_viewport_rect().size.x + 200: continue
		p.y += (58 + fposmod(sin(i * 23.7) * 1893, 35)) * sc
		var id = ["fern", "bush", "rocks"][posmod(i, 3)]
		var h = (32 + fposmod(sin(i * 1.9) * 5137, 28)) * sc
		ellipse(p + Vector2(8, 0), Vector2(h * 0.65, h * 0.12), Color(0.08, 0.13, 0.07, 0.28))
		grounded_sprite(id, p, h, Color(0.76, 0.84, 0.66))

func draw_train() -> void:
	var ids = model.body_ids()
	var scale_value = view_scale()
	if screen == "depot": draw_parked_wagons()
	# Draw every connector from the same transformed mount used by its body.
	for i in range(1,ids.size()):
		if screen == "depot" and not coupling_anim.is_empty() and coupling_anim.attach and ids[i] == coupling_anim.id: continue
		var front_s = model.body_s_render(i-1) if screen!="depot" else -model.body_offset(i-1)
		var rear_s = model.body_s_render(i) if screen!="depot" else -model.body_offset(i)
		var a = body_transform(ids[i],rear_s)*Geometry.coupling(ids[i],1)
		var b = body_transform(ids[i-1],front_s)*Geometry.coupling(ids[i-1],-1)
		draw_coupler(a,b)
	for i in range(ids.size() - 1, -1, -1):
		if screen == "depot" and not coupling_anim.is_empty() and coupling_anim.attach and ids[i] == coupling_anim.id: continue
		var s = model.body_s_render(i) if screen != "depot" else -model.body_offset(i)
		var p = world_point(s)
		var transform = body_transform(ids[i],s)
		draw_set_transform_matrix(transform)
		draw_body(ids[i], s, screen == "game")
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var local_bounds = art.body_bounds(ids[i])
		var world_bounds = Rect2(transform*local_bounds.position,Vector2.ZERO)
		for corner in [local_bounds.end,Vector2(local_bounds.end.x,local_bounds.position.y),Vector2(local_bounds.position.x,local_bounds.end.y)]: world_bounds=world_bounds.expand(transform*corner)
		body_hits.append({"id":ids[i],"rect":world_bounds.grow(6)})
		if screen == "depot" and tab == "Улучшения" and selected_object == ids[i] and model.state.active.is_empty(): draw_workshop_spots(ids[i], transform)
		if screen == "depot" and selected_object == ids[i]:
			draw_line(p + Vector2(-art.body_width(ids[i])*0.46,14)*scale_value,p+Vector2(art.body_width(ids[i])*0.46,14)*scale_value,GOLD,3,true)
		if screen == "game":
			add_world_hits(ids[i], i, transform)
	for pair in [[0,1],[ids.size()-1,-1]]:
		var id = ids[pair[0]]
		var s = model.body_s_render(pair[0]) if screen!="depot" else -model.body_offset(pair[0])
		var outer = body_transform(id,s)
		var mount = Geometry.coupling(id,pair[1])
		draw_coupler(outer*mount,outer*(mount+Vector2(pair[1]*float(Geometry.data().coupler.end_extension_m)*ArtV3.PX,0)))

# Wagons the player owns but has not coupled stand behind the train.
func parked_wagons() -> Array:
	var result: Array = []
	for id in parked_order + Model.WAGON_IDS:
		if model.state.wagons_by_id.has(id) and id not in model.state.consist_ids and id not in result: result.append(id)
	if not coupling_anim.is_empty() and coupling_anim.attach and coupling_anim.id not in result: result.push_front(coupling_anim.id)
	return result

func train_tail_s() -> float:
	var ids = model.body_ids()
	var last = ids.size()-1
	if not coupling_anim.is_empty() and coupling_anim.attach: last -= 1
	return -model.body_offset(last) - Geometry.length(ids[last])*0.5

func parked_s(index: int) -> float:
	var length = Geometry.length("W01")
	return train_tail_s() - PARK_GAP_M - length*0.5 - index*(length + PARK_GAP_M)

func depot_span_m() -> float:
	var parked = 0
	for id in Model.WAGON_IDS:
		if model.state.wagons_by_id.has(id) and id not in model.state.consist_ids: parked += 1
	return model.train_length() + parked*(Geometry.length("W01") + PARK_GAP_M)

func draw_parked_wagons() -> void:
	coupler_hits.clear()
	var parked = parked_wagons()
	for k in range(parked.size()):
		var id = parked[k]
		var s = parked_s(k)
		if not coupling_anim.is_empty() and coupling_anim.id == id:
			s = lerpf(coupling_anim.from, coupling_anim.to, ease(clampf(coupling_anim.t, 0, 1), -2.0))
		var transform = body_transform(id, s)
		draw_set_transform_matrix(transform)
		draw_body(id, s, false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if not coupling_anim.is_empty() or not model.depot_editable(): return
	var ids = model.body_ids()
	# Only the tail wagon can go and only the nearest parked one can come,
	# as on a real siding.
	if ids.size() > 1:
		var tail = ids[-1]
		var tail_transform = body_transform(tail, -model.body_offset(ids.size()-1))
		var ahead_transform = body_transform(ids[-2], -model.body_offset(ids.size()-2))
		var joint = (tail_transform*Geometry.coupling(tail,1) + ahead_transform*Geometry.coupling(ids[-2],-1))*0.5
		coupler_hits.append({"id": tail, "attach": false, "position": joint})
	if not parked.is_empty() and model.state.consist_ids.size() < model.max_wagons(model.vehicle_id()):
		var tail_point = body_transform(ids[-1], -model.body_offset(ids.size()-1))*Geometry.coupling(ids[-1],-1)
		var first_point = body_transform(parked[0], parked_s(0))*Geometry.coupling(parked[0],1)
		coupler_hits.append({"id": parked[0], "attach": true, "position": (tail_point+first_point)*0.5})
	var mouse = get_global_mouse_position()
	for hit in coupler_hits:
		var hover = hit.position.distance_to(mouse) < 22
		draw_circle(hit.position, 15, Color(INK, 0.9))
		draw_arc(hit.position, 15, 0, TAU, 28, Color("e2c27a") if hover else GOLD, 2.5, true)
		# Two links: closed when coupled (offer to open), apart when not.
		var gap = 3.0 if hit.attach else 0.0
		draw_arc(hit.position + Vector2(-4 - gap, 0), 5, 0, TAU, 16, PAPER, 2, true)
		draw_arc(hit.position + Vector2(4 + gap, 0), 5, 0, TAU, 16, PAPER, 2, true)
		if hover:
			var text = ("Прицепить " if hit.attach else "Отцепить ") + str(hit.id)
			var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22
			var box = Rect2(hit.position + Vector2(-width*0.5, -50), Vector2(width, 26))
			draw_style_box(style(Color(INK, 0.92), GOLD, 10), box)
			draw_string(font, box.position + Vector2(0, 18), text, HORIZONTAL_ALIGNMENT_CENTER, width, 15, PAPER)
	if not latch_flash.is_empty():
		var age = float(latch_flash.t)
		draw_arc(latch_flash.position, 10 + age*30, 0, TAU, 24, Color(1, 0.9, 0.6, 1.0 - age), 3, true)

func start_shunting(id: String, attach: bool) -> void:
	if not coupling_anim.is_empty(): return
	if not model.depot_editable():
		notify("Сцеплять вагоны можно в депо без активного рейса")
		return
	var from = parked_s(parked_wagons().find(id)) if attach else -model.body_offset(model.state.consist_ids.find(id) + 1)
	if not model.toggle_wagon(id):
		notify(model.message)
		return
	parked_order.erase(id)
	if not attach: parked_order.push_front(id)
	var to = -model.body_offset(model.state.consist_ids.find(id) + 1) if attach else parked_s(parked_wagons().find(id))
	coupling_anim = {"id": id, "attach": attach, "from": from, "to": to, "t": 0.0}
	sound.play("gear", 0.4)

func advance_shunting(dt: float) -> void:
	if not latch_flash.is_empty():
		latch_flash.t = float(latch_flash.t) + dt*2.0
		if latch_flash.t >= 1.0: latch_flash = {}
	if coupling_anim.is_empty(): return
	coupling_anim.t = float(coupling_anim.t) + dt/COUPLE_SECONDS
	if coupling_anim.t < 1.0: return
	var id = coupling_anim.id
	var attach = coupling_anim.attach
	coupling_anim = {}
	var ids = model.body_ids()
	var index = ids.find(id)
	var joint = body_transform(id, -model.body_offset(index))*Geometry.coupling(id, 1) if attach else body_transform(ids[-1], -model.body_offset(ids.size()-1))*Geometry.coupling(ids[-1], -1)
	latch_flash = {"position": joint, "t": 0.0}
	sound.play("cargo", 0.5)
	notify(("%s прицеплен" if attach else "%s отцеплен") % id)
	save_game()
	rebuild()

func body_transform(id: String, s: float) -> Transform2D:
	var direction = int(model.state.direction) if screen!="depot" else 1
	var wheels = art.wheel_positions(id)
	var a = world_point(s+direction*wheels[0].x/ArtV3.PX)
	var b = world_point(s+direction*wheels[1].x/ArtV3.PX)
	var x = (b-a).normalized()
	var y = -x.orthogonal()*direction
	var mean_x = (wheels[0].x+wheels[1].x)*0.5
	var sc = view_scale()
	var lift = Vector2(0, float(model.air_z) * ArtV3.PX * sc) if screen != "depot" else Vector2.ZERO
	return Transform2D(x*sc,y*sc,(a+b)*0.5-x*mean_x*sc-lift)

func draw_coupler(a: Vector2, b: Vector2) -> void:
	var tex = art.textures["vehicles/coupler"]
	var span = a.distance_to(b)
	var height = span*float(tex.get_height())/float(tex.get_width())
	draw_set_transform((a+b)*0.5,(b-a).angle())
	draw_texture_rect(tex,Rect2(-span*0.5,-height*0.5,span,height),false)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_body(id: String, s: float, controls: bool) -> void:
	var body_scale = view_scale()
	var body_transform = body_transform(id,s)
	ellipse(Vector2(10, 7), Vector2(art.body_width(id)*0.48, 7), Color(0.05, 0.08, 0.05, 0.23))
	art.draw_vehicle(self,id,s,int(model.state.direction) if screen!="depot" else 1,body_transform,model,controls)
	if id=="locomotive" and screen=="game": draw_charge_strip(body_transform)
	var stats = model.object_stats(id)
	for index in range(int(stats.slots)):
		var loc = slot_local(id, index)
		var key = id + ":" + str(index)
		var item = find_slot_cargo(key)
		var slot_hover=(body_transform*loc).distance_to(get_global_mouse_position())<45
		if controls and item.is_empty() and (screen=="depot" or model.state.phase=="loading" or drag=="cargo" or slot_hover):
			draw_style_box(style(Color(0.9, 0.87, 0.65, 0.35), Color("d1bd71"), 5), Rect2(loc - Vector2(32, 39), Vector2(64, 62)))
		if not item.is_empty():
			var sway = clampf(-model.acceleration * 0.04, -0.07, 0.07)
			var sprite_id = str(model.cargo_base(item.type).sprite)
			var bounds = visual_layout[sprite_id]
			var ratio = float(bounds[2]-bounds[0])/maxf(1,float(bounds[3]-bounds[1]))
			var height = art.cargo_size(sprite_id,ratio).y
			var foot=loc+Vector2(-sway*10,19)
			var local_rect=Rect2(foot-Vector2(height*ratio*0.5,height),Vector2(height*ratio,height))
			var screen_rect=Rect2(body_transform*local_rect.position,Vector2.ZERO)
			for corner in [local_rect.end,Vector2(local_rect.end.x,local_rect.position.y),Vector2(local_rect.position.x,local_rect.end.y)]: screen_rect=screen_rect.expand(body_transform*corner)
			cargo_visuals[item.id]=screen_rect.grow(4)
			if item.id!=drag_item:
				grounded_sprite(sprite_id,foot,height)
				# Straps follow the load instead of fixed screen-sized crosses.
				for side in [-1,1]:
					var x = height*ratio*0.28*side
					draw_line(foot+Vector2(x,-height*0.85),foot+Vector2(x,0),Color("806e49"),1.6,true)
	if id.begins_with("W"): art.draw_wagon_front(self,id,body_transform)
	if id.begins_with("W") and screen=="depot": draw_string(font,Vector2(-25,art.deck_y(id)+34),id,HORIZONTAL_ALIGNMENT_CENTER,50,15,PAPER)
	if id == model.vehicle_id() and controls:
		draw_controls(body_transform)

func wheel_rotation(distance: float, facing: int) -> float:
	# Positive rotation is clockwise in Godot. Mirrored bodies invert the local angle.
	return distance * 64.0 / 28.0 * facing

func find_slot_cargo(key: String) -> Dictionary:
	for item in model.state.cargo:
		if item.slot == key and not item.delivered: return item
	return {}

func slot_local(id: String, index: int) -> Vector2:
	var count = int(model.object_stats(id).slots)
	var item = find_slot_cargo(id+":"+str(index))
	var sprite_id = str(model.cargo_base(item.type).sprite) if not item.is_empty() else "sack"
	var position = art.slot_position(id,index,count,sprite_id)
	# A wide bundle rests on both columns. Smaller cargo rests on its own
	# column; removing a lower item settles the remaining stack onto the deck.
	var levels = [0.0,0.0]
	for previous in range(index+1):
		var cargo = find_slot_cargo(id+":"+str(previous))
		if previous<index and cargo.is_empty(): continue
		var sprite_id_at = str(model.cargo_base(cargo.type).sprite) if not cargo.is_empty() else sprite_id
		var wide = sprite_id_at=="log_bundle"
		var row = maxf(levels[0],levels[1]) if wide else float(levels[previous%2])
		if previous==index:
			position.y = art.deck_y(id)-19-row
			break
		var bounds = visual_layout[sprite_id_at]
		var ratio = float(bounds[2]-bounds[0])/float(bounds[3]-bounds[1])
		var height = art.cargo_size(sprite_id_at,ratio).y
		if wide: levels=[row+height,row+height]
		else: levels[previous%2]=row+height
	return position

# What kind of mouse control a pult element is: an arc lever, a rotary hand
# wheel (steam regulator and water tap), an H-gate (petrol gearbox) or a toggle.
func control_kind(id: String) -> String:
	# The electric locomotive has aircraft-style handles: vertical sliders in slots.
	if model.vehicle_id() == "locomotive" and id in ["brake", "throttle"]: return "slider"
	if model.vehicle_id() == "steam" and id in ["throttle", "gear"]: return "wheel"
	if model.vehicle_id() == "motorcar" and id == "gear": return "gate"
	return "toggle" if id == "start" else "lever"

func gate_rect(closeup: bool) -> Rect2:
	if closeup: return Rect2(control_zoom_rect().position + Vector2(222, 126), Vector2(86, 112))
	return Rect2(Vector2(-1.20, -1.58) * ArtV3.PX, Vector2(0.36, 0.38) * ArtV3.PX)

func gate_local(rect: Rect2, g: Vector2) -> Vector2:
	return rect.position + Vector2(rect.size.x * (0.15 + 0.35 * g.x), rect.size.y * (0.5 + 0.38 * g.y))

func gate_slot_pos(gear: int) -> Vector2:
	return GATE_SLOTS.get(gear, Vector2(1, 0))

# The knob moves in the neutral channel freely, and in a column only up and down.
func gate_move(pos: Vector2, delta: Vector2) -> Vector2:
	var p = pos + delta
	p.x = clampf(p.x, 0.0, 2.0)
	p.y = clampf(p.y, -1.0, 1.0)
	if absf(pos.y) > 0.1:
		p.x = float(roundi(pos.x))
	else:
		var column = roundi(p.x)
		if absf(p.y) > 0.1:
			if absf(p.x - column) > 0.22: p.y = clampf(p.y, -0.1, 0.1)
			else: p.x = float(column)
	return p

func gate_gear(pos: Vector2, previous: int) -> int:
	var column = roundi(pos.x)
	if absf(pos.y) <= 0.15: return 0
	if pos.y <= -0.85: return {0: 1, 1: 3, 2: 5}.get(column, 0)
	if pos.y >= 0.85: return {0: 2, 1: 4, 2: 6}.get(column, 0)
	return previous

func draw_gate(rect: Rect2, knob: Vector2, active: bool) -> void:
	draw_style_box(style(Color("1d2420"), Color("918363") if not active else PAPER, 4), rect.grow(4))
	var width = maxf(3.0, rect.size.x * 0.07)
	var channel = Color("070a09")
	var left = gate_local(rect, Vector2(0, 0))
	var right = gate_local(rect, Vector2(2, 0))
	draw_line(left, right, Color("5e6b62"), width + 2, true)
	for column in range(3):
		var top = gate_local(rect, Vector2(column, -1))
		draw_line(top, gate_local(rect, Vector2(column, 1)), Color("5e6b62"), width + 2, true)
	draw_line(left, right, channel, width, true)
	for column in range(3):
		var top = gate_local(rect, Vector2(column, -1))
		draw_line(top, gate_local(rect, Vector2(column, 1)), channel, width, true)
	var small = clampi(int(rect.size.x * 0.17), 11, 16)
	var labels = [[Vector2(0, -1), "1", PAPER], [Vector2(0, 1), "2", PAPER], [Vector2(1, -1), "3", PAPER], [Vector2(1, 1), "4", PAPER], [Vector2(2, -1), "5", PAPER], [Vector2(2, 1), "R", RED], [Vector2(1.52, 0), "N", GOLD]]
	for item in labels:
		var at = gate_local(rect, item[0])
		var offset = Vector2(-small * 0.4, -small * 0.9) if item[0].y < 0 else (Vector2(-small * 0.4, small * 1.35) if item[0].y > 0 else Vector2(-small * 0.3, -small * 0.55))
		draw_string(font, at + offset, item[1], HORIZONTAL_ALIGNMENT_LEFT, 20, small, item[2])
	var ball = gate_local(rect, knob)
	var radius = maxf(4.5, rect.size.x * 0.10)
	draw_circle(ball + Vector2(1.5, 2.0), radius, Color(0, 0, 0, 0.45))
	draw_circle(ball, radius, Color("17120f"))
	draw_circle(ball + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.3, Color(1, 1, 1, 0.35))
	draw_arc(ball, radius, 0, TAU, 20, GOLD, 1.2, true)

# A brass hand wheel; angle is the clockwise turn from the top.
func draw_handwheel(center: Vector2, radius: float, angle: float, color: Color, active: bool) -> void:
	draw_arc(center, radius + 5, -PI / 2, -PI / 2 + WHEEL_SWEEP, 28, Color("66796b"), 2, true)
	draw_circle(center + Vector2(1.5, 2.0), radius, Color(0, 0, 0, 0.35))
	draw_circle(center, radius, Color("2a2f2c"))
	draw_arc(center, radius - 1.5, 0, TAU, 36, color, maxf(2.0, radius * 0.16), true)
	for i in range(6):
		var spoke = Vector2(0, -1).rotated(angle + TAU * i / 6.0)
		draw_line(center + spoke * radius * 0.18, center + spoke * (radius - 2), Color("a8a38a"), maxf(1.5, radius * 0.1), true)
		draw_circle(center + spoke * (radius - 1), maxf(2.0, radius * 0.11), color)
	draw_circle(center, radius * 0.22, color)
	draw_circle(center, radius * 0.09, Color("2a2f2c"))
	var mark = center + Vector2(0, -1).rotated(angle) * (radius + 9)
	draw_circle(mark, 3.0, PAPER if active else GOLD)

# An aircraft-style handle: a slot with a scale, a coloured track up to a knurled knob.
# pivot is the bottom end of the slot, value 0..1 runs upward.
func draw_slider(base: Transform2D, pivot: Vector2, length: float, value: float, color: Color, active: bool) -> void:
	draw_set_transform_matrix(base)
	var w = clampf(length * 0.075, 4.0, 9.0)
	var plate = Rect2(pivot + Vector2(-w * 3.4, -length - w * 2.6), Vector2(w * 6.8, length + w * 5.2))
	draw_rect(plate, Color("1c2421"))
	draw_rect(plate, Color("918363"), false, 1.5)
	for corner in [plate.position + Vector2(4, 4), Vector2(plate.end.x - 4, plate.position.y + 4), Vector2(plate.position.x + 4, plate.end.y - 4), plate.end - Vector2(4, 4)]:
		draw_circle(corner, 1.8, Color("a98a4a"))
	var slot = Rect2(pivot + Vector2(-w * 0.55, -length), Vector2(w * 1.1, length))
	draw_rect(slot, Color("030504"))
	draw_rect(Rect2(slot.position + Vector2(w * 0.15, length * (1.0 - value)), Vector2(w * 0.8, length * value)), Color(color, 0.75))
	var small = clampi(roundi(length * 0.075), 7, 12)
	for i in range(11):
		var y = pivot.y - length * i / 10.0
		var major = i % 5 == 0
		draw_line(Vector2(pivot.x - w * 2.9, y), Vector2(pivot.x - w * (1.2 if major else 1.7), y), PAPER if major else Color(PAPER, 0.5), 1.6 if major else 1.0)
		draw_line(Vector2(pivot.x + w * (1.2 if major else 1.7), y), Vector2(pivot.x + w * 2.9, y), PAPER if major else Color(PAPER, 0.5), 1.6 if major else 1.0)
	draw_string(font, Vector2(pivot.x - w * 3.2, pivot.y + small + 3), "0", HORIZONTAL_ALIGNMENT_CENTER, w * 6.4, small, Color("c7c3a0"))
	draw_string(font, Vector2(pivot.x - w * 3.2, pivot.y - length - 5), "100", HORIZONTAL_ALIGNMENT_CENTER, w * 6.4, small, Color("c7c3a0"))
	var knob_y = pivot.y - length * value
	var kw = w * 2.4
	var kh = clampf(length * 0.28, 16.0, 36.0)
	var knob = Rect2(Vector2(pivot.x - kw * 0.5, knob_y - kh * 0.5), Vector2(kw, kh))
	draw_rect(Rect2(knob.position + Vector2(1.5, 2.0), knob.size), Color(0, 0, 0, 0.4))
	draw_rect(knob, Color("141917"))
	for groove in range(5):
		var gy = knob.position.y + kh * (groove + 1.0) / 6.0
		draw_line(Vector2(knob.position.x + 2, gy), Vector2(knob.end.x - 2, gy), Color(1, 1, 1, 0.16), 1.2)
	draw_rect(Rect2(knob.position, Vector2(kw, kh * 0.22)), color)
	draw_line(knob.position + Vector2(1.5, 1), Vector2(knob.position.x + 1.5, knob.end.y - 1), Color(1, 1, 1, 0.28), 1.5)
	draw_rect(knob, PAPER if active else Color("5c6660"), false, 1.5)
	draw_set_transform_matrix(base)

func lever_geometry(id: String) -> Dictionary:
	if id == "pump":
		var pose = art.mechanism_pose(model)
		return {"pivot":pose.rocker*ArtV3.PX,"grip":pose.grip_right*ArtV3.PX,"angle":pose.angle}
	return control_geometry(id)

# Where a control stands on the machine, metres. The sail car's brake stands at the bow, the end the
# sail never reaches (the boom always runs aft of the mast), so that it cannot be mistaken for the sail.
func control_anchor(id: String) -> Vector2:
	var anchor = art.vec(Geometry.body(model.vehicle_id()).control_anchors_m[id])
	if model.vehicle_id() == "sail" and id == "brake": return Vector2(1.0 * float(int(model.state.direction)), anchor.y)
	return anchor

func control_geometry(id: String, closeup: bool = false) -> Dictionary:
	var kind=control_kind(id)
	if kind=="slider":
		var slot_pivot=control_anchor(id)*ArtV3.PX
		var slot_length=0.40*ArtV3.PX
		if closeup:
			slot_pivot=control_zoom_rect().position+Vector2(65+100*["brake","throttle","gear","start"].find(id),230)
			slot_length=124.0
		var amount=float(model.state.get(id,0))
		return {"pivot":slot_pivot,"grip":slot_pivot+Vector2(0,-slot_length*amount),"angle":0.0,"length":slot_length}
	if kind=="gate":
		var rect=gate_rect(closeup)
		var knob=gate_pos if drag=="gear" else gate_slot_pos(int(model.state.gear))
		return {"pivot":rect.get_center(),"grip":gate_local(rect,knob),"angle":0.0}
	if kind=="wheel":
		var radius=34.0 if closeup else 0.17*ArtV3.PX
		var center=control_anchor(id)*ArtV3.PX
		if closeup: center=control_zoom_rect().position+Vector2(65+100*["brake","throttle","gear","start"].find(id),188)
		var turn=(float(model.boiler().feed) if id=="gear" else float(model.state.throttle))*WHEEL_SWEEP
		return {"pivot":center,"grip":center+Vector2(0,-radius).rotated(turn),"angle":turn,"radius":radius}
	var pivot=control_anchor(id)*ArtV3.PX
	var length=float(Geometry.data().controls[id+"_length_m"])*ArtV3.PX
	if closeup:
		pivot=control_zoom_rect().position+Vector2(65+100*["brake","throttle","gear","start"].find(id),225)
		length=42.0 if id=="start" else 78.0
	var value=float(model.state.get(id,0))
	if id=="gear": value=float(model.boiler().feed) if model.vehicle_id()=="steam" else float(GEAR_ORDER.find(lever_pending_gear if drag=="gear" else int(model.state.gear)))/6.0
	var angle=lerpf(-0.55,0.55,value)
	if id=="start": angle=0.0 if model.state.engine else PI
	return {"pivot":pivot,"grip":pivot+Vector2(0,-length).rotated(angle),"angle":angle}

func draw_controls(body_transform: Transform2D, show_labels: bool = true) -> void:
	var ids = world_control_ids()
	var hover = get_global_mouse_position()
	if model.vehicle_id()=="handcar":
		var left_grip=model.handcar.pose().grip_left*ArtV3.PX
		if drag=="pump" and pump_grip_side<0 or hover.distance_to(body_transform*left_grip)<24:
			draw_arc(left_grip,9,0,TAU,28,PAPER,1.5,true)
		if model.can_push_handcar():
			draw_string(font,Vector2(-118,20),"Подтолкни край платформы ↔",HORIZONTAL_ALIGNMENT_LEFT,320,16,PAPER)
		if drag=="pump":
			var pose=model.handcar.pose()
			var target=(pose.rocker+Vector2(cos(model.hand_drive.target_angle),sin(model.hand_drive.target_angle))*float(model.handcar.config.grip_radius)*pump_grip_side)*ArtV3.PX
			var grip=pose.rocker+(pose.grip_right-pose.rocker)*pump_grip_side
			draw_line(grip*ArtV3.PX,target,Color("c5a76b"),1.0,true)
			draw_arc(target,7,0,TAU,24,Color("e1c989"),1.2,true)
	for id in ids:
		var geo = lever_geometry(id)
		var color = {"pump": Color("a16b38"), "brake": RED, "throttle": GREEN, "gear": GOLD, "start": Color("708574")}[id]
		var factor = geo.pivot.distance_to(geo.grip)/float({"pump":116,"brake":166,"throttle":165,"gear":166,"start":138}[id])
		var angle = float(geo.angle)
		var kind = control_kind(id) if id != "pump" else "pump"
		if kind == "gate":
			draw_gate(gate_rect(false), gate_pos if drag == "gear" else gate_slot_pos(int(model.state.gear)), drag == id)
		elif kind == "wheel":
			draw_handwheel(geo.pivot, float(geo.radius), angle, GOLD if id == "gear" else GREEN, drag == id)
		elif kind == "slider":
			draw_slider(body_transform, geo.pivot, float(geo.length), float(model.state.get(id, 0)), Color("c23b2e") if id == "brake" else Color("4f9a5f"), drag == id)
		elif id in ["brake","throttle"]:
			draw_arc(geo.pivot,geo.pivot.distance_to(geo.grip),-PI/2-0.55,-PI/2+0.55,24,Color("918363"),1.0,true)
			draw_lever(body_transform,geo.pivot,geo.pivot.distance_to(geo.grip),angle,Color("c23b2e") if id=="brake" else Color("4f9a5f"),drag==id)
		else:
			if id not in ["pump","start"]:
				draw_arc(geo.pivot,geo.pivot.distance_to(geo.grip),-PI/2-0.55,-PI/2+0.55,24,Color("918363"),1.0,true)
			if id == "start": angle = 0.0 if model.state.engine else PI
			var pivot = Vector2(128, 128 if id == "pump" else 224)
			# The base stays fixed; only the independent supplied SVG part rotates.
			if id != "pump": sprite("control_mount", Rect2(geo.pivot - Vector2(0.065,0.065)*ArtV3.PX, Vector2.ONE*0.13*ArtV3.PX))
			draw_set_transform_matrix(body_transform * Transform2D(angle, geo.pivot))
			if id != "pump":
				sprite("control_" + id, Rect2(-pivot * factor, Vector2.ONE * 256 * factor))
			draw_set_transform_matrix(body_transform)
		var highlighted = drag==id or hover.distance_to(body_transform*geo.grip)<24
		if not highlighted or not show_labels: continue
		draw_arc(geo.grip, 9, 0, TAU, 28, PAPER, 1.5, true)
		if kind == "lever" and id in ["brake","throttle"]:
			for endpoint in range(2):
				var mark=geo.pivot+Vector2(0,-geo.pivot.distance_to(geo.grip)).rotated(lerpf(-0.55,0.55,float(endpoint)))
				draw_string(font,mark+Vector2(-8,-12),["0","100"][endpoint],HORIZONTAL_ALIGNMENT_LEFT,30,12,PAPER)
		var label = {"pump": "КАЧАЙ ↕", "brake": "%d%%" % (float(model.state.brake) * 100), "throttle": "%d%%" % (float(model.state.throttle) * 100), "gear": ("%d%%" % (float(model.boiler().feed) * 100)) if model.vehicle_id() == "steam" else GEAR_LABELS[int(model.state.gear)], "start": "ВКЛ" if model.state.engine else "ПУСК"}[id]
		draw_string(font, geo.grip + Vector2(-25, -25), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, PAPER)

func add_world_hits(id: String, index: int, transform: Transform2D) -> void:
	if index == 0:
		var ids = world_control_ids()
		for control_id in ids:
			grip_hits.append({"id": control_id, "position": transform * lever_geometry(control_id).grip})
		if id=="handcar":
			grip_hits.append({"id":"pump","side":-1.0,"position":transform*(model.handcar.pose().grip_left*ArtV3.PX)})
		if id=="sail":
			var geo = art.sail_geometry(model)
			var a = transform * art.sail_point(float(geo.mast_x) + 0.2 * float(geo.fwd), 1.0)
			var b = transform * art.sail_point(float(geo.mast_x) - 1.8 * float(geo.fwd), 3.8)
			sail_rect = Rect2(a, Vector2.ZERO).expand(b).grow(10.0)
			sail_cleat_point = transform * art.sail_point(-0.14 * float(geo.fwd), 0.66)
		if id=="pneumatic":
			for i in range(ArtV3.FROST_SPOTS.size()):
				ice_hits.append({"spot": i, "position": transform * art.steam_point(ArtV3.FROST_SPOTS[i].x, ArtV3.FROST_SPOTS[i].y)})
	for slot in model.slots():
		if slot.owner != id: continue
		var p = transform * slot_local(id, int(slot.index))
		var rect = Rect2(p - Vector2(37, 45) * zoom_level, Vector2(74, 80) * zoom_level)
		slot_hits.append({"key": slot.key, "rect": rect})
		var item = find_slot_cargo(slot.key)
		if not item.is_empty(): cargo_hits.append({"id": item.id, "rect": cargo_visuals.get(item.id,rect)})

func draw_map(size: Vector2) -> void:
	var left = 80.0
	var right = size.x - 80
	var y = 132.0
	draw_line(Vector2(left, y), Vector2(right, y), Color(0.95, 0.92, 0.82, 0.4), 3)
	var train_x = lerpf(left, right, clampf(float(model.state.s) / float(model.route.station_s[-1]), 0, 1))
	draw_line(Vector2(left, y), Vector2(train_x, y), GOLD, 3)
	for i in range(model.data.stations.size()):
		var station = model.data.stations[i]
		var x = lerpf(left, right, float(model.route.station_s[i]) / float(model.route.station_s[-1]))
		draw_circle(Vector2(x, y), 7, GOLD if station.id == model.next_destination() else PAPER)
		draw_string(font, Vector2(x - 96, y + 29), station.name, HORIZONTAL_ALIGNMENT_CENTER, 192, 17, PAPER)
	draw_circle(Vector2(train_x, y), 11, GREEN)
	draw_circle(Vector2(train_x, y), 5, PAPER)

func draw_loading_dock(size: Vector2) -> void:
	var interaction=station_state()
	var station_index = int(interaction.station_index)
	var rect = dock_rect()
	var accepting=drag=="cargo" and interaction.can_transfer and (drag_item in interaction.eligible or station_index==0)
	draw_style_box(style(Color(0.14, 0.21, 0.17, 0.95), GOLD if accepting else Color("82916c"), 12), rect)
	var title = ("ПОГРУЗКА · " if model.state.phase=="loading" else "РАЗГРУЗКА · ")+interaction.station_name
	if model.state.phase=="loading" and model.selectable_loading():
		var plan=model.loading_preview()
		title+=" · На складе %d · Везём %d из %d" % [model.state.cargo.size()-int(plan.loaded),plan.loaded,plan.offered]
	draw_string(font, rect.position + Vector2(20, 28), title, HORIZONTAL_ALIGNMENT_LEFT, 600, 18, PAPER)
	if accepting:
		draw_string(font, rect.position + Vector2(590, 28), "✓ ОТПУСТИ ЗДЕСЬ · "+interaction.station_name, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 615, 18, GOLD)
	var index = 0
	for item in model.state.cargo:
		if item.delivered or item.slot != "": continue
		if station_index != 0: continue
		var p = rect.position + Vector2(42 + index * 128, 58)
		if item.id != drag_item:
			sprite(model.cargo_base(item.type).sprite, Rect2(p, Vector2(60, 65)))
		cargo_hits.append({"id": item.id, "rect": Rect2(p - Vector2(8, 4), Vector2(96, 82))})
		draw_string(font, p + Vector2(65, 44), item.destination, HORIZONTAL_ALIGNMENT_LEFT, 45, 19, GOLD)
		index += 1
	if index == 0:
		var text=interaction.reason
		if model.state.phase=="loading" and model.all_loaded(): text="Груз закреплён. Можно ехать: просто дай ход."
		if selected_cargo!="" and selected_cargo not in interaction.eligible and station_index!=0:
			for cargo in model.state.cargo:
				if cargo.id==selected_cargo and not cargo.delivered: text="Этот груз ждут в «%s»" % model.station_name(cargo.destination)
		draw_string(font, rect.position + Vector2(25, 67), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 50, 19, PAPER)
		if selected_cargo=="": draw_string(font,rect.position+Vector2(25,115),"Перетащи предмет или выбери его кликом для выгрузки кнопкой",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-50,17,Color("b9c7b2"))

func draw_cargo_feedback() -> void:
	var interaction=station_state()
	if interaction.visible:
		var marker=world_point(interaction.stop_s)
		var sc=view_scale()
		draw_colored_polygon(PackedVector2Array([marker+Vector2(-8,17)*sc,marker+Vector2(8,17)*sc,marker+Vector2(0,5)*sc]),GOLD)
		for hit in cargo_hits:
			if hit.id==drag_item: continue
			var selected=hit.id==selected_cargo
			if hit.id in interaction.eligible or selected:
				draw_rect(hit.rect,GOLD if selected else Color("8db78a"),false,3 if selected else 1.5)
	if drag=="cargo":
		if interaction.can_transfer and (drag_item in interaction.eligible or interaction.station_id=="A"):
			draw_rect(world_platform_rect(),Color("e9ce83"),false,3)
		var r=Rect2(drag_cursor-drag_offset,drag_size)
		for cargo in model.state.cargo:
			if cargo.id==drag_item:
				grounded_sprite(model.cargo_base(cargo.type).sprite,r.position+Vector2(r.size.x*0.5,r.size.y),r.size.y)
				draw_rect(r,GOLD,false,2)
	if not delivery_ghost.is_empty():
		var alpha=1-clampf(float(delivery_ghost.time)/0.45,0,1)
		var point=Vector2(delivery_ghost.from).lerp(delivery_ghost.to,smoothstep(0,0.3,float(delivery_ghost.time)))
		grounded_sprite(delivery_ghost.sprite,point,44,Color(1,1,1,alpha))

# Short battery strip on the locomotive body (TZ 3.1, N6): readable at any
# zoom, colour only, exact numbers on hover.
func draw_charge_strip(body_transform: Transform2D) -> void:
	var fraction=charge_fraction()
	var bounds=art.body_bounds("locomotive")
	var anchor=body_transform*Vector2(bounds.position.x+bounds.size.x*0.68,art.deck_y("locomotive")-10)
	var rect=Rect2(anchor-Vector2(36,5),Vector2(72,10))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_style_box(style(Color(INK,0.9),Color(0.96,0.93,0.84,0.55),4),rect.grow(2))
	if fraction>0: draw_style_box(style(charge_color(fraction),Color.TRANSPARENT,3),Rect2(rect.position,Vector2(rect.size.x*fraction,rect.size.y)))
	draw_set_transform_matrix(body_transform)
	charge_strip_rect=rect.grow(10)

func charge_fraction() -> float:
	return clampf(float(model.state.fleet_by_id.locomotive.fuel)/maxf(0.000001,float(model.object_stats("locomotive").tank)),0,1)

func charge_color(fraction: float) -> Color:
	var green=Color("7fab85")
	var amber=Color("e2a33c")
	var red=Color("d9533c")
	if fraction>=0.5: return green
	if fraction>=0.25: return green.lerp(amber,(0.5-fraction)/0.25)
	if fraction>=0.15: return amber
	return red

# Warn once per threshold crossed downward; regeneration must lift the charge
# 2% above a threshold before it re-arms, so braking does not cause flicker.
func update_charge_warning() -> void:
	if model.vehicle_id()!="locomotive":
		charge_band=0
		return
	var fraction=charge_fraction()
	var thresholds=[0.5,0.25,0.15]
	var band=0
	for i in range(thresholds.size()):
		if fraction<thresholds[i]: band=i+1
	if band>charge_band:
		notify(["Заряд ниже 50%: тяга слабеет","Заряд 25%: тяги мало для подъёмов","Заряд 15%: тяга почти исчерпана. Зарядка в депо"][band-1])
		charge_band=band
	elif band<charge_band and fraction>thresholds[charge_band-1]+0.02:
		charge_band=band

func draw_tooltip() -> void:
	if drag != "": return
	var mouse = get_global_mouse_position()
	var text = ""
	for hit in grip_hits:
		if hit.position.distance_to(mouse) < 31:
			text = {"pump": "Зажми хват и веди его по дуге рычага", "brake": "Тормоз: двигай ручку вверх по прорези от 0 до 100%" if model.vehicle_id() == "locomotive" else "Тормоз: веди рукоять по дуге от 0 до 100%", "throttle": "Вентиль: крути колесо по кругу, отпустишь — закроется сам" if model.vehicle_id() == "steam" else ("Тяга: двигай ручку вверх по прорези от 0 до 100%" if model.vehicle_id() == "locomotive" else "Подача: веди рукоять по дуге от 0 до 100%"), "gear": "Кран воды: крути по кругу. Без воды пара нет" if model.vehicle_id() == "steam" else "Кулиса: веди шар через N в паз. Менять при газе ниже 15%, R только на остановке", "start": "Щёлкни, чтобы разжечь или погасить огонь" if model.vehicle_id() == "steam" else "Щёлкни тумблер, чтобы включить или выключить"}[hit.id]
	if text=="" and screen=="game" and model.vehicle_id()=="locomotive" and charge_strip_rect.has_point(mouse):
		text="Заряд %d%% · доступная тяга %d%%" % [roundi(charge_fraction()*100),roundi(model.charge_traction_factor()*100)]
	for hit in cargo_hits:
		if hit.rect.has_point(mouse):
			for item in model.state.cargo:
				if item.id == hit.id:
					text = "%s · %d кг → %s" % [model.cargo_base(item.type).name, model.cargo_base(item.type).mass_kg, model.station_name(item.destination)]
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if text != "" else Input.CURSOR_ARROW)
	if text != "":
		var p = Vector2(clampf(mouse.x - 180, 20, get_viewport_rect().size.x - 560), mouse.y - 68)
		draw_style_box(style(INK, GOLD, 6), Rect2(p, Vector2(540, 45)))
		draw_string(font, p + Vector2(12, 29), text, HORIZONTAL_ALIGNMENT_LEFT, 515, 18, PAPER)

func draw_menu_train(size: Vector2) -> void:
	var p = Vector2(size.x*0.74,size.y*0.75)
	draw_line(Vector2(size.x*0.48,p.y-5),Vector2(size.x,p.y-5),INK,7,true)
	var outer = Transform2D(0,Vector2(1.7,1.7),0,p)
	art.draw_vehicle(self,"handcar",0,1,outer,menu_preview,false,art.forward_pose(time*1.5))
	draw_set_transform_matrix(Transform2D.IDENTITY)
