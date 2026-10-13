extends "res://tests/world_calendar_tests.gd"

func migration(map: Node) -> void:
	var before: Dictionary = map.loadout.snapshot()
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	var raw := state.snapshot()
	raw.erase("respawn_rules_version")
	check(WorldCalendar.advance(raw.calendar,10,"base.test.respawn").is_empty(),"legacy day ten")
	var today := WorldCalendar.current_day(raw.calendar)
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/respawn_rules.json"))
	var enemy_id: String = rules.legacy_encounter_days.keys()[0]
	var expired_enemy: String = rules.legacy_encounter_days.keys()[1]
	raw.encounter_cooldowns = {enemy_id:today+5,expired_enemy:today}
	var chest_id: String = rules.chest_reward_ids[0]
	var expired_chest: String = rules.chest_reward_ids[1]
	var item := "base.map_item.qingshi_short_sword"
	raw.granted_rewards = {chest_id:{"item_id":item,"quantity":1},expired_chest:{"item_id":item,"quantity":1}}
	raw.chest_cooldowns = {chest_id:{"delay_days":30,"remaining_days":20,"ready_day":today+20,"cycle":1},expired_chest:{"delay_days":30,"remaining_days":0,"ready_day":today,"cycle":1}}
	check(state.restore(raw).is_empty(),"upgrade legacy pending deadlines")
	check(int(state.encounter_cooldowns[enemy_id])==today+10,"old fifteen-day enemy keeps ten days elapsed")
	check(int(state.chest_cooldowns[chest_id].ready_day)==today+30 and state.chest_cooldowns[chest_id].delay_days==40,"old thirty-day chest keeps ten days elapsed")
	check(int(state.encounter_cooldowns[expired_enemy])==today and int(state.chest_cooldowns[expired_chest].ready_day)==today,"already open nodes stay open")
	var once := state.snapshot()
	check(state.restore(once).is_empty() and state.snapshot()==once,"upgrade is idempotent through transaction cloning")
	var isolated := "res://artifacts/respawn-migration-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(isolated,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var copy: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(copy,isolated).is_empty() and copy.snapshot()==once,"old disk save upgrades on load")
	check(JSON.parse_string(FileAccess.get_file_as_string(isolated)).respawn_rules_version==1,"migration marker persisted atomically")
	check(MapLoadoutStore.load_into(copy,isolated).is_empty() and copy.snapshot()==once,"reload does not add days twice")
	var bad := raw.duplicate(true)
	bad.respawn_rules_version = 99
	check(not copy.restore(bad).is_empty() and copy.snapshot()==once,"invalid migration version leaves state unchanged")
	bad = raw.duplicate(true)
	bad.encounter_cooldowns[enemy_id] = WorldCalendar.MAX_DAY
	check(not copy.restore(bad).is_empty() and copy.snapshot()==once,"overflow migration rejected atomically")
	check(map.loadout.snapshot()==before,"migration uses isolated state only")

func all_encounters(map: Node) -> void:
	var before: Dictionary = map.loadout.snapshot()
	var rows: Array = map.event_registry.events.values().filter(func(e): return e.type=="encounter")
	check(rows.size()==11,"all eleven encounters found")
	var raw: Dictionary = map.loadout.snapshot()
	var today := WorldCalendar.current_day(raw.calendar)
	raw.encounter_cooldowns = {}
	for event: Dictionary in rows:
		check(event.respawn_days==20,"twenty-day config "+event.id)
		raw.encounter_cooldowns[event.id] = today+20
	check(map.loadout.restore(raw).is_empty(),"fixture defeated encounter deadlines")
	map._sync_calendar()
	check(rows.all(func(e):return map.event_state.completed.has(e.id)),"all dead nodes hidden")
	check(map.loadout.advance_days(19,"base.test.wait").is_empty(),"advance nineteen days")
	map._sync_calendar()
	check(rows.all(func(e):return map.event_state.completed.has(e.id)),"all still dead before boundary")
	check(map.loadout.advance_days(1,"base.test.wait").is_empty(),"advance final day")
	map._sync_calendar()
	check(rows.all(func(e):return not map.event_state.completed.has(e.id)),"all eleven reopen on day twenty")
	for event: Dictionary in rows: check(map.event_state.resolved_event(event.id).enemy_id==event.enemy_id,"no enemy rotation")
	for event: Dictionary in map.event_registry.events.values():
		if event.type=="chest": check(event.respawn_days==40,"forty-day chest config")
	check(map.loadout.restore(before).is_empty(),"restore fixture after deadline boundary")
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	map._sync_calendar()

func run() -> void:
	create_timer(55).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	var map := await new_map()
	if not map.startup_error.is_empty():quit(1);return
	migration(map)
	all_encounters(map)
	await chest_cycle(map)
	map = await victory_deadline(map)
	map.queue_free()
	await settle()
	print("ECONOMY RESPAWN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
