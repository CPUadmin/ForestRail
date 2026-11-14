extends RefCounted
# Двор «Узловая Лесная» (docs/STATION_LOCATIONS_REWORK_RU.md, задумка владельца 14.11): главный экран между рейсами.
# Четыре здания: Депо, Мастерская, Магазин, Казик. Наводишь — в здании теплеет свет; щёлкаешь — камера наезжает, и ты внутри.
# Состав игрока стоит на пути двора. Картинка и места зданий — в data/yard_layout.json (доли картинки), чтобы их двигать без кода.
# Помощник main.gd, как depot_ui.gd: всё через canvas.

const PLACES = ["depot", "workshop", "shop", "casino"]
const NAMES = {"depot": "Депо", "workshop": "Мастерская", "shop": "Магазин", "casino": "Казик"}
const ENTER_ZOOM = 0.35   # how much closer the camera comes to the building while the screen darkens

var canvas = null
var layout: Dictionary = {}
var day: Texture2D = null
var evening: Texture2D = null
var rooms: Dictionary = {}   # place -> the painted room
var icons: Dictionary = {}   # place -> the small painted sign of the place (for the tabs)
var hover = ""        # the building under the mouse
var entering = ""     # the building the camera flies into

func _init(owner_canvas) -> void:
	canvas = owner_canvas
	var file = FileAccess.open("res://data/yard_layout.json", FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary: layout = parsed
	if ResourceLoader.exists(str(layout.get("day", ""))): day = load(str(layout.day))
	if ResourceLoader.exists(str(layout.get("evening", ""))): evening = load(str(layout.evening))
	# the painted rooms are loaded here, not while drawing: a picture loaded for the first time inside _draw came out white
	for id in layout.get("rooms", {}):
		var path = str(layout.rooms[id].get("picture", ""))
		if ResourceLoader.exists(path): rooms[id] = load(path)
	for id in PLACES: icons[id] = load("res://assets/art_yard/icon_%s.png" % id)

# The picture covers the window (the sides are cut on a narrow window, never stretched); the track stays in view.
func image_rect(size: Vector2) -> Rect2:
	if day == null: return Rect2(Vector2.ZERO, size)
	var aspect = float(day.get_width()) / float(day.get_height())
	var w = maxf(size.x, size.y * aspect)
	var h = w / aspect
	var top = clampf(size.y - h, size.y * 0.82 - float(layout.get("track_y", 0.8)) * h, 0.0)   # the track no lower than 82% of the window
	return Rect2((size.x - w) * 0.5, top, w, h)

func part(size: Vector2, frac: Array) -> Rect2:
	var r = image_rect(size)
	return Rect2(r.position + Vector2(float(frac[0]) * r.size.x, float(frac[1]) * r.size.y), Vector2(float(frac[2]) * r.size.x, float(frac[3]) * r.size.y))

# a painted room covers the window; its rails stand near 63% of the height (as in the old depot room), as far as the picture allows
func room_rect(size: Vector2, id: String) -> Rect2:
	var picture: Texture2D = rooms.get(id)
	if picture == null: return Rect2()
	var aspect = float(picture.get_width()) / float(picture.get_height())
	var w = maxf(size.x, size.y * aspect)
	var h = w / aspect
	var top = clampf(size.y * 0.63 - float(layout.rooms[id].track_y) * h, size.y - h, 0.0)
	return Rect2((size.x - w) * 0.5, top, w, h)

# where the machine stands in a painted room: on the rails of the picture
func room_rail_y(size: Vector2, id: String) -> float:
	var r = room_rect(size, id)
	return r.position.y + float(layout.rooms[id].track_y) * r.size.y

func building_rect(size: Vector2, id: String) -> Rect2:
	return part(size, layout.buildings[id].rect)

func rail_y(size: Vector2) -> float:
	var r = image_rect(size)
	return r.position.y + float(layout.get("track_y", 0.8)) * r.size.y

func train_x(size: Vector2) -> float:
	var r = image_rect(size)
	return r.position.x + float(layout.get("train_x", 0.6)) * r.size.x

# The machine is as long as the painted buildings want it (a share of the picture), whatever the machine is.
func train_scale(size: Vector2) -> float:
	var length = canvas.Geometry.length(canvas.model.vehicle_id())
	return image_rect(size).size.x * float(layout.get("train_width", 0.12)) / (canvas.ArtV3.PX * maxf(1.0, length))

# --- the picture
func draw_yard(size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color("10140f"))
	var r = image_rect(size)
	if entering != "" and canvas.depot_anim == "leave":
		# the camera comes closer to the building while the screen darkens
		var t = smoothstep(0.0, 1.0, clampf(canvas.depot_anim_t / canvas.place_fade_s(), 0.0, 1.0))
		var focus = building_rect(size, entering).get_center()
		var k = 1.0 + ENTER_ZOOM * t
		r = Rect2(focus + (r.position - focus) * k, r.size * k)
	if day != null: canvas.draw_texture_rect(day, r, false)
	# the evening picture comes in with the dusk of the game clock (the same layout, the lamps lit)
	var dusk = clampf(canvas.model.night_amount() * 1.2 + canvas.model.twilight() * 0.5, 0.0, 1.0)
	if evening != null and dusk > 0.01: canvas.draw_texture_rect(evening, r, false, Color(1, 1, 1, dusk))
	elif evening == null and dusk > 0.01: canvas.draw_rect(r, Color(0.05, 0.06, 0.16, 0.45 * dusk))
	# the building under the mouse: its windows and door get warmer (a soft lamp glow over it, no frame over the painting)
	if hover != "" and entering == "":
		var b = building_rect(size, hover)
		var glow = maxf(b.size.x, b.size.y) * 1.25
		canvas.draw_texture_rect(canvas.DEPOT_GLOW, Rect2(b.get_center() - Vector2(glow, glow) * 0.5, Vector2(glow, glow)), false, Color(1.0, 0.82, 0.5, 0.55))

# --- the controls over the picture
func build_yard(size: Vector2) -> void:
	entering = ""
	var model = canvas.model
	canvas.depot_ui().build_header(size, "Узловая " + model.station_name("A"))
	for id in PLACES:
		var b = building_rect(size, id)
		var door = Button.new()
		door.flat = true
		door.focus_mode = Control.FOCUS_ALL
		door.position = b.position
		door.size = b.size
		door.tooltip_text = NAMES[id]
		door.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty = StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled"]: door.add_theme_stylebox_override(state, empty)
		var focus = StyleBoxFlat.new()
		focus.draw_center = false
		focus.border_color = Color(canvas.UiKit.LAMP, 0.7)
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(8)
		door.add_theme_stylebox_override("focus", focus)
		door.mouse_entered.connect(func(): hover = id; canvas.queue_redraw())
		door.mouse_exited.connect(func():
			if hover == id: hover = ""
			canvas.queue_redraw())
		door.pressed.connect(func(): enter(id))
		canvas.ui.add_child(door)
		if not bool(layout.get("signs_painted", false)): sign_label(size, id)
		badge(size, id)
	build_bottom_bar(size)

# the name of the building on its blank painted sign: dark letters burnt into the wood
func sign_label(size: Vector2, id: String) -> void:
	var at = part(size, layout.buildings[id].sign)
	var label = Label.new()
	label.text = NAMES[id]
	label.position = at.position
	label.size = at.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the name fits the plate: as tall as half the plate, and no wider than the plate
	var font_size = clampf(at.size.y * 0.52, 14.0, 34.0)
	var wide = canvas.font.get_string_size(NAMES[id], HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size)).x
	if wide > at.size.x * 0.86: font_size = maxf(12.0, font_size * at.size.x * 0.86 / wide)
	label.add_theme_font_size_override("font_size", int(font_size))
	label.add_theme_color_override("font_color", Color("2e1c0e"))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.85, 0.55, 0.35))
	label.add_theme_constant_override("outline_size", 2)
	canvas.ui.add_child(label)

# what waits inside, in one short word on a chip by the building (nothing when nothing waits)
func badge_text(id: String) -> String:
	var model = canvas.model
	if id == "workshop" and canvas.Model.wear_rules and model.wear().needs_repair():
		var worst = 1.0
		for body in model.body_ids():
			for def in model.wear().nodes_of(body): worst = minf(worst, model.wear().condition(body, str(def.id)))
		if worst < 0.4: return "! ремонт"
	if id == "casino" and model.casino().tokens() > 0: return "жетонов %d" % model.casino().tokens()
	if id == "shop" and not model.creative():
		for vehicle in canvas.Model.VEHICLE_IDS:
			var cost = int(model.vehicle_base(vehicle).cost)
			if not model.state.fleet_by_id.has(vehicle) and cost > 0 and cost <= int(model.state.money): return "по карману"
	if id == "depot" and not model.state.active.is_empty(): return "рейс ждёт"
	return ""

func badge(size: Vector2, id: String) -> void:
	var text = badge_text(id)
	if text == "": return
	var b = part(size, layout.buildings[id].sign)
	var chip = Label.new()
	chip.text = text
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_font_size_override("font_size", int(16 * float(canvas.settings.text_scale)))
	chip.add_theme_color_override("font_color", Color("ffe6a8") if not text.begins_with("!") else Color("ffb49a"))
	var back = StyleBoxFlat.new()
	back.bg_color = Color(0.09, 0.07, 0.05, 0.86)
	back.border_color = Color(canvas.UiKit.LAMP, 0.55) if not text.begins_with("!") else Color("d0604a")
	back.set_border_width_all(1)
	back.set_corner_radius_all(10)
	back.content_margin_left = 10
	back.content_margin_right = 10
	back.content_margin_top = 3
	back.content_margin_bottom = 3
	chip.add_theme_stylebox_override("normal", back)
	canvas.ui.add_child(chip)
	chip.position = Vector2(b.get_center().x - chip.get_combined_minimum_size().x * 0.5, b.end.y + 4.0)

# the bottom of the yard: the map of the line and the one main action (to the loading of the order, or on with the trip)
func build_bottom_bar(size: Vector2) -> void:
	var model = canvas.model
	var bar = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	bar.position = Vector2(size.x * 0.5 - 520, size.y - 96)
	bar.size = Vector2(1040, 72)
	canvas.ui.add_child(bar)
	var map = canvas.add_button(bar, "Карта линии", func(): canvas.show_modal("map"), false, false, &"QuietAction")
	map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	map.custom_minimum_size = Vector2(220, 60)
	if not model.state.active.is_empty():
		var on = canvas.add_button(bar, "Продолжить рейс: %s →" % str(model.state.active.title), func():
			model.resume_mission()
			canvas.screen = "game"
			canvas.zoom_level = canvas.fit_train_zoom()
			canvas.save_game()
			canvas.rebuild(), false, false, &"PrimaryAction")
		on.custom_minimum_size = Vector2(460, 68)
		return
	var main = canvas.depot_ui().main_order()
	if main.is_empty():
		var ride = canvas.add_button(bar, "Просто поехать →", canvas.take_free_ride, false, false, &"PrimaryAction")
		ride.custom_minimum_size = Vector2(360, 68)
		return
	var problem = model.mission_error(main)
	var go = canvas.add_button(bar, "К погрузке: %s →" % str(main.title), func(): canvas.take_mission(main), problem != "", false, &"PrimaryAction")
	go.custom_minimum_size = Vector2(460, 68)
	if problem != "": go.tooltip_text = problem

# a click on a building: the casino is its own screen (Mikhalych and the wheel); the others are rooms of the yard
func enter(id: String) -> void:
	canvas.sound.play("ui_click", 0.5)
	if id == "casino":
		canvas.show_modal("casino")
		return
	entering = id
	canvas.go_place(id)
