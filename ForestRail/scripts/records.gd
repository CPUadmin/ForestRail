extends RefCounted

# Records of the line: the best time from one end station to the other (A to F and back) and the top speed, for every machine.
# A pure model: it knows nothing about the scene, it only watches the train go by (tick) and keeps the table that lives in the save.
#
# A run starts when the train stands still at an end station and then moves; it ends when the train stands still at the other end.
# The clock counts from the last moment of standing, so the start-up of the machine is part of the time.

const STILL_MPS = 0.3
const MIN_RUN_SECONDS = 5.0   # a teleport (help of the depot) is not a run

var from_station = -1
var clock0 = 0.0
var running = false

func reset() -> void:
	from_station = -1
	running = false

static func empty_row() -> Dictionary:
	return {"a_f": 0.0, "f_a": 0.0, "top_kmh": 0.0}

static func row_of(table: Dictionary, vehicle_id: String) -> Dictionary:
	if not table.has(vehicle_id) or not table[vehicle_id] is Dictionary:
		table[vehicle_id] = empty_row()
	var row: Dictionary = table[vehicle_id]
	for key in empty_row():
		if not row.has(key): row[key] = 0.0
	return row

# One step of watching. Returns the news of this step: [{"kind": "a_f" | "f_a", "seconds": float, "best": bool}].
func tick(table: Dictionary, vehicle_id: String, seconds: float, station: int, last_station: int, speed_mps: float, on_route: bool) -> Array:
	var news: Array = []
	if not on_route:
		reset()
		return news
	var speed = absf(speed_mps)
	var row = row_of(table, vehicle_id)
	if speed * 3.6 > float(row.top_kmh) + 0.05: row.top_kmh = speed * 3.6
	var still = speed < STILL_MPS
	var at_end = station == 0 or (station == last_station and last_station > 0)
	if at_end and still:
		if running and station != from_station and seconds - clock0 >= MIN_RUN_SECONDS:
			var key = "a_f" if from_station == 0 else "f_a"
			var took = seconds - clock0
			var best = float(row[key]) <= 0.0 or took < float(row[key])
			if best: row[key] = took
			news.append({"kind": key, "seconds": took, "best": best})
		from_station = station
		clock0 = seconds
		running = false
		return news
	if from_station >= 0 and not running and not still: running = true
	return news

# 134.6 -> "2:14.6"
static func time_text(seconds: float) -> String:
	if seconds <= 0.0: return "—"
	var tenths = int(floor(seconds * 10.0 + 0.000001))
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]
