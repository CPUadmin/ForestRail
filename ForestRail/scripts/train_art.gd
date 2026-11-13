extends RefCounted
# Помощник main.gd: рисование поезда, припаркованных вагонов, кузовов и погрузки.
# Работает через canvas (main.gd), как cab_art.gd и control_art.gd.

var canvas = null   # main.gd: it holds the model, the settings and the shared state

func _init(owner_canvas) -> void:
	canvas = owner_canvas

func draw_train() -> void:
	var ids = canvas.model.body_ids()
	var scale_value = canvas.view_scale()
	if canvas.screen == "depot": draw_parked_wagons()
	# Draw every connector from the same transformed mount used by its body.
	for i in range(1,ids.size()):
		if canvas.screen == "depot" and not canvas.coupling_anim.is_empty() and canvas.coupling_anim.attach and ids[i] == canvas.coupling_anim.id: continue
		var front_s = canvas.model.body_s_render(i-1) if canvas.screen!="depot" else -canvas.model.body_offset(i-1)
		var rear_s = canvas.model.body_s_render(i) if canvas.screen!="depot" else -canvas.model.body_offset(i)
		var a = body_transform(ids[i],rear_s)*canvas.Geometry.coupling(ids[i],1)
		var b = body_transform(ids[i-1],front_s)*canvas.Geometry.coupling(ids[i-1],-1)
		draw_coupler(a,b)
	var bounds_by_id = {}
	for i in range(ids.size() - 1, -1, -1):
		if canvas.screen == "depot" and not canvas.coupling_anim.is_empty() and canvas.coupling_anim.attach and ids[i] == canvas.coupling_anim.id: continue
		var s = canvas.model.body_s_render(i) if canvas.screen != "depot" else -canvas.model.body_offset(i)
		var p = canvas.world_point(s)
		var transform = body_transform(ids[i],s)
		canvas.draw_set_transform_matrix(transform)
		draw_body(ids[i], s, canvas.screen == "game")
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
		var local_bounds = canvas.art.body_bounds(ids[i])
		var world_bounds = Rect2(transform*local_bounds.position,Vector2.ZERO)
		for corner in [local_bounds.end,Vector2(local_bounds.end.x,local_bounds.position.y),Vector2(local_bounds.position.x,local_bounds.end.y)]: world_bounds=world_bounds.expand(transform*corner)
		canvas.body_hits.append({"id":ids[i],"rect":world_bounds.grow(6)})
		bounds_by_id[ids[i]] = world_bounds
		if canvas.screen == "depot" and canvas.tab == "Улучшения" and canvas.selected_object == ids[i] and canvas.model.state.active.is_empty(): canvas.draw_workshop_spots(ids[i], transform)
		if canvas.screen == "depot" and canvas.selected_object == ids[i]:
			canvas.draw_line(p + Vector2(-canvas.art.body_width(ids[i])*0.46,14)*scale_value,p+Vector2(canvas.art.body_width(ids[i])*0.46,14)*scale_value,canvas.GOLD,3,true)
		if canvas.screen == "game":
			canvas.add_world_hits(ids[i], i, transform)
	if canvas.screen == "game":
		canvas.draw_land_dust()
		canvas.draw_glints()
		draw_wear_badges(ids, bounds_by_id)
	for pair in [[0,1],[ids.size()-1,-1]]:
		var id = ids[pair[0]]
		var s = canvas.model.body_s_render(pair[0]) if canvas.screen!="depot" else -canvas.model.body_offset(pair[0])
		var outer = body_transform(id,s)
		var mount = canvas.Geometry.coupling(id,pair[1])
		draw_coupler(outer*mount,outer*(mount+Vector2(pair[1]*float(canvas.Geometry.data().coupler.end_extension_m)*canvas.ArtV3.PX,0)))

# 1.4.1: up to three badges over the worst worn parts of the train (the pictures of the parts are pack P19 of GPT).
# Amber ring below 40% (the lamp «АВАРИЯ» is on), red and blinking below 20% (the part may stop on the way).
const WEAR_BADGES_MAX = 3
var wear_icon_cache = {}

func wear_icon(node: String) -> Texture2D:
	if not wear_icon_cache.has(node):
		var path = "res://assets/art_wear/node_%s.png" % node
		wear_icon_cache[node] = load(path) if ResourceLoader.exists(path) else null
	return wear_icon_cache[node]

func worn_parts(ids: Array) -> Array:
	var wear = canvas.model.wear()
	var found: Array = []
	for id in ids:
		for def in wear.nodes_of(id):
			var value = wear.condition(id, str(def.id))
			if value < wear.WARN_BELOW: found.append([value, id, str(def.id)])
	found.sort_custom(func(a, b): return a[0] < b[0])
	return found.slice(0, WEAR_BADGES_MAX)

func draw_wear_badges(ids: Array, bounds_by_id: Dictionary) -> void:
	var parts = worn_parts(ids)
	if parts.is_empty(): return
	var by_id = {}
	for part in parts:
		if not by_id.has(part[1]): by_id[part[1]] = []
		by_id[part[1]].append(part)
	var radius = clampf(0.3 * canvas.ArtV3.PX * canvas.view_scale(), 16.0, 26.0)
	var blink = 1.0 if canvas.settings.reduce_motion else 0.75 + 0.25 * sin(canvas.time * TAU * 2.0)
	var top_limit = 66.0 + radius   # under the top bar of the road screen
	for id in by_id:
		if not bounds_by_id.has(id): continue
		var box: Rect2 = bounds_by_id[id]
		var row: Array = by_id[id]
		var step = radius * 2.4
		var left = box.get_center().x - step * (row.size() - 1) * 0.5
		for k in range(row.size()):
			var value = float(row[k][0])
			var red = value < canvas.model.wear().BREAKDOWN_BELOW
			var ring = Color("d63b26") if red else canvas.UiKit.WARN
			var center = Vector2(left + step * k, maxf(top_limit, box.position.y - radius - 8.0))
			# the dark metal pictures read on the cream of the paper; the ring tells how bad it is
			canvas.draw_circle(center, radius + 4.0, Color(ring, blink if red else 1.0))
			canvas.draw_circle(center, radius, Color(canvas.UiKit.PAPER, 0.96))
			var icon = wear_icon(str(row[k][2]))
			if icon != null:
				var side = radius * 1.55
				var aspect = float(icon.get_width()) / float(icon.get_height())
				var size = Vector2(side * minf(1.0, aspect), side / maxf(1.0, aspect))
				canvas.draw_texture_rect(icon, Rect2(center - size * 0.5, size), false)

# Wagons the player owns but has not coupled stand behind the train.
func parked_wagons() -> Array:
	var result: Array = []
	for id in canvas.parked_order + canvas.Model.WAGON_IDS:
		if canvas.model.state.wagons_by_id.has(id) and id not in canvas.model.state.consist_ids and id not in result: result.append(id)
	if not canvas.coupling_anim.is_empty() and canvas.coupling_anim.attach and canvas.coupling_anim.id not in result: result.push_front(canvas.coupling_anim.id)
	return result

func train_tail_s() -> float:
	var ids = canvas.model.body_ids()
	var last = ids.size()-1
	if not canvas.coupling_anim.is_empty() and canvas.coupling_anim.attach: last -= 1
	return -canvas.model.body_offset(last) - canvas.Geometry.length(ids[last])*0.5

func parked_s(index: int) -> float:
	var length = canvas.Geometry.length("W01")
	return train_tail_s() - canvas.PARK_GAP_M - length*0.5 - index*(length + canvas.PARK_GAP_M)

func depot_span_m() -> float:
	var parked = 0
	for id in canvas.Model.WAGON_IDS:
		if canvas.model.state.wagons_by_id.has(id) and id not in canvas.model.state.consist_ids: parked += 1
	return canvas.model.train_length() + parked*(canvas.Geometry.length("W01") + canvas.PARK_GAP_M)

func draw_parked_wagons() -> void:
	canvas.coupler_hits.clear()
	var parked = parked_wagons()
	for k in range(parked.size()):
		var id = parked[k]
		var s = parked_s(k)
		if not canvas.coupling_anim.is_empty() and canvas.coupling_anim.id == id:
			s = lerpf(canvas.coupling_anim.from, canvas.coupling_anim.to, ease(clampf(canvas.coupling_anim.t, 0, 1), -2.0))
		var transform = body_transform(id, s)
		canvas.draw_set_transform_matrix(transform)
		draw_body(id, s, false)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	if not canvas.coupling_anim.is_empty() or not canvas.model.depot_editable(): return
	var ids = canvas.model.body_ids()
	# Only the tail wagon can go and only the nearest parked one can come,
	# as on a real siding.
	if ids.size() > 1:
		var tail = ids[-1]
		var tail_transform = body_transform(tail, -canvas.model.body_offset(ids.size()-1))
		var ahead_transform = body_transform(ids[-2], -canvas.model.body_offset(ids.size()-2))
		var joint = (tail_transform*canvas.Geometry.coupling(tail,1) + ahead_transform*canvas.Geometry.coupling(ids[-2],-1))*0.5
		canvas.coupler_hits.append({"id": tail, "attach": false, "position": joint})
	if not parked.is_empty() and canvas.model.state.consist_ids.size() < canvas.model.max_wagons(canvas.model.vehicle_id()):
		var tail_point = body_transform(ids[-1], -canvas.model.body_offset(ids.size()-1))*canvas.Geometry.coupling(ids[-1],-1)
		var first_point = body_transform(parked[0], parked_s(0))*canvas.Geometry.coupling(parked[0],1)
		canvas.coupler_hits.append({"id": parked[0], "attach": true, "position": (tail_point+first_point)*0.5})
	var mouse = canvas.get_global_mouse_position()
	for hit in canvas.coupler_hits:
		var hover = hit.position.distance_to(mouse) < 22
		canvas.draw_circle(hit.position, 15, Color(canvas.INK, 0.9))
		canvas.draw_arc(hit.position, 15, 0, TAU, 28, Color("e2c27a") if hover else canvas.GOLD, 2.5, true)
		# Two links: closed when coupled (offer to open), apart when not.
		var gap = 3.0 if hit.attach else 0.0
		canvas.draw_arc(hit.position + Vector2(-4 - gap, 0), 5, 0, TAU, 16, canvas.PAPER, 2, true)
		canvas.draw_arc(hit.position + Vector2(4 + gap, 0), 5, 0, TAU, 16, canvas.PAPER, 2, true)
		if hover:
			var text = ("Прицепить " if hit.attach else "Отцепить ") + str(hit.id)
			var width = canvas.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22
			var box = Rect2(hit.position + Vector2(-width*0.5, -50), Vector2(width, 26))
			canvas.draw_style_box(canvas.style(Color(canvas.INK, 0.92), canvas.GOLD, 10), box)
			canvas.draw_string(canvas.font, box.position + Vector2(0, 18), text, HORIZONTAL_ALIGNMENT_CENTER, width, 15, canvas.PAPER)
	if not canvas.latch_flash.is_empty():
		var age = float(canvas.latch_flash.t)
		canvas.draw_arc(canvas.latch_flash.position, 10 + age*30, 0, TAU, 24, Color(1, 0.9, 0.6, 1.0 - age), 3, true)

func body_transform(id: String, s: float, swaying: bool = true) -> Transform2D:
	var direction = int(canvas.model.state.direction) if canvas.screen!="depot" else 1
	var wheels = canvas.art.wheel_positions(id)
	var a = canvas.world_point(s+direction*wheels[0].x/canvas.ArtV3.PX)
	var b = canvas.world_point(s+direction*wheels[1].x/canvas.ArtV3.PX)
	var x = (b-a).normalized()
	var y = -x.orthogonal()*direction
	var mean_x = (wheels[0].x+wheels[1].x)*0.5
	var sc = canvas.view_scale()
	var lift = Vector2(0, float(canvas.model.air_z) * canvas.ArtV3.PX * sc) if canvas.screen != "depot" else Vector2.ZERO
	var result = Transform2D(x*sc,y*sc,(a+b)*0.5-x*mean_x*sc-lift)
	if canvas.screen == "game" and canvas.Model.live_effects and swaying:
		# B5.1: the body rides on its springs: it bobs on the joints and the crests and rocks when the train
		# speeds up or brakes (the nose comes up and dips). It turns about the middle of the wheelbase.
		var index = canvas.model.body_ids().find(id)
		var bob = canvas.model.live.lift_m(index)
		var pitch_air = clampf(float(canvas.model.air_vy) * 0.035, -0.2, 0.2) if canvas.model.air_fly else 0.0   # B5.5: the nose follows the flight
		var turn = -(canvas.model.live.rock_rad(index) + pitch_air) * float(direction)
		if absf(bob) > 0.0001 or absf(turn) > 0.00005:
			var centre = (a+b)*0.5
			var origin = (result.origin - centre).rotated(turn) + centre - Vector2(0, bob * canvas.ArtV3.PX * sc)
			result = Transform2D(result.x.rotated(turn), result.y.rotated(turn), origin)
	return result

func draw_coupler(a: Vector2, b: Vector2) -> void:
	var tex = canvas.art.textures["vehicles/coupler"]
	var span = a.distance_to(b)
	var height = maxf(5.0 * canvas.view_scale(), span * float(tex.get_height()) / float(tex.get_width()))
	canvas.draw_set_transform((a+b)*0.5,(b-a).angle())
	canvas.draw_line(Vector2(-span * 0.5, 0), Vector2(span * 0.5, 0), Color("3d3427"), height * 0.72, true)
	canvas.draw_texture_rect(tex,Rect2(-span*0.5,-height*0.5,span,height),false)
	for end in [-1, 1]:
		var mount = Vector2(end * (span * 0.5 - minf(2.0, span * 0.25)), 0)
		canvas.draw_circle(mount, height * 0.44, Color("5a503c"))
		canvas.draw_circle(mount, height * 0.23, Color("ba9e67"))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_body(id: String, s: float, controls: bool) -> void:
	var outer = body_transform(id, s)
	var rail = body_transform(id, s, false)   # the running gear stands on the rail while the body sways above it
	var air_height = float(canvas.model.air_z) if canvas.screen == "game" else 0.0
	canvas.ellipse(Vector2(10, 7 + air_height * canvas.ArtV3.PX), Vector2(canvas.art.body_width(id)*0.48/(1.0 + air_height * 0.8), 7.0/(1.0 + air_height * 0.8)), Color(0.05, 0.08, 0.05, 0.23/(1.0 + air_height * 1.5)))
	# the skid: the locked wheels of the machine stand still and sparks fly from under them
	var wheel_s = s
	var skidding = canvas.screen == "game" and canvas.model.wheel_lock and id == canvas.model.vehicle_id() and canvas.model.body_ids().find(id) == 0
	if skidding:
		if not canvas.skid_active:
			canvas.skid_active = true
			canvas.skid_s = s
		wheel_s = canvas.skid_s
	else:
		canvas.skid_active = false
	canvas.art.draw_vehicle(canvas, id, wheel_s, int(canvas.model.state.direction) if canvas.screen != "depot" else 1, outer, canvas.model, controls, {}, false, rail)
	if skidding:
		canvas.art.draw_skid_sparks(canvas, id, rail, outer, canvas.time)
	if not id.begins_with("W"): canvas.art.draw_added_headlamp(canvas, id)
	if id == "locomotive" and canvas.screen == "game":
		canvas.draw_charge_strip(outer)
		if canvas.electric_start_flash > 0.0 and canvas.light_flicker_enabled():
			var axle: Vector2 = canvas.art.wheel_positions(id)[1]
			var contact = Vector2(axle.x, 0)
			var strength = canvas.electric_start_flash / canvas.ELECTRIC_START_FLASH
			canvas.draw_circle(contact, 7.0, Color(0.44, 0.76, 1.0, strength * 0.26))
			for ray in range(5):
				var tip = contact + Vector2(-10.0 + ray * 5.0, -5.0 - (ray % 3) * 3.5)
				canvas.draw_line(contact, tip, Color(0.80, 0.94, 1.0, strength), 1.6, true)
	var boxes = cargo_layout(id)
	for index in range(boxes.size()):
		var box: Rect2 = boxes[index]
		var key = id + ":" + str(index)
		var item = find_slot_cargo(key)
		var on_screen = outer * box
		if item.is_empty():
			var hover = on_screen.grow(8).has_point(canvas.get_global_mouse_position())
			if controls and (canvas.screen == "depot" or canvas.model.state.phase == "loading" or canvas.drag == "cargo" or hover):
				canvas.draw_style_box(canvas.style(Color(0.9, 0.87, 0.65, 0.35), Color("d1bd71"), 5), box.grow(3))
			continue
		canvas.cargo_visuals[item.id] = on_screen.grow(4)
		if item.id == canvas.drag_item: continue
		var foot = Vector2(box.get_center().x, box.end.y)
		canvas.ellipse(foot, Vector2(box.size.x * 0.47, 3), Color(0.07, 0.05, 0.03, 0.38))
		canvas.grounded_sprite(str(canvas.model.cargo_base(item.type).sprite), foot, box.size.y)
		for side in [-1, 1]:
			var strap = foot + Vector2(box.size.x * 0.28 * side, 0)
			var anchor = strap + Vector2(side * 2, 4)
			canvas.draw_line(strap - Vector2(0, box.size.y * 0.82), anchor, Color("4a3c29"), 2.5, true)
			canvas.draw_line(strap - Vector2(0, box.size.y * 0.82), anchor, Color("a48a57"), 1.0, true)
			canvas.draw_circle(anchor, 2.3, Color("6e593d"))
	if id == "pole": canvas.art.draw_pole_overlay(canvas, canvas.model, outer)
	if id == "sail": canvas.art.draw_sail_overlay(canvas, canvas.model)
	if id.begins_with("W"): canvas.art.draw_wagon_front(canvas, id, outer)
	if id.begins_with("W") and canvas.screen == "depot":
		canvas.draw_string(canvas.font, Vector2(-25, canvas.art.deck_y(id) + 34), id, HORIZONTAL_ALIGNMENT_CENTER, 50, 15, canvas.PAPER)
	if id == canvas.model.vehicle_id() and controls: canvas.draw_controls(outer)

func wheel_rotation(distance: float, facing: int) -> float:
	# Positive rotation is clockwise in Godot. Mirrored bodies invert the local angle.
	return distance * 64.0 / 28.0 * facing

func find_slot_cargo(key: String) -> Dictionary:
	for item in canvas.model.state.cargo:
		if item.slot == key and not item.delivered: return item
	return {}

# Pack occupied and empty slots in one row so every load has a deck contact.
# When an upgraded deck is crowded, fit the whole row without changing slot IDs.
func cargo_layout(id: String) -> Array[Rect2]:
	var count = int(canvas.model.object_stats(id).slots)
	var sizes: Array[Vector2] = []
	var total_width = 0.0
	for index in range(count):
		var item = find_slot_cargo(id + ":" + str(index))
		var sprite_id = "sack" if item.is_empty() else str(canvas.model.cargo_base(item.type).sprite)
		var bounds = canvas.visual_layout[sprite_id]
		var ratio = float(bounds[2] - bounds[0]) / maxf(1.0, float(bounds[3] - bounds[1]))
		var size = canvas.art.cargo_size(sprite_id, ratio)
		if item.is_empty(): size.x = maxf(size.x, 0.38 * canvas.ArtV3.PX)
		sizes.append(size)
		total_width += size.x
	var boxes: Array[Rect2] = []
	if count == 0: return boxes
	var gap = 0.10 * canvas.ArtV3.PX
	var space = canvas.art.body_width(id) - 0.16 * canvas.ArtV3.PX - gap * (count - 1)
	var fit = minf(1.0, space / total_width)
	var x = -(total_width * fit + gap * (count - 1)) * 0.5
	var deck = canvas.art.deck_y(id)
	for index in range(count):
		var size = sizes[index] * fit
		var item = find_slot_cargo(id + ":" + str(index))
		var slide = 0.0
		if not item.is_empty() and canvas.screen == "game" and canvas.Model.live_effects:
			slide = clampf(canvas.model.live.cargo_p(item.id) * canvas.ArtV3.PX * float(canvas.model.state.direction), -gap * 0.4, gap * 0.4)
		boxes.append(Rect2(Vector2(x + slide, deck - size.y), size))
		x += size.x + gap
	return boxes

func draw_loading_dock(size: Vector2) -> void:
	var interaction=canvas.station_state()
	var station_index = int(interaction.station_index)
	var rect = canvas.dock_rect()
	var accepting=canvas.drag=="cargo" and interaction.can_transfer and (canvas.drag_item in interaction.eligible or station_index==0)
	canvas.draw_style_box(canvas.style(Color(0.14, 0.21, 0.17, 0.95), canvas.GOLD if accepting else Color("82916c"), 12), rect)
	var title = ("ПОГРУЗКА · " if canvas.model.state.phase=="loading" else "РАЗГРУЗКА · ")+interaction.station_name
	if canvas.model.state.phase=="loading" and canvas.model.selectable_loading():
		var plan=canvas.model.loading_preview()
		title+=" · На складе %d · Везём %d из %d" % [canvas.model.state.cargo.size()-int(plan.loaded),plan.loaded,plan.offered]
	canvas.draw_string(canvas.font, rect.position + Vector2(20, 28), title, HORIZONTAL_ALIGNMENT_LEFT, 600, 18, canvas.PAPER)
	if accepting:
		canvas.draw_string(canvas.font, rect.position + Vector2(590, 28), "✓ ОТПУСТИ ЗДЕСЬ · "+interaction.station_name, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 615, 18, canvas.GOLD)
	var index = 0
	for item in canvas.model.state.cargo:
		if item.delivered or item.slot != "": continue
		if station_index != 0: continue
		var p = rect.position + Vector2(42 + index * 128, 58)
		if item.id != canvas.drag_item:
			canvas.sprite(canvas.model.cargo_base(item.type).sprite, Rect2(p, Vector2(60, 65)))
		canvas.cargo_hits.append({"id": item.id, "rect": Rect2(p - Vector2(8, 4), Vector2(96, 82))})
		canvas.draw_string(canvas.font, p + Vector2(65, 44), item.destination, HORIZONTAL_ALIGNMENT_LEFT, 45, 19, canvas.GOLD)
		index += 1
	if index == 0:
		var text=interaction.reason
		if canvas.model.state.phase=="loading" and canvas.model.all_loaded(): text="Груз закреплён. Можно ехать: просто дай ход."
		if canvas.selected_cargo!="" and canvas.selected_cargo not in interaction.eligible and station_index!=0:
			for cargo in canvas.model.state.cargo:
				if cargo.id==canvas.selected_cargo and not cargo.delivered: text="Этот груз ждут в «%s»" % canvas.model.station_name(cargo.destination)
		canvas.draw_string(canvas.font, rect.position + Vector2(25, 67), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 50, 19, canvas.PAPER)
		if canvas.selected_cargo=="": canvas.draw_string(canvas.font,rect.position+Vector2(25,115),"Перетащи предмет или выбери его кликом для выгрузки кнопкой",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-50,17,Color("b9c7b2"))

func draw_cargo_feedback() -> void:
	var interaction=canvas.station_state()
	if interaction.visible:
		var marker=canvas.world_point(interaction.stop_s)
		var sc=canvas.view_scale()
		canvas.draw_colored_polygon(PackedVector2Array([marker+Vector2(-8,17)*sc,marker+Vector2(8,17)*sc,marker+Vector2(0,5)*sc]),canvas.GOLD)
		for hit in canvas.cargo_hits:
			if hit.id==canvas.drag_item: continue
			var selected=hit.id==canvas.selected_cargo
			if hit.id in interaction.eligible or selected:
				canvas.draw_rect(hit.rect,canvas.GOLD if selected else Color("8db78a"),false,3 if selected else 1.5)
	if canvas.drag=="cargo":
		if interaction.can_transfer and (canvas.drag_item in interaction.eligible or interaction.station_id=="A"):
			canvas.draw_rect(canvas.world_platform_rect(),Color("e9ce83"),false,3)
		var r=Rect2(canvas.drag_cursor-canvas.drag_offset,canvas.drag_size)
		for cargo in canvas.model.state.cargo:
			if cargo.id==canvas.drag_item:
				canvas.grounded_sprite(canvas.model.cargo_base(cargo.type).sprite,r.position+Vector2(r.size.x*0.5,r.size.y),r.size.y)
				canvas.draw_rect(r,canvas.GOLD,false,2)
	if not canvas.delivery_ghost.is_empty():
		var alpha=1-clampf(float(canvas.delivery_ghost.time)/0.45,0,1)
		var point=Vector2(canvas.delivery_ghost.from).lerp(canvas.delivery_ghost.to,smoothstep(0,0.3,float(canvas.delivery_ghost.time)))
		canvas.grounded_sprite(canvas.delivery_ghost.sprite,point,44,Color(1,1,1,alpha))
