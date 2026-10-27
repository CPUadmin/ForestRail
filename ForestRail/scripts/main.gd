extends Node2D

const Model = preload("res://scripts/model.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const Sound = preload("res://scripts/sound.gd")
const ArtV3 = preload("res://scripts/art_v3.gd")
const ArtWorld = preload("res://scripts/art_world.gd")
const PAPER = Color("f5ecd6")
const INK = Color("29383b")
const GREEN = Color("466c51")
const GOLD = Color("bb964f")
const RED = Color("a64d3b")
var model = Model.new()
var saves = SaveGame.new()
var sound
var textures: Dictionary = {}
var art
var art_world
var visual_layout: Dictionary = {}
var font: Font
var ui: Control
var overlay: Control
var hud: Label
var hint_label: Label
var action_bar: HBoxContainer
var screen = "menu"
var tab = "Рейсы"
var selected_object = "handcar"
var paused = false
var modal_kind = ""
var settings = {"master": 0.65, "mechanisms": 0.7, "forest": 0.6, "music": 0.25, "sensitivity": 1.0, "text_scale": 1.0, "fullscreen": false}
var camera_s = 0.0
var camera_y = 0.0
var camera_x = 0.0
var zoom_level = 1.0
var drag = ""
var drag_item = ""
var drag_total = 0.0
var drag_horizontal = 0.0
var drag_initial = 0.0
var grip_hits: Array = []
var slot_hits: Array = []
var cargo_hits: Array = []
var body_hits: Array = []
var toast = ""
var toast_seconds = 0.0
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
	font = ThemeDB.fallback_font
	var edge_shader = Shader.new()
	edge_shader.code = "shader_type canvas_item; void fragment() { vec4 t = texture(TEXTURE, UV); if(t.r > 0.8 && t.g < 0.19 && t.b < 0.2) { COLOR.a = 0.0; } }"
	var edge_material = ShaderMaterial.new()
	edge_material.shader = edge_shader
	material = edge_material
	var qa_args = OS.get_cmdline_user_args()
	if not get_tree().root.has_meta("qa_running"):
		for arg in qa_args:
			if arg.begins_with("--qa-suite="):
				var suite = arg.trim_prefix("--qa-suite=")
				if suite not in ["check_model", "check_physics", "check_interaction", "drive_campaign", "check_presentation", "check_handcar_revision", "check_art_v3"]: get_tree().quit(2); return
				get_tree().root.set_meta("qa_running", true)
				set_process(false)
				set_physics_process(false)
				set_process_input(false)
				set_process_unhandled_input(false)
				get_tree().root.add_child.call_deferred(load("res://tests/" + suite + ".gd").new())
				return
	get_tree().auto_accept_quit = false
	load_textures()
	art = ArtV3.new()
	edge_material.shader = load(ArtV3.ROOT + "materials/edge_clean.gdshader")
	art_world = ArtWorld.new()
	art_world.game = self
	art_world.art = art
	add_child(art_world)
	load_settings()
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	sound = Sound.new()
	add_child(sound)
	sound.settings = settings
	get_viewport().size_changed.connect(rebuild)
	get_window().focus_exited.connect(focus_lost)
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--qa-dir="):
			saves.directory = arg.trim_prefix("--qa-dir=")
			DirAccess.make_dir_recursive_absolute(saves.directory)
			test_mode = true
	for arg in args:
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

func load_settings() -> void:
	if FileAccess.file_exists(settings_path):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if saved is Dictionary:
			for key in settings:
				if saved.has(key):
					settings[key] = saved[key]
	apply_settings()

func apply_settings() -> void:
	settings.master = clampf(float(settings.master), 0, 1)
	settings.text_scale = clampf(float(settings.text_scale), 1, 1.5)
	settings.sensitivity = clampf(float(settings.sensitivity), 0.5, 2)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func save_settings() -> void:
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
	apply_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if screen != "menu" and not model.state.is_empty():
			save_game()
		get_tree().quit()

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
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func setup_theme() -> void:
	var theme = Theme.new()
	theme.default_font_size = int(20 * float(settings.text_scale))
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("a6a58e"))
	theme.set_stylebox("normal", "Button", style(GREEN, GREEN, 8))
	theme.set_stylebox("hover", "Button", style(Color("5b8060"), GOLD, 8))
	theme.set_stylebox("pressed", "Button", style(INK, GOLD, 8))
	theme.set_stylebox("disabled", "Button", style(Color("d7d2ba"), Color("c9c0a3"), 8))
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

func add_button(parent: Node, text: String, action: Callable, disabled: bool = false) -> Button:
	var button = Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func():
		sound.play("ui_click", 0.5)
		action.call())
	parent.add_child(button)
	return button

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

func build_menu(size: Vector2) -> void:
	positioned_label("ЛЕСНАЯ ЖЕЛЕЗНАЯ ДОРОГА", Rect2(80, 85, 1000, 40), 20, GOLD)
	var title = positioned_label("Лесная\nколея", Rect2(76, 142, 900, 220), 86)
	title.add_theme_font_size_override("font_size", 86)
	positioned_label("Начни с рычага. Верни поезда в Дальний бор.", Rect2(82, 360, 740, 60), 23)
	var box = panel_at(ui, Rect2(80, 440, 400, minf(430, size.y - 465)), true)
	add_button(box, "Продолжить", continue_game, not saves.has_any())
	add_button(box, "Новая игра", func():
		if saves.has_any():
			confirm("Начать новую карьеру? Текущая останется в резервной копии.", func(): begin_new())
		else:
			begin_new())
	add_button(box, "Настройки", func(): show_modal("settings"))
	add_button(box, "Как играть", func(): show_modal("help"))
	add_button(box, "Об игре", func(): show_modal("credits"))
	add_button(box, "Выход", func(): get_tree().quit())
	positioned_label("01  /  ОТ РУЧНОЙ ДРЕЗИНЫ ДО ЭЛЕКТРОВОЗА", Rect2(580, size.y - 60, size.x - 620, 40), 17)

func begin_new(seed_number: int = -1) -> void:
	if seed_number < 0:
		seed_number = int(Time.get_unix_time_from_system()) % 100000
	model.new_game(seed_number)
	selected_object = "handcar"
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
	model.message = "Готов продолжить поездку?" if paused else ""
	rebuild()

func build_depot(size: Vector2) -> void:
	positioned_label("ДЕПО  /  ЛЕСНАЯ", Rect2(44, 30, 1000, 50), 32)
	positioned_label("%d монет  ·  %d / 10 основных рейсов  ·  дорога %d" % [model.state.money, model.state.chapter, model.route.seed_value], Rect2(46, 87, 1100, 45), 20)
	var menu_row = HBoxContainer.new()
	menu_row.position = Vector2(size.x - 285, 28)
	menu_row.size = Vector2(245, 50)
	ui.add_child(menu_row)
	add_button(menu_row, "☰  Меню", func(): pause_game())
	var left_width = size.x * 0.46
	var panel_rect = Rect2(left_width + 30, 155, size.x - left_width - 70, size.y - 185)
	var right = panel_at(ui, panel_rect, true)
	var tabs = HBoxContainer.new()
	right.add_child(tabs)
	for name in ["Гараж", "Состав", "Улучшения", "Рейсы"]:
		add_button(tabs, name, func(): tab = name; rebuild(), tab == name)
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
			var label = str(base.name) if id != "locomotive" else "Электролокомотив"
			add_label(right, label, 24)
			add_label(right, {"handcar": "Ручной рычаг · без топлива · до 4 мест", "motorcar": "Бензиновый двигатель · бак 2 л · один вагон", "locomotive": "Электротяга · батарея 0,6 кВт·ч · до трёх вагонов"}[id], 18)
			if owned:
				add_button(right, "Выбрана" if model.vehicle_id() == id else "Выбрать", func():
					if model.select_vehicle(id):
						selected_object = id
						save_game()
						rebuild()
					else: notify(model.message), model.vehicle_id() == id)
			else:
				add_button(right, "Купить · %d монет" % base.cost, func():
					confirm("Купить %s за %d? Останется %d монет. Предыдущая машина останется в гараже." % [label, base.cost, maxi(0, int(model.state.money) - int(base.cost))], func():
						if model.buy_vehicle(id):
							selected_object = id
							save_game()
							rebuild()
						else: notify(model.message)))
	elif tab == "Состав":
		add_label(right, "Выбери конкретные вагоны. Их улучшения сохраняются при перестановке.")
		for id in model.state.wagons_by_id:
			var stats = model.object_stats(id)
			add_label(right, "%s  ·  %d мест  ·  %d кг" % [id, stats.slots, stats.mass], 22)
			add_button(right, "Отцепить " + id if id in model.state.consist_ids else "Прицепить " + id, func():
				if model.toggle_wagon(id): save_game(); rebuild()
				else: notify(model.message))
		if not model.state.wagons_by_id.has("W03"):
			add_button(right, "Купить W03 · 180 монет", func(): confirm("Купить третий вагон за 180 монет?", func():
				if model.buy_wagon(): save_game(); rebuild()
				else: notify(model.message)))
		add_label(right, "Мест в составе: %d. Для финала нужно шесть." % model.capacity(), 21)
	elif tab == "Улучшения":
		build_upgrades(right)
	else:
		build_missions(right)
	positioned_label(vehicle_display_name(), Rect2(44, 158, left_width - 20, 70), 32)
	var stats = model.object_stats(model.vehicle_id())
	var details = "%d кг  ·  %d мест  ·  тормоз %d Н" % [model.train_mass(), model.capacity(), stats.brake]
	if model.vehicle_id() == "handcar":
		details += "\nРычажный привод: %d Вт · %.0f Дж/цикл\nКоэффициент качения: %.4f" % [stats.power, stats.cycle_work, stats.rolling]
	else:
		details += "\nТяга: %d / %d Н · скорость %.1f / %.1f м/с\n" % [stats.traction[0], stats.traction[1], stats.speeds[0], stats.speeds[1]] + energy_text()
	positioned_label(details, Rect2(46, 239, left_width - 20, 105), 19)
	var service = HBoxContainer.new()
	service.position = Vector2(44, size.y - 150)
	service.size = Vector2(left_width - 25, 50)
	ui.add_child(service)
	add_button(service, "Зарядить бесплатно" if model.vehicle_id() == "locomotive" else "Заправить бесплатно", func():
		if model.refuel(): save_game(); rebuild(); notify("Запас пополнен")
		else: notify(model.message), model.vehicle_id() == "handcar")
	add_button(service, "Улучшить", func(): selected_object = model.vehicle_id(); tab = "Улучшения"; rebuild())
	positioned_label("Нажми на машину или вагон, чтобы выбрать его улучшения.", Rect2(46, size.y - 83, left_width - 30, 60), 17)

func build_upgrades(right: VBoxContainer) -> void:
	var row = HBoxContainer.new()
	right.add_child(row)
	var objects = [model.vehicle_id()] + model.state.wagons_by_id.keys()
	if not selected_object in objects:
		selected_object = model.vehicle_id()
	for id in objects:
		add_button(row, "Машина" if not id.begins_with("W") else id, func(): selected_object = id; rebuild(), id == selected_object)
	var before = model.object_stats(selected_object)
	add_label(right, "Выбран: " + (selected_object if selected_object.begins_with("W") else vehicle_display_name()), 22)
	add_label(right, "%d мест · %d кг · тормоз %d Н" % [before.slots, before.mass, before.brake], 18)
	if selected_object.begins_with("W"):
		add_label(right, "Качение: %.4f · защита посуды: %d%%" % [before.rolling, roundi((1.0 - float(before.shock)) * 100)], 18)
	for branch in model.data.upgrade_catalog:
		if branch.target_type != ("wagon" if selected_object.begins_with("W") else selected_object):
			continue
		var lv = int(model.object_state(selected_object).levels.get(branch.id, 0))
		var name = str(branch.name)
		if selected_object == "locomotive":
			name = {"locomotive_engine": "Электромотор", "locomotive_gearbox": "Контроллер тяги", "locomotive_tank": "Аккумулятор"}.get(branch.id, name)
		add_label(right, "%s  ·  %d / 2" % [name, lv], 23)
		if lv < 2:
			var preview = upgrade_preview(selected_object, branch)
			add_label(right, preview, 18)
			var cost = int(branch.level_costs[lv])
			add_button(right, "Улучшить до %s · %d монет" % ["I" if lv == 0 else "II", cost], func():
				var id = selected_object
				confirm("%s: %s\nЦена %d. Останется %d монет." % [id, preview, cost, maxi(0, int(model.state.money) - cost)], func():
					if model.upgrade(id, branch.id): save_game(); rebuild()
					else: notify(model.message)))
		else:
			add_label(right, "Максимальный уровень", 17, GREEN)

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
	var mission = model.current_mission()
	if not mission.is_empty():
		add_label(right, "%s · %s" % [mission.id, mission.title], 25)
		add_label(right, mission_description(mission), 19)
		var problem = model.mission_error(mission)
		if problem != "":
			add_label(right, problem, 19, RED)
		add_button(right, "К погрузке →", func(): take_mission(mission), problem != "")
	else:
		add_label(right, "Линия работает. Выбирай следующую перевозку.", 23)
	add_label(right, "Свободные рейсы", 24)
	for offer in model.free_offers():
		add_label(right, str(offer.title), 20)
		add_label(right, mission_description(offer), 17)
		add_button(right, "Взять · %d монет" % offer.reward, func(): take_mission(offer))

func mission_description(mission: Dictionary) -> String:
	var stops: Array = []
	for stop in mission.dropoffs:
		var goods: Array = []
		for pair in stop.cargo:
			goods.append("%s × %d" % [model.cargo_base(pair[0]).name, pair[1]])
		stops.append(model.station_name(stop.station) + ": " + ", ".join(goods))
	return "\n".join(stops) + "\nВернись в Лесную. Оплата в депо: %d монет." % mission.reward

func take_mission(mission: Dictionary) -> void:
	if model.accept_mission(mission):
		screen = "game"
		zoom_level = fit_train_zoom()
		camera_s = 0
		camera_y = 0
		last_phase = "loading"
		save_game()
		rebuild()
	else:
		notify(model.message)

func fit_train_zoom() -> float:
	return clampf(10.5 / maxf(10.5, model.train_length()), 0.75, 1.0)

func build_hud(size: Vector2) -> void:
	hud = positioned_label("", Rect2(42, 24, size.x - 220, 90), 22)
	var pause_row = HBoxContainer.new()
	pause_row.position = Vector2(size.x - 160, 26)
	pause_row.size = Vector2(120, 48)
	ui.add_child(pause_row)
	add_button(pause_row, "Пауза", pause_game)
	hint_label = positioned_label("", Rect2(42, 177, size.x - 84, 78), 22)
	action_bar = HBoxContainer.new()
	action_bar.position = Vector2(42, size.y - 253)
	action_bar.size = Vector2(size.x - 84, 50)
	action_bar.add_theme_constant_override("separation", 12)
	ui.add_child(action_bar)
	last_action_key = ""
	update_hud()

func update_hud() -> void:
	if screen != "game" or hud == null:
		return
	var state = model.state
	var destination = model.next_destination()
	var target_s = float(model.route.station_s[station_number(destination)])
	var order = "Свободное движение" if state.active.is_empty() else str(state.active.title)
	var returning = not state.active.is_empty() and state.active.phase == "return"
	var stop_index = model.station_index()
	var at_station = model.station_name(model.data.stations[stop_index].id) if stop_index >= 0 else ""
	hud.text = "%.1f км/ч    ·    %d монет    ·    %s    ·    Тяга %s\n%s  →  %s   ·   %d м" % [absf(float(state.v)) * 3.6, state.money, energy_text(), "→" if model.drive_direction() > 0 else "←", "Домой" if returning else order, model.station_name(destination), absf(target_s - float(state.s))]
	var hint = ""
	if state.phase == "loading":
		hint = "Перетащи груз с площадки в подсвеченные места на машине."
	elif returning and model.stopped() and stop_index > 0:
		hint = "Груз доставлен. Разверни состав и возвращайся домой за оплатой."
	elif stop_index >= 0 and model.stopped():
		hint = "Станция «%s». Перетащи груз для этой станции на площадку внизу." % at_station
	elif model.vehicle_id() == "handcar":
		hint = "Зажми деревянный хват и качай вверх-вниз. Ровные полные ходы разгоняют лучше. Красный рычаг — тормоз."
	elif not state.engine:
		hint = "Запуск: подача 0%, передача Н. Потяни тумблер вверх, затем выбери режим и подай тягу."
	else:
		hint = "Подача — зелёный рычаг, тормоз — красный. Передача меняется при подаче ниже 15%."
	if float(state.brake) > 0.95 and not model.stopped():
		hint = "Торможение."
	if model.stopped() and state.phase == "route" and not returning and stop_index == 0:
		hint = "Отпусти красный тормозной рычаг вниз, затем начинай движение."
	if model.vehicle_id() == "locomotive" and model.regen_kw > 0.01:
		hint = "Рекуперация: +%.1f кВт. Часть энергии торможения возвращается в аккумулятор." % model.regen_kw
	hint_label.text = hint if state.tutorial else ""
	var key = "%s_%d_%s_%s_%s_%d" % [state.phase, stop_index, str(model.stopped()), str(model.all_loaded()), str(returning), model.drive_direction()]
	if key != last_action_key:
		last_action_key = key
		clear_children(action_bar)
		if state.phase == "loading":
			add_button(action_bar, "Отправиться →", func():
				if model.depart(): save_game(); rebuild()
				else: notify(model.message), not model.all_loaded())
			add_button(action_bar, "Вернуться в депо", func(): model.back_to_depot(); screen = "depot"; save_game(); rebuild())
		elif model.stopped():
			add_button(action_bar, "← Задний ход" if state.direction > 0 else "← Вперёд", func():
				if model.set_reverser(-int(state.direction)): save_game(); last_action_key = ""
				else: notify(model.message), model.drive_direction() < 0)
			add_button(action_bar, "Вперёд →" if state.direction > 0 else "Задний ход →", func():
				if model.set_reverser(int(state.direction)): save_game(); last_action_key = ""
				else: notify(model.message), model.drive_direction() > 0)
			if stop_index >= 0:
				add_button(action_bar, "Развернуть состав", func():
					if model.turn(): save_game(); notify("Состав развёрнут"); last_action_key = ""
					else: notify(model.message), model.can_turn() != "")
			if stop_index == 0:
				add_button(action_bar, "В домашнее депо", func(): model.back_to_depot(); screen = "depot"; save_game(); rebuild())
			add_button(action_bar, "Сохранить", func(): save_game(); notify("Сохранено"))

func energy_text() -> String:
	if model.vehicle_id() == "handcar": return "Ручной привод · %d Вт" % roundi(model.output_power)
	var amount = float(model.state.fleet_by_id[model.vehicle_id()].fuel)
	var cap = float(model.object_stats(model.vehicle_id()).tank)
	if model.vehicle_id() == "locomotive":
		return "Заряд %d%% · %.2f / %.2f кВт·ч" % [roundi(amount / cap * 100), amount, cap]
	return "Бензин %.2f / %.1f л" % [amount, cap]

func vehicle_display_name() -> String:
	return "Электролокомотив" if model.vehicle_id() == "locomotive" else str(model.vehicle_base().name)

func station_number(id: String) -> int:
	for i in range(model.data.stations.size()):
		if model.data.stations[i].id == id: return i
	return 0

func pause_game() -> void:
	paused = true
	cancel_drag()
	modal_kind = "pause"
	rebuild()

func show_modal(kind: String) -> void:
	cancel_drag()
	if screen != "menu": paused = true
	modal_kind = kind
	rebuild()

func close_modal() -> void:
	modal_kind = ""
	paused = false
	rebuild()

func confirm(text: String, action: Callable) -> void:
	toast = text
	pending_action = action
	show_modal("confirm")

func build_modal(size: Vector2) -> void:
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
		if model.message == "Готов продолжить поездку?": add_label(box, model.message, 23)
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
		add_label(box, "Настройки", 32)
		for key in ["master", "mechanisms", "forest", "music", "sensitivity"]:
			var names = {"master": "Общая громкость", "mechanisms": "Механизмы", "forest": "Лес", "music": "Музыка", "sensitivity": "Чувствительность рычага"}
			add_label(box, names[key], 21)
			var slider = HSlider.new()
			slider.min_value = 0.5 if key == "sensitivity" else 0
			slider.max_value = 2 if key == "sensitivity" else 1
			slider.step = 0.05
			slider.value = float(settings[key])
			slider.custom_minimum_size.y = 28
			box.add_child(slider)
			slider.value_changed.connect(func(value): settings[key] = value; save_settings())
		add_button(box, "Полный экран: " + ("вкл." if settings.fullscreen else "выкл."), func(): settings.fullscreen = not settings.fullscreen; save_settings(); rebuild())
		var row = HBoxContainer.new()
		box.add_child(row)
		for scale_value in [1.0, 1.25, 1.5]:
			add_button(row, "Текст %d%%" % (scale_value * 100), func(): settings.text_scale = scale_value; save_settings(); rebuild())
		add_button(box, "Готово", close_modal)
	elif modal_kind == "help":
		add_label(box, "Как играть", 32)
		add_label(box, "1. В депо выбери рейс и нажми «К погрузке». Перетащи каждый предмет с площадки в свободное место на машине или вагоне. Отправляйся, когда всё погружено.\n\n2. Отпусти тормоз: зажми красную рукоять и потяни вниз. На ручной дрезине качай выделенный правый конец деревянного рычага вверх-вниз. На спуске можно катиться по инерции.\n\n3. Перед станцией плавно затяни тормоз вверх. Остановись в пределах платформы, затяни тормоз до 100% и перетащи нужные грузы на площадку. У каждого предмета указана станция.\n\n4. После последней доставки убери подачу, разверни пустой состав кнопкой на станции и вернись в Лесную. Деньги выдаются в домашнем депо.\n\n5. Моторная дрезина: передача Н, подача 0%, потяни тумблер запуска вверх. Затем выбери 1 и добавь подачу. На ровном участке можно включить 2, сначала снизив подачу ниже 15%. Бензин пополняется в депо.\n\n6. Электролокомотив: вместо бензина аккумулятор. Режим 1 — тяговый, 2 — ходовой. Без подачи он катится по инерции; торможение возвращает четверть доступной энергии. Зарядка бесплатна в депо.\n\n7. В гараже остаются все купленные машины. Вагоны выбираются отдельно, улучшения следуют за их ID. Для финального рейса нужны шесть мест: три обычных вагона или два расширенных.\n\nЗадний ход: остановись, затяни тормоз и выбери стрелку направления. На ручной дрезине можно взять хват и толкнуть его влево или вправо с затянутым тормозом. Состав при этом сохраняет положение и груз.\n\nКолесо мыши — приблизить машину. Esc — пауза. При потере фокуса игра останавливается. Если застрял или кончилась энергия, вызови помощь депо из паузы.", 20)
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
		add_label(box, "Небольшая игра о работе лесной железной дороги.\nРазработка: Codex совместно с владельцем проекта, 2026.\nГрафика: предоставленный комплект ForestRail, созданный с image_gen. Звуки синтезированы для этого комплекта.\nGodot Engine 4.7.2, лицензия MIT. Полные лицензии движка и его компонентов включены в поставку.\n\nВерсия игры 1.0.1 · ТЗ 2.1 с электрическим локомотивом.", 22)
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
	toast_seconds = maxf(0, toast_seconds - dt)
	if screen != "menu" and not model.state.is_empty():
		var target_s = float(model.state.s)
		if screen == "depot": target_s = 0
		camera_s = lerpf(camera_s, target_s, 1 - exp(-dt * 6))
		camera_y = lerpf(camera_y, model.route.sample(camera_s).y, 1 - exp(-dt * 4))
		var target_x = get_viewport_rect().size.x * (0.31 if screen == "depot" else (0.65 if model.state.direction > 0 else 0.35))
		if screen == "depot" and not model.state.consist_ids.is_empty(): target_x = get_viewport_rect().size.x * 0.46 - 136
		camera_x = lerpf(camera_x if camera_x > 0 else target_x, target_x, 1 - exp(-dt * 3))
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
		sound.play(str(model.events.pop_front()), 0.6)
	sound.update(model, paused, screen == "menu", dt)
	if art_world != null: art_world.update_view()
	queue_redraw()
	if smoke_frames >= 0:
		smoke_frames -= 1
		if smoke_frames == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(screenshot_path)
			get_tree().quit()

func _physics_process(dt: float) -> void:
	if screen == "game" and not paused:
		model.physics_step(dt)
		autosave += dt
		if autosave >= 60 and drag == "":
			autosave = 0
			save_game()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if modal_kind == "": pause_game()
		else: close_modal()
		get_viewport().set_input_as_handled()
		return
	if drag == "": return
	if event is InputEventMouseMotion:
		if paused: cancel_drag(); return
		var delta_y = event.relative.y * float(settings.sensitivity)
		drag_total += delta_y
		if drag == "pump":
			drag_horizontal += event.relative.x
			if model.stopped() and absf(drag_horizontal) >= 38:
				model.set_reverser(int(signf(drag_horizontal)) * int(model.state.direction))
				drag_horizontal = 0
			if float(model.state.brake) > 0.9 and absf(delta_y) > 2: notify("Тормоз затянут. Сначала отпусти красную рукоять вниз")
			model.pump_motion(delta_y / maxf(45, 64 * zoom_level))
		elif drag == "brake":
			model.state.brake = clampf(drag_initial - drag_total / 130, 0, 1)
		elif drag == "throttle":
			model.state.throttle = clampf(drag_initial - drag_total / 130, 0, 1)
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
			for hit in body_hits:
				if hit.rect.has_point(mouse): selected_object = hit.id; tab = "Улучшения"; rebuild(); return
			return
		var nearest: Dictionary = {}
		var distance = 31.0
		for hit in grip_hits:
			var d = mouse.distance_to(hit.position)
			if d < distance:
				distance = d
				nearest = hit
		for hit in cargo_hits:
			if hit.rect.has_point(mouse) and mouse.distance_to(hit.rect.get_center()) < distance:
				nearest = {}
		if not nearest.is_empty():
			drag = nearest.id
			drag_total = 0
			drag_horizontal = 0
			drag_initial = float(model.state.get(drag, 0))
			model.reset_input()
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			return
		for hit in cargo_hits:
			if hit.rect.has_point(mouse):
				if not model.stopped(): notify("Сначала остановись и затяни тормоз"); return
				drag = "cargo"
				drag_item = hit.id
				return

func finish_drag(mouse: Vector2) -> void:
	if drag == "cargo":
		var target = "invalid"
		for slot in slot_hits:
			if slot.rect.has_point(mouse): target = slot.key; break
		var size = get_viewport_rect().size
		if Rect2(36, size.y - 182, size.x - 72, 160).has_point(mouse): target = ""
		if target != "invalid":
			if model.transfer(drag_item, target): save_game()
			else: notify(model.message)
	elif drag == "gear" and absf(drag_total) >= 12:
		var value = clampi(int(model.state.gear) + (1 if drag_total < 0 else -1), 0, 2)
		if not model.set_gear(value): notify(model.message)
	elif drag == "start" and absf(drag_total) >= 12:
		if not model.start_engine(drag_total < 0): notify(model.message)
	cancel_drag()

func world_point(s: float) -> Vector2:
	var size = get_viewport_rect().size
	var p = model.route.sample(s)
	var cam = model.route.sample(camera_s)
	var head_x = camera_x if camera_x > 0 else size.x * (0.31 if screen == "depot" else 0.65)
	var scale_value = ArtV3.PX * view_scale()
	return Vector2(head_x + (p.x - cam.x) * scale_value, size.y * 0.63 - (p.y - camera_y) * scale_value)

func view_scale() -> float:
	if screen != "depot": return zoom_level
	return minf(0.94, (get_viewport_rect().size.x * 0.46 - 150) / (ArtV3.PX * model.train_length()))

func _draw() -> void:
	if art == null: return
	var size = get_viewport_rect().size
	if art_world == null: draw_background(size)
	grip_hits.clear()
	slot_hits.clear()
	cargo_hits.clear()
	body_hits.clear()
	if screen == "menu":
		draw_rect(Rect2(0, 0, size.x * 0.55, size.y), Color(0.06, 0.13, 0.1, 0.72))
		draw_menu_train(size)
	else:
		draw_train()
		if screen == "depot":
			draw_style_box(style(Color(0.08,0.15,0.12,0.88),Color(0.5,0.57,0.39,0.45),8),Rect2(22,12,size.x-44,115))
			draw_style_box(style(Color(0.08,0.15,0.12,0.88),Color(0.5,0.57,0.39,0.45),8),Rect2(22,151,size.x*0.46-28,195))
		if screen == "game":
			draw_style_box(style(Color(0.08,0.15,0.12,0.88),Color(0.5,0.57,0.39,0.45),8),Rect2(22,12,size.x-44,246))
			draw_map(size)
			draw_loading_dock(size)
			draw_tooltip()
	if toast_seconds > 0 and modal_kind != "confirm":
		var width = minf(1100, size.x - 100)
		var rect = Rect2((size.x - width) / 2, size.y - 65, width, 44)
		draw_style_box(style(INK, GOLD, 8), rect)
		draw_string(font, rect.position + Vector2(18, 29), toast, HORIZONTAL_ALIGNMENT_LEFT, width - 30, 19, PAPER)

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
	for i in range(ids.size() - 1, -1, -1):
		var s = model.body_s(i) if screen != "depot" else -i * 3.5
		var p = world_point(s)
		var angle = -model.route.slope(s)
		var direction = int(model.state.direction) if screen != "depot" else 1
		var transform = Transform2D(angle, Vector2(scale_value * direction, scale_value), 0, p)
		draw_set_transform_matrix(transform)
		draw_body(ids[i], s, screen == "game")
		draw_set_transform_matrix(Transform2D.IDENTITY)
		body_hits.append({"id": ids[i], "rect": Rect2(p - Vector2(art.body_width(ids[i])*0.5, 220) * scale_value, Vector2(art.body_width(ids[i]), 230) * scale_value)})
		if screen == "depot" and selected_object == ids[i]:
			draw_line(p + Vector2(-art.body_width(ids[i])*0.46,14)*scale_value,p+Vector2(art.body_width(ids[i])*0.46,14)*scale_value,GOLD,3,true)
		if i > 0:
			var front = world_point(model.body_s(i - 1) if screen != "depot" else -(i - 1) * 3.5)
			draw_line(p + Vector2(art.body_width(ids[i])*0.5*direction*scale_value,-27*scale_value),front-Vector2(art.body_width(ids[i-1])*0.5*direction*scale_value,27*scale_value),INK,5)
		if screen == "game":
			add_world_hits(ids[i], i, transform)

func draw_body(id: String, s: float, controls: bool) -> void:
	var body_scale = view_scale()
	var body_transform = Transform2D(-model.route.slope(s), Vector2(body_scale * (model.state.direction if screen != "depot" else 1), body_scale), 0, world_point(s))
	ellipse(Vector2(10, 7), Vector2(art.body_width(id)*0.48, 7), Color(0.05, 0.08, 0.05, 0.23))
	art.draw_vehicle(self,id,s,int(model.state.direction) if screen!="depot" else 1,body_transform,model,controls)
	var stats = model.object_stats(id)
	for index in range(int(stats.slots)):
		var loc = slot_local(id, index)
		var key = id + ":" + str(index)
		var item = find_slot_cargo(key)
		if controls and item.is_empty():
			draw_style_box(style(Color(0.9, 0.87, 0.65, 0.35), Color("d1bd71"), 5), Rect2(loc - Vector2(32, 39), Vector2(64, 62)))
		if not item.is_empty() and item.id != drag_item:
			var sway = clampf(-model.acceleration * 0.04, -0.07, 0.07)
			var sprite_id = str(model.cargo_base(item.type).sprite)
			var bounds = visual_layout[sprite_id]
			var ratio = float(bounds[2]-bounds[0])/maxf(1,float(bounds[3]-bounds[1]))
			var height = minf(46.0 if id=="handcar" else 60.0,66.0/ratio)
			grounded_sprite(sprite_id,loc+Vector2(-sway*10,19),height)
			draw_line(loc + Vector2(-24, -25), loc + Vector2(24, 14), GOLD, 3)
			draw_line(loc + Vector2(24, -25), loc + Vector2(-24, 14), GOLD, 3)
	if id.begins_with("W"): art.draw_wagon_front(self,id,body_transform)
	if id == model.vehicle_id() and controls:
		draw_controls(body_transform)

func wheel_rotation(distance: float, facing: int) -> float:
	# Positive rotation is clockwise in Godot. Mirrored bodies invert the local angle.
	return distance * 64.0 / 28.0 * facing

func draw_pump_linkage() -> void:
	var pivot = Vector2(0, -177)
	var bearing = Vector2(40, -48)
	var normalized = clampf(sin(model.pump_angle) / sin(deg_to_rad(28)), -1, 1)
	var phase = asin(normalized)
	if model.pump_last_direction * model.drive_direction() < 0: phase = PI - phase
	var attachment = pivot + Vector2(42, 0).rotated(model.pump_angle)
	var crank_pin = bearing + Vector2(cos(phase), sin(phase)) * 20
	draw_circle(bearing, 25, Color("242e2b"))
	for i in range(14):
		var a = phase + i * TAU / 14
		var radial = Vector2(cos(a), sin(a))
		var tangent = radial.orthogonal()
		draw_colored_polygon(PackedVector2Array([bearing + radial * 22 - tangent * 3, bearing + radial * 29 - tangent * 2, bearing + radial * 29 + tangent * 2, bearing + radial * 22 + tangent * 3]), Color("8e805c"))
	draw_arc(bearing, 23, 0, TAU, 32, Color("b5a275"), 3, true)
	for i in range(8):
		var a = phase + i * TAU / 8
		draw_line(bearing + Vector2(cos(a), sin(a)) * 8, bearing + Vector2(cos(a), sin(a)) * 24, Color("736d54"), 4, true)
	draw_line(attachment + Vector2(2, 1), crank_pin + Vector2(2, 1), Color("26332f"), 9, true)
	draw_line(attachment, crank_pin, Color("b4a27a"), 6, true)
	draw_line(attachment + Vector2(-1, 0), crank_pin + Vector2(-1, 0), Color("e0cba0"), 2, true)
	for pin in [attachment, crank_pin, bearing]:
		draw_circle(pin, 6, Color("34443e"))
		draw_circle(pin, 3, GOLD)

func find_slot_cargo(key: String) -> Dictionary:
	for item in model.state.cargo:
		if item.slot == key and not item.delivered: return item
	return {}

func slot_local(id: String, index: int) -> Vector2:
	var count = int(model.object_stats(id).slots)
	return art.slot_position(id,index,count)

func lever_geometry(id: String) -> Dictionary:
	if id == "pump":
		var pose = art.mechanism_pose(model)
		return {"pivot":pose.rocker*ArtV3.PX/128+Vector2(0,art.axis_height("handcar")),"grip":art.hand_grip(model),"angle":pose.angle}
	if id == "brake":
		var pivot = Vector2(-130 if model.vehicle_id()=="handcar" else -145, -52)
		var angle = lerpf(-0.95, 0.12, float(model.state.brake))
		return {"pivot": pivot, "grip": pivot + Vector2(0, -95).rotated(angle), "angle": angle}
	if id == "throttle":
		var pivot = Vector2(80, -52)
		var angle = lerpf(0.8, -0.25, float(model.state.throttle))
		return {"pivot": pivot, "grip": pivot + Vector2(0, -76).rotated(angle), "angle": angle}
	if id == "gear":
		var pivot = Vector2(-35, -48)
		var angle = lerpf(-0.6, 0.45, float(model.state.gear) / 2)
		return {"pivot": pivot, "grip": pivot + Vector2(0, -83).rotated(angle), "angle": angle}
	return {"pivot": Vector2(-40, -184), "grip": Vector2(-40, -209 if model.state.engine else -159), "angle": 0.0}

func draw_controls(body_transform: Transform2D) -> void:
	var ids = ["pump", "brake"] if model.vehicle_id() == "handcar" else ["brake", "throttle", "gear", "start"]
	if model.vehicle_id() != "handcar":
		draw_line(Vector2(-40,-54),Vector2(-40,-184),INK,7,true)
		draw_line(Vector2(-41,-54),Vector2(-41,-184),Color("8d917a"),2,true)
	for id in ids:
		var geo = lever_geometry(id)
		var color = {"pump": Color("a16b38"), "brake": RED, "throttle": GREEN, "gear": GOLD, "start": Color("708574")}[id]
		var factor = {"pump": 102.0 / 116, "brake": 95.0 / 166, "throttle": 76.0 / 165, "gear": 83.0 / 166, "start": 25.0 / 138}[id]
		var angle = float(geo.angle)
		if id == "start": angle = 0.0 if model.state.engine else PI
		var pivot = Vector2(128, 128 if id == "pump" else 224)
		# The base stays fixed; only the independent supplied SVG part rotates.
		if id != "pump": sprite("control_mount", Rect2(geo.pivot - Vector2(16, 20), Vector2(32, 32)))
		draw_set_transform_matrix(body_transform * Transform2D(angle, geo.pivot))
		if id != "pump":
			sprite("control_" + id, Rect2(-pivot * factor, Vector2.ONE * 256 * factor))
		draw_set_transform_matrix(body_transform)
		draw_arc(geo.grip, 16, 0, TAU, 28, PAPER, 2, true)
		var label = {"pump": "КАЧАЙ ↕", "brake": "%d%%" % (float(model.state.brake) * 100), "throttle": "%d%%" % (float(model.state.throttle) * 100), "gear": ["Н", "1", "2"][int(model.state.gear)], "start": "ВКЛ" if model.state.engine else "ПУСК"}[id]
		draw_string(font, geo.grip + Vector2(-25, -25), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, PAPER)

func add_world_hits(id: String, index: int, transform: Transform2D) -> void:
	if index == 0:
		var ids = ["pump", "brake"] if model.vehicle_id() == "handcar" else ["brake", "throttle", "gear", "start"]
		for control_id in ids:
			grip_hits.append({"id": control_id, "position": transform * lever_geometry(control_id).grip})
	for slot in model.slots():
		if slot.owner != id: continue
		var p = transform * slot_local(id, int(slot.index))
		var rect = Rect2(p - Vector2(37, 45) * zoom_level, Vector2(74, 80) * zoom_level)
		slot_hits.append({"key": slot.key, "rect": rect})
		var item = find_slot_cargo(slot.key)
		if not item.is_empty(): cargo_hits.append({"id": item.id, "rect": rect})

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
	var station_index = model.station_index()
	var rect = Rect2(36, size.y - 182, size.x - 72, 160)
	draw_style_box(style(Color(0.14, 0.21, 0.17, 0.95), Color("82916c"), 12), rect)
	var title = "ПЛОЩАДКА · " + (model.station_name(model.data.stations[station_index].id) if station_index >= 0 else "ГРУЗ ЗАКРЕПЛЁН")
	draw_string(font, rect.position + Vector2(20, 28), title, HORIZONTAL_ALIGNMENT_LEFT, 600, 18, PAPER)
	if station_index >= 0 and model.stopped():
		draw_string(font, rect.position + Vector2(590, 28), "Отпусти груз здесь, чтобы выгрузить", HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 615, 18, PAPER)
	var index = 0
	for item in model.state.cargo:
		if item.delivered or item.slot != "": continue
		if station_index != 0: continue
		var p = rect.position + Vector2(42 + index * 128, 73)
		if item.id != drag_item:
			sprite(model.cargo_base(item.type).sprite, Rect2(p, Vector2(60, 65)))
		cargo_hits.append({"id": item.id, "rect": Rect2(p - Vector2(8, 4), Vector2(96, 82))})
		draw_string(font, p + Vector2(65, 44), item.destination, HORIZONTAL_ALIGNMENT_LEFT, 45, 19, GOLD)
		index += 1
	if drag_item != "":
		for item in model.state.cargo:
			if item.id == drag_item:
				sprite(model.cargo_base(item.type).sprite, Rect2(get_global_mouse_position() - Vector2(38, 48), Vector2(76, 80)))
	if index == 0:
		var text = "Площадка свободна. Груз должен оставаться на составе до нужной станции."
		if not model.state.active.is_empty() and model.state.active.phase == "return": text = "Все доставки выполнены. Дома ждут %d монет." % model.state.active.pending_reward
		draw_string(font, rect.position + Vector2(25, 95), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 50, 21, PAPER)

func draw_tooltip() -> void:
	if drag != "": return
	var mouse = get_global_mouse_position()
	var text = ""
	for hit in grip_hits:
		if hit.position.distance_to(mouse) < 31:
			text = {"pump": "Зажми и качай вверх-вниз", "brake": "Тормоз: вверх — затянуть, вниз — отпустить", "throttle": "Подача: вверх — больше, вниз — меньше", "gear": "Н / 1 / 2: потяни вверх или вниз", "start": "Тумблер: вверх — запуск, вниз — выключить"}[hit.id]
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
	if model.state.is_empty(): model.new_game(42)
	var previous = model.pump_angle
	model.pump_angle = sin(time*1.5)*deg_to_rad(26)
	var outer = Transform2D(0,Vector2(1.7,1.7),0,p)
	art.draw_vehicle(self,"handcar",0,1,outer,model,false)
	model.pump_angle = previous
	draw_set_transform_matrix(Transform2D.IDENTITY)
