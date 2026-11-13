extends RefCounted
# Помощник main.gd: экраны депо (мастерская, склад, рекорды, казино).
# Работает через canvas (main.gd), как cab_art.gd и control_art.gd.

var canvas = null   # main.gd: it holds the model, the settings and the shared state

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func build_depot(size: Vector2) -> void:
	# Header and info box grow with the text scale; at 150 % the fixed boxes
	# let the money line touch the title and the details spill out.
	var money_y = maxf(87, 30 + canvas.line_height(32) + 6)
	canvas.depot_header_bottom = maxf(127, money_y + canvas.line_height(20) + 8)
	canvas.positioned_label("ДЕПО  /  ЛЕСНАЯ", Rect2(44, 30, 1000, 50), 32)
	canvas.positioned_label("Творческий режим  ·  деньги и топливо без ограничений" if canvas.model.creative() else "%d монет%s  ·  %d / 10 основных рейсов" % [canvas.model.state.money, ("  ·  долг %d" % int(canvas.model.state.get("debt", 0))) if int(canvas.model.state.get("debt", 0)) > 0 else "", canvas.model.state.chapter], Rect2(46, money_y, 1000, 45), 20)
	# the bolts are money too: the chip "Болты (N)" stands right after the coins and opens the bolt desk
	var money_text = "Творческий режим  ·  деньги и топливо без ограничений" if canvas.model.creative() else "%d монет%s  ·  %d / 10 основных рейсов" % [canvas.model.state.money, ("  ·  долг %d" % int(canvas.model.state.get("debt", 0))) if int(canvas.model.state.get("debt", 0)) > 0 else "", canvas.model.state.chapter]
	var money_width = canvas.font.get_string_size(money_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * float(canvas.settings.text_scale))).x
	# it reads as a part of the same line: no box, the same size, a dot between; the brass colour and the underline on hover tell that it is pressable
	canvas.positioned_label("·", Rect2(46 + money_width + 9, money_y, 20, 45), 20)
	var bolts_chip = Button.new()
	bolts_chip.text = "Болты (%d)" % canvas.model.casino().bolt_total()
	bolts_chip.flat = true
	bolts_chip.focus_mode = Control.FOCUS_ALL
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var plain = StyleBoxEmpty.new()
		plain.content_margin_left = 4
		plain.content_margin_right = 4
		plain.content_margin_top = 0
		plain.content_margin_bottom = 0
		bolts_chip.add_theme_stylebox_override(state_name, plain)
	bolts_chip.add_theme_stylebox_override("focus", canvas.UiKit.box("quiet", "focus"))
	bolts_chip.add_theme_font_size_override("font_size", int(20 * float(canvas.settings.text_scale)))
	bolts_chip.add_theme_color_override("font_color", canvas.UiKit.BRASS_LIGHT)
	bolts_chip.add_theme_color_override("font_hover_color", canvas.UiKit.LAMP)
	bolts_chip.add_theme_color_override("font_pressed_color", canvas.UiKit.LAMP)
	bolts_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bolts_chip.position = Vector2(46 + money_width + 30, money_y + 1)
	bolts_chip.size = Vector2(150 * float(canvas.settings.text_scale), 34 * float(canvas.settings.text_scale))
	bolts_chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bolts_chip.tooltip_text = "Приёмка болтов: сдать шлак за монеты или жетоны"
	bolts_chip.pressed.connect(func():
		canvas.sound.play("ui_click", 0.5)
		canvas.show_modal("receiving"))
	canvas.ui.add_child(bolts_chip)
	var menu_row = HBoxContainer.new()
	menu_row.position = Vector2(size.x - 285, 28)
	menu_row.size = Vector2(245, 50)
	canvas.ui.add_child(menu_row)
	canvas.add_button(menu_row, "☰  Меню", func(): canvas.pause_game())
	var left_width = size.x * 0.46
	var panel_rect = Rect2(left_width + 30, canvas.depot_header_bottom + 28, size.x - left_width - 70, size.y - canvas.depot_header_bottom - 58)
	var right = canvas.panel_at(canvas.ui, panel_rect, true)
	# B1.2b: the four places of the depot are pictures to choose from, not a row of words
	var tiles = HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 6)
	right.add_child(tiles)
	var places = [["Гараж", "Гараж", "garage"], ["Состав", "Состав", "wagons"], ["Улучшения", "Мастерская", "bench"], ["Рейсы", "Доска заказов", "board"], ["Казик", "Казик", "casino"]]
	if canvas.model.records_open(): places.append(["Рекорды", "Рекорды", "records"])
	for entry in places:
		depot_tile(tiles, entry[0], entry[1], entry[2])
	canvas.add_label(right, canvas.tab, 28)
	if not canvas.model.state.active.is_empty():
		canvas.add_label(right, "Активный рейс: " + str(canvas.model.state.active.title), 23)
		canvas.add_label(right, "Груз и отметки доставки сохранены. Продолжи рейс или отмени его без оплаты.")
		canvas.add_button(right, "Продолжить рейс →", func():
			canvas.model.resume_mission()
			canvas.screen = "game"
			canvas.zoom_level = canvas.fit_train_zoom()
			canvas.save_game()
			canvas.rebuild())
		canvas.add_button(right, "Отменить рейс", func(): canvas.confirm("Вернуть груз на склад и отменить рейс без оплаты?", func(): canvas.model.cancel_mission(); canvas.save_game(); canvas.rebuild()))
	elif canvas.tab == "Гараж":
		for id in canvas.Model.VEHICLE_IDS:
			var owned = canvas.model.state.fleet_by_id.has(id)
			var base = canvas.model.vehicle_base(id)
			var label = str(base.name)
			var c = canvas.picture_card(right, id, owned, canvas.GOLD if canvas.model.vehicle_id() == id else canvas.CARD_EDGE)
			canvas.add_label(c, label, 23)
			canvas.add_label(c, str(canvas.VEHICLE_ROLE.get(id, "")), 18, canvas.INK)
			canvas.add_label(c, canvas.vehicle_summary(id), 17, canvas.MUTED_INK)
			if owned:
				canvas.add_button(c, "Выбрана" if canvas.model.vehicle_id() == id else "Выбрать", func():
					if canvas.model.select_vehicle(id):
						canvas.selected_object = id
						canvas.save_game()
						canvas.rebuild()
					else: canvas.notify(canvas.model.message), false, canvas.model.vehicle_id() == id)
			else:
				canvas.add_button(c, "Купить · %d монет" % base.cost, func():
					canvas.confirm("Купить %s за %d? Останется %d монет. Предыдущая машина останется в гараже." % [label, base.cost, maxi(0, int(canvas.model.state.money) - int(base.cost))], func():
						if canvas.model.buy_vehicle(id):
							canvas.selected_object = id
							canvas.save_game()
							canvas.rebuild()
						else: canvas.notify(canvas.model.message)))
	elif canvas.tab == "Казик":
		build_casino_tab(right)
	elif canvas.tab == "Рекорды" and canvas.model.records_open():
		build_records_tab(right)
	elif canvas.tab == "Состав":
		canvas.consist_strip(right)
		canvas.add_label(right, "Вагоны твои: их улучшения сохраняются при перестановке. %s допускает вагонов: %d." % [canvas.vehicle_display_name(), canvas.model.max_wagons(canvas.model.vehicle_id())])
		for id in canvas.model.state.wagons_by_id:
			if id == canvas.Model.TEMP_WAGON: continue
			var stats = canvas.model.object_stats(id)
			var coupled = id in canvas.model.state.consist_ids
			var c = canvas.picture_card(right, id, coupled, canvas.GOLD if coupled else canvas.CARD_EDGE)
			canvas.add_label(c, "%s  ·  %d мест  ·  %d кг%s" % [id, stats.slots, stats.mass, "  ·  в составе" if coupled else ""], 21)
			canvas.add_button(c, "Отцепить " + id if id in canvas.model.state.consist_ids else "Прицепить " + id, func():
				if canvas.model.toggle_wagon(id): canvas.save_game(); canvas.rebuild()
				else: canvas.notify(canvas.model.message))
		var next_wagon = canvas.model.next_wagon_id()
		if next_wagon != "":
			var price = canvas.model.wagon_price(next_wagon)
			canvas.add_button(right, "Купить %s · %d монет" % [next_wagon, price], func(): canvas.confirm("Купить вагон %s за %d? Останется %d монет." % [next_wagon, price, maxi(0, int(canvas.model.state.money) - price)], func():
				if canvas.model.buy_wagon(): canvas.save_game(); canvas.rebuild()
				else: canvas.notify(canvas.model.message)))
		canvas.add_label(right, "Мест в составе: %d. Для финала нужно шесть." % canvas.model.capacity(), 21)
	elif canvas.tab == "Улучшения":
		build_upgrades(right)
	else:
		build_missions(right)
	var info_top = canvas.depot_header_bottom + 24
	canvas.depot_info_rect = Rect2()
	if canvas.tab != "Улучшения":
		canvas.positioned_label(canvas.vehicle_display_name(), Rect2(44, info_top + 7, left_width - 20, 70), 32)
		var stats = canvas.model.object_stats(canvas.model.vehicle_id())
		var details = "%d кг  ·  %d мест" % [canvas.model.train_mass(), canvas.model.capacity()]
		if canvas.model.vehicle_id() == "sail":
			details += "\nПарус · без топлива\nВетер задаёт ход: штиль — стоим\n" + canvas.wind_route_line()
		elif canvas.model.vehicle_id() == "pole":
			details += "\nШест · без топлива\nГрунт решает: глина вязнет, камни скользят"
		elif canvas.model.vehicle_id() == "handcar":
			details += "\nРучной привод · без топлива\nМаховик сохраняет накат"
		else:
			var drive = {"motorcar":"Передачи R / N / 1–5","steam":"Паровой вентиль","pneumatic":"Воздушный вентиль","locomotive":"Регулятор электротяги","zeppelin":"Газ, шаг винта, ручка","jet":"Предохранители, пуск, тяга"}
			details += "\n%s · до %.0f км/ч\n" % [drive[canvas.model.vehicle_id()], canvas.model.top_speed_kmh()] + canvas.energy_text() + "\n" + canvas.forecast_line(canvas.model.current_mission())
		var details_y = maxf(info_top + 88, info_top + 7 + canvas.line_height(32) + 6)
		var details_lines = canvas.wrapped_lines(details, left_width - 20, 19)
		canvas.positioned_label(details, Rect2(46, details_y, left_width - 20, maxf(105, details_lines * canvas.line_height(19))), 19)
		canvas.depot_info_rect = Rect2(22, info_top, left_width - 28, maxf(195, details_y + details_lines * canvas.line_height(19) + 12 - info_top))
	var service = HBoxContainer.new()
	service.position = Vector2(44, size.y - 150)
	service.size = Vector2(left_width - 25, 50)
	canvas.ui.add_child(service)
	var refill = canvas.model.refill_cost() if not canvas.model.human_powered() else 0
	# the button says "full" only when the tank really is full; in the creative mode the refill is free
	var room = canvas.model.tank_missing() > 0.0001
	var refill_text = ({"locomotive": "Зарядить", "pneumatic": "Накачать"}.get(canvas.model.vehicle_id(), "Заправить")) + (" · %d монет" % refill if refill > 0 else (" · бесплатно" if room else " · полон"))
	# a person and the wind need no fuel: no refill button for them
	if not canvas.model.human_powered() and room:
		var refill_button = canvas.add_button(service, refill_text, func():
			if canvas.model.refuel(): canvas.save_game(); canvas.rebuild(); canvas.notify(canvas.model.message if canvas.model.message != "" else "Запас пополнен"); canvas.model.message = ""
			else: canvas.notify(canvas.model.message), not room)
		if canvas.model.vehicle_id() == "locomotive":
			refill_button.icon = canvas.CHARGING_PLUG
			refill_button.add_theme_constant_override("icon_max_width", 22)
	# no separate "Улучшить" button: the workshop is the tab "Мастерская" and a click on the machine itself
	# the bolts stand next to the coins in the header (see build_depot)
	if canvas.model.state.active.is_empty(): canvas.add_button(service, "Просто поехать →", canvas.take_free_ride)   # the one main action of the depot is the order card: this one is quiet
	canvas.positioned_label("Нажми на машину или вагон, чтобы выбрать его улучшения.", Rect2(46, size.y - 83, left_width - 30, 60), 17)

# A big picture button for one place of the depot: the picture and its name are drawn on top of an
# ordinary button, which keeps the click, the hover and the keyboard focus.
# B6.11 g: the tab of the casino in the depot: what is in the pocket, the honest odds, the way in.
func build_casino_tab(right: VBoxContainer) -> void:
	var casino = canvas.model.casino()
	var c = canvas.card(right, canvas.GOLD)
	canvas.add_label(c, "КАЗИК «у стрелки»", 26)
	canvas.add_label(c, "Жетонов: %d  ·  шлака: %d шт.  ·  до гарантированной карточки: %d из %d" % [casino.tokens(), casino.bolt_total(), casino.pity(), int(canvas.model.data.casino.pity_max)], 18)
	canvas.add_label(c, "Михалыч берёт шлак жетонами («деп»), за жетоны крутится колесо «лудки». Из колеса выпадают жетоны, шлак, монеты, ремнаборы, бонуски, а изредка карточка гаджета.", 16, canvas.MUTED_INK)
	canvas.add_button(c, "Войти в казик →", func(): canvas.show_modal("casino"))
	var album_total = canvas.model.data.casino.cards.size() + 4
	var album_have = 0
	for card in canvas.model.data.casino.cards:
		if casino.card_owned(str(card.id)): album_have += 1
	canvas.add_button(c, "Альбом карточек Таро (%d из %d)" % [album_have, album_total], func(): canvas.show_modal("album"))
	var odds: Array = []
	var total = 0.0
	for s in canvas.model.data.casino.sectors: total += float(s.weight)
	var names = {"empty": "пусто", "tokens1": "5 жетонов", "tokens2": "10 жетонов", "junk": "шлак", "coins": "монеты", "repair": "ремнабор", "golden": "золочёный болт", "bonus": "бонуска", "card": "КАРТОЧКА"}
	for s in canvas.model.data.casino.sectors:
		var chance = float(s.weight) / total * 100.0
		if str(s.kind) == "card": chance = casino.card_chance() * 100.0
		odds.append("%s %.1f%%" % [names.get(str(s.id), str(s.id)), chance])
	var rules = canvas.card(right, canvas.CARD_EDGE)
	canvas.add_label(rules, "Честные шансы одной крутки", 20)
	canvas.add_label(rules, ", ".join(odds) + ". Карточка выпадает наверняка, когда счётчик гаранта дойдёт до %d; он растёт на каждой крутке и на каждом рейсе. Всё только за игровые жетоны." % int(canvas.model.data.casino.pity_max), 15, canvas.MUTED_INK)
	canvas.add_button(right, "Приёмка болтов за монеты", func(): canvas.show_modal("receiving"))

# B6.6d: the table of the records (a free ride from the first station to the last and back; every machine has its own line)
func build_records_tab(right: Node) -> void:
	var first = str(canvas.model.data.stations[0].name)
	var last = str(canvas.model.data.stations[canvas.model.data.stations.size() - 1].name)
	canvas.add_label(right, "Лучшее время между конечными станциями (%s и %s) и высшая скорость. Выезжай без заказа, разгоняйся и останавливайся на конечной." % [first, last], 19, canvas.MUTED_INK)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)
	var scale_text = float(canvas.settings.text_scale)
	for head in ["Машина", "Туда", "Обратно", "Скорость"]:
		var h = canvas.add_label(grid, head, 18, canvas.GOLD)
		if head == "Машина": h.custom_minimum_size.x = 250.0 * scale_text
	for row in canvas.model.record_rows():
		var tint = canvas.INK if row.owned else canvas.MUTED_INK
		canvas.add_label(grid, str(row.name), 18, tint)
		canvas.add_label(grid, canvas.Records.time_text(float(row.a_f)), 19, tint)
		canvas.add_label(grid, canvas.Records.time_text(float(row.f_a)), 19, tint)
		canvas.add_label(grid, ("%d км/ч" % roundi(float(row.top_kmh))) if float(row.top_kmh) > 0.0 else "—", 19, tint)

func depot_tile(parent: Node, tab_name: String, caption: String, icon: String) -> Button:
	var selected = canvas.tab == tab_name
	var button = Button.new()
	# a strip of words instead of 96-px picture tiles (the pictures return when the icons of the interface kit are connected): it gives the height back to the list
	button.custom_minimum_size = Vector2(0, 40.0 * float(canvas.settings.text_scale))
	button.text = caption
	button.add_theme_font_size_override("font_size", int(18 * float(canvas.settings.text_scale)))
	button.add_theme_color_override("font_disabled_color", canvas.UiKit.LAMP)   # the chosen tab is inert but lit
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = caption
	button.disabled = selected
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var kit_state = "selected" if selected and state != "focus" else ("normal" if state == "disabled" else state)
		button.add_theme_stylebox_override(state, canvas.UiKit.box("tab", kit_state))
	button.pressed.connect(func():
		canvas.sound.play("ui_click", 0.5)
		canvas.tab = tab_name
		canvas.rebuild())
	parent.add_child(button)
	return button

func draw_depot_icon(icon_canvas: Control, icon: String, caption: String, selected: bool, hovered: bool) -> void:
	var size = icon_canvas.size
	var color = canvas.GOLD if selected else (Color("fff2c8") if hovered else canvas.PAPER)
	var dark = Color("1a2622")
	var unit = minf(size.x, size.y) / 96.0
	var centre = Vector2(size.x * 0.5, size.y * 0.40)
	var line = maxf(1.5, 2.2 * unit)
	if icon == "bench":
		# a gear and a spanner
		var gear = centre + Vector2(-10, 2) * unit
		for i in range(8):
			var a = TAU * float(i) / 8.0
			icon_canvas.draw_line(gear + Vector2.from_angle(a) * 12.0 * unit, gear + Vector2.from_angle(a) * 17.0 * unit, color, 5.0 * unit)
		icon_canvas.draw_arc(gear, 12.0 * unit, 0, TAU, 28, color, line * 1.4, true)
		icon_canvas.draw_circle(gear, 4.5 * unit, color)
		icon_canvas.draw_line(centre + Vector2(4, 22) * unit, centre + Vector2(26, -8) * unit, color, 5.0 * unit)
		icon_canvas.draw_arc(centre + Vector2(27, -10) * unit, 7.0 * unit, deg_to_rad(40), deg_to_rad(320), 16, color, 4.0 * unit, true)
	elif icon == "board":
		var board = Rect2(centre + Vector2(-26, -20) * unit, Vector2(52, 40) * unit)
		icon_canvas.draw_rect(board, color, false, line * 1.4)
		for note in [Rect2(-20, -14, 14, 15), Rect2(-2, -15, 14, 12), Rect2(-12, 4, 18, 11), Rect2(14, -12, 9, 22)]:
			icon_canvas.draw_rect(Rect2(centre + note.position * unit, note.size * unit), color)
			icon_canvas.draw_circle(centre + (note.position + Vector2(note.size.x * 0.5, 2.0)) * unit, 1.6 * unit, dark)
	elif icon == "garage":
		icon_canvas.draw_rect(Rect2(centre + Vector2(-26, -4) * unit, Vector2(40, 16) * unit), color)
		icon_canvas.draw_rect(Rect2(centre + Vector2(-26, -20) * unit, Vector2(16, 16) * unit), color)
		icon_canvas.draw_rect(Rect2(centre + Vector2(6, -16) * unit, Vector2(7, 12) * unit), color)
		icon_canvas.draw_rect(Rect2(centre + Vector2(-23, -16) * unit, Vector2(10, 7) * unit), dark)
		for x in [-17.0, 4.0]:
			icon_canvas.draw_circle(centre + Vector2(x, 15) * unit, 7.0 * unit, color)
			icon_canvas.draw_circle(centre + Vector2(x, 15) * unit, 2.5 * unit, dark)
	elif icon == "wagons":
		for x in [-30.0, 3.0]:
			icon_canvas.draw_rect(Rect2(centre + Vector2(x, -6) * unit, Vector2(27, 14) * unit), color)
			icon_canvas.draw_circle(centre + Vector2(x + 6, 14) * unit, 5.0 * unit, color)
			icon_canvas.draw_circle(centre + Vector2(x + 21, 14) * unit, 5.0 * unit, color)
		icon_canvas.draw_line(centre + Vector2(-3, 2) * unit, centre + Vector2(3, 2) * unit, color, line * 1.6)
	elif icon == "records":
		# a stopwatch with a button on top
		icon_canvas.draw_arc(centre + Vector2(0, 3) * unit, 19.0 * unit, 0, TAU, 32, color, line * 1.6, true)
		icon_canvas.draw_rect(Rect2(centre + Vector2(-4, -22) * unit, Vector2(8, 5) * unit), color)
		icon_canvas.draw_line(centre + Vector2(0, 3) * unit, centre + Vector2(0, -10) * unit, color, line * 1.4)
		icon_canvas.draw_line(centre + Vector2(0, 3) * unit, centre + Vector2(9, 8) * unit, color, line)
		icon_canvas.draw_circle(centre + Vector2(0, 3) * unit, 2.5 * unit, color)
	elif icon == "casino":
		# a wheel with spokes and a flag on top
		icon_canvas.draw_arc(centre + Vector2(0, 2) * unit, 20.0 * unit, 0, TAU, 32, color, line * 1.6, true)
		for i in range(8):
			var a = TAU * float(i) / 8.0
			icon_canvas.draw_line(centre + Vector2(0, 2) * unit, centre + Vector2(0, 2) * unit + Vector2.from_angle(a) * 20.0 * unit, color, line)
		icon_canvas.draw_circle(centre + Vector2(0, 2) * unit, 4.5 * unit, color)
		icon_canvas.draw_colored_polygon(PackedVector2Array([centre + Vector2(-5, -24) * unit, centre + Vector2(5, -24) * unit, centre + Vector2(0, -16) * unit]), color)
	var caption_size = int(round(15.0 * float(canvas.settings.text_scale)))
	icon_canvas.draw_string(canvas.font, Vector2(0, size.y - 11.0 * unit), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, caption_size, color)

# A picture of the workshop standing on a point (bottom middle) with the given height.
func depot_prop(name: String, base: Vector2, height: float, tint: Color = Color(0.92, 0.88, 0.82)) -> void:
	var tex: Texture2D = canvas.DEPOT_PROP[name]
	var width = height * float(tex.get_width()) / float(tex.get_height())
	canvas.draw_texture_rect(tex, Rect2(base - Vector2(width * 0.5, height), Vector2(width, height)), false, tint)

func draw_depot_interior(size: Vector2) -> void:
	var floor_y = canvas.rail_baseline()
	# the wall: a tile as high as the wall, repeated along; the dark top and bottom keep the lamplight in the middle
	var wall_w = floor_y * float(canvas.DEPOT_WALL.get_width()) / float(canvas.DEPOT_WALL.get_height())
	var x = -wall_w * 0.35
	while x < size.x:
		canvas.draw_texture_rect(canvas.DEPOT_WALL, Rect2(x, 0, wall_w + 1.0, floor_y), false, Color(0.74, 0.66, 0.58))
		x += wall_w
	for i in range(8):
		var t = float(i) / 7.0
		canvas.draw_rect(Rect2(0, floor_y * 0.80 + floor_y * 0.20 * t, size.x, floor_y * 0.20 / 8.0 + 1.0), Color(0.02, 0.01, 0.0, 0.05 + 0.25 * t))
		canvas.draw_rect(Rect2(0, floor_y * 0.30 * (1.0 - t), size.x, floor_y * 0.30 / 8.0 + 1.0), Color(0.02, 0.01, 0.0, 0.05 + 0.20 * t))
	# the rafters under the roof, the lamps hang on their rings (one ring in the middle of every tile)
	var raft_h = floor_y * 0.27
	var raft_w = raft_h * float(canvas.DEPOT_RAFTERS.get_width()) / float(canvas.DEPOT_RAFTERS.get_height())
	var raft_x0 = size.x * 0.17 - raft_w * 0.5
	var rx = raft_x0
	while rx < size.x:
		canvas.draw_texture_rect(canvas.DEPOT_RAFTERS, Rect2(rx, 0, raft_w + 1.0, raft_h), false, Color(0.80, 0.72, 0.64))
		rx += raft_w
	# the things of the wall go below the info card and left of the tab panel; the machine stands in front of them
	var free_top = maxf(canvas.depot_info_rect.end.y + 12.0, raft_h + 14.0)
	var free_left = 24.0
	var free_right = size.x * 0.47
	var room = floor_y - 30.0 - free_top
	if room > 70.0:
		var tools_h = minf(room * 0.62, 150.0)
		depot_prop("tools", Vector2(free_left + tools_h * 0.55, free_top + tools_h + 4.0), tools_h)
		var shelf_h = minf(room * 0.44, 110.0)
		depot_prop("shelf", Vector2(free_right * 0.58, free_top + shelf_h + 10.0), shelf_h)
		if room > 140.0:
			depot_prop("window", Vector2(free_right - 60.0, free_top + minf(room * 0.75, 190.0)), minf(room * 0.75, 190.0))
	# the floor things stand on the floor line behind the machine
	depot_prop("barrel", Vector2(free_left + 30.0, floor_y - 4.0), minf(floor_y * 0.20, 120.0))
	depot_prop("ladder", Vector2(size.x * 0.455, floor_y - 4.0), minf(floor_y * 0.40, 230.0))
	# the lamps: a chain from the ring, the shade, a pool of warm light on the wall
	var lamp_y = maxf(free_top + 40.0, raft_h + 90.0)
	var ring_x = raft_x0 + raft_w * 0.5
	while ring_x < free_right + 80.0:
		if ring_x > 30.0:
			var lamp_h = minf(floor_y * 0.19, 120.0)
			canvas.draw_line(Vector2(ring_x, raft_h - 6.0), Vector2(ring_x, lamp_y - lamp_h + 10.0), Color("1a120c"), 3.0)
			var glow = floor_y * 0.95
			canvas.draw_texture_rect(canvas.DEPOT_GLOW, Rect2(Vector2(ring_x, lamp_y - lamp_h * 0.2) - Vector2(glow, glow) * 0.5, Vector2(glow, glow)), false, Color(1, 1, 1, 0.85))
			depot_prop("lamp", Vector2(ring_x, lamp_y), lamp_h, Color.WHITE)
		ring_x += raft_w
	# the floor line and a shadow under the wall
	canvas.draw_rect(Rect2(0, floor_y - 10, size.x, 10), Color(0, 0, 0, 0.30))

func build_upgrades(right: VBoxContainer) -> void:
	var row = HBoxContainer.new()
	right.add_child(row)
	var objects = [canvas.model.vehicle_id()] + canvas.model.state.wagons_by_id.keys().filter(func(id): return id != canvas.Model.TEMP_WAGON)
	if not canvas.selected_object in objects:
		canvas.selected_object = canvas.model.vehicle_id()
	for id in objects:
		canvas.add_button(row, "Машина" if not id.begins_with("W") else id, func(): canvas.selected_object = id; canvas.rebuild(), false, id == canvas.selected_object)
	var before = canvas.model.object_stats(canvas.selected_object)
	canvas.add_label(right, "Выбран: " + (canvas.selected_object if canvas.selected_object.begins_with("W") else canvas.vehicle_display_name()), 22)
	canvas.add_label(right, "%d мест · %d кг · тормоз %d Н" % [before.slots, before.mass, before.brake], 18)
	if canvas.selected_object.begins_with("W"):
		canvas.add_label(right, "Качение: %.4f · защита посуды: %d%%" % [before.rolling, roundi((1.0 - float(before.shock)) * 100)], 18)
	build_wear_card(right)
	var branches: Array = []
	for branch in canvas.model.data.upgrade_catalog:
		if branch.target_type != ("wagon" if canvas.selected_object.begins_with("W") else canvas.selected_object):
			continue
		if str(branch.id) == canvas.workshop_branch: branches.push_front(branch)
		else: branches.append(branch)
	if not branches.is_empty(): canvas.add_label(right, "Укажи деталь на машине слева или выбери здесь.", 17, canvas.MUTED_INK)
	for branch in branches:
		var lv = int(canvas.model.object_state(canvas.selected_object).levels.get(branch.id, 0))
		var name = upgrade_branch_name(canvas.selected_object, branch)
		var levels = int(branch.get("levels", 2))
		var gadget = bool(branch.get("gadget", false))
		var c = canvas.card(right, canvas.GOLD if str(branch.id) == canvas.workshop_branch else (canvas.GREEN if lv >= levels else (Color("c9a24e") if gadget else canvas.CARD_EDGE)))
		var tarot = canvas.model.casino().card_for_upgrade(str(branch.id)) if gadget else {}
		if not tarot.is_empty(): gadget_icon(c, str(tarot.id))
		canvas.add_label(c, ("ГАДЖЕТ  ·  %s  ·  %s" % [name, "● установлен" if lv >= 1 else "○"]) if gadget else ("%s  ·  %s" % [name, ["○ ○", "● ○", "● ●"][lv]]), 22)
		if lv < levels:
			var preview = upgrade_preview(canvas.selected_object, branch)
			canvas.add_label(c, preview, 17, canvas.MUTED_INK)
			if not tarot.is_empty():
				var card_id = str(tarot.id)
				if canvas.model.casino().card_owned(card_id):
					canvas.add_button(c, "Установить по карте", func():
						if canvas.model.casino().install(card_id):
							canvas.save_game()
							canvas.rebuild()
						else:
							canvas.notify("Гаджет можно установить в депо до погрузки"), not canvas.model.depot_editable())
					continue
				canvas.add_label(c, "Карта ещё не найдена", 17, canvas.MUTED_INK)
			if gadget and bool(canvas.model.data.casino.cards_only): continue
			var cost = int(branch.level_costs[lv])
			canvas.add_button(c, ("Установить гаджет · %d монет" % cost) if gadget else ("Улучшить до %s · %d монет" % ["I" if lv == 0 else "II", cost]), func():
				var id = canvas.selected_object
				canvas.confirm("%s: %s\nЦена %d. Останется %d монет." % [id, preview, cost, maxi(0, int(canvas.model.state.money) - cost)], func():
					if canvas.model.upgrade(id, branch.id): canvas.save_game(); canvas.rebuild()
					else: canvas.notify(canvas.model.message)))
			var plan = canvas.model.casino().bolt_plan(cost)
			if not gadget and int(plan.count) > 0:
				canvas.add_button(c, "Доплатить болтами · %d монет + %d болтов" % [cost - int(plan.coins), int(plan.count)], func():
					var id = canvas.selected_object
					canvas.confirm("%s: %s\nПлатишь %d монет и %d болтов вместо %d монет." % [id, preview, cost - int(plan.coins), int(plan.count), cost], func():
						if canvas.model.upgrade(id, branch.id, false, true): canvas.save_game(); canvas.rebuild()
						else: canvas.notify(canvas.model.message)))
		else:
			if not tarot.is_empty() and str(tarot.id) in canvas.model.casino().st().installed:
				var card_id = str(tarot.id)
				canvas.add_button(c, "Снять карту", func():
					if canvas.model.casino().uninstall(card_id):
						canvas.save_game()
						canvas.rebuild()
					else:
						canvas.notify("Гаджет можно снять в депо до погрузки"), not canvas.model.depot_editable())
			elif not gadget:
				canvas.add_label(c, "Максимальный уровень", 17, canvas.GREEN)

# the picture of a gadget (the same one as on the back of its Tarot card) above its card in the workshop
func gadget_icon(box: VBoxContainer, card_id: String) -> void:
	var path = "res://assets/art_kazik/gadget_icons/%s.png" % card_id
	if not ResourceLoader.exists(path): return
	var icon = TextureRect.new()
	icon.texture = load(path)
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

func junk_icon(parent: Node, id: String, size: float = 40.0) -> void:
	var holder = Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	parent.add_child(holder)
	var name = str(canvas.JUNK_ICON.get(id, ""))
	var path = "res://assets/art_kazik/%s.png" % name
	if name == "" or not ResourceLoader.exists(path): return
	var icon = TextureRect.new()
	icon.texture = load(path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon)

# B6.11 c: the receiving desk: the bag with the price of every kind, sell one or all, or all the common ones at once.
func build_receiving(box: VBoxContainer) -> void:
	var casino = canvas.model.casino()
	canvas.add_label(box, "Приёмка болтов", 34)
	canvas.add_label(box, "Монет: %d · жетонов: %d\nПлатит мало: болты лучше беречь для ремонта, улучшений и лудки." % [int(canvas.model.state.money), casino.tokens()], 19)
	var bag = casino.bag()
	if bag.is_empty(): canvas.add_label(box, "В мешке пусто. Болты находят на дороге: у рельса блестит, а рейс приносит хлам.", 21)
	for entry in bag:
		var id = str(entry.id)
		var rare = str(entry.kind) == "rare"
		var line = HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		box.add_child(line)
		junk_icon(line, id)
		var label = canvas.add_label(line, "%s ×%d" % [entry.name, int(entry.count)], 20)
		label.custom_minimum_size.x = 290
		var each = canvas.add_label(line, "по %d" % int(entry.coins), 18, canvas.MUTED_INK)
		each.custom_minimum_size.x = 70
		canvas.add_button(line, "Продать 1", func(): sell_bolts(id, 1, rare))
		canvas.add_button(line, "Все · %d монет" % (int(entry.coins) * int(entry.count)), func(): sell_bolts(id, canvas.model.casino().junk_count(id), rare))
	var common = 0
	for entry in bag:
		if str(entry.kind) != "rare": common += int(entry.coins) * int(entry.count)
	if common > 0:
		canvas.add_button(box, "Продать всё обычное · %d монет (редкое останется)" % common, func():
			var got = canvas.model.casino().sell_common_here()
			canvas.notify("Продано: +%d монет" % got if got > 0 else canvas.model.message)
			canvas.save_game()
			canvas.rebuild())
	canvas.add_button(box, "Закрыть", canvas.close_modal)

func sell_bolts(id: String, count: int, rare: bool) -> void:
	var def = canvas.model.casino().junk_def(id)
	var action = func():
		var got = canvas.model.casino().sell_here(id, count)
		canvas.notify("Продано: +%d монет" % got if got > 0 else canvas.model.message)
		canvas.save_game()
		canvas.rebuild()
	if rare:
		canvas.confirm("%s стоит %d жетонов в казике, а здесь дают %d монет. Продать?" % [def.name, int(def.tokens), int(def.coins) * count], action)
	else:
		action.call()

# B5.6: the window "Состояние": the nodes of the chosen machine or wagon with their bars, and the ways to mend them.
func wear_color(value: float) -> Color:
	return Color("6fae5a") if value >= 0.7 else (Color("d6a73c") if value >= 0.4 else Color("c9473d"))

func build_wear_card(right: VBoxContainer) -> void:
	if not canvas.Model.wear_rules: return
	var wear = canvas.model.wear()
	var id = canvas.selected_object
	var nodes = wear.nodes_of(id)
	if nodes.is_empty(): return
	var worst = wear.worst(id)
	var c = canvas.card(right, wear_color(float(worst.cond)) if float(worst.cond) < 0.7 else canvas.CARD_EDGE)
	canvas.add_label(c, "Состояние  ·  " + ("всё в порядке" if float(worst.cond) >= 0.7 else "слабое место: " + str(worst.name).to_lower()), 22)
	# 1.4.6: in the creative mode the whole fleet is mended in one click
	var fleet = [canvas.model.vehicle_id()] + canvas.model.state.wagons_by_id.keys()
	if canvas.model.creative() and wear.needs_repair(fleet):
		canvas.add_button(c, "Починить всё", func():
			var mended = canvas.model.wear().repair_all([canvas.model.vehicle_id()] + canvas.model.state.wagons_by_id.keys())
			canvas.notify("Починено узлов: %d" % mended)
			canvas.save_game()
			canvas.rebuild())
	for def in nodes:
		var node = str(def.id)
		var value = wear.condition(id, node)
		var line = HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		c.add_child(line)
		var label = canvas.add_label(line, "%s  %d%%" % [def.name, roundi(value * 100.0)], 17)
		label.custom_minimum_size.x = 215
		var bar = ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = value * 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(110, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", canvas.style(wear_color(value), wear_color(value), 3))
		bar.add_theme_stylebox_override("background", canvas.style(Color(0.13, 0.17, 0.15), canvas.CARD_EDGE, 3))
		line.add_child(bar)
		if value < 0.999 and not canvas.model.creative():   # the creative mode mends everything with the one button above
			var gain = wear.bolts_gain(id, node)
			canvas.add_button(line, "Болтами +%d%%" % roundi(gain * 100.0) if gain > 0.0 else "Болтов нет", func():
				var got = canvas.model.wear().repair_bolts_auto(id, node)
				canvas.notify("Починено болтами: +%d%%" % roundi(got * 100.0))
				canvas.save_game()
				canvas.rebuild(), gain <= 0.0)
			var price = wear.money_price(id, node, 1.0 - value)
			canvas.add_button(line, "За %d монет" % price, func():
				var got = canvas.model.wear().repair_with_money(id, node, 1.0 - float(canvas.model.wear().condition(id, node)))
				canvas.notify("Починено за монеты: +%d%%" % roundi(got * 100.0) if got > 0.0 else "Не хватает монет")
				canvas.save_game()
				canvas.rebuild(), int(canvas.model.state.money) < 3 and not canvas.model.creative())
	if canvas.model.creative():
		canvas.add_label(c, "Творческий режим: узлы изнашиваются, «Починить всё» чинит бесплатно, в рейсе тоже (пауза).", 15, canvas.MUTED_INK)
		return
	var kits = int(canvas.model.casino().st().repair_kits)
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	c.add_child(footer)
	var total = wear.full_repair_price(id)
	if total > 0:
		canvas.add_button(footer, "Починить всё · %d монет" % total, func():
			for def in canvas.model.wear().nodes_of(id): canvas.model.wear().repair_with_money(id, str(def.id), 1.0)
			canvas.notify("Всё починено, что хватило денег")
			canvas.save_game()
			canvas.rebuild())
	if kits > 0 and float(worst.cond) < 0.999:
		canvas.add_button(footer, "Ремнабор +25%% · есть %d" % kits, func():
			var got = canvas.model.wear().repair_with_kit(id, str(canvas.model.wear().worst(id).node))
			canvas.notify("Ремнабор: +%d%%" % roundi(got * 100.0))
			canvas.save_game()
			canvas.rebuild())
	canvas.add_label(c, "Узлы изнашиваются от езды и ошибок. 1% стоит 3 монеты; болты: свои +5%, общие +2%, редкие +4%. На линии чинит только мастерская станции (до 50%)." , 15, canvas.MUTED_INK)

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
		"shaft": return Vector2(length * 0.15, 1.5)
		"tip": return Vector2(front, 0.5)
		"cloth": return Vector2(length * 0.25, 2.4)
		"rigging": return Vector2(-length * 0.15, 1.6)
		"boiler": return Vector2(length * 0.25, 1.1)
		"firebox": return Vector2(-length * 0.2, 1.0)
		"pipes": return Vector2(length * 0.05, 0.6)
	return Vector2(0.0, 0.8)

# B1.2c: pulsing markers on the machine, one for each part that can be improved, with its level.
func draw_workshop_spots(id: String, transform: Transform2D) -> void:
	var spec = canvas.Geometry.body(id)
	var length = float(spec.length_m)
	var centre = float(spec.region_px[0]) + float(spec.region_px[2]) * 0.5
	var axles: Array = []
	for axle in spec.axles_px: axles.append((float(axle[0]) - centre) / float(spec.region_px[2]) * length)
	var radius = float(spec.wheel_diameter_m) * 0.5
	var target = "wagon" if id.begins_with("W") else id
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	for branch in canvas.model.data.upgrade_catalog:
		if branch.target_type != target or branch.get("gadget", false): continue
		var part = str(branch.id).get_slice("_", 1)
		var place = workshop_spot_place(part, length, axles)
		var pos = transform * (Vector2(place.x, -(place.y - radius)) * canvas.ArtV3.PX)
		var level = int(canvas.model.object_state(id).levels.get(branch.id, 0))
		var picked = str(branch.id) == canvas.workshop_branch
		var pulse = 0.5 + 0.5 * sin(canvas.time * 3.0 + place.x)
		canvas.draw_circle(pos, 13.0, Color(canvas.INK, 0.9))
		canvas.draw_arc(pos, 15.0 + 2.5 * pulse, 0, TAU, 28, canvas.GOLD if picked else Color(canvas.PAPER, 0.85), 2.2 if picked else 1.6, true)
		for k in range(2):
			canvas.draw_circle(pos + Vector2(-5.0 + 10.0 * float(k), 0), 3.4, canvas.GOLD if k < level else Color(canvas.PAPER, 0.35))
		canvas.workshop_hits.append({"branch": str(branch.id), "position": pos, "label": upgrade_branch_name(id, branch)})
	var spot = nearest_workshop_spot(canvas.get_global_mouse_position())
	if spot.is_empty():
		for hit in canvas.workshop_hits:
			if hit.branch == canvas.workshop_branch:
				spot = hit
				break
	if not spot.is_empty():
		var label: String = spot.label
		var width = canvas.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var at: Vector2 = spot.position + Vector2(-width * 0.5, -25)
		at.x = maxf(at.x, 10.0)
		canvas.draw_rect(Rect2(at + Vector2(-6, -17), Vector2(width + 12, 23)), Color(canvas.INK, 0.94))
		canvas.draw_string(canvas.font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, canvas.GOLD)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func nearest_workshop_spot(point: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var distance = 26.0
	for hit in canvas.workshop_hits:
		var candidate = point.distance_to(hit.position)
		if candidate < distance:
			nearest = hit
			distance = candidate
	return nearest

# D9: a stat of an upgrade card in words and not as raw arrays: numbers as "before → after (+x%)", a row of numbers
# (one per gear) as the mean change "+x% on every gear".
# 100.0 -> "100", 2.5 -> "2.5", 0.125 -> "0.13"
func num_text(v: float) -> String:
	if absf(v - roundf(v)) < 0.005: return str(int(roundf(v)))
	var s = "%.2f" % v
	while s.ends_with("0"): s = s.substr(0, s.length() - 1)
	return s

func stat_change(before, after) -> String:
	if before is Array and after is Array:
		var sum_before = 0.0
		var sum_after = 0.0
		for v in before: sum_before += float(v)
		for v in after: sum_after += float(v)
		if sum_before <= 0.0: return "изменится"
		return "%+d%% на всех передачах" % int(round((sum_after / sum_before - 1.0) * 100.0))
	var fb = float(before)
	var fa = float(after)
	var text = "%s → %s" % [num_text(fb), num_text(fa)]
	if absf(fb) > 0.0001: text += " (%+d%%)" % int(round((fa / fb - 1.0) * 100.0))
	return text

func upgrade_preview(id: String, branch: Dictionary) -> String:
	var object = canvas.model.object_state(id)
	var lv = int(object.levels.get(branch.id, 0))
	var before = canvas.model.object_stats(id)
	object.levels[branch.id] = lv + 1
	var after = canvas.model.object_stats(id)
	object.levels[branch.id] = lv
	var parts: Array = []
	for key in ["slots", "mass", "brake", "tank", "power", "rolling", "shock", "traction", "speeds"]:
		if not before.has(key) or before[key] == after[key]: continue
		var label = {"slots": "Места", "mass": "Масса, кг", "brake": "Тормоз, Н", "tank": "Батарея, кВт·ч" if id == "locomotive" else "Бак, л", "power": "Мощность, Вт", "rolling": "Качение", "shock": "Повреждение посуды", "traction": "Тяга, Н", "speeds": "Скорость, м/с"}[key]
		parts.append("%s: %s" % [label, stat_change(before[key], after[key])])
	# parts of a machine that are not a stat of the table above: the strength of the push, the sail, the fire...
	var before_ef = canvas.model.effects(id)
	object.levels[branch.id] = lv + 1
	var after_ef = canvas.model.effects(id)
	object.levels[branch.id] = lv
	var words = {"steam_superheater": "Пароперегреватель: угля на 30% меньше, пара на 10% больше, но разогревается дольше", "steam_stoker": "Механический кочегар: сам подбрасывает уголь и держит огонь ровно, но тратит на 20% больше", "sail_spinnaker": "Спинакер: тяга на попутном ветре ×1,8 (в бейдевинд хуже, рвётся раньше)", "sail_autopilot": "Парус сам держит угол, шкот фиксируется в любом положении (80% тяги)", "pole_force_multiplier": "Сила толчка", "zep_power_multiplier": "Мощность мотора", "sail_oars": "Вёсла: на штиле можно грести (медленно, но всегда доедешь)", "zep_flaps_gadget": "Закрылки: взлёт на скорости ниже на 20%, сопротивление в воздухе +5%", "zep_trim": "Триммер: держит высоту, на которой включён, ручка не нужна", "zep_wing_multiplier": "Площадь крыла (взлёт при меньшей скорости)", "pole_grip_multiplier": "Хватка наконечника", "sail_area_multiplier": "Площадь паруса", "sail_hold_multiplier": "Держит порыв", "steam_power_multiplier": "Пар", "fire_burn_multiplier": "Расход угля в топке", "water_capacity_multiplier": "Запас воды", "frost_multiplier": "Рост инея"}
	for key in words:
		if not after_ef.has(key): continue
		if after_ef[key] is bool or key in ["sail_spinnaker", "steam_superheater", "steam_stoker"]: parts.append(str(words[key]))
		else: parts.append("%s: ×%.2f → ×%.2f" % [words[key], float(before_ef.get(key, 1.0)), float(after_ef[key])])
	return "\n".join(parts)

func build_missions(right: VBoxContainer) -> void:
	if canvas.model.creative():
		# Sandbox: every order of the career is open at any time, and as often as you like.
		canvas.add_label(right, "Любые рейсы, любые машины", 22)
		for index in range(canvas.model.data.missions.size()):
			var open_mission = canvas.model.scaled_mission(canvas.model.data.missions[index])
			mission_notice(right, open_mission, "ОТКРЫТЫЙ РЕЙС  ·  %s" % open_mission.id, "К погрузке →", index == 0)
		canvas.add_label(right, "Свободные рейсы", 22)
		for offer in canvas.model.free_offers():
			mission_notice(right, offer, "СВОБОДНЫЙ РЕЙС", "Взять")
		return
	var mission = canvas.model.current_mission()
	var offers: Array = canvas.model.free_offers()
	if not mission.is_empty():
		mission_notice(right, mission, "ОСНОВНОЙ РЕЙС  ·  %s" % mission.id, "К погрузке →", true)
	else:
		canvas.add_label(right, "Линия работает. Выбирай следующую перевозку.", 23)
	# one main order in sight; the free trips are under a fold (when there is no main order they are the choice itself and stay open)
	var open = canvas.free_trips_open or mission.is_empty()
	if not mission.is_empty():
		canvas.add_button(right, "Свободные рейсы (%d) %s" % [offers.size(), "▴" if canvas.free_trips_open else "▾"], func(): canvas.free_trips_open = not canvas.free_trips_open; canvas.rebuild(), false, false, &"QuietAction")
	else:
		canvas.add_label(right, "Свободные рейсы", 22)
	if open:
		for offer in offers:
			mission_notice(right, offer, "СВОБОДНЫЙ РЕЙС", "Взять · %d монет" % offer.reward)

# B1.2d: an order is a notice pinned to the board: where it goes, what it carries, what it pays, how
# hard the road is, and the button that takes it.
func mission_notice(parent: Node, mission: Dictionary, kind: String, take_text: String, highlighted: bool = false) -> void:
	var problem = canvas.model.mission_error(mission)
	var notice = canvas.card(parent, canvas.GOLD if highlighted else canvas.CARD_EDGE)
	var top = HBoxContainer.new()
	notice.add_child(top)
	canvas.add_label(top, kind, 17, Color("755921"))
	var far = canvas.model.mission_far_s(mission)
	var distance = canvas.add_label(top, "%.1f км" % (far / 1000.0), 17, canvas.MUTED_INK)
	distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	canvas.add_label(notice, str(mission.title), 22)
	var places: Array = [canvas.model.station_name("A")]
	for stop in mission.dropoffs:
		var name = canvas.model.station_name(stop.station)
		if places[places.size() - 1] != name: places.append(name)
	canvas.add_label(notice, " → ".join(places), 16, canvas.INK)
	var goods: Array = []
	for stop in mission.dropoffs:
		for pair in stop.cargo: goods.append("%s × %d" % [canvas.model.cargo_base(pair[0]).name, pair[1]])
	canvas.add_label(notice, "Груз: " + ", ".join(goods), 17, canvas.MUTED_INK)
	var grade = canvas.route_climb_to(far)
	var hard = grade > (0.03 if canvas.model.human_powered() else 0.045)
	var road_text = "Ровный путь" if grade <= 0.02 else ("Подъёмы до %.1f%%" % (grade * 100.0))
	if hard: road_text = "Крутой подъём %.1f%%" % (grade * 100.0)
	var bottom = HBoxContainer.new()
	notice.add_child(bottom)
	canvas.add_label(bottom, "Награда до %d" % int(mission.reward), 20, canvas.GOLD.darkened(0.25))
	if canvas.Model.order_rules and not canvas.model.creative():
		var minutes = canvas.model.mission_budget_s(mission) / 60.0
		var rule = "Срок %d:%02d езды: раньше +10–25%%, опоздал штраф" % [int(minutes), int(fposmod(minutes, 1.0) * 60.0)]
		if not mission.get("free", false): rule = "Срок %d:%02d езды: раньше +10–25%%, опоздал рейс отменится" % [int(minutes), int(fposmod(minutes, 1.0) * 60.0)]
		canvas.add_label(notice, rule, 17, canvas.MUTED_INK)
	var road = canvas.add_label(bottom, road_text, 17, canvas.RED if hard else (canvas.GREEN if grade <= 0.02 else canvas.MUTED_INK))
	road.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if problem != "": canvas.add_label(notice, problem, 16, canvas.RED)
	canvas.add_button(notice, take_text, func(): canvas.take_mission(mission), problem != "", false, &"PrimaryAction" if highlighted else &"Button")
