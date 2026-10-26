extends SceneTree

const DIR := "res://artifacts/xiyuanyaopo-art/"
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(DIR)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "content loads")
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "memory-only inventory")
	var model: MapLoadoutState = created.state
	var expected := {
		"gathering_n07":"caiyao-huapoaicong", "gathering_n12":"caiyao-beipoaicong",
		"gathering_n13":"caiyao-xiqiaoshitai", "gathering_n18":"caiyao-puqianshitai",
		"mining_n10":"wakuang-xiyalingkuang", "mining_n17":"wakuang-dongyayalingkuang",
		"mining_n15":"wakuang-nanyacutiekuang"
	}
	var dialogs := {}
	var only := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): only=argument.trim_prefix("--only=")
	for key: String in expected:
		if not only.is_empty() and key!=only: continue
		var event: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/xiyuanyaopo_"+key+".json"))
		var record := MapGatheringRewards.record_for(model.records,event.item_id)
		var profile := MapGatheringOptions.path_for_record(record)
		if not dialogs.has(profile):
			var dialog := MapGatheringDialog.new(profile)
			root.add_child(dialog)
			dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			dialogs[profile]=dialog
		var dialog: MapGatheringDialog = dialogs[profile]
		var path: String = "res://assets/tanchuang-xyyp-"+expected[key]+".webp"
		check(event.presentation.illustration==path,"exact mapping "+key)
		dialog.bind_herb(record,model,event.presentation)
		dialog.present(event.title)
		for i in 3: await process_frame
		check(dialog.location_illustration.texture.resource_path==path,"display path "+key)
		check(dialog.location_illustration.visible and dialog.location_frame.visible,"image and frame visible "+key)
		check(dialog.location_illustration.texture.get_image().has_mipmaps(),"mipmaps "+key)
		check(dialog.location_illustration.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED and dialog.location_illustration.clip_contents,"contained aspect "+key)
		check(dialog.location_illustration.get_meta("source_rect")==dialog.location_frame.get_meta("source_rect").grow(-4),"frame inset "+key)
		check(dialog.heading.text==event.title and dialog.herb_name.text==record.name,"location and resource intact "+key)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR+key+".png")
		dialog.hide()
	for dialog: MapGatheringDialog in dialogs.values(): dialog.queue_free()
	await process_frame
	print("XIYUANYAOPO ART: ",checks," checks, ",failures," failures; static only, no save IO or input.")
	quit(0 if failures==0 else 1)
