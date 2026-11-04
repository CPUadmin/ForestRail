extends Node
# Skins: a player's body.png (and wheel.png) replaces the built-in picture while the
# class keeps its standard platform length, axle places and floor height.
const Art = preload("res://scripts/art_v3.gd")
const Geometry = preload("res://scripts/world_geometry.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func write_skin(dir: String, kind: String, scale: int, pad: int) -> void:
	# A skin made from the built-in picture, drawn 'scale' times larger and padded.
	var spec = Geometry.body(kind)
	var source = Image.load_from_file(ProjectSettings.globalize_path("res://assets/art_p2/" + str(spec.file)))
	source.convert(Image.FORMAT_RGBA8)
	var r = spec.region_px
	var cropped = source.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	cropped.resize(int(r[2]) * scale, int(r[3]) * scale, Image.INTERPOLATE_BILINEAR)
	var padded = Image.create(cropped.get_width() + pad * 2, cropped.get_height() + pad * 2, false, Image.FORMAT_RGBA8)
	padded.blit_rect(cropped, Rect2i(0, 0, cropped.get_width(), cropped.get_height()), Vector2i(pad, pad))
	DirAccess.make_dir_recursive_absolute(dir.path_join(kind))
	padded.save_png(dir.path_join(kind).path_join("body.png"))

func run() -> void:
	var dir = ProjectSettings.globalize_path("user://qa_skins_" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(dir)
	var plain = Art.new(dir)
	check(plain.skin_deck.is_empty() and plain.skin_report.is_empty(), "empty skins folder changes nothing")
	check(FileAccess.file_exists(dir.path_join("README.txt")) and DirAccess.dir_exists_absolute(dir.path_join("steam")), "skins folder and README are created")
	var reference = Art.new()
	for kind in ["steam", "motorcar", "locomotive"]:
		write_skin(dir, kind, 2, 40)
	var skinned = Art.new(dir)
	for kind in ["steam", "motorcar", "locomotive"]:
		check(skinned.is_skinned(kind), kind + " skin is picked up")
		var spec = Geometry.body(kind)
		var region = spec.region_px
		var centre_x = float(region[0]) + float(region[2]) * 0.5
		var scale = float(spec.length_m) * Art.PX / float(region[2])
		var wheels = skinned.wheel_positions(kind)
		check(wheels.size() == spec.axles_px.size(), kind + " keeps its standard axle count")
		for i in range(mini(wheels.size(), spec.axles_px.size())):
			var expected = Vector2((float(spec.axles_px[i][0]) - centre_x) * scale, -float(spec.wheel_diameter_m) * Art.PX * 0.5)
			check(wheels[i].distance_to(expected) < 1.5, kind + " skin keeps its standard axle position")
		check(absf(reference.deck_y(kind) - skinned.deck_y(kind)) < 1.5, kind + " floor height is standard")
		check(absf(reference.body_width(kind) - skinned.body_width(kind)) < 0.5, kind + " keeps the standard platform length")
	# A broken picture falls back to the built-in one and says so.
	var broken_dir = dir.path_join("broken")
	DirAccess.make_dir_recursive_absolute(broken_dir.path_join("steam"))
	var file = FileAccess.open(broken_dir.path_join("steam").path_join("body.png"), FileAccess.WRITE)
	file.store_string("not a picture")
	file.close()
	var fallback = Art.new(broken_dir)
	check(not fallback.is_skinned("steam") and fallback.skin_report.size() >= 1, "unreadable body.png falls back with a message")
	# A custom wheel is used for that class only.
	var wheel = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	wheel.fill(Color(1, 0, 0, 1))
	wheel.save_png(dir.path_join("motorcar").path_join("wheel.png"))
	var with_wheel = Art.new(dir)
	check(with_wheel.skin_wheel.has("motorcar") and not with_wheel.skin_wheel.has("steam"), "wheel.png applies to its own class only")
	print("SKIN CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
