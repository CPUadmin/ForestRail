extends Control
# Карточка Таро Михалыча (docs/KAZIK_CARDS_RU.md): картина в окне рамки, сверху римская цифра, снизу название аркана,
# гаджет и реплика Михалыча. Только показ: что выбито, решает Casino. Рамка и рубашка нарисованы GPT (пакет П9б),
# картины арканов приходят пакетом П10 в assets/art_kazik/cards/<id>.png; пока их нет, в окне заглушка.

var game
var card_id = "fool"
var revealed = true            # false: карточка ещё не открыта, на её месте пустой слот
var show_back = false          # true: открытая карточка лежит рубашкой вверх (только значок гаджета)
var flip_p = -1.0              # ход переворота 0..1, -1: карточка не крутится
var flip_seconds = 0.55
var flip_to_back = false
var flip_switched = false
var boxes: Dictionary = {}
signal flipped
var art: Texture2D
var frame: Texture2D
var back: Texture2D
var icon: Texture2D            # the picture of the gadget: it lies on the back of the card

# окно картинки и таблички в долях рамки (измерено по прозрачному окну card_frame.png)
const WINDOW = Rect2(0.076, 0.182, 0.846, 0.486)
const RIBBON = Rect2(0.24, 0.085, 0.52, 0.062)
const PLAQUE = Rect2(0.10, 0.752, 0.80, 0.172)

# тайные арканы: в игре их пока нет, но место в альбоме и рамка готовы
const SECRET = {
	"moon": {"arcana": "XVIII", "name": "Луна", "gadget": "Тайная карта", "quote": "Ночью рельсы длиннее. Это не точно."},
	"sun": {"arcana": "XIX", "name": "Солнце", "gadget": "Тайная карта", "quote": "Ровно и тепло. Так бы всегда."},
	"judgement": {"arcana": "XX", "name": "Суд", "gadget": "Тайная карта", "quote": "Суд решил. Приговор: ещё по чаю."},
	"world": {"arcana": "XXI", "name": "Мир", "gadget": "Тайная карта", "quote": "Всё собрано. Казик закрыт на чай."},
}

# что говорит Михалыч, когда карта выпала: узнаёт на ней своих (лор: docs/KAZIK_CARDS_RU.md, раздел 9)
const FOUND = {
	"fool": "О... Дымок! Помню, как по моей комнате ходил.",
	"magician": "Фокус-покус! Колесо крутится - уголь мутится.",
	"empress": "А жинка-то запасливая была...",
	"hierophant": "По нормативу давление держаться должно... А нервы в норматив не входили.",
	"lovers": "О, это Нинка, жинка моя... Эх. Только с ней так храпел.",
	"strength": "Почувствуй силушку богатырскую!",
	"death": "Как-то практикант спросил, когда мы тестировали: «А парашют выдержит?» Ну а я ему: парашют выдержит, трусы не выдержат.",
	"devil": "Форсаааж! ФАЙЯ! *играет рок*",
	"tower": "Помню друга-матроса... Мы даже песню сочинили. Как там было... «Плыли мы по морю, ветер мачту рвал, капитан З...» Забыл, короче.",
}

const QUOTE = {
	"fool": "Прыгай! Земля сама подстелется. Обычно.",
	"magician": "Фокус. Ты крутил, а колесо само.",
	"priestess": "Она слышит ветер. А ты слышишь только щёлканье.",
	"empress": "Запас карман не тянет. Запас кладовую набивает.",
	"emperor": "Порядок наконец-то. Дай коробке самой разобраться.",
	"hierophant": "По уставу. Давление держим, нервы не держим.",
	"lovers": "Туда-сюда, как у людей.",
	"chariot": "Вот это рывок! Конденсаторы в восторге.",
	"strength": "Нитро: кричит, но слушается.",
	"hermit": "Огонёк в руке, цеппелин в небе. Тише едешь.",
	"wheel": "Колесо крутится. Не то, на которое ты смотришь.",
	"justice": "Холодная голова. Остужай мотор, не себя.",
	"hanged": "Тянет тебя вверх ногами, а ты и рад.",
	"death": "Не пугайся. Это только парашют.",
	"temperance": "Меньше угля, больше чая.",
	"devil": "Форсаж! Огонь не обманывает. Почти.",
	"tower": "Красиво. Ненадолго. Держись за мачту.",
	"star": "Вот-вот взлетишь. Я верю.",
}

func _ready() -> void:
	set_process(false)
	frame = load("res://assets/art_kazik/card_frame.png")
	back = load("res://assets/art_kazik/sector_card.png")
	var icon_path = "res://assets/art_kazik/gadget_icons/%s.png" % card_id
	if ResourceLoader.exists(icon_path): icon = load(icon_path)
	var path = "res://assets/art_kazik/cards/%s.png" % card_id
	if ResourceLoader.exists(path): art = load(path)

# the line when this card has just been won
func found_line() -> String:
	if FOUND.has(card_id): return str(FOUND[card_id])
	return str(QUOTE.get(card_id, ""))

func info() -> Dictionary:
	if SECRET.has(card_id): return SECRET[card_id]
	var card: Dictionary = game.model.casino().card_def(card_id)
	var gadget = "скоро в мастерской"
	for branch in game.model.data.upgrade_catalog:
		if str(branch.id) == str(card.get("upgrade", "")): gadget = str(branch.name)
	return {"arcana": str(card.get("arcana", "")), "name": str(card.get("name", card_id)), "gadget": gadget, "quote": found_line()}

func part(rect: Rect2) -> Rect2:
	return Rect2(rect.position * size, rect.size * size)

func text_line(text: String, rect: Rect2, font_size: int, color: Color, y: float) -> void:
	var k = size.x / 566.0
	var fs = maxi(8, int(round(font_size * k)))
	var width = rect.size.x
	game_text(Vector2(rect.position.x, y), text, fs, color, width)

func game_text(pos: Vector2, text: String, fs: int, color: Color, width: float) -> void:
	draw_multiline_string(game.font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, 2, Color(0, 0, 0, 0.7))
	draw_multiline_string(game.font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, 2, color)

func _process(dt: float) -> void:
	if flip_p < 0.0:
		set_process(false)
		return
	flip_p += dt / flip_seconds
	if flip_p >= 0.5 and not flip_switched:
		flip_switched = true
		show_back = flip_to_back
	if flip_p >= 1.0:
		flip_p = -1.0
		flip_switched = false
		set_process(false)
		flipped.emit()
	queue_redraw()

# turn the card over: the width shrinks to a line, the other side comes up (0.55 s, 0.01 s when the player asked for less motion)
func flip(instant: bool = false) -> void:
	if flip_p >= 0.0 or not revealed: return
	flip_to_back = not show_back
	if instant:
		show_back = flip_to_back
		flipped.emit()
		queue_redraw()
		return
	flip_p = 0.0
	flip_switched = false
	set_process(true)

func box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var key = "%s|%s|%d|%d" % [fill.to_html(), border.to_html(), width, radius]
	if boxes.has(key): return boxes[key]
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	boxes[key] = style
	return style

# the place of a card that is not found yet: an empty slot with a dashed edge, only the numeral says what belongs here
func draw_slot() -> void:
	var k = size.x / 566.0
	draw_style_box(box(Color(0.06, 0.05, 0.035, 0.78), Color(0.35, 0.27, 0.12, 0.0), 0, int(38.0 * k)), Rect2(Vector2.ZERO, size).grow(-6.0 * k))
	var r = Rect2(Vector2.ZERO, size).grow(-14.0 * k)
	var dash = 18.0 * k
	var color = Color(0.62, 0.50, 0.24, 0.55)
	var x = r.position.x
	while x < r.end.x:
		var x2 = minf(x + dash, r.end.x)
		draw_line(Vector2(x, r.position.y), Vector2(x2, r.position.y), color, 3.0 * k)
		draw_line(Vector2(x, r.end.y), Vector2(x2, r.end.y), color, 3.0 * k)
		x += dash * 2.0
	var y = r.position.y
	while y < r.end.y:
		var y2 = minf(y + dash, r.end.y)
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x, y2), color, 3.0 * k)
		draw_line(Vector2(r.end.x, y), Vector2(r.end.x, y2), color, 3.0 * k)
		y += dash * 2.0
	var arc = str(info().arcana)
	var big = int(round(size.x * 0.34))
	var w = game.font.get_string_size(arc, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	draw_string(game.font, Vector2((size.x - w) * 0.5, size.y * 0.5 + big * 0.35), arc, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(0.80, 0.64, 0.30, 0.22))
	text_line("Ещё не открыта", Rect2(size.x * 0.10, 0.0, size.x * 0.80, 1.0), 24, Color(0.84, 0.76, 0.58, 0.7), size.y * 0.86)

# the back of a card: one picture, the gadget, on a sunburst with a brass medallion; no words
func draw_back() -> void:
	var k = size.x / 566.0
	var body = Rect2(Vector2.ZERO, size).grow(-4.0 * k)
	draw_style_box(box(Color(0.08, 0.16, 0.11), Color("c9a24e"), maxi(2, int(round(12.0 * k))), int(40.0 * k)), body)
	draw_style_box(box(Color(0, 0, 0, 0), Color(0.78, 0.62, 0.30, 0.65), maxi(1, int(round(3.0 * k))), int(28.0 * k)), body.grow(-24.0 * k))
	var c = size * 0.5
	for i in range(20):
		var a = TAU * float(i) / 20.0
		draw_line(c + Vector2.from_angle(a) * size.x * 0.20, c + Vector2.from_angle(a) * size.x * 0.58, Color(0.80, 0.64, 0.30, 0.16), maxf(2.0, 6.0 * k))
	for rr in [0.43, 0.36]:
		draw_arc(c, size.x * rr, 0.0, TAU, 48, Color(0.80, 0.64, 0.30, 0.55), maxf(2.0, 5.0 * k), true)
	draw_circle(c, size.x * 0.34, Color(0.05, 0.10, 0.07, 0.92))
	var side = size.x * 0.52
	var mark: Texture2D = icon if icon != null else back
	draw_texture_rect(mark, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false)
	for corner in [Vector2(0.12, 0.08), Vector2(0.88, 0.08), Vector2(0.12, 0.92), Vector2(0.88, 0.92)]:
		draw_circle(corner * size, 9.0 * k, Color("e8c66a"))
		draw_circle(corner * size, 5.0 * k, Color(0.30, 0.20, 0.06))
	var data = info()
	var arc = str(data.arcana)
	var fs = maxi(10, int(round(34.0 * k)))
	var w = game.font.get_string_size(arc, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(game.font, Vector2((size.x - w) * 0.5, size.y * 0.915), arc, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.84, 0.52, 0.9))

func draw_face() -> void:
	var window = part(WINDOW)
	if art != null:
		var ts = Vector2(art.get_width(), art.get_height())
		var k = maxf(window.size.x / ts.x, window.size.y / ts.y)
		var cover = ts * k
		var source = Rect2((cover - window.size) * 0.5 / k, window.size / k)
		draw_texture_rect_region(art, window, source)
	else:
		# заглушка: тёмный бархат с тёплым пятном света; картинку принесёт пакет П10
		draw_rect(window, Color(0.07, 0.12, 0.09))
		for i in range(6):
			var r = window.size.y * (0.50 - 0.07 * float(i))
			draw_circle(window.get_center() + Vector2(0, -window.size.y * 0.06), r, Color(0.55, 0.40, 0.15, 0.05))
		var arc = str(info().arcana)
		var big = int(round(window.size.y * 0.40))
		var w = game.font.get_string_size(arc, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		draw_string(game.font, window.get_center() + Vector2(-w * 0.5, big * 0.35), arc, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(0.80, 0.64, 0.30, 0.38))
	draw_texture_rect(frame, Rect2(Vector2.ZERO, size), false)
	var data = info()
	var rib = part(RIBBON)
	text_line(str(data.arcana), rib, 32, Color("f3e3b0"), rib.position.y + rib.size.y * 1.12)
	var pl = part(PLAQUE)
	var k = size.x / 566.0
	# как на настоящей карте Таро: крупное название, под ним мелко гаджет; реплика Михалыча живёт в подписи под карточкой (info().quote)
	text_line(str(data.name).to_upper(), pl, 44, Color("ffe9b0"), pl.position.y + 58.0 * k)
	text_line(str(data.gadget), pl, 24, Color("d9cdb0"), pl.position.y + 112.0 * k)

func _draw() -> void:
	var s = 1.0
	if flip_p >= 0.0: s = maxf(0.03, absf(cos(PI * flip_p)))
	draw_set_transform(Vector2(size.x * 0.5 * (1.0 - s), 0.0), 0.0, Vector2(s, 1.0))
	if not revealed: draw_slot()
	elif show_back: draw_back()
	else: draw_face()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
