extends SceneTree
const Access=preload("res://scripts/map/map_breakthrough_access.gd")
const Run=preload("res://scripts/map/map_breakthrough_run.gd")
const ID="base.map_shortcut.breakthrough"
var checks:=0
var failures:=0
var output:="res://artifacts/breakthrough-shortcut-20261113"

func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(text)
func settle() -> void:
	for i in 4: await process_frame
func key() -> void:
	var e:=InputEventKey.new()
	e.physical_keycode=KEY_T
	e.pressed=true
	root.push_input(e,true)
	e=e.duplicate()
	e.pressed=false
	root.push_input(e,true)
func click(control: Control) -> void:
	var p:=control.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new()
	move.position=p
	root.push_input(move,true)
	for down in [true,false]:
		var e:=InputEventMouseButton.new()
		e.position=p
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=down
		root.push_input(e,true)

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(output)
	MapLoadoutStore.GameSaveSession.index_path=output+"/session-index.json"
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1920,1080)
	var map=load("res://scenes/maps/baishacun.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	map.defer_location_save=true
	map.defer_optional_views=true
	root.add_child(map)
	await settle()
	map.set_process(false)
	map._location_active=true
	map.travel.paused=false
	map._sync_shortcut_visibility()
	check(map.startup_error.is_empty(),"actual map starts")
	var state: MapLoadoutState=map.loadout
	if OS.get_environment("BREAKTHROUGH_SHORTCUT_VISUAL_ONLY")=="1":
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output+"/current-save-copy.json"))
		check(state.restore(saved).is_empty(),"visual fixture loads isolated player copy")
		await capture(map,state)
		map.deactivate_location()
		map.queue_free()
		await settle()
		print("BREAKTHROUGH SHORTCUT VISUAL: %d checks, %d failures"%[checks,failures])
		quit(1 if failures else 0)
		return
	check(not state.is_test_save,"new state defaults to normal")
	check(not Access.can_open(state),"ineligible normal save cannot open breakthrough")
	map.set_breakthrough_open(true)
	key()
	await settle()
	check(not map.is_breakthrough_open(),"direct and T entry reject ineligible save")
	check(not map.shortcut_bar.buttons[ID].visible,"ineligible entry is hidden")
	map.set_inventory_open(true)
	await settle()
	key()
	await settle()
	check(map.is_inventory_open() and not map.is_breakthrough_open(),"fullscreen hotkey switch cannot bypass eligibility")
	map.set_inventory_open(false)
	var original: Dictionary=state.snapshot()
	var fixture: Dictionary=original.duplicate(true)
	fixture.placements=[]
	fixture.board_id="base.board.qinglan_1"
	fixture.growth=CultivationGrowth.initial(0)
	fixture.growth.resources={"hp":5000,"stamina":5000,"spirit":0}
	fixture.growth.progress=CultivationGrowth.target(fixture.growth)
	fixture.learning={"version":1,"learned":{},"practice":{}}
	for target: Dictionary in QuestState.definition.objectives: fixture.quests[QuestState.ID].counts[target.id]=target.required
	fixture.quests[QuestState.ID].story=QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done=["traces","injured","entrance","root","mirror","beasts_gone","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]
	fixture.quests[RiverQuest.ID].accepted_location=RiverQuest.RIVER
	fixture.quests[HomecomingQuest.ID].accepted_location=HomecomingQuest.data.shop.map_id
	fixture.quests[HomecomingQuest.ID].letter_received=true
	fixture.quests[HomecomingQuest.ID].home_reunited=true
	fixture.quests[HomecomingQuest.ID].guidance_completed=true
	fixture.map_location={"map_id":Access.rule.map_id,"point_id":Access.rule.point_id}
	fixture.is_test_save=false
	var fixture_error:=state.restore(fixture)
	check(fixture_error.is_empty(),"eligible mortal fixture restores: "+fixture_error)
	check(Access.eligibility_error(state).is_empty() and Access.can_open(state),"actual breakthrough requirements allow opening")
	var rail: Control=map.shortcut_bar
	check(rail.buttons[ID].visible,"eligible entry appears")
	check(rail._visible_ids[0]==ID and rail.buttons[ID].position.y<rail.buttons["base.map_shortcut.bag"].position.y,"breakthrough occupies first row above bag")
	var runtime=Run.new()
	runtime.bind(state,map.player_status,"")
	check(runtime.eligibility_error()==Access.eligibility_error(state),"entry and runtime share requirements")
	state.set_map_location(Access.rule.map_id,"base.map.baishacun.point.n01")
	check(not Access.can_open(state) and not rail.buttons[ID].visible,"leaving eligible node in same region removes icon immediately")
	state.set_map_location(Access.rule.map_id,Access.rule.point_id)
	check(rail.buttons[ID].visible,"returning to eligible node restores icon")
	state.growth.progress=0
	state.changed.emit()
	check(not Access.can_open(state) and not rail.buttons[ID].visible,"insufficient progress retracts access")
	state.growth.progress=CultivationGrowth.target(state.growth)
	state.quests[HomecomingQuest.ID].guidance_completed=false
	state.changed.emit()
	check(not Access.can_open(state),"story guidance remains required")
	state.quests[HomecomingQuest.ID].guidance_completed=true
	var board: BoardLayout=state.board
	state.board=state.registry.get_board("base.board.bag")
	check(not Access.can_open(state),"starter bag cannot qualify")
	state.board=board
	state.growth.breakthrough_attempt={"phase":"paused"}
	state.growth.progress=0
	check(Access.can_open(state),"existing paused attempt remains reachable")
	state.growth.breakthrough_attempt.phase="succeeded"
	check(Access.can_open(state),"unconfirmed result remains reachable")
	state.growth.erase("breakthrough_attempt")
	check(not Access.can_open(state),"confirming/clearing attempt restores normal gate")
	check(state.restore(original).is_empty(),"restore high-realm ineligible baseline")
	state.is_test_save=true
	state.changed.emit()
	map.travel.paused=false
	map._sync_shortcut_visibility()
	check(Access.can_open(state) and rail.buttons[ID].visible,"test save can inspect panel without gameplay qualification")
	click(rail.buttons[ID])
	await settle()
	check(map.is_breakthrough_open(),"top icon opens actual breakthrough panel")
	check(ID not in state.map_shortcuts.unread,"opening clears breakthrough alert")
	check(not map.breakthrough_session.runtime.eligibility_error().is_empty(),"test UI exception does not bypass actual breakthrough start rules")
	map.set_breakthrough_open(false)
	key()
	await settle()
	check(map.is_breakthrough_open(),"test save T shortcut opens")
	map.set_breakthrough_open(false)
	map.set_inventory_open(true)
	await settle()
	key()
	await settle()
	check(map.is_breakthrough_open() and not map.is_inventory_open(),"test save fullscreen switching permits breakthrough")
	map.set_breakthrough_open(false)
	var legacy: Dictionary=state.snapshot()
	legacy.erase("is_test_save")
	legacy.content_grants[MapLoadoutState.TEST_SPELL_GRANT]=true
	check(state.restore(legacy).is_empty() and state.is_test_save,"dedicated legacy test grant migrates to test save")
	legacy.is_test_save=false
	check(state.restore(legacy).is_empty() and not state.is_test_save,"explicit normal marker overrides inherited test content")
	legacy.erase("is_test_save")
	legacy.content_grants.erase(MapLoadoutState.TEST_SPELL_GRANT)
	legacy.content_grants.erase("test.cultivation_books.20261019")
	check(state.restore(legacy).is_empty() and not state.is_test_save,"unmarked ordinary legacy saves do not gain exemption")
	legacy.is_test_save="true"
	check(not state.restore(legacy).is_empty(),"malformed test marker rejected")
	var current_path:=output+"/current-save-copy.json"
	if FileAccess.file_exists(current_path):
		var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(current_path))
		check(state.restore(current).is_empty() and state.is_test_save,"actual current save copy recognizes its historical test grants")
		check(Access.can_open(state),"current player can still open breakthrough")
		check(MapLoadoutStore.save(state,output+"/roundtrip.json").is_empty(),"migrated flag saves")
		var copy:=MapLoadoutStore.candidate(state)
		check(copy.error.is_empty() and copy.state.is_test_save,"test identity survives candidate/save transitions")
		copy.state.is_test_save=false
		check(MapLoadoutStore.load_into(copy.state,output+"/roundtrip.json").is_empty() and copy.state.is_test_save,"test identity survives disk reload")
	if DisplayServer.get_name()!="headless":
		await capture(map,state)
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("BREAKTHROUGH SHORTCUT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func capture(map: Control,state: MapLoadoutState) -> void:
	state.is_test_save=true
	state.set_map_shortcuts_collapsed(false)
	state.changed.emit()
	map.travel.paused=false
	map._sync_shortcut_visibility()
	var rail: Control=map.shortcut_bar
	for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dimensions
		await settle()
		rail._hovered=ID
		rail._show_hint()
		check(rail.buttons[ID].is_visible_in_tree(),"rendered breakthrough is expanded")
		check(rail.buttons[ID].position.y<rail.buttons["base.map_shortcut.bag"].position.y,"rendered breakthrough above bag")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/top-entry-%d.png"%dimensions.x)
