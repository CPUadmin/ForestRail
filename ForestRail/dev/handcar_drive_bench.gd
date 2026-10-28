extends Node2D

var game
var loaded=true
var info: Label
var energy_label: Label

func _ready() -> void:
	get_tree().root.set_meta("drive_bench_running",true)
	game=load("res://main.tscn").instantiate()
	game.test_mode=true
	game.saves.directory=ProjectSettings.globalize_path("res://../qa/v3_p4/bench_profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.settings_path=game.saves.directory.path_join("settings.json")
	add_child(game)
	var ui=Control.new()
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.z_index=5
	add_child(ui)
	info=Label.new()
	info.position=Vector2(38,22);info.size=Vector2(1200,70)
	info.add_theme_font_size_override("font_size",23)
	ui.add_child(info)
	var row=HBoxContainer.new()
	row.position=Vector2(38,126)
	row.add_theme_constant_override("separation",12)
	ui.add_child(row)
	for text in ["Лёгкая · 180 кг","С грузом · 340 кг","Отпустить тормоз","Затянуть тормоз"]:
		var button=Button.new()
		button.text=text
		button.custom_minimum_size=Vector2(215,44)
		row.add_child(button)
		if text.begins_with("Лёгкая"): button.pressed.connect(func(): reset_fixture(false))
		elif text.begins_with("С грузом"): button.pressed.connect(func(): reset_fixture(true))
		elif text.begins_with("Отпустить"): button.pressed.connect(func(): game.model.state.brake=0.0)
		else: button.pressed.connect(func(): game.model.state.brake=1.0)
	energy_label=Label.new()
	energy_label.position=Vector2(38,get_viewport_rect().size.y-170)
	energy_label.size=Vector2(1300,145)
	energy_label.add_theme_font_size_override("font_size",19)
	ui.add_child(energy_label)
	reset_fixture(true)

func reset_fixture(with_load: bool) -> void:
	loaded=with_load
	game.cancel_drag()
	game.model.new_game(42)
	game.model.accept_mission(game.model.current_mission())
	for i in range(2): game.model.transfer(game.model.state.cargo[i].id,game.model.slots()[i].key)
	game.model.depart()
	if with_load:
		for cargo in game.model.state.cargo: cargo.type="parts"
	else: game.model.state.cargo=[]
	for point in game.model.route.points: point[1]=0.0
	for i in range(game.model.route.station_s.size()): game.model.route.station_s[i]+=10000
	game.model.state.s=100.0
	game.model.state.brake=0.0
	game.screen="game"
	game.paused=false
	game.camera_s=100.0;game.camera_y=0.0;game.camera_x=get_viewport_rect().size.x*0.65
	game.zoom_level=1.5
	game.rebuild()
	game.ui.hide()
	refresh()

func _process(_dt: float) -> void:
	refresh()

func refresh() -> void:
	if game==null or game.model.state.is_empty(): return
	var model=game.model
	info.text="РУЧНОЙ ПРИВОД · %d кг · %.1f км/ч\nЗажми деревянный хват и двигай мышь. Светлый контур показывает цель руки." % [model.train_mass(),absf(model.state.v)*3.6]
	var d=model.hand_drive.last
	if d.is_empty(): energy_label.text="Маховик: момент инерции 1,2 кг·м². Цепь: 1,75 оборота колеса на оборот кривошипа.";return
	energy_label.text="Маховик: %.1f Дж · скорость кривошипа %.2f об/с · работа руки %.1f Вт\nПолная кинетическая энергия %.1f Дж · работа руки с начала %.1f Дж · потери %.1f Дж\nБаланс шага %+.5f Дж · тормоз %d%% · φ %.3f рад\nОтпусти мышь для наката. У мёртвой точки можно потянуть край платформы при отпущенном тормозе." % [d.flywheel_energy,d.omega/TAU,model.output_power,d.kinetic,model.hand_drive.hand_work,model.hand_drive.losses,d.balance_error,model.state.brake*100,model.handcar.phase]
