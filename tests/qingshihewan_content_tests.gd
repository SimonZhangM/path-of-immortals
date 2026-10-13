extends SceneTree

const PREFIX := "base.enemy."
const EXPECTED := {
	"huiji_shanlang": [45,42,"无甲",0,4],
	"qingke_heyuan": [51,45,"重甲",7,7],
	"qingling_yanzhi": [46,45,"轻甲",5,7],
	"chisong_liaozhu": [96,98,"轻甲",6,9]
}
const LOCATIONS := {
	1:["雾松崖径","qingling_yanzhi"],7:["河心乱礁","qingke_heyuan"],
	10:["青溪渡口","qingke_heyuan"],12:["夹壁山径","huiji_shanlang"],
	30:["落英林径","chisong_liaozhu"],21:["回水岭径","huiji_shanlang"],
	28:["临溪石坡","qingling_yanzhi"],33:["南湾沙洲","huiji_shanlang"],
	24:["断阶水口","qingke_heyuan"],17:["翻车商道","chisong_liaozhu"],26:["南岸深林","qingling_yanzhi"]
}
var registry := ContentRegistry.new()
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	check(registry.load_base_content(), "registered complete and staged data: " + str(registry.errors))
	if not registry.errors.is_empty(): quit(1); return
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "materials registered without granting")
	var storage: MapLoadoutState = created.state
	var gallery: Array[Dictionary] = []
	for key: String in EXPECTED:
		var expected: Array = EXPECTED[key]
		var definition := registry.get_enemy(PREFIX+key)
		var enemy := PartyMemberState.new(definition,registry)
		enemy.equip_definition_loadout()
		check(enemy.maximum("hp")==expected[0] and enemy.maximum("stamina")==expected[1] and enemy.maximum("spirit")==0, key+" resources")
		check(enemy.armor_type==expected[2] and enemy.maximum("armor")==expected[3] and enemy.armor==0,key+" armor starts empty, cap from organs")
		check(enemy.inventory.grid_size==Vector2i(3,3) and enemy.inventory.occupied_cells()==expected[4],key+" board footprint")
		check(definition.encounter_descriptions.size()==3 and definition.presentation.summary.size()==4,key+" three narratives and four summaries")
		var is_pig := key=="chisong_liaozhu"
		check(registry.enemy_battle_error(definition.id).is_empty(),key+" real battle availability")
		check(definition.progression_rewards.cultivation==(5 if is_pig else 3) and definition.progression_rewards.experience==(2 if is_pig else 1),key+" rewards")
		if not is_pig:
			check(ResourceLoader.exists(definition.portrait) and ResourceLoader.exists(definition.presentation.battle_background) and not enemy.board.pending_art,key+" own portrait, board and background ready")
			var bad := definition.duplicate(true)
			bad.id = "test.enemy."+key
			bad.battle_enabled = true
			bad.presentation.battle_background = ""
			check(not registry.register_enemy(bad),key+" cannot activate with missing background")
		for row: Dictionary in definition.loadout:
			var item := registry.get_item(row.item_id)
			check(item.quality=="下品" and FileAccess.file_exists(item.icon_path),item.id+" lower grade and image")
			check((load(item.icon_path) as Texture2D).get_image().has_mipmaps(),item.id+" mipmaps")
			if not is_pig: gallery.append({"name":item.display_name,"icon":item.icon_path,"quality":item.quality,"art_outline_px":1})
		for row: Dictionary in definition.loot:
			var is_heart: bool = row.item_id == "base.material.cslz_heart"
			check(row.chance == (0.1 if is_heart else 0.25) and row.get("first_victory_guaranteed",false) == is_heart,row.item_id+" authored drop chance and guarantee")
			check(storage.records.has(row.item_id) and storage.records[row.item_id].effects.is_empty(),row.item_id+" inert material")
			check(storage.records[row.item_id].source_enemy_id==definition.id,row.item_id+" source binding")
		var misses: Array = []; misses.resize(definition.loot.size()); misses.fill(.25)
		var hits: Array = []; hits.resize(definition.loot.size()); hits.fill(.099)
		var missed := BattleLoot.candidate(storage,definition,key+"miss",misses)
		check(missed.drops == (["base.material.cslz_heart"] if is_pig else []),key+" only pig heart has first guarantee")
		var loot := BattleLoot.candidate(storage,definition,key+"hit",hits)
		check(loot.drops.size()==definition.loot.size() and loot.snapshot.owned_units.size()==storage.snapshot().owned_units.size()+definition.loot.size(),key+" exactly one per hit")
	check(storage.storage_records().all(func(r:Dictionary): return r.category!="beast"),"no test materials granted")
	check(storage.records.has("base.material.cslz_heart"),"old owned heart definition remains compatible")
	check(registry.get_enemy(PREFIX+"chisong_liaozhu").loot.any(func(r:Dictionary): return r.item_id=="base.material.cslz_heart" and r.chance==0.1 and r.first_victory_guaranteed),"heart restores original drop rule")
	var skin := registry.get_item("base.organ.shanlang_hide")
	check(skin.cooldown_usec==0 and skin.effects.is_empty() and skin.armor_capacity==0,"wolf hide has no combat effect")
	for row: Array in [["shanlang_claw",2.5,2,4,"斩击"],["shanlang_fang",4,3,6,"穿刺"],["heyuan_beak",3.5,2,5,"穿刺"],["heyuan_tail",4.5,3,6,"钝击"],["yanzhi_beak",3,2,5,"穿刺"],["yanzhi_claw",3.5,2,5,"斩击"]]:
		var item := registry.get_item("base.organ."+row[0])
		check(item.cooldown_usec==int(row[1]*1000000) and item.stamina_cost==row[2] and item.effects[0].value==row[3] and item.effects[0].damage_type==row[4],"attack parameters "+row[0])
	for row: Array in [["heyuan_shell",6.5,3],["yanzhi_feather",5.5,2]]:
		var item := registry.get_item("base.organ."+row[0])
		check(item.cooldown_usec==int(row[1]*1000000) and item.stamina_cost==0 and item.effects[0].effect=="restore_armor" and item.effects[0].value==row[2],"armor cooldown "+row[0])
	var definitions: Array = []
	var points: Array = []
	for n: int in LOCATIONS:
		var filename := "cliff_encounter" if n==30 else "encounter_n%02d"%n
		var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_"+filename+".json"))
		var wanted: Array = LOCATIONS[n]
		check(event.title==wanted[0] and event.enemy_id==PREFIX+wanted[1] and not event.has("enemy_sequence"),"location and fixed species N%d"%n)
		check((event.get("respawn_days",0)==15)==(n in [1,10,30,21,28,26]),"existing authored respawn delays retained")
		definitions.append(event); points.append(event.point_id)
	var events := MapEventRegistry.new()
	check(events.configure(definitions,points).is_empty(),"event catalog validates")
	for event: Dictionary in definitions:
		var stale := {event.id: {"index": 1, "remaining_days": -1}}
		var fixed := MapEventState.new(events, {}, stale)
		check(fixed.resolved_event(event.id).enemy_id == event.enemy_id, "old rotation index cannot change fixed enemy")
		fixed.resolve_encounter(event.id, "victory")
		fixed.advance_encounter_days(15)
		if fixed.completed.has(event.id): fixed.respawn_encounter(event.id)
		check(not fixed.completed.has(event.id) and fixed.resolved_event(event.id).enemy_id == event.enemy_id, "each node respawns same species")
	var completed := {}; var records := {}
	var state := MapEventState.new(events,completed,records)
	state.enemy_lookup = registry.get_enemy
	state.enemy_available = func(id:String):return registry.enemy_battle_error(id).is_empty()
	state.narrative_rng.seed = 91
	var id := "base.map_event.qingshihewan.cliff_encounter"
	var point: String = events.events[id].point_id
	var seen := {}
	for i in 24:
		check(state.try_start(point,point,true,"arrival"),"pig opens")
		var selected := state.active_event()
		seen[selected.description] = true
		check(selected.description==events.events[id].description and state.active_event()==selected,"authored location narrative stays stable")
		state.cancel_encounter()
	check(seen.size()==1,"fixed location copy is not overwritten by random species prose")
	check(state.resolve_encounter(id,"defeat") and state.resolved_event(id).enemy_id==PREFIX+"chisong_liaozhu" and records.is_empty(),"defeat does not rotate")
	check(state.resolve_encounter(id,"victory") and records[id].remaining_days==15,"victory starts15day delay")
	check(not state.respawn_encounter(id) and not state.try_start(point,point,true,"arrival"),"cannot bypass waiting by click or manual respawn")
	state.advance_encounter_days(14)
	var restored := MapEventState.new(events,completed,records)
	check(restored.completed.has(id) and restored.encounters[id].remaining_days==1,"reopening retains elapsed logical days")
	restored.advance_encounter_days(1)
	check(not restored.completed.has(id) and restored.resolved_event(id).enemy_id==PREFIX+"chisong_liaozhu","day15 respawns same pig")
	restored.enemy_available = state.enemy_available
	check(restored.try_start(point,point,true,"arrival"),"respawned pig opens with its own art")
	restored.cancel_encounter()
	check(restored.resolve_encounter(id,"retreat") and restored.resolved_event(id).enemy_id==PREFIX+"chisong_liaozhu","retreat retains pig")
	restored.resolve_encounter(id,"victory")
	restored.advance_encounter_days(15)
	check(restored.resolved_event(id).enemy_id==PREFIX+"chisong_liaozhu","second respawn retains fixed species")
	check(not restored.advance_encounter_days(0) and not restored.advance_encounter_days(-1),"invalid day increments rejected")
	check(MapEventState.new(events,{}).resolved_event(id).enemy_id==PREFIX+"chisong_liaozhu","new session starts from first species")
	var single := "base.map_event.qingshihewan.encounter_n17"
	restored.resolve_encounter(single,"victory"); restored.advance_encounter_days(100)
	check(restored.completed.has(single) and restored.respawn_encounter(single),"single-species delay not invented; manual respawn retained")
	var bad_event: Dictionary = events.events[id].duplicate(true)
	bad_event.respawn_days = 0
	check(not MapEventRegistry.new().configure([bad_event],[point]).is_empty(),"zero respawn days rejected")
	if DisplayServer.get_name()!="headless": await render_gallery(gallery)
	print("Qingshihewan content: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func render_gallery(records: Array[Dictionary]) -> void:
	root.size = Vector2i(2560,1440)
	var canvas := Control.new(); root.add_child(canvas)
	var bg := ColorRect.new(); bg.color=Color("101b28"); bg.size=Vector2(2560,1440); canvas.add_child(bg)
	for i in records.size():
		var cell := Vector2(190+(i%3)*790,100+(i/3)*420)
		var panel := Panel.new(); panel.position=cell; panel.size=Vector2(640,370); canvas.add_child(panel)
		var art := MapItemArtwork.new(); panel.add_child(art); art.position=Vector2(170,15); art.size=Vector2(300,300); art.configure(records[i],true)
		var label := Label.new(); label.text=records[i].name; label.position=Vector2(0,320); label.size=Vector2(640,45); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",30); panel.add_child(label)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/qshw-organs-gallery.png")
	canvas.queue_free()
