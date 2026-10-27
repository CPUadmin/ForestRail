extends SceneTree

const Model = preload("res://scripts/model.gd")
const SaveGame = preload("res://scripts/save_game.gd")

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	var destination = args[0] if not args.is_empty() else "user://qa_scenario"
	var scenario = args[1] if args.size() > 1 else "loading"
	var m = Model.new()
	m.new_game(42)
	if scenario in ["electric", "motor", "finale", "upgrades"]:
		m.state.money = 5000
		m.buy_vehicle("motorcar")
		if scenario != "motor":
			m.buy_vehicle("locomotive")
			m.buy_wagon()
	if scenario == "loading":
		m.accept_mission(m.current_mission())
	elif scenario in ["electric", "motor"]:
		m.state.chapter = 9 if scenario == "electric" else 2
		m.accept_mission(m.current_mission())
		for i in range(m.state.cargo.size()): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
		m.depart()
		m.state.s = m.route.station_s[1] + 48
		m.state.v = 3
		m.state.brake = 0
		m.state.engine = true
		m.state.gear = 1
		m.state.throttle = 0.7
	elif scenario == "finale":
		m.state.chapter = 10
		m.state.finale = true
		m.state.last_result = {"title": "Поезд до Дальнего бора", "reward": 500, "final": true}
	var storage = SaveGame.new()
	storage.directory = destination
	DirAccess.make_dir_recursive_absolute(destination)
	if not storage.write(m): print(storage.error); quit(1); return
	quit()
