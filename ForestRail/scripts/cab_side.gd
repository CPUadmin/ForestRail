extends Control
# A side window of the cab: the lineside rushing past, in three layers of parallax.
# The window clips its own drawing, so the scenery cannot spill over the cab frame.
# side is -1 for the left window and +1 for the right one.

var game
var side = -1.0

func hash_at(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

func fog(color: Color, amount: float) -> Color:
	return color.lerp(Color("cfe0dc"), amount)

func _draw() -> void:
	if game == null or game.model.state.is_empty(): return
	var w = size.x
	var h = size.y
	var facing = int(game.model.state.direction)
	var travelled = game.model.render_s() * facing
	var speed = absf(float(game.model.state.v))
	var horizon = h * 0.50
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon), Vector2(0, horizon)]), PackedColorArray([Color("6ea6d4"), Color("6ea6d4"), Color("d9e8e0"), Color("d9e8e0")]))
	var forest: Texture2D = game.art.textures["parallax/far_forest"]
	var forest_height = h * 0.38
	var forest_width = forest_height * float(forest.get_width()) / float(forest.get_height())
	var x0 = -fposmod(-side * travelled * 3.0, forest_width)
	while x0 < w:
		draw_texture_rect(forest, Rect2(x0, horizon - forest_height, forest_width + 1.0, forest_height), false)
		x0 += forest_width
	draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)]), PackedColorArray([Color("77a06a"), Color("77a06a"), Color("3a5e3c"), Color("3a5e3c")]))
	# three layers: far, middle and near trees, each scrolling at its own rate
	var layers = [[16.0, 64.0, 0.55, 0.30], [42.0, 110.0, 0.25, 0.55], [125.0, 250.0, 0.0, 0.95]]
	for layer_index in range(layers.size()):
		var rate = float(layers[layer_index][0])
		var spacing = float(layers[layer_index][1])
		var haze = float(layers[layer_index][2])
		var scale_h = float(layers[layer_index][3])
		var shift = -side * travelled * rate
		var first = floori(shift / spacing) - 1
		var last = floori((shift + w) / spacing) + 1
		for idx in range(first, last + 1):
			var x = idx * spacing - shift + hash_at(idx, layer_index * 3.0) * spacing * 0.5
			var pick = hash_at(idx, layer_index * 3.0 + 1.0)
			var base_y = horizon + h * (0.06 + 0.10 * layer_index) + hash_at(idx, 7.0) * h * 0.05
			var tree_h = h * scale_h * (0.7 + hash_at(idx, layer_index * 3.0 + 2.0) * 0.6)
			if layer_index == 2 and pick < 0.45: continue
			var kind = "bush" if pick > 0.82 else ("birch" if pick > 0.62 else "pine")
			var sprite: Texture2D = game.textures[kind]
			var height = tree_h * (0.30 if kind == "bush" else 1.0)
			var width = height * float(sprite.get_width()) / float(sprite.get_height())
			draw_texture_rect(sprite, Rect2(x - width * 0.5, base_y - height, width, height), false, fog(Color(0.86, 0.94, 0.82), haze))
	# a telegraph pole rushes by now and then
	var pole_shift = -side * travelled * 70.0
	var pole_gap = 520.0
	for idx in range(floori(pole_shift / pole_gap) - 1, floori((pole_shift + w) / pole_gap) + 2):
		var px = idx * pole_gap - pole_shift
		draw_line(Vector2(px, h * 0.08), Vector2(px, h * 0.86), Color("4b3a2c"), 5.0, true)
		draw_line(Vector2(px - 18, h * 0.16), Vector2(px + 18, h * 0.16), Color("4b3a2c"), 3.0, true)
	# the gravel and a white edge line close to the glass
	draw_rect(Rect2(0, h * 0.90, w, h * 0.10), Color("8a8174"))
	draw_line(Vector2(0, h * 0.90), Vector2(w, h * 0.90), Color(1, 1, 1, 0.25), 2.0)
	game.art_world.draw_weather(self, Rect2(Vector2.ZERO, size), game.shown_weather(), game.time, bool(game.settings.reduce_motion))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.12, game.night_shade()))
	# motion streaks, glass sheen and an inner shadow
	if speed > 2.0:
		for streak in range(10):
			var y = h * (0.55 + 0.4 * hash_at(streak, 5.0))
			draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, clampf((speed - 2.0) * 0.015, 0.0, 0.1)), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.1, 0), Vector2(w * 0.4, 0), Vector2(w * 0.05, h), Vector2(-w * 0.2, h)]), Color(1, 1, 1, 0.07))
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.0), false, 1.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
