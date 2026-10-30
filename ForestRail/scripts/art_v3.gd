extends RefCounted

const ROOT = "res://assets/art_v3/"
const BODY = {"handcar": "vehicles/handcar_body", "motorcar": "vehicles/petrol_motorcar_body", "locomotive": "vehicles/battery_locomotive_body"}
const PX = 96.0
var manifest: Dictionary
var assets: Dictionary
var textures: Dictionary = {}
var rig: Dictionary
var wagon_front: AtlasTexture

func _init() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	assets = manifest.assets
	rig = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "rig/mechanism.json"))
	for id in assets:
		textures[id] = load(ROOT + assets[id].resource)
	var wagon_meta = assets["vehicles/freight_wagon_body"]
	wagon_front = AtlasTexture.new()
	wagon_front.atlas = load(ROOT + wagon_meta.file)
	wagon_front.region = Rect2(wagon_meta.region_px[0],246,wagon_meta.region_px[2],166)
	wagon_front.filter_clip = true

func vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func body_key(id: String) -> String:
	return "vehicles/freight_wagon_body" if id.begins_with("W") else BODY[id]

func scale_for(id: String) -> float:
	return float(assets[id].scale_at_128_px_per_m) * PX / 128.0

func pivot(id: String) -> Vector2:
	return vec(assets[id].pivot_px)

func axis_height(id: String) -> float:
	return -3.0 - PX * (0.55 if id == "locomotive" else 0.42) * 0.5

func body_width(id: String) -> float:
	return float(assets[body_key(id)].physical_width_m) * PX

func wheel_positions(id: String) -> Array:
	var meta = assets[body_key(id)]
	var positions: Array = []
	for point in meta.wheel_centres_px:
		positions.append((vec(point) - pivot(body_key(id))) * scale_for(body_key(id)) + Vector2(0, axis_height(id)))
	return positions

func deck_y(id: String) -> float:
	var source_y = {"handcar": 280.0, "motorcar": 350.0, "wagon": 390.0}.get("wagon" if id.begins_with("W") else id, 360.0)
	return axis_height(id) + (source_y - pivot(body_key(id)).y) * scale_for(body_key(id))

func slot_position(id: String, index: int, count: int) -> Vector2:
	var x = (index % 2 - 0.5) * 71.0 if count > 2 else (index - (count - 1) * 0.5) * 76.0
	if id == "motorcar": x += 66.0
	if id == "handcar": x = -92.0 if index % 2 == 0 else 92.0
	var y = deck_y(id) - 19.0 - (floori(index / 2.0) * 62.0 if count > 2 else 0.0)
	return Vector2(x, y)

func draw_wagon_front(canvas: Node2D, id: String, outer: Transform2D) -> void:
	var meta = assets[body_key(id)]
	var scale = scale_for(body_key(id))
	canvas.draw_set_transform_matrix(outer)
	canvas.draw_texture_rect(wagon_front,Rect2((wagon_front.region.position-pivot(body_key(id)))*scale+Vector2(0,axis_height(id)),wagon_front.region.size*scale),false)

func draw_part(canvas: Node2D, id: String, position: Vector2, angle: float, scale: float, outer: Transform2D = Transform2D.IDENTITY, tint: Color = Color.WHITE) -> void:
	var meta = assets[id]
	var region = meta.region_px
	var cropped_pivot = pivot(id) - Vector2(float(region[0]), float(region[1]))
	canvas.draw_set_transform_matrix(outer * Transform2D(angle, position))
	canvas.draw_texture_rect(textures[id], Rect2(-cropped_pivot * scale, Vector2(region[2], region[3]) * scale), false, tint)
	canvas.draw_set_transform_matrix(outer)

func forward_pose(phase: float) -> Dictionary:
	var s = vec(rig.rocker_pivot)
	var c = vec(rig.crank_pivot)
	var b = c + Vector2(cos(phase), sin(phase)) * float(rig.crank_radius)
	var delta = b - s
	var d = delta.length()
	var u = delta / d
	var radius = float(rig.rocker_pin_radius)
	var length = float(rig.rod_length)
	var a = (radius * radius - length * length + d * d) / (2 * d)
	var h = sqrt(maxf(0, radius * radius - a * a))
	var rocker_pin = s + u * a + Vector2(u.y, -u.x) * h
	return {"rocker": s, "rocker_pin": rocker_pin, "crank": c, "crank_pin": b, "angle": (rocker_pin - s).angle(), "phase": phase}

# motion is the last non-zero stroke direction; it picks the crank branch.
func pose(control_angle: float, motion: int, direction: int) -> Dictionary:
	var stroke = motion if motion != 0 else 1
	var limits = rig.validation.rocker_degrees
	var angle = deg_to_rad(lerpf(float(limits[0]), float(limits[1]), clampf((control_angle + deg_to_rad(28)) / deg_to_rad(56), 0.00001, 0.99999)))
	var s = vec(rig.rocker_pivot)
	var c = vec(rig.crank_pivot)
	var a_point = s + Vector2(cos(angle), sin(angle)) * float(rig.rocker_pin_radius)
	var delta = a_point - c
	var d = delta.length()
	var u = delta / d
	var r = float(rig.crank_radius)
	var length = float(rig.rod_length)
	var along = (r * r - length * length + d * d) / (2 * d)
	var h = sqrt(maxf(0, r * r - along * along))
	var base = c + u * along
	var perpendicular = u.orthogonal()
	var chosen = base + perpendicular * h
	for b in [base + perpendicular * h, base - perpendicular * h]:
		var phase = (b - c).angle()
		var slope = float(forward_pose(phase + 0.0001).angle) - float(forward_pose(phase).angle)
		if signf(slope) == signf(float(stroke * direction)): chosen = b; break
	return {"rocker": s, "rocker_pin": a_point, "crank": c, "crank_pin": chosen, "angle": angle, "phase": (chosen - c).angle()}

func mechanism_pose(model) -> Dictionary:
	return pose(model.pump_angle, model.pump_visual_motion, model.drive_direction())

func hand_grip(model) -> Vector2:
	var p = mechanism_pose(model)
	var at128 = vec(rig.rocker_pivot) + Vector2(128, 0).rotated(float(p.angle))
	return at128 * PX / 128 + Vector2(0, axis_height("handcar"))

func draw_vehicle(canvas: Node2D, id: String, distance: float, facing: int, outer: Transform2D, model, active: bool) -> void:
	draw_part(canvas, body_key(id), Vector2(0, axis_height(id)), 0, scale_for(body_key(id)), outer)
	var wheel_id = "vehicles/wheel_large" if id == "locomotive" else "vehicles/wheel_small"
	var radius = PX * (0.55 if id == "locomotive" else 0.42) * 0.5
	for position in wheel_positions(id):
		draw_part(canvas, wheel_id, position, distance * PX / radius * facing, scale_for(wheel_id), outer)
		canvas.draw_set_transform_matrix(outer * Transform2D(distance * PX / radius * facing, position))
		canvas.draw_circle(Vector2(0, -radius * 0.72), 1.8, Color("c9af73"))
		canvas.draw_set_transform_matrix(outer)
	if id == "handcar": draw_mechanism(canvas, model, outer)
	if id.begins_with("W"):
		canvas.draw_string(ThemeDB.fallback_font, Vector2(-25, deck_y(id) + 34), id, HORIZONTAL_ALIGNMENT_CENTER, 50, 15, Color("f5ecd6"))

func draw_mechanism(canvas: Node2D, model, outer: Transform2D) -> void:
	var p = mechanism_pose(model)
	var factor = PX / 128.0
	var offset = Vector2(0, axis_height("handcar"))
	draw_part(canvas, "mechanism/support", p.rocker * factor + offset, 0, float(rig.support_scale) * factor, outer)
	draw_part(canvas, "mechanism/gear", p.crank * factor + offset, p.phase, scale_for("mechanism/gear"), outer)
	var crank_source = assets["mechanism/crank"].pins_px
	var crank_vector = vec(crank_source.end) - vec(crank_source.start)
	var crank_scale = float(rig.crank_radius) / crank_vector.length() * factor
	draw_part(canvas, "mechanism/crank", p.crank * factor + offset, p.phase - crank_vector.angle(), crank_scale, outer)
	var rod_source = assets["mechanism/connecting_rod"].pins_px
	var rod_vector = vec(rod_source.end) - vec(rod_source.start)
	var rod_scale = float(rig.rod_length) / rod_vector.length() * factor
	draw_part(canvas, "mechanism/connecting_rod", p.rocker_pin * factor + offset, (p.crank_pin - p.rocker_pin).angle() - rod_vector.angle(), rod_scale, outer)
	draw_part(canvas, "mechanism/axle_end", p.crank * factor + offset, 0, scale_for("mechanism/axle_end"), outer)
	draw_part(canvas, "mechanism/lever", p.rocker * factor + offset, p.angle - float(rig.lever_source_angle), scale_for("mechanism/lever"), outer)
