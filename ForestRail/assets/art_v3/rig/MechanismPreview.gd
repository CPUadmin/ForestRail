extends Node2D

@export var animate := true
@export var show_pivots := true
@export var cycles_per_second := 0.35
var phase := 0.0
var frame_count := 0
var assets: Dictionary
var rig: Dictionary
var textures: Dictionary = {}
var base_path: String

func _ready() -> void:
	base_path = get_script().resource_path.get_base_dir().get_base_dir()
	assets = JSON.parse_string(FileAccess.get_file_as_string(base_path + "/manifest.json")).assets
	rig = JSON.parse_string(FileAccess.get_file_as_string(base_path + "/rig/mechanism.json"))
	for id in assets:
		if id.begins_with("mechanism/") or id in ["vehicles/handcar_body", "vehicles/wheel_small"]:
			textures[id] = load(base_path + "/" + assets[id].file)
	var clean := ShaderMaterial.new()
	clean.shader = load(base_path + "/materials/edge_clean.gdshader")
	material = clean
	queue_redraw()

func _process(delta: float) -> void:
	if animate: phase = fposmod(phase + delta * TAU * cycles_per_second, TAU)
	queue_redraw()
	frame_count += 1
	if frame_count == 18:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--art-preview-shot="):
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(arg.get_slice("=", 1))
				get_tree().quit()

func point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func pose(angle: float) -> Dictionary:
	var fixed: Vector2 = point(rig.rocker_pivot)
	var axle: Vector2 = point(rig.crank_pivot)
	var b: Vector2 = axle + Vector2.from_angle(angle) * float(rig.crank_radius)
	var delta: Vector2 = b - fixed
	var distance := delta.length()
	var radius := float(rig.rocker_pin_radius)
	var length := float(rig.rod_length)
	var along := (radius*radius - length*length + distance*distance) / (2.0*distance)
	var height := sqrt(maxf(0.0, radius*radius - along*along))
	var direction := delta / distance
	var a: Vector2 = fixed + direction*along + Vector2(direction.y, -direction.x)*height
	return {"rocker": fixed, "axle": axle, "a": a, "b": b}

func part(id: String, at: Vector2, angle: float, factor: float, pivot: Vector2) -> void:
	draw_set_transform(at, angle, Vector2.ONE * factor)
	draw_texture(textures[id], -pivot)
	draw_set_transform(Vector2.ZERO)

func standard(id: String, at: Vector2, angle := 0.0) -> void:
	part(id, at, angle, float(assets[id].scale_at_128_px_per_m), point(assets[id].pivot_px))

func link(id: String, from: Vector2, to: Vector2) -> void:
	var pins: Dictionary = assets[id].pins_px
	var start: Vector2 = point(pins.start)
	var finish: Vector2 = point(pins.end)
	var source: Vector2 = finish - start
	var target: Vector2 = to - from
	part(id, from, target.angle() - source.angle(), target.length()/source.length(), start)

func _draw() -> void:
	if textures.is_empty(): return
	var p := pose(phase)
	var body: Dictionary = assets["vehicles/handcar_body"]
	var body_pivot := point(body.pivot_px)
	var body_scale := float(body.scale_at_128_px_per_m)
	draw_line(Vector2(-250, 27), Vector2(250, 27), Color("575d55"), 4, true)
	for wheel in body.wheel_centres_px:
		standard("vehicles/wheel_small", (point(wheel)-body_pivot)*body_scale, phase)
	standard("vehicles/handcar_body", Vector2.ZERO)
	part("mechanism/support", p.rocker, 0, float(rig.support_scale), point(assets["mechanism/support"].pivot_px))
	standard("mechanism/gear", p.axle, phase)
	link("mechanism/crank", p.axle, p.b)
	link("mechanism/connecting_rod", p.a, p.b)
	var lever_angle: float = (p.a - p.rocker).angle() - float(rig.lever_source_angle)
	standard("mechanism/lever", p.rocker, lever_angle)
	standard("mechanism/axle_end", p.axle, phase)
	if show_pivots:
		for key in ["rocker", "axle", "a", "b"]:
			var at: Vector2 = p[key]
			draw_arc(at, 4, 0, TAU, 20, Color("ff4dc2"), 1.2, true)
