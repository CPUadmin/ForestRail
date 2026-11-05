extends Node

const Model=preload("res://scripts/model.gd")
const Storage=preload("res://scripts/save_game.gd")
var checks=0
var failures: Array=[]

func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL: ",label)

func run() -> void:
	var out_dir=""
	var legacy_path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--p8-output="): out_dir=arg.trim_prefix("--p8-output=")
		if arg.begins_with("--migration-save="): legacy_path=arg.trim_prefix("--migration-save=")
	if out_dir=="" or legacy_path=="": get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var raw=FileAccess.get_file_as_bytes(legacy_path)
	var old=JSON.parse_string(raw.get_string_from_utf8())
	var m=Model.new()
	check(old is Dictionary and m.restore(old),"restore untouched copy of original legacy career")
	for key in ["money","chapter","fleet_by_id","wagons_by_id","consist_ids","paid_ids","completed_ids","cargo","stats"]:
		check(m.state[key]==old[key],"migration preserves "+key)
	check(m.handcar.phase==m.serialize().handcar_phase and is_finite(m.handcar.phase),"legacy phase assigned once and serialized")
	check(not m.serialize().has("flywheel_energy"),"legacy fake work tank is not imported as energy")
	if not m.state.active.is_empty():
		check(not m.selectable_loading() and m.state.active.reward==old.active.reward,"old accepted order keeps fixed conditions")
	var storage=Storage.new()
	storage.directory=out_dir.path_join("storage_"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(storage.directory)
	check(storage.write(m),"write migrated career to isolated storage")
	var initial=m.serialize()
	m.state.money+=1
	check(storage.write(m),"next save creates valid backup")
	var backup=storage.read_valid("save_v2.backup.json")
	check(not backup.is_empty() and backup.money==initial.money,"backup preserves previous career")
	var f=FileAccess.open(storage.path("save_v2.json"),FileAccess.WRITE)
	f.store_string("{ broken");f.close()
	check(storage.read_valid("save_v2.json").is_empty(),"corrupted primary rejected")
	check(m.restore(backup) and m.state.money==initial.money,"backup restores career without fabricated progress")
	check(storage.write(m,true),"recovered save can be written preserving backup")
	check(storage.read_valid("save_v2.backup.json").money==initial.money,"recovery does not replace good backup with corrupt primary")
	check(FileAccess.get_file_as_bytes(legacy_path)==raw,"migration input copy remains byte-identical")
	# New coupled motion survives disk round-trip; capture never survives load.
	m.new_game(42)
	check(m.accept_mission(m.current_mission()), "accept current starting order")
	check(m.transfer(m.state.cargo[0].id,m.slots()[0].key), "load only one cargo item")
	var expected_reward = m.selected_reward()
	check(m.depart() and m.state.cargo.size() == 1, "depart with a partial load")
	m.state.v=2;m.handcar.set_phase(1234.56);m.grab_pump()
	check(storage.write(m),"moving coupled drive saves to disk")
	var phase=m.handcar.phase
	check(m.restore(storage.read_valid("save_v2.json")),"moving drive restores from disk")
	check(m.state.v==2 and absf(m.handcar.phase-phase)<1e-9 and not m.hand_drive.held,"load keeps phase/speed and releases hand")
	check(m.state.active.reward==expected_reward and m.state.cargo.size()==1 and m.state.active.selection_locked,"frozen partial order survives motion save")
	var report={"checks":checks,"failures":failures,"legacy_money":old.money,"legacy_chapter":old.chapter,
		"legacy_fleet":old.fleet_by_id.keys(),"scope":"native model/storage checks on a copy; no user files modified"}
	f=FileAccess.open(out_dir.path_join("save_results.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close()
	print("SAVE P8 CHECKS ",checks,"; FAILURES ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
