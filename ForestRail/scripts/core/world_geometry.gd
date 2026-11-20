extends RefCounted

# All world dimensions and local attachments are metres. Screen pixels appear
# only at the renderer boundary; physics and station bounds use this catalogue.
const PX = 96.0
static var catalogue: Dictionary = {}

static func data() -> Dictionary:
	if catalogue.is_empty():
		catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/object_dimensions.json"))
	return catalogue

static func kind(id: String) -> String:
	return "wagon" if id.begins_with("W") else id

static func body(id: String) -> Dictionary:
	return data().bodies[kind(id)]

static func length(id: String) -> float:
	return float(body(id).length_m)

static func offset(ids: Array, index: int) -> float:
	var result = 0.0
	for i in range(index):
		result += (length(ids[i]) + length(ids[i+1])) * 0.5 + float(data().coupler.gap_m)
	return result

static func train_length(ids: Array) -> float:
	var result = float(data().coupler.end_extension_m)*2
	for id in ids: result += length(id)
	return result + maxf(0,ids.size()-1)*float(data().coupler.gap_m)

static func coupling(id: String, end: int) -> Vector2:
	return Vector2(length(id)*0.5*end,-float(data().coupler.height_m))*PX
