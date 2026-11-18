extends RefCounted
# Помощник main.gd (1.3.7): кабина паровоза: топка, ведро, дверца, панель котла, кнопки кабины.
# Работает через canvas (main.gd), как depot_ui.gd.

var canvas = null   # main.gd
const BOARD = preload("res://assets/art_cab/steam_workbench.png")
const WINDOW_WALL = preload("res://assets/art_cab/steam_window_wall.png")
const TRACK_GROUND = preload("res://assets/art_cab/steam_track_ground.png")
# Crop the exterior edges. The side-view rectangles terminate inside the solid posts.
const WALL_ART = Rect2(44, 0, 2084, 724)
const LEFT_LIGHT = Rect2(44, 142, 216, 548)
const RIGHT_LIGHT = Rect2(1910, 142, 218, 548)
const BOILER = preload("res://assets/art_cab/steam_boiler_forward.png")
const TOOLS = preload("res://assets/art_cab/steam_firing_tools.png")
const CONTROLS = preload("res://assets/art_cab/steam_drive_controls.png")
const BUCKET_ART = Rect2(12, 37, 660, 647)
const OPEN_ART = Rect2(686, 12, 748, 670)
const CLOSED_ART = Rect2(1536, 12, 625, 670)
var classic = "--classic-steam-cab" in OS.get_cmdline_user_args()
# 19.11 (owner): the instruments go to the right, the firebox to the left. The painted board keeps its middle; its
# two outer sections change places, mirrored, so the pipes and brackets stay at the edges. Cut at the middle of a post.
const BOARD_LEFT = Rect2(0, 0, 692, 724)       # the copper section, up to the middle of the left brass post
const BOARD_RIGHT = Rect2(1431, 0, 741, 724)   # the green section, from the middle of the right brass post
const INSTRUMENTS_X = 0.824   # board fractions across the screen
const FIRING_X = 0.164
const BUCKET_X = 0.092
const FIRE_X = 0.222

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func steam_fire_rect(rect: Rect2) -> Rect2:
	if revised():
		return Rect2(board_point(FIRE_X, 0.45) - Vector2(77, 73), Vector2(154, 146))
	return Rect2(rect.position+Vector2(150,282),Vector2(130,64))

func revised() -> bool:
	return not classic and canvas.cab_active() and canvas.model.vehicle_id() == "steam"

func side_art(side: float) -> Rect2:
	return LEFT_LIGHT if side < 0.0 else RIGHT_LIGHT

func side_rect(size: Vector2, top: float, side: float) -> Rect2:
	var region = side_art(side)
	var scale = Vector2(size.x, top) / WALL_ART.size
	return Rect2((region.position - WALL_ART.position) * scale, region.size * scale)

func wall_tint() -> Color:
	return Color.WHITE.darkened(canvas.model.night_amount() * 0.26)

func draw_window_wall(size: Vector2, top: float) -> void:
	canvas.draw_texture_rect_region(WINDOW_WALL, Rect2(0, 0, size.x, top), WALL_ART, wall_tint())
	var tint = Color.WHITE.darkened(canvas.model.night_amount() * 0.22)
	var height = size.y - top
	var k = size.x / float(BOARD.get_width())
	canvas.draw_texture_rect(BOARD, Rect2(0, top, size.x, height), false, tint)
	# a negative width mirrors the section (Godot still draws it from the given x to the right); each one is fitted to
	# the width of the place it takes
	canvas.draw_texture_rect_region(BOARD, Rect2(0, top, -BOARD_LEFT.size.x * k, height), BOARD_RIGHT, tint)
	canvas.draw_texture_rect_region(BOARD, Rect2(BOARD_RIGHT.position.x * k, top, -BOARD_RIGHT.size.x * k, height), BOARD_LEFT, tint)

# Fractional board positions are mapped back to the same pult coordinates used for mouse input.
func board_point(x: float, y: float) -> Vector2:
	var size = canvas.get_viewport_rect().size
	var top = float(canvas.cab_layout(size).dash_top)
	return canvas.pult_t.affine_inverse() * Vector2(size.x * x, lerpf(top, size.y, y))

func centered(text: String, point: Vector2, width: float, pixels: int, color: Color) -> void:
	canvas.draw_string(canvas.font, point - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, width, pixels, color)

func draw_drive_control(id: String, geo: Dictionary) -> void:
	canvas.draw_set_transform_matrix(canvas.pult_t * Transform2D(geo.angle, geo.pivot))
	if id == "brake":
		# The painted ball and mounting bolt are 550 texture pixels apart.
		var scale = Vector2(geo.pivot).distance_to(geo.grip) / 550.0
		canvas.draw_texture_rect_region(CONTROLS, Rect2(Vector2(-98, -645) * scale, Vector2(196, 720) * scale), Rect2(255, 0, 196, 720))
	else:
		var diameter = 2.0 * float(geo.radius) + 10.0
		var dest = Rect2(Vector2.ONE * -diameter * 0.5, Vector2.ONE * diameter)
		var source = Rect2(731, 0, 708, 715) if id == "throttle" else Rect2(1456, 0, 707, 715)
		canvas.draw_texture_rect_region(CONTROLS, dest, source)
		canvas.draw_circle(Vector2(0, -geo.radius), 3.5, Color("f8dd8a"))
	canvas.draw_set_transform_matrix(canvas.pult_t)

func draw_board_labels() -> void:
	canvas.draw_set_transform_matrix(canvas.pult_t)
	for group in [[INSTRUMENTS_X, "ПРИБОРЫ"], [0.486, "УПРАВЛЕНИЕ"], [FIRING_X, "ТОПКА"]]:
		var pos = board_point(group[0], 0.145)
		centered(group[1], pos, 210, 21, Color("f1dfaf"))
		canvas.draw_line(pos + Vector2(-43, 9), pos + Vector2(43, 9), Color("aa8854"), 1.5)
	var fleet = canvas.model.state.fleet_by_id.steam
	var water = float(fleet.water)
	var glass = Rect2(board_point(INSTRUMENTS_X, 0.74) - Vector2(100, 0), Vector2(200, 13))
	canvas.draw_style_box(canvas.style(Color("142022"), Color("a38a55"), 5), glass.grow(3))
	var filled = glass.size.x * clampf(water / float(canvas.model.object_stats("steam").water), 0.0, 1.0)
	canvas.draw_rect(Rect2(glass.position, Vector2(filled, glass.size.y)), Color("57878c"))
	for i in range(1, 8):
		var mark = glass.position + Vector2(glass.size.x * i / 8.0, 0)
		canvas.draw_line(mark, mark + Vector2(0, 5), Color("f5e9c9"), 1.5)
	centered("Вода в запасе  ·  %.0f л" % water, glass.get_center() + Vector2(0, 36), 260, 18, canvas.PAPER)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_boiler_ahead(cx: float, view: Rect2, running: bool) -> void:
	var height = view.size.y * 0.46
	var boiler = Rect2(cx - 0.75 * height, view.end.y - height, 1.5 * height, height)
	canvas.draw_texture_rect(BOILER, boiler, false)
	if running:
		var mouth = Vector2(cx, boiler.position.y + height * 0.085)
		for i in range(7):
			var age = fposmod(canvas.time * (0.55 + canvas.model.state.throttle) + i / 7.0, 1.0)
			var offset = Vector2(sin(i + canvas.time) * 7 * age - 22 * age, -age * height * 0.7)
			canvas.draw_circle(mouth + offset, 4 + age * 24, Color(0.85, 0.83, 0.77, (1.0 - age) * 0.28), true, -1, true)

func draw_firing_station(rect: Rect2) -> void:
	var boiler = canvas.model.boiler()
	var fleet = canvas.model.state.fleet_by_id.steam
	var bucket = Rect2(board_point(BUCKET_X, 0.448) - Vector2(63, 61), Vector2(126, 122))
	var fire = steam_fire_rect(rect)
	canvas.draw_texture_rect_region(TOOLS, bucket, BUCKET_ART, Color.WHITE if float(fleet.fuel) > 0 else Color("656366"))
	var open = bool(boiler.door)
	# The open leaf projects to the left. Keep the actual opening fixed between both states.
	var frame = Rect2(fire.position - Vector2(23, 0), fire.size + Vector2(23, 0)) if open else fire
	canvas.draw_rect(fire.grow(-20), Color("120f0c"))
	canvas.draw_texture_rect_region(TOOLS, frame, OPEN_ART if open else CLOSED_ART)
	if bool(boiler.lit):
		var flicker = 0.5 + 0.5 * sin(canvas.time * 8.0) if canvas.light_flicker_enabled() else 0.5
		var glow = Color(1.0, 0.39, 0.09, 0.12 + flicker * 0.06)
		if open:
			var bed = fire.get_center() + Vector2(0, 32)
			canvas.draw_circle(bed, 30, glow)
			for i in range(9):
				var ember = bed + Vector2((i - 4) * 8, sin(i * 2.3) * 3)
				canvas.draw_circle(ember, 6, Color("983813"), true, -1, true)
				canvas.draw_circle(ember - Vector2(1, 2), 3.5 + flicker, Color("fbaa4c"), true, -1, true)
				var height = (10 + 14 * absf(sin(i * 1.4 + flicker))) * (0.55 + 0.45 * float(boiler.heat))
				var tip = ember + Vector2(sin(i + flicker) * 5, -height)
				var flame = PackedVector2Array([ember + Vector2(-5, 1), ember + Vector2(-3, -height * 0.5), tip, ember + Vector2(3, -height * 0.44), ember + Vector2(5, 1)])
				canvas.draw_colored_polygon(flame, Color(1, 0.56, 0.15, 0.8))
		else:
			canvas.draw_line(fire.get_center() + Vector2(-23, 4), fire.get_center() + Vector2(20, 4), Color("dd7431"), 3)
	centered("Уголь  ·  %.0f кг" % fleet.fuel, bucket.get_center() + Vector2(0, 92), 180, 19, canvas.PAPER)
	centered("%.1f / %.0f кг" % [boiler.firebox, canvas.model.boiler_cfg().firebox_kg], fire.get_center() + Vector2(0, 94), 175, 19, canvas.PAPER)
	var door = Rect2(board_point(FIRE_X, 0.78) - Vector2(83, 22), Vector2(166, 44))
	canvas.draw_style_box(canvas.style(Color("24221d"), Color("b69860"), 5), door)
	centered("Закрыть дверцу" if open else "Открыть дверцу", door.get_center() + Vector2(0, 6), door.size.x, 17, canvas.PAPER)
	canvas.steam_hits.append({"id":"bucket", "rect":canvas.pult_t * bucket})
	canvas.steam_hits.append({"id":"door", "rect":canvas.pult_t * door})
	if canvas.drag == "coal":
		var coal = canvas.pult_t.affine_inverse() * canvas.drag_cursor
		canvas.draw_circle(coal, 10, Color("282623"))
		canvas.draw_arc(coal, 10, PI, TAU, 12, canvas.GOLD, 1.5, true)

# In the cab the steam corner of the dashboard has real props: an iron plate, a bucket
# with coal in it and a firebox door that glows and flickers with the fire.
func draw_steam_cab_props(bucket: Rect2, fire: Rect2, door_button: Rect2, boiler: Dictionary, fleet: Dictionary) -> void:
	var plate = Rect2(bucket.position - Vector2(14, 14), Vector2(fire.end.x - bucket.position.x + 28, door_button.end.y - bucket.position.y + 30))
	canvas.draw_style_box(canvas.style(Color("232a28"), Color("6c6f66"), 6), plate)
	for rivet in [plate.position + Vector2(7, 7), Vector2(plate.end.x - 7, plate.position.y + 7), Vector2(plate.position.x + 7, plate.end.y - 7), plate.end - Vector2(7, 7)]:
		canvas.draw_circle(rivet, 3.0, Color("a98a4a"))
	# bucket: tapered, hooped, a handle and a heap of coal that shrinks with the stock
	var body = PackedVector2Array([bucket.position + Vector2(16, 26), Vector2(bucket.end.x - 16, bucket.position.y + 26), Vector2(bucket.end.x - 24, bucket.end.y - 4), bucket.position + Vector2(24, bucket.size.y - 4)])
	canvas.draw_colored_polygon(body, Color("2a2f2c"))
	canvas.draw_polyline(PackedVector2Array([bucket.position + Vector2(18, 28), bucket.position + Vector2(56, 4), Vector2(bucket.end.x - 18, bucket.position.y + 28)]), Color("8a8a7a"), 2.5, true)
	canvas.draw_line(bucket.position + Vector2(20, 40), Vector2(bucket.end.x - 20, bucket.position.y + 40), Color("6c6f66"), 3.0)
	var stock = clampf(float(fleet.fuel) / float(canvas.model.object_stats("steam").tank), 0.0, 1.0)
	for lump in range(int(8 + 10 * stock)):
		var lx = bucket.position.x + 24 + fposmod(lump * 23.0, bucket.size.x - 48)
		canvas.draw_circle(Vector2(lx, bucket.position.y + 26 - 2.0 * stock * (lump % 3)), 4.0 + (lump % 3), Color("141517") if lump % 2 == 0 else Color("2c2e33"))
	if canvas.drag == "coal": canvas.draw_arc(bucket.get_center(), 54, 0, TAU, 28, canvas.GOLD, 2.0, true)
	# firebox door: an iron arch with the fire behind it; the fire lights the dashboard
	var heat = float(boiler.heat)
	if heat > 0.05:
		var flicker = 0.7 + 0.3 * sin(canvas.time * 9.0) * sin(canvas.time * 3.7) if canvas.light_flicker_enabled() else 1.0
		for ring in range(5): canvas.draw_circle(fire.get_center(), 60.0 + ring * 38.0, Color(1.0, 0.5, 0.12, 0.05 * heat * flicker))
	var door_open = bool(boiler.door)
	canvas.draw_rect(fire, Color("0a0b0b"))
	if heat > 0.02:
		var inner = fire.grow(-6)
		canvas.draw_polygon(PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.end.x, inner.end.y), Vector2(inner.position.x, inner.end.y)]), PackedColorArray([Color(0.35 + 0.3 * heat, 0.1, 0.02), Color(0.35 + 0.3 * heat, 0.1, 0.02), Color(1.0, 0.55 + 0.3 * heat, 0.1), Color(1.0, 0.55 + 0.3 * heat, 0.1)]))
		for flame in range(6):
			var fx = inner.position.x + inner.size.x * (flame + 0.5) / 6.0
			var flick = 0.55 + 0.45 * sin(canvas.time * 8.0 + flame * 1.9)
			var fh = (6.0 + 26.0 * heat) * flick
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(fx - 9, inner.end.y), Vector2(fx + 9, inner.end.y), Vector2(fx + sin(canvas.time * 5.0 + flame) * 4.0, inner.end.y - fh)]), Color(1.0, 0.8 - 0.2 * flick, 0.2, 0.85))
	if not door_open:
		# closed leaf with slits the glow shows through
		var leaf = fire.grow(-3)
		canvas.draw_rect(leaf, Color("2d3230"))
		for slit in range(4):
			var sy = leaf.position.y + 9 + slit * 11
			canvas.draw_line(Vector2(leaf.position.x + 12, sy), Vector2(leaf.end.x - 12, sy), Color(1.0, 0.6, 0.15, 0.2 + 0.7 * heat) if heat > 0.02 else Color("0a0b0b"), 3.0)
		canvas.draw_circle(Vector2(leaf.end.x - 14, leaf.get_center().y), 5.0, Color("c9a85a"))
		canvas.draw_rect(leaf, Color("5c615a"), false, 2.0)
	else:
		canvas.draw_polygon(PackedVector2Array([fire.position + Vector2(-26, -4), fire.position + Vector2(-2, 6), fire.position + Vector2(-2, fire.size.y - 6), fire.position + Vector2(-26, fire.size.y + 4)]), PackedColorArray([Color("3a403d"), Color("2d3230"), Color("2d3230"), Color("3a403d")]))
		canvas.draw_rect(fire, canvas.GOLD if canvas.drag == "coal" else Color("a98a4a"), false, 2.5)
	var lintel := PackedVector2Array()
	for segment in range(13):
		var angle = PI * float(segment) / 12.0
		lintel.append(Vector2(fire.get_center().x - cos(angle) * fire.size.x * 0.5, fire.position.y - sin(angle) * 9.0))
	canvas.draw_polyline(lintel, Color("5c615a"), 3.0, true)

# Boiler corner of the steam pult: coal bucket, firebox with door, manometer.
func draw_steam_panel(rect: Rect2) -> void:
	if revised():
		draw_firing_station(rect)
		return
	var b=canvas.model.boiler()
	var cfg=canvas.model.boiler_cfg()
	var fleet=canvas.model.state.fleet_by_id.steam
	var dim=Color("c7c3a0")
	var bucket=Rect2(rect.position+Vector2(16,282),Vector2(112,64))
	var fire=steam_fire_rect(rect)
	var door_button=Rect2(rect.position+Vector2(150,352),Vector2(130,28))
	var heat=float(b.heat)
	if canvas.cab_active(): draw_steam_cab_props(bucket,fire,door_button,b,fleet)
	else: canvas.draw_style_box(canvas.style(Color("3b2c1f"),canvas.GOLD if canvas.drag=="coal" else Color("66796b"),6),bucket)
	# in the cab the words lie over painted props: a small dark plate under each keeps them readable (designer journal 16.11)
	if canvas.cab_active():
		for plate in [Rect2(bucket.position+Vector2(22,8),Vector2(68,22)),Rect2(bucket.position+Vector2(26,34),Vector2(60,22)),Rect2(fire.position+Vector2(30,8),Vector2(70,22)),Rect2(fire.position+Vector2(14,34),Vector2(102,22))]:
			canvas.draw_style_box(canvas.style(Color(0.06,0.07,0.06,0.82),Color(0,0,0,0),5),plate)
	canvas.draw_string(canvas.font,bucket.position+Vector2(0,24),"ВЕДРО",HORIZONTAL_ALIGNMENT_CENTER,112,16,canvas.PAPER)
	canvas.draw_string(canvas.font,bucket.position+Vector2(0,50),"%.0f кг" % float(fleet.fuel),HORIZONTAL_ALIGNMENT_CENTER,112,18,canvas.GOLD)
	canvas.draw_string(canvas.font,bucket.position+Vector2(0,82),"тащи в топку",HORIZONTAL_ALIGNMENT_CENTER,112,13,dim)
	var fire_edge=canvas.GOLD if (bool(b.door) and canvas.drag=="coal") else (canvas.PAPER if bool(b.door) else Color("66796b"))
	var glow=roundf(heat*12.0)/12.0
	if not canvas.cab_active(): canvas.draw_style_box(canvas.style(Color(0.12+0.5*glow,0.07+0.2*glow,0.05),fire_edge,6),fire)
	canvas.draw_string(canvas.font,fire.position+Vector2(0,24),"ТОПКА",HORIZONTAL_ALIGNMENT_CENTER,130,16,canvas.PAPER)
	canvas.draw_string(canvas.font,fire.position+Vector2(0,50),"%.1f / %d кг" % [float(b.firebox),int(cfg.firebox_kg)],HORIZONTAL_ALIGNMENT_CENTER,130,17,canvas.GOLD)
	# B3.4: the fire is good between a third and 85% of the grate: thinner burns out, fuller chokes
	var fill=clampf(float(b.firebox)/float(cfg.firebox_kg),0.0,1.0)
	var bar=Rect2(fire.position+Vector2(12,56),Vector2(106,6))
	canvas.draw_rect(bar,Color("141a17"))
	canvas.draw_rect(Rect2(bar.position+Vector2(bar.size.x*float(cfg.thin_fire),0),Vector2(bar.size.x*(float(cfg.choke_from)-float(cfg.thin_fire)),bar.size.y)),Color("27402f"))
	canvas.draw_rect(Rect2(bar.position,Vector2(bar.size.x*fill,bar.size.y)),Color("5cc17f") if fill>=float(cfg.thin_fire) and fill<=float(cfg.choke_from) else Color("e0564a"))
	canvas.draw_style_box(canvas.style(canvas.INK,canvas.GOLD if bool(b.door) else Color("66796b"),6),door_button)
	canvas.draw_string(canvas.font,door_button.position+Vector2(0,20),"Дверца: открыта" if bool(b.door) else "Дверца: закрыта",HORIZONTAL_ALIGNMENT_CENTER,130,14,canvas.PAPER)
	# 17.11 (owner): the small pressure gauge of the pult is gone: the big «ДАВЛЕНИЕ» on the dash shows the same, nothing doubles
	canvas.steam_hits.append({"id":"bucket","rect":Rect2(canvas.pult_t*bucket.position,bucket.size*canvas.pult_t.get_scale())})
	canvas.steam_hits.append({"id":"door","rect":Rect2(canvas.pult_t*door_button.position,door_button.size*canvas.pult_t.get_scale())})
	if canvas.drag=="coal":
		var piece=Rect2(canvas.pult_t.affine_inverse()*canvas.drag_cursor-Vector2(9,9),Vector2(18,18))
		canvas.draw_rect(piece,Color("1b1713"))
		canvas.draw_rect(piece,canvas.GOLD,false,2)

# Clicks on the dashboard buttons: the direction switch (steam, electric) and the
# emergency stop (electric). The direction rules are the same as the buttons outside.
func cab_button(id: String) -> void:
	if id == "contactor":
		canvas.contactor_view().toggle()
		return
	if id.begins_with("drain"):
		var spot = int(id.trim_prefix("drain"))
		var was_plugged = canvas.model.plugged(spot)
		if canvas.model.drain(spot):
			canvas.sound.play("steam_blow", 0.4, 1.6)
			canvas.notify("Клапан %d: конденсат сброшен%s" % [spot + 1, ", ледяная пробка растаяла" if was_plugged else ""])
		return
	if id == "light":
		canvas.lamp_manual = 0 if canvas.lights_lit() else 1
		canvas.notify("Фара включена" if canvas.lamp_manual == 1 else "Фара выключена")
		canvas.sound.play("gear", 0.5, 1.2)
		return
	if id == "wiper":
		canvas.wiper_on = not canvas.wiper_on
		canvas.notify("Дворники включены" if canvas.wiper_on else "Дворники выключены")
		canvas.sound.play("gear", 0.5, 0.8)
		return
	if id == "whistle":
		if canvas.model.vehicle_id() == "steam":
			canvas.whistle_pull = 1.0
			canvas.sound.play("whistle", 0.9)
		else:
			canvas.sound.play("horn", 0.9)
		return
	if id == "forward" or id == "back":
		if canvas.model.set_reverser(1 if id == "forward" else -1): canvas.save_game()
		else: canvas.notify(canvas.model.message)
	elif id == "emergency":
		canvas.model.state.throttle = 0.0
		canvas.model.state.brake = 1.0
		canvas.notify("Аварийное торможение: тяга снята, тормоз затянут")
