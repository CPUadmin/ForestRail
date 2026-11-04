extends Control
const CardView = preload("res://scripts/card_view.gd")
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
var back_button: Button
var tex = {}
var drop: Control              # the found card on the screen (nothing while no card is shown)
var mood = "calm"              # calm, happy, sad, surprised, pouring: which picture of Mikhalych is shown

const SECTOR_TEXT = {"empty": "пусто", "tokens1": "+5", "tokens2": "+10", "junk": "шлак", "coins": "монеты", "repair": "ремнабор", "golden": "золото", "bonus": "бонуска", "card": "КАРТА"}
const SECTOR_COLOR = {"empty": Color("5a4a38"), "tokens1": Color("b08a3c"), "tokens2": Color("d1a846"), "junk": Color("6b4a2e"), "coins": Color("c8b04a"), "repair": Color("3e7d78"), "golden": Color("f0c640"), "bonus": Color("7a4d8c"), "card": Color("d03a2e")}
# какая картинка листа шлака ближе всего к виду хлама (для строки в мешке)
const JUNK_PICTURE = {"rusty_bolt": 1, "bearing_cover": 2, "tie_plate": 4, "brake_shoe": 6, "rail_clip": 7, "cracked_lantern": 8, "stationmaster_watch": 9, "track_spike": 1, "fishplate": 5}
const BONUS_NAME = {"spin": "халявная крутка", "x2": "иксы на ставку", "junk": "шлак в мешок", "tea": "чайку!"}

var plaque_cache = {}

func plaque_box(alpha: float) -> StyleBoxFlat:
	var key = str(alpha)
	if plaque_cache.has(key): return plaque_cache[key]
	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.065, 0.03, alpha)
	box.border_color = Color("c9a24e")
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 4)
	plaque_cache[key] = box
	return box

# wood-and-brass buttons instead of the flat green ones
func brass_button(button: Button, hot: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box = StyleBoxFlat.new()
		var base = Color("6b4423") if hot else Color("3b2814")
		if state == "hover": base = base.lightened(0.15)
		if state == "pressed": base = base.darkened(0.2)
		if state == "disabled": base = Color("2a2118")
		box.bg_color = base
		box.border_color = Color("d8b258") if state != "disabled" else Color("6b5a3a")
		box.set_border_width_all(3)
		box.set_corner_radius_all(10)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 5
		box.shadow_offset = Vector2(0, 3)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("fff1cc"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("8a7c5c"))
	button.add_theme_font_size_override("font_size", 20)

func cas():
	return game.model.casino()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for name in ["facade", "interior", "wheel", "pointer", "glow", "mikhalych", "mikhalych_happy", "mikhalych_sad", "mikhalych_surprised", "mikhalych_pouring", "token", "bag"]:
		tex[name] = load("res://assets/art_kazik/%s.png" % name)
	for id in SECTOR_COLOR.keys(): tex["sector_" + str(id)] = load("res://assets/art_kazik/sector_%s.png" % str(id))
	for i in range(1, 10): tex["junk_%d" % i] = load("res://assets/art_kazik/junk_%d.png" % i)
	shown_tokens = float(cas().tokens())
	tokens_target = cas().tokens()
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.position = Vector2(size.x * 0.30, size.y - 74.0)
	row.size = Vector2(size.x * 0.66, 56)
	add_child(row)
	spin_button = game.add_button(row, "Крутануть", Callable(self, "on_spin"))
	dep_button = game.add_button(row, "Деп", Callable(self, "on_deposit"))
	back_button = game.add_button(row, "Назад в депо", game.close_modal)
	brass_button(spin_button, true)
	brass_button(dep_button, false)
	brass_button(back_button, false)
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
		mood = "pouring"
		line = "Принял %d шт., это %d %s. Золочёное я не трогаю, оно для души." % [n, got, plural(got, "жетон", "жетона", "жетонов")]
		game.sound.play("coins", 0.5, 1.2)
		game.save_game()
	refresh_buttons()

func on_spin() -> void:
	if spin_t >= 0.0: return
	close_drop()
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
	mood = "calm"
	line = "Крутим-вертим…"
	refresh_buttons()

# the found Tarot card: it comes out face down, turns over and the player takes it with a click
func show_drop() -> void:
	close_drop()
	drop = Control.new()
	drop.size = size
	add_child(drop)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.size = size
	drop.add_child(shade)
	var card = CardView.new()
	card.game = game
	card.card_id = str(result.get("card", ""))
	card.show_back = true
	var h = size.y * 0.76
	card.size = Vector2(h / 1.59, h)
	card.position = Vector2(size.x * 0.5 - card.size.x * 0.5, size.y * 0.08)
	drop.add_child(card)
	var hint = Label.new()
	hint.text = "Нажми, чтобы забрать"
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color("ffe9b0"))
	hint.size = Vector2(size.x, 36)
	hint.position = Vector2(0, size.y * 0.08 + h + 10.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop.add_child(hint)
	var take = Button.new()
	take.flat = true
	take.size = size
	take.pressed.connect(close_drop)
	drop.add_child(take)
	var quick = bool(game.settings.reduce_motion)
	get_tree().create_timer(0.7).timeout.connect(func(): if is_instance_valid(card): card.flip(quick))

func close_drop() -> void:
	if drop != null and is_instance_valid(drop): drop.queue_free()
	drop = null

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
	mood = {"empty": "sad", "card": "surprised", "golden": "surprised"}.get(kind, "happy")
	if kind == "card": show_drop()
	if kind == "card":
		var probe = CardView.new()
		probe.card_id = str(result.get("card", ""))
		var said = probe.found_line()
		probe.free()
		if said != "": line = "ЗАНОС! " + said
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

func plaque(rect: Rect2, alpha: float = 0.92) -> void:
	draw_style_box(plaque_box(alpha), rect)
	draw_rect(rect.grow(-5.0), Color(1, 0.85, 0.5, 0.10), false, 1.5)

# the painted-looking sector: the colour deepens towards the hub, a light edge at the rim, brass dividers
func draw_sector(i: int, r0: float, r1: float) -> void:
	var s = sectors()[i]
	var b = sector_bounds(i)
	var base: Color = SECTOR_COLOR.get(str(s.id), Color.GRAY)
	var steps = maxi(2, ceili((b.y - b.x) / 0.08))
	var rings = 12
	for ring in range(rings):
		var ra = lerpf(r0, r1, float(ring) / float(rings))
		var rb = lerpf(r0, r1, float(ring + 1) / float(rings))
		var shade = lerpf(0.66, 1.10, float(ring + 1) / float(rings))
		var points = PackedVector2Array()
		for k in range(steps + 1): points.append(Vector2.from_angle(b.x - PI * 0.5 + (b.y - b.x) * float(k) / float(steps)) * rb)
		for k in range(steps, -1, -1): points.append(Vector2.from_angle(b.x - PI * 0.5 + (b.y - b.x) * float(k) / float(steps)) * ra)
		draw_colored_polygon(points, Color(clampf(base.r * shade, 0, 1), clampf(base.g * shade, 0, 1), clampf(base.b * shade, 0, 1), 1.0))
	# a light line on the rim side and a dark one near the hub give the carved look
	var rim = PackedVector2Array()
	var hub = PackedVector2Array()
	for k in range(steps + 1):
		var a = b.x - PI * 0.5 + (b.y - b.x) * float(k) / float(steps)
		rim.append(Vector2.from_angle(a) * (r1 - 2.0))
		hub.append(Vector2.from_angle(a) * (r0 + 2.0))
	draw_polyline(rim, Color(1, 0.92, 0.7, 0.35), 3.0, true)
	draw_polyline(hub, Color(0, 0, 0, 0.5), 3.0, true)

func _draw() -> void:
	draw_cover(tex.interior, Color(0.70, 0.66, 0.60))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.01, 0.34))
	# Михалыч стоит слева, поменьше: главное тут колесо
	var m: Texture2D = tex["mikhalych" if mood == "calm" else "mikhalych_" + mood]
	var mh = size.y * 0.70
	var mw = mh * float(m.get_width()) / float(m.get_height())
	var mpos = Vector2(size.x * 0.015, size.y - mh - 8.0 + (2.0 * sin(Time.get_ticks_msec() / 900.0)))
	draw_texture_rect(m, Rect2(mpos, Vector2(mw, mh)), false)
	# колесо
	var center = Vector2(size.x * 0.635, size.y * 0.43)
	var diameter = minf(size.y * 0.70, size.x * 0.40)
	var wheel: Texture2D = tex.wheel
	var radius = diameter * 0.5
	if glow > 0.02:
		var g = diameter * (1.5 + 0.3 * glow)
		draw_texture_rect(tex.glow, Rect2(center - Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(1, 1, 1, clampf(glow, 0.0, 1.0)))
	# a soft shadow of the wheel on the wall
	draw_circle(center + Vector2(10, 14), radius * 1.02, Color(0, 0, 0, 0.35))
	draw_set_transform(center, angle, Vector2.ONE)
	var wh = diameter * float(wheel.get_height()) / float(wheel.get_width())
	draw_texture_rect(wheel, Rect2(-Vector2(diameter, wh) * 0.5, Vector2(diameter, wh)), false)
	var r0 = radius * 0.19
	var r1 = radius * 0.80
	for i in range(sectors().size()): draw_sector(i, r0, r1)
	# the brass dividers with a stud at the rim end
	for i in range(sectors().size()):
		var b = sector_bounds(i)
		var a = b.x - PI * 0.5
		draw_line(Vector2.from_angle(a) * r0, Vector2.from_angle(a) * r1, Color(0.08, 0.05, 0.02, 0.9), 5.0, true)
		draw_line(Vector2.from_angle(a) * r0, Vector2.from_angle(a) * r1, Color("d8b258"), 2.2, true)
		draw_circle(Vector2.from_angle(a) * (r1 + 2.0), 6.0, Color("2a1a08"))
		draw_circle(Vector2.from_angle(a) * (r1 + 2.0), 4.4, Color("e8c66a"))
		draw_circle(Vector2.from_angle(a) * (r1 + 1.0) + Vector2(-1.2, -1.2), 1.6, Color("fff4c8"))
	# the labels read upright on both halves of the wheel
	for i in range(sectors().size()):
		var s = sectors()[i]
		var b = sector_bounds(i)
		var width = b.y - b.x
		var mid = (b.x + b.y) * 0.5 - PI * 0.5
		if width > 0.30:
			# the painted icon of the sector, its top pointing to the rim
			var icon: Texture2D = tex["sector_" + str(s.id)]
			var icon_size = clampf(width * radius * 0.46, 40.0, radius * 0.40)
			draw_set_transform(center, angle + mid + PI * 0.5, Vector2.ONE)
			draw_texture_rect(icon, Rect2(Vector2(-icon_size * 0.5, -radius * 0.50 - icon_size * 0.5), Vector2(icon_size, icon_size)), false)
			draw_set_transform(center, angle, Vector2.ONE)
		elif width > 0.0:
			draw_line(Vector2.from_angle(mid) * (r0 + 6.0), Vector2.from_angle(mid) * (r1 - 4.0), Color("ffe08a"), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# light from the upper left over the whole face: the wheel is one object, not a picture with a sticker
	draw_circle(center + Vector2(-radius * 0.22, -radius * 0.26), radius * 0.62, Color(1, 0.95, 0.8, 0.06))
	# the pointer on top, larger
	var pointer: Texture2D = tex.pointer
	var ph = diameter * 0.20
	var pw = ph * float(pointer.get_width()) / float(pointer.get_height())
	draw_texture_rect(pointer, Rect2(center + Vector2(-pw * 0.5, -radius - ph * 0.60), Vector2(pw, ph)), false)
	# the tokens and the guarantee on a plaque at the top, to the left of the wheel
	var tp = Rect2(Vector2(size.x * 0.30, 18.0), Vector2(size.x * 0.20, 82.0))
	plaque(tp)
	draw_texture_rect(tex.token, Rect2(tp.position + Vector2(12, 14), Vector2(54, 54)), false)
	draw_text(tp.position + Vector2(76, 42), "Жетоны: %d" % int(round(shown_tokens)), 30, Color("ffe9b0"))
	var pity = cas().pity()
	var pity_max = int(game.model.data.casino.pity_max)
	draw_text(tp.position + Vector2(76, 68), "гарант карточки: %d из %d" % [pity, pity_max], 16, Color("d9cdb0"))
	# the result and the words of Mikhalych on a plaque under the wheel
	var rp = Rect2(Vector2(size.x * 0.40, size.y * 0.795), Vector2(size.x * 0.46, size.y * 0.085))
	plaque(rp)
	if spin_t < 0.0 and not result.is_empty():
		draw_text(rp.position + Vector2(16, rp.size.y * 0.42), result_text(), 22, Color("ffe08a"), rp.size.x - 32.0, HORIZONTAL_ALIGNMENT_CENTER)
		draw_text(rp.position + Vector2(16, rp.size.y * 0.80), line, 17, Color("fff2c8"), rp.size.x - 32.0, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		draw_text(rp.position + Vector2(16, rp.size.y * 0.62), line, 20, Color("fff2c8"), rp.size.x - 32.0, HORIZONTAL_ALIGNMENT_CENTER)
	# the bag of junk on a plaque at the right
	var bag = cas().bag()
	var rows = maxi(1, mini(bag.size(), 8))
	var bag_w = maxf(size.x * 0.14, 210.0)
	var bp = Rect2(Vector2(size.x - bag_w - 12.0, 18.0), Vector2(bag_w, 52.0 + 28.0 * float(rows)))
	plaque(bp)
	draw_text(bp.position + Vector2(14, 30), "Мешок шлака", 19, Color("ffe9b0"))
	var bagtex: Texture2D = tex.bag
	draw_texture_rect(bagtex, Rect2(bp.position + Vector2(bp.size.x - 52.0, 4.0), Vector2(44, 44.0 * float(bagtex.get_height()) / float(bagtex.get_width()))), false)
	var row = 0
	for entry in bag:
		if row >= 8: break
		var pic = int(JUNK_PICTURE.get(str(entry.id), 1))
		var jt: Texture2D = tex["junk_%d" % pic]
		draw_texture_rect(jt, Rect2(bp.position + Vector2(12, 42.0 + 28.0 * float(row)), Vector2(24, 24)), false)
		draw_text(bp.position + Vector2(44, 60.0 + 28.0 * float(row)), "%s ×%d" % [entry.name, int(entry.count)], 14, Color("e8dcc0"))
		row += 1
	if bag.is_empty(): draw_text(bp.position + Vector2(14, 66), "пусто: ищи у рельса", 15, Color("c9bda0"))
