extends Control
# КАЗИК «у стрелки», этап «г» (docs/KAZIK_RU.md): экран с колесом «лудки», Михалычем, жетонами и мешком шлака.
# Логика во всём лежит в Casino (scripts/casino.gd); здесь только показ и анимация. Сектора колеса рисуются по весам из данных,
# поэтому ширина сектора и есть настоящий шанс (карточка почти невидима: 0,2%, так и задумано, цифры честные).

var game
var angle = 0.0                # поворот колеса, рад (по часовой, 0: начало первого сектора под указателем)
var spin_from = 0.0
var spin_to = 0.0
var spin_t = -1.0              # секунд с начала прокрутки, -1: колесо стоит
var spin_seconds = 4.2
var last_sector = -1
var result: Dictionary = {}
var line = "Заходи, не стесняйся. Колесо крутится, чайник греется."
var shown_tokens = 0.0
var tokens_target = 0
var glow = 0.0
var spin_button: Button
var dep_button: Button
var tex = {}

const SECTOR_TEXT = {"empty": "пусто", "tokens1": "+5", "tokens2": "+10", "junk": "шлак", "coins": "монеты", "repair": "ремнабор", "golden": "золото", "bonus": "бонуска", "card": "КАРТА"}
const SECTOR_COLOR = {"empty": Color("2a3a30"), "tokens1": Color("b08a3c"), "tokens2": Color("d1a846"), "junk": Color("6b4a2e"), "coins": Color("c8b04a"), "repair": Color("3e7d78"), "golden": Color("f0c640"), "bonus": Color("7a4d8c"), "card": Color("d03a2e")}
# какая картинка листа шлака ближе всего к виду хлама (для строки в мешке)
const JUNK_PICTURE = {"rusty_bolt": 1, "bearing_cover": 2, "tie_plate": 4, "brake_shoe": 6, "rail_clip": 7, "cracked_lantern": 8, "stationmaster_watch": 9, "track_spike": 1, "fishplate": 5}
const BONUS_NAME = {"spin": "халявная крутка", "x2": "иксы на ставку", "junk": "шлак в мешок", "tea": "чайку!"}

func cas():
	return game.model.casino()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for name in ["facade", "interior", "wheel", "pointer", "glow", "mikhalych", "token"]:
		tex[name] = load("res://assets/art_kazik/%s.png" % name)
	for i in range(1, 10): tex["junk_%d" % i] = load("res://assets/art_kazik/junk_%d.png" % i)
	shown_tokens = float(cas().tokens())
	tokens_target = cas().tokens()
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.position = Vector2(size.x * 0.30, size.y - 78.0)
	row.size = Vector2(size.x * 0.66, 56)
	add_child(row)
	spin_button = game.add_button(row, "Крутануть", Callable(self, "on_spin"))
	dep_button = game.add_button(row, "Деп", Callable(self, "on_deposit"))
	game.add_button(row, "Назад в депо", game.close_modal)
	refresh_buttons()

# ---- the sectors by their weights
func sectors() -> Array:
	return game.model.data.casino.sectors

func weight_total() -> float:
	var sum = 0.0
	for s in sectors(): sum += float(s.weight)
	return sum

func sector_bounds(index: int) -> Vector2:
	var start = 0.0
	for i in range(index): start += float(sectors()[i].weight)
	return Vector2(start, start + float(sectors()[index].weight)) / weight_total() * TAU

func sector_at(wheel_angle: float) -> int:
	var a = fposmod(-wheel_angle, TAU)
	for i in range(sectors().size()):
		var b = sector_bounds(i)
		if a >= b.x and a < b.y: return i
	return 0

func sector_index(id: String) -> int:
	for i in range(sectors().size()):
		if str(sectors()[i].id) == id: return i
	return 0

# ---- actions
func common_junk_value() -> Dictionary:
	var tokens = 0
	var count = 0
	for entry in cas().bag():
		if str(entry.kind) == "rare": continue
		tokens += int(entry.tokens) * int(entry.count)
		count += int(entry.count)
	return {"tokens": tokens, "count": count}

func refresh_buttons() -> void:
	var cost = int(game.model.data.casino.spin_cost)
	spin_button.text = "Крутануть · %d %s" % [cost, plural(cost, "жетон", "жетона", "жетонов")]
	spin_button.disabled = spin_t >= 0.0 or cas().tokens() < cost
	var v = common_junk_value()
	dep_button.text = "Деп: сдать шлак · %d шт → %d %s" % [v.count, v.tokens, plural(int(v.tokens), "жетон", "жетона", "жетонов")] if v.count > 0 else "Деп: шлака нет"
	dep_button.disabled = spin_t >= 0.0 or v.count <= 0

func on_deposit() -> void:
	var got = 0
	var n = 0
	for entry in cas().bag():
		if str(entry.kind) == "rare": continue
		got += cas().deposit(str(entry.id), int(entry.count))
		n += int(entry.count)
	if got > 0:
		tokens_target = cas().tokens()
		line = "Принял %d шт., это %d %s. Золочёное я не трогаю, оно для души." % [n, got, plural(got, "жетон", "жетона", "жетонов")]
		game.sound.play("coins", 0.5, 1.2)
		game.save_game()
	refresh_buttons()

func on_spin() -> void:
	if spin_t >= 0.0: return
	var before = cas().tokens()
	result = cas().spin()
	if not bool(result.get("ok", false)):
		line = "Жетонов не хватает. Сдай шлак на «Деп», я подожду."
		return
	shown_tokens = float(before - int(game.model.data.casino.spin_cost))
	tokens_target = cas().tokens()
	var index = sector_index(str(result.sector))
	var b = sector_bounds(index)
	var mid = lerpf(b.x, b.y, 0.5 + (fposmod(float(int(result.spin)) * 0.37, 1.0) - 0.5) * 0.6)
	spin_from = fposmod(angle, TAU)
	var base = fposmod(-mid - spin_from, TAU)
	spin_to = spin_from + 4.0 * TAU + base
	spin_seconds = 1.2 if bool(game.settings.reduce_motion) else 4.2
	spin_t = 0.0
	last_sector = -1
	glow = 0.0
	line = "Крутим-вертим…"
	refresh_buttons()

func result_text() -> String:
	var r = result
	match str(r.get("kind", "")):
		"tokens": return "Жетоны: +%d" % int(r.tokens) + ("  (всё найдено, Михалыч доплачивает)" if bool(r.get("dupe", false)) else "")
		"junk":
			var names: Array = []
			for id in r.get("junk", []): names.append(str(cas().junk_def(str(id)).get("name", id)).to_lower())
			return "Шлак в мешок: " + ", ".join(names)
		"coins": return "Монеты: +%d" % int(r.coins)
		"repair": return "Ремнабор: +1 (лечит узел на 25%)"
		"golden": return "Золочёный болт!"
		"bonus": return "Бонуска: " + str(BONUS_NAME.get(str(r.get("bonus", "")), "талончик"))
		"card":
			return "Карточка гаджета: " + str(cas().card_def(str(r.card)).get("name", r.card))
	return "Пусто. Бывает."

func finish_spin() -> void:
	spin_t = -1.0
	angle = fposmod(spin_to, TAU)
	var kind = str(result.get("kind", ""))
	line = {"empty": "Бывает. Чайку?", "tokens": "Ну вот, а ты сомневался.", "junk": "Железо не пропадает, оно ждёт своего заноса.", "coins": "Звенит, значит живём.", "repair": "Пригодится, машина просила.", "golden": "Такой болт держит не рельсы, а мечты.", "bonus": "Талончик припрячь, пригодится.", "card": "ЗАНОС! Сорвал банк!"}.get(kind, "Ещё разок?")
	if kind != "empty":
		glow = 1.0
		game.sound.play("coins", 0.6, 1.0 if kind != "card" else 0.8)
	game.save_game()
	refresh_buttons()

func _process(dt: float) -> void:
	if spin_t >= 0.0:
		spin_t += dt
		var p = clampf(spin_t / spin_seconds, 0.0, 1.0)
		angle = lerpf(spin_from, spin_to, 1.0 - pow(1.0 - p, 3.0))
		var idx = sector_at(angle)
		if idx != last_sector:
			if last_sector >= 0: game.sound.play("ui_click", 0.18, 1.3)
			last_sector = idx
		if p >= 1.0: finish_spin()
	shown_tokens = move_toward(shown_tokens, float(tokens_target) if spin_t < 0.0 else shown_tokens, 40.0 * dt)
	glow = maxf(0.0, glow - dt * 0.5)
	queue_redraw()

# ---- the picture
func draw_cover(texture: Texture2D, tint: Color) -> void:
	var ts = Vector2(texture.get_width(), texture.get_height())
	var k = maxf(size.x / ts.x, size.y / ts.y)
	var draw_size = ts * k
	draw_texture_rect(texture, Rect2((size - draw_size) * 0.5, draw_size), false, tint)

func draw_text(pos: Vector2, text: String, font_size: int, color: Color, width: float = -1.0, align = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if width > 0.0:
		draw_multiline_string(game.font, pos + Vector2(1.5, 1.5), text, align, width, font_size, 3, Color(0, 0, 0, 0.6))
		draw_multiline_string(game.font, pos, text, align, width, font_size, 3, color)
		return
	draw_string(game.font, pos + Vector2(1.5, 1.5), text, align, width, font_size, Color(0, 0, 0, 0.6))
	draw_string(game.font, pos, text, align, width, font_size, color)

# 1 жетон, 2 жетона, 5 жетонов
func plural(n: int, one: String, few: String, many: String) -> String:
	var r100 = n % 100
	var r10 = n % 10
	if r100 >= 11 and r100 <= 14: return many
	if r10 == 1: return one
	if r10 >= 2 and r10 <= 4: return few
	return many

func _draw() -> void:
	draw_cover(tex.interior, Color(0.72, 0.68, 0.62))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.01, 0.30))
	# Михалыч стоит слева за стойкой
	var m: Texture2D = tex.mikhalych
	var mh = size.y * 0.80
	var mw = mh * float(m.get_width()) / float(m.get_height())
	var mpos = Vector2(size.x * 0.02, size.y - mh - 6.0 + (2.0 * sin(Time.get_ticks_msec() / 900.0)))
	draw_texture_rect(m, Rect2(mpos, Vector2(mw, mh)), false)
	# колесо
	var center = Vector2(size.x * 0.60, size.y * 0.46)
	var diameter = minf(size.y * 0.66, size.x * 0.40)
	var wheel: Texture2D = tex.wheel
	var scale = diameter / float(wheel.get_width())
	var radius = diameter * 0.5
	if glow > 0.02:
		var g = diameter * (1.5 + 0.3 * glow)
		draw_texture_rect(tex.glow, Rect2(center - Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(1, 1, 1, clampf(glow, 0.0, 1.0)))
	draw_set_transform(center, angle, Vector2.ONE)
	draw_texture_rect(wheel, Rect2(-Vector2(diameter, diameter * float(wheel.get_height()) / float(wheel.get_width())) * 0.5, Vector2(diameter, diameter * float(wheel.get_height()) / float(wheel.get_width()))), false)
	var r0 = radius * 0.19
	var r1 = radius * 0.80
	for i in range(sectors().size()):
		var s = sectors()[i]
		var b = sector_bounds(i)
		var steps = maxi(2, ceili((b.y - b.x) / 0.12))
		var points = PackedVector2Array()
		for k in range(steps + 1): points.append(Vector2.from_angle(b.x - PI * 0.5 + (b.y - b.x) * float(k) / float(steps)) * r1)
		for k in range(steps, -1, -1): points.append(Vector2.from_angle(b.x - PI * 0.5 + (b.y - b.x) * float(k) / float(steps)) * r0)
		draw_colored_polygon(points, Color(SECTOR_COLOR.get(str(s.id), Color.GRAY), 0.96))
		draw_polyline(points, Color(0.1, 0.07, 0.04, 0.9), 2.0, true)
		var width = b.y - b.x
		var mid = (b.x + b.y) * 0.5 - PI * 0.5
		if width > 0.30:
			draw_set_transform(center, angle + mid, Vector2.ONE)
			draw_string(game.font, Vector2(radius * 0.30, 7.0), str(SECTOR_TEXT.get(str(s.id), "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 19 if width > 0.5 else 15, Color("fff6dc"))
			draw_set_transform(center, angle, Vector2.ONE)
		elif width > 0.0:
			draw_line(Vector2.from_angle(mid) * r0, Vector2.from_angle(mid) * r1, Color("ffe08a"), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# указатель сверху
	var pointer: Texture2D = tex.pointer
	var ph = diameter * 0.17
	var pw = ph * float(pointer.get_width()) / float(pointer.get_height())
	draw_texture_rect(pointer, Rect2(center + Vector2(-pw * 0.5, -radius - ph * 0.55), Vector2(pw, ph)), false)
	# жетоны, гарант, строка Михалыча
	var token: Texture2D = tex.token
	draw_texture_rect(token, Rect2(Vector2(size.x * 0.40, 26.0), Vector2(46, 46)), false)
	draw_text(Vector2(size.x * 0.40 + 56.0, 60.0), "Жетоны: %d" % int(round(shown_tokens)), 28, Color("ffe9b0"))
	var pity = cas().pity()
	var pity_max = int(game.model.data.casino.pity_max)
	draw_text(Vector2(size.x * 0.40 + 56.0, 88.0), "До гарантированной карточки: %d из %d" % [pity, pity_max], 17, Color("d9cdb0"))
	draw_text(Vector2(size.x * 0.34, size.y - 104.0), line, 21, Color("fff2c8"), size.x * 0.62, HORIZONTAL_ALIGNMENT_CENTER)
	if spin_t < 0.0 and not result.is_empty():
		draw_text(Vector2(size.x * 0.34, center.y + radius + 34.0), result_text(), 24, Color("ffe08a"), size.x * 0.52, HORIZONTAL_ALIGNMENT_CENTER)
	# мешок шлака справа сверху
	var bag = cas().bag()
	var bx = size.x * 0.835
	var by = 28.0
	draw_rect(Rect2(bx - 14.0, by - 6.0, size.x * 0.165 - 12.0, 36.0 + 28.0 * float(maxi(1, mini(bag.size(), 10)))), Color(0.05, 0.04, 0.02, 0.62))
	draw_text(Vector2(bx, by + 18.0), "Мешок шлака", 19, Color("ffe9b0"))
	var row = 1
	for entry in bag:
		if row > 10: break
		var pic = int(JUNK_PICTURE.get(str(entry.id), 1))
		var jt: Texture2D = tex["junk_%d" % pic]
		draw_texture_rect(jt, Rect2(Vector2(bx, by + 8.0 + 28.0 * float(row)), Vector2(22, 22)), false)
		draw_text(Vector2(bx + 30.0, by + 26.0 + 28.0 * float(row)), "%s ×%d" % [entry.name, int(entry.count)], 15, Color("e8dcc0"))
		row += 1
	if bag.is_empty(): draw_text(Vector2(bx, by + 46.0), "пусто, ищи у рельса", 15, Color("c9bda0"))
