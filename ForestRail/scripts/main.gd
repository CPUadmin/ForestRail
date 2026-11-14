extends Node2D

const Model = preload("res://scripts/model.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const Sound = preload("res://scripts/sound.gd")
const ArtV3 = preload("res://scripts/art_v3.gd")
const Records = preload("res://scripts/records.gd")
const ControlArt = preload("res://scripts/control_art.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const CabArt = preload("res://scripts/cab_art.gd")
const TrainArt = preload("res://scripts/train_art.gd")
const MenuUi = preload("res://scripts/menu_ui.gd")
const DepotUi = preload("res://scripts/depot_ui.gd")
const ArtWorld = preload("res://scripts/art_world.gd")
const Geometry = preload("res://scripts/world_geometry.gd")
const Instruments = preload("res://scripts/instruments.gd")
const ZeppelinPult = preload("res://scripts/zeppelin_pult.gd")
const JetPult = preload("res://scripts/jet_pult.gd")
const CabSide = preload("res://scripts/cab_side.gd")
const CHARGING_PLUG = preload("res://assets/art_electric/charging_plug.png")
const CONTACTOR_HATCH = preload("res://assets/art_electric/contactor_hatch.png")
const CAB_WOOD = preload("res://assets/art_cab/cab_dash_wood.png")
const CAB_STEEL = preload("res://assets/art_cab/cab_dash_steel.png")
const CAB_WINDSHIELD = preload("res://assets/art_cab/cab_window_frame.png")
const PAPER = Color("f5ecd6")
const MUTED_INK = Color("5c6b62")
const CasinoView = preload("res://scripts/casino_view.gd")
const AlbumView = preload("res://scripts/album_view.gd")
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
var map_button: Button    # the minimap strip (a click opens the map): the header has no map button any more
var menu_hud_button: Button   # the only global button of the header: the menu (pause)
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
	"autosave": 60, "night_light": 0.0, "light_flicker": true, "weather": 0, "weather_frequency": 1.0, "keys": {"map": KEY_M, "cab": KEY_E, "ice": KEY_I, "brake": KEY_SPACE, "sail_side": KEY_F, "burst": KEY_B, "grapnel": KEY_G}}
const WINDOW_SIZES = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const SETTINGS_TABS = ["Звук", "Экран", "Игра"]   # three groups; the technical things are folded under "Ещё"
var settings = DEFAULT_SETTINGS.duplicate(true)
var settings_backup: Dictionary = {}
var settings_tab = "Звук"
var free_trips_open = false   # the depot: the list of free trips is unfolded under the main order
var settings_fold: Dictionary = {}   # which folded groups of the settings are open
var pause_stuck_open = false   # the pause menu: the group "Застрял?" (the help of the depot and the repair at the station) is unfolded
var awaiting_key = ""
var camera_s = 0.0
var camera_y = 0.0
var camera_x = 0.0
var clean_frame = false   # the scene without the panels of the interface (pictures for mockups, tests/probe_ui_tour.gd); never on in the game
var camera_target_last = INF   # where the camera aimed in the previous frame: gives it the speed of the train
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
var grapnel_button: Button    # the button of the grapnel of the pole truck (nothing without the gadget)
var burst_button: Button       # the button of the supercapacitor of the electric locomotive (nothing without the gadget)
var cab_blend = 0.0
# B3.1: arriving at a platform in the cab lowers it so that the platform and the load are in view;
# moving off again raises it back. Pressing E by hand cancels the automatic return.
var cab_resume = false
# B-cab: the dashboard buttons of the steam cab. The headlamp is lit by itself at night until the driver
# takes it over (lamp_manual 1 on, 0 off, -1 by itself); the wipers only matter in rain.
var lamp_manual = -1
var wiper_on = false
var wiper_phase = 0.0
var whistle_pull = 0.0
var mini_button: Button   # the invisible button over the minimap; the cab dashboard has its own gauges there
var was_docked = false
var cab_hits: Array = []
# The pult drawn full size inside the cab scene is the same pult scaled and moved:
# pult_t maps its own coordinates to the screen (identity for the panel on C).
var pult_t = Transform2D.IDENTITY
var cab_exit_rect = Rect2()
var zpult = ZeppelinPult.new()   # the cockpit of the rail zeppelin (B6.5): its own levers and dials
var jpult = JetPult.new()   # the cockpit of the jet (rocket) train (B6.6): the fuses, the cover, the countdown
var cab_sides: Array = []
# Visual-only engine temperature of the petrol car, 0..1: warms up while it runs.
var cab_temp = 0.05
# Cab liveliness: a jolt at every rail joint, spring-driven needles, frame time.
var cab_jolt = 0.0
var cab_joint = -999999
var needle_state: Dictionary = {}
var cab_dt = 0.016
const ELECTRIC_START_FLASH = 0.35
var electric_start_flash = 0.0
var electric_was_powered = false
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
const REDUCER_SWEEP = TAU * 3.0   # the reducer wheel of the pneumatic train: three full turns

func wheel_sweep() -> float:
	return REDUCER_SWEEP if model.vehicle_id() == "pneumatic" else WHEEL_SWEEP
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
var valve_hits: Array = []   # the four condensate valves under the frosted places (B6.2)
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
var time = 0.0
var test_mode = false
var land_dust: Dictionary = {}   # B5.5: the puff of dust where the train came down {t, s, power}
var live_in_tests = false   # the view test of the live train looks at it in test mode
var junk_in_tests = false   # and the view test of the road finds
var glint_hits: Array = []   # B6.11 b: the glints by the rail on the screen {index, position}
var smoke_frames = -1
var screenshot_path = ""
var settings_path = "user://settings.json"

# A test suite may be started by name from the command line when its script exists in res://tests and the name is of the test kind.
func qa_suite_allowed(suite: String) -> bool:
	var name_ok = suite.begins_with("check_") or suite.begins_with("probe_") or suite.begins_with("drive_")
	for c in suite:
		if not (c >= "a" and c <= "z") and not (c >= "0" and c <= "9") and c != "_": name_ok = false
	return name_ok and ResourceLoader.exists("res://tests/" + suite + ".gd")

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
				if not qa_suite_allowed(suite): get_tree().quit(2); return   # any tests/check_*, probe_* or drive_* script that exists (T8: no list to extend by hand)
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
	if art != null: art.reduce_motion_flag = bool(settings.reduce_motion)
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
	settings.night_light = clampf(float(settings.night_light), 0.0, 1.0)
	settings.light_flicker = settings.light_flicker is not bool or settings.light_flicker
	settings.weather = int(settings.weather) if int(settings.weather) in [0, 1, 2] else 0
	settings.weather_frequency = float(settings.weather_frequency) if float(settings.weather_frequency) in [0.5, 1.0, 2.0] else 1.0
	model.weather_frequency = float(settings.weather_frequency)
	# Hot keys: valid, never Escape (it always pauses), never twice; otherwise back to the defaults.
	var keys: Dictionary = settings.keys
	if not keys.has("burst"): keys["burst"] = KEY_B   # saves from before the supercapacitor keep their own keys
	if not keys.has("grapnel"): keys["grapnel"] = KEY_G
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

var menu_ui_cache = null
func menu_ui():
	if menu_ui_cache == null: menu_ui_cache = MenuUi.new(self)
	return menu_ui_cache

func build_settings(box: VBoxContainer) -> void:
	menu_ui().build_settings(box)

func build_menu(size: Vector2) -> void:
	menu_ui().build_menu(size)


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
	theme.set_color("font_color", "Label", UiKit.T1)
	# the buttons: brass on dark wood (ui_kit.gd); the green flat boxes are gone
	UiKit.apply_to_theme(theme, "Button", "secondary")
	theme.set_type_variation("PrimaryAction", "Button")
	UiKit.apply_to_theme(theme, "PrimaryAction", "primary")
	theme.set_type_variation("QuietAction", "Button")
	UiKit.apply_to_theme(theme, "QuietAction", "quiet")
	theme.set_type_variation("DangerAction", "Button")
	UiKit.apply_to_theme(theme, "DangerAction", "danger")
	theme.set_stylebox("panel", "PanelContainer", UiKit.board())
	ui.theme = theme
	overlay.theme = theme

func add_label(parent: Node, text: String, size: int = 20, color: Color = INK) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(size * float(settings.text_scale)))
	label.add_theme_color_override("font_color", UiKit.on_dark(color, INK, MUTED_INK, GOLD, RED, GREEN))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

# selected marks the current choice in a group (tab, vehicle, direction): it is
# inert like a disabled button but must read as active, not unavailable.
func add_button(parent: Node, text: String, action: Callable, disabled: bool = false, selected: bool = false, appearance: StringName = &"Button") -> Button:
	var button = Button.new()
	button.theme_type_variation = appearance
	button.text = text
	button.disabled = disabled or selected
	if selected:
		button.add_theme_stylebox_override("disabled", UiKit.box("secondary", "selected"))
		button.add_theme_color_override("font_disabled_color", UiKit.LAMP)
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
	var box = UiKit.plaque(Color(0, 0, 0, 0) if edge == CARD_EDGE else (UiKit.LAMP if edge == GOLD else edge))
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

# P4: the inside of the depot painted by GPT: the plank wall, the rafters with the lamps on rings, the things of the workshop, the light.
const DEPOT_WALL = preload("res://assets/art_depot/wall.png")
const DEPOT_RAFTERS = preload("res://assets/art_depot/rafters.png")
const DEPOT_GLOW = preload("res://assets/art_depot/lamp_glow.png")
const DEPOT_PROP = {
	"window": preload("res://assets/art_depot/prop_window.png"), "lamp": preload("res://assets/art_depot/prop_lamp.png"),
	"shelf": preload("res://assets/art_depot/prop_shelf.png"), "tools": preload("res://assets/art_depot/prop_tools.png"),
	"bench": preload("res://assets/art_depot/prop_bench.png"), "barrel": preload("res://assets/art_depot/prop_barrel.png"),
	"ladder": preload("res://assets/art_depot/prop_ladder.png"), "wheels": preload("res://assets/art_depot/prop_wheels.png"),
	"chain": preload("res://assets/art_depot/prop_chain.png")}

# The pictures of the junk (P9b, painted by GPT: the sheets of junk and of rare junk, cut into junk_1..9 and rare_1..9): the sheets are general, so only the kinds
# that really match a picture have one; the rest stay a text line (no wrong picture is better than a wrong one).
const JUNK_ICON = {"rusty_bolt": "junk_1", "bearing_cover": "junk_2", "tie_plate": "junk_4", "brake_shoe": "junk_6", "lever_bolt": "junk_7", "stationmaster_watch": "junk_9",
	"golden_bolt": "rare_2", "cracked_lantern": "rare_4", "grate_bar": "rare_6", "mikhalych_seal": "rare_9"}

var depot_ui_cache = null
func depot_ui():
	if depot_ui_cache == null: depot_ui_cache = DepotUi.new(self)
	return depot_ui_cache

func build_depot(size: Vector2) -> void:
	depot_ui().build_depot(size)

func draw_depot_interior(size: Vector2) -> void:
	depot_ui().draw_depot_interior(size)

func build_receiving(box: VBoxContainer) -> void:
	depot_ui().build_receiving(box)

func sell_bolts(id: String, count: int, rare: bool) -> void:
	depot_ui().sell_bolts(id, count, rare)

func draw_workshop_spots(id: String, transform: Transform2D) -> void:
	depot_ui().draw_workshop_spots(id, transform)

func nearest_workshop_spot(point: Vector2) -> Dictionary:
	return depot_ui().nearest_workshop_spot(point)

func stat_change(before, after) -> String:
	return depot_ui().stat_change(before, after)


# The steepest climb of the road from the depot to distance s (as a grade, 0.03 is 3%), measured
# over 30 m so that a short springboard knoll is not mistaken for a hill.
# The steepest climb from the depot to a distance. 1.3.9: it walked the whole line for every order card (6 ms each,
# the board of orders froze for ~65 ms); now the running maximum is built once per line and read from the table.
var climb_table := PackedFloat32Array()
var climb_table_key = null
func route_climb_to(distance: float) -> float:
	var key = [model.route, model.route.seed_value, model.route.points.size()]
	if climb_table_key != key:
		climb_table_key = key
		climb_table.clear()
		var worst = 0.0
		var s = 0.0
		var last = float(model.route.station_s[-1]) + 100.0
		while s <= last:
			worst = maxf(worst, (model.route.sample(s + 30.0).y - model.route.sample(s).y) / 30.0)
			climb_table.append(worst)
			s += 10.0
	if distance < 0.0: return 0.0
	var index = floori(distance / 10.0)
	if index < climb_table.size(): return climb_table[index]
	var worst_far = climb_table[-1]
	var s_far = float(climb_table.size()) * 10.0
	while s_far <= distance:
		worst_far = maxf(worst_far, (model.route.sample(s_far + 30.0).y - model.route.sample(s_far).y) / 30.0)
		s_far += 10.0
	return worst_far

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
	# a long train (the jet with four wagons) must fit the screen: the head stands at about two thirds of the width, the tail must not leave it
	var by_length = 10.5 / maxf(10.5, model.train_length())
	var by_width = 0.62 * get_viewport_rect().size.x / (ArtV3.PX * maxf(1.0, model.train_length()))
	var fit = clampf(minf(by_length, by_width), 0.45, 1.0)
	if model.grapnel_installed(): fit = minf(fit, 0.7)   # the posts to throw at stand up to 15 m ahead: the view goes out to show them
	return fit

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
	var buttons_width = ((210 if model.grapnel_installed() else 70) if model.human_powered() else (210 if model.burst_gadget() != "" else 70))*float(settings.text_scale)   # the row holds the menu button and the gadget buttons
	hud = positioned_label("", Rect2(34, 12, size.x - buttons_width - 90, 42), 20)
	hud.autowrap_mode=TextServer.AUTOWRAP_OFF
	hud.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var pause_row = HBoxContainer.new()
	pause_row.position = Vector2(size.x - buttons_width - 34, 10)
	pause_row.size = Vector2(buttons_width, 46)
	pause_row.add_theme_constant_override("separation",10)
	ui.add_child(pause_row)
	map_button = mini_button
	burst_button = null
	if model.burst_gadget() != "": burst_button = add_button(pause_row, burst_button_text(), try_burst)
	grapnel_button = null
	if model.grapnel_installed(): grapnel_button = add_button(pause_row, grapnel_button_text(), try_grapnel)
	# the cab is entered by the key E or by a click on the machine, the map by the key M or by a click on the strip of the route, the pause by Esc
	menu_hud_button = add_button(pause_row, "☰", pause_game, false, false, &"QuietAction")
	menu_hud_button.tooltip_text = "Меню и пауза [Esc]"
	menu_hud_button.custom_minimum_size.x = 52
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

# B5.4: how far the train still rolls with the best braking, a warning when the stop is near, and the state of the wheels.
func brake_hint_text(target_s: float) -> String:
	var text = ""
	var speed = absf(float(model.state.v))
	if speed >= 3.0:
		var stop_m = model.stopping_distance()
		text = " · торм. путь %d м" % roundi(minf(stop_m, 999.0))
		var ahead = (target_s - float(model.state.s)) * int(model.state.direction)
		if ahead > 0.0 and float(model.state.v) * int(model.state.direction) > 0.0 and stop_m * 1.1 >= ahead: text += " — ТОРМОЗИ"
	# the wear warning is the lamp in the speed panel now (instruments.gd), the weak node is named in the pause window
	if model.wheel_slip and not model.wheel_lock and float(model.state.throttle) > 0.05: text += " · колёса буксуют"
	return text

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
	hud.text = "%s · %d м · %s · %s" % [model.journey_heading(),absf(target_s-float(state.s)),model.clock_text(),model.weather_name() if int(settings.weather) != 2 else "ясно"] + deadline_text() + brake_hint_text(target_s) + keys_hint_text()
	if burst_button != null and is_instance_valid(burst_button):
		burst_button.text = burst_button_text()
		burst_button.disabled = not model.burst_ready()
	if grapnel_button != null and is_instance_valid(grapnel_button):
		grapnel_button.text = grapnel_button_text()
		grapnel_button.disabled = model.state.phase != "route" or model.grapnel.mode in ["flying", "dropped", "torn"]
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
		hint = "Зажми нижний угол паруса мышью и держи: к мачте — парус раскрыт, назад — ребром; вверх или вниз — угол приподнимается или опускается (высоко держишь — полотно закручивается и ветер уходит). Клавиша F (по умолчанию) переводит гик на другой борт: боковой ветер наполняет парус на подветренном борту. Отпустил — парус полощет и не тянет; отпусти над утёй у кормы (медная скоба) — шкот закреплён в ближайшей из трёх засечек (с гаджетом — в любом положении). Попутный ветер — раскрой, боковой — наполовину. Тормоз — красный рычаг у носа или клавиша %s."  % key_name("brake")
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
	key += "_" + str(model.oars_out()) + "_" + str(model.can_turn() == "")
	if key != last_action_key:
		last_action_key = key
		clear_children(action_bar)
		if state.phase == "loading":
			add_button(action_bar, "Отправиться →", func():
				if model.depart(): save_game(); rebuild()
				else: notify(model.message), not model.all_loaded(), false, &"PrimaryAction")
			add_button(action_bar, "Заехать в депо →", start_depot_entry)
			var plan=model.loading_preview()
			var choice_label=add_label(action_bar,"Везём %d / %d · %d кг · %d монет" % [plan.loaded,plan.capacity,plan.mass_kg,plan.reward],19,PAPER)
			choice_label.add_theme_stylebox_override("normal",style(INK,Color("5d7561"),6))
			choice_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		elif model.stopped():
			if model.vehicle_id() == "sail" and (model.oars_owned() or model.oars_out()):
				add_button(action_bar, "Убрать вёсла" if model.oars_out() else "Вёсла", func():
					if model.set_oars(not model.oars_out()): last_action_key = ""
					else: notify(model.message))
			# one switch for the direction of the pull instead of two buttons: it shows where the machine pulls now and flips it
			if model.vehicle_id() not in ["handcar","pole","sail","motorcar"]:
				var forward = model.drive_direction() > 0
				add_button(action_bar, "Тяга →" if forward else "Тяга ←", func():
					var wanted = -int(state.direction) if forward else int(state.direction)
					if model.set_reverser(wanted): save_game(); last_action_key = ""
					else: notify(model.message))
			# what cannot be done now is not shown (no grey button without a reason): the turn is offered only when it is possible
			if stop_index >= 0 and model.can_turn() == "":
				add_button(action_bar, "Развернуть", func():
					if model.turn(): save_game(); notify("Состав развёрнут"); last_action_key = ""
					else: notify(model.message))
			if stop_index == 0:
				add_button(action_bar, "Заехать в депо →", start_depot_entry)
			# the frost of the pneumatic train is knocked off by the key I or by a click on the white spots; the manual save is in the pause menu only
		for child in action_bar.get_children():
			if child is Button: child.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	action_bar.visible=not cab_active() and action_bar.get_child_count()>0 and (state.phase=="loading" or model.stopped())

# The first three deliveries the header reminds where the removed buttons went.
func keys_hint_text() -> String:
	if int(model.state.stats.get("deliveries", 99)) >= 3 or cab_active(): return ""
	var cab_part = "" if model.human_powered() else " · %s кабина" % key_name("cab")
	return "   [%s карта%s · Esc меню]" % [key_name("map"), cab_part]

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
	if model.vehicle_id() == "jet": return "Керосин %.0f / %.0f л" % [amount, cap]
	return "Бензин %.2f / %.1f л" % [amount, cap]

func vehicle_display_name() -> String:
	return str(model.vehicle_base().name)

# What each machine is for, in a few words (the court of the five vehicles and the speed table).
const VEHICLE_ROLE = {
	"handcar": "Бесплатная, качай рычаг.",
	"pole": "Идёт шестом, медленно и точно.",
	"sail": "Ходит по ветру, в штиль стоит.",
	"steam": "Тянет много, разгоняется медленно.",
	"motorcar": "Быстрая, но прожорливая.",
	"pneumatic": "Сильная на подъёмах, боится мороза.",
	"locomotive": "Ровная тяга, бережёт заряд.",
	"zeppelin": "Летает, если ловко управлять.",
	"jet": "Самый мощный, ракетный запуск."}

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
	var on_deck = int(base.deck_slots) > 0
	var wagons = int(base.get("max_wagons", 0)) > 0
	var cargo = "платформа и вагоны" if on_deck and wagons else ("платформа" if on_deck else ("вагоны" if wagons else "нет"))
	var energy = {"handcar": "без топлива", "steam": "уголь и вода", "motorcar": "бензин", "pneumatic": "сжатый воздух", "pole": "мускулы", "sail": "ветер", "locomotive": "аккумулятор", "zeppelin": "бензин", "jet": "керосин"}.get(id, "")
	return "Груз: %s  ·  Ход: %s" % [cargo, energy]

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
# The supercapacitor: +50% of the pull for 5 seconds, then 45 seconds to charge (Model.start_burst).
func try_burst() -> void:
	if not model.start_burst():
		if model.nitro_installed():
			if model.nitro_charges() <= 0: notify("Закись азота кончилась: баллоны наполнят к следующему рейсу")
			elif not model.state.engine: notify("Нитро работает только на заведённом двигателе")
		elif model.burst_cooldown() > 0.0: notify("Суперконденсатор заряжается: ещё %d с" % int(ceil(model.burst_cooldown())))
		return
	sound.play("contactor", 0.9, 0.8)
	sound.play("coins", 0.35, 1.9)
	cab_jolt = maxf(cab_jolt, 0.5)

# The grapnel of the pole truck: the right mouse button throws at the cursor (the dotted arc shows where the hook goes), the winch pulls the truck up to the support;
# the same button (or the key G) lets it go. The key G and the button without the mouse throw at the nearest post, tree or rock ahead.
func grapnel_aim_local(mouse: Vector2) -> Vector2:
	var outer = body_transform(model.vehicle_id(), model.body_s_render(0))
	var local = outer.affine_inverse() * mouse / ArtV3.PX
	return Vector2(local.x, 0.21 - local.y)   # metres ahead of the truck, metres above the rail

func aim_grapnel(mouse: Vector2) -> void:
	if model.grapnel.mode == "hooked":
		model.release_grapnel()
		return
	var aim = grapnel_aim_local(mouse)
	if aim.x < 0.5:
		notify("Кошка бросается вперёд по ходу: целься правее")
		return
	if not model.throw_grapnel_at(aim.x, aim.y - float(model.grapnel.HAND_H)): notify(model.message)

func try_grapnel() -> void:
	if model.grapnel.mode == "hooked":
		model.release_grapnel()
		return
	if not model.throw_grapnel(): notify(model.message)

func grapnel_button_text() -> String:
	match model.grapnel.mode:
		"flying": return "Кошка летит"
		"hooked": return "Снять [%s]" % key_name("grapnel")
		"dropped", "torn": return "Кошка…"
	return "Кошка [%s / ПКМ]" % key_name("grapnel")

func burst_button_text() -> String:
	if model.nitro_installed():
		if model.burst_left() > 0.0: return "Нитро: %.0f с" % ceil(model.burst_left())
		return "Нитро ×%d [%s]" % [model.nitro_charges(), key_name("burst")]
	if model.burst_left() > 0.0: return "Рывок: %.0f с" % ceil(model.burst_left())
	if model.burst_cooldown() > 0.0: return "Заряд: %d с" % int(ceil(model.burst_cooldown()))
	return "Рывок [%s]" % key_name("burst")

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
	if model.vehicle_id() == "locomotive": return ["brake", "throttle"]
	if model.auto_reducer(): return ["brake", "throttle", "start"]   # the automatic reducer has no wheel
	return ["brake", "throttle", "gear", "start"]   # the pneumatic train: gear is the wheel of the reducer, start is the tap of the heating (B6.2)

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
		var flicker = 0.7 + 0.3 * sin(time * 9.0) * sin(time * 3.7) if light_flicker_enabled() else 1.0
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
	var lintel := PackedVector2Array()
	for segment in range(13):
		var angle = PI * float(segment) / 12.0
		lintel.append(Vector2(fire.get_center().x - cos(angle) * fire.size.x * 0.5, fire.position.y - sin(angle) * 9.0))
	draw_polyline(lintel, Color("5c615a"), 3.0, true)

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
	if id.begins_with("drain"):
		var spot = int(id.trim_prefix("drain"))
		var was_plugged = model.plugged(spot)
		if model.drain(spot):
			sound.play("steam_blow", 0.4, 1.6)
			notify("Клапан %d: конденсат сброшен%s" % [spot + 1, ", ледяная пробка растаяла" if was_plugged else ""])
		return
	if id == "light":
		lamp_manual = 0 if lights_lit() else 1
		notify("Фара включена" if lamp_manual == 1 else "Фара выключена")
		sound.play("gear", 0.5, 1.2)
		return
	if id == "wiper":
		wiper_on = not wiper_on
		notify("Дворники включены" if wiper_on else "Дворники выключены")
		sound.play("gear", 0.5, 0.8)
		return
	if id == "whistle":
		if model.vehicle_id() == "steam":
			whistle_pull = 1.0
			sound.play("whistle", 0.9)
		else:
			sound.play("horn", 0.9)
		return
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
	if has_own_pult(): return []   # the zeppelin and the jet have their own pults
	if model.vehicle_id() == "handcar": return ["pump", "brake"]
	if model.vehicle_id() in ["pole", "sail"]: return ["brake"]
	return ["brake", "throttle"]

func draw_lever(base: Transform2D, pivot: Vector2, length: float, angle: float, knob: Color, active: bool) -> void:
	control_art().draw_lever(base, pivot, length, angle, knob, active)

# The zeppelin and the jet have their own pult only in the cab (the decision of the owner, 08.11.2026: no separate pults in the game);
# outside, in the side view, there are only the two usual levers on the machine: the brake and the throttle.
func has_own_pult() -> bool:
	return cab_active() and model.vehicle_id() in ["zeppelin", "jet"]

func own_pult():
	return jpult if model.vehicle_id() == "jet" else zpult

func draw_zeppelin_pult(origin: Vector2, scale: float) -> void:
	var pult = own_pult()
	pult.model = model
	pult.font = font
	pult.place(origin, scale)
	pult.draw(self, get_global_mouse_position())

func control_zoom_rect() -> Rect2:
	if has_own_pult(): return Rect2(36, 90, own_pult().W, own_pult().H)
	return Rect2(36,90,430,456 if model.vehicle_id()=="steam" else 320)

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
			if model.auto_gearbox(): draw_selector(gate_rect(true),gate_pos if drag=="gear" else gate_slot_pos(int(model.state.gear)),drag==id)
			else: draw_gate(gate_rect(true),gate_pos if drag=="gear" else gate_slot_pos(int(model.state.gear)),drag==id)
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
		var title={"brake":"Тормоз","throttle":{"locomotive":"Тяга","steam":"Вентиль","pneumatic":"Вентиль"}.get(model.vehicle_id(),"Газ"),"gear":"Вода" if steam else ("Редуктор" if model.vehicle_id()=="pneumatic" else "Передача"),"start":"Розжиг" if steam else ("Обогрев" if model.vehicle_id()=="pneumatic" else "Пуск")}[id]
		var shown_gear=lever_pending_gear if drag=="gear" else int(model.state.gear)
		var label={"brake":"%d%%" % (model.state.brake*100),"throttle":"%d%%" % (model.state.throttle*100),"gear":("%d%%" % (float(model.boiler().feed)*100)) if steam else (("%.0f бар" % model.working_pressure()) if model.vehicle_id()=="pneumatic" else GEAR_LABELS[shown_gear]),"start":("Горит" if model.state.engine else "Разжечь") if steam else (("Греет" if model.heating_on() else "Выкл.") if model.vehicle_id()=="pneumatic" else ("Вкл." if model.state.engine else "Выкл."))}[id]
		draw_string(font,rect.position+Vector2(15+100*i,78),title,HORIZONTAL_ALIGNMENT_CENTER,100,16,PAPER)
		draw_string(font,rect.position+Vector2(15+100*i,168 if id=="start" else (268 if kind=="slider" else 253)),label,HORIZONTAL_ALIGNMENT_CENTER,100,16,GOLD)
		if kind=="lever":
			for endpoint in range(2):
				var mark=pivot+Vector2(0,-length).rotated(lerpf(-0.55,0.55,float(endpoint)))
				# the ends of neighbouring levers stand close: "100" is set higher than "0" so that they never touch
				draw_string(font,mark+Vector2(-17,-27 if endpoint==1 else -12),["0","100"][endpoint],HORIZONTAL_ALIGNMENT_CENTER,34,13,PAPER)
		if drag==id or (pult_t*point).distance_to(get_global_mouse_position())<24: draw_arc(point,10,0,TAU,28,PAPER,1.5,true)
	if model.vehicle_id()=="steam": draw_steam_panel(rect)
	var feedback=toast if toast_seconds>0 else ("Крути вентиль по кругу, отпусти — закроется сам. Розжиг — щелчком." if model.vehicle_id()=="steam" else ("Веди шар рычага по кулисе: через N в нужный паз. Пуск — щелчком." if model.vehicle_id()=="motorcar" else ("Двигай ручки вверх и вниз по прорезям, они держат положение." if model.vehicle_id()=="locomotive" else "Редуктор: крути колесо, 3 оборота. Обогрев и клапаны: щелчок.")))
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
	if modal_kind == "album":
		var album_screen = AlbumView.new()
		album_screen.game = self
		album_screen.size = size
		overlay.add_child(album_screen)
		return
	if modal_kind == "casino":
		var casino_screen = CasinoView.new()
		casino_screen.game = self
		casino_screen.size = size
		overlay.add_child(casino_screen)
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
			rebuild(), false, false, &"PrimaryAction")
		add_button(box, "Отмена", close_modal, false, false, &"QuietAction")
	elif modal_kind == "pause":
		add_label(box, "Пауза", 34)
		if resume_prompt: add_label(box, "Готов продолжить поездку?", 23)
		if Model.wear_rules and model.wear().warning():
			var weak_node = model.wear().train_worst()
			add_label(box, "Слабое место: %s %d%%" % [str(weak_node.name).to_lower(), roundi(float(weak_node.cond) * 100.0)], 22)
		if Model.wear_rules and not model.wear().journal.is_empty():
			add_label(box, "Что случилось в рейсе", 22)
			for line in model.wear().journal_lines(): add_label(box, str(line), 19)
		add_button(box, "Продолжить", close_modal, false, false, &"PrimaryAction")
		if Model.wear_rules and model.creative() and model.wear().needs_repair():
			add_button(box, "Починить всё", func():
				var mended = model.wear().repair_all()
				notify("Починено узлов: %d" % mended)
				save_game()
				show_modal("pause"))
		add_button(box, "Сохранить", func(): save_game(); notify("Сохранено"))
		add_button(box, "Настройки", func(): show_modal("settings"))
		# the rare actions are folded under one line: the pause menu shows three things at first sight
		add_button(box, "Застрял? ▴" if pause_stuck_open else "Застрял? ▾", func(): pause_stuck_open = not pause_stuck_open; show_modal("pause"), false, false, &"QuietAction")
		if pause_stuck_open and Model.wear_rules and model.wear().emergency_possible() and float(model.wear().train_worst().cond) < 0.5:
			add_button(box, "Аварийный ремонт (до 50%)", func():
				var done = model.wear().emergency_all()
				notify("Мастерская станции: +%d%% износа, %d монет" % [roundi(float(done.gained) * 100.0), int(done.price)])
				save_game()
				close_modal())
		if pause_stuck_open: add_button(box, "Помощь депо", func(): confirm("Вернуть состав домой%s? Груз, отметки доставки и покупки сохранятся. Запас энергии пополнится.%s" % [(" за %d монет" % model.rescue_fee()) if model.rescue_fee() > 0 else "", (" Не хватает монет: остаток уйдёт в долг и вычтется из следующей награды. Узлы тяги депо починит сразу.") if model.rescue_fee() > int(model.state.money) else (" Узлы тяги депо починит сразу." if model.rescue_fee() > 0 else "")], func():
			model.rescue()
			screen = "depot"
			camera_s = 0
			save_game()
			if model.state.paid_ids.size() > last_paid_count:
				last_paid_count = model.state.paid_ids.size()
				show_modal("result")
			else: rebuild()))
		add_button(box, "В главное меню", func(): save_game(); screen = "menu"; close_modal())
	elif modal_kind == "receiving":
		build_receiving(box)
	elif modal_kind == "settings":
		build_settings(box)
	elif modal_kind == "help":
		add_label(box, "Как играть", 32)
		var fleet_speeds: PackedStringArray = []
		for id in Model.VEHICLE_IDS:
			fleet_speeds.append("%s — %d" % [model.vehicle_base(id).name, roundi(model.top_speed_kmh(id))])
		var speed_help = "Предельные скорости в км/ч. " + " · ".join(fleet_speeds) + "."
		add_label(box, "1. В депо выбери рейс и нажми «К погрузке». Перетащи каждый предмет с площадки в свободное место на машине или вагоне. Когда всё погружено, просто тронься: дай ход, и рейс начался (кнопка «Отправиться» тоже есть).\n\n2. Тормоз ставить на станции не нужно: остановился на платформе, и состав стоит сам, он отпустится, когда дашь ход. В пути тормоз красной рукоятью, веди её по дуге к 0%. На ручной дрезине веди любой конец деревянного рычага по его дуге. На спуске можно катиться по инерции.\n\n3. Перед станцией плавно переведи тормоз к 100%. Остановись в пределах платформы и перетащи нужные грузы на площадку. У каждого предмета указана станция.\n\n4. После последней доставки убери подачу, разверни пустой состав кнопкой на станции и вернись в Лесную. Деньги выдаются в домашнем депо.\n\n5. Карьера начинается с шестовой дрезины. Другие машины покупаются в гараже. Если на машине нет мест для груза, она получает первый вагон. Дополнительные вагоны покупаются отдельно. Свободные рейсы помогают накопить монеты. " + speed_help + " «Творческий режим» из меню: всё открыто, деньги и топливо без ограничений, любые рейсы.\n\n6. Паровоз: разожги котёл тумблером (режим Н, регулятор 0%), выбери отсечку 1 и открой регулятор. Он тратит уголь и воду. Бензиновая машина запускается так же и тратит бензин. Электровоз тратит заряд; ниже 75% заряда тяга слабеет, торможение возвращает часть энергии. Пополнение платное: в депо и на станции Дальний бор (там в полтора раза дороже), воду можно набрать ещё на Тихой заводи. Остановись у платформы, затяни тормоз и нажми «Заправить» в панели станции. Бака хватает примерно на один рейс туда и обратно: смотри строку «Рейс: нужно… есть…» в депо и на карте.\n\n7. Вагоны в депо стоят на пути. Щёлкни по сцепке между составом и вагоном: хвостовой вагон отъедет, ближайший стоящий подкатится и сцепится. Улучшения следуют за ID вагона. Для финального рейса нужны шесть мест.\n\nЗадний ход: остановись, затяни тормоз и выбери стрелку направления. На ручной дрезине направление задаётся усилием на рычаге с отпущенным тормозом. Обратное усилие сначала замедляет движение. В мёртвой точке потяни край платформы, чтобы подтолкнуть машину. Состав при этом сохраняет положение и груз.\n\nКолесо мыши — приблизить машину. Esc — пауза. Карта и кабина открываются клавишами из настроек (по умолчанию M и E). В кабине все органы и приборы машины; на станции кабина сама опускается, чтобы был виден груз, а когда тронешься, поднимается снова. При потере фокуса игра останавливается. Если застрял или кончилась энергия, вызови помощь депо из паузы.", 20)
		if model.state.get("fleet_by_id", {}).has("zeppelin"):
			add_label(box, "Цеппелин: газ даёт ход, ползунок «Шаг» надо менять по ходу (мелкий на старте, крупнее с разгоном, держи его у зелёной метки: в красной зоне мотор изнашивается, на тяжёлом винте глохнет). На 130 км/ч потяни «Ручку» до зелёной черты (+3,5°), и он взлетит. В воздухе винт слабее: скорость держи ручкой вниз. Садись плавно: газ меньше, ручку чуть на себя (около +3°), тогда касание мягкое. Рычаги держат положение, их не надо удерживать. Грубая посадка стоит половины монет.", 18, MUTED_INK)
		if screen != "menu":
			add_button(box, "Подсказки: " + ("вкл." if model.state.tutorial else "выкл."), func(): model.state.tutorial = not model.state.tutorial; save_game(); rebuild())
		add_button(box, "Понятно", close_modal)
	elif modal_kind == "result":
		var result = model.state.get("last_result", {})
		add_label(box, "Линия работает" if result.get("final", false) else "С возвращением", 38)
		add_label(box, "Линия работает. До Дальнего бора снова ходят поезда. А дома тебя ждёт следующий рейс." if result.get("final", false) else str(result.get("title", "Рейс окончен")), 25)
		var notes_text = "\n" + "\n".join(result.get("notes", [])) if not result.get("notes", []).is_empty() else ""
		add_label(box, "Оплата: %d монет%s\nВсего доставлено: %d предметов\nПройдено: %.1f км\nОсновные рейсы: %d / 10" % [result.get("reward", 0), notes_text, model.state.stats.deliveries, float(model.state.stats.distance) / 1000, model.state.chapter], 23)
		var finds: Array = result.get("finds", [])
		if not finds.is_empty():
			var parts: Array = []
			var total = 0
			for entry in finds:
				total += int(entry.count)
				parts.append("%s%s" % [str(entry.name).to_lower(), (" ×%d" % int(entry.count)) if int(entry.count) > 1 else ""])
			add_label(box, "Принесли с дороги: %d шт.\n%s" % [total, ", ".join(parts)], 20)
		if Model.wear_rules and not model.wear().journal.is_empty():
			add_label(box, "Что случилось в рейсе:\n%s" % "\n".join(model.wear().journal_lines()), 20)
		add_button(box, "Продолжить перевозки", close_modal, false, false, &"PrimaryAction")
		add_button(box, "В главное меню", func(): screen = "menu"; close_modal(), false, false, &"QuietAction")
	else:
		add_label(box, "Лесная колея", 36)
		add_label(box, "Небольшая игра о работе лесной железной дороги.\nРазработка: Codex совместно с владельцем проекта, 2026.\nГрафика: предоставленный комплект ForestRail, созданный с image_gen. Звуки синтезированы для этого комплекта.\nGodot Engine 4.7.2, лицензия MIT. Полные лицензии движка и его компонентов включены в поставку.\n\nВерсия игры %s · ТЗ 3.0 · проверка P8." % ProjectSettings.get_setting("application/config/version"), 22)
		add_button(box, "Назад", close_modal)
	var scroll := box.get_parent() as ScrollContainer
	var panel := scroll.get_parent() as PanelContainer
	var fit_panel := func():
		if not is_instance_valid(panel) or panel.get_parent() != overlay: return
		var padding = panel.get_theme_stylebox("panel").get_minimum_size().y
		panel.size.y = minf(size.y - 160, ceilf(box.get_combined_minimum_size().y + padding))
		panel.position.y = (size.y - panel.size.y) * 0.5
	box.minimum_size_changed.connect(fit_panel, CONNECT_DEFERRED)
	fit_panel.call_deferred()

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
	wp_valid = false
	time += dt
	whistle_pull = move_toward(whistle_pull, 0.0, dt * 3.0)
	if wiper_on or wiper_phase > 0.0:
		wiper_phase += dt * 0.75
		if wiper_phase >= 1.0:
			wiper_phase = fposmod(wiper_phase, 1.0) if wiper_on else 0.0
	var electric_powered = screen == "game" and not model.state.is_empty() and model.vehicle_id() == "locomotive" and bool(model.state.engine)
	if electric_powered and not electric_was_powered and not paused:
		electric_start_flash = ELECTRIC_START_FLASH
		sound.play("contactor", 0.4)
	else:
		electric_start_flash = move_toward(electric_start_flash, 0.0, dt)
	if not paused or not electric_powered:
		electric_was_powered = electric_powered
	model.weather_effect = [1.0, 0.5, 0.0][clampi(int(settings.weather), 0, 2)]
	Model.wear_rules = not test_mode or live_in_tests   # wear and damage of the nodes (B5.6)
	Model.junk_rules = not test_mode or junk_in_tests   # bolts from the road (B6.11 b)
	Model.live_effects = not test_mode or live_in_tests   # the live train: couplers, rocking, shifting cargo (B5); the tests keep the rigid numbers
	Model.order_rules = not test_mode   # deadlines and bonuses of the orders only in the real game (tests keep the old numbers)
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
		# 1.3.9: the camera moves with the train (it knows the speed), so the machine no longer slides to the edge of
		# the screen while it speeds up and back when it brakes; at speed it looks a little ahead to show more road.
		var follow_v = 0.0
		if screen == "game" and camera_target_last != INF and absf(target_s - camera_target_last) < 5.0 and dt > 0.0:
			follow_v = clampf((target_s - camera_target_last) / dt, -60.0, 60.0)
		camera_target_last = target_s if screen == "game" else INF
		if drag in ["","pump","brake","throttle","gear","start","coal","sail","pole","zpult","oars"]:
			if screen == "game":
				var max_lag = get_viewport_rect().size.x * 0.17 / (ArtV3.PX * view_scale())
				var lead = signf(follow_v) * minf(absf(follow_v) * 0.12, max_lag * 0.6)
				camera_s += follow_v * dt
				camera_s = lerpf(camera_s, target_s + lead, 1 - exp(-dt * 3))
				# a soft limit instead of a hard wall, so that zoom and speed cannot carry the engine out of frame
				var off = camera_s - target_s
				if absf(off) > max_lag: camera_s = target_s + signf(off) * (max_lag + (absf(off) - max_lag) * exp(-dt * 20))
			else:
				camera_s = lerpf(camera_s, target_s, 1 - exp(-dt * 6))
			camera_y = lerpf(camera_y, model.route.sample(camera_s).y + camera_climb(), 1 - exp(-dt * 4))
		var ahead_x = 0.3 if model.grapnel_installed() else 0.65   # with the grapnel the truck stands far back so that the posts ahead are in the frame
		var target_x = get_viewport_rect().size.x * (0.31 if screen == "depot" else (ahead_x if model.state.direction > 0 else 1.0 - ahead_x))
		if screen == "depot" and not model.state.consist_ids.is_empty(): target_x = get_viewport_rect().size.x * 0.46 - 136
		if drag in ["","pump","brake","throttle","gear","start","coal","sail","pole","zpult","oars"]: camera_x = lerpf(camera_x if camera_x > 0 else target_x, target_x, 1 - exp(-dt * 3))
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
	# B6.1: the pole truck: the tip of the pole knocks differently on every kind of ground
	while not model.pole.events.is_empty():
		var knock = model.pole.events.pop_front()
		var ground = str(knock.get("ground", "dense"))
		var kind = str(knock.get("kind", ""))
		if kind == "plant": sound.play("pole_plant_" + ground, 0.85, randf_range(0.94, 1.06))
		elif kind == "skid": sound.play("pole_plant_stones", 0.6, randf_range(1.25, 1.45))
		elif kind == "lift": sound.play("pole_lift", 0.6, 0.9 if ground == "clay" else randf_range(0.98, 1.08))
		elif kind == "slide": sound.play("pole_plant_" + ground, 0.35, randf_range(0.7, 0.8))
	while not model.events.is_empty():
		var event_name = str(model.events.pop_front())
		if event_name == "land":
			# The train comes down on the rail: a thud scaled by the hit, and the cab shakes.
			land_dust = {"t": 0.0, "s": float(model.state.s), "power": clampf(0.45 + float(model.last_landing) / 4.0, 0.5, 1.0)}
			sound.play("land_thud", clampf(0.35 + float(model.last_landing) * 0.18, 0.35, 1.0), clampf(1.15 - float(model.last_landing) * 0.08, 0.8, 1.15))
			sound.play("cargo", clampf(0.15 + float(model.last_landing) * 0.1, 0.15, 0.6), 0.7)
			cab_jolt = 1.0
		elif event_name == "record":
			notify(model.last_record_text)
			sound.play("coins", 0.5, 1.3)
		elif event_name == "jet_countdown":
			notify("Отсчёт пошёл: десять секунд")
		elif event_name == "jet_abort":
			notify("Отсчёт сброшен: тронули предохранитель")
		elif event_name == "jet_ignition":
			notify("Зажигание! Мощность рычагом")
			sound.play("jet_ignite", 0.9)
			cab_jolt = 1.0
		elif event_name == "jet_misfire":
			notify("Осечка: двигатель не зажёгся. Пуск ещё раз")
			sound.play("petrol_stall", 0.6)
		elif event_name == "jet_chute":
			sound.play("sail_flap", 0.8, 0.7)
		elif event_name == "jet_chute_cut":
			notify("Состав встал, парашют обрезан")
		elif event_name == "jet_overheat":
			notify("Двигатель перегрет и встал")
		elif event_name == "zep_takeoff":
			sound.play("horn", 0.5, 1.25)
			notify("Взлёт! Держи ручку и следи за скоростью")
		elif event_name == "zep_land":
			land_dust = {"t": 0.0, "s": float(model.state.s), "power": 0.8}
			sound.play("land_thud", 0.7, 1.0)
			cab_jolt = 1.0
		elif event_name == "zep_stall":
			sound.play("petrol_stall", 0.6)
			notify("Мотор заглох: газ в ноль и «Пуск»")
		elif event_name == "zep_overheat":
			notify("Мотор перегрет и встал: дай ему остыть")
		elif event_name == "crash":
			sound.play("zep_crash", 0.9)
			cab_jolt = 1.0
		elif event_name == "clank":
			# B5.2: a coupler takes up the slack with a knock, harder when the jerk is
			sound.play("coupler_clank", clampf(0.25 + float(model.last_clank) * 0.5, 0.25, 0.9), randf_range(0.92, 1.08))
			cab_jolt = maxf(cab_jolt, clampf(float(model.last_clank), 0.0, 0.6))
		elif event_name == "glint":
			sound.play("coins", 0.4, 1.7)
		elif event_name == "burst":
			cab_jolt = maxf(cab_jolt, 0.4)
		elif event_name == "grapnel_throw":
			sound.play("sail_flap", 0.5, 1.5)
		elif event_name == "grapnel_hook":
			sound.play("coupler_clank", 0.6, 1.2)
			notify("Крюк зацепился: %s. Лебёдка тянет" % str(model.grapnel.status_text()).trim_prefix("Трос на опоре: "))
		elif event_name == "grapnel_miss":
			sound.play("cargo", 0.35, 0.8)
			notify("Мимо: крюк упал. Бросай с другого места")
		elif event_name == "grapnel_tear":
			sound.play("coupler_clank", 0.8, 0.6)
			notify("Опора не удержала: крюк сорвался")
		elif event_name == "grapnel_reached":
			notify("Дрезина у опоры: крюк снят")
		elif event_name == "wear_warn":
			sound.play("coupler_clank", 0.35, 0.7)
		elif event_name == "breakdown":
			sound.play("petrol_stall", 0.7)
			cab_jolt = 1.0
		elif event_name == "skid":
			notify("Тормоз перетянут. Колёса проскальзывают")
			sound.play("brake", 0.5, 1.3)
		elif event_name == "cargo_hit":
			sound.play("cargo", clampf(0.3 + float(model.last_cargo_hit) * 0.4, 0.3, 0.9), randf_range(0.85, 1.0))
		else: sound.play(event_name, 0.6)
	if not land_dust.is_empty(): land_dust.t = float(land_dust.t) + dt
	sound.update(model, paused, screen == "menu", dt, cab_active())
	var view_started = Time.get_ticks_usec() if perf_on else 0
	if art_world != null: art_world.update_view()
	if perf_on: perf_add("update_view", view_started)
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
		var physics_started = Time.get_ticks_usec() if perf_on else 0
		model.physics_step(dt)
		if perf_on: perf_add("physics", physics_started)
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
	if key_is(event,"sail_side") and event.pressed and not event.echo and screen=="game" and not paused and model.vehicle_id()=="sail" and model.state.phase=="route":
		model.sail_set_side(-model.sail_side)
		notify("Парус на дальний борт" if model.sail_side > 0 else "Парус на ближний борт")
		get_viewport().set_input_as_handled()
		return
	if key_is(event,"ice") and event.pressed and not event.echo and screen=="game" and not paused and model.vehicle_id()=="pneumatic":
		chip_all_ice()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and key_is(event,"burst") and screen=="game" and not paused and model.burst_gadget() != "":
		try_burst()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and key_is(event,"grapnel") and screen=="game" and not paused and model.grapnel_installed():
		try_grapnel()
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1 and modal_kind == "" and not test_mode:
		show_modal("help")   # the help is also at hand without the menu
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
		if drag == "oars":
			model.oars_hand(-event.relative.x * float(int(model.state.direction)) * 0.004 * float(settings.sensitivity))
			get_viewport().set_input_as_handled()
			return
		if drag == "zpult":
			own_pult().motion(event.position)
			get_viewport().set_input_as_handled()
			return
		if drag == "sail":
			# relative motion in the machine's own frame, so that the car running away from the camera
			# does not drag the sail with it (the same lesson as with the brake lever)
			var outer_sail = body_transform(model.vehicle_id(), model.body_s_render(0))
			var moved = outer_sail.affine_inverse().basis_xform(event.relative * float(settings.sensitivity)).x / ArtV3.PX * float(int(model.state.direction))
			if not is_finite(moved): moved = 0.0
			sail_hold = clampf(sail_hold - moved, 0.0, ArtV3.SAIL_BOOM)
			# the free corner goes wherever the hand goes, up and down as well: held high it twists the cloth
			var moved_y = outer_sail.affine_inverse().basis_xform(event.relative * float(settings.sensitivity)).y / ArtV3.PX
			if not is_finite(moved_y): moved_y = 0.0
			model.set_sail_lift(model.sail_lift - moved_y)
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
					if model.auto_gearbox():
						gate_pos=Vector2(1.0,clampf(gate_pos.y+local_move.y/(gate.size.y*0.38),-1.0,1.0))
						lever_pending_gear=selector_gear_of(gate_pos.y)
					else:
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
					wheel_acc=clampf(wheel_acc+wrapf(now-wheel_last,-PI,PI),0.0,wheel_sweep())
					wheel_last=now
					var spin=wheel_acc/wheel_sweep()
					if spin<0.001: spin=0.0
					elif spin>0.999: spin=1.0
					if drag=="gear":
						if model.vehicle_id()=="pneumatic": model.set_reducer(spin)
						else: model.set_feed(spin)
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
			zoom_level = clampf(zoom_level + (0.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1), 0.5, 1.5)
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and screen == "game" and not cab_active() and model.grapnel_installed() and model.state.phase == "route":
			aim_grapnel(event.position)   # the grapnel: the right button throws at the cursor, and lets go when the hook is on
			get_viewport().set_input_as_handled()
			return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		var mouse = event.position
		if screen == "depot":
			var spot = nearest_workshop_spot(mouse)
			if not spot.is_empty():
				workshop_branch = str(spot.branch)
				tab = "Улучшения"
				sound.play("ui_click", 0.5)
				rebuild()
				return
			for hit in coupler_hits:
				if hit.position.distance_to(mouse) < 22: start_shunting(hit.id, hit.attach); return
			for hit in body_hits:
				if hit.rect.has_point(mouse): selected_object = hit.id; tab = "Улучшения"; rebuild(); return
			return
		if cab_active() and has_own_pult():
			var pult = own_pult()
			pult.model = model
			if pult.press(mouse):
				drag = "zpult"
				get_viewport().set_input_as_handled()
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
			for hit in valve_hits:
				if mouse.distance_to(hit.position) < 0.07 * ArtV3.PX * view_scale() + 6.0:
					cab_button("drain%d" % int(hit.spot))
					get_viewport().set_input_as_handled()
					return
			for hit in ice_hits:
				if mouse.distance_to(hit.position) < ice_radius and model.chip_ice(int(hit.spot)):
					notify("Иней сбит: %d%%" % roundi(model.frost() * 100.0))
					get_viewport().set_input_as_handled()
					return
		if not in_closeup:
			for hit in glint_hits:
				if mouse.distance_to(hit.position) < 24.0 * view_scale() + 8.0:
					model.casino().pick_glint(int(hit.index))
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
			lever_pending_gear=model.selector_gear()
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
		if model.vehicle_id() == "sail" and model.state.phase == "route" and not in_closeup and not paused and model.oars_out():
			drag = "oars"   # the oars: the hand pulls the mouse toward the stern, stroke after stroke
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			get_viewport().set_input_as_handled()
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
				return
		# a click on an empty place of the machine (no lever, no cargo, no pole under the mouse) enters the cab
		if screen == "game" and not cab_active() and not paused and not model.human_powered() and model.state.phase in ["route", "loading"]:
			for hit in body_hits:
				if hit.id == model.vehicle_id() and hit.rect.has_point(mouse):
					toggle_cab_view()
					get_viewport().set_input_as_handled()
					return

# The mouse place along the track in the pole truck's own frame: metres forward of the
# platform centre in the direction of travel.
func pole_mouse_rel(mouse: Vector2) -> float:
	var outer = body_transform(model.vehicle_id(), model.body_s_render(0))
	return (outer.affine_inverse() * mouse).x / ArtV3.PX * float(int(model.state.direction))

func finish_drag(mouse: Vector2) -> void:
	if drag == "zpult":
		zpult.release()
		jpult.release()
	elif drag == "cargo":
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
	elif drag == "gear" and lever_pending_gear!=model.selector_gear():
		if not model.set_gear(lever_pending_gear): notify(model.message)
	elif drag == "start" and lever_travel<8 and mouse.distance_to(lever_click_origin)<8:
		if model.vehicle_id()=="pneumatic":
			model.set_heating(not model.heating_on())
			notify("Обогрев трубок включён: иней растёт медленнее, воздуха уходит больше" if model.heating_on() else "Обогрев выключен")
		elif not model.start_engine(not model.state.engine): notify(model.message)
	cancel_drag()

func lights_lit() -> bool:
	if lamp_manual >= 0: return lamp_manual == 1
	return model.night_amount() > 0.3 or float(model.weather().fog) * model.weather_effect > 0.5

func light_flicker_enabled() -> bool:
	return bool(settings.light_flicker) and not settings.reduce_motion

# The weather as the player's settings show it: normal, weaker, or none.
func shown_weather() -> Dictionary:
	var w = model.weather()
	match int(settings.weather):
		1: return {"cloud": float(w.cloud) * 0.7, "rain": float(w.rain) * 0.4, "fog": float(w.fog) * 0.4}
		2: return {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	return w

# Darkness of the night over the glass and the world; the setting makes it lighter.
func night_shade() -> float:
	return 0.62 * model.night_amount() * (1.0 - 0.5 * float(settings.night_light))

# The time left to the deadline of the order on the road, for the header ("" when there is none).
func deadline_text() -> String:
	var left = model.deadline_left()
	if left > 1.0e8: return ""
	if left < 0.0: return " · СРОК ВЫШЕЛ"
	return " · срок %d:%02d" % [int(left / 60.0), int(fposmod(left, 60.0))]

# The zeppelin climbs high (the ceiling is 30 m): the camera climbs after it, so that the machine stays on the screen and the ground falls away.
func camera_climb() -> float:
	if screen != "game" or model.vehicle_id() != "zeppelin" or not model.air_fly: return 0.0
	return maxf(0.0, float(model.air_z) - 4.0)

# The part of world_point that does not depend on the point (the camera spot, the head x, the scale, the rail line) is the same for the ~350 calls
# of a frame: it is counted once per frame and again as soon as one of its inputs changes. The cache is dropped at the start of every frame.
var wp_valid = false
var wp_route = null
var wp_key = Vector4.ZERO      # camera_s, camera_x, camera_y, zoom_level
var wp_size = Vector2.ZERO
var wp_screen = ""
var wp_tab = ""
var wp_cam = Vector2.ZERO
var wp_head = 0.0
var wp_scale = 1.0
var wp_base = 0.0

func world_point(s: float) -> Vector2:
	var size = get_viewport_rect().size
	var key = Vector4(camera_s, camera_x, camera_y, zoom_level)
	if not wp_valid or wp_route != model.route or wp_key != key or wp_size != size or wp_screen != screen or wp_tab != tab:
		wp_valid = true
		wp_route = model.route
		wp_key = key
		wp_size = size
		wp_screen = screen
		wp_tab = tab
		wp_cam = model.route.sample(camera_s)
		wp_head = camera_x if camera_x > 0 else size.x * (0.31 if screen == "depot" else 0.65)
		wp_scale = ArtV3.PX * view_scale()
		wp_base = rail_baseline()
	var p = model.route.sample(s)
	return Vector2(wp_head + (p.x - wp_cam.x) * wp_scale, wp_base - (p.y - camera_y) * wp_scale)

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
	var key=selected_cargo+str(available)+str(item.is_empty())+str(offer.get("station",""))+str(model.refill_cost())+str(roundi(float(model.state.money)))+str(model.casino().bolt_total())
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
		var room=model.tank_missing()>0.0001
		if model.fuel_service_mult(offer.services)>=0.0: label=({"locomotive":"Зарядить","pneumatic":"Накачать"}.get(model.vehicle_id(),"Заправить"))+(" · %d монет" % cost if cost>0 else (" · бесплатно" if room else " · полон"))
		if water_short: label+=(" + " if label!="" else "")+"вода"
		if label!="":
			var service_button=add_button(cargo_actions,label,use_station_service,not room and not water_short)
			service_button.add_theme_font_size_override("font_size",int(18*float(settings.text_scale)))
	if interaction.can_transfer and model.casino().receiving_possible() and model.casino().bolt_total() > 0:
		var desk_button=add_button(cargo_actions,"Приёмка болтов (%d)" % model.casino().bolt_total(),use_station_receiving_button)
		desk_button.add_theme_font_size_override("font_size",int(18*float(settings.text_scale)))

func use_station_receiving_button() -> void:
	show_modal("receiving")

func use_station_service() -> void:
	if model.refuel():
		save_game()
		cargo_action_key=""
		notify(model.message if model.message!="" else "Запас пополнен")
		model.message=""
		update_hud()
	else: notify(model.message)

# One line for the depot panel and the map: what the next trip needs against what is on board.
# B6.4: the steady wind of the line at the stations (without gusts), for the sail car in the depot: where the ride will be easy
func wind_route_line() -> String:
	model.wind_ready()
	var parts: Array = []
	for i in range(model.data.stations.size()):
		parts.append("%s %.1f" % [str(model.data.stations[i].name), model.wind.strength_at(float(model.route.station_s[i]))])
	return "Ветер по линии, м/с: " + " · ".join(parts)

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
	# the tabs where the whole train does not have to be reachable (the garage, the trips, the casino) show the machine and the first wagon big, the rest of the train goes off to the left
	var span = depot_span_m()
	if tab not in ["Улучшения", "Состав"]:
		span = minf(model.train_length(), Geometry.length(model.vehicle_id()) + 1.3 * Geometry.length("W01"))   # the parked wagons wait off to the left
	# the tall rigs (the lever of the handcar, the pole, the mast) would run into the text panel at the top: they stay smaller
	var tall_cap = {"handcar": 1.05, "pole": 0.94, "sail": 0.94}.get(model.vehicle_id(), 1.5)
	return minf(1.9 if tab == "Улучшения" else float(tall_cap), (get_viewport_rect().size.x * 0.46 - 150) / (ArtV3.PX * span))

func _draw() -> void:
	var draw_started = Time.get_ticks_usec() if perf_on else 0
	_draw_scene()
	if perf_on: perf_add("draw", draw_started)

func _draw_scene() -> void:
	wp_valid = false
	if art == null: return
	var size = get_viewport_rect().size
	if art_world == null: draw_background(size)
	grip_hits.clear()
	ice_hits.clear()
	valve_hits.clear()
	glint_hits.clear()
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
			draw_toast_box(Rect2(size.x * 0.5 - 420, 66, 840, 44), false)
		return
	if screen == "menu":
		var scrim = Color(0.03, 0.08, 0.06, 0.9)
		draw_rect(Rect2(0, 0, size.x * 0.22, size.y), scrim)
		ArtWorld.horizontal_gradient(self, Rect2(size.x * 0.22, 0, size.x * 0.4, size.y), scrim, Color(scrim, 0.0))

		draw_menu_train(size)
	else:
		if screen == "depot": draw_depot_interior(size)
		draw_train()
		if screen == "depot" and not clean_frame:
			draw_style_box(style(Color(0.08,0.15,0.12,0.88),Color(0.5,0.57,0.39,0.45),8),Rect2(22,12,size.x-44,depot_header_bottom-12))
			draw_style_box(style(Color(0.08,0.15,0.12,0.88),Color(0.5,0.57,0.39,0.45),8),depot_info_rect)
		if screen == "game" and not clean_frame:
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
		if screen == "depot":
			# above the hint line and the service buttons, inside the left column (the right panel covers the rest)
			rect = Rect2(size.x * 0.02, size.y - 215, size.x * 0.44, 44)
		draw_toast_box(rect, screen != "game")

# The notice: a long text wraps to up to three lines instead of being cut at the edge of the box (it was cut in the narrow depot column).
# A box that stands low on the screen grows upward, so that it does not cover the buttons under it.
func draw_toast_box(rect: Rect2, grow_up: bool) -> void:
	var width = rect.size.x - 30
	var text_h = font.get_multiline_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, width, 19, 3).y
	var extra = maxf(0.0, text_h + 20.0 - rect.size.y)
	rect.size.y += extra
	if grow_up: rect.position.y -= extra
	draw_style_box(style(INK, GOLD, 8), rect)
	draw_multiline_string(font, rect.position + Vector2(18, 29), toast, HORIZONTAL_ALIGNMENT_LEFT, width, 19, 3, PAPER)

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
	var strength = 0.5 + 0.7 * float(model.state.throttle)
	if model.vehicle_id() == "jet": strength = 0.3 + 3.2 * clampf(float(model.jet.thrust) / 12000.0, 0.0, 1.0)   # the rocket shakes the cab by its thrust
	var tremble = Vector2(sin(time * 61.0), sin(time * 53.0 + 1.3)) * (strength if vibrating else 0.0)
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

const CAB_FOG = Color("cfe0dc")
func cab_fog(color: Color, z: float) -> Color:
	return color.lerp(CAB_FOG, clampf(z / 170.0, 0.0, 0.85))

var cab_art_cache = null
func cab_art():
	if cab_art_cache == null: cab_art_cache = CabArt.new(self)
	return cab_art_cache

func draw_cab_scene(size: Vector2) -> void:
	cab_art().draw_cab_scene(size)


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

# B6.11 b: a glint of brass by the rail: a bolt lies in the gravel. It twinkles when the train is near; a click picks it up.
func draw_glints() -> void:
	if model.state.phase != "route" or not model.casino().has_trip(): return
	var sc = view_scale()
	var list = model.casino().glints()
	for i in range(list.size()):
		var g = list[i]
		if bool(g.taken): continue
		var p = world_point(float(g.s))
		if p.x < -60 or p.x > get_viewport_rect().size.x + 60: continue
		p += Vector2(0, 17 * sc)
		var gold = bool(g.golden)
		var pulse = 0.55 + 0.45 * sin(time * 5.0 + float(i) * 2.1)
		if settings.reduce_motion: pulse = 0.85
		var tint = Color(1.0, 0.82, 0.3) if gold else Color(0.95, 0.78, 0.45)
		ellipse(p, Vector2(16, 6) * sc, Color(tint.r, tint.g, tint.b, 0.3 * pulse))
		var arm = (12.0 + 8.0 * pulse) * sc * (1.4 if gold else 1.0)
		draw_line(p + Vector2(-arm, 0), p + Vector2(arm, 0), Color(tint.r, tint.g, tint.b, 0.9 * pulse), 2.0 * sc, true)
		draw_line(p + Vector2(0, -arm), p + Vector2(0, arm), Color(tint.r, tint.g, tint.b, 0.9 * pulse), 2.0 * sc, true)
		draw_circle(p, 2.6 * sc, Color(1, 0.97, 0.8, pulse))
		glint_hits.append({"index": i, "position": p})

# B5.5: a landing kicks up the dust of the track bed: a few soft puffs that spread and fade.
func draw_land_dust() -> void:
	if land_dust.is_empty(): return
	var age = float(land_dust.t)
	if age > 0.8:
		land_dust = {}
		return
	var sc = view_scale()
	var power = float(land_dust.power)
	for k in range(7):
		var side = (float(k) - 3.0) / 3.0
		var spread = (0.4 + age * 3.2) * power
		var p = world_point(float(land_dust.s) + side * (1.5 + age * 3.5) * power) + Vector2(0, 6 * sc)
		var radius = (16.0 + 34.0 * age) * sc * power * (0.7 + 0.3 * absf(sin(float(k) * 2.1)))
		ellipse(p + Vector2(0, -age * 26.0 * sc * (0.5 + 0.5 * absf(side))), Vector2(radius * (1.0 + spread * 0.2), radius * 0.6), Color(0.66, 0.58, 0.45, 0.5 * (1.0 - age / 0.8)))

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

var train_art_cache = null
func train_art():
	if train_art_cache == null: train_art_cache = TrainArt.new(self)
	return train_art_cache

func draw_train() -> void:
	train_art().draw_train()

func parked_wagons() -> Array:
	return train_art().parked_wagons()

func parked_s(index: int) -> float:
	return train_art().parked_s(index)

func depot_span_m() -> float:
	return train_art().depot_span_m()

func body_transform(id: String, s: float, swaying: bool = true) -> Transform2D:
	return train_art().body_transform(id, s, swaying)

func wheel_rotation(distance: float, facing: int) -> float:
	return train_art().wheel_rotation(distance, facing)

func find_slot_cargo(key: String) -> Dictionary:
	return train_art().find_slot_cargo(key)

func cargo_layout(id: String) -> Array[Rect2]:
	return train_art().cargo_layout(id)

func draw_loading_dock(size: Vector2) -> void:
	train_art().draw_loading_dock(size)

func draw_cargo_feedback() -> void:
	train_art().draw_cargo_feedback()


# What kind of mouse control a pult element is: an arc lever, a rotary hand
# wheel (steam regulator and water tap), an H-gate (petrol gearbox) or a toggle.
func control_kind(id: String) -> String:
	# The electric locomotive has aircraft-style handles: vertical sliders in slots.
	if model.vehicle_id() == "locomotive" and id in ["brake", "throttle"]: return "slider"
	if model.vehicle_id() == "steam" and id in ["throttle", "gear"]: return "wheel"
	if model.vehicle_id() == "pneumatic" and id == "gear": return "wheel"   # the reducer: a hand wheel, turn it round like the valve of the steam locomotive
	if model.vehicle_id() == "motorcar" and id == "gear": return "gate"
	return "toggle" if id == "start" else "lever"

func gate_rect(closeup: bool) -> Rect2:
	if closeup: return Rect2(control_zoom_rect().position + Vector2(222, 126), Vector2(86, 112))
	return Rect2(Vector2(-1.20, -1.58) * ArtV3.PX, Vector2(0.36, 0.38) * ArtV3.PX)

func gate_local(rect: Rect2, g: Vector2) -> Vector2:
	return ControlArt.gate_local(rect, g)

var control_art_cache = null
# The frame counters of the performance check (check_perf_budget): off in the game, the test turns it on; the samples are microseconds.
var perf_on = false
var perf_samples = {}

func perf_add(counter: String, started_usec: int) -> void:
	if not perf_samples.has(counter): perf_samples[counter] = []
	perf_samples[counter].append(Time.get_ticks_usec() - started_usec)

var skid_active = false   # the wheels are locked: the angle they stopped at
var skid_s = 0.0
func control_art():
	if control_art_cache == null: control_art_cache = ControlArt.new(self)
	return control_art_cache

func gate_slot_pos(gear: int) -> Vector2:
	if model.auto_gearbox(): return Vector2(1, -1.0 if gear >= 1 and gear <= 5 else (1.0 if gear == 6 else 0.0))   # the selector: D up, N in the middle, R down
	return GATE_SLOTS.get(gear, Vector2(1, 0))

# The selector of the automatic gearbox: one slot, D on top, N in the middle, R at the bottom.
func selector_gear_of(y: float) -> int:
	if y <= -0.5: return 1
	if y >= 0.5: return 6
	return 0

func draw_selector(rect: Rect2, knob: Vector2, active: bool) -> void:
	control_art().draw_selector(rect, knob, active)

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
	control_art().draw_gate(rect, knob, active)

func draw_handwheel(center: Vector2, radius: float, angle: float, color: Color, active: bool) -> void:
	control_art().draw_handwheel(center, radius, angle, color, active)

func draw_slider(base: Transform2D, pivot: Vector2, length: float, value: float, color: Color, active: bool) -> void:
	control_art().draw_slider(base, pivot, length, value, color, active)

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
		elif not art.is_skinned("locomotive"):
			# The factory cab has two clear panels between the window and steps.
			slot_pivot = art.stock_body_point("locomotive", Vector2(200 if id == "brake" else 310, 562))
			slot_length = 0.32 * ArtV3.PX
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
		var turn=((model.reducer_position() if model.vehicle_id()=="pneumatic" else float(model.boiler().feed)) if id=="gear" else float(model.state.throttle))*wheel_sweep()
		return {"pivot":center,"grip":center+Vector2(0,-radius).rotated(turn),"angle":turn,"radius":radius}
	var pivot=control_anchor(id)*ArtV3.PX
	var length_key = id + "_length_m"
	var body_spec = Geometry.body(model.vehicle_id())
	var length = float(body_spec.get(length_key, Geometry.data().controls[length_key])) * ArtV3.PX
	if closeup:
		pivot=control_zoom_rect().position+Vector2(65+100*["brake","throttle","gear","start"].find(id),225)
		length=42.0 if id=="start" else 78.0
	var value=float(model.state.get(id,0))
	if id=="gear": value=float(model.boiler().feed) if model.vehicle_id()=="steam" else float(GEAR_ORDER.find(lever_pending_gear if drag=="gear" else int(model.state.gear)))/6.0
	var angle=lerpf(-0.55,0.55,value)
	if id=="start": angle=0.0 if (model.heating_on() if model.vehicle_id()=="pneumatic" else model.state.engine) else PI
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
			if model.auto_gearbox(): draw_selector(gate_rect(false), gate_pos if drag == "gear" else gate_slot_pos(int(model.state.gear)), drag == id)
			else: draw_gate(gate_rect(false), gate_pos if drag == "gear" else gate_slot_pos(int(model.state.gear)), drag == id)
		elif kind == "wheel":
			draw_handwheel(geo.pivot, float(geo.radius), angle, GOLD if id == "gear" else GREEN, drag == id)
		elif kind == "slider":
			draw_slider(body_transform, geo.pivot, float(geo.length), float(model.state.get(id, 0)), Color("c23b2e") if id == "brake" else Color("4f9a5f"), drag == id)
			if id == "brake": draw_brake_safe_mark(geo, true)
		elif id in ["brake","throttle"]:
			draw_arc(geo.pivot,geo.pivot.distance_to(geo.grip),-PI/2-0.55,-PI/2+0.55,24,Color("918363"),1.0,true)
			if id == "brake": draw_brake_safe_mark(geo, false)
			draw_lever(body_transform,geo.pivot,geo.pivot.distance_to(geo.grip),angle,Color("c23b2e") if id=="brake" else Color("4f9a5f"),drag==id)
		else:
			if id not in ["pump","start"]:
				draw_arc(geo.pivot,geo.pivot.distance_to(geo.grip),-PI/2-0.55,-PI/2+0.55,24,Color("918363"),1.0,true)
			if id == "start": angle = 0.0 if (model.heating_on() if model.vehicle_id() == "pneumatic" else model.state.engine) else PI
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

# 1.4.1: the green mark on the brake: the strongest braking that does not lock the wheels (Model.brake_safe, it moves by
# itself with the load, the rain and the wear); past it the way of the lever is red. Without a skid risk there is no mark.
func draw_brake_safe_mark(geo: Dictionary, slider: bool) -> void:
	var safe = model.brake_safe()
	if safe >= 0.999: return
	var safe_green = Color("5cc17f")
	var danger = Color(0.86, 0.25, 0.18, 0.75)
	if slider:
		var length = float(geo.length)
		var at = geo.pivot + Vector2(0, -length * safe)
		draw_line(at, geo.pivot + Vector2(0, -length), danger, 3.0, true)
		draw_line(at + Vector2(-9, 0), at + Vector2(9, 0), safe_green, 3.0, true)
		return
	var radius = geo.pivot.distance_to(geo.grip)
	var angle = lerpf(-0.55, 0.55, safe)
	draw_arc(geo.pivot, radius, -PI / 2 + angle, -PI / 2 + 0.55, 16, danger, 2.5, true)
	var dir = Vector2(0, -1).rotated(angle)
	draw_line(geo.pivot + dir * (radius - 7.0), geo.pivot + dir * (radius + 7.0), safe_green, 3.0, true)

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
				valve_hits.append({"spot": i, "position": transform * (art.steam_point(ArtV3.FROST_SPOTS[i].x, ArtV3.FROST_SPOTS[i].y) + Vector2(0, ArtV3.VALVE_DROP * ArtV3.PX))})
	var boxes = cargo_layout(id)
	for i in range(boxes.size()):
		var key = id + ":" + str(i)
		var rect = (transform * boxes[i]).grow(5)
		slot_hits.append({"key": key, "rect": rect})
		var item = find_slot_cargo(key)
		if not item.is_empty(): cargo_hits.append({"id": item.id, "rect": cargo_visuals.get(item.id, rect)})

# Short battery strip on the locomotive body (TZ 3.1, N6): readable at any
# zoom, colour only, exact numbers on hover.
func draw_charge_strip(body_transform: Transform2D) -> void:
	var fraction=charge_fraction()
	draw_set_transform_matrix(body_transform)
	var anchor = Vector2(0.70 * ArtV3.PX, art.deck_y("locomotive") - 0.37 * ArtV3.PX)
	if not art.is_skinned("locomotive"):
		anchor = art.stock_body_point("locomotive", Vector2(803, 586))
	var rect = Rect2(anchor - Vector2(20, 3), Vector2(40, 6))
	draw_style_box(style(Color("242b24"), Color("897658"), 2), rect.grow(3))
	if fraction > 0: draw_rect(Rect2(rect.position, Vector2(rect.size.x * fraction, rect.size.y)), charge_color(fraction))
	charge_strip_rect = (body_transform * rect).grow(10)

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
