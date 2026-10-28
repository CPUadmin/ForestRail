extends RefCounted

const Geometry = preload("res://scripts/world_geometry.gd")
const SERVICE_LENGTH = 18.0
const STOP_SPEED = 0.05
const BRAKE = 0.95
const DWELL = 0.25

static func train_bounds(model) -> Vector2:
	var lo = INF
	var hi = -INF
	var ids = model.body_ids()
	for i in range(ids.size()):
		var half = Geometry.length(ids[i])*0.5 + float(Geometry.data().coupler.end_extension_m)
		lo=minf(lo,model.body_s(i)-half)
		hi=maxf(hi,model.body_s(i)+half)
	return Vector2(lo,hi)

static func stop_position(model, index: int) -> float:
	var bounds = train_bounds(model)
	return float(model.route.station_s[index])+float(model.state.s)-(bounds.x+bounds.y)*0.5

static func evaluate(model) -> Dictionary:
	var nearest = 0
	for i in range(model.route.station_s.size()):
		if absf(float(model.route.station_s[i])-float(model.state.s))<absf(float(model.route.station_s[nearest])-float(model.state.s)): nearest=i
	var center = float(model.route.station_s[nearest])
	var interval = Vector2(center-SERVICE_LENGTH*0.5,center+SERVICE_LENGTH*0.5)
	var bounds = train_bounds(model)
	var in_zone = bounds.x>=interval.x-0.5 and bounds.y<=interval.y+0.5
	var visible = absf(float(model.state.s)-center)<45
	var id = str(model.data.stations[nearest].id)
	var total = 0
	var delivered = 0
	var eligible: Array = []
	for item in model.state.cargo:
		if item.destination!=id: continue
		total+=1
		if item.delivered: delivered+=1
		elif item.slot!="": eligible.append(item.id)
	var target = stop_position(model,nearest)
	var stationary = absf(float(model.state.v))<=STOP_SPEED
	var secured = float(model.state.brake)>=BRAKE
	var elapsed = model.stationary_seconds if model.stationary_station==nearest and in_zone and stationary and secured else 0.0
	var can_transfer = in_zone and stationary and secured and elapsed>=DWELL-0.00001 and model.state.phase!="depot"
	var phase = "ready"
	var reason = ""
	if not visible: phase="approaching";reason="Подъедь к станции"
	elif not in_zone: phase="position_required";reason="Подвинь состав %s на %.1f м к отметке остановки" % ["→" if target>float(model.state.s) else "←",absf(target-float(model.state.s))]
	elif not stationary: phase="stop_required";reason="Остановись для разгрузки"
	elif not secured: phase="brake_required";reason="Затяни красный тормоз до конца"
	elif not can_transfer: phase="stop_required";reason="Дождись полной остановки (0,25 с)"
	elif not model.state.active.is_empty() and model.state.active.get("phase","")=="return":
		phase="return_home";reason="Все доставки выполнены. Вернись в Лесную. К выплате: %d монет" % model.state.active.pending_reward
	elif model.state.phase=="loading": reason="Перетащи груз со склада в свободные места на составе"
	elif total==0: phase="station_complete";reason="Здесь нет груза для разгрузки. Следующая: "+model.station_name(model.next_destination())
	elif delivered==total: phase="station_complete";reason="Всё для этой станции выгружено. Следующая: "+model.station_name(model.next_destination())
	elif delivered>0: phase="partial";reason="Выгружено %d из %d. Осталось: %d" % [delivered,total,total-delivered]
	else: reason="К разгрузке: %d. Перенеси груз на подсвеченную платформу или в панель" % eligible.size()
	return {"station_index":nearest,"station_id":id,"station_name":model.station_name(id),"service_interval_m":interval,
		"stop_s":target,"train_bounds_m":bounds,"in_zone":in_zone,"visible":visible,"velocity":float(model.state.v),
		"brake":float(model.state.brake),"stationary_seconds":elapsed,"total":total,"delivered":delivered,"remaining":total-delivered,
		"eligible":eligible,"can_transfer":can_transfer,"phase":phase,"reason":reason}
