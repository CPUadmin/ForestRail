extends RefCounted
# Помощник main.gd: настройки и главное меню.
# Работает через canvas (main.gd), как cab_art.gd и control_art.gd.

var canvas = null   # main.gd: it holds the model, the settings and the shared state

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func settings_slider(box: VBoxContainer, key: String, title: String, low: float, high: float, step: float) -> void:
	var value_label = canvas.add_label(box, "", 20)
	var slider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(canvas.settings[key])
	slider.custom_minimum_size.y = 28
	box.add_child(slider)
	var refresh = func(): value_label.text = "%s: %d%%" % [title, roundi(float(canvas.settings[key]) * 100.0)]
	refresh.call()
	slider.value_changed.connect(func(value):
		canvas.settings[key] = value
		canvas.apply_settings()
		refresh.call())

func settings_choice(box: VBoxContainer, key: String, title: String, options: Array, after: Callable = Callable()) -> void:
	canvas.add_label(box, title, 20)
	var row = HBoxContainer.new()
	box.add_child(row)
	for option in options:
		var button = canvas.add_button(row, str(option[1]), func():
			canvas.settings[key] = option[0]
			canvas.apply_settings()
			if after.is_valid(): after.call()
			canvas.rebuild(), false, canvas.setting_matches(canvas.settings[key], option[0]))
		button.add_theme_font_size_override("font_size", int(18 * float(canvas.settings.text_scale)))

func settings_toggle(box: VBoxContainer, key: String, title: String) -> void:
	canvas.add_button(box, "%s: %s" % [title, "вкл." if canvas.settings[key] else "выкл."], func():
		canvas.settings[key] = not canvas.settings[key]
		canvas.apply_settings()
		canvas.rebuild())

func settings_key(box: VBoxContainer, action: String, title: String) -> void:
	var waiting = canvas.awaiting_key == action
	canvas.add_button(box, "%s: %s" % [title, "нажми новую клавишу (Esc отмена)" if waiting else canvas.key_name(action)], func():
		canvas.awaiting_key = action
		canvas.rebuild())

func build_settings(box: VBoxContainer) -> void:
	canvas.add_label(box, "Настройки", 32)
	var actions = HBoxContainer.new()
	box.add_child(actions)
	canvas.add_button(actions, "Применить", func():
		canvas.save_settings()
		canvas.settings_backup = canvas.settings.duplicate(true)
		canvas.notify("Настройки сохранены")
		canvas.close_modal(), false, false, &"PrimaryAction")
	canvas.add_button(actions, "Отменить", canvas.close_modal, false, false, &"QuietAction")
	canvas.add_button(actions, "По умолчанию", func():
		canvas.copy_settings(canvas.settings, canvas.DEFAULT_SETTINGS)
		canvas.apply_settings()
		canvas.apply_window_size()
		canvas.rebuild())
	var tabs = GridContainer.new()
	tabs.columns = 3
	box.add_child(tabs)
	for tab_name in canvas.SETTINGS_TABS:
		var tab_button = canvas.add_button(tabs, tab_name, func():
			canvas.settings_tab = tab_name
			canvas.awaiting_key = ""
			canvas.rebuild(), false, tab_name == canvas.settings_tab)
		tab_button.add_theme_font_size_override("font_size", int(18 * float(canvas.settings.text_scale)))
	if canvas.settings_tab == "Звук":
		settings_slider(box, "master", "Общая громкость", 0, 1, 0.05)
		settings_slider(box, "music", "Музыка", 0, 1, 0.05)
		settings_slider(box, "forest", "Эмбиент (лес, ветер, вода, птицы)", 0, 1, 0.05)
		settings_slider(box, "mechanisms", "Машины и рельсы", 0, 1, 0.05)
		settings_slider(box, "interface", "Интерфейс (клики, монеты)", 0, 1, 0.05)
		canvas.add_label(box, "Проверить звук:", 20)
		var row = HBoxContainer.new()
		box.add_child(row)
		canvas.add_button(row, "Музыка", func(): canvas.sound.play("sting_start", 0.55))
		canvas.add_button(row, "Эмбиент", func(): canvas.sound.play("bird_%d" % randi_range(1, 4), 0.8))
		canvas.add_button(row, "Машины", func(): canvas.sound.play("rail_clack_a", 0.6))
		canvas.add_button(row, "Интерфейс", func(): canvas.sound.play("coins", 0.6))
	elif canvas.settings_tab == "Экран":
		# the main things are in sight; the technical ones are folded under "Ещё"
		settings_toggle(box, "fullscreen", "Полный экран")
		settings_choice(box, "window_size", "Размер окна (если не на весь экран)", [[0, "1280×720"], [1, "1600×900"], [2, "1920×1080"]], canvas.apply_window_size)
		settings_choice(box, "text_scale", "Размер текста", [[1.0, "100%"], [1.25, "125%"], [1.5, "150%"]])
		settings_slider(box, "night_light", "Яркость ночи (0 тёмная, 1 светлее)", 0.0, 1.0, 0.1)
		settings_choice(box, "weather", "Погода", [[0, "Обычная"], [1, "Реже и слабее"], [2, "Без осадков и тумана"]])
		settings_toggle(box, "light_flicker", "Мерцание ламп и искры")
		settings_toggle(box, "reduce_motion", "Без тряски и мерцания")
		settings_slider(box, "cab_shake", "Тряска кабины", 0, 1, 0.05)
		if settings_fold_button(box, "screen_more", "Ещё"):
			settings_toggle(box, "borderless", "Окно без рамки")
			settings_toggle(box, "vsync", "Вертикальная синхронизация")
			settings_choice(box, "fps_cap", "Ограничение кадров", [[0, "Без ограничения"], [30, "30"], [60, "60"], [120, "120"], [144, "144"]])
			settings_choice(box, "msaa", "Сглаживание краёв", [[0, "Выкл."], [2, "2×"], [4, "4×"]])
			settings_choice(box, "instrument_hz", "Частота обновления приборов", [[30, "30 Гц"], [60, "60 Гц"]])
			settings_choice(box, "weather_frequency", "Частота смены погоды", [[0.5, "Медленнее"], [1.0, "Обычно"], [2.0, "Быстрее"]])
	else:
		settings_slider(box, "sensitivity", "Чувствительность ручной дрезины", 0.5, 2, 0.05)
		settings_choice(box, "autosave", "Автосохранение раз в", [[0, "Выкл."], [30, "30 с"], [60, "60 с"], [120, "2 мин"], [300, "5 мин"]])
		if canvas.screen != "menu" and not canvas.model.state.is_empty():
			canvas.add_button(box, "Подсказки: " + ("вкл." if canvas.model.state.tutorial else "выкл."), func():
				canvas.model.state.tutorial = not canvas.model.state.tutorial
				canvas.save_game()
				canvas.rebuild())
		if settings_fold_button(box, "keys_more", "Клавиши"):
			canvas.add_label(box, "Клавиши (Esc всегда пауза, F1 справка):", 20)
			settings_key(box, "map", "Карта")
			settings_key(box, "cab", "Кабина")
			settings_key(box, "burst", "Рывок (суперконденсатор, нитро)")
			settings_key(box, "grapnel", "Кошка шестовой: бросить или отпустить")
			settings_key(box, "ice", "Сбить иней (пневматический)")
			settings_key(box, "brake", "Тормоз: затянуть или отпустить")
			settings_key(box, "sail_side", "Парусная: гик на другой борт")
		canvas.add_button(box, "Как играть", func(): canvas.show_modal("help"))
		canvas.add_button(box, "Об игре", func(): canvas.show_modal("credits"))
		canvas.add_label(box, "Версия игры %s" % ProjectSettings.get_setting("application/config/version"), 20)
		canvas.add_label(box, "Сохранения и настройки: %s" % ProjectSettings.globalize_path(canvas.saves.directory), 17, canvas.MUTED_INK)
		canvas.add_button(box, "Открыть папку сохранений", func(): OS.shell_open(ProjectSettings.globalize_path(canvas.saves.directory)))

# A folded group: the button "Ещё ▾" / "Ещё ▴" opens and closes it; returns true when the group is open.
func settings_fold_button(box: VBoxContainer, id: String, title: String) -> bool:
	var open = bool(canvas.settings_fold.get(id, false))
	canvas.add_button(box, "%s %s" % [title, "▴" if open else "▾"], func():
		canvas.settings_fold[id] = not bool(canvas.settings_fold.get(id, false))
		canvas.awaiting_key = ""
		canvas.rebuild(), false, false, &"QuietAction")
	return open

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
	canvas.ui.add_child(column)
	canvas.add_label(column, "ЛЕСНАЯ ЖЕЛЕЗНАЯ ДОРОГА", 17, Color("e2c27a"))
	var title = canvas.add_label(column, "Лесная\nколея", 96, canvas.PAPER)
	title.add_theme_font_size_override("font_size", int(96 * k))
	title.add_theme_constant_override("line_spacing", int(-22 * k))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	canvas.add_label(column, "Начни с рычага. Верни поезда в Дальний бор.", 22, Color(canvas.PAPER, 0.82))
	var gap = Control.new()
	gap.custom_minimum_size.y = 18 * k
	column.add_child(gap)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.custom_minimum_size.x = 330
	box.add_theme_constant_override("separation", int(6 * k))
	column.add_child(box)
	var has_save = canvas.saves.has_any()
	if has_save: menu_button(box, "Продолжить", canvas.continue_game, true)
	menu_button(box, "Новая игра", func():
		if has_save:
			canvas.confirm("Начать новую карьеру? Текущая будет сохранена в файл %s рядом с сохранениями." % canvas.SaveGame.PREVIOUS_CAREER, func(): canvas.begin_new())
		else:
			canvas.begin_new(), not has_save)
	menu_button(box, "Творческий режим", func():
		if has_save:
			canvas.confirm("Начать творческий режим? Текущая карьера будет сохранена в файл %s рядом с сохранениями." % canvas.SaveGame.PREVIOUS_CAREER, func(): canvas.begin_new(-1, true))
		else:
			canvas.begin_new(-1, true))
	menu_button(box, "Настройки", func(): canvas.show_modal("settings"))
	# "Как играть" and "Об игре" live in the settings (the tab "Служебное") and in F1: the menu keeps only what is needed to start
	menu_button(box, "Выход", func(): canvas.get_tree().quit())
	# The footer needs the room the column leaves at small windows with large text.
	if size.y / float(canvas.settings.text_scale) > 640:
		canvas.positioned_label("От ручной дрезины до электровоза  ·  версия %s" % ProjectSettings.get_setting("application/config/version"), Rect2(86, size.y - 52, 700, 30), 15, Color(canvas.PAPER, 0.55))

# Menu entries are a plain list on the scrim; only the main action is filled.
func menu_button(parent: Node, text: String, action: Callable, primary: bool = false) -> Button:
	var button = canvas.add_button(parent, text, action, false, false, &"PrimaryAction" if primary else &"Button")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 46
	if not primary:
		var ghost = canvas.style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8)
		button.add_theme_stylebox_override("normal", ghost)
		button.add_theme_stylebox_override("hover", canvas.style(Color(1, 1, 1, 0.08), Color(0.89, 0.76, 0.48, 0.5), 8))
		button.add_theme_stylebox_override("pressed", canvas.style(Color(0, 0, 0, 0.25), Color(0.89, 0.76, 0.48, 0.5), 8))
		button.add_theme_color_override("font_color", Color(canvas.PAPER, 0.88))
	return button
