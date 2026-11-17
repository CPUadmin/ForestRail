extends RefCounted
# Помощник main.gd (1.3.7): кабина паровоза: топка, ведро, дверца, панель котла, кнопки кабины.
# Работает через canvas (main.gd), как depot_ui.gd.

var canvas = null   # main.gd

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func steam_fire_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position+Vector2(150,282),Vector2(130,64))

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
	var center=rect.position+Vector2(360,322)
	var first=deg_to_rad(150)
	var sweep=deg_to_rad(240)
	canvas.draw_arc(center,40,first,first+sweep,40,Color("66796b"),3,true)
	var work=float(cfg.work_pressure_bar)/float(cfg.max_pressure_bar)
	var mark=Vector2.from_angle(first+sweep*work)
	canvas.draw_line(center+mark*34,center+mark*46,canvas.GREEN,3,true)
	var needle=Vector2.from_angle(first+sweep*float(b.pressure))
	canvas.draw_line(center,center+needle*34,canvas.RED if bool(b.venting) else canvas.PAPER,2.5,true)
	canvas.draw_circle(center,3,canvas.PAPER)
	canvas.draw_string(canvas.font,center+Vector2(-50,58),"%.1f бар" % canvas.model.pressure_bar(),HORIZONTAL_ALIGNMENT_CENTER,100,16,canvas.GOLD if canvas.model.steam_ready() else dim)
	canvas.draw_string(canvas.font,center+Vector2(-50,-66),"ДАВЛЕНИЕ",HORIZONTAL_ALIGNMENT_CENTER,100,13,dim)   # above the work mark of the scale
	canvas.steam_hits.append({"id":"bucket","rect":Rect2(canvas.pult_t*bucket.position,bucket.size*canvas.pult_t.get_scale())})
	canvas.steam_hits.append({"id":"door","rect":Rect2(canvas.pult_t*door_button.position,door_button.size*canvas.pult_t.get_scale())})
	if canvas.drag=="coal":
		var piece=Rect2(canvas.pult_t.affine_inverse()*canvas.drag_cursor-Vector2(9,9),Vector2(18,18))
		canvas.draw_rect(piece,Color("1b1713"))
		canvas.draw_rect(piece,canvas.GOLD,false,2)

# Clicks on the dashboard buttons: the direction switch (steam, electric) and the
# emergency stop (electric). The direction rules are the same as the buttons outside.
func cab_button(id: String) -> void:
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
