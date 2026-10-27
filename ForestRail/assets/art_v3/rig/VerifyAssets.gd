extends SceneTree

func _initialize() -> void:
	var root := "res://assets/art_v3/"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "manifest.json"))
	var errors := 0
	var count := 0
	for id in data.assets:
		var entry: Dictionary = data.assets[id]
		var texture := load(root + str(entry.resource))
		if texture == null:
			push_error("Missing texture resource: " + str(id))
			errors += 1
		count += 1
	for kind in ["soil", "ballast", "grass", "rail"]:
		if load(root + "materials/" + kind + ".tres") == null:
			push_error("Missing periodic material: " + kind)
			errors += 1
	print("ART_V3_RESOURCES ", count, " textures, 4 materials, errors=", errors)
	quit(0 if errors == 0 else 1)
