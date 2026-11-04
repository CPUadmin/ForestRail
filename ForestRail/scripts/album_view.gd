extends Control
# Альбом карточек Таро Михалыча (docs/KAZIK_CARDS_RU.md, этап «д»): 22 места, выбитые лицом, остальные рубашкой вверх.
# Щелчок по выбитой карточке открывает её крупно с репликой Михалыча. Что выбито, решает Casino (state.casino.cards).

const CardView = preload("res://scripts/card_view.gd")
const SECRET_IDS = ["moon", "sun", "judgement", "world"]

var game
var views: Dictionary = {}
var detail: Control
var detail_card: Control
var close_button: Button

func cas():
	return game.model.casino()

func all_ids() -> Array:
	var ids: Array = []
	for card in game.model.data.casino.cards: ids.append(str(card.id))
	return ids + SECRET_IDS

func owned(id: String) -> bool:
	return cas().card_owned(id)

func owned_count() -> int:
	var n = 0
	for id in all_ids():
		if owned(str(id)): n += 1
	return n

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back = ColorRect.new()
	back.color = Color(0.07, 0.05, 0.03, 1.0)
	back.size = size
	add_child(back)
	var title = Label.new()
	title.text = "Альбом Михалыча: колода Таро (%d из %d)" % [owned_count(), all_ids().size()]
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ffe9b0"))
	title.position = Vector2(30, 14)
	add_child(title)
	var ids = all_ids()
	var columns = 8
	var rows = int(ceil(float(ids.size()) / float(columns)))
	var gap = 10.0
	var top = 64.0
	var card_h = minf((size.y - top - 70.0 - gap * float(rows - 1)) / float(rows), (size.x - 40.0 - gap * float(columns - 1)) / float(columns) * 1.59)
	var card_w = card_h / 1.59
	var left = (size.x - (card_w * columns + gap * (columns - 1))) * 0.5
	for i in range(ids.size()):
		var id = str(ids[i])
		var view = CardView.new()
		view.game = game
		view.card_id = id
		view.revealed = owned(id)
		view.size = Vector2(card_w, card_h)
		view.position = Vector2(left + float(i % columns) * (card_w + gap), top + float(i / columns) * (card_h + gap))
		add_child(view)
		views[id] = view
		var hit = Button.new()
		hit.flat = true
		hit.size = view.size
		hit.position = view.position
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.disabled = not view.revealed
		hit.pressed.connect(func(): show_card(id))
		add_child(hit)
	close_button = game.add_button(self, "Назад", Callable(self, "on_close"))
	close_button.position = Vector2(size.x - 220.0, size.y - 60.0)
	close_button.size = Vector2(190, 46)

func on_close() -> void:
	if detail != null:
		detail.queue_free()
		detail = null
		return
	game.close_modal()

# the big card with the line of Mikhalych
func show_card(id: String) -> void:
	if detail != null: detail.queue_free()
	detail = Control.new()
	detail.size = size
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(detail)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.size = size
	detail.add_child(shade)
	var h = size.y - 150.0
	var view = CardView.new()
	view.game = game
	view.card_id = id
	view.size = Vector2(h / 1.59, h)
	view.position = Vector2(size.x * 0.5 - view.size.x - 30.0, 40.0)
	detail.add_child(view)
	detail_card = view
	var turn = Button.new()
	turn.flat = true
	turn.size = view.size
	turn.position = view.position
	turn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	turn.pressed.connect(func(): view.flip(bool(game.settings.reduce_motion)))
	detail.add_child(turn)
	var data = view.info()
	var text = Label.new()
	text.text = "%s\n\n%s\n\n«%s»\n\n— Михалыч\n\nНажми на карточку, чтобы перевернуть." % [str(data.name), str(data.gadget), str(data.quote)]
	text.add_theme_font_size_override("font_size", 26)
	text.add_theme_color_override("font_color", Color("fff1cc"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.position = Vector2(size.x * 0.5 + 10.0, 120.0)
	text.size = Vector2(size.x * 0.40, 360.0)
	detail.add_child(text)
	var bring_to_front = close_button
	if bring_to_front != null: move_child(bring_to_front, get_child_count() - 1)
