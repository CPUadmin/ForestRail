extends RefCounted
# Помощник main.gd (1.3.7): органы управления на машине: где рычаги, как их рисовать и ловить мышью, полоска заряда.
# Работает через canvas (main.gd), как depot_ui.gd.

var canvas = null   # main.gd

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func lever_geometry(id: String) -> Dictionary:
	if id == "pump":
		var pose = canvas.art.mechanism_pose(canvas.model)
		return {"pivot":pose.rocker*canvas.ArtV3.PX,"grip":pose.grip_right*canvas.ArtV3.PX,"angle":pose.angle}
	return control_geometry(id)

# Where a control stands on the machine, metres. The sail car's brake stands at the bow, the end the
# sail never reaches (the boom always runs aft of the mast), so that it cannot be mistaken for the sail.
func control_anchor(id: String) -> Vector2:
	var anchor = canvas.art.vec(canvas.Geometry.body(canvas.model.vehicle_id()).control_anchors_m[id])
	if canvas.model.vehicle_id() == "sail" and id == "brake": return Vector2(1.0 * float(int(canvas.model.state.direction)), anchor.y)
	return anchor

func control_geometry(id: String, closeup: bool = false) -> Dictionary:
	var kind=canvas.control_kind(id)
	if kind=="slider":
		var slot_pivot=control_anchor(id)*canvas.ArtV3.PX
		var slot_length=0.40*canvas.ArtV3.PX
		if closeup:
			slot_pivot=canvas.control_zoom_rect().position+Vector2(65+100*["brake","throttle","gear","start"].find(id),230)
			slot_length=124.0
			if canvas.electric_cab().revised():   # 1.12: the slots of the painted board of the electric cab
				var slot = canvas.electric_cab().slider_geometry(id)
				slot_pivot = slot.pivot
				slot_length = float(slot.length)
		elif not canvas.art.is_skinned("locomotive"):
			# The factory cab has two clear panels between the window and steps.
			slot_pivot = canvas.art.stock_body_point("locomotive", Vector2(200 if id == "brake" else 310, 562))
			slot_length = 0.32 * canvas.ArtV3.PX
		var amount=float(canvas.model.state.get(id,0))
		return {"pivot":slot_pivot,"grip":slot_pivot+Vector2(0,-slot_length*amount),"angle":0.0,"length":slot_length}
	if kind=="gate":
		var rect=canvas.gate_rect(closeup)
		var knob=canvas.gate_pos if canvas.drag=="gear" else canvas.gate_slot_pos(int(canvas.model.state.gear))
		return {"pivot":rect.get_center(),"grip":canvas.gate_local(rect,knob),"angle":0.0}
	if kind=="key":
		var centre=control_anchor(id)*canvas.ArtV3.PX
		var side=canvas.KEY_LOCK_M*canvas.ArtV3.PX
		var choke_side=side*canvas.Ignition.CHOKE_RATIO
		var choke=centre-Vector2(side*0.56+choke_side*0.5,0)
		if closeup:
			# 16.11: the lock is set into the dashboard right under the gauges, no longer in the pult; pult coordinates
			var size=canvas.get_viewport_rect().size
			var right=canvas.cab_art().petrol_right(size,canvas.cab_layout(size))
			var back=canvas.pult_t.affine_inverse()
			var k=canvas.pult_t.get_scale().x
			centre=back*Vector2(right.lock)
			side=float(right.side)/k
			choke=back*Vector2(right.choke)
			choke_side=float(right.choke_side)/k
		return {"pivot":centre,"grip":centre,"angle":canvas.ignition().angle,"side":side,"choke":choke,"choke_side":choke_side}
	if kind=="wheel":
		var radius=34.0 if closeup else 0.17*canvas.ArtV3.PX
		var center=control_anchor(id)*canvas.ArtV3.PX
		if closeup: center=canvas.control_zoom_rect().position+Vector2(65+100*["brake","throttle","gear","start"].find(id),188)
		var turn=((canvas.model.reducer_position() if canvas.model.vehicle_id()=="pneumatic" else float(canvas.model.boiler().feed)) if id=="gear" else float(canvas.model.state.throttle))*canvas.wheel_sweep()
		return {"pivot":center,"grip":center+Vector2(0,-radius).rotated(turn),"angle":turn,"radius":radius}
	var pivot=control_anchor(id)*canvas.ArtV3.PX
	var length_key = id + "_length_m"
	var body_spec = canvas.Geometry.body(canvas.model.vehicle_id())
	var length = float(body_spec.get(length_key, canvas.Geometry.data().controls[length_key])) * canvas.ArtV3.PX
	if closeup:
		pivot=canvas.control_zoom_rect().position+Vector2(65+100*["brake","throttle","gear","start"].find(id),225)
		length=42.0 if id=="start" else 78.0
	var value=float(canvas.model.state.get(id,0))
	if id=="gear": value=float(canvas.model.boiler().feed) if canvas.model.vehicle_id()=="steam" else float(canvas.GEAR_ORDER.find(canvas.lever_pending_gear if canvas.drag=="gear" else int(canvas.model.state.gear)))/6.0
	var angle=lerpf(-0.55,0.55,value)
	if id=="start": angle=0.0 if (canvas.model.heating_on() if canvas.model.vehicle_id()=="pneumatic" else canvas.model.state.engine) else PI
	return {"pivot":pivot,"grip":pivot+Vector2(0,-length).rotated(angle),"angle":angle}

func draw_controls_inner(body_transform: Transform2D, show_labels: bool = true) -> void:
	var ids = canvas.world_control_ids()
	var hover = canvas.get_global_mouse_position()
	if canvas.model.vehicle_id()=="handcar":
		var left_grip=canvas.model.handcar.pose().grip_left*canvas.ArtV3.PX
		if canvas.drag=="pump" and canvas.pump_grip_side<0 or hover.distance_to(body_transform*left_grip)<24:
			canvas.draw_arc(left_grip,9,0,TAU,28,canvas.PAPER,1.5,true)
		if canvas.model.can_push_handcar():
			canvas.draw_string(canvas.font,Vector2(-118,20),"Подтолкни край платформы ↔",HORIZONTAL_ALIGNMENT_LEFT,320,16,canvas.PAPER)
		if canvas.drag=="pump":
			var pose=canvas.model.handcar.pose()
			var target=(pose.rocker+Vector2(cos(canvas.model.hand_drive.target_angle),sin(canvas.model.hand_drive.target_angle))*float(canvas.model.handcar.config.grip_radius)*canvas.pump_grip_side)*canvas.ArtV3.PX
			var grip=pose.rocker+(pose.grip_right-pose.rocker)*canvas.pump_grip_side
			canvas.draw_line(grip*canvas.ArtV3.PX,target,Color("c5a76b"),1.0,true)
			canvas.draw_arc(target,7,0,TAU,24,Color("e1c989"),1.2,true)
	for id in ids:
		var geo = lever_geometry(id)
		var color = {"pump": Color("a16b38"), "brake": canvas.RED, "throttle": canvas.GREEN, "gear": canvas.GOLD, "start": Color("708574")}[id]
		var factor = geo.pivot.distance_to(geo.grip)/float({"pump":116,"brake":166,"throttle":165,"gear":166,"start":138}[id])
		var angle = float(geo.angle)
		var kind = canvas.control_kind(id) if id != "pump" else "pump"
		if kind == "gate":
			if canvas.model.auto_gearbox(): canvas.draw_selector(canvas.gate_rect(false), canvas.gate_pos if canvas.drag == "gear" else canvas.gate_slot_pos(int(canvas.model.state.gear)), canvas.drag == id)
			else: canvas.draw_gate(canvas.gate_rect(false), canvas.gate_pos if canvas.drag == "gear" else canvas.gate_slot_pos(int(canvas.model.state.gear)), canvas.drag == id)
		elif kind == "key":
			canvas.draw_ignition(geo, body_transform, false)
			continue
		elif kind == "matchbox":
			# 1.4.14: the box of matches (P31) where the toggle «Розжиг» was, with the count beside it
			var span = maxf(18.0, geo.pivot.distance_to(geo.grip)) * 1.5
			var tex: Texture2D = canvas.match_view().BOX_CLOSED
			var box = Rect2(geo.pivot - Vector2(span * 0.5, span * 0.5 * float(tex.get_height()) / float(tex.get_width()) + span * 0.2), Vector2(span, span * float(tex.get_height()) / float(tex.get_width())))
			canvas.draw_set_transform_matrix(body_transform)
			canvas.draw_texture_rect(tex, box, false)
			canvas.draw_string(canvas.font, box.position + Vector2(0, box.size.y + 13.0), "×%d" % canvas.model.matches().count(), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 12, canvas.PAPER)
			continue
		elif kind == "wheel":
			canvas.draw_handwheel(geo.pivot, float(geo.radius), angle, canvas.GOLD if id == "gear" else canvas.GREEN, canvas.drag == id)
		elif kind == "slider":
			canvas.draw_slider(body_transform, geo.pivot, float(geo.length), float(canvas.model.state.get(id, 0)), Color("c23b2e") if id == "brake" else Color("4f9a5f"), canvas.drag == id)
			if id == "brake": draw_brake_safe_mark(geo, true)
		elif id in ["brake","throttle"]:
			canvas.draw_arc(geo.pivot,geo.pivot.distance_to(geo.grip),-PI/2-0.55,-PI/2+0.55,24,Color("918363"),1.0,true)
			if id == "brake": draw_brake_safe_mark(geo, false)
			canvas.draw_lever(body_transform,geo.pivot,geo.pivot.distance_to(geo.grip),angle,Color("c23b2e") if id=="brake" else Color("4f9a5f"),canvas.drag==id)
		else:
			if id not in ["pump","start"]:
				canvas.draw_arc(geo.pivot,geo.pivot.distance_to(geo.grip),-PI/2-0.55,-PI/2+0.55,24,Color("918363"),1.0,true)
			if id == "start": angle = 0.0 if (canvas.model.heating_on() if canvas.model.vehicle_id() == "pneumatic" else canvas.model.state.engine) else PI
			var pivot = Vector2(128, 128 if id == "pump" else 224)
			# The base stays fixed; only the independent supplied SVG part rotates.
			if id != "pump": canvas.sprite("control_mount", Rect2(geo.pivot - Vector2(0.065,0.065)*canvas.ArtV3.PX, Vector2.ONE*0.13*canvas.ArtV3.PX))
			canvas.draw_set_transform_matrix(body_transform * Transform2D(angle, geo.pivot))
			if id != "pump":
				canvas.sprite("control_" + id, Rect2(-pivot * factor, Vector2.ONE * 256 * factor))
			canvas.draw_set_transform_matrix(body_transform)
		var highlighted = canvas.drag==id or hover.distance_to(body_transform*geo.grip)<24
		if not highlighted or not show_labels: continue
		canvas.draw_arc(geo.grip, 9, 0, TAU, 28, canvas.PAPER, 1.5, true)
		if kind == "lever" and id in ["brake","throttle"]:
			for endpoint in range(2):
				var mark=geo.pivot+Vector2(0,-geo.pivot.distance_to(geo.grip)).rotated(lerpf(-0.55,0.55,float(endpoint)))
				canvas.draw_string(canvas.font,mark+Vector2(-8,-12),["0","100"][endpoint],HORIZONTAL_ALIGNMENT_LEFT,30,12,canvas.PAPER)
		var label = {"pump": "КАЧАЙ ↕", "brake": "%d%%" % (float(canvas.model.state.brake) * 100), "throttle": "%d%%" % (float(canvas.model.state.throttle) * 100), "gear": ("%d%%" % (float(canvas.model.boiler().feed) * 100)) if canvas.model.vehicle_id() == "steam" else canvas.GEAR_LABELS[int(canvas.model.state.gear)], "start": "ВКЛ" if canvas.model.state.engine else "ПУСК"}[id]
		canvas.draw_string(canvas.font, geo.grip + Vector2(-25, -25), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, canvas.PAPER)

# 1.4.1: the green mark on the brake: the strongest braking that does not lock the wheels (Model.brake_safe, it moves by
# itself with the load, the rain and the wear); past it the way of the lever is red. Without a skid risk there is no mark.
func draw_brake_safe_mark(geo: Dictionary, slider: bool) -> void:
	var safe = canvas.model.brake_safe()
	if safe >= 0.999: return
	var safe_green = Color("5cc17f")
	var danger = Color(0.86, 0.25, 0.18, 0.75)
	if slider:
		var length = float(geo.length)
		var at = geo.pivot + Vector2(0, -length * safe)
		canvas.draw_line(at, geo.pivot + Vector2(0, -length), danger, 3.0, true)
		canvas.draw_line(at + Vector2(-9, 0), at + Vector2(9, 0), safe_green, 3.0, true)
		return
	var radius = geo.pivot.distance_to(geo.grip)
	var angle = lerpf(-0.55, 0.55, safe)
	canvas.draw_arc(geo.pivot, radius, -PI / 2 + angle, -PI / 2 + 0.55, 16, danger, 2.5, true)
	var dir = Vector2(0, -1).rotated(angle)
	canvas.draw_line(geo.pivot + dir * (radius - 7.0), geo.pivot + dir * (radius + 7.0), safe_green, 3.0, true)

func add_world_hits(id: String, index: int, transform: Transform2D) -> void:
	if index == 0:
		var ids = canvas.world_control_ids()
		for control_id in ids:
			var control_geo = lever_geometry(control_id)
			canvas.grip_hits.append({"id": control_id, "position": transform * control_geo.grip, "radius": float(control_geo.get("side", 0.0)) * 0.5 * transform.get_scale().x})
		if id=="handcar":
			canvas.grip_hits.append({"id":"pump","side":-1.0,"position":transform*(canvas.model.handcar.pose().grip_left*canvas.ArtV3.PX)})
		if id=="sail":
			var geo = canvas.art.sail_geometry(canvas.model)
			var a = transform * canvas.art.sail_point(float(geo.mast_x) + 0.2 * float(geo.fwd), 1.0)
			var b = transform * canvas.art.sail_point(float(geo.mast_x) - 1.8 * float(geo.fwd), 3.8)
			canvas.sail_rect = Rect2(a, Vector2.ZERO).expand(b).grow(10.0)
			canvas.sail_cleat_point = transform * canvas.art.sail_point(-0.14 * float(geo.fwd), 0.66)
		if id=="pneumatic":
			for i in range(canvas.ArtV3.FROST_SPOTS.size()):
				canvas.ice_hits.append({"spot": i, "position": transform * canvas.art.steam_point(canvas.ArtV3.FROST_SPOTS[i].x, canvas.ArtV3.FROST_SPOTS[i].y)})
				canvas.valve_hits.append({"spot": i, "position": transform * (canvas.art.steam_point(canvas.ArtV3.FROST_SPOTS[i].x, canvas.ArtV3.FROST_SPOTS[i].y) + Vector2(0, canvas.ArtV3.VALVE_DROP * canvas.ArtV3.PX))})
	var boxes = canvas.cargo_layout(id)
	for i in range(boxes.size()):
		var key = id + ":" + str(i)
		var rect = (transform * boxes[i]).grow(5)
		canvas.slot_hits.append({"key": key, "rect": rect})
		var item = canvas.find_slot_cargo(key)
		if not item.is_empty(): canvas.cargo_hits.append({"id": item.id, "rect": canvas.cargo_visuals.get(item.id, rect)})

# Short battery strip on the locomotive body (TZ 3.1, N6): readable at any
# zoom, colour only, exact numbers on hover.
func draw_charge_strip(body_transform: Transform2D) -> void:
	var fraction=charge_fraction()
	canvas.draw_set_transform_matrix(body_transform)
	var anchor = Vector2(0.70 * canvas.ArtV3.PX, canvas.art.deck_y("locomotive") - 0.37 * canvas.ArtV3.PX)
	if not canvas.art.is_skinned("locomotive"):
		anchor = canvas.art.stock_body_point("locomotive", Vector2(803, 586))
	var rect = Rect2(anchor - Vector2(20, 3), Vector2(40, 6))
	canvas.draw_style_box(canvas.style(Color("242b24"), Color("897658"), 2), rect.grow(3))
	if fraction > 0: canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * fraction, rect.size.y)), charge_color(fraction))
	canvas.charge_strip_rect = (body_transform * rect).grow(10)

func charge_fraction() -> float:
	return clampf(float(canvas.model.state.fleet_by_id.locomotive.fuel)/maxf(0.000001,float(canvas.model.object_stats("locomotive").tank)),0,1)

func charge_color(fraction: float) -> Color:
	var green=Color("7fab85")
	var amber=Color("e2a33c")
	var red=Color("d9533c")
	if fraction>=0.5: return green
	if fraction>=0.25: return green.lerp(amber,(0.5-fraction)/0.25)
	if fraction>=0.15: return amber
	return red

# Warn once per threshold crossed downward; regeneration must lift the charge
# 2% above a threshold before it re-arms, so braking does not cause flicker.
func update_charge_warning() -> void:
	if canvas.model.vehicle_id()!="locomotive":
		canvas.charge_band=0
		return
	var fraction=charge_fraction()
	var thresholds=[0.5,0.25,0.15]
	var band=0
	for i in range(thresholds.size()):
		if fraction<thresholds[i]: band=i+1
	if band>canvas.charge_band:
		canvas.notify(["Заряд ниже 50%: тяга слабеет","Заряд 25%: тяги мало для подъёмов","Заряд 15%: тяга почти исчерпана. Зарядка в депо"][band-1])
		canvas.charge_band=band
	elif band<canvas.charge_band and fraction>thresholds[canvas.charge_band-1]+0.02:
		canvas.charge_band=band
