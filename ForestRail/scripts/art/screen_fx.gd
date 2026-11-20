extends RefCounted
# Помощник main.gd: мелкие экранные эффекты и подсказки: блики, облачко песочницы, пыль при посадке, плашка уведомления, всплывающая подсказка (нарезка main.gd, 21.11). Работает через canvas (main.gd), как steam_cab.gd.

var canvas = null   # main.gd

func _init(owner_canvas) -> void:
	canvas = owner_canvas

# B6.11 b: a glint of brass by the rail: a bolt lies in the gravel. It twinkles when the train is near; a click picks it up.
func draw_glints() -> void:
	if canvas.model.state.phase != "route" or not canvas.model.casino().has_trip(): return
	var sc = canvas.view_scale()
	var list = canvas.model.casino().glints()
	for i in range(list.size()):
		var g = list[i]
		if bool(g.taken): continue
		var p = canvas.world_point(float(g.s))
		if p.x < -60 or p.x > canvas.get_viewport_rect().size.x + 60: continue
		p += Vector2(0, 17 * sc)
		var gold = bool(g.golden)
		var pulse = 0.55 + 0.45 * sin(canvas.time * 5.0 + float(i) * 2.1)
		if canvas.settings.reduce_motion: pulse = 0.85
		var tint = Color(1.0, 0.82, 0.3) if gold else Color(0.95, 0.78, 0.45)
		canvas.ellipse(p, Vector2(16, 6) * sc, Color(tint.r, tint.g, tint.b, 0.3 * pulse))
		var arm = (12.0 + 8.0 * pulse) * sc * (1.4 if gold else 1.0)
		canvas.draw_line(p + Vector2(-arm, 0), p + Vector2(arm, 0), Color(tint.r, tint.g, tint.b, 0.9 * pulse), 2.0 * sc, true)
		canvas.draw_line(p + Vector2(0, -arm), p + Vector2(0, arm), Color(tint.r, tint.g, tint.b, 0.9 * pulse), 2.0 * sc, true)
		canvas.draw_circle(p, 2.6 * sc, Color(1, 0.97, 0.8, pulse))
		canvas.glint_hits.append({"index": i, "position": p})

# B5.5: a landing kicks up the dust of the track bed: a few soft puffs that spread and fade.
# 1.4.15: the sander blows sand under both driving wheels: a small sandy cloud at each, low on the rail, gone in 0.7 s
func draw_sand_puff() -> void:
	if canvas.sand_puff.is_empty(): return
	var age = float(canvas.sand_puff.t)
	if age > 0.7:
		canvas.sand_puff = {}
		return
	var sc = canvas.view_scale()
	var s0 = canvas.model.body_s_render(0)
	for axle in [-0.75, 0.75]:
		var at = canvas.world_point(s0 + axle) + Vector2(0, 4 * sc)
		for k in range(4):
			var side = (float(k) - 1.5) / 1.5
			var p = at + Vector2(side * (10.0 + 40.0 * age) * sc, -(6.0 + 18.0 * age * (1.0 - absf(side) * 0.4)) * sc)
			var r = (10.0 + 24.0 * age) * sc * (0.8 + 0.2 * absf(sin(float(k) * 1.7)))
			canvas.ellipse(p, Vector2(r * 1.3, r * 0.7), Color(0.80, 0.68, 0.44, 0.78 * (1.0 - age / 0.7)))

func draw_land_dust() -> void:
	if canvas.land_dust.is_empty(): return
	var age = float(canvas.land_dust.t)
	if age > 0.8:
		canvas.land_dust = {}
		return
	var sc = canvas.view_scale()
	var power = float(canvas.land_dust.power)
	for k in range(7):
		var side = (float(k) - 3.0) / 3.0
		var spread = (0.4 + age * 3.2) * power
		var p = canvas.world_point(float(canvas.land_dust.s) + side * (1.5 + age * 3.5) * power) + Vector2(0, 6 * sc)
		var radius = (16.0 + 34.0 * age) * sc * power * (0.7 + 0.3 * absf(sin(float(k) * 2.1)))
		canvas.ellipse(p + Vector2(0, -age * 26.0 * sc * (0.5 + 0.5 * absf(side))), Vector2(radius * (1.0 + spread * 0.2), radius * 0.6), Color(0.66, 0.58, 0.45, 0.5 * (1.0 - age / 0.8)))

# The notice: a long text wraps to up to three lines instead of being cut at the edge of the box (it was cut in the narrow depot column).
# A box that stands low on the screen grows upward, so that it does not cover the buttons under it.
func draw_toast_box(rect: Rect2, grow_up: bool) -> void:
	var width = rect.size.x - 30
	var text_h = canvas.font.get_multiline_string_size(canvas.toast, HORIZONTAL_ALIGNMENT_LEFT, width, 19, 3).y
	var extra = maxf(0.0, text_h + 20.0 - rect.size.y)
	rect.size.y += extra
	if grow_up: rect.position.y -= extra
	canvas.draw_style_box(canvas.style(canvas.INK, canvas.GOLD, 8), rect)
	canvas.draw_multiline_string(canvas.font, rect.position + Vector2(18, 29), canvas.toast, HORIZONTAL_ALIGNMENT_LEFT, width, 19, 3, canvas.PAPER)

func draw_tooltip() -> void:
	if canvas.drag != "": return
	var mouse = canvas.get_global_mouse_position()
	var text = ""
	for hit in canvas.grip_hits:
		if hit.position.distance_to(mouse) < 31:
			text = {"pump": "Зажми хват и веди его по дуге рычага", "brake": "Тормоз: двигай ручку вверх по прорези от 0 до 100%" if canvas.model.vehicle_id() == "locomotive" else "Тормоз: веди рукоять по дуге от 0 до 100%", "throttle": "Вентиль: крути колесо по кругу, отпустишь — закроется сам" if canvas.model.vehicle_id() == "steam" else ("Тяга: двигай ручку вверх по прорези от 0 до 100%" if canvas.model.vehicle_id() == "locomotive" else "Подача: веди рукоять по дуге от 0 до 100%"), "gear": "Кран воды: крути по кругу. Без воды пара нет" if canvas.model.vehicle_id() == "steam" else "Кулиса: веди шар через N в паз. Менять при газе ниже 15%, R только на остановке", "start": "Щёлкни, чтобы разжечь или погасить огонь" if canvas.model.vehicle_id() == "steam" else ("Ключ: держи, пока мотор не схватит. Щелчок — выкл." if canvas.model.vehicle_id() == "motorcar" else "Щёлкни тумблер, чтобы включить или выключить")}[hit.id]
			if hit.id == "start" and canvas.control_kind("start") == "matchbox":
				text = "Щёлкни по коробку, чтобы взять спичку" if canvas.cab_active() else "За спичками войди в кабину [%s]" % canvas.key_name("cab")
	for hit in canvas.ignition_hits:
		if hit.rect.has_point(mouse): text = "Подсос: вытяни для холодного мотора, сам уйдёт, когда прогреется"
	if text=="" and canvas.screen=="game" and canvas.model.vehicle_id()=="locomotive" and canvas.charge_strip_rect.has_point(mouse):
		text="Заряд %d%% · доступная тяга %d%%" % [roundi(canvas.charge_fraction()*100),roundi(canvas.model.charge_traction_factor()*100)]
	for hit in canvas.cargo_hits:
		if hit.rect.has_point(mouse):
			for item in canvas.model.state.cargo:
				if item.id == hit.id:
					text = "%s · %d кг → %s" % [canvas.model.cargo_base(item.type).name, canvas.model.cargo_base(item.type).mass_kg, canvas.model.station_name(item.destination)]
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if text != "" else Input.CURSOR_ARROW)
	if text != "":
		var p = Vector2(clampf(mouse.x - 180, 20, canvas.get_viewport_rect().size.x - 560), mouse.y - 68)
		canvas.draw_style_box(canvas.style(canvas.INK, canvas.GOLD, 6), Rect2(p, Vector2(540, 45)))
		canvas.draw_string(canvas.font, p + Vector2(12, 29), text, HORIZONTAL_ALIGNMENT_LEFT, 515, 18, canvas.PAPER)
