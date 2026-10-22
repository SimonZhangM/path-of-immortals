extends SceneTree

func _initialize() -> void: run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func run() -> void:
	var path:=MapLoadoutStore.session_path(MapLoadoutStore.DEFAULT_PATH)
	if not FileAccess.file_exists(path): fail("已有存档不存在。"); return
	var original:=FileAccess.get_file_as_string(path)
	var raw: Dictionary=JSON.parse_string(original)
	var registry:=ContentRegistry.new()
	if not registry.load_base_content(): fail(str(registry.errors)); return
	var made:=MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	if not made.error.is_empty(): fail(made.error); return
	var state: MapLoadoutState=made.state
	# Read legacy learning without invoking automatic inventory migrations.
	if not raw.has("learning"):
		var legacy:=CultivationStore.load_into(state.knowledge,registry.library,5,path+".cultivation.json")
		if not legacy.is_empty(): fail(legacy); return
	var error:=state.restore(raw)
	if not error.is_empty(): fail(error); return
	if state.growth.is_empty():
		state.growth=CultivationGrowth.initial(5)
		var base:=CultivationGrowth.maxima(state.growth)
		for key: String in base: state.growth.resources[key]=(int(base[key])+state.board.resource_bonus(key))*100
		state.growth.experience=int(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json")).experience)
	state.growth.roots=CultivationGrowth.ELEMENTS.duplicate()
	var next:=state.snapshot()
	for key: String in raw:
		if key in ["growth","learning"]: continue
		if JSON.stringify(raw[key])!=JSON.stringify(next.get(key)) and raw[key]!=JSON.parse_string(JSON.stringify(next.get(key))):
			fail("无关字段变化，停止写入："+key); return
	print("GROWTH: realm ",state.growth.realm," layer ",state.growth.layer," roots ",state.growth.roots.size()," books ",state.knowledge.learned.size()," bag ",state.storage_used_slots())
	if "--apply" not in OS.get_cmdline_user_args(): print("DRY RUN; original save unchanged"); quit(); return
	if raw==JSON.parse_string(JSON.stringify(next)): print("Already migrated; no write"); quit(); return
	if FileAccess.get_file_as_string(path)!=original: fail("存档已被其他进程修改，请重试。"); return
	var backup:=ProjectSettings.globalize_path(path)+".before-growth-%d.bak" % int(Time.get_unix_time_from_system())
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),backup)!=OK: fail("无法备份存档。"); return
	error=MapLoadoutStore.save(state,path)
	if not error.is_empty(): fail(error); return
	if JSON.parse_string(FileAccess.get_file_as_string(path))!=JSON.parse_string(JSON.stringify(next)): fail("写入后核对失败。"); return
	print("APPLIED; backup: ",backup)
	quit()
