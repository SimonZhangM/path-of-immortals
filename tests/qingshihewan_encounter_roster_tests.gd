extends SceneTree

const GROUPS := {
	"chisong_liaozhu": [17,30], "qingke_heyuan": [7,10,24],
	"huiji_shanlang": [12,21,33], "qingling_yanzhi": [1,26,28]
}
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = "res://artifacts/encounter-roster-test.json"
	root.add_child(map)
	current_scene = map
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "actual map loads with all four enemies")
	check(map._encounter_enemies.size()==11, "all eleven encounters instantiate combatants")
	var total := 0
	var chest_count := 0
	var dialogue_count := 0
	for event: Dictionary in map.event_registry.events.values():
		if event.type=="encounter": total+=1
		if event.type=="chest": chest_count+=1
		if event.type=="dialogue": dialogue_count+=1
	check(total==11 and chest_count==5 and dialogue_count==2, "11 encounters; existing chests and stories retained")
	var pig_ids: Array[String] = []
	for species: String in GROUPS:
		for n: int in GROUPS[species]:
			var point := "base.map.qingshihewan.point.n%02d" % n
			var id: String = map.event_registry.by_point[point]
			var event: Dictionary = map.event_registry.events[id]
			var enabled := true
			check(event.enemy_id=="base.enemy."+species and event.enabled==enabled, "correct species and enabled state N%02d" % n)
			check(not event.title.is_empty(), "location title authored N%02d" % n)
			var marker = map.content.get_node("Points/N%02d" % n)
			check(marker.location_note == event.title and marker.has_node("Sign"), "named route point retains sign N%02d" % n)
			map.travel.current_node_id = point
			map.travel.mode = "idle"
			map.travel.node_arrived.emit(point)
			check(map.encounter_dialog.visible==enabled and map.event_state.is_active()==enabled, "arrival opens only configured encounters N%02d" % n)
			if enabled:
				if species=="chisong_liaozhu": pig_ids.append(id)
				check(map.encounter_dialog.heading.text == event.title and map.encounter_dialog.enemy_name.text==map.loadout.registry.get_enemy(event.enemy_id).name, "popup has location name and correct enemy")
				if n==30 and DisplayServer.get_name()!="headless":
					await settle()
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/encounter-roster-pig.png")
				map._retreat_encounter()
			else:
				check(not map._try_start_event(point,"click",true), "pending node cannot start by click")
				check(not map.event_state.resolve_encounter(id,"victory") and not map.event_state.respawn_encounter(id), "pending node cannot acquire completion state")
	check(pig_ids.size()==2 and pig_ids[0]!=pig_ids[1], "pig instances have distinct stable IDs")
	check(map.event_state.resolve_encounter(pig_ids[0],"victory") and not map.event_state.completed.has(pig_ids[1]), "defeating first pig leaves second alive")
	check(not map.event_state.respawn_encounter(pig_ids[0]), "individual pig waits for its cooldown")
	map.event_state.advance_encounter_days(20)
	check(not map.event_state.completed.has(pig_ids[0]), "individual pig respawns after 20 days")
	var pig: Dictionary = map.loadout.registry.get_enemy("base.enemy.chisong_liaozhu")
	check(pig.progression_rewards.cultivation==5 and pig.progression_rewards.experience==2, "growth rewards unchanged")
	var loot_registry := ContentRegistry.new()
	check(loot_registry.load_base_content(), "isolated loot registry loads")
	var created := MapLoadoutStore.create_state(loot_registry,loot_registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "isolated loot state loads")
	var state: MapLoadoutState = created.state
	var first := BattleLoot.candidate(state,pig,"roster.first",[0.99,0.99,0.99,0.99,0.99])
	check(first.error.is_empty() and first.drops == ["base.material.cslz_heart"], "first victory guarantees heart")
	var all := BattleLoot.candidate(state,pig,"roster.all",[0.0,0.0,0.0,0.0,0.0])
	check(all.drops.size()==5, "drops are independent and can all occur")
	state.battle_rewards = first.snapshot.battle_rewards.duplicate(true)
	var later := BattleLoot.candidate(state,pig,"roster.second",[0.25,0.25,0.25,0.25,0.1])
	check(later.drops.is_empty(), "another location of same species has no second guarantee; thresholds exclusive")
	var bad: Dictionary = map.event_registry.events[pig_ids[0]].duplicate(true)
	bad.enabled = "false"
	check(not MapEventRegistry.new().configure([bad],[bad.point_id]).is_empty(), "invalid enabled flag rejected")
	map.queue_free()
	await settle()
	print("Encounter roster: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
