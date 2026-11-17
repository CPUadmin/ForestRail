extends RefCounted
# Помощник main.gd (1.3.7): окна поверх игры: карта, пауза, настройки, подтверждения.
# Работает через canvas (main.gd), как depot_ui.gd.

var canvas = null   # main.gd

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func build_modal(size: Vector2) -> void:
	if canvas.modal_kind == "map":
		var map_view = canvas.Instruments.new()
		map_view.game = canvas
		map_view.full_map = true
		map_view.size = size
		canvas.overlay.add_child(map_view)
		var close_row = HBoxContainer.new()
		var close_width = 230*float(canvas.settings.text_scale)
		close_row.position = Vector2(size.x-close_width-50,38)
		close_row.size = Vector2(close_width,48)
		canvas.overlay.add_child(close_row)
		canvas.add_button(close_row,"Закрыть [%s / Esc]" % canvas.key_name("map"),canvas.close_modal)
		return
	if canvas.modal_kind == "album":
		var album_screen = canvas.AlbumView.new()
		album_screen.game = canvas
		album_screen.size = size
		canvas.overlay.add_child(album_screen)
		return
	if canvas.modal_kind == "casino":
		var casino_screen = canvas.CasinoView.new()
		casino_screen.game = canvas
		casino_screen.size = size
		canvas.overlay.add_child(casino_screen)
		return

	var shade = ColorRect.new()
	shade.color = Color(0.08, 0.13, 0.11, 0.76)
	shade.size = size
	canvas.overlay.add_child(shade)
	var width = minf(940, size.x - 100)
	var box = canvas.panel_at(canvas.overlay, Rect2((size.x - width) / 2, 80, width, size.y - 160), true)
	if canvas.modal_kind == "confirm":
		canvas.add_label(box, "Подтверждение", 30)
		canvas.add_label(box, canvas.toast, 23)
		canvas.add_button(box, "Подтвердить", func():
			var action = canvas.pending_action
			canvas.modal_kind = ""
			canvas.paused = false
			canvas.toast = ""
			action.call()
			canvas.rebuild(), false, false, &"PrimaryAction")
		canvas.add_button(box, "Отмена", canvas.close_modal, false, false, &"QuietAction")
	elif canvas.modal_kind == "pause":
		canvas.add_label(box, "Пауза", 34)
		if canvas.resume_prompt: canvas.add_label(box, "Готов продолжить поездку?", 23)
		if canvas.Model.wear_rules and canvas.model.wear().warning():
			var weak_node = canvas.model.wear().train_worst()
			canvas.add_label(box, "Слабое место: %s %d%%" % [str(weak_node.name).to_lower(), roundi(float(weak_node.cond) * 100.0)], 22)
		if canvas.Model.wear_rules and not canvas.model.wear().journal.is_empty():
			canvas.add_label(box, "Что случилось в рейсе", 22)
			for line in canvas.model.wear().journal_lines(): canvas.add_label(box, str(line), 19)
		canvas.add_button(box, "Продолжить", canvas.close_modal, false, false, &"PrimaryAction")
		if canvas.Model.wear_rules and canvas.model.creative() and canvas.model.wear().needs_repair():
			canvas.add_button(box, "Починить всё", func():
				var mended = canvas.model.wear().repair_all()
				canvas.notify("Починено узлов: %d" % mended)
				canvas.save_game()
				canvas.show_modal("pause"))
		canvas.add_button(box, "Сохранить", func(): canvas.save_game(); canvas.notify("Сохранено"))
		canvas.add_button(box, "Настройки", func(): canvas.show_modal("settings"))
		# the rare actions are folded under one line: the pause menu shows three things at first sight
		canvas.add_button(box, "Сохранить в слот ▴" if canvas.pause_slots_open else "Сохранить в слот ▾", func(): canvas.pause_slots_open = not canvas.pause_slots_open; canvas.show_modal("pause"), false, false, &"QuietAction")
		if canvas.pause_slots_open:
			for n in range(1, canvas.saves.SLOTS + 1):
				var line = canvas.saves.summary(canvas.saves.slot_name(n))
				canvas.add_button(box, "Слот %d · %s" % [n, line if line != "" else "пусто"], func():
					if canvas.saves.write_slot(canvas.model, n): canvas.notify("Сохранено в слот %d" % n); canvas.show_modal("pause")
					else: canvas.notify(canvas.saves.error), false, false, &"QuietAction")
		canvas.add_button(box, "Застрял? ▴" if canvas.pause_stuck_open else "Застрял? ▾", func(): canvas.pause_stuck_open = not canvas.pause_stuck_open; canvas.show_modal("pause"), false, false, &"QuietAction")
		if canvas.pause_stuck_open and canvas.Model.wear_rules and canvas.model.wear().emergency_possible() and float(canvas.model.wear().train_worst().cond) < 0.5:
			canvas.add_button(box, "Аварийный ремонт (до 50%)", func():
				var done = canvas.model.wear().emergency_all()
				canvas.notify("Мастерская станции: +%d%% износа, %d монет" % [roundi(float(done.gained) * 100.0), int(done.price)])
				canvas.save_game()
				canvas.close_modal())
		if canvas.pause_stuck_open: canvas.add_button(box, "Помощь депо", func(): canvas.confirm("Вернуть состав домой%s? Груз, отметки доставки и покупки сохранятся. Запас энергии пополнится.%s" % [(" за %d монет" % canvas.model.rescue_fee()) if canvas.model.rescue_fee() > 0 else "", (" Не хватает монет: остаток уйдёт в долг и вычтется из следующей награды. Узлы тяги депо починит сразу.") if canvas.model.rescue_fee() > int(canvas.model.state.money) else (" Узлы тяги депо починит сразу." if canvas.model.rescue_fee() > 0 else "")], func():
			canvas.model.rescue()
			canvas.screen = "depot"
			canvas.camera_s = 0
			canvas.save_game()
			if canvas.model.state.paid_ids.size() > canvas.last_paid_count:
				canvas.last_paid_count = canvas.model.state.paid_ids.size()
				canvas.show_modal("result")
			else: canvas.rebuild()))
		canvas.add_button(box, "В главное меню", func(): canvas.save_game(); canvas.screen = "menu"; canvas.close_modal())
	elif canvas.modal_kind == "receiving":
		canvas.build_receiving(box)
	elif canvas.modal_kind == "settings":
		canvas.build_settings(box)
	elif canvas.modal_kind == "help":
		var help_head = HBoxContainer.new()
		box.add_child(help_head)
		var help_title = canvas.add_label(help_head, "Как играть", 32)
		help_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var help_close = canvas.add_button(help_head, "Понятно ✕", canvas.close_modal, false, false, &"QuietAction")
		help_close.size_flags_horizontal = Control.SIZE_SHRINK_END
		# designer journal 16.11: the help was a wall of ~3000 letters; now short parts with a title each
		var help_parts = [
			["Как начать", "Узловая Лесная → Депо → «К погрузке». Перетащи груз на машину и трогай."],
			["Ехать и тормозить", "Отпусти тормоз: красный рычаг к 0%% или %s. Газ дай плавно: резкий газ срывает колёса в буксование. Перед станцией тормози заранее." % canvas.key_name("brake")],
			["На станции", "Встань у платформы и перетащи груз этой станции на площадку. Потом разверни состав и вернись домой: деньги платят в депо."],
			["Плавность", "Плавный рейс +5% к оплате, резкая езда −5%."],
			["Машины", "Ручная и шестовая едут силой рук. Паровоз: уголь в топку, розжиг, жди давление. Бензиновая: ключ на стартер и держи, холодной поможет подсос. Электровоз: заряд."],
			["Топливо", "Заправка в депо и на Дальнем бору (там дороже), вода ещё на Тихой заводи."],
			["Клавиши", "Esc пауза · %s карта · %s кабина · колесо мыши — ближе. Застрял — «Помощь депо» в паузе." % [canvas.key_name("map"), canvas.key_name("cab")]],
		]
		for part in help_parts:
			canvas.add_label(box, str(part[0]), 22, canvas.GOLD)
			canvas.add_label(box, str(part[1]), 18)
		var fleet_speeds: PackedStringArray = []
		for id in canvas.Model.VEHICLE_IDS:
			fleet_speeds.append("%s %d" % [canvas.model.vehicle_base(id).name, roundi(canvas.model.top_speed_kmh(id))])
		canvas.add_label(box, "Скорости, км/ч: " + " · ".join(fleet_speeds), 15, canvas.MUTED_INK)
		if canvas.model.state.get("fleet_by_id", {}).has("zeppelin"):
			canvas.add_label(box, "Цеппелин: газ даёт ход, ползунок «Шаг» надо менять по ходу (мелкий на старте, крупнее с разгоном, держи его у зелёной метки: в красной зоне мотор изнашивается, на тяжёлом винте глохнет). На 130 км/ч потяни «Ручку» до зелёной черты (+3,5°), и он взлетит. В воздухе винт слабее: скорость держи ручкой вниз. Садись плавно: газ меньше, ручку чуть на себя (около +3°), тогда касание мягкое. Рычаги держат положение, их не надо удерживать. Грубая посадка стоит половины монет.", 18, canvas.MUTED_INK)
		if canvas.screen != "menu":
			canvas.add_button(box, "Подсказки: " + ("вкл." if canvas.model.state.tutorial else "выкл."), func(): canvas.model.state.tutorial = not canvas.model.state.tutorial; canvas.save_game(); canvas.rebuild())
		# «Об игре» lives here now (owner 14.11: not in the settings)
		canvas.add_label(box, "Об игре", 26)
		canvas.add_label(box, "Небольшая игра о работе лесной железной дороги. Разработка: владелец проекта вместе с Claude и GPT, 2026. Godot Engine 4.7.2, лицензия MIT.\nВерсия %s" % ProjectSettings.get_setting("application/config/version"), 18, canvas.MUTED_INK)
		canvas.add_button(box, "Открыть папку сохранений", func(): OS.shell_open(ProjectSettings.globalize_path(canvas.saves.directory)), false, false, &"QuietAction")
		canvas.add_button(box, "Понятно", canvas.close_modal)
	elif canvas.modal_kind == "result":
		var result = canvas.model.state.get("last_result", {})
		canvas.build_result_sheet(box, result, size, width)
		var finds: Array = result.get("finds", [])
		if not finds.is_empty():
			var parts: Array = []
			var total = 0
			for entry in finds:
				total += int(entry.count)
				parts.append("%s%s" % [str(entry.name).to_lower(), (" ×%d" % int(entry.count)) if int(entry.count) > 1 else ""])
			canvas.add_label(box, "Принесли с дороги: %d шт. · %s" % [total, ", ".join(parts)], 18)
		if canvas.Model.wear_rules and not canvas.model.wear().journal.is_empty():
			canvas.add_label(box, "Что случилось в рейсе:\n%s" % "\n".join(canvas.model.wear().journal_lines()), 20)
		canvas.add_button(box, "Продолжить перевозки", canvas.close_modal, false, false, &"PrimaryAction")
	else:
		canvas.add_label(box, "Лесная колея", 36)
		canvas.add_label(box, "Небольшая игра о работе лесной железной дороги.\nРазработка: Codex совместно с владельцем проекта, 2026.\nГрафика: предоставленный комплект ForestRail, созданный с image_gen. Звуки синтезированы для этого комплекта.\nGodot Engine 4.7.2, лицензия MIT. Полные лицензии движка и его компонентов включены в поставку.\n\nВерсия игры %s · ТЗ 3.0 · проверка P8." % ProjectSettings.get_setting("application/config/version"), 22)
		canvas.add_button(box, "Назад", canvas.close_modal)
	var scroll := box.get_parent() as ScrollContainer
	var panel := scroll.get_parent() as PanelContainer
	var fit_panel := func():
		if not is_instance_valid(panel) or panel.get_parent() != canvas.overlay: return
		var padding = panel.get_theme_stylebox("panel").get_minimum_size().y
		panel.size.y = minf(size.y - 160, ceilf(box.get_combined_minimum_size().y + padding))
		panel.position.y = (size.y - panel.size.y) * 0.5
	box.minimum_size_changed.connect(fit_panel, CONNECT_DEFERRED)
	fit_panel.call_deferred()
