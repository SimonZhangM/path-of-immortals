extends SceneTree
## Export only. Never edits the source or starts formal character creation.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var source := ""
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): source = argument.trim_prefix("--source=")
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if source.is_empty() or output.is_empty() or not output.begins_with("res://artifacts/") or not FileAccess.file_exists(source):
		push_error("需要已有源存档与res://artifacts/内的独立输出路径。")
		quit(1)
		return
	var registry := ContentRegistry.new()
	if not registry.load_base_content():
		push_error(str(registry.errors)); quit(1); return
	var made := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	if not made.error.is_empty():
		push_error(made.error); quit(1); return
	var state: MapLoadoutState = made.state
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var error := state.restore(original)
	if error.is_empty(): error = QuestStory.prepare_start(state)
	if not error.is_empty():
		push_error(error); quit(1); return
	var prepared := MapLoadoutStore.SaveMetadata.stamp(state.snapshot(),output,source)
	prepared.save_info.checkpoint_reason = "prologue_home_opening"
	# Gameplay outside the explicit opening fields must be unchanged after normalizing.
	var before: Dictionary = JSON.parse_string(JSON.stringify(original))
	var after: Dictionary = JSON.parse_string(JSON.stringify(prepared))
	for key: String in before:
		if key in ["quests","quest_tracking","map_location","save_info","narrative","gathering_offers"]: continue
		if before[key]!=after.get(key):
			push_error("开场准备意外改变字段："+key); quit(1); return
	if before.narrative.identity!=after.narrative.identity or before.narrative.npcs!=after.narrative.npcs:
		push_error("开场准备意外改变姓名或普通对话历史。"); quit(1); return
	var code := preload("res://scripts/entry/save_file.gd").write(output,prepared)
	if code!=OK: push_error(error_string(code)); quit(1); return
	print("PREPARED: "+output)
	print("HOME: "+str(prepared.map_location)+"; existing identity, possessions, growth and calendar preserved")
	quit()
