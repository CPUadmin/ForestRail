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

# P1: the road painted by GPT: the rail with the sleepers and the ballast, the cut of the earth under it, small things of the verge
const ROAD_TRACK = preload("res://assets/art_road/track_tile.png")
const ROAD_GROUND = preload("res://assets/art_road/ground_tile.png")
const DEPOT_FLOOR = preload("res://assets/art_depot/floor.png")   # P4: in the depot the cut of the floor replaces the cut of the earth
const STATION_ART = {
	"B": [preload("res://assets/art_stations/station_b_small.png"), 3.0],
	"E": [preload("res://assets/art_stations/station_e.png"), 4.6],
	"F": [preload("res://assets/art_stations/station_f.png"), 5.5],
}
const ROAD_TRACK_M = 1.8       # the length of the track tile in metres (three sleepers, 0.6 m apart)
const ROAD_GROUND_M = 3.0      # the length of the ground tile in metres
const ROAD_LIP_OVERLAP = 26.0  # the grass lip of the ground overlaps the bottom of the ballast, in pixels at the view scale 1
const TRACKSIDE = [
	preload("res://assets/art_road/trackside_1.png"), preload("res://assets/art_road/trackside_2.png"), preload("res://assets/art_road/trackside_3.png"),
	preload("res://assets/art_road/trackside_4.png"), preload("res://assets/art_road/trackside_5.png"), preload("res://assets/art_road/trackside_6.png"),
	preload("res://assets/art_road/trackside_7.png"), preload("res://assets/art_road/trackside_8.png"), preload("res://assets/art_road/trackside_9.png")]
const TRACKSIDE_M = [0.46, 0.60, 0.70, 0.64, 0.58, 0.70, 0.40, 0.85, 0.58]   # the height of every thing in metres (kept low: they stand in front of the track)

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
	for name in ["track", "ground"]:
		var part = MeshInstance2D.new()
		part.texture = ROAD_TRACK if name == "track" else ROAD_GROUND
		part.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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

# B4.1: night and twilight over the world, then the lights of the machine and of the stations on top of it.
func draw_day_night(canvas: Node2D, size: Vector2) -> void:
	var model = game.model
	if model == null or model.state.is_empty() or game.screen != "game": return
	var night = model.night_amount()
	var tw = minf(1.0, model.twilight())
	if tw > 0.01: canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.5, 0.25, 0.16 * tw))
	if night > 0.01: canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.12, game.night_shade()))
	draw_weather(canvas, Rect2(Vector2.ZERO, size), game.shown_weather(), Time.get_ticks_msec() / 1000.0, bool(game.settings.reduce_motion))
	# the lights burn at night and, brighter than the fog, in a thick fog by day
	var lit = maxf(clampf((night - 0.25) / 0.5, 0.0, 1.0), clampf(float(game.shown_weather().fog) * 1.2, 0.0, 1.0))
	if lit < 0.05: return
	var sc = game.view_scale()
	# windows of the stations
	for i in range(model.data.stations.size()):
		var at = game.world_point(float(model.route.station_s[i])) + Vector2(0, -1.6 * art.PX * sc)
		glow(canvas, at, Vector2(1.5, 0.9) * art.PX * sc, Color(1.0, 0.8, 0.45, 0.5 * lit))
	# the headlamp of the lead machine: a warm cone ahead, when it is lit
	if not game.lights_lit(): return
	lit = clampf(0.55 + night * 0.45, 0.0, 1.0)
	var id: String = model.vehicle_id()
	var body: Transform2D = game.body_transform(id, model.body_s_render(0))
	var front = body * art.headlamp_point(id)
	var forward = body.x.normalized()
	var down = Vector2.DOWN
	var unit = art.PX * sc
	var centers = [front, front + (forward * 2.8 + down * 0.35) * unit, front + (forward * 8.0 + down * 0.85) * unit]
	var widths = [0.035, 0.64, 1.45]
	var color = Color(1.0, 0.88, 0.55, 0.32 * lit)
	var colors = [color, Color(color, 0.13 * lit), Color(color, 0.0)]
	for i in range(2):
		for side in [-1, 1]:
			var a: Vector2 = centers[i]
			var b: Vector2 = centers[i + 1]
			var far_edge = b + down * float(widths[i + 1]) * unit * side
			var near_edge = a + down * float(widths[i]) * unit * side
			canvas.draw_polygon(PackedVector2Array([a, b, far_edge, near_edge]), PackedColorArray([colors[i], colors[i + 1], Color(color, 0.0), Color(color, 0.0)]))
	var ground = game.world_point(float(model.body_s_render(0)) + float(model.state.direction) * 4.3)
	glow(canvas, ground, Vector2(1.9, 0.16) * unit, Color(1.0, 0.88, 0.55, 0.17 * lit))
	glow(canvas, front, Vector2(0.28, 0.24) * unit, Color(1.0, 0.9, 0.6, 0.72 * lit))

# B4.2: clouds, rain and fog over a rectangle of the screen (the world, or the glass of the cab).
func draw_weather(canvas: CanvasItem, rect: Rect2, weather: Dictionary, time: float, calm: bool = false) -> void:
	var cloud = float(weather.cloud)
	var rain = float(weather.rain)
	var fog = float(weather.fog)
	if cloud > 0.02: canvas.draw_rect(rect, Color(0.55, 0.6, 0.65, 0.2 * cloud))
	if fog > 0.02:
		vertical_gradient(canvas, Rect2(rect.position, Vector2(rect.size.x, rect.size.y)), Color(0.82, 0.86, 0.86, 0.35 * fog), Color(0.82, 0.86, 0.86, 0.62 * fog))
	if rain > 0.05:
		canvas.draw_rect(rect, Color(0.12, 0.16, 0.22, 0.2 * rain))
		var drops = int(110.0 * rain)
		var length = rect.size.y * 0.035
		for i in range(drops):
			var seed_x = fposmod(float(i) * 0.6180339 + 0.13, 1.0)
			var seed_y = fposmod(float(i) * 0.3819660 + 0.71, 1.0)
			var speed = 0.0 if calm else (0.9 + 0.5 * fposmod(float(i) * 0.137, 1.0))
			var y = fposmod(seed_y + time * speed, 1.0)
			var x = fposmod(seed_x + y * 0.12, 1.0)
			var at = rect.position + Vector2(x * rect.size.x, y * rect.size.y)
			canvas.draw_line(at, at + Vector2(length * 0.2, length), Color(0.78, 0.85, 0.92, 0.38), 1.2)

func draw_light(canvas: Node2D) -> void:
	var size = game.get_viewport_rect().size
	draw_day_night(canvas, size)
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
	var road_scale = 1.0 if in_menu else game.view_scale()
	var track_depth = ROAD_TRACK_M * art.PX * road_scale * float(ROAD_TRACK.get_height()) / float(ROAD_TRACK.get_width())
	for name in ["track", "ground"]:
		var points: Array = []
		var uv: Array = []
		var tile_m = ROAD_TRACK_M if name == "track" else ROAD_GROUND_M
		var tex: Texture2D = ROAD_TRACK if name == "track" else (DEPOT_FLOOR if game.screen == "depot" else ROAD_GROUND)
		if name == "ground": strips[name].texture = tex
		var depth = tile_m * art.PX * road_scale * float(tex.get_height()) / float(tex.get_width())
		var top = 0.0 if name == "track" else track_depth - (8.0 if game.screen == "depot" else ROAD_LIP_OVERLAP) * road_scale
		for i in range(97):
			var s = game.camera_s - 32 + i * (64.0 / 96)
			var p = Vector2((s-game.camera_s)*art.PX+size.x*0.74,rail_y) if in_menu else game.world_point(s)
			points.append(p + Vector2(0, top))
			points.append(p + Vector2(0, top + depth))
			uv.append(Vector2(s / tile_m, 0))
			uv.append(Vector2(s / tile_m, 1))
		strips[name].mesh = mesh_strip(points, uv, Color.WHITE)
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
	draw_rect(Rect2(0, rail_y() - 5, size.x, size.y), Color("1b1008"))

func station_building_id(index: int) -> String:
	return "stations/depot" if index == 0 else ("stations/sawmill_shelter" if index == 2 else "stations/station_house")

# B6.3: a pennant on the roof of every station: cloth on a few joints that streams down the wind (the along-route wind of
# the place) and flutters faster and wider in a strong wind and in a gust. In the calm it hangs.
func wind_on_screen(s: float) -> Vector2:
	var m = game.model
	if m.state.is_empty(): return Vector2(2.0, 0.0)
	var w = m.wind_here(s)
	return Vector2(w.x * float(int(m.state.direction)), w.y)   # x: toward the larger distance = to the right of the picture

func draw_pennant(canvas: Node2D, foot: Vector2, sc: float, s: float, colour: Color, phase_shift: float = 0.0) -> void:
	var wind = wind_on_screen(s)
	var strength = clampf(wind.length(), 0.0, 9.0)
	var pole_h = 0.95 * art.PX * sc
	var top = foot + Vector2(0, -pole_h)
	canvas.draw_line(foot, top, Color("3a2d1c"), maxf(2.0, 0.035 * art.PX * sc), true)
	canvas.draw_circle(top, 0.03 * art.PX * sc, Color("c9a85a"))
	var side = 1.0 if wind.x >= 0.0 else -1.0
	var lift = clampf(1.0 - strength / 5.0, 0.0, 1.0)          # a calm lets the cloth hang down, a wind lifts it level
	var length = (0.55 + 0.05 * strength) * art.PX * sc
	var width = 0.22 * art.PX * sc
	var t = Time.get_ticks_msec() / 1000.0 * (1.6 + 0.9 * strength) + phase_shift
	var calm_motion = 0.25 if game.settings.reduce_motion else 1.0
	var upper = PackedVector2Array()
	var lower = PackedVector2Array()
	var steps = 8
	for k in range(steps + 1):
		var u = float(k) / float(steps)
		var wave = sin(t - u * 5.0) * (0.02 + 0.045 * u) * (0.3 + 0.12 * strength) * art.PX * sc * calm_motion
		var along = Vector2(side * u * length * (1.0 - 0.55 * lift), u * length * 0.8 * lift)   # hangs down in the calm
		var centre = top + Vector2(0, width * 0.55) + along + Vector2(0, wave)
		var half = width * 0.5 * (1.0 - 0.55 * u)
		upper.append(centre + Vector2(0, -half))
		lower.append(centre + Vector2(0, half))
	var poly = PackedVector2Array()
	for p in upper: poly.append(p)
	for k in range(lower.size() - 1, -1, -1): poly.append(lower[k])
	canvas.draw_colored_polygon(poly, colour)
	canvas.draw_polyline(upper, colour.darkened(0.35), 1.5, true)
	canvas.draw_polyline(lower, colour.darkened(0.35), 1.5, true)

func draw_stations(canvas: Node2D) -> void:
	var size = game.get_viewport_rect().size
	for i in range(game.model.data.stations.size()):
		var station = game.model.data.stations[i]
		var name = station_building_id(i)
		var spec = art.Geometry.data().buildings[name]
		var sc = game.view_scale()
		var facade = STATION_ART.get(station.id, [])
		var center = game.world_point(game.model.route.station_s[i] + float(spec.offset_m))
		var texture: Texture2D = art.textures[name]
		var height = texture.get_height() * art.scale_for(name)
		var half_width = texture.get_width() * art.scale_for(name) * sc * 0.5
		if facade.is_empty():
			center.y -= float(spec.foot_height_m) * art.PX * sc
		else:
			texture = facade[0]
			height = float(facade[1]) * art.PX
			half_width = height * float(texture.get_width()) / float(texture.get_height()) * sc * 0.5
		if center.x+half_width < -50 or center.x-half_width > size.x+50: continue
		if game.screen=="game": draw_service_platform(canvas,i)
		draw_station_details(canvas,i)
		if facade.is_empty():
			art.draw_part(canvas, name, center, 0, art.scale_for(name)*sc)
		else:
			canvas.draw_texture_rect(texture, Rect2(center - Vector2(half_width, height * sc), Vector2(2.0 * half_width, height * sc)), false)
		if game.screen == "game":
			var flag_colours = [Color("bf3b2e"), Color("e8d9a8"), Color("3f7a52"), Color("d9a640"), Color("bf3b2e"), Color("e8d9a8")]
			draw_pennant(canvas, center + Vector2(half_width * 0.74, -height * sc * 0.93), sc, float(game.model.route.station_s[i]), flag_colours[i % flag_colours.size()], float(i) * 1.7)
		var plaque = Rect2(center+Vector2(-150,-height-48)*sc,Vector2(300,42)*sc)
		if game.screen=="game": plaque.position.y=maxf(plaque.position.y,game.hud_top_clearance())
		plaque.position.x=clampf(plaque.position.x,12,size.x-plaque.size.x-12)
		# In the depot the board would sit under the info box or the tab panel.
		var covered=game.screen=="depot" and (plaque.intersects(game.depot_info_rect) or plaque.end.x>size.x*0.46)
		if not covered:
			draw_station_board(canvas,plaque,sc,station.name)
		if i == 0 and game.model.state.finale:
			canvas.draw_texture_rect(game.textures.final_flags,Rect2(center+Vector2(-170,-290),Vector2(320,130)),false)

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

# P1: small things of the verge (stones, a boulder, grass, a fern, flowers, a stump, a log, a heap of sleepers, a kilometre post),
# placed by the number of the cell of the line, so a place always looks the same.
func trackside_noise(i: int, k: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233 + float(int(game.model.route.seed_value) % 977) * 0.37) * 43758.5453, 1.0)

func draw_trackside(canvas: Node2D) -> void:
	var sc = game.view_scale()
	var track_depth = ROAD_TRACK_M * art.PX * sc * float(ROAD_TRACK.get_height()) / float(ROAD_TRACK.get_width())
	var lip = track_depth - ROAD_LIP_OVERLAP * sc * 0.15
	for i in range(floori((game.camera_s - 40) / 4.0), ceili((game.camera_s + 40) / 4.0)):
		if trackside_noise(i, 1) < 0.30: continue
		var s = i * 4.0 + (trackside_noise(i, 2) - 0.5) * 3.0
		var near_station = false
		for station_s in game.model.route.station_s:
			if absf(s - float(station_s)) < 16.0: near_station = true
		if near_station: continue
		var kind = int(trackside_noise(i, 3) * 8.0)
		if kind >= 7: kind += 1          # the post (7) is not among the random things, it stands at every kilometre
		draw_trackside_thing(canvas, kind, s, lip + trackside_noise(i, 4) * 9.0 * sc, 0.85 + 0.3 * trackside_noise(i, 5), trackside_noise(i, 6) > 0.5, sc)
	# a kilometre post at every full kilometre of the line
	for k in range(floori((game.camera_s - 40) / 1000.0), ceili((game.camera_s + 40) / 1000.0) + 1):
		if k <= 0: continue
		var s = k * 1000.0
		if absf(s - game.camera_s) < 45.0: draw_trackside_thing(canvas, 7, s, lip + 4.0 * sc, 1.0, false, sc)

func draw_trackside_thing(canvas: Node2D, kind: int, s: float, drop: float, size_k: float, flip: bool, sc: float) -> void:
	var tex: Texture2D = TRACKSIDE[kind]
	var height = float(TRACKSIDE_M[kind]) * size_k * art.PX * sc
	var width = height * float(tex.get_width()) / float(tex.get_height())
	var at = game.world_point(s) + Vector2(0, drop)
	var x = -width * 0.5
	var tint = Color(0.96, 0.96, 0.92)
	# B6.3: tall grass (2), fern (3) and flowers (4) bend with the wind: the foot stays, the top leans downwind and trembles in a gust
	if kind >= 2 and kind <= 4:
		var wind = wind_on_screen(s)
		var strength = clampf(wind.length(), 0.0, 9.0)
		var motion = 0.25 if game.settings.reduce_motion else 1.0
		var lean = (clampf(wind.x, -7.0, 7.0) * 0.012 + sin(Time.get_ticks_msec() / 1000.0 * (1.4 + 0.5 * strength) + s * 0.7) * 0.006 * strength * motion) * height
		var left = at.x - width * 0.5
		var right = at.x + width * 0.5
		var top = at.y - height
		var u0 = 1.0 if flip else 0.0
		var u1 = 0.0 if flip else 1.0
		var pts = PackedVector2Array([Vector2(left + lean, top), Vector2(right + lean, top), Vector2(right, at.y), Vector2(left, at.y)])
		var uvs = PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])
		canvas.draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uvs, tex)
		return
	canvas.draw_texture_rect(tex, Rect2(at + Vector2(-x if flip else x, -height), Vector2(-width if flip else width, height)), false, tint)

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
		# P1: the grass lip of the painted ground replaces this band of ferns (it stays only in the menu)
		if false: canvas.draw_texture_rect(tex,Rect2(p+Vector2(0,height*0.05),Vector2(width+1,height)),false,Color("a3b392"))
	for i in range(floori((game.camera_s-35)/6),ceili((game.camera_s+35)/6)):
		if false: grounded(canvas,"rocks",i*6.0+sin(i)*1.1,0.35,Vector2(0,0.65),Color("87946e"))
	draw_trackside(canvas)
