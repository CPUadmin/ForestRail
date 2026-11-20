extends RefCounted
# Помощник main.gd (1.3.7): лист результата рейса: картинки, медали, состав.
# Работает через canvas (main.gd), как depot_ui.gd.

var canvas = null   # main.gd

func _init(owner_canvas) -> void:
	canvas = owner_canvas

# ui-v2 (owner 14.11: «для экрана результата нужны специальные ассеты»; P22 painted by GPT): the evening platform
# with the greeting, the waybill with the trip written on its lines, the stamp (on time or late), the coins and the medals
const RESULT_ART = {
	"banner": preload("res://assets/art_result/banner.png"), "waybill": preload("res://assets/art_result/waybill.png"),
	"stamp_ok": preload("res://assets/art_result/stamp_ok.png"), "stamp_late": preload("res://assets/art_result/stamp_late.png"),
	"coins_small": preload("res://assets/art_result/coins_small.png"), "coins_big": preload("res://assets/art_result/coins_big.png"),
	"medal_on_time": preload("res://assets/art_result/medal_on_time.png"), "medal_night": preload("res://assets/art_result/medal_night.png"),
	"medal_heavy": preload("res://assets/art_result/medal_heavy.png"), "medal_first": preload("res://assets/art_result/medal_first.png"),
	"medal_smooth": preload("res://assets/art_result/medal_brakes.png")}
const MEDAL_NAMES = {"on_time": "Раньше срока", "night": "Ночной рейс", "heavy": "Тяжёлый груз", "first": "Первый основной рейс", "smooth": "Плавный рейс"}
const SHEET_INK = Color("3a2a18")

# A card with the picture of the machine or wagon on its left; returns the box for the text and buttons.
func picture_card(parent: Node, id: String, bright: bool, edge: Color) -> VBoxContainer:
	var outer = canvas.card(parent, edge)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	outer.add_child(row)
	var picture = TextureRect.new()
	picture.texture = canvas.art.textures[canvas.art.body_key(id)]
	picture.custom_minimum_size = Vector2(150.0, 78.0) * float(canvas.settings.text_scale)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.modulate = Color.WHITE if bright else Color(1, 1, 1, 0.55)
	row.add_child(picture)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	return info

func sheet_label(parent: Control, text: String, at: Rect2, font_size: int, color: Color = SHEET_INK, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label = Label.new()
	label.text = text
	label.position = at.position
	label.size = at.size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", int(font_size * float(canvas.settings.text_scale)))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(label)
	return label

func sheet_picture(parent: Control, texture: Texture2D, at: Rect2, tint: Color = Color.WHITE) -> TextureRect:
	var picture = TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # first: otherwise the size is held at the size of the texture
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.position = at.position
	picture.size = at.size
	picture.modulate = tint
	picture.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(picture)
	return picture

func build_result_sheet(box: VBoxContainer, result: Dictionary, screen: Vector2, width: float) -> void:
	var final = bool(result.get("final", false))
	var late = bool(result.get("late", false))
	var reward = int(result.get("reward", 0))
	var greeting = "Линия работает" if final else ("Рейс сорван" if late else "С возвращением")
	# the banner only when the screen is tall enough; on a small one the greeting is a plain title
	var sheet_w = minf(width - 48.0, 820.0)
	var tall = screen.y >= 860.0
	# the sheet takes what is left of the height: the panel, the greeting, the medals, the finds, the button
	var reserved = 160.0 + 40.0 + 80.0 * float(canvas.settings.text_scale) + (150.0 if tall else 50.0 * float(canvas.settings.text_scale))
	if not tall and not result.get("medals", []).is_empty(): reserved += 90.0
	if not result.get("finds", []).is_empty(): reserved += 40.0 * float(canvas.settings.text_scale)
	sheet_w = maxf(360.0, minf(sheet_w, (screen.y - reserved) * 1263.0 / 767.0))
	if tall:
		var banner = Control.new()
		banner.custom_minimum_size = Vector2(0, 150)
		banner.clip_contents = true
		box.add_child(banner)
		var picture = TextureRect.new()
		picture.texture = RESULT_ART.banner
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.add_child(picture)
		var shade = ColorRect.new()
		shade.color = Color(0.03, 0.02, 0.01, 0.35)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.add_child(shade)
		var title = Label.new()
		title.text = greeting
		title.add_theme_font_size_override("font_size", int(40 * float(canvas.settings.text_scale)))
		title.add_theme_color_override("font_color", Color("f5e2b0"))
		title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 0.9))
		title.add_theme_constant_override("outline_size", 8)
		title.position = Vector2(24, 12)
		banner.add_child(title)
		# the medals of the trip hang from the top edge of the banner, on the right
		var hanging = HBoxContainer.new()
		hanging.add_theme_constant_override("separation", 12)
		banner.add_child(hanging)
		medal_row(hanging, result.get("medals", []), Vector2(62, 86))
		var hang_w = hanging.get_combined_minimum_size().x
		hanging.anchor_left = 1.0
		hanging.anchor_right = 1.0
		hanging.offset_left = -hang_w - 22.0
		hanging.offset_right = -22.0
		hanging.offset_top = 0.0
		hanging.offset_bottom = 86.0
	else:
		canvas.add_label(box, greeting, 34)
	var holder = CenterContainer.new()
	box.add_child(holder)
	var sheet = Control.new()
	var w = sheet_w
	var h = w * 767.0 / 1263.0
	sheet.custom_minimum_size = Vector2(w, h)
	holder.add_child(sheet)
	sheet_picture(sheet, RESULT_ART.waybill, Rect2(0, 0, w, h))
	# the lines of the waybill (fractions of the picture): x 0.125..0.493, y 0.302, 0.394, 0.482, 0.570, 0.652, 0.735
	var lx = w * 0.125
	var lw = w * 0.37
	var line_y = [0.302, 0.394, 0.482, 0.570, 0.652, 0.735]
	var title_text = "До Дальнего бора снова ходят поезда" if final else str(result.get("title", "Рейс окончен"))
	var title_label = sheet_label(sheet, title_text, Rect2(lx, h * 0.13, w * 0.74, h * 0.15), 22)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.tooltip_text = title_text
	var notes: Array = result.get("notes", [])
	var row = 0
	for note in notes.slice(0, 3):
		sheet_label(sheet, str(note), Rect2(lx, h * line_y[row] + 2.0, lw, h * (line_y[row + 1] - line_y[row]) - 4.0), 17, Color("7a2a1a") if late else SHEET_INK)
		row += 1
	var totals: Dictionary = canvas.model.state.get("stats", {})
	var stats = ["доставлено всего: %d" % int(totals.get("deliveries", 0)), "пройдено: %.1f км" % (float(totals.get("distance", 0.0)) / 1000.0), "основные рейсы: %d из 10" % int(canvas.model.state.get("chapter", 0))]
	for line in stats:
		if row >= line_y.size() - 1: break
		sheet_label(sheet, line, Rect2(lx, h * line_y[row] + 2.0, lw, h * (line_y[row + 1] - line_y[row]) - 4.0), 16, Color("5a4a34"))
		row += 1
	# the pay: the coins and the sum in the free right half
	var coins = RESULT_ART.coins_big if reward >= 300 else RESULT_ART.coins_small
	if reward > 0: sheet_picture(sheet, coins, Rect2(w * 0.52, h * 0.29, w * 0.17, h * 0.27))
	var pay_x = w * 0.68 if reward > 0 else w * 0.55
	var pay_w = w * 0.22 if reward > 0 else w * 0.35
	var pay = sheet_label(sheet, ("+%d" % reward) if reward >= 0 else ("−%d" % -reward), Rect2(pay_x, h * 0.29, pay_w, h * 0.18), 44, Color("8a5a12") if reward >= 0 else Color("8a2a1a"), HORIZONTAL_ALIGNMENT_CENTER)
	pay.clip_text = false
	pay.autowrap_mode = TextServer.AUTOWRAP_OFF
	pay.tooltip_text = "Оплата за рейс, монет"
	sheet_label(sheet, "монет", Rect2(pay_x, h * 0.47, pay_w, h * 0.07), 16, Color("5a4a34"), HORIZONTAL_ALIGNMENT_CENTER).vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# the stamp sits in its circle, a little turned
	var stamp = sheet_picture(sheet, RESULT_ART.stamp_late if late else RESULT_ART.stamp_ok, Rect2(w * 0.81 - h * 0.14, h * 0.698 - h * 0.14, h * 0.28, h * 0.28), Color(1, 1, 1, 0.88))
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation = deg_to_rad(-12.0 if late else 9.0)
	stamp.tooltip_text = "Опоздание" if late else "Доставлено"
	# on a small screen (no banner) the medals stand in a row under the sheet
	if not tall and not result.get("medals", []).is_empty():
		var shelf = HBoxContainer.new()
		shelf.alignment = BoxContainer.ALIGNMENT_CENTER
		shelf.add_theme_constant_override("separation", 18)
		box.add_child(shelf)
		medal_row(shelf, result.get("medals", []), Vector2(56, 76))

func medal_row(row: HBoxContainer, medals: Array, each: Vector2) -> void:
	for id in medals:
		if not RESULT_ART.has("medal_" + str(id)): continue
		var medal = TextureRect.new()
		medal.texture = RESULT_ART["medal_" + str(id)]
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		medal.custom_minimum_size = each
		medal.tooltip_text = str(MEDAL_NAMES.get(str(id), ""))
		row.add_child(medal)

# The train as it stands on the rails: the machine and its coupled wagons, then the wagons standing aside.
func consist_strip(parent: Node) -> void:
	var strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 6)
	parent.add_child(strip)
	var coupled: Array = [canvas.model.vehicle_id()] + canvas.model.state.consist_ids
	# ui-v2 (owner 14.11): drawn as on the rails of the room: the wagons on the left, the machine on the right
	var drawn = coupled.duplicate()
	drawn.reverse()
	for id in drawn:
		var tile = TextureRect.new()
		tile.texture = canvas.art.textures[canvas.art.body_key(id)]
		tile.custom_minimum_size = Vector2(0, 54.0 * float(canvas.settings.text_scale))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.tooltip_text = canvas.vehicle_display_name() if id == canvas.model.vehicle_id() else str(id)
		strip.add_child(tile)
	canvas.add_label(parent, "В составе: %s. Сцепки на рельсах слева тоже нажимаются мышью." % ", ".join(coupled.map(func(id): return canvas.vehicle_display_name() if id == canvas.model.vehicle_id() else str(id))), 15, canvas.MUTED_INK)

func vehicle_summary(id: String) -> String:
	var base = canvas.model.vehicle_base(id)
	var on_deck = int(base.deck_slots) > 0
	var wagons = int(base.get("max_wagons", 0)) > 0
	var cargo = "платформа и вагоны" if on_deck and wagons else ("платформа" if on_deck else ("вагоны" if wagons else "нет"))
	var energy = {"handcar": "без топлива", "steam": "уголь и вода", "motorcar": "бензин", "pneumatic": "сжатый воздух", "pole": "мускулы", "sail": "ветер", "locomotive": "аккумулятор", "zeppelin": "бензин", "jet": "керосин"}.get(id, "")
	return "Груз: %s  ·  Ход: %s" % [cargo, energy]
