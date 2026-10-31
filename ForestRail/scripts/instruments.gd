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
var profile_key: Array = []
var profile_low = 0.0
var profile_high = 1.0
# Track heights are small; a floor on the range keeps metre-high humps from
# filling the whole band, and the map states the resulting exaggeration.
const PROFILE_MIN_RANGE_M = 4.0
const WINDOW_BEHIND_M = 100.0
const WINDOW_AHEAD_M = 400.0

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

# Height range of the saved route; same samples the wheels use (TZ 3.1 N7.1).
func ensure_profile() -> void:
	var route=game.model.route
	var key=[route.seed_value,route.points.size()]
	if key==profile_key: return
	profile_key=key
	var total=float(route.station_s[-1])
	profile_low=INF
	profile_high=-INF
	for i in range(241):
		var h=route.sample(total*i/240.0).y
		profile_low=minf(profile_low,h)
		profile_high=maxf(profile_high,h)
	var middle=(profile_low+profile_high)*0.5
	var half=maxf(PROFILE_MIN_RANGE_M,profile_high-profile_low)*0.5
	profile_low=middle-half
	profile_high=middle+half

func profile_y(s: float, area: Rect2) -> float:
	ensure_profile()
	var fraction=clampf((game.model.route.sample(s).y-profile_low)/(profile_high-profile_low),0,1)
	return area.position.y+(1.0-fraction)*area.size.y

# Point of the profile for distance s when the area shows [from_s, to_s].
func profile_point(s: float, area: Rect2, from_s: float, to_s: float) -> Vector2:
	var fraction=clampf((s-from_s)/maxf(1,to_s-from_s),0,1)
	return Vector2(area.position.x+area.size.x*fraction,profile_y(s,area))

func vertical_exaggeration(area: Rect2, from_s: float, to_s: float) -> float:
	ensure_profile()
	return (area.size.y/(profile_high-profile_low))/(area.size.x/maxf(1,to_s-from_s))

# Line, traveled part and a vertical fill gradient down to floor_y.
func draw_profile(area: Rect2, from_s: float, to_s: float, floor_y: float, samples: int, width: float) -> void:
	var here=float(game.model.state.s)
	var line=PackedVector2Array()
	var traveled=PackedVector2Array()
	for i in range(samples+1):
		var s=lerpf(from_s,to_s,i/float(samples))
		var p=profile_point(s,area,from_s,to_s)
		line.append(p)
		if s<=here: traveled.append(p)
	if here>=from_s and here<=to_s: traveled.append(profile_point(here,area,from_s,to_s))
	var top=Color(0.36,0.55,0.4,0.45)
	var bottom=Color(top,0.0)
	for i in range(line.size()-1):
		var a=line[i]
		var b=line[i+1]
		draw_polygon(PackedVector2Array([a,b,Vector2(b.x,floor_y),Vector2(a.x,floor_y)]),PackedColorArray([top,top,bottom,bottom]))
	draw_polyline(line,Color("13271f"),width+6,true)
	draw_polyline(line,Color("8fae8f"),width,true)
	if traveled.size()>1: draw_polyline(traveled,GOLD,width,true)

# First climb steeper than 1.5 % within the window ahead, in travel direction.
func climb_ahead(limit_m: float) -> Dictionary:
	var m=game.model
	var drive=m.drive_direction()
	var here=float(m.state.s)
	for step in range(0,int(limit_m),5):
		var s=here+drive*step
		if s<0 or s>float(m.route.station_s[-1]): break
		var grade=tan(m.route.slope(s))*100.0*drive
		if grade>1.5:
			var peak=grade
			for extra in range(5,80,5): peak=maxf(peak,tan(m.route.slope(s+drive*extra))*100.0*drive)
			return {"distance":step,"grade":peak}
	return {}

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
	# The strip shows the stretch around the train, mostly ahead of it; A stays
	# on the left and F on the right in both directions (TZ 3.1 N7.1).
	var drive=m.drive_direction()
	var here=float(m.state.s)
	var total=float(m.route.station_s[-1])
	var from_s=here-(WINDOW_BEHIND_M if drive>0 else WINDOW_AHEAD_M)
	var to_s=here+(WINDOW_AHEAD_M if drive>0 else WINDOW_BEHIND_M)
	if from_s<0: to_s-=from_s;from_s=0.0
	if to_s>total: from_s=maxf(0,from_s-(to_s-total));to_s=total
	var area=Rect2(r.position.x+24,r.position.y+48,r.size.x-48,40)
	draw_profile(area,from_s,to_s,area.end.y+14,100,3)
	for i in range(m.route.station_s.size()):
		var station_s=float(m.route.station_s[i])
		if station_s<from_s or station_s>to_s: continue
		var p=profile_point(station_s,area,from_s,to_s)
		draw_line(p,Vector2(p.x,area.end.y+14),Color(MUTED,0.4),1)
		draw_circle(p,7 if i==target else 5,GOLD if i==target else PAPER)
		draw_circle(p,2.5,PANEL)
		put("%d · %s" % [i+1,m.data.stations[i].name],Vector2(clampf(p.x-90,area.position.x,area.end.x-180),area.end.y+30),180,12,GOLD if i==target else MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	# Train from tail to head, then the direction arrow at the head.
	var tail=m.body_s(m.body_ids().size()-1)
	var head_point=profile_point(here,area,from_s,to_s)
	draw_line(profile_point(tail,area,from_s,to_s)+Vector2(0,-6),head_point+Vector2(0,-6),PAPER,5,true)
	draw_colored_polygon(PackedVector2Array([head_point+Vector2(10*drive,-13),head_point+Vector2(-9*drive,-20),head_point+Vector2(-9*drive,-6)]),PAPER)
	var climb=climb_ahead(WINDOW_AHEAD_M)
	var ahead="Впереди без крутых подъёмов"
	if not climb.is_empty(): ahead="Подъём +%.1f%% — сейчас" % climb.grade if climb.distance<10 else "Подъём +%.1f%% через %d м" % [climb.grade,climb.distance]
	put(ahead,Vector2(area.position.x,r.end.y-14),r.size.x*0.45,14,GOLD if not climb.is_empty() else MUTED)
	put("%d м до станции" % absf(float(m.route.station_s[target])-here),Vector2(r.end.x-r.size.x*0.45-24,r.end.y-14),r.size.x*0.45,14,PAPER,HORIZONTAL_ALIGNMENT_RIGHT)

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

func map_area() -> Rect2:
	return Rect2(90,size.y*0.24,size.x-180,size.y*0.2)

func map_point(s: float) -> Vector2:
	return profile_point(s,map_area(),0,float(game.model.route.station_s[-1]))

# Small conifers under the profile; positions are fixed per index.
func draw_map_forest(total: float, floor_y: float) -> void:
	for j in range(110):
		var s=fposmod(sin(j*12.9898)*43758.5453,1.0)*total
		var p=map_point(s)
		var depth=26+fposmod(sin(j*78.233)*12345.678,1.0)*maxf(10,floor_y-p.y-30)
		var h=11+fposmod(sin(j*3.7)*9631.1,1.0)*10
		var foot=p+Vector2(0,depth)
		draw_colored_polygon(PackedVector2Array([foot+Vector2(0,-h),foot+Vector2(-h*0.42,0),foot+Vector2(h*0.42,0)]),Color("21402f") if j%3 else Color("2c5139"))

func draw_full_map() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.04,0.09,0.07,0.92))
	panel(Rect2(22,22,size.x-44,size.y-44))
	put("КАРТА · ЛЕСНАЯ ЛИНИЯ",Vector2(50,67),size.x-350,27)
	var m = game.model
	var total = float(m.route.station_s[-1])
	var area=map_area()
	var floor_y=area.end.y+90
	put("Профиль пути · высота увеличена ×%d · белый указатель — состав · выбери станцию" % roundi(vertical_exaggeration(area,0,total)),Vector2(50,99),size.x-100,16,MUTED)
	draw_profile(area,0,total,floor_y,240,5)
	draw_map_forest(total,floor_y)
	station_hits.clear()
	var target = game.station_number(m.next_destination())
	if selected_station<0: selected_station=target
	for i in range(m.data.stations.size()):
		var p = map_point(m.route.station_s[i])
		station_hits.append(p)
		draw_line(p,Vector2(p.x,floor_y),Color(MUTED,0.3),1)
		draw_circle(p,14,GOLD if i==target else GREEN)
		draw_circle(p,7,PANEL)
		if i==selected_station: draw_arc(p,21,0,TAU,40,PAPER,2,true)
		var label_y = p.y-48 if i%2==0 else floor_y+30
		var label_x = clampf(p.x-115,40,size.x-270)
		put("%d · %s" % [i+1,m.data.stations[i].name],Vector2(label_x,label_y),230,18,GOLD if i==target else PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		put("%.0f м" % float(m.route.station_s[i]),Vector2(label_x,label_y+24),230,13,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var here = map_point(float(m.state.s))
	var direction = m.drive_direction()
	draw_colored_polygon(PackedVector2Array([here+Vector2(13*direction,-27),here+Vector2(-12*direction,-35),here+Vector2(-12*direction,-19)]),PAPER)
	var r = Rect2(50,size.y-78-200,size.x-100,200)
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
