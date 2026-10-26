extends SceneTree

const DIR := "res://artifacts/xiyuanyaopo-chest-art/"
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(DIR)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(),"content")
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(created.error.is_empty(),"memory-only state")
	var model: MapLoadoutState=created.state
	var records: Array[Dictionary]=[]
	for category in ["weapon","armor"]:
		for record: Dictionary in model.records.values():
			if record.category==category and record.quality=="下品":
				var entry:=record.duplicate(true)
				entry.quantity=1
				records.append(entry)
				break
	var observation=load("res://scripts/map/map_chest_observation_dialog.gd").new()
	var result=load("res://scripts/map/map_chest_dialog.gd").new()
	for dialog: Control in [observation,result]:
		root.add_child(dialog)
		dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dialog.hide()
	var mapping := {"n05":"xiyashuxi","n16":"huayinshiping"}
	for node: String in mapping:
		var event: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/xiyuanyaopo_chest_"+node+".json"))
		for stage in [1,2]:
			var dialog: Control=observation if stage==1 else result
			var key: String="illustration" if stage==1 else "result_illustration"
			var path: String="res://assets/tanchuang-xxyp-baoxiang-"+mapping[node]+str(stage)+".webp"
			check(event.presentation[key]==path,"mapping "+node+str(stage))
			if stage==1: observation.present(event)
			else: result.present_choices(event,records,{"weapon":"武器","armor":"防具"},model)
			for i in 3: await process_frame
			if stage==1:
				var icon_path: String="res://assets/tanchuang-xxyp-baoxiang-"+mapping[node]+"0.webp"
				check(event.presentation.chest_image==icon_path and observation.chest_image.texture.resource_path==icon_path,"matching separate chest")
				check(observation.chest_image.texture.get_image().has_mipmaps(),"chest icon mipmaps")
				check(observation.chest_image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"chest keeps aspect centered")
				check((observation.chest_image.get_meta("source_rect") as Rect2).size.is_equal_approx(Vector2(177.3,160.2)),"existing 90 percent chest slot")
			check(dialog.location_illustration.texture.resource_path==path,"display "+node+str(stage))
			check(dialog.location_illustration.texture.get_image().has_mipmaps(),"mipmaps")
			check(dialog.location_illustration.clip_contents and dialog.location_illustration.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"aspect and clipping")
			check(dialog.location_illustration.get_meta("source_rect")==dialog.location_frame.get_meta("source_rect").grow(-4),"frame inset")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(DIR+node+"-"+str(stage)+".png")
			dialog.hide()
	observation.queue_free()
	result.pick_sound.stream=null
	result.queue_free()
	await process_frame
	print("XIYUANYAOPO CHEST ART: ",checks," checks, ",failures," failures; static only, no saves or input.")
	quit(0 if failures==0 else 1)
