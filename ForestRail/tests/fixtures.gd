extends RefCounted

# Gives a test model the machine and a full set of wagons it can pull,
# without touching the money the test is about. Since 3.2 machines without
# deck places carry everything in wagons bought one at a time, so the old
# "buy motorcar, buy locomotive, buy wagon" chains no longer give the same
# consist (ECONOMY_v3_2_RU.md).
static func equip(m, id: String) -> void:
	var money = int(m.state.money)
	m.state.money = 1000000
	if not m.state.fleet_by_id.has(id): m.buy_vehicle(id)
	m.select_vehicle(id)
	while m.state.consist_ids.size() < m.max_wagons(id):
		if m.next_wagon_id() != "":
			m.buy_wagon()
			continue
		var spare = ""
		for wagon in m.WAGON_IDS:
			if m.state.wagons_by_id.has(wagon) and wagon not in m.state.consist_ids: spare = wagon
		if spare == "" or not m.toggle_wagon(spare): break
	m.state.money = money
