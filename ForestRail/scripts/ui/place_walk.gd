extends RefCounted
# Помощник main.gd: переходы по двору и депо: прогулка к зданию, затемнение, казик, заезд в депо (нарезка main.gd, 21.11). Работает через canvas (main.gd), как steam_cab.gd.

var canvas = null   # main.gd

func _init(owner_canvas) -> void:
	canvas = owner_canvas

# a walk across the yard: the screen darkens (the camera comes closer to the building), the place opens, the light comes back
func go_place(id: String) -> void:
	if id == "casino":
		var open = func():
			canvas.casino_intro = true
			canvas.show_modal("casino")
		if canvas.test_mode and not canvas.animate_in_tests:
			open.call()
			return
		if canvas.depot_anim != "": return
		canvas.cancel_drag()
		if canvas.place == "yard" and not bool(canvas.settings.reduce_motion): canvas.yard_ui().entering = "casino"
		canvas.place_style = "casino_in" if not bool(canvas.settings.reduce_motion) else ""
		canvas.fade_tint = canvas.UiKit.GLOW if canvas.place_style != "" else Color(0, 0, 0)
		canvas.place_change = true
		canvas.depot_exit_action = open
		canvas.depot_anim = "leave"
		canvas.depot_anim_t = 0.0
		canvas.ensure_fade_rect()
		canvas.sound.play("gear", 0.3, 1.5)
		return
	var change = func():
		canvas.place = id
		canvas.tab = canvas.PLACE_TAB.get(id, "Рейсы")
		canvas.free_trips_open = false
		canvas.selected_object = canvas.model.vehicle_id()
		canvas.rebuild()
	if canvas.place == id: return
	if canvas.test_mode and not canvas.animate_in_tests:
		change.call()
		return
	canvas.cancel_drag()
	canvas.place_change = true
	canvas.depot_exit_action = change
	canvas.depot_anim = "leave"
	canvas.depot_anim_t = 0.0
	canvas.ensure_fade_rect()

func place_fade_s() -> float:
	if canvas.place_style == "casino_in": return canvas.CASINO_OUT_S if canvas.depot_anim == "out" else canvas.CASINO_IN_S
	if canvas.place_style == "casino_out": return canvas.CASINO_LEAVE_S
	return 0.25 if canvas.place_change else canvas.DEPOT_FADE_S

# the way out of the casino: a short warm fade back to the yard
func leave_casino() -> void:
	if (canvas.test_mode and not canvas.animate_in_tests) or canvas.depot_anim != "":
		canvas.close_modal()
		return
	canvas.cancel_drag()
	canvas.place_style = "casino_out"
	canvas.fade_tint = canvas.UiKit.GLOW
	canvas.place_change = true
	canvas.depot_exit_action = canvas.close_modal
	canvas.depot_anim = "leave"
	canvas.depot_anim_t = 0.0
	canvas.ensure_fade_rect()

# the cover of the fade: black for the usual walks, warm light for the casino doors
func set_fade(alpha: float) -> void:
	if canvas.fade_rect != null: canvas.fade_rect.color = Color(canvas.fade_tint.r, canvas.fade_tint.g, canvas.fade_tint.b, alpha)

# --- Entering the depot (B1.2a): the train rolls to its mark, the view closes in, the screen fades to
# black, the depot opens and fades in. Any key or click skips the rolling part.
func start_depot_entry() -> void:
	if canvas.depot_anim != "" or canvas.screen != "game" or canvas.model.state.phase == "depot": return
	if not canvas.model.stopped():
		canvas.notify("Остановись у платформы, чтобы заехать в депо")
		return
	if canvas.model.station_index() != 0:
		canvas.notify(canvas.model.message if canvas.model.message != "" else "Заехать в депо можно на станции Лесная")
		return
	canvas.cancel_drag()
	canvas.depot_anim = "in"
	canvas.depot_anim_t = 0.0
	canvas.depot_anim_from = float(canvas.model.state.s)
	canvas.depot_anim_zoom = canvas.zoom_level
	canvas.ensure_fade_rect()
	canvas.sound.play("gear", 0.5, 0.7)

func skip_depot_anim() -> void:
	if canvas.depot_anim == "in": canvas.depot_anim_t = maxf(canvas.depot_anim_t, canvas.DEPOT_MOVE_S)
	elif canvas.depot_anim == "leave": canvas.depot_anim_t = canvas.place_fade_s()
	elif canvas.depot_anim == "out": canvas.depot_anim_t = canvas.place_fade_s()
	if canvas.place_style != "":   # the casino doors: a click goes straight to the end
		canvas.advance_depot_anim(0.0)
		if canvas.depot_anim == "out":
			canvas.depot_anim_t = canvas.place_fade_s()
			canvas.advance_depot_anim(0.0)

func advance_depot_anim(dt: float) -> void:
	canvas.depot_anim_t += dt
	if canvas.depot_anim == "in":
		var mark = float(canvas.model.service_stop(0))
		var move = clampf(canvas.depot_anim_t / canvas.DEPOT_MOVE_S, 0.0, 1.0)
		canvas.model.state.s = lerpf(canvas.depot_anim_from, mark, smoothstep(0.0, 1.0, move))
		canvas.model.state.v = 0.0
		canvas.model.state.brake = 1.0
		canvas.zoom_level = lerpf(canvas.depot_anim_zoom, minf(1.5, canvas.depot_anim_zoom * 1.25), smoothstep(0.0, 1.0, move))
		if canvas.fade_rect != null: canvas.fade_rect.color.a = clampf((canvas.depot_anim_t - canvas.DEPOT_MOVE_S) / canvas.DEPOT_FADE_S, 0.0, 1.0)
		if canvas.depot_anim_t >= canvas.DEPOT_MOVE_S + canvas.DEPOT_FADE_S:
			canvas.zoom_level = canvas.depot_anim_zoom
			if canvas.model.back_to_depot():
				canvas.screen = "depot"
				canvas.place = "yard"
				canvas.save_game()
				canvas.rebuild()
				canvas.depot_anim = "out"
				canvas.depot_anim_t = 0.0
			else:
				canvas.notify(canvas.model.message)
				canvas.depot_anim = ""
				if canvas.fade_rect != null: canvas.fade_rect.color.a = 0.0
	elif canvas.depot_anim == "leave":
		var p = clampf(canvas.depot_anim_t / canvas.place_fade_s(), 0.0, 1.0)
		if canvas.place_style == "casino_in":
			canvas.fade_tint = canvas.UiKit.GLOW.lerp(canvas.CASINO_DEEP, smoothstep(0.4, 1.0, p))
			canvas.set_fade(smoothstep(0.35, 1.0, p))   # the light floods in at the end of the flight, not from the start
		else: canvas.set_fade(p)
		if canvas.screen == "depot" and canvas.place == "yard": canvas.queue_redraw()   # the camera comes closer to the building
		if canvas.depot_anim_t >= canvas.place_fade_s():
			if canvas.depot_exit_action.is_valid(): canvas.depot_exit_action.call()
			canvas.depot_exit_action = Callable()
			canvas.depot_anim = "out"
			canvas.depot_anim_t = 0.0
	elif canvas.depot_anim == "out":
		var q = clampf(canvas.depot_anim_t / canvas.place_fade_s(), 0.0, 1.0)
		if canvas.place_style != "": canvas.fade_tint = canvas.CASINO_DEEP.lerp(canvas.UiKit.LAMP, q)
		canvas.set_fade(1.0 - smoothstep(0.0, 1.0, q) if canvas.place_style != "" else 1.0 - q)
		if canvas.depot_anim_t >= canvas.place_fade_s():
			canvas.depot_anim = ""
			canvas.place_change = false
			canvas.place_style = ""
			canvas.fade_tint = Color(0, 0, 0)
			canvas.set_fade(0.0)
