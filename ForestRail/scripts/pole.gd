extends RefCounted
# N12: the pole truck. The pole is a real rod, not a scripted stroke: it is carried loose
# (a spring-damped tip that follows the aim), planted into the ground ahead or behind, and
# then the person works it freely. The pole can only transmit force along its axis. With
# the tip ahead the person pulls the truck toward it (or, pushing the other way, stands on
# it and brakes); with the tip behind he pushes off from it. The tip holds only as well as
# the ground does: an embedded tip holds some pull by itself, a pressed one holds more by
# friction, and past that the tip slides. A person pushes weaker the faster his hands move
# along the pole. Nothing else limits pushing: no stroke, no work or power cap, no rhythm.
#
# All places are metres in the travel frame: x forward of the platform centre, the
# hands at HAND_HEIGHT above the ground.

const LENGTH = 4.0
const HAND_HEIGHT = 1.45
const REACH = 3.4          # farthest tip place the pole can be carried to
const MIN_PLANT = 0.4      # the tip cannot be planted under the hands
const F_MAX = 380.0        # N, a strong push along the pole
const V_HAND = 6.0         # m/s along the pole at which the push fades to nothing
const EMBED = 160.0        # N per unit of ground quality: an embedded tip holds this much alone
const FRICTION = 0.7
const SLIDE_RATE = 300.0   # N·s/m: how fast a tip slides when overpowered
const ARM_RATE = 6.0       # effort per second: the arms are not instant
const SWING_K = 25.0       # carried pole follows its aim like a spring
const SWING_C = 9.0
const CLAY_LIFT_S = 0.4    # pulling the tip out of clay takes time
const GROUNDS = {
	"dense": {"g": 1.0, "name": "плотный грунт"},
	"clay": {"g": 0.35, "name": "глина"},
	"stones": {"g": 0.15, "name": "камни"},
	"roots": {"g": 1.25, "name": "корни"}}

var segments: Array = []   # [start_s, end_s, type]
var wet = 0.0              # rain, 0..1: the ground is slicker, the clay most of all
var built_for = ""
var mode = "free"
var tip = 1.5              # tip place relative to the platform, forward positive
var tip_v = 0.0
var aim = 1.5
var tip_s = 0.0
var effort = 0.0
var effort_target = 0.0
var lock = 0.0
var slipping = false
var force = 0.0            # last force on the platform along the route
var events: Array = []     # {"kind": plant / skid / slide / lift, "ground": type}, for sound and view

# The ground under the line: stretches of 2-6 m, the same for the same seed. The lake
# station is damp (clay), the upper forest is stony, elsewhere it is mostly firm with
# roots among the trees.
func build(seed_value: int, length_m: float, station_s: Array) -> void:
	var key = "%d:%.1f" % [seed_value, length_m]
	if key == built_for: return
	built_for = key
	segments.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value + 4242
	var s = -45.0
	while s < length_m + 45.0:
		var length = rng.randf_range(2.0, 6.0)
		var near_lake = station_s.size() > 3 and absf(s - float(station_s[3])) < 260.0
		var near_bor = station_s.size() > 4 and absf(s - float(station_s[4])) < 260.0
		var roll = rng.randf()
		var type = "dense"
		if near_lake: type = "clay" if roll < 0.7 else "dense"
		elif near_bor: type = "stones" if roll < 0.55 else ("roots" if roll > 0.85 else "dense")
		else: type = "roots" if roll < 0.25 else ("stones" if roll > 0.95 else "dense")
		segments.append([s, s + length, type])
		s += length

func ground_at(s: float) -> Dictionary:
	var low = 0
	var high = segments.size() - 1
	while low < high:
		var mid = (low + high) / 2
		if float(segments[mid][1]) <= s: low = mid + 1
		else: high = mid
	var type = str(segments[low][2]) if not segments.is_empty() else "dense"
	var info = GROUNDS[type].duplicate()
	info.type = type
	info.g = float(info.g) * (1.0 - wet * (0.4 if type == "clay" else 0.25))
	return info

func reset() -> void:
	mode = "free"
	tip = 1.5
	tip_v = 0.0
	aim = 1.5
	effort = 0.0
	effort_target = 0.0
	lock = 0.0
	slipping = false
	force = 0.0
	events.clear()

func set_aim(value: float) -> void:
	aim = clampf(value, -REACH, REACH)

func set_effort(value: float) -> void:
	effort_target = clampf(value, -1.0, 1.0)

func planted() -> bool:
	return mode == "planted"

# Drop the carried tip where it is. A stony place may skid the tip off instead (40% of the
# stony places, fixed by the place itself so it is the same every time).
func plant(s: float, direction: int) -> bool:
	if mode != "free" or lock > 0.0 or absf(tip) < MIN_PLANT: return false
	var place = s + tip * float(direction)
	var ground = ground_at(place)
	var skid = ground.type == "stones" and fposmod(sin(place * 12.9898) * 43758.5453, 1.0) < 0.4
	if skid:
		events.append({"kind": "skid", "ground": ground.type})
		lock = 0.25
		return false
	mode = "planted"
	tip_s = place
	effort = 0.0
	slipping = false
	events.append({"kind": "plant", "ground": ground.type})
	return true

func lift(s: float, direction: int) -> void:
	if mode != "planted": return
	var ground = ground_at(tip_s)
	mode = "free"
	tip = clampf((tip_s - s) * float(direction), -REACH, REACH)
	tip_v = 0.0
	aim = tip
	effort = 0.0
	slipping = false
	lock = CLAY_LIFT_S if ground.type == "clay" else 0.12
	events.append({"kind": "lift", "ground": ground.type})

# One physics step; the result is the force on the platform along the route (sign of s).
func step(dt: float, s: float, v: float, direction: int) -> float:
	force = 0.0
	lock = maxf(0.0, lock - dt)
	if mode == "free":
		var spring = SWING_K * (aim - tip) - SWING_C * tip_v
		tip_v += spring * dt
		tip = clampf(tip + tip_v * dt, -REACH, REACH)
		if absf(tip) >= REACH: tip_v = 0.0
		effort = 0.0
		return 0.0
	effort = move_toward(effort, effort_target, ARM_RATE * dt)
	var a = (tip_s - s) * float(direction)
	tip = a
	var axis = sqrt(a * a + HAND_HEIGHT * HAND_HEIGHT)
	if axis > LENGTH:
		# The truck has run past the pole's reach: it is pulled out of the ground.
		lift(s, direction)
		return 0.0
	var cos_phi = absf(a) / axis
	var sin_phi = HAND_HEIGHT / axis
	var forward_speed = v * float(direction)
	var sign_value = signf(effort)
	# A person pushes weaker the faster his hands travel along the pole in the push direction.
	var hand_speed = forward_speed * sign_value * cos_phi
	var fade = clampf(1.0 - hand_speed / V_HAND, 0.0, 1.5)
	var axial = F_MAX * absf(effort) * fade
	var horizontal = axial * cos_phi
	# Pulling toward a tip ahead or pushing off from a tip behind draws the tip out of the
	# ground; the opposite pairing presses it in.
	var pressing = effort * a < 0.0
	var normal = axial * sin_phi * (1.0 if pressing else -1.0)
	var ground = ground_at(tip_s)
	var holds = float(ground.g) * (EMBED + FRICTION * maxf(0.0, normal))
	var transmitted = horizontal
	slipping = false
	if horizontal > holds:
		slipping = true
		transmitted = holds * 0.85
		# The overpowered tip is dragged along the ground, backwards against the push.
		var slide = minf(3.0, (horizontal - holds) / SLIDE_RATE)
		tip_s -= sign_value * float(direction) * slide * dt
		events.append({"kind": "slide", "ground": ground.type})
	# A positive effort drives the truck forward in the travel frame (toward the tip ahead
	# or away from the tip behind), a negative one back.
	force = sign_value * transmitted * float(direction)
	return force
