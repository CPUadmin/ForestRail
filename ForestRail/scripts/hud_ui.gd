extends RefCounted
# Помощник main.gd (1.3.7): надписи поверх дороги: заказ, подсказки, энергия, кнопки действий.
# Работает через canvas (main.gd), как depot_ui.gd.

var canvas = null   # main.gd

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func build_hud(size: Vector2) -> void:
	canvas.instruments = canvas.Instruments.new()
	canvas.instruments.game = canvas
	canvas.instruments.size = size
	canvas.ui.add_child(canvas.instruments)
	canvas.mini_button = Button.new()
	canvas.mini_button.position = canvas.instruments.mini_rect().position
	canvas.mini_button.size = canvas.instruments.mini_rect().size
	canvas.mini_button.flat = true
	canvas.mini_button.tooltip_text = "Открыть карту линии [M]"
	for state in ["normal","hover","pressed","focus"]: canvas.mini_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	canvas.mini_button.pressed.connect(canvas.toggle_map)
	canvas.ui.add_child(canvas.mini_button)
	var buttons_width = ((210 if canvas.model.grapnel_installed() else 70) if canvas.model.human_powered() else (210 if canvas.model.burst_gadget() != "" else 70))*float(canvas.settings.text_scale)   # the row holds the menu button and the gadget buttons
	canvas.hud = canvas.positioned_label("", Rect2(34, 12, size.x - buttons_width - 90, 42), 20)
	canvas.hud.autowrap_mode=TextServer.AUTOWRAP_OFF
	canvas.hud.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var pause_row = HBoxContainer.new()
	pause_row.position = Vector2(size.x - buttons_width - 34, 10)
	pause_row.size = Vector2(buttons_width, 46)
	pause_row.add_theme_constant_override("separation",10)
	canvas.ui.add_child(pause_row)
	canvas.map_button = canvas.mini_button
	canvas.burst_button = null
	if canvas.model.burst_gadget() != "": canvas.burst_button = canvas.add_button(pause_row, canvas.burst_button_text(), canvas.try_burst)
	canvas.grapnel_button = null
	if canvas.model.grapnel_installed(): canvas.grapnel_button = canvas.add_button(pause_row, canvas.grapnel_button_text(), canvas.try_grapnel)
	# the cab is entered by the key E or by a click on the machine, the map by the key M or by a click on the strip of the route, the pause by Esc
	canvas.menu_hud_button = canvas.add_button(pause_row, "☰", canvas.pause_game, false, false, &"QuietAction")
	canvas.menu_hud_button.tooltip_text = "Меню и пауза [Esc]"
	canvas.menu_hud_button.custom_minimum_size.x = 52
	for button in pause_row.get_children():
		for state_name in ["normal","hover","pressed","disabled","focus"]:
			var padding=button.get_theme_stylebox(state_name).duplicate()
			padding.content_margin_top=2;padding.content_margin_bottom=2
			button.add_theme_stylebox_override(state_name,padding)
	canvas.order_label=canvas.positioned_label("",Rect2(34,64,size.x-68,28),16,Color("c7c3a0"))
	canvas.order_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	canvas.order_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	canvas.hint_label = canvas.positioned_label("", Rect2(34, 96, size.x - 68, 64), 17)
	canvas.hint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	canvas.hint_label.max_lines_visible=2
	canvas.hint_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	canvas.action_bar = HBoxContainer.new()
	canvas.action_bar.position = Vector2(34, 168)
	canvas.action_bar.size = Vector2(size.x - 68, 48)
	canvas.action_bar.add_theme_constant_override("separation", 12)
	canvas.ui.add_child(canvas.action_bar)
	canvas.cargo_actions=HBoxContainer.new()
	canvas.cargo_actions.position=Vector2(size.x-720,canvas.dock_rect().position.y+84)
	canvas.cargo_actions.size=Vector2(664,44)
	canvas.cargo_actions.alignment=BoxContainer.ALIGNMENT_END
	canvas.cargo_actions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.ui.add_child(canvas.cargo_actions)
	canvas.cargo_action_key=""
	canvas.last_action_key = ""
	update_hud()

# Lowest edge of the visible top HUD; world signs are kept below it.
func hud_top_clearance() -> float:
	var bottom=56.0
	for label in [canvas.order_label,canvas.hint_label]:
		if label!=null and label.visible: bottom=maxf(bottom,label.get_rect().end.y+7)
	if canvas.action_bar!=null and canvas.action_bar.visible: bottom=maxf(bottom,canvas.action_bar.position.y+canvas.action_bar.size.y)
	return bottom+8

func draw_zone_label() -> void:
	var info=canvas.art_world.zone_label() if canvas.art_world!=null else {}
	if info.is_empty(): return
	var width=minf(canvas.font.get_string_size(info.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+28,maxf(120,info.width))
	var box=Rect2(info.anchor+Vector2(-12,-24),Vector2(width,32))
	if canvas.instruments!=null and is_instance_valid(canvas.instruments) and box.end.y>canvas.instruments.hud_top()-40: return
	canvas.draw_style_box(canvas.style(Color(canvas.INK,0.86),info.color,10),box)
	canvas.draw_string(canvas.font,box.position+Vector2(14,22),info.text,HORIZONTAL_ALIGNMENT_LEFT,width-20,16,info.color)

# B5.4: how far the train still rolls with the best braking, a warning when the stop is near, and the state of the wheels.
func brake_hint_text(target_s: float) -> String:
	var text = ""
	var speed = absf(float(canvas.model.state.v))
	if speed >= 3.0:
		var stop_m = canvas.model.stopping_distance()
		text = " · торм. путь %d м" % roundi(minf(stop_m, 999.0))
		var ahead = (target_s - float(canvas.model.state.s)) * int(canvas.model.state.direction)
		if ahead > 0.0 and float(canvas.model.state.v) * int(canvas.model.state.direction) > 0.0 and stop_m * 1.1 >= ahead: text += " — ТОРМОЗИ"
	# the wear warning is the lamp in the speed panel now (instruments.gd), the weak node is named in the pause window
	if canvas.model.wheel_slip and not canvas.model.wheel_lock and float(canvas.model.state.throttle) > 0.05: text += " · колёса буксуют"
	return text

func update_hud() -> void:
	if canvas.screen != "game" or canvas.hud == null:
		return
	canvas.update_charge_warning()
	var state = canvas.model.state
	var destination = canvas.model.next_destination()
	var target_s = float(canvas.model.route.station_s[canvas.station_number(destination)])
	var order = "Свободное движение" if state.active.is_empty() else str(state.active.title)
	var returning = not state.active.is_empty() and state.active.phase == "return"
	var stop_index = canvas.model.station_index()
	var at_station = canvas.model.station_name(canvas.model.data.stations[stop_index].id) if stop_index >= 0 else ""
	# ui-v2: the time and the weather only; the target and the distance are on the minimap (the owner: no doubles)
	canvas.hud.text = "%s · %s" % [canvas.model.clock_text(), canvas.model.weather_name() if int(canvas.settings.weather) != 2 else "ясно"] + canvas.deadline_text() + brake_hint_text(target_s) + keys_hint_text()
	if canvas.burst_button != null and is_instance_valid(canvas.burst_button):
		canvas.burst_button.text = canvas.burst_button_text()
		canvas.burst_button.disabled = not canvas.model.burst_ready()
	if canvas.grapnel_button != null and is_instance_valid(canvas.grapnel_button):
		canvas.grapnel_button.text = canvas.grapnel_button_text()
		canvas.grapnel_button.disabled = canvas.model.state.phase != "route" or canvas.model.grapnel.mode in ["flying", "dropped", "torn"]
	canvas.order_label.text=order
	if state.phase=="loading" and canvas.model.selectable_loading():
		var plan_line=canvas.model.loading_preview()
		canvas.order_label.text="Заказ · %s · погружено %d из %d" % [order, plan_line.loaded, plan_line.offered]
	var hint = ""
	if state.phase == "loading":
		if canvas.model.selectable_loading():
			var plan=canvas.model.loading_preview()
			hint="Выбери груз. Подъём через %d м, до +%.1f%% · %s. Лишнее можно снять." % [maxf(0,plan.first_hill_m),plan.max_grade*100,plan.difficulty]
		else: hint = "Сохранённый заказ: размести весь принятый груз. Его прежние условия сохранены."
	elif returning and canvas.model.stopped() and stop_index > 0:
		hint = "Груз доставлен. Разверни состав и возвращайся домой за оплатой."
	elif stop_index == 0 and canvas.model.stopped() and not returning and float(state.brake) > 0.5:
		# the start of a trip (player journal 16.11): the brake is on and nothing said so; the old line asked to unload here
		hint = "Тормоз затянут. Отпусти его: красный рычаг к 0%% или клавиша %s. Потом трогай." % canvas.key_name("brake")
	elif stop_index >= 0 and canvas.model.stopped():
		hint = "Станция «%s». Перетащи груз для этой станции на площадку внизу." % at_station
	elif canvas.model.vehicle_id() == "sail":
		hint = "Зажми нижний угол паруса мышью и держи: к мачте — парус раскрыт, назад — ребром; вверх или вниз — угол приподнимается или опускается (высоко держишь — полотно закручивается и ветер уходит). Клавиша F (по умолчанию) переводит гик на другой борт: боковой ветер наполняет парус на подветренном борту. Отпустил — парус полощет и не тянет; отпусти над утёй у кормы (медная скоба) — шкот закреплён в ближайшей из трёх засечек (с гаджетом — в любом положении). Попутный ветер — раскрой, боковой — наполовину. Тормоз — красный рычаг у носа или клавиша %s."  % canvas.key_name("brake")
	elif canvas.model.vehicle_id() == "pole":
		hint = "Веди мышью — шест следует за ней. Щелчок втыкает его; держи и тяни мышь назад — едешь, вперёд — встаёшь на шест. Отпустил — шест поднят. Красный рычаг — тормоз."
	elif canvas.model.vehicle_id() == "handcar":
		hint = "Зажми деревянный хват и веди его по дуге рычага. Ровные полные ходы разгоняют лучше. Красный рычаг — тормоз."
	elif canvas.model.vehicle_id() == "steam":
		if not state.engine: hint = "Войди в кабину [%s]. Проверь воду, открой дверцу и перетащи уголь в топку. Чиркни спичкой по тёрке и щёлкни по топке." % canvas.key_name("cab") if canvas.Model.match_rules else "Кабина [E]: открой дверцу, перетащи уголь из ведра в топку, закрой дверцу и нажми «Розжиг»."
		elif not canvas.model.steam_ready(): hint = "Давление растёт: жди %d бар. Вода в кране должна быть открыта." % int(canvas.model.boiler_cfg().work_pressure_bar)
		else: hint = "Вентиль — колесо: крути по кругу, отпустишь — закроется сам. Тормоз — красный рычаг."
	elif canvas.model.vehicle_id() == "pneumatic":
		hint = "Вентиль — зелёный рычаг, тормоз — красный. Трубки обмерзают: кликай по белому инею на трубках (или клавиша %s сбивает всё сразу). Воздух набирается у компрессора станции." % canvas.key_name("ice")
	elif canvas.model.vehicle_id() == "locomotive":
		hint = "Тяга — зелёный рычаг, тормоз — красный. Направление выбирается на стоянке кнопками «Тяга ←» и «Тяга →»."
	elif not state.engine:
		hint = "Запуск: газ 0%, передача N. Поверни ключ и держи, пока мотор не схватит."
	else:
		hint = "Подача — зелёный рычаг, тормоз — красный. Передача меняется при подаче ниже 15%."
	if float(state.brake) > 0.95 and not canvas.model.stopped():
		hint = "Торможение."
	if canvas.model.stopped() and state.phase == "route" and not returning and stop_index == 0:
		hint = "Переведи красную рукоять к 0%, затем начинай движение."
	if canvas.model.vehicle_id() == "locomotive" and canvas.model.regen_kw > 0.01:
		hint = "Рекуперация: +%.1f кВт. Часть энергии торможения возвращается в аккумулятор." % canvas.model.regen_kw
	var interaction=canvas.station_state()
	if canvas.mini_button != null and is_instance_valid(canvas.mini_button): canvas.mini_button.visible = not canvas.cab_active()
	canvas.order_label.visible=not canvas.cab_active() and state.phase=="loading"
	canvas.hint_label.visible=not canvas.cab_active() and state.tutorial and (state.phase=="loading" or (canvas.drag!="" and not interaction.visible))
	# ui-v2: the loading actions stand at the bottom right above the instruments, the main one last (nearest the corner)
	if state.phase=="loading":
		var bottom_y=(canvas.instruments.hud_top() if canvas.instruments!=null and is_instance_valid(canvas.instruments) else canvas.get_viewport_rect().size.y-174)-70
		canvas.action_bar.position=Vector2(canvas.get_viewport_rect().size.x-720, bottom_y)
		canvas.action_bar.size=Vector2(686, 64)
		canvas.action_bar.alignment=BoxContainer.ALIGNMENT_END
		if canvas.cargo_actions!=null and is_instance_valid(canvas.cargo_actions): canvas.cargo_actions.position.y=bottom_y-58   # above the main button, never over it
	else:
		canvas.action_bar.position=Vector2(34, 70)
		canvas.action_bar.size=Vector2(canvas.get_viewport_rect().size.x-68, 48)
		canvas.action_bar.alignment=BoxContainer.ALIGNMENT_BEGIN
		if canvas.cargo_actions!=null and is_instance_valid(canvas.cargo_actions): canvas.cargo_actions.position.y=canvas.dock_rect().position.y+84
	canvas.hint_label.text = hint if state.phase=="loading" else (interaction.reason if interaction.visible else (hint if state.tutorial else ""))
	var max_w = canvas.get_viewport_rect().size.x - 68
	canvas.order_label.size.x = minf(max_w, canvas.font.get_string_size(canvas.order_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * float(canvas.settings.text_scale))).x + 12)
	canvas.hint_label.size.x = minf(minf(max_w, 900.0), canvas.font.get_string_size(canvas.hint_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * float(canvas.settings.text_scale))).x + 12)
	canvas.update_cargo_actions(interaction)
	var key = "%s_%d_%s_%s_%s_%d" % [state.phase, stop_index, str(canvas.model.stopped()), str(canvas.model.all_loaded()), str(returning), canvas.model.drive_direction()]
	if state.phase=="loading": key+=str(canvas.model.loading_preview().signature)
	key += "_" + str(canvas.model.oars_out()) + "_" + str(canvas.model.can_turn() == "")
	if key != canvas.last_action_key:
		canvas.last_action_key = key
		canvas.clear_children(canvas.action_bar)
		if state.phase == "loading":
			canvas.add_button(canvas.action_bar, "В депо", canvas.start_depot_entry, false, false, &"QuietAction")
			var plan=canvas.model.loading_preview()
			var go_text="Отправиться →" if int(plan.loaded)>=int(plan.offered) or not canvas.model.selectable_loading() else "Отправиться · %d из %d →" % [plan.loaded, plan.offered]
			var go=canvas.add_button(canvas.action_bar, go_text, func():
				if canvas.model.depart(): canvas.save_game(); canvas.rebuild()
				else: canvas.notify(canvas.model.message), not canvas.model.all_loaded(), false, &"PrimaryAction")
			go.custom_minimum_size=Vector2(320, 60)
			go.tooltip_text="%d кг · награда %d" % [plan.mass_kg, plan.reward]
		elif canvas.model.stopped():
			if canvas.model.vehicle_id() == "sail" and (canvas.model.oars_owned() or canvas.model.oars_out()):
				canvas.add_button(canvas.action_bar, "Убрать вёсла" if canvas.model.oars_out() else "Вёсла", func():
					if canvas.model.set_oars(not canvas.model.oars_out()): canvas.last_action_key = ""
					else: canvas.notify(canvas.model.message))
			# one switch for the direction of the pull instead of two buttons: it shows where the machine pulls now and flips it
			if canvas.model.vehicle_id() not in ["handcar","pole","sail","motorcar"]:
				var forward = canvas.model.drive_direction() > 0
				canvas.add_button(canvas.action_bar, "Тяга →" if forward else "Тяга ←", func():
					var wanted = -int(state.direction) if forward else int(state.direction)
					if canvas.model.set_reverser(wanted): canvas.save_game(); canvas.last_action_key = ""
					else: canvas.notify(canvas.model.message))
			# what cannot be done now is not shown (no grey button without a reason): the turn is offered only when it is possible
			if stop_index >= 0 and canvas.model.can_turn() == "":
				canvas.add_button(canvas.action_bar, "Развернуть", func():
					if canvas.model.turn(): canvas.save_game(); canvas.notify("Состав развёрнут"); canvas.last_action_key = ""
					else: canvas.notify(canvas.model.message))
			if stop_index == 0:
				canvas.add_button(canvas.action_bar, "Заехать в депо →", canvas.start_depot_entry)
			# the frost of the pneumatic train is knocked off by the key I or by a click on the white spots; the manual save is in the pause menu only
		for child in canvas.action_bar.get_children():
			if child is Button: child.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	canvas.action_bar.visible=not canvas.cab_active() and canvas.action_bar.get_child_count()>0 and (state.phase=="loading" or canvas.model.stopped())

# The first three deliveries the header reminds where the removed buttons went.
func keys_hint_text() -> String:
	if int(canvas.model.state.stats.get("deliveries", 99)) >= 3 or canvas.cab_active(): return ""
	var cab_part = "" if canvas.model.human_powered() else " · %s кабина" % canvas.key_name("cab")
	return "   [%s карта%s · Esc меню]" % [canvas.key_name("map"), cab_part]

func energy_text() -> String:
	if canvas.model.vehicle_id() == "handcar": return "Ручной привод · %d Вт" % roundi(canvas.model.output_power)
	if canvas.model.vehicle_id() == "sail": return "Парус · ветер %.1f м/с" % canvas.model.wind_here().length()
	if canvas.model.vehicle_id() == "pole": return "Шест · опора: %s" % (str(canvas.model.pole_ground_at(float(canvas.model.pole.tip_s)).name) if canvas.model.pole.planted() else "в руках")
	var amount = float(canvas.model.state.fleet_by_id[canvas.model.vehicle_id()].fuel)
	var cap = float(canvas.model.object_stats(canvas.model.vehicle_id()).tank)
	if canvas.model.vehicle_id() == "locomotive":
		return "Заряд %d%% · %.2f / %.2f кВт·ч" % [roundi(amount / cap * 100), amount, cap]
	if canvas.model.vehicle_id() == "steam":
		var fleet = canvas.model.state.fleet_by_id.steam
		return "Давление %.1f бар · топка %.1f кг · ведро %.0f / %.0f кг · вода %.0f / %.0f л" % [canvas.model.pressure_bar(), float(canvas.model.boiler().firebox), amount, cap, float(fleet.get("water", 0)), float(canvas.model.object_stats("steam").water)]
	if canvas.model.vehicle_id() == "pneumatic":
		return "Давление %.0f / %.0f бар · иней %d%%" % [amount, cap, roundi(canvas.model.frost() * 100.0)]
	if canvas.model.vehicle_id() == "jet": return "Керосин %.0f / %.0f л" % [amount, cap]
	return "Бензин %.2f / %.1f л" % [amount, cap]

func vehicle_display_name() -> String:
	return str(canvas.model.vehicle_base().name)
