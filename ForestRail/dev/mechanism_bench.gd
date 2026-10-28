extends Node2D

const Mechanism = preload("res://scripts/handcar_mechanism.gd")
const Art = preload("res://scripts/art_v3.gd")
const Model = preload("res://scripts/model.gd")
const PAPER = Color("f5ecd6")
const GOLD = Color("c5a76b")
var mechanism = Mechanism.new()
var art = Art.new()
var model = Model.new()
var frame_pose: Dictionary = {}
var running = true
var cycles_per_second = 0.12
var show_pins = true
var speed: HSlider
var phase_slider: HSlider
var pause_button: Button
var reverse_button: Button
var values: Label
var pins_button: CheckButton
var synchronizing = false

func _ready() -> void:
	model.new_game(42)
	material = ShaderMaterial.new()
	material.shader = load("res://assets/art_v3/materials/edge_clean.gdshader")
	var box = VBoxContainer.new()
	box.position=Vector2(36,102)
	box.size=Vector2(365,650)
	box.add_theme_constant_override("separation",18)
	add_child(box)
	var label = Label.new()
	label.text="Медленное вращение"
	label.add_theme_font_size_override("font_size",23)
	box.add_child(label)
	speed=HSlider.new()
	speed.min_value=-0.5;speed.max_value=0.5;speed.step=0.01;speed.value=cycles_per_second
	speed.custom_minimum_size=Vector2(365,30)
	box.add_child(speed)
	speed.value_changed.connect(func(value): cycles_per_second=value)
	pause_button=Button.new()
	pause_button.text="Остановить [Пробел]"
	pause_button.custom_minimum_size.y=44
	box.add_child(pause_button)
	pause_button.pressed.connect(toggle_pause)
	reverse_button=Button.new()
	reverse_button.text="Сменить вращение"
	reverse_button.custom_minimum_size.y=44
	box.add_child(reverse_button)
	reverse_button.pressed.connect(func(): cycles_per_second=-cycles_per_second;speed.value=cycles_per_second)
	label=Label.new()
	label.text="Фаза · остановка в любой точке"
	label.add_theme_font_size_override("font_size",20)
	box.add_child(label)
	phase_slider=HSlider.new()
	phase_slider.min_value=0;phase_slider.max_value=360;phase_slider.step=0.1
	phase_slider.custom_minimum_size=Vector2(365,30)
	box.add_child(phase_slider)
	phase_slider.value_changed.connect(func(value):
		if synchronizing: return
		running=false
		mechanism.set_phase(floor(mechanism.phase/TAU)*TAU+deg_to_rad(value))
		refresh())
	pins_button=CheckButton.new()
	pins_button.text="Показать шарниры"
	pins_button.button_pressed=true
	box.add_child(pins_button)
	pins_button.toggled.connect(func(value): show_pins=value;queue_redraw())
	values=Label.new()
	values.add_theme_font_size_override("font_size",21)
	box.add_child(values)
	refresh()

func toggle_pause() -> void:
	running=not running
	refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_SPACE: toggle_pause();get_viewport().set_input_as_handled()
		if event.keycode in [KEY_LEFT,KEY_RIGHT] and not running:
			mechanism.advance(1 if event.keycode==KEY_RIGHT else -1,deg_to_rad(1))
			refresh()

func _process(dt: float) -> void:
	if running: mechanism.advance(cycles_per_second*TAU,dt)
	refresh()

func refresh() -> void:
	frame_pose=mechanism.pose()
	if is_instance_valid(values):
		var error=absf(frame_pose.rocker_pin.distance_to(frame_pose.crank_pin)-float(mechanism.config.rod_length))
		values.text="Обороты: %.3f\nФаза: %.2f°\nРычаг: %.2f°\nШатун: %.4f м\nОшибка длины: %.4f мм\nХод хвата: %.3f м\nПередаточное отношение: 1:1" % [mechanism.phase/TAU,fposmod(rad_to_deg(mechanism.phase),360),rad_to_deg(frame_pose.angle),float(mechanism.config.rod_length),error*1000,float(mechanism.limits.stroke_m)]
		synchronizing=true
		phase_slider.value=fposmod(rad_to_deg(mechanism.phase),360)
		synchronizing=false
		pause_button.text="Остановить [Пробел]" if running else "Продолжить [Пробел]"
	queue_redraw()

func view_transform() -> Transform2D:
	var size=get_viewport_rect().size
	var sc=minf(2.7,(size.x-490)/350)
	return Transform2D(0,Vector2.ONE*sc,0,Vector2(490+(size.x-490)*0.5,size.y*0.79))

func _draw() -> void:
	var size=get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO,size),Color("233a36"))
	draw_rect(Rect2(20,84,400,size.y-110),Color("304a40"))
	draw_string(ThemeDB.fallback_font,Vector2(36,50),"РУЧНОЙ МЕХАНИЗМ · СТЕНД",HORIZONTAL_ALIGNMENT_LEFT,-1,28,PAPER)
	var outer=view_transform()
	for i in range(-6,7):
		var x=(outer*Vector2(i*0.5*96,0)).x
		draw_line(Vector2(x,110),Vector2(x,size.y-100),Color(0.6,0.7,0.6,0.15),1)
	for i in range(5):
		var y=(outer*Vector2(0,-i*0.5*96)).y
		draw_line(Vector2(450,y),Vector2(size.x-30,y),Color(0.6,0.7,0.6,0.15),1)
	draw_line(Vector2(450,outer.origin.y),Vector2(size.x-30,outer.origin.y),GOLD,3,true)
	if frame_pose.is_empty(): return
	art.draw_vehicle(self,"handcar",0,1,outer,model,false,frame_pose)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if show_pins:
		var keys={"O":"rocker","A":"rocker_pin","C":"crank","B":"crank_pin"}
		for letter in keys:
			var point=outer*(frame_pose[keys[letter]]*96)
			draw_circle(point,5,Color("71d2be"))
			draw_string(ThemeDB.fallback_font,point+Vector2(10,-10),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,22,PAPER)
	draw_string(ThemeDB.fallback_font,Vector2(450,size.y-62),"Стенд задаёт вращение кривошипа. Колесо связано с ним через постоянное отношение.",HORIZONTAL_ALIGNMENT_LEFT,size.x-480,18,PAPER)
	draw_string(ThemeDB.fallback_font,Vector2(450,size.y-32),"Усилие руки и движение состава проверяются на следующем этапе.",HORIZONTAL_ALIGNMENT_LEFT,size.x-480,18,Color("bac6ac"))
