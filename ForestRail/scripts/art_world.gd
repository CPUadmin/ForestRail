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
	for name in ["soil", "ballast", "grass", "rail"]:
		var part = MeshInstance2D.new()
		part.material = load(art.ROOT + "materials/" + name + ".tres")
		part.z_index = 3 + strips.size() - 3
		add_child(part)
		strips[name] = part
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
	for name in ["far_hills", "far_forest", "mid_forest"]:
		var height = size.y * {"far_hills": 0.25, "far_forest": 0.31, "mid_forest": 0.50}[name]
		var baseline = rail_y - {"far_hills": 105.0, "far_forest": 48.0, "mid_forest": -4.0}[name]
		var meta = art.assets["parallax/" + name]
		var width = height * float(meta.region_px[2]) / float(meta.region_px[3])
		var u = game.camera_s * art.PX * float(meta.parallax_speed) / width
		var xspan = size.x / width
		strips[name].mesh = mesh_strip([Vector2(0,baseline-height),Vector2(0,baseline),Vector2(size.x,baseline-height),Vector2(size.x,baseline)], [Vector2(u,0),Vector2(u,1),Vector2(u+xspan,0),Vector2(u+xspan,1)], Color.WHITE if name == "mid_forest" else Color(0.86,0.92,0.86))
	for name in ["soil", "ballast", "grass", "rail"]:
		var points: Array = []
		var uv: Array = []
		var scale = 1.0 if in_menu else game.view_scale()
		var top = {"soil": 16.0, "ballast": -4.0, "grass": 43.0, "rail": -6.0}[name] * scale
		var depth = {"soil": 160.0, "ballast": 31.0, "grass": 22.0, "rail": 9.0}[name] * scale
		var tile_m = {"soil": 2.2, "ballast": 1.8, "grass": 3.2, "rail": 3.0}[name]
		for i in range(97):
			var s = game.camera_s - 32 + i * (64.0 / 96)
			var p = Vector2((s-game.camera_s)*art.PX+size.x*0.74,rail_y) if in_menu else game.world_point(s)
			points.append(p + Vector2(0, top))
			points.append(p + Vector2(0, top + depth))
			uv.append(Vector2(s / tile_m, 0))
			uv.append(Vector2(s / tile_m, 1))
		strips[name].mesh = mesh_strip(points, uv, Color(0.88,0.9,0.8) if name=="soil" else Color.WHITE)
	stations.visible = not in_menu
	foreground.visible = true
	stations.queue_redraw()
	foreground.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if art == null: return
	var size = game.get_viewport_rect().size
	draw_texture_rect(art.textures["parallax/sky"], Rect2(Vector2.ZERO, size), false)
	var rail_y = size.y * 0.75 - 5 if game.screen == "menu" else game.rail_baseline()
	draw_rect(Rect2(0, rail_y - 5, size.x, size.y), Color("63533b"))

func draw_stations(canvas: Node2D) -> void:
	var size = game.get_viewport_rect().size
	for i in range(game.model.data.stations.size()):
		var p = game.world_point(game.model.route.station_s[i])
		if p.x < -700 or p.x > size.x + 700: continue
		var name = "stations/depot" if i == 0 else ("stations/sawmill_shelter" if i == 2 else "stations/station_house")
		var center = p + Vector2(370, -48)
		art.draw_part(canvas, "stations/platform", p + Vector2(370,-15), 0, art.scale_for("stations/platform") * 0.72)
		art.draw_part(canvas, name, center, 0, art.scale_for(name) * 0.72)
		var plaque = Rect2(clampf(center.x - 150, 20, size.x-325), center.y-205, 300, 42)
		canvas.draw_style_box(game.style(game.PAPER, game.GOLD, 5), plaque)
		canvas.draw_string(ThemeDB.fallback_font, plaque.position+Vector2(10,28), game.model.data.stations[i].name,HORIZONTAL_ALIGNMENT_CENTER,280,20,game.INK)
		if i == 0 and game.model.state.finale:
			canvas.draw_texture_rect(game.textures.final_flags,Rect2(center+Vector2(-170,-290),Vector2(320,130)),false)
	# The sleepers stay aligned to the same tangent as the rail strips.
	for i in range(floori((game.camera_s-30)*2), ceili((game.camera_s+30)*2)):
		var s = i * 0.5
		var p = game.world_point(s)
		if p.x < -40 or p.x > size.x+40: continue
		art.draw_part(canvas,"terrain/sleeper",p+Vector2(0,12*game.view_scale()),-game.model.route.slope(s),art.scale_for("terrain/sleeper")*0.58*game.view_scale(),Transform2D.IDENTITY,Color(0.82,0.82,0.7))

func draw_foreground(canvas: Node2D) -> void:
	var size = game.get_viewport_rect().size
	var tex = art.textures["parallax/foreground"]
	var height = 95 * (1.0 if game.screen == "menu" else game.view_scale())
	var rail_y = size.y * 0.75 - 5 if game.screen == "menu" else game.rail_baseline()
	var width = height * tex.get_width() / tex.get_height()
	var offset = fposmod(game.camera_s * art.PX * 1.12, width)
	for i in range(-1, ceili(size.x / width)+2):
		canvas.draw_texture_rect(tex,Rect2(i*width-offset,rail_y+height*0.05,width,height),false,Color(0.73,0.83,0.67))
