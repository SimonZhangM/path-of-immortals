extends SceneTree
## Only this feature: progress gates, unread receipts, delayed hover, rail and entry clicks.
const Shortcuts = preload("res://scripts/map/map_shortcut_state.gd")
const BAG := "base.map_shortcut.bag"
const BOOKS := "base.map_shortcut.techniques"
const TASKS := "base.map_shortcut.tasks"
const WORLD := "base.map_shortcut.world"
var checks := 0
var failures := 0
var output := "res://artifacts/map-shortcuts-20261113"
var visual_only := "--visual-only" in OS.get_cmdline_user_args()

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func settle() -> void:
	for i in range(4): await process_frame

func move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	root.push_input(event,true)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	move(point)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)

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
	var map=load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	map.defer_location_save=true
	map.defer_optional_views=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"real town initializes")
	if not map.startup_error.is_empty(): quit(1); return
	map._location_active=true
	var state: MapLoadoutState=map.loadout
	# Use an empty narrative/knowledge fixture, without touching any player save.
	state.knowledge.learned.clear()
	state.quests=QuestState.initial(0)
	state.map_visited={"base.map.qingshizhen":["base.map.qingshizhen.point.n03"]}
	state.map_location={"map_id":"base.map.qingshizhen","point_id":"base.map.qingshizhen.point.n03"}
	state.map_shortcuts={}
	state.sync_map_shortcuts()
	map.travel.paused=false
	map._sync_shortcut_visibility()
	var rail: Control=map.shortcut_bar
	check(state.map_shortcuts.unlocked==[BAG],"new player has only bag")
	check(state.map_shortcuts.unread.is_empty(),"migration/new baseline does not label all starting inventory new")
	check(rail.buttons[BAG].visible and not rail.buttons[BOOKS].visible,"locked entries are absent")
	map.set_world_map_open(true)
	map.set_technique_open(true)
	map.set_task_open(true)
	check(not map.is_world_map_open() and not map.is_technique_open() and not map.is_task_open(),"locked screens cannot bypass via normal commands")
	state.quests[QuestState.ID].counts.talk=1
	state.changed.emit()
	check(TASKS in state.map_shortcuts.unlocked and TASKS in state.map_shortcuts.unread,"first actual quest unlocks task and notifies")
	state.visit_map_point("base.map.xiyuanyaopo","base.map.xiyuanyaopo.point.n01")
	check(WORLD in state.map_shortcuts.unlocked and WORLD in state.map_shortcuts.unread,"first departure unlocks map and notifies")
	var book_id: String=state.registry.library.books.keys()[0]
	state.knowledge.acquire(state.registry.library,book_id)
	state.changed.emit()
	check(BOOKS in state.map_shortcuts.unlocked and BOOKS in state.map_shortcuts.unread,"first book unlocks techniques")
	state.mark_map_shortcut_read("map_world_map")
	state.visit_map_point("base.map.xiyuanyaopo","base.map.xiyuanyaopo.point.n02")
	check(WORLD not in state.map_shortcuts.unread,"walking within known region does not create false coordinate alert")
	state.visit_map_point("base.map.diecuifeng","base.map.diecuifeng.point.n01")
	check(WORLD in state.map_shortcuts.unread,"new world location notifies")
	var item_id: String=state._owned.values()[0]
	var reward := {"id":"base.map_reward.shortcut_test","item_id":item_id,"quantity":1}
	check(MapLoadoutStore.claim_reward(state,reward,"").is_empty(),"actual candidate/save/publish reward transaction succeeds")
	check(BAG in state.map_shortcuts.unread,"acquisition of another item in existing stack notifies")
	state.mark_map_shortcut_read("map_inventory")
	state.changed.emit()
	check(BAG not in state.map_shortcuts.unread,"no new acquisition does not relight")
	check(TASKS in state.map_shortcuts.unread and WORLD in state.map_shortcuts.unread,"reading bag leaves other alerts intact")
	state.mark_map_shortcut_read("map_tasks")
	state.quests[HerbQuest.ID].accepted_location="base.map.qingshizhen"
	state.changed.emit()
	check(TASKS in state.map_shortcuts.unread,"new accepted side quest notifies independently of task presentation")
	state.mark_map_shortcut_read("map_techniques")
	state.knowledge.acquire(state.registry.library,state.registry.library.books.keys()[1])
	state.changed.emit()
	check(BOOKS in state.map_shortcuts.unread,"another new book relights technique notification")
	var saved := state.snapshot()
	var copy := MapLoadoutStore.candidate(state)
	check(copy.error.is_empty() and copy.state.map_shortcuts==state.map_shortcuts,"candidate transactions preserve unread ledger")
	check(copy.state.restore(saved).is_empty(),"new save restores")
	check(copy.state.map_shortcuts==state.map_shortcuts,"read receipts persist after restore")
	state.set_map_shortcuts_collapsed(true)
	check(MapLoadoutStore.save(state,output+"/isolated-save.json").is_empty(),"UI preference and unread ledger save to isolated disk")
	check(MapLoadoutStore.load_into(copy.state,output+"/isolated-save.json").is_empty(),"saved shortcut state reloads from disk")
	check(copy.state.map_shortcuts.collapsed and copy.state.map_shortcuts.unread==state.map_shortcuts.unread,"collapse and unread survive disk round trip")
	state.set_map_shortcuts_collapsed(false)
	var legacy := saved.duplicate(true)
	legacy.erase("map_shortcuts")
	check(copy.state.restore(legacy).is_empty(),"old saves migrate without a new required field")
	check(copy.state.map_shortcuts.unread.is_empty() and copy.state.map_shortcuts.unlocked.size()==4,"legacy progress unlocks entries without spurious red dots")
	var broken := saved.duplicate(true)
	broken.map_shortcuts.collapsed="bad"
	check(not copy.state.restore(broken).is_empty(),"malformed UI state rejected")
	rail.refresh(state.map_shortcuts)
	await settle()
	var previous_y := -1.0
	for id in [BAG,BOOKS,TASKS,WORLD]:
		var button: Control=rail.buttons[id]
		check(button.visible and button.position.y>previous_y,"ordered visible entry "+id)
		previous_y=button.position.y
	check(rail.buttons[WORLD].get_global_rect().get_center().is_equal_approx(Vector2(62,1024)),"lowest map circle is fixed at lower-left anchor")
	check(rail.toggle_button.size.x==rail.buttons[BAG].size.x*0.5,"toggle radius is half icon radius")
	check(rail.hover_timer.wait_time==3.0,"tooltip delay exactly three seconds")
	if not visual_only:
		move(rail.buttons[BOOKS].get_global_rect().get_center())
		await create_timer(2.6).timeout
		check(not rail.tooltip.visible,"no tooltip before three seconds")
		await create_timer(0.5).timeout
		check(rail.tooltip.visible and rail.tooltip.title_label.text=="功法","correct tooltip after three seconds")
		check(rail.tooltip.shortcut_label.text==preload("res://scripts/settings/settings_input.gd").action_label("map_techniques"),"tooltip reads actual configured shortcut")
		move(Vector2(500,500))
		await settle()
		check(not rail.tooltip.visible,"leaving cancels hint")
		move(rail.buttons[TASKS].get_global_rect().get_center())
		await create_timer(0.3).timeout
		move(Vector2(500,500))
		await create_timer(3.0).timeout
		check(not rail.tooltip.visible,"canceled hover never appears at stale entry")
		click(rail.toggle_button)
		await create_timer(0.3).timeout
		check(rail.collapsed and state.map_shortcuts.collapsed,"collapse click persists preference")
		check(rail.toggle_button.get_global_rect().get_center().is_equal_approx(Vector2(62,1024)),"collapsed toggle moves to bottom anchor")
		check(rail.toggle_button.collapsed and not rail.buttons[WORLD].visible,"up arrow alone remains after collapse")
		check(rail.buttons[BOOKS].mouse_filter==Control.MOUSE_FILTER_STOP and not rail.buttons[BOOKS].visible,"hidden entries cannot receive clicks")
		click(rail.toggle_button)
		await create_timer(0.3).timeout
		check(not rail.collapsed and rail.buttons[WORLD].visible,"expand click restores entries")
		click(rail.toggle_button)
		await create_timer(0.08).timeout
		click(rail.toggle_button)
		await create_timer(0.3).timeout
		check(not rail.collapsed and rail.buttons[BOOKS].visible and not rail._animating,"rapid toggle reverses cleanly without stranded invisible buttons")
		for entry: Dictionary in Shortcuts.config.entries:
			if entry.id not in state.map_shortcuts.unlocked: continue
			if entry.id not in state.map_shortcuts.unread: state.map_shortcuts.unread.append(entry.id)
			rail.refresh(state.map_shortcuts)
			click(rail.buttons[entry.id])
			await settle()
			var opened: bool={"map_inventory":map.is_inventory_open(),"map_techniques":map.is_technique_open(),"map_tasks":map.is_task_open(),"map_world_map":map.is_world_map_open()}[entry.action]
			check(opened,"actual icon click opens "+entry.title)
			check(entry.id not in state.map_shortcuts.unread,"opening clears only corresponding alert "+entry.title)
			check(not rail.visible,"rail hidden behind fullscreen "+entry.title)
			match entry.action:
				"map_inventory": map.set_inventory_open(false)
				"map_techniques": map.set_technique_open(false)
				"map_tasks": map.set_task_open(false)
				"map_world_map": map.set_world_map_open(false)
			map.travel.paused=false
			map._sync_shortcut_visibility()
			await settle()
		check(rail.visible,"all screens return to normal map rail")
		state.notify_map_shortcut(BAG)
		map.set_inventory_open(true)
		await settle()
		check(BAG not in state.map_shortcuts.unread,"keyboard/shared opening path also clears notification")
		map.set_inventory_open(false)
		map.travel.paused=false
		map._sync_shortcut_visibility()
		map._open_system_menu()
		map._sync_shortcut_visibility()
		check(not rail.visible,"system menu suppresses rail and pending hint")
		map.system_menu_controller.close()
		map.travel.paused=false
		map._sync_shortcut_visibility()
	if DisplayServer.get_name()!="headless":
		state.map_shortcuts.unread=[BAG,TASKS,WORLD]
		rail.refresh(state.map_shortcuts)
		for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size=dimensions
			await settle()
			rail._hovered=BOOKS
			rail.buttons[BOOKS].hover_amount=1.0
			rail.buttons[BOOKS].queue_redraw()
			rail._show_hint()
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/expanded-%d.png"%dimensions.x)
			rail.set_collapsed(true,false)
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/collapsed-%d.png"%dimensions.x)
			rail.set_collapsed(false,false)
	map.deactivate_location()
	map.queue_free()
	await settle()
	print("MAP SHORTCUTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
