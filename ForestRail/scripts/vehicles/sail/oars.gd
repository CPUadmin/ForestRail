extends RefCounted
# В6.9: вёсла парусной на штиле (решение владельца 06.11.2026: запасное средство парусной это вёсла). Чистая модель без картинки и ввода.
# Игрок тянет мышь (рука идёт к себе), это гребок: ход даёт только гребок, возврат весла по воздуху хода не даёт. Тяга растёт с темпом гребка,
# падает с усталостью и с скоростью (потолок ≈ 6 км/ч), в штиль это страховка, а не способ ездить (docs/SAIL_SPARE_PROPOSAL_RU.md).

const DEFAULTS = {
	"thrust_n": 150.0, "max_speed_mps": 1.67, "full_rate_mps": 1.2,
	"fatigue_per_s": 0.05, "recover_per_s": 0.04, "fatigue_loss": 0.7, "smooth": 0.35,
}

var cfg: Dictionary = DEFAULTS.duplicate()
var rate = 0.0            # the speed of the stroke, m/s of the hand (smoothed)
var fatigue = 0.0         # 0 fresh .. 1 spent
var phase = 0.0           # the swing of the oars for the picture, radians
var pending = 0.0         # the hand travel gathered since the last step, metres (only the pull)
var stroke_back = 0.0     # the recovery travel gathered (the oar goes forward in the air)

func _init(config: Dictionary = {}) -> void:
	for key in config: cfg[key] = config[key]

func c(key: String) -> float:
	return float(cfg[key])

func reset() -> void:
	rate = 0.0
	fatigue = 0.0
	phase = 0.0
	pending = 0.0
	stroke_back = 0.0

# the hand moved by `metres`: positive is the pull (the stroke), negative the return in the air
func hand(metres: float) -> void:
	if metres > 0.0: pending += metres
	else: stroke_back += -metres

# the thrust along the car at this speed (N, + forward)
func force(v_forward: float) -> float:
	var effort = clampf(rate / c("full_rate_mps"), 0.0, 1.0)
	var speed_left = clampf(1.0 - maxf(0.0, v_forward) / c("max_speed_mps"), 0.0, 1.0)
	return c("thrust_n") * effort * (1.0 - c("fatigue_loss") * fatigue) * speed_left

func step(dt: float) -> void:
	if dt <= 0.0: return
	var raw = pending / dt
	pending = 0.0
	rate = lerpf(rate, raw, c("smooth"))
	if rate < 0.02: rate = 0.0
	var effort = clampf(rate / c("full_rate_mps"), 0.0, 1.0)
	if effort > 0.1: fatigue = minf(1.0, fatigue + c("fatigue_per_s") * effort * dt)
	else: fatigue = maxf(0.0, fatigue - c("recover_per_s") * dt)
	phase = fposmod(phase + (raw + stroke_back / dt) * dt * 3.0, TAU)
	stroke_back = 0.0
