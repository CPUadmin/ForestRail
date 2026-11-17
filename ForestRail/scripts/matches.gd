extends RefCounted
# 1.4.14 Спичка у паровоза (идея владельца 16.11, концепция одобрена; дождь и ветер не мешают): вместо кнопки «Розжиг»
# коробок спичек. Чиркнуть по боку коробка: медленно — только царапает (три раза — головка стёрлась), в меру —
# вспыхивает, слишком резко — ломается. Горит ~6 с; донести до открытой топки с углём, не дёргая (рывок задувает).
# Иногда спичка отсырела (~1 из 10, головка темнее): только царапает. Без таймеров и денежных штрафов; кончились —
# помощь депо. Коробок на 10 штук пополняется в депо бесплатно. Картинки коробка и спичек — П31, пламя — код.
#
# Число спичек живёт в fleet_by_id.steam.matches (сохраняется). Спичка в руке — нет: это мгновение игры.

const BOX = 10
const DAMP_CHANCE = 0.1
const BURN_S = 6.0
const SLOW = 0.8          # длин тёрки в секунду: медленнее — только царапает
const FAST = 4.0          # быстрее — спичка ломается
const RUB_AFTER = 3       # столько царапаний стирают головку
const BLOW = 2.2          # высот экрана в секунду: рука дёрнулась быстрее — пламя задуло

var m = null
var hand = ""             # "" | "fresh" | "damp" | "lit" | "rubbed" | "broken" | "burnt"
var burn = 0.0            # секунды горения, что остались
var scratches = 0
var serial = 0            # номер взятой спички: какая из них сырая, решает кубик игры

func _init(owner_model = null) -> void:
	m = owner_model

func fleet() -> Dictionary:
	return m.state.fleet_by_id.get("steam", {})

func count() -> int:
	return int(fleet().get("matches", BOX))

func in_hand() -> bool:
	return hand in ["fresh", "damp", "lit"]

func lit() -> bool:
	return hand == "lit"

# Взять спичку из коробка (в творческом коробок не кончается).
func take() -> bool:
	if in_hand(): return true
	if count() <= 0 and not m.creative():
		return m.fail("Спички кончились. Вызови помощь депо: там дадут новый коробок")
	if not m.creative(): fleet().matches = count() - 1
	serial += 1
	var rng = RandomNumberGenerator.new()
	rng.seed = int(m.route.seed_value) * 4507 + int(fleet().get("match_serial", 0)) * 131 + serial * 977 + 3
	fleet().match_serial = int(fleet().get("match_serial", 0)) + 1
	hand = "damp" if rng.randf() < DAMP_CHANCE else "fresh"
	scratches = 0
	burn = 0.0
	m.events.append("match_take")
	return true

# Положить невзятую в дело спичку обратно.
func put_back() -> void:
	if hand in ["fresh", "damp"] and not m.creative(): fleet().matches = count() + 1
	hand = ""

func drop() -> void:
	hand = ""

# Чиркнуть: speed — длин тёрки в секунду. Ответ: "scratch", "rubbed", "lit", "broken" или "" (нечем чиркать).
func strike(speed: float) -> String:
	if not hand in ["fresh", "damp"]: return ""
	if speed > FAST:
		hand = "broken"
		m.events.append("match_broken")
		m.message = "Слишком резко: спичка сломалась. Возьми другую"
		return "broken"
	if speed < SLOW or hand == "damp":
		scratches += 1
		m.events.append("match_scratch")
		if scratches >= RUB_AFTER:
			var damp = hand == "damp"
			hand = "rubbed"
			m.message = "Спичка отсырела и не загорелась: головка стёрлась. Возьми другую" if damp else "Головка стёрлась: чиркай быстрее, но не рви"
			return "rubbed"
		m.message = "Отсырела: только царапает" if hand == "damp" else "Медленно: только царапает. Чиркни быстрее"
		return "scratch"
	hand = "lit"
	burn = BURN_S
	m.events.append("match_lit")
	m.message = "Горит! Неси к открытой топке, не дёргай"
	return "lit"

# Горение: догорела — в руке обгорелая спичка.
func step(dt: float) -> void:
	if hand != "lit": return
	burn -= dt
	if burn <= 0.0:
		burn = 0.0
		hand = "burnt"
		m.events.append("match_out")
		m.message = "Спичка догорела. Возьми другую"

# Рука дёрнулась: speed — высот экрана в секунду. Пламя задуло.
func jerk(speed: float) -> bool:
	if hand != "lit" or speed <= BLOW: return false
	hand = "burnt"
	m.events.append("match_out")
	m.message = "Рывком задуло спичку. Неси плавнее"
	return true

# Поднести горящую спичку к топке.
func to_fire() -> bool:
	if hand != "lit": return false
	if m.vehicle_id() != "steam": return false
	if not bool(m.boiler().door): return m.fail("Дверца топки закрыта: открой её, потом подноси спичку")
	if not m.light_fire(): return false
	hand = ""
	m.events.append("match_used")
	return true

func refill() -> void:
	if m.state.fleet_by_id.has("steam"): fleet().matches = BOX
