extends Node
const Fixtures = preload("res://tests/fixtures.gd")

const Geometry = preload("res://scripts/world_geometry.gd")
var game
var checks = 0
var failures: Array = []
var measurements: Dictionary = {}
var out_dir = ProjectSettings.globalize_path("res://../qa/v3_p2")
var max_contact_error = 0.0
var max_coupling_error = 0.0

class ScaleSheet extends Node2D:
	var game
	func _draw() -> void:
		var font = ThemeDB.fallback_font
		draw_rect(Rect2(0,0,1600,1000),Color("263b38"))
		draw_string(font,Vector2(36,40),"ЛЕСНАЯ КОЛЕЯ · P2 · ОБЩИЙ МАСШТАБ",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("f5ecd6"))
		draw_string(font,Vector2(36,72),"Сетка 0,5 м · человек 1,75 м · дверь 2,05 м · все изображения масштабируются равномерно",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("c7c3a0"))
		for lane in [330,840]:
			for y in range(0,8):
				draw_line(Vector2(25,lane-y*33.6),Vector2(1575,lane-y*33.6),Color(0.6,0.7,0.6,0.18),1)
			draw_line(Vector2(25,lane),Vector2(1575,lane),Color("adac84"),2)
		var ids = ["handcar","motorcar","locomotive","W01"]
		for i in range(ids.size()):
			var id = ids[i]
			var p = Vector2(250+i*355,330)
			var outer = Transform2D(0,Vector2.ONE*0.7,0,p)
			game.art.draw_vehicle(self,id,0,1,outer,game.model,false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			draw_string(font,p+Vector2(-100,28),"%s · %.2f м" % [id,Geometry.length(id)],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f5ecd6"))
		person(Vector2(60,330))
		for i in range(2):
			var id = "stations/station_house" if i==0 else "stations/depot"
			var p = Vector2(415+i*790,840)
			game.art.draw_part(self,id,p,0,game.art.scale_for(id)*0.7)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			draw_string(font,p+Vector2(-160,32),"Станция · дверь 2,05 м" if i==0 else "Депо · локомотив проходит в ворота",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f5ecd6"))
		person(Vector2(775,840))
		draw_string(font,Vector2(36,930),"Колёса: 0,42 / 0,55 м. Между кузовами: 0,30 м. Масштаб этого листа: 0,70 × 96 px/м.",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("f5ecd6"))
	func person(foot: Vector2) -> void:
		var scale = 96*0.7
		var color = Color("d5c093")
		draw_circle(foot+Vector2(0,-1.62)*scale,0.13*scale,color)
		draw_line(foot+Vector2(0,-1.48)*scale,foot+Vector2(0,-0.73)*scale,color,0.19*scale,true)
		for side in [-1,1]:
			draw_line(foot+Vector2(0,-0.8)*scale,foot+Vector2(0.20*side,0)*scale,color,0.10*scale,true)
			draw_line(foot+Vector2(0,-1.35)*scale,foot+Vector2(0.28*side,-0.85)*scale,color,0.09*scale,true)

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text); print("FAIL: ",text)

func _ready() -> void:
	call_deferred("run")

func frame() -> void:
	game.update_hud()
	game.art_world.update_view()
	game.queue_redraw()
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name+".png"))

func prepare(vehicle: String, chapter: int) -> void:
	game.control_zoom=false
	game.paused=false
	game.model.new_game(42)
	game.model.state.money = 10000
	if vehicle!="handcar": Fixtures.equip(game.model,vehicle)
	game.model.state.chapter = chapter
	check(game.model.accept_mission(game.model.current_mission()),"prepare mission "+str(chapter))
	var slots = game.model.slots()
	for i in range(game.model.state.cargo.size()): check(game.model.transfer(game.model.state.cargo[i].id,slots[i].key),"fixture load")
	game.screen = "game"
	game.model.state.phase = "route"
	game.rebuild()

func button(point: Vector2, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_tree().root.push_input(event,true)
	await frame()

func motion(point: Vector2, delta: Vector2) -> void:
	var event = InputEventMouseMotion.new()
	event.position=point
	event.relative=delta
	event.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(event,true)
	await frame()

func key(value: int) -> void:
	var event = InputEventKey.new()
	event.keycode=value;event.physical_keycode=value;event.pressed=true
	get_tree().root.push_input(event,true)
	await frame()

func arc_drag(id: String, value: float) -> void:
	var point=grip(id,true)
	var geo=game.control_geometry(id,true)
	var target=geo.pivot+Vector2(0,-geo.pivot.distance_to(geo.grip)).rotated(lerpf(-0.55,0.55,value))
	await button(point,true)
	await motion(target,target-point)
	await button(target,false)

func grip(id: String, closeup: bool = false) -> Vector2:
	for hit in game.grip_hits:
		if hit.id==id and bool(hit.get("closeup",false))==closeup: return hit.position
	return Vector2.ZERO

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://main.tscn").instantiate()
	game.test_mode = true
	game.saves.directory = out_dir.path_join("profile")
	game.settings_path = out_dir.path_join("settings.json")
	get_tree().root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	get_tree().root.size = Vector2i(1600,1000)
	prepare("handcar",0)
	for id in ["handcar","motorcar","locomotive","W01"]:
		var meta = game.art.assets[game.art.body_key(id)]
		var source = Geometry.body(id)
		var deck_height = -game.art.deck_y(id)/96
		var roof_height = (float(meta.pivot_px[1])-float(meta.region_px[1]))*game.art.scale_for(game.art.body_key(id))/96-game.art.axis_height(id)/96
		measurements[id] = {"length_m":Geometry.length(id),"deck_m":deck_height,"top_m":roof_height,"wheel_m":source.wheel_diameter_m,"axle_positions_px":game.art.wheel_positions(id)}
		check(absf(game.art.body_width(id)/96-Geometry.length(id))<0.00001,"body length from one scale "+id)
		if id!="locomotive": check(deck_height>=0.50 and deck_height<=0.70,"deck at human scale "+id)
		else: check(roof_height>=2.4 and roof_height<=2.7,"locomotive has human-height cab")
	for id in Geometry.data().buildings:
		var spec = Geometry.data().buildings[id]
		var meta = game.art.assets[id]
		var scale = game.art.scale_for(id)/96
		var height = float(meta.region_px[3])*scale
		measurements[id] = {"width_m":float(meta.region_px[2])*scale,"height_m":height}
		if spec.has("door_px"):
			var door = (float(spec.door_px[3])-float(spec.door_px[1]))*scale
			measurements[id].door_m = door
			check(absf(door-2.05)<0.001,"door common reference "+id)
		if id.ends_with("depot"):
			var gate = (661.0-250.0)*scale
			check(gate>float(measurements.locomotive.top_m)+0.10,"depot gate clears locomotive")
		if id.ends_with("station_house"): check(height>=3.2 and height<=3.5,"station height")
		if id.ends_with("depot"): check(height>=3.9 and height<=4.5,"depot height")
	prepare("motorcar",5)
	for control in ["brake","throttle","gear","start"]:
		var g = game.lever_geometry(control)
		check(absf(g.pivot.distance_to(g.grip)/96-float(Geometry.data().controls[control+"_length_m"]))<0.001,"physical handle length "+control)
	prepare("handcar",0)
	var sheet = ScaleSheet.new()
	sheet.game = game
	sheet.material = game.material
	get_tree().root.add_child(sheet)
	game.hide()
	await shot("scale_sheet")
	sheet.queue_free()
	game.show()
	var terrain = {"flat":0.0,"up":0.0,"crest":0.0,"down":0.0}
	var steep_up = 0.0
	var steep_down = 0.0
	var high = 0.0
	for s in range(25,275):
		var slope = game.model.route.slope(s)
		if slope>steep_up: terrain.up=float(s); steep_up=slope
		if slope<steep_down: terrain.down=float(s); steep_down=slope
		if game.model.route.sample(s).y>high: terrain.crest=float(s); high=game.model.route.sample(s).y
	for vehicle in ["handcar","motorcar","locomotive"]:
		prepare(vehicle,{"handcar":0,"motorcar":5,"locomotive":9}[vehicle])
		for name in terrain:
			for direction in [-1,1]:
				game.model.state.direction = direction
				game.model.state.s = terrain[name]
				game.camera_s = game.model.state.s
				game.camera_y = game.model.route.sample(game.camera_s).y
				game.camera_x = 1000 if direction>0 else 600
				for zoom in [0.75,1.0,1.5]:
					game.zoom_level = zoom
					var ids = game.model.body_ids()
					for i in range(ids.size()):
						var id = str(ids[i])
						var outer = game.body_transform(id,game.model.body_s(i))
						var radius = float(Geometry.body(id).wheel_diameter_m)*48
						for wheel in game.art.wheel_positions(id):
							var contact = outer*(wheel+Vector2(0,radius))
							var rail = game.world_point(game.model.body_s(i)+direction*wheel.x/96)
							check((outer*wheel).y<rail.y,"wheel centre above rail "+id)
							max_contact_error = maxf(max_contact_error,contact.distance_to(rail))
							check(contact.distance_to(rail)<1.0,"rail contact "+vehicle+" "+name)
						check(absf(outer.x.length()*game.art.body_width(id)/(zoom*96)-Geometry.length(id))<0.001,"scale ratio independent of zoom/direction")
						if i>0:
							var a = outer*Geometry.coupling(id,1)
							var b = game.body_transform(ids[i-1],game.model.body_s(i-1))*Geometry.coupling(ids[i-1],-1)
							var gap = a.distance_to(b)/(96*zoom)
							max_coupling_error = maxf(max_coupling_error,absf(gap-0.30)*96*zoom)
							check(gap>=0.20 and gap<=0.35,"coupler span on terrain")
							check(absf(game.model.body_s(i)-game.model.body_s(i-1))-(Geometry.length(id)+Geometry.length(ids[i-1]))*0.5>0.20,"body spacing")
					if vehicle=="motorcar" and direction==1 and zoom==1.0: await shot("terrain_"+name)
			game.model.state.direction = 1
		game.model.state.s = game.model.service_stop(1)
		game.camera_s = game.model.state.s
		game.camera_y = game.model.route.sample(game.camera_s).y
		game.camera_x = 900
		for zoom in [0.75,1.0,1.5]:
			game.zoom_level = zoom
			for tick in range(20): game.model.physics_step(1.0/60)
			await shot(vehicle+"_zoom_"+str(zoom))
			for item in game.model.state.cargo:
				var box = game.cargo_visuals[item.id]
				var sprite = game.model.cargo_base(item.type).sprite
				var size = game.art.cargo_size(sprite,box.size.x/box.size.y)
				check(box.size.x>20 and box.size.y>20,"visible load "+str(item.id))
				var expected = game.art.cargo_size(sprite,float(game.visual_layout[sprite][2])/float(game.visual_layout[sprite][3]))
				check((box.size-Vector2.ONE*8).distance_to(expected*zoom)<1,"cargo dimensions at zoom "+str(zoom))
			var controls = game.control_ids()
			for id in controls:
				var point = grip(id)
				await button(point,true)
				check(game.drag==id,"GUI captures scaled "+vehicle+" "+id+" at "+str(zoom))
				await button(point,false)
		check(game.model.train_length()<=18,"longest formation fits service platform")
	prepare("motorcar",5)
	game.zoom_level=0.75
	game.camera_s=game.model.state.s
	game.camera_y=game.model.route.sample(game.camera_s).y
	game.camera_x=900
	await frame()
	await key(KEY_C)
	check(game.control_zoom,"C opens closeup")
	await shot("control_closeup")
	for id in ["brake","throttle","gear","start"]:
		var point=grip(id,true)
		await button(point,true)
		check(game.drag==id,"GUI captures closeup "+id)
		await button(point,false)
	var point=grip("start",true)
	await button(point,true)
	await motion(point+Vector2(0,-30),Vector2(0,-30))
	await button(point+Vector2(0,-30),false)
	check(game.model.state.engine,"closeup starts engine through mouse")
	# Since preview.9 the levers follow their visible arc (LEVER_CONTROLS_RU.md),
	# so the drags go along the arc instead of straight up or down.
	await arc_drag("gear",0.5)
	check(game.model.state.gear==1,"closeup selects first gear")
	await arc_drag("throttle",0.5)
	check(absf(game.model.state.throttle-0.5)<0.001,"closeup throttle follows drag")
	await arc_drag("brake",0.0)
	check(game.model.state.brake==0,"closeup releases brake")
	await key(KEY_ESCAPE)
	check(not game.control_zoom and not game.paused,"Escape closes closeup")
	var report = {"checks":checks,"failures":failures,"actual_dimensions":measurements,"max_wheel_contact_error_px":max_contact_error,"max_coupling_gap_variation_px":max_coupling_error,"terrain_s":terrain,"human_novice_trial":"not performed","P3_P4_physics":"not implemented by P2"}
	var file = FileAccess.open(out_dir.path_join("geometry_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WORLD GEOMETRY CHECKS ",checks,"; FAILURES ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
