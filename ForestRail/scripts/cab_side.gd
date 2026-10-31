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
	var ridge = PackedVector2Array([Vector2(0, horizon)])
	for step in range(0, int(w) + 21, 20):
		ridge.append(Vector2(step, horizon - h * (0.06 + 0.07 * (0.5 + 0.5 * sin(step * 0.03 + travelled * -side * 0.01)))))
	ridge.append(Vector2(w + 20, horizon))
	draw_colored_polygon(ridge, Color("8fa9a6"))
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
			if pick > 0.82:
				# a bush
				draw_circle(Vector2(x, base_y - tree_h * 0.12), tree_h * 0.16, fog(Color("2f6a3a"), haze))
				draw_circle(Vector2(x + tree_h * 0.14, base_y - tree_h * 0.08), tree_h * 0.12, fog(Color("3a7b44"), haze))
			elif pick > 0.62:
				# a birch
				draw_line(Vector2(x, base_y), Vector2(x, base_y - tree_h * 0.7), fog(Color("e6e2d4"), haze), maxf(2.0, tree_h * 0.035), true)
				draw_circle(Vector2(x, base_y - tree_h * 0.75), tree_h * 0.16, fog(Color("6f9d4a"), haze))
				draw_circle(Vector2(x - tree_h * 0.09, base_y - tree_h * 0.66), tree_h * 0.11, fog(Color("7fae56"), haze))
			else:
				var half = tree_h * 0.17
				draw_rect(Rect2(x - maxf(1.5, half * 0.12), base_y - tree_h * 0.14, maxf(3.0, half * 0.24), tree_h * 0.14), fog(Color("3b2a1d"), haze))
				for tier in range(3):
					var lift = tree_h * (0.1 + tier * 0.25)
					var tier_half = half * (1.0 - tier * 0.26)
					draw_colored_polygon(PackedVector2Array([Vector2(x - tier_half, base_y - lift), Vector2(x + tier_half, base_y - lift), Vector2(x, base_y - lift - tree_h * 0.42)]), fog(Color(0.12, 0.30 + tier * 0.02, 0.16), haze))
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
	# motion streaks, glass sheen and an inner shadow
	if speed > 2.0:
		for streak in range(10):
			var y = h * (0.55 + 0.4 * hash_at(streak, 5.0))
			draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, clampf((speed - 2.0) * 0.015, 0.0, 0.1)), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.1, 0), Vector2(w * 0.4, 0), Vector2(w * 0.05, h), Vector2(-w * 0.2, h)]), Color(1, 1, 1, 0.07))
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.0), false, 1.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
