extends RefCounted
# Набор интерфейса «Латунь по тёмному дереву» (docs/UI_REDESIGN_RU.md, шаги 1.5.1–1.5.2): цвета, размеры и вид кнопок.
# Кнопка рисуется как «клавиша»: толстая нижняя кромка-ступенька; состояния меняют ширину верхней и нижней кромок так, что их сумма всегда 7 px,
# поэтому размер кнопки не прыгает, а поля содержимого заданы явно (текст при нажатии уходит на 3 px вниз).

# --- поверхности
const BG_DEEP = Color("17120d")
const WOOD_DARK = Color("241a10")
const WOOD = Color("2a1d12")
const WOOD_MID = Color("3a2916")
const WOOD_LIGHT = Color("4a3520")
const ENAMEL = Color("1d2b24")
const PAPER = Color("e9dcb8")
const PAPER_EDGE = Color("cdbd92")
const LEATHER = Color("6b4423")
# --- латунь
const BRASS_SHADOW = Color("5c431a")
const BRASS_DARK = Color("8a6a2c")
const BRASS = Color("c9a24e")
const BRASS_LIGHT = Color("e8c878")
const BRASS_FILL = Color("d9ae55")
const LAMP = Color("ffd47a")
const GLOW = Color("ffb94a")
# --- состояния
const OK = Color("6fae6a")
const WARN = Color("e0a63a")
const DANGER_FILL = Color("8e3326")
const DANGER_DARK = Color("6a2217")
const DANGER_TEXT = Color("e8806a")
const INFO = Color("78b8d8")
# --- текст
const T1 = Color("f3e6c4")
const T2 = Color("cdbb92")
const T3 = Color("a89a78")
const INK1 = Color("2b1d10")
const INK2 = Color("5a4630")
const OFF = Color("8a7a5a")

const STEP = 5            # нижняя кромка-ступенька обычной кнопки
const EDGE_SUM = 7        # сумма верхней и нижней кромок во всех состояниях

static var cache: Dictionary = {}

# kind: "primary" | "secondary" | "quiet" | "danger" | "tab"; state: "normal" | "hover" | "pressed" | "disabled" | "selected" | "focus"
static func box(kind: String, state: String) -> StyleBoxFlat:
	var key = kind + "|" + state
	if cache.has(key): return cache[key]
	var b = StyleBoxFlat.new()
	var fill = WOOD_MID
	var edge = BRASS_DARK
	var top = 2
	var bottom = 5
	var shadow = Color(0.043, 0.027, 0.016, 1.0)
	var glow = 0.0
	var glow_color = BRASS
	match kind:
		"primary":
			fill = BRASS_FILL
			edge = BRASS_SHADOW
			glow_color = GLOW
		"danger":
			fill = DANGER_FILL
			edge = Color("3d120b")
			shadow = Color("1c0805")
			glow_color = DANGER_TEXT
		"quiet":
			fill = WOOD
			edge = Color("6a4a14")
		"tab":
			fill = WOOD
			edge = Color("6a4a14")
			bottom = 2
			top = 2
	match state:
		"hover":
			match kind:
				"primary": fill = Color("e8c26a")
				"danger": fill = Color("a63c2c")
				"quiet": fill = WOOD_MID
				_: fill = WOOD_LIGHT
			if kind != "primary" and kind != "danger": edge = BRASS
			top = 1
			bottom = EDGE_SUM - 1 if kind != "tab" else 2
			glow = 0.30 if kind == "primary" or kind == "danger" else 0.18
		"pressed":
			match kind:
				"primary": fill = Color("c9964a")
				"danger": fill = DANGER_DARK
				"quiet": fill = Color("1f160d")
				_: fill = WOOD_DARK
			if kind != "primary" and kind != "danger": edge = BRASS
			top = EDGE_SUM - 2 if kind != "tab" else 2
			bottom = 2
		"disabled":
			match kind:
				"primary": fill = Color("5a4a2e"); edge = Color("2f2414")
				"danger": fill = Color("3a2a24"); edge = Color("2a1d18")
				_: fill = WOOD_DARK; edge = Color("4a3a22")
			top = 2
			bottom = 2
			shadow = Color(0, 0, 0, 0)
		"selected":
			fill = WOOD_LIGHT
			edge = LAMP
			bottom = 3
			top = 2
			glow = 0.25
			glow_color = GLOW
		"focus":
			b.draw_center = false
			b.set_border_width_all(3)
			b.border_color = LAMP
			b.set_corner_radius_all(9)
			b.set_expand_margin_all(3)
			b.anti_aliasing = true
			cache[key] = b
			return b
	b.bg_color = fill
	b.border_color = edge
	b.border_width_left = 2
	b.border_width_right = 2
	b.border_width_top = top
	b.border_width_bottom = bottom
	b.set_corner_radius_all(7 if kind == "primary" else 6)
	b.corner_detail = 8
	b.anti_aliasing = true
	b.shadow_color = Color(shadow, 0.9) if state != "pressed" and state != "disabled" else Color(0, 0, 0, 0)
	b.shadow_size = 1
	b.shadow_offset = Vector2(0, 2)
	if glow > 0.0:
		b.shadow_color = Color(glow_color, glow)
		b.shadow_size = 8
		b.shadow_offset = Vector2(0, 0)
	# the content margins are set by hand: the text stands in the middle of the face and goes 3 px down when the button is pressed
	b.content_margin_left = 18
	b.content_margin_right = 18
	var shift = 0
	if state == "pressed": shift = 3
	elif state == "hover": shift = -1
	var pad_top = 10 if kind == "primary" else 8
	b.content_margin_top = pad_top + shift
	b.content_margin_bottom = pad_top - shift
	cache[key] = b
	return b

# --- panels: the board (windows), the plaque (rows and cards inside the board)
static func board() -> StyleBoxFlat:
	if cache.has("board"): return cache["board"]
	var b = StyleBoxFlat.new()
	b.bg_color = WOOD
	b.border_color = BRASS
	b.set_border_width_all(2)
	b.set_corner_radius_all(10)
	b.anti_aliasing = true
	b.shadow_color = Color(0, 0, 0, 0.5)
	b.shadow_size = 14
	b.shadow_offset = Vector2(0, 6)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 14
	b.content_margin_bottom = 14
	cache["board"] = b
	return b

# accent: the colour of the edge that tells the state of the card (the current choice, a maxed upgrade, a warning); the plain card has a quiet edge
static func plaque(accent: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var key = "plaque|" + accent.to_html()
	if cache.has(key): return cache[key]
	var b = StyleBoxFlat.new()
	b.bg_color = Color("33241a")
	b.border_color = Color("5a4328") if accent.a == 0.0 else accent
	b.set_border_width_all(1)
	if accent.a > 0.0: b.border_width_left = 5
	b.set_corner_radius_all(8)
	b.anti_aliasing = true
	b.shadow_color = Color(0, 0, 0, 0.35)
	b.shadow_size = 6
	b.shadow_offset = Vector2(0, 3)
	b.set_content_margin_all(14)
	cache[key] = b
	return b

# the text colours were chosen for the cream paper; on the dark board they are exchanged for their light twins
static func on_dark(c: Color, ink: Color, muted_ink: Color, gold: Color, red: Color, green: Color) -> Color:
	if c == ink: return T1
	if c == muted_ink: return T2
	if c == Color("755921") or c == gold.darkened(0.25): return LAMP
	if c == red: return DANGER_TEXT
	if c == green: return OK
	return c

# the colours of the text of a kind of button in a state
static func text_color(kind: String, state: String) -> Color:
	match kind:
		"primary":
			if state == "disabled": return Color("9c8f72")
			return Color("1d1208") if state == "hover" else INK1
		"danger":
			if state == "disabled": return T3
			return Color("fff6e0") if state == "hover" else Color("fff0d0")
		_:
			if state == "disabled": return OFF
			if state == "selected": return LAMP
			return Color("fff4d6") if state == "hover" else T1

# the buttons of the theme: sets the styleboxes and the colours of one type variation
static func apply_to_theme(theme: Theme, type_name: String, kind: String) -> void:
	var color_names = {"normal": "font_color", "hover": "font_hover_color", "pressed": "font_pressed_color", "disabled": "font_disabled_color"}
	for state in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(state, type_name, box(kind, state))
		theme.set_color(color_names[state], type_name, text_color(kind, state))
	theme.set_stylebox("focus", type_name, box(kind, "focus"))
	theme.set_color("font_focus_color", type_name, text_color(kind, "normal"))
	theme.set_color("font_hover_pressed_color", type_name, text_color(kind, "pressed"))
