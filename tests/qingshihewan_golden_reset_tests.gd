extends SceneTree

const DIR := "res://artifacts/qingshihewan-golden-reset/"
const RANK := "base.cultivation.golden_core"
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"plan.json"))
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"candidate.json"))
	check(FileAccess.get_sha256(DIR+"candidate.json")==plan.candidate_sha256,"prepared candidate hash")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(DIR+"candidate.json"),ProjectSettings.globalize_path(DIR+"run.json"))==OK,"isolated copy")
	MapEventState.session_completed.clear()
	MapEventState.session_encounters.clear()
	var map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path=DIR+"run.json"
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	for frame in 8: await process_frame
	check(map.startup_error.is_empty(),"map startup: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	var status: MapPlayerStatus=map.player_status
	check(status.cultivation_rank_id==RANK and status.rank_name=="结丹 · 一层","map rank and layer")
	check(status.lifespan==500,"lifespan 500")
	check(status.cultivation_required==25000 and is_equal_approx(status.cultivation_progress,20.8),"progress retained and target updated")
	check(map.loadout.growth.roots==raw.growth.roots,"roots retained")
	var learning: Dictionary=map.loadout.knowledge.snapshot()
	# JSON numbers restore as floats; compare the version numerically.
	check(int(learning.version)==int(raw.learning.version) and learning.learned==raw.learning.learned and learning.practice==raw.learning.practice,"learning retained")
	check(map.loadout.growth.experience==raw.growth.experience,"experience retained")
	for key: String in plan.maxima:
		check(status.maxima[key]==int(plan.maxima[key]),"map maximum "+key)
		check(is_equal_approx(status.resources[key],raw.growth.resources[key]/100.0),"map current "+key)
		check(map.status_header.values[key].text=="%d/%d" % [status.resources[key],status.maxima[key]],"header values "+key)
	check(map.status_header._frame_rank_id==RANK,"map portrait rank refreshed")
	check(map.status_header.hero_rank.text==status.rank_name,"header rank")
	check(map.status_header.values.cultivation.text=="20.8/25000","header cultivation")
	for id: String in plan.encounters:
		check(map.event_registry.events.has(id),"encounter registered "+id)
		check(not map.event_state.completed.has(id) and not map.loadout.encounter_cooldowns.has(id),"encounter alive "+id)
		check(map.event_state._available(map.event_state.resolved_event(id)),"enemy content available "+id)
	var manager:=GameManager.new()
	manager.use_saved_loadout=true
	manager.loadout_save_path=DIR+"run.json"
	manager.player_snapshot=status.battle_snapshot()
	root.add_child(manager)
	manager.set_process(false)
	check(manager.startup_error.is_empty(),"battle startup: "+manager.startup_error)
	var member: PartyMemberState=manager.party[0]
	check(member.cultivation_rank_id==RANK and T01CombatRules.rank(member)==3,"battle cultivation rank")
	for key: String in plan.maxima:
		check(member.maximum(key)==int(plan.maxima[key]),"battle maximum "+key)
		check(is_equal_approx(float(member.get(key)),status.resources[key]),"battle current "+key)
	check(manager.startup_error.is_empty() and manager.simulation.configuration_error.is_empty(),"existing board remains valid")
	check(FileAccess.get_sha256(DIR+"candidate.json")==plan.candidate_sha256,"candidate not mutated")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR+"map.png")
	manager.queue_free()
	map.queue_free()
	for frame in 8: await process_frame
	var file:=FileAccess.open(DIR+"verified.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"candidate_sha256":plan.candidate_sha256}))
	file.close()
	print("GOLDEN CORE RESET: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
