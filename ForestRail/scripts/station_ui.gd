extends RefCounted
# Помощник main.gd (1.3.7): станция: платформа, перекладка груза, обслуживание, прогноз.
# Работает через canvas (main.gd), как depot_ui.gd.

var canvas = null   # main.gd

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func dock_visible() -> bool:
	if canvas.screen!="game" or canvas.cab_active(): return false
	if canvas.drag=="cargo": return true
	var interaction=station_state()
	if not interaction.visible: return false
	# ui-v2: an empty station adds nothing (the old panel said «nothing to unload» on half of the screen)
	if canvas.model.state.phase=="loading": return shelf_count()>0
	return not interaction.eligible.is_empty()

# things that still wait on the shelf of the home station
func shelf_count() -> int:
	var n=0
	for item in canvas.model.state.cargo:
		if not item.delivered and item.slot=="": n+=1
	return n

func station_state() -> Dictionary:
	var result=canvas.model.station_interaction()
	if canvas.drag=="cargo" and canvas.drag_item in result.eligible and result.can_transfer:
		result.phase="dragging"
		result.reason="Отпусти груз на подсвеченную платформу или в панель «Разгрузка»"
	return result

func world_platform_rect(index: int = -1) -> Rect2:
	if index<0: index=int(station_state().station_index)
	var center=float(canvas.model.route.station_s[index])
	var half=canvas.Model.StationInteraction.SERVICE_LENGTH*0.5
	var left=canvas.world_point(center-half)
	var right=canvas.world_point(center+half)
	var height = float(canvas.Geometry.data().reference.platform_height_m)*canvas.ArtV3.PX*canvas.view_scale()
	return Rect2(Vector2(left.x,left.y-height),Vector2(right.x-left.x,height))

func update_cargo_actions(interaction: Dictionary) -> void:
	if not is_instance_valid(canvas.cargo_actions): return
	canvas.cargo_actions.visible=dock_visible()
	var item={}
	for cargo in canvas.model.state.cargo:
		if cargo.id==canvas.selected_cargo and not cargo.delivered and cargo.slot!="": item=cargo
	var available=not item.is_empty() and interaction.can_transfer and (interaction.station_id=="A" or canvas.selected_cargo in interaction.eligible)
	var offer=canvas.model.service_offer()
	var key=canvas.selected_cargo+str(available)+str(item.is_empty())+str(offer.get("station",""))+str(canvas.model.refill_cost())+str(roundi(float(canvas.model.state.money)))+str(canvas.model.casino().bolt_total())
	if key==canvas.cargo_action_key: return
	canvas.cargo_action_key=key
	canvas.clear_children(canvas.cargo_actions)
	canvas.unload_selected_button=null
	if not item.is_empty():
		canvas.unload_selected_button=canvas.add_button(canvas.cargo_actions,"Выгрузить выбранный",func(): transfer_cargo(canvas.selected_cargo,"",world_platform_rect().get_center()),not available)
		canvas.unload_selected_button.add_theme_font_size_override("font_size",int(18*float(canvas.settings.text_scale)))
		canvas.unload_selected_button.tooltip_text="Этот груз ждут в "+canvas.model.station_name(item.destination) if canvas.selected_cargo not in interaction.eligible and interaction.station_id!="A" else interaction.reason
	# Fuel and water on the road: only where the station really has the service.
	if not offer.is_empty() and offer.station!="A":
		var cost=canvas.model.refill_cost()
		var water_short=float(canvas.model.object_stats(canvas.model.vehicle_id()).water)>0 and offer.services.has("water") and float(canvas.model.state.fleet_by_id[canvas.model.vehicle_id()].get("water",0))<float(canvas.model.object_stats(canvas.model.vehicle_id()).water)-0.0001
		var label=""
		var room=canvas.model.tank_missing()>0.0001
		if canvas.model.fuel_service_mult(offer.services)>=0.0: label=({"locomotive":"Зарядить","pneumatic":"Накачать"}.get(canvas.model.vehicle_id(),"Заправить"))+(" · %d монет" % cost if cost>0 else (" · бесплатно" if room else " · полон"))
		if water_short: label+=(" + " if label!="" else "")+"вода"
		if label!="":
			# the fuel is filled as far as the money goes, so one coin is enough to start; the water is free
			var broke=room and cost>0 and int(canvas.model.state.money)<1 and not water_short and not canvas.model.creative()
			var service_button=canvas.add_button(canvas.cargo_actions,label,use_station_service,(not room and not water_short) or broke)
			if broke: service_button.tooltip_text="Не хватает %d монет" % (1-int(canvas.model.state.money))
			service_button.add_theme_font_size_override("font_size",int(18*float(canvas.settings.text_scale)))
	if interaction.can_transfer and canvas.model.casino().receiving_possible() and canvas.model.casino().bolt_total() > 0:
		var desk_button=canvas.add_button(canvas.cargo_actions,"Приёмка болтов (%d)" % canvas.model.casino().bolt_total(),use_station_receiving_button)
		desk_button.add_theme_font_size_override("font_size",int(18*float(canvas.settings.text_scale)))

func use_station_receiving_button() -> void:
	canvas.show_modal("receiving")

func use_station_service() -> void:
	if canvas.model.refuel():
		canvas.save_game()
		canvas.cargo_action_key=""
		canvas.notify(canvas.model.message if canvas.model.message!="" else "Запас пополнен")
		canvas.model.message=""
		canvas.update_hud()
	else: canvas.notify(canvas.model.message)

# One line for the depot panel and the map: what the next trip needs against what is on board.
# B6.4: the steady wind of the line at the stations (without gusts), for the sail car in the depot: where the ride will be easy
func wind_route_line() -> String:
	canvas.model.wind_ready()
	var parts: Array = []
	for i in range(canvas.model.data.stations.size()):
		parts.append("%s %.1f" % [str(canvas.model.data.stations[i].name), canvas.model.wind.strength_at(float(canvas.model.route.station_s[i]))])
	return "Ветер по линии, м/с: " + " · ".join(parts)

func forecast_line(mission: Dictionary = {}) -> String:
	var f=canvas.model.trip_forecast(mission)
	if f.is_empty(): return ""
	var text="Рейс: нужно ~%.2f из %.2f %s" % [f.need,f.have,f.unit]
	if float(f.water_tank)>0: text+=" · вода ~%.0f из %.0f л" % [f.water_need,f.water_have]
	var enough=float(f.have)>=float(f.need) and (float(f.water_tank)<=0 or float(f.water_have)>=float(f.water_need))
	return text+(" · хватит" if enough else " · НЕ ХВАТИТ")

func service_text(id: String) -> String:
	var services=canvas.model.station_services(id)
	var parts: Array = []
	if services.has("fuel"): parts.append("заправка" + (" ×%s" % str(services.fuel).replace(".",",") if float(services.fuel)!=1.0 else ""))
	if services.has("water"): parts.append("вода")
	return " · ".join(parts)

func transfer_cargo(id: String, target: String, from: Vector2) -> bool:
	var interaction=station_state()
	if not interaction.can_transfer:
		canvas.notify(interaction.reason)
		return false
	var item={}
	for cargo in canvas.model.state.cargo:
		if cargo.id==id: item=cargo
	if item.is_empty() or item.delivered: return false
	var delivered_here=target=="" and item.destination==interaction.station_id
	var sprite_id=str(canvas.model.cargo_base(item.type).sprite)
	if not canvas.model.transfer(id,target):
		canvas.notify(canvas.model.message)
		return false
	if delivered_here:
		var platform=world_platform_rect()
		var landing=Vector2(clampf(from.x,platform.position.x+20,platform.end.x-20),platform.position.y)
		canvas.delivery_ghost={"sprite":sprite_id,"from":from,"to":landing,"time":0.0}
		canvas.selected_cargo=""
		canvas.notify("Доставлено в «%s». Выгружено %d из %d" % [interaction.station_name,interaction.delivered+1,interaction.total])
	canvas.model.message=""
	canvas.cargo_action_key=""
	canvas.save_game()
	canvas.update_hud()
	return true

func dock_rect() -> Rect2:
	var size = canvas.get_viewport_rect().size
	var hud = canvas.instruments.hud_top() if canvas.instruments != null and is_instance_valid(canvas.instruments) else size.y-174
	return Rect2(36,hud-156,size.x-72,144)
