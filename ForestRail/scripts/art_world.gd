extends Node2D

class PaintLayer extends Node2D:
	var painter: Callable
	func _draw() -> void:
		if painter.is_valid(): painter.call(self)

var game
var art
var strips: Dictionary = {}
var stations
var foreground
var scenery
var lake_layer: Sprite2D
var haze
var ground_shade
var light

func _ready() -> void:
	z_index = -10
	material = ShaderMaterial.new()
	material.shader = load("res://assets/art_v3/materials/edge_clean.gdshader")
	for name in ["far_hills", "far_forest", "mid_forest"]:
		var part = MeshInstance2D.new()
		var mat = ShaderMaterial.new()
		mat.shader = load("res://assets/art_v3/materials/periodic.gdshader")
		var meta = art.assets["parallax/" + name]
		var r = meta.region_px
		var dims = meta.size_px
		mat.set_shader_parameter("source_tex", load(art.ROOT + meta.file))
		mat.set_shader_parameter("source_region", Vector4(float(r[0])/dims[0],float(r[1])/dims[1],float(r[2])/dims[0],float(r[3])/dims[1]))
		mat.set_shader_parameter("repeat_y", false)
		part.material = mat
		part.z_index = strips.size()
		add_child(part)
		strips[name] = part
	# Same z as the far forest but added later: aerial haze sits between the
	# distant planes and the near forest, which gives the scene its depth.
	haze = paint_layer(1, draw_haze)
	for name in ["soil", "ballast", "grass", "rail"]:
		var part = MeshInstance2D.new()
		part.material = load(art.ROOT + "materials/" + name + ".tres")
		part.z_index = 3 + strips.size() - 3
		add_child(part)
		strips[name] = part
	lake_layer=Sprite2D.new()
	lake_layer.texture=load("res://assets/art_p7/backwater_v1.png")
	lake_layer.material=ShaderMaterial.new()
	lake_layer.material.shader=load("res://assets/art_p7/backwater_blend.gdshader")
	lake_layer.z_index=2
	add_child(lake_layer)
	scenery=PaintLayer.new()
	scenery.z_index=2
	scenery.painter=draw_scenery
	add_child(scenery)
	stations = PaintLayer.new()
	stations.visible = false
	stations.z_index = 8
	stations.painter = draw_stations
	add_child(stations)
	foreground = PaintLayer.new()
	foreground.visible = false
	foreground.z_index = 9
	foreground.painter = draw_foreground
	add_child(foreground)
	ground_shade = paint_layer(7, draw_ground_shade)
	light = paint_layer(10, draw_light)

func paint_layer(z: int, painter: Callable) -> PaintLayer:
	var layer = PaintLayer.new()
	layer.z_index = z
	layer.painter = painter
	add_child(layer)
	return layer

func rail_y() -> float:
	var size = game.get_viewport_rect().size
	return size.y * 0.75 - 5 if game.screen == "menu" else game.rail_baseline()

static func vertical_gradient(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	canvas.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))

static func horizontal_gradient(canvas: CanvasItem, rect: Rect2, left: Color, right: Color) -> void:
	canvas.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([left, right, right, left]))

static func glow(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var edge = Color(color, 0.0)
	for i in range(40):
		var a = Vector2(cos(i * TAU / 40), sin(i * TAU / 40)) * radii
		var b = Vector2(cos((i + 1) * TAU / 40), sin((i + 1) * TAU / 40)) * radii
		canvas.draw_polygon(PackedVector2Array([center, center + a, center + b]), PackedColorArray([color, edge, edge]))

func draw_haze(canvas: Node2D) -> void:
	var size = game.get_viewport_rect().size
	var y = rail_y()
	var mist = Color(0.84, 0.9, 0.86)
	# Warm sunlight behind the treeline, then a cool mist that thickens toward the horizon.
	glow(canvas, Vector2(size.x * 0.8, y - size.y * 0.42), Vector2(size.x * 0.45, size.y * 0.32), Color(1.0, 0.93, 0.74, 0.32))
	vertical_gradient(canvas, Rect2(0, y - size.y * 0.36, size.x, size.y * 0.24), Color(mist, 0.0), Color(mist, 0.32))
	vertical_gradient(canvas, Rect2(0, y - size.y * 0.12, size.x, size.y * 0.12), Color(mist, 0.32), Color(mist, 0.12))

# Below the embankment the ground fades to a dark base for the bottom HUD
# instead of ending in a flat brown band.
func draw_ground_shade(canvas: Node2D) -> void:
	var size = game.get_viewport_rect().size
	var y = rail_y()
	var shade = Color("17201a")
	vertical_gradient(canvas, Rect2(0, y + 70, size.x, 130), Color(shade, 0.0), Color(shade, 0.78))
	canvas.draw_rect(Rect2(0, y + 200, size.x, maxf(0, size.y - y - 200)), Color(shade, 0.78))

func draw_light(canvas: Node2D) -> void:
	var size = game.get_viewport_rect().size
	var edge = Color(0.05, 0.09, 0.06, 0.38)
	var clear = Color(edge, 0.0)
	horizontal_gradient(canvas, Rect2(0, 0, size.x * 0.2, size.y), edge, clear)
	horizontal_gradient(canvas, Rect2(size.x * 0.8, 0, size.x * 0.2, size.y), clear, edge)

func mesh_strip(points: Array, uv_points: Array, tint: Color) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var uv = PackedVector2Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	for i in range(points.size()):
		vertices.append(Vector3(points[i].x, points[i].y, 0))
		uv.append(uv_points[i])
		colors.append(tint)
	for i in range(0, points.size() - 2, 2): indices.append_array(PackedInt32Array([i, i+1, i+2, i+1, i+3, i+2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func update_view() -> void:
	if art == null or game == null: return
	var size = game.get_viewport_rect().size
	var in_menu = game.screen == "menu"
	var rail_y = size.y * 0.75 - 5 if in_menu else game.rail_baseline()
	var water=0.0 if in_menu else 1-smoothstep(12,65,absf(game.camera_s-float(game.model.route.station_s[3])))
	var high=0.0 if in_menu else 1-smoothstep(12,65,absf(game.camera_s-float(game.model.route.station_s[4])))
	var warm=0.0 if in_menu else 1-smoothstep(15,85,absf(game.camera_s-float(game.model.route.station_s[5])))
	lake_layer.visible=not in_menu and water>0
	if not in_menu:
		var sc=game.view_scale()
		lake_layer.position=game.world_point(float(game.model.route.station_s[3]))+Vector2(0,-150)*sc
		lake_layer.scale=Vector2.ONE*(2600*sc/lake_layer.texture.get_width())
		lake_layer.material.set_shader_parameter("presence",water)
	for name in ["far_hills", "far_forest", "mid_forest"]:
		var height = size.y * {"far_hills": 0.25, "far_forest": 0.31, "mid_forest": 0.50}[name]
		var baseline = rail_y - {"far_hills": 105.0, "far_forest": 48.0, "mid_forest": -4.0}[name]
		var meta = art.assets["parallax/" + name]
		var width = height * float(meta.region_px[2]) / float(meta.region_px[3])
		var u = game.camera_s * art.PX * float(meta.parallax_speed) / width
		var xspan = size.x / width
		var tint=Color.WHITE if name=="mid_forest" else Color(0.78,0.87,0.86)
		tint=tint.lerp(Color(1,0.88,0.72),warm*0.45)
		if name=="mid_forest": tint.a=1-maxf(water*0.82,high*0.65)
		strips[name].mesh = mesh_strip([Vector2(0,baseline-height),Vector2(0,baseline),Vector2(size.x,baseline-height),Vector2(size.x,baseline)], [Vector2(u,0),Vector2(u,1),Vector2(u+xspan,0),Vector2(u+xspan,1)], tint)
	for name in ["soil", "ballast", "grass", "rail"]:
		var points: Array = []
		var uv: Array = []
		var scale = 1.0 if in_menu else game.view_scale()
		var top = {"soil": 16.0, "ballast": 0.0, "grass": 43.0, "rail": -0.5}[name] * scale
		var depth = {"soil": 160.0, "ballast": 31.0, "grass": 22.0, "rail": 3.0}[name] * scale
		if name=="soil": depth=maxf(depth,size.y-rail_y+80)
		var tile_m = {"soil": 2.2, "ballast": 1.8, "grass": 3.2, "rail": 3.0}[name]
		for i in range(97):
			var s = game.camera_s - 32 + i * (64.0 / 96)
			var p = Vector2((s-game.camera_s)*art.PX+size.x*0.74,rail_y) if in_menu else game.world_point(s)
			points.append(p + Vector2(0, top))
			points.append(p + Vector2(0, top + depth))
			uv.append(Vector2(s / tile_m, 0))
			uv.append(Vector2(s / tile_m, depth/(160*scale) if name=="soil" else 1))
		strips[name].mesh = mesh_strip(points, uv, Color(0.88,0.9,0.8) if name=="soil" else Color.WHITE)
	stations.visible = not in_menu
	scenery.visible=not in_menu
	scenery.queue_redraw()
	foreground.visible = true
	for layer in [stations, foreground, haze, ground_shade, light]:
		layer.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if art == null: return
	var size = game.get_viewport_rect().size
	draw_texture_rect(art.textures["parallax/sky"], Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(0, rail_y() - 5, size.x, size.y), Color("3b3326"))

func draw_stations(canvas: Node2D) -> void:
	var size = game.get_viewport_rect().size
	for i in range(game.model.data.stations.size()):
		var name = "stations/depot" if i == 0 else ("stations/sawmill_shelter" if i == 2 else "stations/station_house")
		var spec = art.Geometry.data().buildings[name]
		var sc = game.view_scale()
		var center = game.world_point(game.model.route.station_s[i]+float(spec.offset_m))+Vector2(0,-float(spec.foot_height_m)*art.PX*sc)
		var half_width = art.textures[name].get_width()*art.scale_for(name)*sc*0.5
		if center.x+half_width < -50 or center.x-half_width > size.x+50: continue
		if game.screen=="game": draw_service_platform(canvas,i)
		draw_station_details(canvas,i)
		art.draw_part(canvas, name, center, 0, art.scale_for(name)*sc)
		var height = art.textures[name].get_height()*art.scale_for(name)
		var plaque = Rect2(center+Vector2(-150,-height-48)*sc,Vector2(300,42)*sc)
		if game.screen=="game": plaque.position.y=maxf(plaque.position.y,game.hud_top_clearance())
		plaque.position.x=clampf(plaque.position.x,12,size.x-plaque.size.x-12)
		# In the depot the board would sit under the info box or the tab panel.
		var covered=game.screen=="depot" and (plaque.intersects(game.depot_info_rect) or plaque.end.x>size.x*0.46)
		if not covered:
			draw_station_board(canvas,plaque,sc,game.model.data.stations[i].name)
		if i == 0 and game.model.state.finale:
			canvas.draw_texture_rect(game.textures.final_flags,Rect2(center+Vector2(-170,-290),Vector2(320,130)),false)
	# The sleepers stay aligned to the same tangent as the rail strips.
	for i in range(floori((game.camera_s-30)*2), ceili((game.camera_s+30)*2)):
		var s = i * 0.5
		var p = game.world_point(s)
		if p.x < -40 or p.x > size.x+40: continue
		art.draw_part(canvas,"terrain/sleeper",p+Vector2(0,12*game.view_scale()),-game.model.route.slope(s),art.scale_for("terrain/sleeper")*0.58*game.view_scale(),Transform2D.IDENTITY,Color(0.82,0.82,0.7))

# Enamel station board: dark green field, brass rim and an inner keyline.
func draw_station_board(canvas: Node2D, plaque: Rect2, sc: float, name: String) -> void:
	canvas.draw_rect(Rect2(plaque.position + Vector2(4, 6), plaque.size), Color(0, 0, 0, 0.25))
	canvas.draw_style_box(game.style(Color("234232"), Color("e2c27a"), 6), plaque)
	canvas.draw_rect(plaque.grow(-4 * sc), Color(0.96, 0.93, 0.84, 0.45), false, 1.0)
	canvas.draw_string(ThemeDB.fallback_font, plaque.position+Vector2(10,28)*sc, name,HORIZONTAL_ALIGNMENT_CENTER,280*sc,int(20*sc*float(game.settings.text_scale)),game.PAPER)

func draw_service_platform(canvas: Node2D, index: int) -> void:
	var rect=game.world_platform_rect(index)
	var sc=game.view_scale()
	# Reuse the supplied platform as short uniform modules, then mark the
	# exact same service interval used by the drop transaction.
	var tex=art.textures["stations/platform"]
	var tile_width=rect.size.y*float(tex.get_width())/float(tex.get_height())
	var modules=ceili(rect.size.x/tile_width)
	for i in range(modules):
		var x=rect.position.x+i*tile_width
		var width=minf(tile_width,rect.end.x-x)
		canvas.draw_texture_rect_region(tex,Rect2(x,rect.position.y,width,rect.size.y),Rect2(0,0,float(tex.get_width())*width/tile_width,tex.get_height()),Color("c7c1a1"))
	var interaction=game.station_state()
	if int(interaction.station_index)!=index or not interaction.visible: return
	var ready=interaction.can_transfer
	var tint=game.GOLD if ready else Color("bdad7d")
	canvas.draw_rect(rect,tint,false,2)
	var marker=game.world_point(interaction.stop_s)
	canvas.draw_line(marker+Vector2(0,8*sc),marker+Vector2(0,26*sc),tint,3,true)
	canvas.draw_colored_polygon(PackedVector2Array([marker+Vector2(-8,29)*sc,marker+Vector2(8,29)*sc,marker+Vector2(0,19)*sc]),tint)

# Caption of the service zone. main draws it above trees and props, which
# otherwise cover it; this only decides its content and anchor.
func zone_label() -> Dictionary:
	if game.screen!="game": return {}
	var interaction=game.station_state()
	if not interaction.visible: return {}
	if not game.model.stopped() and game.model.state.phase!="loading": return {}
	var rect=game.world_platform_rect(int(interaction.station_index))
	var ready=interaction.can_transfer
	var label="✓ ПРИЁМ ГРУЗА · "+interaction.station_name if ready else "МЕСТО ОСТАНОВКИ · "+interaction.station_name
	if ready and interaction.eligible.is_empty() and game.model.state.phase!="loading": label="СТАНЦИЯ · "+interaction.station_name
	return {"text":label,"anchor":Vector2(rect.position.x+16,rect.position.y-12*game.view_scale()),"color":game.GOLD if ready else Color("bdad7d"),"width":minf(rect.size.x-30,700)}

func grounded(canvas: Node2D,id: String,s: float,height_m: float,offset: Vector2=Vector2.ZERO,tint: Color=Color.WHITE) -> void:
	var tex=game.textures[id]
	var scale=game.view_scale()
	var height=height_m*art.PX*scale
	var width=height*float(tex.get_width())/float(tex.get_height())
	var foot=game.world_point(s)+offset*art.PX*scale
	canvas.draw_texture_rect(tex,Rect2(foot-Vector2(width*0.5,height),Vector2(width,height)),false,tint)

func draw_scenery(canvas: Node2D) -> void:
	var scale=game.view_scale()
	# Sparse trees have roots on the same sampled terrain as the railway.
	# Their unequal spacing interrupts the periodic background silhouette.
	for i in range(floori((game.camera_s-35)/9),ceili((game.camera_s+35)/9)):
		var s=i*9.0+sin(i*3.71)*2.5
		var near_station=false
		for station_s in game.model.route.station_s:
			if absf(s-float(station_s))<14: near_station=true
		if near_station: continue
		var height=2.6+fposmod(sin(i*7.19)*713.2,2.2)
		grounded(canvas,"birch" if posmod(i,5)==0 else "pine",s,height,Vector2(0,0.06),Color("9fae91"))

func draw_station_details(canvas: Node2D,index: int) -> void:
	var s=float(game.model.route.station_s[index])
	if index==0:
		grounded(canvas,"fuel_pump",s-7,1.2)
		grounded(canvas,"log_pile",s+16,0.9)
	elif index==1:
		for offset in [-9,-6,12,17]: grounded(canvas,"pine",s+offset,3.8+0.05*absf(offset))
	elif index==2:
		for offset in [-8,-5,12]: grounded(canvas,"log_pile",s+offset,1.0+0.03*absf(offset))
		grounded(canvas,"pine",s+25,4.0)
	elif index==3:
		for offset in [-9,-6,13,18]: grounded(canvas,"birch",s+offset,3.3+0.02*absf(offset))
		grounded(canvas,"rocks",s-8,0.8)
	elif index==4:
		for offset in [-9,-5,13,18]: grounded(canvas,"rocks",s+offset,1.3+0.035*absf(offset))
		grounded(canvas,"pine",s+22,4.4,Vector2.ZERO,Color("b4b59b"))
	else:
		for offset in [-11]:
			var at=game.world_point(s+offset)
			art.draw_part(canvas,"stations/station_house",at,0,art.scale_for("stations/station_house")*game.view_scale())
		grounded(canvas,"birch",s-28,4.1)

func draw_foreground(canvas: Node2D) -> void:
	var size = game.get_viewport_rect().size
	var tex = art.textures["parallax/foreground"]
	var height = 95 * (1.0 if game.screen == "menu" else game.view_scale())
	var rail_y = size.y * 0.75 - 5 if game.screen == "menu" else game.rail_baseline()
	var width = height * tex.get_width() / tex.get_height()
	if game.screen=="menu":
		for i in range(-1,ceili(size.x/width)+2): canvas.draw_texture_rect(tex,Rect2(i*width,rail_y+height*0.05,width,height),false,Color("a3b392"))
		return
	var tile_m=width/(art.PX*game.view_scale())
	for i in range(floori((game.camera_s-35)/tile_m),ceili((game.camera_s+35)/tile_m)):
		var p=game.world_point(i*tile_m)
		canvas.draw_texture_rect(tex,Rect2(p+Vector2(0,height*0.05),Vector2(width+1,height)),false,Color("a3b392"))
	for i in range(floori((game.camera_s-35)/6),ceili((game.camera_s+35)/6)):
		if posmod(i,3)==0: grounded(canvas,"rocks",i*6.0+sin(i)*1.1,0.35,Vector2(0,0.65),Color("87946e"))
