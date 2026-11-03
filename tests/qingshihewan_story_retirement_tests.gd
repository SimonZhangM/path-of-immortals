extends SceneTree
## Exercise the actual map registry with fresh and historical completion records.
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
const OUTPUT := "res://artifacts/qingshihewan-story-retirement-20261031/"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	Slots.auto_path = OUTPUT+"auto.json"
	Session.index_path = OUTPUT+"session.json"
	Session.clear_selection()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false})
	root.get_node("GameSettings").set_application_focus(true)
	var screen = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	screen.inventory_save_path = ""
	screen.defer_map_music = true
	screen.defer_optional_views = true
	root.add_child(screen)
	for i in 6: await process_frame
	check(screen.startup_error.is_empty(),"actual river map starts")
	if not screen.startup_error.is_empty():
		finish()
		return
	screen.set_process(false)
	var registry: MapEventRegistry = screen.event_registry
	check(registry.events.size()==24,"24 non-story interactions remain")
	for event: Dictionary in registry.events.values():
		check(event.type!="dialogue","no old river dialogue: "+event.id)
	var points: Node = screen.content.get_node("Points")
	check(points.get_child_count()==40,"all 40 route points remain")
	check(screen.content.get_node("Routes").get_child_count()==44,"all 44 routes remain")
	for node_name: String in ["N03","N16","N20","N37"]:
		var point = points.get_node(node_name)
		check(point.get_node_or_null("Sign")==null,"no obsolete story sign: "+node_name)
		check(not registry.by_point.has(point.point_id),"no old event binding: "+node_name)
		for history: Dictionary in [{},{"base.map_event.qingshihewan.bridge_traces":true,"base.map_event.qingshihewan.wounded_disciple":true}]:
			var before := history.duplicate(true)
			var state := MapEventState.new(registry,history)
			check(not state.try_start(point.point_id,point.point_id,true,"arrival"),"arrival cannot launch retired story: "+node_name)
			check(not state.try_start(point.point_id,point.point_id,true,"click"),"click cannot launch retired story: "+node_name)
			check(not state.is_active() and history==before,"history unchanged: "+node_name)
	check(screen.definition.exits.size()==1,"town exit preserved")
	check(QuestStory.configuration_error().is_empty(),"current main quest configuration remains valid")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"river-map.png")
	screen.queue_free()
	await process_frame
	finish()

func finish() -> void:
	var report := {"checks":checks,"failures":failures}
	FileAccess.open(OUTPUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RIVER_STORY_RETIREMENT: ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
