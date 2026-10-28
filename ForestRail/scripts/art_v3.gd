extends RefCounted

const ROOT = "res://assets/art_v3/"
const BODY = {"handcar": "vehicles/handcar_body", "motorcar": "vehicles/petrol_motorcar_body", "locomotive": "vehicles/battery_locomotive_body"}
const Geometry = preload("res://scripts/world_geometry.gd")
const Mechanism = preload("res://scripts/handcar_mechanism.gd")
const PX = Geometry.PX
var manifest: Dictionary
var assets: Dictionary
var textures: Dictionary = {}
var rig: Dictionary
var geometry = Mechanism.new()

func _init() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	assets = manifest.assets
	rig = geometry.config
	for id in assets:
		textures[id] = load(ROOT + assets[id].resource)
	# Replacement bodies are calibrated uniformly by deck length. The origin
	# stays at the axle line; wheel centres and all attachments share it.
	for kind in Geometry.data().bodies:
		var spec = Geometry.body(kind)
		var id = "vehicles/freight_wagon_body" if kind=="wagon" else BODY[kind]
		var meta = assets[id].duplicate(true)
		meta.file = "../art_p2/"+spec.file
		meta.region_px = spec.region_px
		meta.pivot_px = [float(spec.region_px[0])+float(spec.region_px[2])*0.5,float(spec.axles_px[0][1])]
		meta.physical_width_m = spec.length_m
		meta.scale_at_128_px_per_m = float(spec.length_m)*128.0/float(spec.region_px[2])
		meta.wheel_centres_px = spec.axles_px
		assets[id] = meta
		var atlas = AtlasTexture.new()
		atlas.atlas = load(ROOT+meta.file)
		atlas.region = Rect2(meta.region_px[0],meta.region_px[1],meta.region_px[2],meta.region_px[3])
		atlas.filter_clip = true
		textures[id] = atlas
	assets["mechanism/lever"].scale_at_128_px_per_m = float(Geometry.body("handcar").beam_width_m)*128.0/float(assets["mechanism/lever"].region_px[2])
	# Preserve the supplied station art and calibrate by its door, not by
	# arbitrary overall image width.
	for id in Geometry.data().buildings:
		var spec = Geometry.data().buildings[id]
		var metres_per_pixel = float(spec.height_m)/float(assets[id].region_px[3]) if spec.has("height_m") else float(spec.door_height_m)/(float(spec.door_px[3])-float(spec.door_px[1]))
		assets[id].scale_at_128_px_per_m = metres_per_pixel*128.0

func vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func body_key(id: String) -> String:
	return "vehicles/freight_wagon_body" if id.begins_with("W") else BODY[id]

func scale_for(id: String) -> float:
	return float(assets[id].scale_at_128_px_per_m) * PX / 128.0

func pivot(id: String) -> Vector2:
	return vec(assets[id].pivot_px)

func axis_height(id: String) -> float:
	return -PX * float(Geometry.body(id).wheel_diameter_m) * 0.5

func body_width(id: String) -> float:
	return float(assets[body_key(id)].physical_width_m) * PX

func body_bounds(id: String) -> Rect2:
	var meta = assets[body_key(id)]
	var r = meta.region_px
	var scale = scale_for(body_key(id))
	var result = Rect2((Vector2(r[0],r[1])-pivot(body_key(id)))*scale+Vector2(0,axis_height(id)),Vector2(r[2],r[3])*scale)
	return result.expand(Vector2(-body_width(id)*0.5,0)).expand(Vector2(body_width(id)*0.5,0))

func wheel_positions(id: String) -> Array:
	var meta = assets[body_key(id)]
	var positions: Array = []
	for point in meta.wheel_centres_px:
		positions.append((vec(point) - pivot(body_key(id))) * scale_for(body_key(id)) + Vector2(0, axis_height(id)))
	return positions

func deck_y(id: String) -> float:
	var source_y = float(Geometry.body(id).deck_y_px)
	return axis_height(id) + (source_y - pivot(body_key(id)).y) * scale_for(body_key(id))

func slot_position(id: String, index: int, count: int, sprite_id: String = "sack") -> Vector2:
	var spec = Geometry.body(id)
	var x = float(spec.cargo_columns_m[index%2])
	if spec.has("cargo_crate_columns_m") and sprite_id in ["fragile_crate","crate"]: x=float(spec.cargo_crate_columns_m[index%2])
	var row = floori(index/2.0) if count>2 else 0
	var height = float(spec.cargo_row_pitch_m)*row
	if sprite_id=="log_bundle":
		x = float(spec.log_center_m)
		height = index*float(Geometry.data().cargo.log_bundle.height_m)
	return Vector2(x*PX,deck_y(id)-height*PX-19.0)

func cargo_size(sprite_id: String, ratio: float) -> Vector2:
	var spec = Geometry.data().cargo[sprite_id]
	var height = float(spec.width_m)/ratio if spec.has("width_m") else float(spec.height_m)
	return Vector2(height*ratio,height)*PX

func draw_wagon_front(canvas: Node2D, id: String, outer: Transform2D) -> void:
	# This low flatbed has no tall foreground wall. Cargo feet stay on the
	# actual visible top edge rather than being hidden by a second body copy.
	canvas.draw_set_transform_matrix(outer)

func draw_part(canvas: Node2D, id: String, position: Vector2, angle: float, scale: float, outer: Transform2D = Transform2D.IDENTITY, tint: Color = Color.WHITE) -> void:
	var meta = assets[id]
	var region = meta.region_px
	var cropped_pivot = pivot(id) - Vector2(float(region[0]), float(region[1]))
	canvas.draw_set_transform_matrix(outer * Transform2D(angle, position))
	canvas.draw_texture_rect(textures[id], Rect2(-cropped_pivot * scale, Vector2(region[2], region[3]) * scale), false, tint)
	canvas.draw_set_transform_matrix(outer)

func forward_pose(phase: float) -> Dictionary:
	return geometry.solve(phase)

func mechanism_pose(model) -> Dictionary:
	return model.handcar.pose()

func hand_grip(model) -> Vector2:
	var p = mechanism_pose(model)
	return p.grip_right*PX

func draw_vehicle(canvas: Node2D, id: String, distance: float, facing: int, outer: Transform2D, model, active: bool, pose_override: Dictionary = {}) -> void:
	draw_part(canvas, body_key(id), Vector2(0, axis_height(id)), 0, scale_for(body_key(id)), outer)
	var p = mechanism_pose(model) if id=="handcar" and pose_override.is_empty() else pose_override
	var wheel_id = "vehicles/wheel_large" if id == "locomotive" else "vehicles/wheel_small"
	var radius = PX * (0.55 if id == "locomotive" else 0.42) * 0.5
	for position in wheel_positions(id):
		var wheel_angle = fposmod(p.wheel_angle,TAU) if not pose_override.is_empty() and id=="handcar" else fposmod(distance*PX/radius*facing,TAU)
		draw_part(canvas, wheel_id, position, wheel_angle, scale_for(wheel_id), outer)
		canvas.draw_set_transform_matrix(outer * Transform2D(wheel_angle, position))
		canvas.draw_circle(Vector2(0, -radius * 0.72), 1.8, Color("c9af73"))
		canvas.draw_set_transform_matrix(outer)
	if id == "handcar": draw_mechanism(canvas, model, outer,p)
	if id.begins_with("W"):
		canvas.draw_string(ThemeDB.fallback_font, Vector2(-25, deck_y(id) + 34), id, HORIZONTAL_ALIGNMENT_CENTER, 50, 15, Color("f5ecd6"))

func mechanism_parts(p: Dictionary) -> Array:
	var parts: Array = []
	var support = assets["mechanism/support"]
	var foot_y = float(support.region_px[1])+float(support.region_px[3])-1
	var support_scale = (deck_y("handcar")-p.rocker.y*PX)/(foot_y-pivot("mechanism/support").y)
	parts.append({"id":"mechanism/support","position":p.rocker*PX,"angle":0.0,"scale":support_scale})
	var crank_angle=fposmod(p.phase,TAU)
	parts.append({"id":"mechanism/gear","position":p.crank*PX,"angle":crank_angle,"scale":scale_for("mechanism/gear")})
	var crank_source = assets["mechanism/crank"].pins_px
	var crank_vector = vec(crank_source.end) - vec(crank_source.start)
	var crank_scale = float(rig.crank_radius)*PX/crank_vector.length()
	parts.append({"id":"mechanism/crank","position":p.crank*PX,"angle":crank_angle-crank_vector.angle(),"scale":crank_scale})
	var rod_source = assets["mechanism/connecting_rod"].pins_px
	var rod_vector = vec(rod_source.end) - vec(rod_source.start)
	var rod_scale = float(rig.rod_length)*PX/rod_vector.length()
	parts.append({"id":"mechanism/connecting_rod","position":p.rocker_pin*PX,"angle":(p.crank_pin-p.rocker_pin).angle()-rod_vector.angle(),"scale":rod_scale})
	parts.append({"id":"mechanism/axle_end","position":p.crank*PX,"angle":0.0,"scale":scale_for("mechanism/axle_end")})
	var lever_vector = vec(assets["mechanism/lever"].pins_px.link)-vec(assets["mechanism/lever"].pins_px.pivot)
	parts.append({"id":"mechanism/lever","position":p.rocker*PX,"angle":p.angle-lever_vector.angle(),"scale":float(rig.rocker_pin_radius)*PX/lever_vector.length()})
	return parts

func draw_mechanism(canvas: Node2D, model, outer: Transform2D, p: Dictionary = {}) -> void:
	if p.is_empty(): p=mechanism_pose(model)
	for part in mechanism_parts(p):
		draw_part(canvas,part.id,part.position,part.angle,part.scale,outer)
