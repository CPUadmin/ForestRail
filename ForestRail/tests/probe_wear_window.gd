extends Node
# Снимок окна «Состояние» для 1.4.5: цена ремонта по классу, склонение слова, серая кнопка при нехватке.
# Не проверка с галочкой. Запуск: godot --path ForestRail -- --qa-suite=probe_wear_window <папка>
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var out_dir = "user://qa_wear_window"
var index = 0

func _ready() -> void:
	call_deferred("run")

func frame(n: int = 6) -> void:
	for i in range(n):
		game.queue_redraw()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await frame()
	index += 1
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join("%02d_%s.png" % [index, name]))

func open(kind: String, money: int, bolts: int = 0) -> void:
	Model.wear_rules = true
	var m = Model.new()
	m.new_game(42, 2)
	m.state.chapter = 4
	Fixtures.equip(m, kind)
	m.state.money = money
	if bolts > 0: m.casino().junk_add("rusty_bolt", bolts)
	# wear three nodes to different depths so the bars, prices and a grey button all show
	var nodes = m.wear().nodes_of(kind)
	var depths = [0.45, 0.2, 0.7]
	for i in range(mini(3, nodes.size())):
		m.wear().set_condition(kind, str(nodes[i].id), depths[i])
	m.state.phase = "depot"
	game.model = m
	game.screen = "depot"
	game.place = "shop"
	game.tab = "Улучшения"
	game.selected_object = kind
	game.rebuild()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): out_dir = arg
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.live_in_tests = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = out_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout

	open("handcar", 1000)
	await shot("handcar_rich")
	open("motorcar", 40, 12)      # price 3/pct: 40 coins cannot cover the cheapest 1%? (3 coins) -> buttons live, "Починить всё" grey
	await shot("motorcar_poor")
	open("jet", 120)          # price 10/pct: a full repair costs a lot; some buttons grey
	await shot("jet_poor")
	open("jet", 100000)
	await shot("jet_rich")
	get_tree().quit(0)
