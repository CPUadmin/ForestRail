extends Control

const PAPER = Color("f5ecd6")
const MUTED = Color("b9c7b2")
const GOLD = Color("d6b875")
const GREEN = Color("7fab85")
const RED = Color("e18265")
const PANEL = Color("203730")
var game
var full_map = false
var selected_station = -1
var station_hits: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if full_map else Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func nominal_speed() -> float:
	if game.model.vehicle_id() == "handcar": return 30.0
	var speeds = game.model.object_stats(game.model.vehicle_id()).speeds
	return maxf(float(speeds[0]),float(speeds[1])) * 3.6

func dial_maximum() -> float:
	var nominal = nominal_speed()
	var step = 5.0 if nominal <= 40 else 10.0
	return ceilf(nominal / step) * step

func mini_rect() -> Rect2:
	return Rect2(244,size.y-174,maxf(240,size.x-244-status_width()-34),152)

func status_width() -> float:
	return 312*clampf(float(game.settings.text_scale),1,1.5)

func permanent_panel_height() -> float:
	return 46+152

func put(text: String, at: Vector2, width: float, font_size: int = 18, color: Color = PAPER, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font = ThemeDB.fallback_font
	var pixels = roundi(font_size * float(game.settings.text_scale))
	while pixels > 12 and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x > width:
		pixels -= 1
	draw_string(font,at,text,align,width,pixels,color)

func panel(rect: Rect2, color: Color = PANEL) -> void:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("5d7561")
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	draw_style_box(box,rect)

func bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_style_box(game.style(Color("13251f"),Color.TRANSPARENT,4),rect)
	if fraction > 0:
		draw_style_box(game.style(color,Color.TRANSPARENT,4),Rect2(rect.position,Vector2(rect.size.x*clampf(fraction,0,1),rect.size.y)))

func _draw() -> void:
	if game == null or game.model.state.is_empty(): return
	if full_map: draw_full_map(); return
	draw_speedometer()
	draw_minimap()
	draw_status()

func draw_speedometer() -> void:
	panel(Rect2(22,size.y-174,210,152))
	var center = Vector2(127,size.y-76)
	var maximum = dial_maximum()
	var current = absf(float(game.model.state.v))*3.6
	var start = deg_to_rad(150)
	var span = deg_to_rad(240)
	draw_arc(center,65,start,start+span,64,Color("53705b"),5,true)
	var limit_angle = start + span*nominal_speed()/maximum
	draw_arc(center,65,limit_angle,start+span,24,RED,5,true)
	for i in range(11):
		var angle = start + span*i/10.0
		var radial = Vector2(cos(angle),sin(angle))
		draw_line(center+radial*57,center+radial*65,PAPER if i%2==0 else MUTED,2,true)
		if i%2==0:
			var p = center+radial*82
			put(str(roundi(maximum*i/10.0)),p+Vector2(-20,5),40,12,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var needle = start + span*clampf(current/maximum,0,1)
	draw_line(center,center+Vector2(cos(needle),sin(needle))*52,GOLD,3,true)
	draw_circle(center,5,GOLD)
	# The digital readout remains readable above the moving needle.
	draw_style_box(game.style(PANEL,Color.TRANSPARENT,4),Rect2(center+Vector2(-53,4),Vector2(106,40)))
	put("%.1f" % current,center+Vector2(-53,33),106,30,RED if current>nominal_speed()+0.5 else PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	put("км/ч",center+Vector2(-30,51),60,12,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func draw_minimap() -> void:
	var r = mini_rect()
	panel(r)
	var m = game.model
	var destination = m.next_destination()
	var target = game.station_number(destination)
	put("ДАЛЕЕ · "+m.station_name(destination),r.position+Vector2(18,27),r.size.x-140,18)
	put("Карта [M] ↗",r.position+Vector2(r.size.x-130,27),112,14,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	var left = r.position.x+24
	var right = r.end.x-24
	var y = r.position.y+76
	draw_line(Vector2(left,y),Vector2(right,y),Color("57735d"),4,true)
	var length = float(m.route.station_s[-1])
	var train_x = lerpf(left,right,clampf(float(m.state.s)/length,0,1))
	draw_line(Vector2(left,y),Vector2(train_x,y),GOLD,4,true)
	for i in range(m.route.station_s.size()):
		var x = lerpf(left,right,float(m.route.station_s[i])/length)
		draw_circle(Vector2(x,y),8 if i==target else 5,GOLD if i==target else MUTED)
		put(str(i+1),Vector2(x-12,y+27),24,12,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var drive = m.drive_direction()
	draw_colored_polygon(PackedVector2Array([Vector2(train_x+10*drive,y-17),Vector2(train_x-9*drive,y-24),Vector2(train_x-9*drive,y-10)]),PAPER)
	put("1 · Лесная",Vector2(left,r.end.y-16),r.size.x*0.38,13,MUTED)
	put("%d м до станции" % absf(float(m.route.station_s[target])-float(m.state.s)),Vector2(left+r.size.x*0.25,r.end.y-16),r.size.x*0.48,15,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	put("Дальний бор · 6",Vector2(r.end.x-r.size.x*0.32-24,r.end.y-16),r.size.x*0.32,13,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)

func draw_status() -> void:
	var r = Rect2(size.x-status_width()-22,size.y-174,status_width(),152)
	panel(r)
	var m = game.model
	var stats = m.object_stats(m.vehicle_id())
	var amount = float(m.state.fleet_by_id[m.vehicle_id()].fuel)
	var title: String
	var value: String
	var fraction: float
	if m.vehicle_id()=="handcar":
		title = "РУЧНОЙ ПРИВОД"
		value = "%d / %d Вт" % [roundi(m.output_power),roundi(stats.power)]
		fraction = m.output_power / float(stats.power)
	else:
		title = "АККУМУЛЯТОР" if m.vehicle_id()=="locomotive" else "БЕНЗИН"
		value = "%.2f / %.2f кВт·ч" % [amount,stats.tank] if m.vehicle_id()=="locomotive" else "%.2f / %.1f л" % [amount,stats.tank]
		fraction = amount / maxf(0.001,float(stats.tank))
	put(title,r.position+Vector2(16,24),r.size.x*0.46-16,12,MUTED)
	put(value,r.position+Vector2(r.size.x*0.48,24),r.size.x*0.52-16,14,RED if fraction<=0.15 and m.vehicle_id()!="handcar" else PAPER,HORIZONTAL_ALIGNMENT_RIGHT)
	bar(Rect2(r.position+Vector2(16,36),Vector2(r.size.x-32,8)),fraction,RED if fraction<=0.15 and m.vehicle_id()!="handcar" else GREEN)
	var dry_mass = 0.0
	for id in m.body_ids(): dry_mass += float(m.object_stats(id).mass)
	var half=r.size.x*0.5-24
	put("Состав  %d кг" % m.train_mass(),r.position+Vector2(16,72),half,16)
	put("Груз  %d кг" % (m.train_mass()-dry_mass),r.position+Vector2(r.size.x*0.5+8,72),half,16)
	put("Уклон  %+.1f%%" % (tan(m.route.slope(float(m.state.s)))*100),r.position+Vector2(16,101),half,15,MUTED)
	put("Тормоз  %d%%" % roundi(float(m.state.brake)*100),r.position+Vector2(r.size.x*0.5+8,101),half,15,RED if m.state.brake>0.9 else MUTED)
	var detail = "Макс. скорость  %.0f км/ч" % nominal_speed()
	if m.vehicle_id()=="locomotive" and m.regen_kw>0.01: detail = "Рекуперация  +%.1f кВт" % m.regen_kw
	elif m.vehicle_id()!="handcar": detail += "  ·  "+["Н","I","II"][int(m.state.gear)]
	put(detail,r.position+Vector2(16,132),r.size.x-32,14,GOLD)

func map_point(s: float) -> Vector2:
	var fraction = clampf(s/float(game.model.route.station_s[-1]),0,1)
	return Vector2(90+(size.x-180)*fraction,size.y*0.37+sin(fraction*TAU-0.4)*size.y*0.075)

func draw_full_map() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.04,0.09,0.07,0.92))
	panel(Rect2(22,22,size.x-44,size.y-44))
	put("КАРТА · ЛЕСНАЯ ЛИНИЯ",Vector2(50,67),size.x-350,27)
	put("Белый указатель — состав · выбери станцию · поезд на паузе",Vector2(50,99),size.x-100,16,MUTED)
	var m = game.model
	var total = float(m.route.station_s[-1])
	var route_line = PackedVector2Array()
	var traveled_line = PackedVector2Array([map_point(0)])
	for i in range(201):
		var s = total*i/200.0
		var p = map_point(s)
		route_line.append(p)
		if s>0 and s<float(m.state.s): traveled_line.append(p)
	traveled_line.append(map_point(float(m.state.s)))
	draw_polyline(route_line,Color("13271f"),13,true)
	draw_polyline(route_line,Color("79937a"),5,true)
	if float(m.state.s)>0: draw_polyline(traveled_line,GOLD,5,true)
	station_hits.clear()
	var target = game.station_number(m.next_destination())
	if selected_station<0: selected_station=target
	for i in range(m.data.stations.size()):
		var p = map_point(m.route.station_s[i])
		station_hits.append(p)
		draw_circle(p,14,GOLD if i==target else GREEN)
		draw_circle(p,7,PANEL)
		if i==selected_station: draw_arc(p,21,0,TAU,40,PAPER,2,true)
		var label_y = p.y-48 if i%2==0 else p.y+54
		var label_x = clampf(p.x-115,40,size.x-270)
		put("%d · %s" % [i+1,m.data.stations[i].name],Vector2(label_x,label_y),230,18,GOLD if i==target else PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		put("%.0f м" % float(m.route.station_s[i]),Vector2(label_x,label_y+24),230,13,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var here = map_point(float(m.state.s))
	var direction = m.drive_direction()
	draw_colored_polygon(PackedVector2Array([here+Vector2(13*direction,-27),here+Vector2(-12*direction,-35),here+Vector2(-12*direction,-19)]),PAPER)
	var r = Rect2(50,size.y*0.58,size.x-100,size.y*0.42-78)
	panel(r,Color("172d25"))
	var station = m.data.stations[selected_station]
	put(station.name,r.position+Vector2(22,36),r.size.x*0.48,25)
	put("%d м от состава  ·  отметка %d м" % [absf(float(m.route.station_s[selected_station])-float(m.state.s)),m.route.station_s[selected_station]],r.position+Vector2(22,68),r.size.x*0.48,17,MUTED)
	put("Домашнее депо · оплата, заправка и зарядка" if selected_station==0 else "Остановись у платформы и затяни тормоз для разгрузки",r.position+Vector2(22,102),r.size.x*0.48,17,MUTED)
	var rows: Array = []
	var grouped: Dictionary = {}
	for cargo in m.state.cargo:
		if cargo.destination==station.id:
			if not grouped.has(cargo.type): grouped[cargo.type]={"total":0,"delivered":0}
			grouped[cargo.type].total+=1
			if cargo.delivered: grouped[cargo.type].delivered+=1
	for type in grouped:
		var item = grouped[type]
		var remaining = int(item.total)-int(item.delivered)
		var text = ("✓  " if remaining==0 else "•  ")+str(m.cargo_base(type).name)+" ×"+str(item.total)
		if remaining>0 and int(item.delivered)>0: text += " · осталось "+str(remaining)
		rows.append(text)
	put("ДОСТАВКИ НА СТАНЦИЮ",r.position+Vector2(r.size.x*0.53,34),r.size.x*0.43,15,GOLD)
	if rows.is_empty(): rows.append("Здесь нет груза по текущему рейсу")
	for i in range(mini(rows.size(),4)):
		put(rows[i],r.position+Vector2(r.size.x*0.53,68+i*26),r.size.x*0.43,17)
	put("Вся линия  %.2f км   ·   %s   ·   %.0f кг" % [total/1000,game.vehicle_display_name(),m.train_mass()],Vector2(50,size.y-43),size.x-100,15,MUTED)

func _gui_input(event: InputEvent) -> void:
	if full_map and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for i in range(station_hits.size()):
			if event.position.distance_to(station_hits[i])<38:
				selected_station=i
				queue_redraw()
				accept_event()
