extends Control

const PAPER = Color("f5ecd6")
const MUTED = Color("b9c7b2")
const GOLD = Color("d6b875")
const GREEN = Color("7fab85")
const RED = Color("e18265")
const PANEL = Color("203730")
var game
var panel_styles: Dictionary = {}
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
const MAP_MIN_SPAN_M = 150.0
# Visible stretch of the full map; a negative end means the whole line.
var view_from = 0.0
var view_to = -1.0
var panning = false
const WINDOW_AHEAD_M = 400.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if full_map else Control.MOUSE_FILTER_IGNORE

# The driving HUD redraws about 30 times a second: the needle and the minimap marker
# move slowly, and every redraw costs a few milliseconds at 1080p.
var redraw_clock = 0.0

func _process(delta: float) -> void:
	redraw_clock += delta
	if full_map or redraw_clock >= 1.0 / 30.0:
		redraw_clock = 0.0
		queue_redraw()

func nominal_speed() -> float:
	if game.model.top_speed_kmh() > 0.0: return game.model.top_speed_kmh()
	var speeds = game.model.object_stats(game.model.vehicle_id()).speeds
	var top = 0.0
	for s in speeds: top = maxf(top, float(s))
	return top * 3.6

func dial_maximum() -> float:
	var nominal = nominal_speed()
	var step = 5.0 if nominal <= 40 else 10.0
	return ceilf(nominal * 1.1 / step - 0.0001) * step

func mini_rect() -> Rect2:
	return Rect2(244,hud_top(),maxf(240,size.x-244-status_width()-34),hud_height())

func status_width() -> float:
	return 312*clampf(float(game.settings.text_scale),1,1.5)

# Bottom strip: about 11 % of a 900 px window at normal text (TZ 3.1 N7.1
# asks 9-11 % for the minimap), growing up to 120 px for 150 % text.
func hud_height() -> float:
	return roundf(100.0+40.0*(clampf(float(game.settings.text_scale),1,1.5)-1.0))

func hud_top() -> float:
	return size.y-22-hud_height()

func permanent_panel_height() -> float:
	return 46+hud_height()

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

func panel(rect: Rect2, color: Color = PANEL, accent: Color = Color.TRANSPARENT) -> void:
	var key = "%s|%s" % [color.to_html(), accent.to_html()]
	var box = panel_styles.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = color
		box.border_color = Color("5d7561") if accent.a == 0.0 else Color(accent, 0.55)
		box.set_border_width_all(1)
		box.set_corner_radius_all(12)
		panel_styles[key] = box
	draw_style_box(box,rect)
	if accent.a > 0.0:
		draw_style_box(game.style(accent,Color.TRANSPARENT,3),Rect2(rect.position+Vector2(0,14),Vector2(4,rect.size.y-28)))

# Fuel, charge and pressure bars: green while healthy, amber when low, red when almost empty.
func level_color(fraction: float) -> Color:
	if fraction <= 0.15: return Color("e0564a")
	if fraction <= 0.35: return Color("e6b34a")
	return Color("5cc17f")

func slope_color(percent: float) -> Color:
	if percent >= 4.0: return Color("e8825a")
	if percent >= 1.5: return Color("e6c25a")
	if percent <= -1.5: return Color("78b8d8")
	return MUTED

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
	var r=Rect2(22,hud_top(),210,hud_height())
	panel(r,Color("1a2a2e"),Color("d9b45a"))
	var f=r.size.y/100.0
	var center=r.position+Vector2(66,56*f)
	var radius=34.0*f
	var maximum=dial_maximum()
	var current=absf(float(game.model.state.v))*3.6
	var nominal=nominal_speed()/maximum
	var start=deg_to_rad(150)
	var span=deg_to_rad(240)
	# Brass bezel, dark face, then coloured zones: calm, getting fast, over the limit.
	draw_circle(center+Vector2(1.5,2.5),radius+9,Color(0,0,0,0.35))
	draw_circle(center,radius+9,Color("a98a4a"))
	draw_circle(center,radius+7,Color("2a2218"))
	draw_circle(center,radius+5,Color("0f1a1c"))
	draw_arc(center,radius-1,start,start+span*nominal*0.72,24,Color("5cc17f"),5,true)
	draw_arc(center,radius-1,start+span*nominal*0.72,start+span*nominal,12,Color("e6b34a"),5,true)
	draw_arc(center,radius-1,start+span*nominal,start+span,16,Color("e0564a"),5,true)
	for i in range(21):
		var angle=start+span*i/20.0
		var radial=Vector2(cos(angle),sin(angle))
		var major=i%2==0
		draw_line(center+radial*(radius-(10 if major else 6)),center+radial*(radius-4),PAPER if major else MUTED,2 if major else 1,true)
	var needle=start+span*clampf(current/maximum,0,1)
	var direction=Vector2(cos(needle),sin(needle))
	draw_line(center+Vector2(1,1.5),center+direction*(radius-3)+Vector2(1,1.5),Color(0,0,0,0.45),3,true)
	draw_line(center-direction*7,center+direction*(radius-3),Color("f3ead2"),3,true)
	draw_line(center+direction*(radius-12),center+direction*(radius-3),Color("e0564a"),3,true)
	draw_circle(center,5,Color("c9af73"))
	draw_circle(center,2,Color("1a1612"))
	put("0",center+Vector2(-radius-4,radius*0.75+8),20,11,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	put(str(roundi(maximum)),center+Vector2(radius-16,radius*0.75+8),30,11,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	# Digital readout beside the dial; its colour follows the zone the needle is in.
	var digits=Color("5cc17f")
	if current>nominal_speed()+0.5: digits=Color("e0564a")
	elif current>nominal_speed()*0.72: digits=Color("e6b34a")
	put("%.1f" % current,r.position+Vector2(124,52*f),78,30,digits,HORIZONTAL_ALIGNMENT_CENTER)
	put("км/ч",r.position+Vector2(124,76*f),78,12,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func draw_minimap() -> void:
	var r = mini_rect()
	panel(r,Color("1b2d30"),Color("5fb3b0"))
	var m = game.model
	var destination = m.next_destination()
	var target = game.station_number(destination)
	var f=r.size.y/100.0
	put("ДАЛЕЕ · %s · %d м" % [m.station_name(destination),absf(float(m.route.station_s[target])-float(m.state.s))],r.position+Vector2(18,24*f),r.size.x*0.55-18,17)
	# The strip shows the stretch around the train, mostly ahead of it; A stays
	# on the left and F on the right in both directions (TZ 3.1 N7.1).
	var drive=m.drive_direction()
	var here=float(m.state.s)
	var total=float(m.route.station_s[-1])
	var from_s=here-(WINDOW_BEHIND_M if drive>0 else WINDOW_AHEAD_M)
	var to_s=here+(WINDOW_AHEAD_M if drive>0 else WINDOW_BEHIND_M)
	if from_s<0: to_s-=from_s;from_s=0.0
	if to_s>total: from_s=maxf(0,from_s-(to_s-total));to_s=total
	# Rows: title with the climb ahead, profile, station names.
	var area=Rect2(r.position.x+24,r.position.y+38*f,r.size.x-48,30*f)
	draw_profile(area,from_s,to_s,area.end.y+8,100,3)
	for i in range(m.route.station_s.size()):
		var station_s=float(m.route.station_s[i])
		if station_s<from_s or station_s>to_s: continue
		var p=profile_point(station_s,area,from_s,to_s)
		draw_line(p,Vector2(p.x,area.end.y+8),Color(MUTED,0.4),1)
		draw_circle(p,7 if i==target else 5,GOLD if i==target else PAPER)
		draw_circle(p,2.5,PANEL)
		put("%d · %s" % [i+1,m.data.stations[i].name],Vector2(clampf(p.x-90,area.position.x,area.end.x-180),r.end.y-8*f),180,12,GOLD if i==target else MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	# Train from tail to head, then the direction arrow at the head.
	var tail=m.body_s(m.body_ids().size()-1)
	var head_point=profile_point(here,area,from_s,to_s)
	draw_line(profile_point(tail,area,from_s,to_s)+Vector2(0,-6),head_point+Vector2(0,-6),Color("f0c75e"),5,true)
	draw_colored_polygon(PackedVector2Array([head_point+Vector2(10*drive,-13),head_point+Vector2(-9*drive,-20),head_point+Vector2(-9*drive,-6)]),Color("f0c75e"))
	var climb=climb_ahead(WINDOW_AHEAD_M)
	var ahead="Впереди без крутых подъёмов"
	if not climb.is_empty(): ahead="Подъём +%.1f%% — сейчас" % climb.grade if climb.distance<10 else "Подъём +%.1f%% через %d м" % [climb.grade,climb.distance]
	put(ahead,Vector2(r.position.x+r.size.x*0.55,24*f+r.position.y),r.size.x*0.45-18,14,GOLD if not climb.is_empty() else MUTED,HORIZONTAL_ALIGNMENT_RIGHT)

func draw_status() -> void:
	var r = Rect2(size.x-status_width()-22,hud_top(),status_width(),hud_height())
	var f=r.size.y/100.0
	var accent={"handcar":Color("8fc46a"),"steam":Color("e8825a"),"motorcar":Color("e6b34a"),"locomotive":Color("6cc4e0")}.get(game.model.vehicle_id(),GOLD)
	panel(r,Color("2a2a22") if game.model.vehicle_id()=="motorcar" else Color("1f2f30"),accent)
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
		title = {"locomotive":"АККУМУЛЯТОР","steam":"УГОЛЬ · ВОДА"}.get(m.vehicle_id(),"БЕНЗИН")
		value = "%.2f / %.2f кВт·ч" % [amount,stats.tank] if m.vehicle_id()=="locomotive" else "%.2f / %.1f л" % [amount,stats.tank]
		fraction = amount / maxf(0.001,float(stats.tank))
		if m.vehicle_id()=="steam":
			title = "ПАР  ·  %.1f бар" % m.pressure_bar()
			value = "ведро %.0f кг · %.0f л" % [amount,float(m.state.fleet_by_id.steam.get("water",0))]
			fraction = float(m.boiler().pressure)
	if m.vehicle_id()=="motorcar": title+="  ·  %s  ·  %.1fк" % [{0:"N",1:"1",2:"2",3:"3",4:"4",5:"R"}[int(m.state.gear)],m.engine_rpm()/1000.0]
	if m.vehicle_id()=="locomotive" and m.regen_kw>0.01: title="РЕКУПЕРАЦИЯ +%.1f кВт" % m.regen_kw
	var level=level_color(fraction) if m.vehicle_id()!="handcar" else Color("8fc46a")
	put(title,r.position+Vector2(16,22*f),r.size.x*0.5-16,12,Color("6cc4e0") if m.regen_kw>0.01 else accent)
	put(value,r.position+Vector2(r.size.x*0.48,22*f),r.size.x*0.52-16,14,level if fraction<=0.35 and m.vehicle_id()!="handcar" else PAPER,HORIZONTAL_ALIGNMENT_RIGHT)
	bar(Rect2(r.position+Vector2(16,30*f),Vector2(r.size.x-32,6)),fraction,level)
	var dry_mass = 0.0
	for id in m.body_ids(): dry_mass += float(m.object_stats(id).mass)
	var half=r.size.x*0.5-24
	# The speed limit lives on the speedometer's red arc, gear in the title.
	put("Состав  %d кг" % m.train_mass(),r.position+Vector2(16,62*f),half,15)
	put("Груз  %d кг" % (m.train_mass()-dry_mass),r.position+Vector2(r.size.x*0.5+8,62*f),half,15)
	var grade=tan(m.route.slope(float(m.state.s)))*100
	put("Уклон  %+.1f%%" % grade,r.position+Vector2(16,88*f),half,14,slope_color(grade))
	put("Тормоз  %d%%" % roundi(float(m.state.brake)*100),r.position+Vector2(r.size.x*0.5+8,88*f),half,14,Color("e0564a") if m.state.brake>0.9 else (Color("e6b34a") if m.state.brake>0.05 else MUTED))

func map_area() -> Rect2:
	return Rect2(90,size.y*0.24,size.x-180,size.y*0.2)

func map_view() -> Vector2:
	var total=float(game.model.route.station_s[-1])
	return Vector2(0,total) if view_to<0 else Vector2(view_from,view_to)

func map_point(s: float) -> Vector2:
	var view=map_view()
	return profile_point(s,map_area(),view.x,view.y)

func set_map_view(from_s: float, to_s: float) -> void:
	var total=float(game.model.route.station_s[-1])
	var span=clampf(to_s-from_s,MAP_MIN_SPAN_M,total)
	from_s=clampf(from_s,0,total-span)
	view_from=from_s
	view_to=from_s+span if span<total-0.5 else -1.0
	queue_redraw()

func map_s_at(x: float) -> float:
	var view=map_view()
	var area=map_area()
	return lerpf(view.x,view.y,clampf((x-area.position.x)/area.size.x,0,1))

# Small conifers under the profile; positions are fixed per index.
func draw_map_forest(total: float, floor_y: float) -> void:
	for j in range(110):
		var s=fposmod(sin(j*12.9898)*43758.5453,1.0)*total
		if s<map_view().x or s>map_view().y: continue
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
	var view=map_view()
	var zoomed=view_to>=0
	put("Профиль пути · высота увеличена ×%d · %s" % [roundi(vertical_exaggeration(area,view.x,view.y)),"участок %.0f–%.0f м · двойной щелчок — вся линия" % [view.x,view.y] if zoomed else "колесо — приблизить, перетащи — сдвинуть, щелчок по выбранной станции — её участок"],Vector2(50,99),size.x-100,16,MUTED)
	draw_profile(area,view.x,view.y,floor_y,240,5)
	draw_map_forest(total,floor_y)
	station_hits.clear()
	var target = game.station_number(m.next_destination())
	if selected_station<0: selected_station=target
	for i in range(m.data.stations.size()):
		var station_s=float(m.route.station_s[i])
		# Hidden stations keep their slot so hit indices match station indices.
		if station_s<view.x-1 or station_s>view.y+1:
			station_hits.append(Vector2(-10000,-10000))
			continue
		var p = map_point(station_s)
		station_hits.append(p)
		draw_line(p,Vector2(p.x,floor_y),Color(MUTED,0.3),1)
		draw_circle(p,14,GOLD if i==target else GREEN)
		draw_circle(p,7,PANEL)
		if i==selected_station: draw_arc(p,21,0,TAU,40,PAPER,2,true)
		var label_y = p.y-48 if i%2==0 else floor_y+30
		var label_x = clampf(p.x-115,40,size.x-270)
		put("%d · %s" % [i+1,m.data.stations[i].name],Vector2(label_x,label_y),230,18,GOLD if i==target else PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		var services_text=game.service_text(str(m.data.stations[i].id))
		put("%.0f м" % float(m.route.station_s[i])+(" · "+services_text if services_text!="" else ""),Vector2(label_x,label_y+24),230,13,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var here = map_point(float(m.state.s))
	var direction = m.drive_direction()
	if float(m.state.s)>=view.x and float(m.state.s)<=view.y: draw_colored_polygon(PackedVector2Array([here+Vector2(13*direction,-27),here+Vector2(-12*direction,-35),here+Vector2(-12*direction,-19)]),PAPER)
	var r = Rect2(50,size.y-78-200,size.x-100,200)
	panel(r,Color("172d25"))
	var station = m.data.stations[selected_station]
	put(station.name,r.position+Vector2(22,36),r.size.x*0.48,25)
	put("%d м от состава  ·  отметка %d м" % [absf(float(m.route.station_s[selected_station])-float(m.state.s)),m.route.station_s[selected_station]],r.position+Vector2(22,68),r.size.x*0.48,17,MUTED)
	var services_here=game.service_text(str(station.id))
	put(("Домашнее депо · оплата, " if selected_station==0 else "Остановись у платформы и затяни тормоз · ")+("услуги: "+services_here if services_here!="" else "услуг нет"),r.position+Vector2(22,102),r.size.x*0.48,17,MUTED)
	var forecast=game.forecast_line()
	if forecast!="": put(forecast,r.position+Vector2(22,134),r.size.x*0.48,15,GOLD if forecast.ends_with("хватит") else Color("e0564a"))
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
	if not full_map: return
	var view=map_view()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		# Zoom about the distance under the cursor.
		var anchor=map_s_at(event.position.x)
		var k=0.8 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.25
		set_map_view(anchor-(anchor-view.x)*k,anchor+(view.y-anchor)*k)
		accept_event()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			panning=false
			return
		if event.double_click:
			set_map_view(0,float(game.model.route.station_s[-1]))
			accept_event()
			return
		for i in range(station_hits.size()):
			if event.position.distance_to(station_hits[i])<38:
				# A second click on the selected station shows its stretch.
				if i==selected_station:
					var at=float(game.model.route.station_s[i])
					set_map_view(at-300,at+300)
				selected_station=i
				queue_redraw()
				accept_event()
				return
		panning=map_area().grow(80).has_point(event.position)
		if panning: accept_event()
	elif event is InputEventMouseMotion and panning:
		var shift=-event.relative.x*(view.y-view.x)/map_area().size.x
		set_map_view(view.x+shift,view.y+shift)
		accept_event()
