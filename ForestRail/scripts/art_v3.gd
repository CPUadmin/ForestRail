extends RefCounted

const ROOT = "res://assets/art_v3/"
# The steam engine body is drawn by tools/make_steam_art.py; the fire glow,
# needle, smoke and rods are drawn live in draw_steam_overlay / draw_steam_motion.
const BODY = {"handcar": "vehicles/handcar_body", "pole": "vehicles/pole_body", "sail": "vehicles/sail_body", "steam": "vehicles/steam_locomotive_body", "motorcar": "vehicles/petrol_motorcar_body", "locomotive": "vehicles/battery_locomotive_body", "pneumatic": "vehicles/pneumatic_body", "zeppelin": "vehicles/zeppelin_body", "jet": "vehicles/jet_body"}
const LARGE_WHEELS = ["locomotive", "steam", "pneumatic"]
# Opaque tread diameters measured horizontally and vertically in the painted sprites.
const PAINTED_WHEEL_TREAD = {
	"vehicles/wheel_large": Vector2(1090, 1102),
	"vehicles/wheel_small": Vector2(1102, 1110),
}
const STOCK_WHEEL_TINT = {
	"locomotive": Color("e3e8d8"),
	"steam": Color("fff0cf"),
	"pneumatic": Color("c2d4e1"),
	"motorcar": Color("f0b8a5"),
}
const Geometry = preload("res://scripts/world_geometry.gd")
const Mechanism = preload("res://scripts/handcar_mechanism.gd")
const PX = Geometry.PX
const WORKER_TEXTURE = preload("res://assets/art_consists/rail_worker_side.png")
const WORKER_REGION = Rect2(382, 21, 357, 1273)

const POLE_HEAD = preload("res://assets/art_pole_sail/pole_head.png")
const POLE_SHAFT = preload("res://assets/art_pole_sail/pole_shaft.png")
const POLE_FOOT = preload("res://assets/art_pole_sail/pole_foot.png")
const ARM_UPPER = preload("res://assets/art_pole_sail/worker_upper_arm.png")
const ARM_FORE = preload("res://assets/art_pole_sail/worker_forearm.png")
const HAND_GRIP = preload("res://assets/art_pole_sail/worker_hand_grip.png")
const HAND_PIVOT = Vector2(29, 20)       # the middle of the rolled cuff, in the pixels of the picture
const HAND_TURN = 1.152                  # the turn of the picture, in which the wrist looks along the forearm (66 degrees)
const HAND_OPEN = preload("res://assets/art_pole_sail/worker_hand_open.png")
const HAND_OPEN_PIVOT = Vector2(19, 14)
const HAND_OPEN_TURN = 0.99
# the sailor sits on a crate (P2b): the points of the picture as fractions of its size
const SAILOR = preload("res://assets/art_pole_sail/sailor_seated.png")
const SAILOR_PIVOT_F = Vector2(0.2464, 0.9971)      # the middle of the crate's foot, it stands on the deck
const SAILOR_SHOULDER_F = Vector2(0.2674, 0.2988)   # the shoulder seam: the arm grows from here
const SAILOR_KNEE_F = Vector2(0.7780, 0.5918)       # the knee: the free hand rests here
const SAILOR_HEIGHT_M = 1.126                       # the figure with the crate, in metres
# The rower and the oars (P16, painted by GPT): three poses of the same man on the same crate (the picture is 380x563 px, the middle of the crate's foot at the pivot), one oar, the oarlock.
const ROWER = {
	"catch": preload("res://assets/art_oars/rower_catch.png"), "drive": preload("res://assets/art_oars/rower_drive.png"), "recovery": preload("res://assets/art_oars/rower_recovery.png")}
const ROWER_PIVOT = Vector2(160, 557)
const ROWER_M_PER_PX = 1.126 / 550.0
const OAR = preload("res://assets/art_oars/oar.png")
const OARLOCK = preload("res://assets/art_oars/oarlock.png")
const SAIL_CLOTH = preload("res://assets/art_pole_sail/sail_cloth.png")
const SAIL_CLEAT = preload("res://assets/art_pole_sail/sail_cleat.png")
const SAIL_PENNANT = preload("res://assets/art_pole_sail/sail_pennant.png")
const STOCK_MOTORS = preload("res://assets/art_consists/stock_motor_bodies.png")
const STOCK_FLATBEDS = preload("res://assets/art_consists/stock_flatbeds.png")
# P5 (GPT, 05.11.2026): the battery locomotive has its own picture; the deck line and the axle line are measured on it
const STOCK_LOCO = preload("res://assets/art_electric/electric_loco_body.png")
# P13 (GPT, 05.11.2026): the pole truck has its own platform (wheels are drawn behind it, the rims are cut from the picture)
const STOCK_POLE = preload("res://assets/art_pole_truck/pole_truck_body.png")
# B6.5: the rail zeppelin (the picture of the other helper, the file is not changed)
const STOCK_JET = preload("res://assets/art_consists/rocket_train_compact_body.png")   # B6.6: the rocket train (the picture of the other helper, the file is not changed)
const STOCK_ZEPPELIN = preload("res://assets/art_zeppelin/body_clean.png")   # the same picture without the movable parts (tools/make_zeppelin_wings.py)
# The exhaust and the parachute of the rocket railcar (P15, painted by GPT): flames of three strengths and the afterburner, two smokes, the open parachute.
const JET_FX = {
	"flame_idle": preload("res://assets/art_jet/flame_idle.png"), "flame_mid": preload("res://assets/art_jet/flame_mid.png"),
	"flame_full": preload("res://assets/art_jet/flame_full.png"), "flame_after": preload("res://assets/art_jet/flame_after.png"),
	"smoke_light": preload("res://assets/art_jet/smoke_light.png"), "smoke_dark": preload("res://assets/art_jet/smoke_dark.png"),
	"chute_open": preload("res://assets/art_jet/chute_open.png"), "chute_slack": preload("res://assets/art_jet/chute_slack.png")}
const JET_MOUTH = Vector2(215, 395)   # the mouth of the nozzle in the picture of the jet body (1774 px wide)
const ZEP_PARTS = {
	"tailplane": {"texture": preload("res://assets/art_zeppelin/tailplane.png"), "rect": Rect2(219, 140, 398, 75), "pivot": Vector2(507, 195)},
	"wing": {"texture": preload("res://assets/art_zeppelin/wing.png"), "rect": Rect2(411, 424, 362, 80), "pivot": Vector2(540, 467)},
	"prop_top": {"texture": preload("res://assets/art_zeppelin/prop_top.png"), "rect": Rect2(174, 123, 43, 273), "pivot": Vector2(196, 447)},
	"prop_bottom": {"texture": preload("res://assets/art_zeppelin/prop_bottom.png"), "rect": Rect2(177, 498, 40, 243), "pivot": Vector2(196, 447)},
}
# Source rectangle, deck line and axle line in each atlas. The deck and the
# running gear remain fixed while the upper body and frame are fitted separately.
const STOCK_BODY = {
	"handcar": [Rect2(50, 207, 802, 168), 210.0, 330.0],
	"zeppelin": [Rect2(0, 0, 1774, 751), 580.0, 712.0],
	"jet": [Rect2(0, 0, 1774, 780), 616.0, 724.0],
	"pole": [Rect2(0, 0, 1497, 304), 48.0, 250.0],   # the new platform: the plank top and the axle line in its own pixels
	"sail": [Rect2(47, 564, 804, 166), 566.0, 686.0],
	"wagon": [Rect2(919, 565, 817, 165), 568.0, 686.0],
	"steam": [Rect2(57, 28, 788, 394), 314.0, 386.0],
	"motorcar": [Rect2(944, 47, 779, 375), 315.0, 386.0],
	"locomotive": [Rect2(0, 0, 1357, 844), 652.0, 783.0],
	"pneumatic": [Rect2(936, 480, 789, 374), 746.0, 816.0],
}
const STOCK_LAMPS = {
	"steam": Vector2(808, 282),
	"motorcar": Vector2(1670, 141),
	"locomotive": Vector2(1291, 245),
	"pneumatic": Vector2(1673, 554),
}
# Bearing centres measured on the stock cab artwork, in atlas pixels.
const STOCK_CAB_AXLES = {
	"steam": Vector2(276, 663),
	"motorcar": Vector2(1158, 1546),
	"locomotive": Vector2(398, 1004),
	"pneumatic": Vector2(1162, 1547),
	"pole": Vector2(437, 1057),
	# the flatbeds: the wheels stand in the axle boxes of the picture that is drawn (the old numbers were measured on another picture)
	"handcar": Vector2(278.4, 625.0),
	"sail": Vector2(277.8, 624.6),
	"wagon": Vector2(1149.3, 1513.9),
}
var manifest: Dictionary
var assets: Dictionary
var textures: Dictionary = {}
var rig: Dictionary
var geometry = Mechanism.new()
# Player skins (tools/skin_check.py, docs/SKINS_RU.md): body.png of a locomotive
# dropped into %APPDATA%/ForestRail/skins/<steam|motorcar|locomotive>/ replaces
# the built-in picture. The picture is fitted to the class's standard platform
# length and the wheels go to the class's standard axle places.
const SKINNED = ["steam", "motorcar", "locomotive"]
var skin_deck: Dictionary = {}
var skin_wheel: Dictionary = {}
var skin_config: Dictionary = {}
var skin_report: Array = []

static func default_skins_dir() -> String:
	var appdata = OS.get_environment("APPDATA")
	return appdata.replace("\\", "/") + "/ForestRail/skins" if appdata != "" else ""

func is_skinned(kind: String) -> bool:
	return skin_deck.has(kind)

# A skinned machine keeps only the live parts that do not depend on where the
# built-in picture has its details; stack_m / lamp_m / overlay in skin.json opt in.
func skin_point(kind: String, key: String, fallback: Vector2) -> Vector2:
	var value = skin_config.get(kind, {}).get(key, null)
	if value is Array and value.size() == 2: return Vector2(float(value[0]), float(value[1]))
	return fallback

func _init(skins_path: String = "") -> void:
	var skins_dir = skins_path
	if skins_dir == "":
		var under_test = false
		for arg in OS.get_cmdline_user_args():
			if str(arg).begins_with("--qa-suite="): under_test = true
		if not under_test: skins_dir = default_skins_dir()
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	assets = manifest.assets
	rig = geometry.config
	for id in assets:
		textures[id] = load(ROOT + assets[id].resource)
	# Replacement bodies are calibrated uniformly by deck length. The origin
	# stays at the axle line; wheel centres and all attachments share it.
	for kind in Geometry.data().bodies:
		var spec = Geometry.body(kind)
		var separate = bool(spec.get("separate_art", false))   # B6.5: the zeppelin has its own picture file
		var id = "vehicles/freight_wagon_body" if kind=="wagon" else BODY[kind]
		# The pneumatic train (tools/make_pneumatic_art.py) has no manifest entry of its own;
		# it takes the steam body's entry as a template for the fields that are overwritten below.
		var meta = assets["vehicles/steam_locomotive_body" if kind == "pneumatic" else ("vehicles/handcar_body" if kind == "pole" or kind == "sail" or kind == "zeppelin" or kind == "jet" else id)].duplicate(true)
		meta.file = spec.file if separate else "../art_p2/"+spec.file
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
		if kind in SKINNED and skins_dir != "": apply_skin(kind, id, skins_dir)
	if skins_dir != "": ensure_skins_folder(skins_dir)
	assets["mechanism/lever"].scale_at_128_px_per_m = float(Geometry.body("handcar").beam_width_m)*128.0/float(assets["mechanism/lever"].region_px[2])
	# Preserve the supplied station art and calibrate by its door, not by
	# arbitrary overall image width.
	for id in Geometry.data().buildings:
		var spec = Geometry.data().buildings[id]
		var metres_per_pixel = float(spec.height_m)/float(assets[id].region_px[3]) if spec.has("height_m") else float(spec.door_height_m)/(float(spec.door_px[3])-float(spec.door_px[1]))
		assets[id].scale_at_128_px_per_m = metres_per_pixel*128.0

func skin_note(kind: String, text: String) -> void:
	skin_report.append("%s: %s" % [kind, text])
	push_warning("skin %s: %s" % [kind, text])

# Loads <dir>/<kind>/body.png (and wheel.png, skin.json) if present. Anything wrong
# is reported and the built-in picture stays.
func apply_skin(kind: String, id: String, skins_dir: String) -> void:
	var folder = skins_dir.path_join(kind)
	var body_path = folder.path_join("body.png")
	if not FileAccess.file_exists(body_path): return
	var image = Image.load_from_file(body_path)
	if image == null or image.is_empty():
		skin_note(kind, "body.png не читается как картинка")
		return
	image.convert(Image.FORMAT_RGBA8)
	var used = image.get_used_rect()
	if used.size.x < 64 or used.size.y < 32:
		skin_note(kind, "в body.png почти нет непрозрачных пикселей")
		return
	var config: Dictionary = {}
	var config_path = folder.path_join("skin.json")
	if FileAccess.file_exists(config_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(config_path))
		if parsed is Dictionary: config = parsed
		else: skin_note(kind, "skin.json не разобран, значения по умолчанию")
	var spec = Geometry.body(kind)
	var length = float(spec.length_m)
	var per_m = float(used.size.x) / length
	var old_region = spec.region_px
	var old_per_m = float(old_region[2]) / length
	var old_center = float(old_region[0]) + float(old_region[2]) * 0.5
	var axle_height = float(spec.wheel_diameter_m) * 0.5
	var bottom_m = clampf(float(config.get("bottom_m", 0.03)), -0.2, 0.6)
	var offset_x = clampf(float(config.get("offset_x_m", 0.0)), -0.5, 0.5)
	var centre_x = float(used.position.x) + float(used.size.x) * 0.5
	var axle_y = float(used.end.y) - (axle_height - bottom_m) * per_m
	var wheel_centres: Array = []
	for point in spec.axles_px:
		var metres = (float(point[0]) - old_center) / old_per_m + offset_x
		wheel_centres.append([centre_x + metres * per_m, axle_y])
	var deck_above_axle = (float(spec.axles_px[0][1]) - float(spec.deck_y_px)) / old_per_m
	var meta = assets[id]
	meta.region_px = [used.position.x, used.position.y, used.size.x, used.size.y]
	meta.pivot_px = [centre_x, axle_y]
	meta.physical_width_m = length
	meta.scale_at_128_px_per_m = length * 128.0 / float(used.size.x)
	meta.wheel_centres_px = wheel_centres
	var atlas = AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	atlas.region = Rect2(used)
	atlas.filter_clip = true
	textures[id] = atlas
	skin_deck[kind] = axle_y - deck_above_axle * per_m
	skin_config[kind] = config
	load_skin_wheel(kind, folder)
	skin_note(kind, "загружен скин (%d×%d px, %.0f px/м)" % [used.size.x, used.size.y, per_m])

func load_skin_wheel(kind: String, folder: String) -> void:
	var path = folder.path_join("wheel.png")
	if not FileAccess.file_exists(path): return
	var image = Image.load_from_file(path)
	if image == null or image.is_empty():
		skin_note(kind, "wheel.png не читается, колесо стандартное")
		return
	image.convert(Image.FORMAT_RGBA8)
	var used = image.get_used_rect()
	if used.size.x < 16 or used.size.y < 16: return
	var id = "skin/%s_wheel" % kind
	var diameter = float(Geometry.body(kind).wheel_diameter_m)
	assets[id] = {"id": id, "region_px": [used.position.x, used.position.y, used.size.x, used.size.y],
		"pivot_px": [used.position.x + used.size.x * 0.5, used.position.y + used.size.y * 0.5],
		"physical_width_m": diameter, "scale_at_128_px_per_m": diameter * 128.0 / float(used.size.x)}
	var atlas = AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	atlas.region = Rect2(used)
	atlas.filter_clip = true
	textures[id] = atlas
	skin_wheel[kind] = id

const SKINS_README = """Лесная колея — скины машин

Положи картинку в папку машины и перезапусти игру. Удалишь файл — вернётся стандартный вид.

  steam/body.png        паровоз          платформа 3.0 м
  motorcar/body.png     бензиновая       платформа 3.6 м
  locomotive/body.png   электровоз       платформа 4.0 м

Правила для body.png (боковой вид, машина смотрит вправо):
  - прозрачный фон (PNG с альфой), без колёс и без сцепок;
  - левый край рисунка — задний буфер, правый — передний: игра растягивает
    рисунок так, чтобы он по ширине равнялся длине платформы;
  - низ рисунка — низ рамы (по умолчанию 3 см над рельсом);
  - оси колёс игра ставит сама на стандартные места, оставь там выемки или
    буксы; колёса рисуются поверх. Свои колёса: wheel.png рядом (круг, без фона).

Необязательный skin.json:
  {"bottom_m": 0.03, "offset_x_m": 0.0, "overlay": false,
   "stack_m": [1.2, 2.3], "lamp_m": [1.6, 1.2]}
  bottom_m    — высота низа рисунка над рельсом;
  offset_x_m  — сдвиг осей вдоль машины (от -0.5 до 0.5);
  overlay     — для паровоза: true оставляет огонь в дверце и стрелку манометра;
  stack_m     — где у трубы начинается дым [x от центра, высота над рельсом];
  lamp_m      — где у бензиновой светит фара.

Проверить картинку заранее: python tools/skin_check.py <папка машины> (в репозитории).
"""

func ensure_skins_folder(skins_dir: String) -> void:
	if DirAccess.make_dir_recursive_absolute(skins_dir) != OK: return
	for kind in SKINNED: DirAccess.make_dir_recursive_absolute(skins_dir.path_join(kind))
	var readme = skins_dir.path_join("README.txt")
	if not FileAccess.file_exists(readme):
		var file = FileAccess.open(readme, FileAccess.WRITE)
		if file != null:
			file.store_string(SKINS_README)
			file.close()

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
	var kind = "wagon" if id.begins_with("W") else id
	if STOCK_CAB_AXLES.has(kind) and not is_skinned(id):
		var axle_x: Vector2 = STOCK_CAB_AXLES[kind]
		var axle_y: float = STOCK_BODY[kind][2]
		return [
			stock_body_point(id, Vector2(axle_x.x, axle_y)),
			stock_body_point(id, Vector2(axle_x.y, axle_y)),
		]
	var meta = assets[body_key(id)]
	var positions: Array = []
	for point in meta.wheel_centres_px:
		positions.append((vec(point) - pivot(body_key(id))) * scale_for(body_key(id)) + Vector2(0, axis_height(id)))
	return positions

func deck_y(id: String) -> float:
	var source_y = float(skin_deck.get(id, Geometry.body(id).deck_y_px))
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

func stock_body_point(id: String, point: Vector2) -> Vector2:
	var kind = "wagon" if id.begins_with("W") else id
	var spec = STOCK_BODY[kind]
	var source: Rect2 = spec[0]
	var deck = deck_y(id)
	var y = remap(point.y, spec[1], spec[2], deck, axis_height(id))
	if point.y < spec[1]:
		var roof = deck - (spec[1] - source.position.y) * body_width(id) / source.size.x
		if STOCK_LAMPS.has(id): roof = body_bounds(id).position.y
		y = remap(point.y, source.position.y, spec[1], roof, deck)
	return Vector2((point.x - source.get_center().x) * body_width(id) / source.size.x, y)

func draw_stock_body(canvas: Node2D, id: String, outer: Transform2D) -> void:
	var kind = "wagon" if id.begins_with("W") else id
	var spec = STOCK_BODY[kind]
	var region: Rect2 = spec[0]
	var seam = Vector2(region.position.x, spec[1])
	var upper = Rect2(region.position, Vector2(region.size.x, seam.y - region.position.y))
	var lower = Rect2(seam, Vector2(region.size.x, region.end.y - seam.y))
	var texture = STOCK_LOCO if id == "locomotive" else (STOCK_POLE if id == "pole" else (STOCK_JET if id == "jet" else (STOCK_ZEPPELIN if id == "zeppelin" else (STOCK_MOTORS if STOCK_LAMPS.has(id) else STOCK_FLATBEDS))))
	canvas.draw_set_transform_matrix(outer)
	for strip in [upper, lower]:
		var start = stock_body_point(id, strip.position)
		var end = stock_body_point(id, strip.end)
		canvas.draw_texture_rect_region(texture, Rect2(start, end - start), strip)

# `outer` is the transform of the body (it may sway on its springs); `rail_outer` is the transform of the running gear: the wheels
# and the rods always stand on the rail (null: the same as the body, as in the depot and in the menu).
func draw_vehicle(canvas: Node2D, id: String, distance: float, facing: int, outer: Transform2D, model, active: bool, pose_override: Dictionary = {}, draw_open_rig: bool = true, rail_outer = null) -> void:
	var run: Transform2D = outer if rail_outer == null else rail_outer
	if id == "pole" and not is_skinned(id): draw_wheels(canvas, id, distance, facing, run, {})   # behind the platform
	if id == "jet" and model != null: draw_jet_exhaust(canvas, outer, model.jet)   # behind the nozzle: the lip of the nozzle overlaps the flame
	if is_skinned(id):
		draw_part(canvas, body_key(id), Vector2(0, axis_height(id)), 0, scale_for(body_key(id)), outer)
	else:
		draw_stock_body(canvas, id, outer)
		if id == "zeppelin" and model != null: draw_zeppelin_parts(canvas, outer, model.zep)
	if id=="locomotive" and is_skinned(id):
		for x in [0.70,1.35]:
			var box=Rect2(Vector2(x-0.26,-1.08)*PX,Vector2(0.52,0.40)*PX)
			var casing=StyleBoxFlat.new()
			casing.bg_color=Color(0.14,0.24,0.20,0.62);casing.border_color=Color("a39a6c");casing.set_border_width_all(1);casing.set_corner_radius_all(2)
			canvas.draw_style_box(casing,box)
			canvas.draw_line(box.position+Vector2(5,7),box.position+Vector2(5,box.size.y-5),Color("728b78"),1,true)
		var bolt=PackedVector2Array([Vector2(0.05,-0.77),Vector2(-0.06,-0.61),Vector2(0.03,-0.61),Vector2(-0.02,-0.47),Vector2(0.13,-0.66),Vector2(0.04,-0.66)])
		for i in range(bolt.size()): bolt[i]=(bolt[i]+Vector2(1.02,-0.28))*PX
		canvas.draw_colored_polygon(bolt,Color("ddc37b"))
	var p = mechanism_pose(model) if id=="handcar" and pose_override.is_empty() else pose_override
	if id=="steam": draw_steam_overlay(canvas, model)
	if id=="pneumatic": draw_pneumatic_overlay(canvas, model)
	if draw_open_rig and id=="pole": draw_pole_overlay(canvas, model)
	if draw_open_rig and id=="sail": draw_sail_overlay(canvas, model)
	if id=="motorcar": draw_petrol_overlay(canvas, model)
	if id != "zeppelin" and id != "jet" and not (id == "pole" and not is_skinned(id)): draw_wheels(canvas, id, distance, facing, run, p)   # the zeppelin has no visible wheels
	if id == "steam" or id == "pneumatic": draw_steam_motion(canvas, distance, facing, run, id)
	if id == "motorcar": draw_side_rod(canvas, id, distance, facing, run)
	if id == "handcar": draw_mechanism(canvas, model, outer,p)
	if id == "jet" and model != null: draw_jet_chutes(canvas, outer, model)

# The movable parts of the zeppelin (B6.5): the tail plane and the wing turn about their pivots, the propeller blades are drawn
# as they foreshorten with the turn, and above some revs a soft disc replaces them.
func zeppelin_part_draw(canvas: Node2D, outer: Transform2D, name: String, angle: float, scale_y: float = 1.0, alpha: float = 1.0) -> void:
	var part = ZEP_PARTS[name]
	var rect: Rect2 = part.rect
	var pivot: Vector2 = part.pivot
	var s = body_width("zeppelin") / 1774.0
	var origin = stock_body_point("zeppelin", pivot)
	canvas.draw_set_transform_matrix(outer * Transform2D(angle, origin) * Transform2D(Vector2(1.0, 0.0), Vector2(0.0, scale_y), Vector2.ZERO))
	canvas.draw_texture_rect(part.texture, Rect2((rect.position - pivot) * s, rect.size * s), false, Color(1, 1, 1, alpha))
	canvas.draw_set_transform_matrix(outer)

# The flame and the smoke of the rocket: from the mouth of the nozzle to the left (the train runs to the right). The strength of the flame follows the thrust,
# the afterburner has its own long blue-white flame; the length flickers a little.
func draw_jet_exhaust(canvas: Node2D, outer: Transform2D, jet) -> void:
	var afterburner = jet.afterburner_time > 0.0
	if not jet.started and not afterburner and jet.thrust < 50.0: return
	var s = body_width("jet") / 1774.0
	var mouth = stock_body_point("jet", JET_MOUTH)
	var frac = clampf(jet.thrust / maxf(1.0, float(jet.c("thrust_max_n"))), 0.0, 1.0)
	var flicker = 1.0 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.05) + 0.03 * sin(float(Time.get_ticks_msec()) * 0.13)
	canvas.draw_set_transform_matrix(outer)
	if frac > 0.22 or afterburner:
		# the smoke trails behind the flame
		var dark = frac > 0.65 or afterburner
		var smoke: Texture2D = JET_FX["smoke_dark" if dark else "smoke_light"]
		var sw = (900.0 if dark else 600.0) * s * flicker
		var sh = sw * float(smoke.get_height()) / float(smoke.get_width()) * 1.1
		var flame_len = (1500.0 if afterburner else (900.0 if frac > 0.55 else 500.0)) * s
		canvas.draw_texture_rect(smoke, Rect2(mouth + Vector2(-flame_len * 0.55 - sw, -sh * 0.5), Vector2(sw, sh)), false, Color(1, 1, 1, clampf(0.35 + frac * 0.5, 0.0, 0.85)))
	var name = "flame_idle"
	var length = 260.0
	if afterburner:
		name = "flame_after"
		length = 1500.0
	elif frac > 0.55:
		name = "flame_full"
		length = 900.0
	elif frac > 0.2:
		name = "flame_mid"
		length = 500.0
	var tex: Texture2D = JET_FX[name]
	var w = length * s * flicker
	var h = w * float(tex.get_height()) / float(tex.get_width()) * 1.25
	canvas.draw_texture_rect(tex, Rect2(mouth + Vector2(-w, -h * 0.5), Vector2(w, h)), false)

# The braking parachute behind the whole train: the ring on the rear coupler, the canopy streams to the left; it opens with jet.chute (0..1).
func draw_jet_chutes(canvas: Node2D, outer: Transform2D, model) -> void:
	var jet = model.jet
	if jet.chute < 0.02 or jet.chutes_open <= 0: return
	var ids = model.body_ids()
	if ids.is_empty(): return
	var rear = Geometry.offset(ids, ids.size() - 1) + Geometry.length(ids[ids.size() - 1]) * 0.5 + float(Geometry.data().coupler.end_extension_m)
	var ring = Vector2(-rear * PX, -float(Geometry.data().coupler.height_m) * PX)
	canvas.draw_set_transform_matrix(outer)
	for k in range(int(jet.chutes_open)):
		var tex: Texture2D = JET_FX["chute_open" if jet.chute > 0.8 else "chute_slack"]
		var total = 6.5 * PX * clampf(jet.chute, 0.0, 1.0) * (1.0 - 0.12 * float(k))
		var h = total * float(tex.get_height()) / float(tex.get_width())
		var shift = Vector2(-0.9 * PX * float(k), 0.55 * PX * float(k))
		canvas.draw_texture_rect(tex, Rect2(ring + shift + Vector2(-total, -h * 0.56), Vector2(total, h)), false, Color(1, 1, 1, clampf(jet.chute * 1.5, 0.0, 1.0)))

func draw_zeppelin_parts(canvas: Node2D, outer: Transform2D, zep) -> void:
	var shake = sin(zep.prop_phase * 7.0) * deg_to_rad(clampf(absf(zep.v) / 37.0, 0.0, 1.0) * 0.8)   # the surfaces flutter at speed
	zeppelin_part_draw(canvas, outer, "tailplane", deg_to_rad(zep.tail_angle) + shake * 0.6)
	zeppelin_part_draw(canvas, outer, "wing", deg_to_rad(zep.wing_angle) - shake)
	var blur = clampf((zep.rpm - 500.0) / 1400.0, 0.0, 1.0)
	var turn = cos(zep.prop_phase)
	var pivot = stock_body_point("zeppelin", ZEP_PARTS.prop_top.pivot)
	var s = body_width("zeppelin") / 1774.0
	if blur > 0.02:
		var disc = PackedVector2Array()
		for i in range(24):
			var a = TAU * i / 24.0
			disc.append(pivot + Vector2(cos(a) * 7.0 * s, sin(a) * 292.0 * s))
		canvas.draw_set_transform_matrix(outer)
		canvas.draw_colored_polygon(disc, Color(0.82, 0.85, 0.88, 0.24 * blur))
	var blade_alpha = 1.0 - 0.65 * blur
	zeppelin_part_draw(canvas, outer, "prop_top", 0.0, turn, blade_alpha)
	zeppelin_part_draw(canvas, outer, "prop_bottom", 0.0, turn, blade_alpha)

func draw_wheels(canvas: Node2D, id: String, distance: float, facing: int, run: Transform2D, p: Dictionary) -> void:
	var wheel_id = skin_wheel.get(id, "vehicles/wheel_large" if id in LARGE_WHEELS else "vehicles/wheel_small")
	var radius = -axis_height(id)
	for position in wheel_positions(id):
		var wheel_angle = fposmod(p.wheel_angle,TAU) if id=="handcar" else fposmod(distance*PX/radius*facing,TAU)
		if PAINTED_WHEEL_TREAD.has(wheel_id):
			var meta = assets[wheel_id]
			var region = meta.region_px
			var tread: Vector2 = PAINTED_WHEEL_TREAD[wheel_id]
			var fit = Vector2(2.0 * radius, 2.0 * radius) / tread
			var centre = pivot(wheel_id) - Vector2(region[0], region[1])
			canvas.draw_set_transform_matrix(run * Transform2D(wheel_angle, position))
			canvas.draw_texture_rect(textures[wheel_id], Rect2(-centre * fit, Vector2(region[2], region[3]) * fit), false, STOCK_WHEEL_TINT.get(id, Color.WHITE))
			canvas.draw_set_transform_matrix(run)
		else:
			draw_part(canvas, wheel_id, position, wheel_angle, scale_for(wheel_id), run)

func headlamp_point(id: String) -> Vector2:
	if STOCK_LAMPS.has(id) and not is_skinned(id): return stock_body_point(id, STOCK_LAMPS[id])
	if id == "motorcar":
		var lamp = skin_point(id, "lamp_m", Vector2(1.58, 1.40))
		return petrol_point(lamp.x, lamp.y)
	if id in ["steam", "pneumatic"]:
		var fallback = Vector2(1.43, 0.60 if id == "steam" else 1.57)
		var lamp = skin_point(id, "lamp_m", fallback)
		return steam_point(lamp.x, lamp.y)
	return Vector2(body_width(id) * 0.43, deck_y(id) - (0.45 if id == "locomotive" else 0.13) * PX)

func draw_added_headlamp(canvas: Node2D, id: String) -> void:
	if id in ["motorcar", "steam", "pneumatic"]: return
	if id == "locomotive" and not is_skinned(id): return
	var at = headlamp_point(id)
	canvas.draw_line(at + Vector2(0, 4), at + Vector2(0, 0.15 * PX), Color("443e30"), 4.0, true)
	canvas.draw_circle(at, 0.078 * PX, Color("383a32"))
	canvas.draw_circle(at, 0.054 * PX, Color("a78449"))
	canvas.draw_circle(at + Vector2(1, -1), 0.031 * PX, Color("e9d396"))

# A picture placed by its pivot (P2): the pivot point of the picture (in its own pixels) lands on pos, the picture is turned
# by angle and scaled; with upright the picture whose top would face down is flipped, so the light stays on top everywhere.
func draw_sprite_at(canvas: Node2D, tex: Texture2D, pivot: Vector2, pos: Vector2, angle: float, scale: Vector2, upright: bool = true) -> void:
	var size = Vector2(tex.get_width(), tex.get_height())
	var sc = scale
	if upright and Vector2(0, -1).rotated(angle).y > 0.0: sc.y = -sc.y
	var pts = PackedVector2Array()
	for corner in [Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]:
		pts.append(pos + ((corner - pivot) * sc).rotated(angle))
	var white = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	canvas.draw_polygon(pts, white, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)

# A long part drawn between two points: its left edge on from, its right edge on to, the given thickness.
func draw_part_between(canvas: Node2D, tex: Texture2D, from: Vector2, to: Vector2, thickness: float, upright: bool = true) -> void:
	var d = to - from
	if d.length() < 0.5: return
	draw_sprite_at(canvas, tex, Vector2(0, tex.get_height() * 0.5), from, d.angle(), Vector2(d.length() / tex.get_width(), thickness / tex.get_height()), upright)

func draw_worker_body(canvas: Node2D, feet: Vector2, height: float) -> void:
	var width = height * WORKER_REGION.size.x / WORKER_REGION.size.y
	var target = Rect2(feet - Vector2(width * 0.5, height), Vector2(width, height))
	canvas.draw_texture_rect_region(WORKER_TEXTURE, target, WORKER_REGION)

# The arm of the person: the upper arm and the forearm in the sleeve, the fist on the hand point. The elbow bends down.
func draw_worker_arm(canvas: Node2D, feet: Vector2, height: float, hand: Vector2, relaxed: bool = false, shoulder_at: Vector2 = Vector2.INF, rest_at: Vector2 = Vector2.INF) -> void:
	var width = height * WORKER_REGION.size.x / WORKER_REGION.size.y
	var sh = height / (1.75 * PX)
	var shoulder = feet + Vector2(width * 0.08, -height * 0.73)
	if shoulder_at.is_finite(): shoulder = shoulder_at
	# nothing to hold (the sheet is made fast): the arm hangs down (or rests on the knee), the hand relaxed
	if relaxed: hand = rest_at if rest_at.is_finite() else shoulder + Vector2(0.04 * PX * sh, 0.52 * PX * sh)
	var l1 = 0.30 * PX * sh
	var l2 = 0.29 * PX * sh
	var hand_back = 0.074 * PX * sh      # from the wrist to the middle of the fist
	var reach = shoulder.distance_to(hand)
	if reach > (l1 + l2) * 0.97:
		var k = reach / ((l1 + l2) * 0.97)
		l1 *= k
		l2 *= k
	var dir = (hand - shoulder).normalized()
	var d = maxf(0.05 * PX, reach)
	var a = (d * d + l1 * l1 - l2 * l2) / (2.0 * d)
	var bend = sqrt(maxf(0.0, l1 * l1 - a * a))
	var normal = Vector2(-dir.y, dir.x)
	if normal.y < 0.0: normal = -normal
	var elbow = shoulder + dir * a + normal * bend
	var wrist = hand - (hand - elbow).normalized() * hand_back
	draw_part_between(canvas, ARM_UPPER, shoulder, elbow, 0.115 * PX * sh)
	draw_part_between(canvas, ARM_FORE, elbow, wrist, 0.10 * PX * sh)
	if relaxed:
		var open_scale = 0.12 * PX * sh / float(HAND_OPEN.get_width())
		draw_sprite_at(canvas, HAND_OPEN, HAND_OPEN_PIVOT, wrist, (hand - wrist).angle() - HAND_OPEN_TURN, Vector2(open_scale, open_scale), false)
		return
	var turn = (hand - wrist).angle() - HAND_TURN
	var s = 0.14 * PX * sh / float(HAND_GRIP.get_width())
	draw_sprite_at(canvas, HAND_GRIP, HAND_PIVOT, wrist, turn, Vector2(s, s), false)

# The sailor of the sailing trolley sits on a crate at the stern (P2b): the picture, then the arm from his shoulder.
# base is the middle of the crate's foot on the deck; hand is where the held sheet is; made fast, the hand rests on the knee.
func draw_sailor_seated(canvas: Node2D, base: Vector2, hand: Vector2, relaxed: bool) -> void:
	var size = Vector2(SAILOR.get_width(), SAILOR.get_height())
	var sc = SAILOR_HEIGHT_M * PX / size.y
	draw_sprite_at(canvas, SAILOR, size * SAILOR_PIVOT_F, base, 0.0, Vector2(sc, sc), false)
	var shoulder = base + size * (SAILOR_SHOULDER_F - SAILOR_PIVOT_F) * sc
	var knee = base + size * (SAILOR_KNEE_F - SAILOR_PIVOT_F) * sc
	draw_worker_arm(canvas, base, 1.65 * PX, hand, relaxed, shoulder, knee)

# The rower on his crate at the stern: the pose follows the stroke (reaching forward, pulling, coming back); fwd mirrors him with the direction of travel.
func draw_rower(canvas: Node2D, base: Vector2, swing: float, fwd: float) -> void:
	var pose = "catch" if swing > 0.35 else ("drive" if swing < -0.35 else "recovery")
	var sc = ROWER_M_PER_PX * PX
	draw_sprite_at(canvas, ROWER[pose], ROWER_PIVOT, base, 0.0, Vector2(sc * fwd, sc), false)

# One oar on the near side: the oarlock on the edge of the platform, the oar swings about it with the stroke (the blade goes forward and down on the catch).
func draw_oar(canvas: Node2D, lock: Vector2, swing: float, fwd: float) -> void:
	var lock_sc = 0.30 * PX / float(OARLOCK.get_height())
	draw_sprite_at(canvas, OARLOCK, Vector2(OARLOCK.get_width() * 0.5, OARLOCK.get_height()), lock + Vector2(0, 0.04 * PX), 0.0, Vector2(lock_sc, lock_sc), false)
	var sc = 2.1 * PX / float(OAR.get_width())
	var angle = (0.10 + swing * 0.42) * fwd
	draw_sprite_at(canvas, OAR, Vector2(OAR.get_width() * 0.36, OAR.get_height() * 0.5), lock + Vector2(0, -0.20 * PX), angle, Vector2(sc * fwd, sc), false)

func draw_worker(canvas: Node2D, feet: Vector2, height: float, hand: Vector2, relaxed: bool = false) -> void:
	draw_worker_body(canvas, feet, height)
	draw_worker_arm(canvas, feet, height, hand, relaxed)

# Petrol locomotive live parts: headlamp glow and exhaust smoke (positions in
# metres above the rail, axle at 0.21 m), plus a side rod between the wheels.
func petrol_point(x: float, rail_y: float) -> Vector2:
	return Vector2(x, -(rail_y - 0.21)) * PX

func draw_petrol_overlay(canvas: Node2D, model) -> void:
	if model == null or model.state.is_empty() or not model.state.get("engine", false): return
	var t = Time.get_ticks_msec() / 1000.0
	var load = clampf(float(model.state.get("throttle", 0)), 0.0, 1.0)
	var lamp = headlamp_point("motorcar")
	for i in range(5 if (not is_skinned("motorcar") or skin_config.get("motorcar", {}).has("lamp_m")) else 0):
		canvas.draw_circle(lamp, (0.13 + 0.07 * i) * PX, Color(1.0, 0.85, 0.45, 0.11 - 0.018 * i))
	var drift = smoke_drift(model) * 0.65
	for i in range(5):
		var age = fposmod(t * (0.8 + 0.6 * load) + i / 5.0, 1.0)
		var origin = skin_point("motorcar", "stack_m", Vector2(0.701, 1.97))
		var stack = petrol_point(origin.x, origin.y) if is_skinned("motorcar") else stock_body_point("motorcar", Vector2(1324, 155))
		var puff = stack + Vector2(age * drift, -age * smoke_rise(drift) * 0.8) * PX
		canvas.draw_circle(puff, (0.05 + age * 0.16) * PX, Color(0.82, 0.82, 0.8, (0.25 + 0.35 * load) * (1.0 - age)))

func draw_side_rod(canvas: Node2D, id: String, distance: float, facing: int, outer: Transform2D) -> void:
	var radius = PX * float(Geometry.body(id).wheel_diameter_m) * 0.5
	var angle = fposmod(distance * PX / radius * facing, TAU)
	var positions = wheel_positions(id)
	var pins: Array = []
	for position in positions: pins.append(position + Vector2(0, -radius * 0.55).rotated(angle))
	canvas.draw_set_transform_matrix(outer)
	canvas.draw_line(pins[0], pins[1], Color("56635f"), 0.04 * PX, true)
	canvas.draw_line(pins[0], pins[1], Color("8a9a94"), 0.01 * PX, true)
	for pin in pins:
		canvas.draw_circle(pin, 0.035 * PX, Color("c9af73"))
		canvas.draw_circle(pin, 0.015 * PX, Color("6f5d33"))

# B6.3: the smoke is carried by the air that moves over the train: the wind along the way minus the speed of the train.
# The value is the metres a puff drifts along the machine (+ toward the front) during its life; a calm standing train
# lets the smoke rise straight, a fast one lays it back, a head wind blows it over the roof.
func smoke_drift(model) -> float:
	if model == null or model.state.is_empty() or model.route == null: return -1.4
	var along = model.wind_here().x - float(model.state.get("v", 0.0))
	return clampf(along * 0.42, -3.4, 3.4)

func smoke_rise(drift: float) -> float:
	return 0.78 - 0.07 * minf(absf(drift), 3.0)   # the smoke blown flat rises a little less

# Live parts of the steam engine on top of the painted body
# (tools/make_steam_art.py): firebox glow, manometer needle, safety valve and
# chimney smoke. Positions are metres above the rail, converted to body pixels.
func steam_point(x: float, rail_y: float) -> Vector2:
	return Vector2(x, -(rail_y - 0.275)) * PX

func draw_steam_overlay(canvas: Node2D, model) -> void:
	if model == null or model.state.is_empty() or not model.state.fleet_by_id.has("steam"): return
	var boiler = model.state.fleet_by_id.steam
	var plain = not is_skinned("steam") or bool(skin_config.get("steam", {}).get("overlay", false))
	var heat = float(boiler.get("heat", 0.0))
	var door_open = bool(boiler.get("door", false))
	var door = Rect2(steam_point(-0.554, 0.96), Vector2(0.19, 0.28) * PX)
	if plain and heat > 0.02:
		canvas.draw_rect(door.grow(-3), Color(1.0, 0.5, 0.12, (0.95 if door_open else 0.55) * heat))
		if door_open:
			canvas.draw_rect(Rect2(steam_point(-0.62, 0.66), Vector2(0.26, 0.035) * PX), Color(1.0, 0.62, 0.22, 0.55 * heat))
	if plain and door_open: canvas.draw_rect(door, Color("f1d890"), false, 2.0)
	var center = steam_point(-0.568, 1.86)
	if not is_skinned("steam"): center = stock_body_point("steam", Vector2(365, 160))
	var needle = deg_to_rad(150.0) + deg_to_rad(240.0) * float(boiler.get("pressure", 0.0))
	if plain:
		if not is_skinned("steam"):
			canvas.draw_circle(center, 9.0, Color("9f834c"))
			canvas.draw_circle(center, 7.5, Color("dfd3ad"))
		canvas.draw_line(center, center + Vector2.from_angle(needle) * 0.075 * PX, Color("a8231c"), 2.0, true)
		canvas.draw_circle(center, 2.0, Color("2a2a2a"))
	var t = Time.get_ticks_msec() / 1000.0
	if plain and bool(boiler.get("venting", false)):
		for i in range(4):
			var age = fposmod(t * 1.6 + i / 4.0, 1.0)
			canvas.draw_circle(steam_point(-0.106 + age * 0.12, 2.0 + age * 0.55), (0.04 + age * 0.12) * PX, Color(1, 1, 1, 0.5 * (1.0 - age)))
	if not model.state.get("engine", false): return
	# Smoke thickens with the regulator and trails backwards.
	var throttle = float(model.state.get("throttle", 0))
	var origin = skin_point("steam", "stack_m", Vector2(1.168, 2.30))
	var stack = steam_point(origin.x, origin.y) if is_skinned("steam") else stock_body_point("steam", Vector2(706, 34))
	var drift = smoke_drift(model)
	for i in range(6):
		var age = fposmod(t * 0.9 + i / 6.0, 1.0)
		var puff = stack + Vector2(age * drift, -age * smoke_rise(drift)) * PX
		canvas.draw_circle(puff, (0.10 + age * 0.22) * PX, Color(0.86, 0.86, 0.82, (0.35 + 0.35 * throttle) * (1.0 - age)))
	var travelled = float(model.state.stats.distance)
	var cycle = fposmod(travelled, 85.0)
	if travelled < 85.0 or absf(float(model.state.v)) < 1.0 or cycle >= 4.0: return
	var age = cycle / 4.0
	var cloud = stack + Vector2(-0.28 - age * 1.3, -0.25 - age * 0.85) * PX
	var radius = lerpf(0.10, 0.27, age) * PX
	var ring = PackedVector2Array()
	for i in range(49):
		var phase = float(i) * TAU / 48.0
		ring.append(cloud + Vector2(sin(phase) * 1.65, sin(phase * 2.0) * 0.75) * radius)
	var alpha = smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.40, 1.0, age))
	canvas.draw_polyline(ring, Color(0.70, 0.75, 0.72, alpha * 0.28), radius * 0.34, true)
	canvas.draw_polyline(ring, Color(0.90, 0.91, 0.85, alpha * 0.82), radius * 0.17, true)

# The sail car's mast, rigging, sail and sailor, drawn live over the painted platform
# (tools/make_sail_art.py). The mast stands at the front end in the direction of travel, the boom runs
# back from it; the wider the sail is open the shorter the boom looks from the side. The cloth bellies
# with the wind and ripples along its trailing edge when the trim does not suit the wind.
var sail_cloth: Dictionary = {}   # the state of the free cloth of the sail (points, velocities, time)
var reduce_motion_flag = false    # set by the game from the setting «без тряски и мерцания»: the ribbons and the cloth flutter less
const SAIL_MAST_X = 0.5
const SAIL_BOOM = 1.6
const SAIL_FOOT_Y = 1.25
const SAIL_TOP_Y = 3.7
func sail_point(x: float, y: float) -> Vector2:
	return Vector2(x, -(y - 0.21)) * PX

func sail_geometry(model) -> Dictionary:
	var fwd = float(int(model.state.direction)) if not model.state.is_empty() else 1.0
	var time = Time.get_ticks_msec() / 1000.0
	# a sail that nobody holds flogs: the boom swings about on its own
	var trim = float(model.sail_trim) if model.sail_engaged() else 0.5 + 0.42 * sin(time * 5.7) * sin(time * 2.3)
	var boom = SAIL_BOOM * cos(trim * PI * 0.5) * (1.25 if float(model.effects("sail").get("sail_spinnaker", 0)) > 0.0 else 1.0)
	var lift = float(model.sail_lift) if model.sail_engaged() else 0.22 * sin(time * 4.1) * sin(time * 1.7)
	return {"fwd": fwd, "mast_x": SAIL_MAST_X * fwd, "boom_end_x": (SAIL_MAST_X * fwd) - fwd * boom, "foot_y": SAIL_FOOT_Y, "top_y": SAIL_TOP_Y, "boom": boom, "lift": lift}

func draw_sail_overlay(canvas: Node2D, model) -> void:
	if model == null or model.state.is_empty(): return
	var g = sail_geometry(model)
	var fwd = float(g.fwd)
	var t = Time.get_ticks_msec() / 1000.0
	var info: Dictionary = model.sail_info
	var quality = float(info.quality) if not info.is_empty() else 1.0
	var pull = clampf(float(info.force) / 220.0, -0.3, 1.0) if not info.is_empty() else 0.0
	if not model.sail_engaged():
		quality = 0.1
		pull = 0.0
	var ripple = (1.0 - quality) * 0.16 + 0.015
	var mast_x = float(g.mast_x)
	var wood = Color("7a5530")
	var wood_light = Color("a67c46")
	var mast_top = sail_point(mast_x, g.top_y)
	# rigging first, behind the cloth: forestay to the bow, backstay to the stern
	canvas.draw_line(mast_top, sail_point(1.15 * fwd, 0.62), Color(0.2, 0.15, 0.1, 0.9), 0.012 * PX, true)
	canvas.draw_line(mast_top, sail_point(-1.15 * fwd, 0.62), Color(0.2, 0.15, 0.1, 0.9), 0.012 * PX, true)
	# the mast, tapering, with brass bands
	canvas.draw_line(sail_point(mast_x, 0.8), sail_point(mast_x, 2.6), wood, 0.085 * PX, true)
	canvas.draw_line(sail_point(mast_x, 2.6), mast_top, wood, 0.055 * PX, true)
	canvas.draw_line(sail_point(mast_x - 0.02 * fwd, 0.8), sail_point(mast_x - 0.02 * fwd, 3.6), wood_light, 0.014 * PX, true)
	for band in [1.05, 1.9, 2.8, 3.55]:
		canvas.draw_line(sail_point(mast_x - 0.05, band), sail_point(mast_x + 0.05, band), Color("c9a24e"), 0.03 * PX, true)
	# the boom from the gooseneck
	var boom_end = sail_point(float(g.boom_end_x), g.foot_y + float(g.lift))
	canvas.draw_line(sail_point(mast_x, g.foot_y), boom_end, wood, 0.06 * PX, true)
	canvas.draw_line(sail_point(mast_x, g.foot_y + 0.01), boom_end + Vector2(0, -0.01 * PX), wood_light, 0.014 * PX, true)
	canvas.draw_circle(sail_point(mast_x, g.foot_y), 0.04 * PX, Color("c9a24e"))
	# the cloth: a grid of free points, fixed along the mast and along the boom, loose elsewhere. The wind shakes it,
	# the neighbours pass the wave on, the tension of a good trim stiffens it, a flogging sail flaps (B6.4, free cloth)
	var width = float(g.boom)
	if width > 0.05:
		var rows = 14
		var cols = 6
		var strain = float(info.get("strain", 0.0)) if not info.is_empty() else 0.0
		var apparent = float(info.get("apparent", 0.0)) if not info.is_empty() else 0.0
		var luff = PackedVector2Array()
		var rest_leech = PackedVector2Array()
		for i in range(rows + 1):
			var u = float(i) / float(rows)
			var y = lerpf(g.foot_y, g.top_y, u)
			var extent = width * pow(1.0 - u, 0.85) * (1.0 + 0.06 * sin(PI * u))
			luff.append(sail_point(mast_x, y))
			# the free corner drags the leech with it: held high, the whole trailing edge rises, less toward the top
			rest_leech.append(sail_point(mast_x - fwd * maxf(extent, 0.03 * width), y + float(g.lift) * (1.0 - u)))
		var count = (rows + 1) * (cols + 1)
		if int(sail_cloth.get("n", -1)) != count:
			sail_cloth = {"n": count, "d": PackedVector2Array(), "v": PackedVector2Array(), "t": t}
			sail_cloth.d.resize(count)
			sail_cloth.v.resize(count)
		var dt = clampf(t - float(sail_cloth.t), 0.0, 0.05)
		sail_cloth.t = t
		var wind_k = clampf(apparent / 8.0, 0.15, 1.6)
		var tight = clampf(quality * (0.35 + 0.65 * clampf(pull + 0.3, 0.0, 1.0)), 0.0, 1.0) if model.sail_engaged() else 0.0
		var stiff = lerpf(5.0, 75.0, tight)
		var damp = lerpf(1.3, 5.5, tight)
		var amp = (0.03 + 0.45 * (1.0 - tight)) * (1.0 + 2.0 * strain) * wind_k * PX
		var d: PackedVector2Array = sail_cloth.d
		var v: PackedVector2Array = sail_cloth.v
		for step in range(2):
			var h = dt * 0.5
			if h <= 0.0: break
			var accel = PackedVector2Array()
			accel.resize(count)
			for i in range(1, rows + 1):
				for c in range(1, cols + 1):
					var idx = i * (cols + 1) + c
					var u = float(i) / float(rows)
					var f = float(c) / float(cols)
					# a taut sail holds a belly (the leech curves aft); a loose one has none
					var belly = Vector2(-fwd * 0.1 * clampf(pull, 0.0, 1.0) * sin(PI * u) * sin(PI * f * 0.5) * width * PX, 0.0)
					var force = Vector2(sin(t * 7.3 + float(i) * 0.9 - float(c) * 0.6) + 0.6 * sin(t * 11.7 + float(i) * 0.4 + float(c) * 1.3), 0.5 * sin(t * 9.1 + float(i) * 0.5 + float(c) * 0.9)) * amp * (0.35 + 0.65 * u) * f
					var near = (d[idx - 1] + d[idx + (1 if c < cols else 0)] + d[idx - (cols + 1)] + d[idx + ((cols + 1) if i < rows else 0)]) * 0.25
					accel[idx] = -stiff * (d[idx] - belly) - damp * v[idx] + 24.0 * (near - d[idx]) + force * (stiff + 12.0)
			for i in range(1, rows + 1):
				for c in range(1, cols + 1):
					var idx = i * (cols + 1) + c
					v[idx] += accel[idx] * h
					d[idx] += v[idx] * h
					# never wander farther than a third of the sail's width
					if d[idx].length() > 0.45 * width * PX: d[idx] = d[idx].normalized() * 0.45 * width * PX
		sail_cloth.d = d
		sail_cloth.v = v
		var grid = PackedVector2Array()
		grid.resize(count)
		for i in range(rows + 1):
			for c in range(cols + 1):
				var idx = i * (cols + 1) + c
				var p = luff[i].lerp(rest_leech[i], float(c) / float(cols)) + d[idx]
				# the cloth never crosses the mast, or it would fold over itself
				if (p.x - luff[i].x) * (-fwd) < 0.02 * width * PX: p.x = luff[i].x - fwd * 0.02 * width * PX
				grid[idx] = p
		# the picture of the sailcloth is stretched over the same grid: the seams run along the rows, the grommets sit at the mast
		var far_tone = 0.9 if model.sail_side > 0 else 1.0
		for k in range(cols):
			var f0 = float(k) / float(cols)
			var f1 = float(k + 1) / float(cols)
			var shade = 0.88 + 0.12 * sin(PI * (f0 + f1) * 0.5) * (0.4 + 0.6 * clampf(pull + 0.4, 0.0, 1.0))
			var tint = Color(shade * far_tone, shade * far_tone, shade * far_tone, 0.98)
			var tints = PackedColorArray([tint, tint, tint])
			for i in range(rows):
				var q = PackedVector2Array([grid[i * (cols + 1) + k], grid[i * (cols + 1) + k + 1], grid[(i + 1) * (cols + 1) + k + 1], grid[(i + 1) * (cols + 1) + k]])
				var v0 = 1.0 - float(i) / float(rows)
				var v1 = 1.0 - float(i + 1) / float(rows)
				var uv = PackedVector2Array([Vector2(f0, v0), Vector2(f1, v0), Vector2(f1, v1), Vector2(f0, v1)])
				# two triangles per patch: a free cloth can fold, and a folded quad cannot be filled, a triangle always can
				if absf((q[1] - q[0]).cross(q[2] - q[0])) > 0.5: canvas.draw_polygon(PackedVector2Array([q[0], q[1], q[2]]), tints, PackedVector2Array([uv[0], uv[1], uv[2]]), SAIL_CLOTH)
				if absf((q[2] - q[0]).cross(q[3] - q[0])) > 0.5: canvas.draw_polygon(PackedVector2Array([q[0], q[2], q[3]]), tints, PackedVector2Array([uv[0], uv[2], uv[3]]), SAIL_CLOTH)
		# B6.4: telltale ribbons (red on the near side, green on the far side) sewn to the cloth near the mast: in a good trim they
		# stream straight aft, when the sail luffs or stalls they curl and flutter. The sailor reads the trim from them.
		var calm_motion = 0.3 if reduce_motion_flag else 1.0
		for r_index in range(3):
			var row = [3, 7, 11][r_index]
			var base = grid[row * (cols + 1) + 2]
			for side_index in range(2):
				var ribbon = PackedVector2Array()
				var ribbon_len = 0.28 * PX
				var stall = clampf(1.0 - quality, 0.0, 1.0) if model.sail_engaged() else 0.9
				for seg in range(7):
					var u = float(seg) / 6.0
					var wave = sin(t * (9.0 + 4.0 * float(side_index)) + float(r_index) * 1.7 - u * 6.0) * (0.015 + 0.10 * stall) * PX * u * calm_motion
					var curl = stall * 0.35 * PX * u * u * (1.0 if side_index == 0 else -1.0) * calm_motion
					ribbon.append(base + Vector2(-fwd * u * ribbon_len * (1.0 - 0.35 * stall), wave + curl + float(side_index) * 0.012 * PX))
				canvas.draw_polyline(ribbon, Color("c4382b") if side_index == 0 else Color("3f8f52"), maxf(1.5, 0.014 * PX), true)
		var leech_line = PackedVector2Array()
		for i in range(rows + 1): leech_line.append(grid[i * (cols + 1) + cols])
		canvas.draw_polyline(leech_line, Color(0.45, 0.38, 0.28), 1.6, true)
		canvas.draw_line(luff[0], grid[cols], Color(0.45, 0.38, 0.28), 1.6, true)
	else:
		canvas.draw_line(sail_point(mast_x, g.foot_y), sail_point(mast_x, g.top_y), Color(0.93, 0.89, 0.8), 0.035 * PX, true)
	# the sheet from the boom end down to the sailor's hand, with a sag
	var cleat_point = sail_point(-0.14 * fwd, 0.66)
	var sailor_hand = cleat_point if model.sail_cleated else sail_point(-0.46 * fwd, 1.22)
	# the cleat: a wooden horn on the deck, where the sheet is made fast (P2 picture)
	draw_sprite_at(canvas, SAIL_CLEAT, Vector2(SAIL_CLEAT.get_width() * 0.5, SAIL_CLEAT.get_height()), cleat_point, 0.0, Vector2.ONE * (0.2 * PX / float(SAIL_CLEAT.get_width())), false)
	var sag = sail_point((float(g.boom_end_x) - 0.78 * fwd) * 0.5, 0.95)
	var sheet = PackedVector2Array()
	for k in range(13):
		var u = float(k) / 12.0
		sheet.append(boom_end * pow(1.0 - u, 2.0) + sag * 2.0 * u * (1.0 - u) + sailor_hand * u * u)
	canvas.draw_polyline(sheet, Color(0.45, 0.34, 0.2), 0.012 * PX, true)
	if model.oars_out():
		var swing = sin(float(model.oars.phase))
		draw_rower(canvas, Vector2(-0.80 * fwd * PX, deck_y("sail")), swing, fwd)
		draw_oar(canvas, Vector2(-0.30 * fwd * PX, deck_y("sail")), swing, fwd)
	else:
		draw_sailor_seated(canvas, Vector2(-0.80 * fwd * PX, deck_y("sail")), sailor_hand, model.sail_cleated)
	# the pennant at the masthead points the way the wind blows, and flutters
	if not info.is_empty():
		var wv: Vector2 = info.wind
		var along = wv.x if absf(wv.x) > 0.2 else 0.2
		var dirx = fwd * signf(along)
		var sway = 0.07 * sin(t * 11.0)
		var flag_scale = 0.34 * PX / float(SAIL_PENNANT.get_height())
		draw_sprite_at(canvas, SAIL_PENNANT, Vector2(SAIL_PENNANT.get_width() * 0.09, SAIL_PENNANT.get_height() * 0.96), mast_top, sway, Vector2(flag_scale * (1.0 if dirx > 0.0 else -1.0), flag_scale), false)

# The pole truck's person, pole and the ground under the line, all live (placeholder figures
# until it has its own art). Local frame: x along increasing route distance, metres above the rail.
func pole_point(x: float, y: float) -> Vector2:
	return Vector2(x, -(y - 0.21)) * PX

# The grapnel with the winch of the pole truck: the posts, trees, rocks, stumps and bushes along the line (their kind tells how strong they are),
# the wooden drum on the frame, the hook and the rope (taut when it pulls, sagging when it lies).
const GRAPNEL_WOOD = Color(0.45, 0.31, 0.18)
const GRAPNEL_ROPE = Color(0.78, 0.66, 0.42)

func draw_grapnel_anchor(canvas: Node2D, x: float, type: String) -> void:
	match type:
		"post":
			canvas.draw_rect(Rect2(pole_point(x - 0.07, 2.6), Vector2(0.14, 2.6) * PX), GRAPNEL_WOOD)
			canvas.draw_rect(Rect2(pole_point(x - 0.12, 2.6), Vector2(0.24, 0.1) * PX), Color(0.3, 0.2, 0.12))
		"tree":
			canvas.draw_rect(Rect2(pole_point(x - 0.16, 3.2), Vector2(0.32, 3.2) * PX), Color(0.34, 0.24, 0.15))
			canvas.draw_circle(pole_point(x, 4.6), 1.0 * PX, Color(0.18, 0.36, 0.2))
		"rock":
			canvas.draw_colored_polygon(PackedVector2Array([pole_point(x - 0.7, 0.0), pole_point(x - 0.5, 0.8), pole_point(x + 0.05, 1.1), pole_point(x + 0.55, 0.7), pole_point(x + 0.75, 0.0)]), Color(0.52, 0.53, 0.55))
		"stump":
			canvas.draw_rect(Rect2(pole_point(x - 0.22, 0.6), Vector2(0.44, 0.6) * PX), Color(0.4, 0.28, 0.17))
			canvas.draw_rect(Rect2(pole_point(x - 0.22, 0.6), Vector2(0.44, 0.07) * PX), Color(0.66, 0.5, 0.3))
		"bush":
			canvas.draw_circle(pole_point(x, 0.5), 0.5 * PX, Color(0.28, 0.46, 0.2))
			canvas.draw_circle(pole_point(x + 0.3, 0.35), 0.35 * PX, Color(0.22, 0.4, 0.18))

func draw_grapnel_overlay(canvas: Node2D, model) -> void:
	var dir = int(model.state.direction)
	var s = float(model.state.s)
	var g = model.grapnel
	g.build(int(model.route.seed_value), float(model.route.length_m), model.route.station_s)
	for a in g.anchors:
		var x = (float(a.s) - s) * float(dir)
		if x > -12.0 and x < 22.0: draw_grapnel_anchor(canvas, x, str(a.type))
	# the drum of the winch on the front of the frame
	var drum = pole_point(0.8, 0.8)
	canvas.draw_rect(Rect2(drum, Vector2(0.28, 0.2) * PX), GRAPNEL_WOOD)
	canvas.draw_arc(drum + Vector2(0.14, 0.1) * PX, 0.1 * PX, 0, TAU, 12, GRAPNEL_ROPE, 2.0, true)
	var ground_y = Callable(model, "route_y")
	var hand_y = model.grapnel_hand_y()
	var off = g.hook_offset(s, dir, hand_y, ground_y)
	var hook = pole_point(off.x, off.y)
	var winch = pole_point(0.94, 0.9)
	var taut = g.mode == "hooked" and g.tension > 1.0
	var pts: PackedVector2Array = PackedVector2Array()
	var count = 10
	var sag = 0.0 if taut else clampf(winch.distance_to(hook) * 0.18, 0.0, 0.6 * PX)
	for i in range(count + 1):
		var t = float(i) / float(count)
		pts.append(winch.lerp(hook, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t)))
	canvas.draw_polyline(pts, GRAPNEL_ROPE, maxf(2.0, 0.025 * PX), true)
	canvas.draw_circle(hook, 0.07 * PX, Color(0.62, 0.64, 0.66))
	canvas.draw_arc(hook, 0.13 * PX, deg_to_rad(20), deg_to_rad(200), 10, Color(0.62, 0.64, 0.66), 3.0, true)

func draw_pole_overlay(canvas: Node2D, model) -> void:
	if model == null or model.state.is_empty() or not model.state.fleet_by_id.has("pole"): return
	var dir = float(int(model.state.direction))
	var s = float(model.state.s)
	# Ground type under the line, 8 m each way: only the unusual kinds are marked.
	if model.state.phase == "route":
		var x = -8.0
		while x < 8.0:
			var ground = model.pole_ground_at(s + x * dir)
			if ground.type != "dense":
				var color = {"clay": Color(0.42, 0.34, 0.26, 0.9), "stones": Color(0.62, 0.62, 0.64, 0.95), "roots": Color(0.30, 0.42, 0.22, 0.95)}[ground.type]
				canvas.draw_rect(Rect2(pole_point(x - 0.25, -0.02), Vector2(0.5, 0.07) * PX), color)
				if ground.type == "stones": canvas.draw_circle(pole_point(x, 0.06), 0.05 * PX, Color(0.72, 0.72, 0.74))
				if ground.type == "roots": canvas.draw_line(pole_point(x - 0.2, 0.0), pole_point(x + 0.2, 0.1), Color(0.35, 0.24, 0.14), 0.04 * PX, true)
			x += 0.5
	if model.grapnel_installed(): draw_grapnel_overlay(canvas, model)
	var pole = model.pole
	var tip_x = float(pole.tip) * dir
	var hands = pole_point(0.0, 1.45)
	var tip = pole_point(tip_x, 0.0)
	var axis = (hands - tip).normalized()
	draw_worker_body(canvas, Vector2(-0.16 * PX, deck_y("pole")), 1.75 * PX)
	# Pole: wooden, 4 m, sliding through the hands, with an iron tip: the picture of the head, the shaft and the foot (P2).
	var top = tip + axis * 4.0 * PX
	var pole_w = 0.09 * PX
	var head_len = pole_w * POLE_HEAD.get_width() / float(POLE_HEAD.get_height())
	var foot_len = pole_w * POLE_FOOT.get_width() / float(POLE_FOOT.get_height())
	draw_part_between(canvas, POLE_SHAFT, tip + axis * foot_len, top - axis * head_len, pole_w)
	draw_part_between(canvas, POLE_HEAD, top - axis * head_len, top, pole_w)
	draw_part_between(canvas, POLE_FOOT, tip + axis * foot_len, tip, pole_w)
	draw_worker_arm(canvas, Vector2(-0.16 * PX, deck_y("pole")), 1.75 * PX, hands)
	if pole.planted():
		var ground = model.pole_ground_at(float(pole.tip_s))
		var spot = {"dense": Color(0.45, 0.35, 0.22), "clay": Color(0.42, 0.34, 0.26), "stones": Color(0.7, 0.7, 0.72), "roots": Color(0.3, 0.42, 0.22)}[ground.type]
		canvas.draw_circle(tip, 0.07 * PX, spot)
		if pole.slipping: canvas.draw_arc(tip, 0.16 * PX, 0, TAU, 20, Color(1, 0.8, 0.4, 0.8), 2.0, true)

# Live parts of the pneumatic train on top of the painted body (tools/make_pneumatic_art.py):
# the manometer needle, frost on the four pipe places (the same places the model counts) and
# the puffs of spent air at the working cylinder.
const VALVE_DROP = 0.17   # the drain valve hangs this far (m) under its frosted place
const FROST_SPOTS = [Vector2(1.36, 0.62), Vector2(1.28, 0.93), Vector2(1.20, 1.20), Vector2(0.40, 1.82)]

func draw_pneumatic_overlay(canvas: Node2D, model) -> void:
	if model == null or model.state.is_empty() or not model.state.fleet_by_id.has("pneumatic"): return
	var fleet = model.state.fleet_by_id.pneumatic
	var center = stock_body_point("pneumatic", Vector2(1419, 562))
	var needle = deg_to_rad(150.0) + deg_to_rad(240.0) * clampf(float(fleet.get("fuel", 0.0)) / float(model.object_stats("pneumatic").tank), 0.0, 1.0)
	canvas.draw_line(center, center + Vector2.from_angle(needle) * 0.075 * PX, Color("a8231c"), 2.0, true)
	canvas.draw_circle(center, 2.0, Color("2a2a2a"))
	# B6.2: a little brass valve under every frosted place lets the condensate out; it rings when it is time (60 s of running)
	for i in range(FROST_SPOTS.size()):
		var valve = steam_point(FROST_SPOTS[i].x, FROST_SPOTS[i].y) + Vector2(0, VALVE_DROP * PX)
		var age = model.drain_age(i)
		if age > 0.8 * 60.0:
			var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
			canvas.draw_arc(valve, 0.075 * PX, 0, TAU, 20, Color(1.0, 0.62 if age <= 60.0 else 0.35, 0.2, 0.4 + 0.5 * pulse), 2.0, true)
		canvas.draw_circle(valve, 0.032 * PX, Color("2a2218"))
		canvas.draw_circle(valve, 0.024 * PX, Color("c9af73"))
		canvas.draw_line(valve + Vector2(-0.02, 0) * PX, valve + Vector2(0.02, 0) * PX, Color("5a4a2a"), 1.5, true)
	var spots: Array = fleet.get("ice_spots", [])
	for i in range(mini(spots.size(), FROST_SPOTS.size())):
		var amount = clampf(float(spots[i]), 0.0, 1.0)
		if amount < 0.03: continue
		var at = steam_point(FROST_SPOTS[i].x, FROST_SPOTS[i].y)
		canvas.draw_circle(at, (0.05 + 0.07 * amount) * PX, Color(0.85, 0.94, 1.0, 0.28 + 0.5 * amount))
		if amount > 0.2: canvas.draw_arc(at, (0.12 + 0.02 * sin(Time.get_ticks_msec() / 260.0)) * PX, 0, TAU, 24, Color(0.75, 0.92, 1.0, 0.35 + 0.35 * amount), 1.5, true)
		for k in range(5):
			var crystal = Vector2.from_angle(float(k) * 1.26 + float(i)) * (0.04 + 0.05 * amount) * PX
			canvas.draw_circle(at + crystal, (0.012 + 0.016 * amount) * PX, Color(1.0, 1.0, 1.0, 0.35 + 0.5 * amount))
	if not model.state.get("engine", false): return
	var throttle = clampf(float(model.state.get("throttle", 0.0)), 0.0, 1.0)
	if throttle < 0.03: return
	var t = Time.get_ticks_msec() / 1000.0
	for i in range(5):
		var age = fposmod(t * (1.2 + 1.2 * throttle) + i / 5.0, 1.0)
		canvas.draw_circle(steam_point(1.48 + age * 0.35, 0.28 - age * 0.10 + 0.04 * sin(t * 9.0 + i)), (0.025 + age * 0.07) * PX, Color(0.9, 0.96, 1.0, (0.25 + 0.3 * throttle) * (1.0 - age)))

# Coupling rod, main rod, crosshead and piston rod follow the wheel angle.
func draw_steam_motion(canvas: Node2D, distance: float, facing: int, outer: Transform2D, id: String = "steam") -> void:
	var radius = PX * 0.55 * 0.5
	var angle = fposmod(distance * PX / radius * facing, TAU)
	var positions = wheel_positions(id)
	var pins: Array = []
	for position in positions: pins.append(position + Vector2(0, -radius * 0.5).rotated(angle))
	canvas.draw_set_transform_matrix(outer)
	var steel = Color("56635f")
	var brass = Color("c9af73")
	canvas.draw_line(pins[0], pins[1], steel, 0.05 * PX, true)
	canvas.draw_line(pins[0], pins[1], Color("8a9a94"), 0.012 * PX, true)
	var front = positions[1]
	var rod_length = 0.30 * PX
	var dy = pins[1].y - front.y
	var crosshead = Vector2(pins[1].x + sqrt(maxf(0.0, rod_length * rod_length - dy * dy)), front.y)
	canvas.draw_line(pins[1], crosshead, steel, 0.04 * PX, true)
	canvas.draw_line(crosshead, Vector2(1.269 * PX, front.y), Color("a8b4ae"), 0.018 * PX, true)
	canvas.draw_rect(Rect2(crosshead - Vector2(0.035, 0.07) * PX, Vector2(0.07, 0.14) * PX), Color("3c4744"))
	for pin in pins:
		canvas.draw_circle(pin, 0.045 * PX, brass)
		canvas.draw_circle(pin, 0.02 * PX, Color("6f5d33"))

func mechanism_parts(p: Dictionary) -> Array:
	var parts: Array = []
	var support = assets["mechanism/support"]
	var foot_y = float(support.region_px[1])+float(support.region_px[3])-1
	var support_scale = (deck_y("handcar")-p.rocker.y*PX)/(foot_y-pivot("mechanism/support").y)
	parts.append({"id":"mechanism/support","position":p.rocker*PX,"angle":0.0,"scale":support_scale})
	var crank_angle=fposmod(p.phase,TAU)
	parts.append({"id":"mechanism/gear","position":p.crank*PX,"angle":crank_angle,"scale":scale_for("mechanism/gear")})
	var gear_width=float(assets["mechanism/gear"].region_px[2])
	parts.append({"id":"mechanism/gear","position":p.crank*PX,"angle":crank_angle,"scale":float(rig.drive_sprocket_radius)*2*PX/gear_width})
	parts.append({"id":"mechanism/gear","position":wheel_positions("handcar")[1],"angle":fposmod(p.wheel_angle,TAU),"scale":float(rig.wheel_sprocket_radius)*2*PX/gear_width})
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
	draw_chain(canvas,p,outer)

func draw_chain(canvas: Node2D, p: Dictionary, outer: Transform2D) -> void:
	var a=p.crank*PX
	var b=wheel_positions("handcar")[1]
	var ra=float(rig.drive_sprocket_radius)*PX
	var rb=float(rig.wheel_sprocket_radius)*PX
	var u=(b-a).normalized()
	var normal=Vector2(-u.y,u.x)
	var c=(ra-rb)/a.distance_to(b)
	var s=sqrt(1-c*c)
	var n1=u*c+normal*s
	var n2=u*c-normal*s
	canvas.draw_set_transform_matrix(outer)
	for color in [Color("172724"),Color("a7aa91")]:
		var width=3.0 if color==Color("172724") else 1.1
		canvas.draw_arc(a,ra,n1.angle(),n2.angle()+TAU,32,color,width,true)
		canvas.draw_arc(b,rb,n2.angle(),n1.angle(),32,color,width,true)
		for n in [n1,n2]: canvas.draw_line(a+n*ra,b+n*rb,color,width,true)
	for side in range(2):
		var n=n1 if side==0 else n2
		var start=a+n*ra
		var end=b+n*rb
		var span=start.distance_to(end)
		var pitch=0.035*PX
		var offset=fposmod(p.phase*ra*(-1 if side==0 else 1),pitch)
		for i in range(ceili(span/pitch)):
			var distance=i*pitch+offset
			if distance<span: canvas.draw_circle(start.lerp(end,distance/span),1.1,Color("c1b98e"))
