extends Node2D

@export var points := PackedVector2Array([Vector2(0,0), Vector2(350,-30), Vector2(650,-36), Vector2(1000,5), Vector2(1450,0)])
var frame_count := 0
var curve := Curve2D.new()
var base_path: String
var metadata: Dictionary

func _ready() -> void:
	base_path = get_script().resource_path.get_base_dir().get_base_dir()
	metadata = JSON.parse_string(FileAccess.get_file_as_string(base_path + "/manifest.json")).assets
	curve.bake_interval = 4
	for i in range(points.size()):
		var before: Vector2 = points[maxi(0, i-1)]
		var after: Vector2 = points[mini(points.size()-1, i+1)]
		var tangent: Vector2 = (after-before)/6.0
		curve.add_point(points[i], -tangent, tangent)
	var baked := curve.get_baked_points()
	band(baked, 31, 380, "soil", 256, 256)
	band(baked, 13, 43, "ballast", 180, 95)
	band(baked, 28, 52, "grass", 256, 24)
	var sleeper: Dictionary = metadata["terrain/sleeper"]
	var tex: Texture2D = load(base_path + "/terrain/sleeper.png")
	var step := 0.0
	while step <= curve.get_baked_length():
		var transform := curve.sample_baked_with_rotation(step)
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.offset = -Vector2(sleeper.pivot_px[0], sleeper.pivot_px[1])
		sprite.scale = Vector2.ONE * float(sleeper.scale_at_128_px_per_m)
		sprite.position = transform.origin + transform.y * 18
		sprite.rotation = transform.get_rotation()
		add_child(sprite)
		step += 0.8 * 128
	band(baked, 0, 10, "rail", 256, 10)

func band(baked: PackedVector2Array, top: float, bottom: float, kind: String, tile_width: float, tile_height: float) -> void:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var distance := 0.0
	for i in range(baked.size()):
		if i>0: distance += baked[i].distance_to(baked[i-1])
		var tangent: Vector2 = (baked[mini(i+1,baked.size()-1)]-baked[maxi(0,i-1)]).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		var a: Vector2 = baked[i]+normal*top
		var b: Vector2 = baked[i]+normal*bottom
		vertices.append(Vector3(a.x,a.y,0))
		vertices.append(Vector3(b.x,b.y,0))
		uv.append(Vector2(distance/tile_width,0))
		uv.append(Vector2(distance/tile_width,(bottom-top)/tile_height))
		if i>0:
			var j := i*2
			indices.append_array(PackedInt32Array([j-2,j,j-1,j-1,j,j+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var view := MeshInstance2D.new()
	view.mesh = mesh
	view.material = load(base_path + "/materials/" + kind + ".tres")
	add_child(view)

func _process(_delta: float) -> void:
	frame_count += 1
	if frame_count == 18:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--art-preview-shot="):
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(arg.get_slice("=",1))
				get_tree().quit()
