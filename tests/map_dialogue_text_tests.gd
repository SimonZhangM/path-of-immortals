extends "res://tests/save_actions_tests.gd"
const Formatter = preload("res://scripts/dialogue/map_dialogue_text.gd")
const Playback = preload("res://scripts/dialogue/dialogue_playback.gd")

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	directory = "res://artifacts/map-dialogue-text/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	var backdrop := ColorRect.new()
	backdrop.color = Color("4b606a")
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := MapDialogue.new()
	view.player_status = MapPlayerStatus.new()
	view.player_status.display_name = "张辰宇"
	view.player_status.cultivation_rank_id = "base.cultivation.nascent_soul"
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var registry := MapEventRegistry.new()
	var event := QuestStory.event("morning")
	registry.events[event.id] = event
	check(view.prepare(registry).is_empty(),"quest dialogue art prepares")
	var sample := "好的，叶伯，我知道了。我先去溪源药坡采药，再回青石镇的药材铺找您。[b]只是原文[/b]"
	view.present(event,sample,"base.map_player.chen_yu")
	await settle()
	check(view.text_label.get_parsed_text()==sample,"literal brackets remain literal; styled text unchanged")
	check(view.text_label.get_theme_color("default_color")==Color.WHITE and view.speaker_name.get_theme_color("font_color")==Color.WHITE,"dialogue and speaker default to white")
	check(view.text_label.get_theme_font("bold_font").font_weight==700 and Formatter.config.color=="f0dfba","place names use original gold and bold face")
	var playback := Playback.new()
	var plain := Label.new()
	plain.text = "普通气泡"
	playback.begin([view.text_label,plain],"medium")
	check(playback.character_count==sample.length()+plain.text.length(),"mixed labels count visible characters only")
	check(not playback.advance(0.1,"medium",false) and view.text_label.visible_characters==3 and plain.visible_characters==0,"typewriter reveals literal characters across runs")
	check(playback.finish_reveal() and plain.visible_characters==-1,"click can finish all text")
	check(not playback.advance(1.9,"medium",true) and playback.advance(0.1,"medium",true),"auto advances only after two seconds fully revealed")
	check(not playback.advance(5,"medium",true),"auto fires once")
	Formatter.apply(view.text_label,"")
	playback.begin([view.text_label],"instant")
	check(playback.character_count==0,"empty text clears previous formatting")
	view.set_line_text("回药材铺。\n保存失败，请重试。",false)
	check(view.text_label.get_parsed_text()=="回药材铺。\n保存失败，请重试。" and not view.playback.is_revealing(),"error refresh retains literal formatting and reveals entire message")
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		for speaker in ["base.npc.yesongnian","base.map_player.chen_yu"]:
			view.present(event,"好的，叶伯，我知道了。我先去溪源药坡采药，再回青石镇的药材铺找您。",speaker)
			await settle()
			check(view.text_label.get_content_height()<=view.text_label.size.y,"wrapped dialogue fits at "+str(resolution))
			if DisplayServer.get_name()!="headless": await capture(speaker.get_slice(".",2)+"-"+str(resolution.x))
	# Quest wording remains indexed exactly as authored for existing story cursors.
	check(QuestStory.data.scenes.morning.lines.size()==10 and QuestStory.data.scenes.returning.lines.size()==13,"respectful edits preserve saved line indexes")
	check(QuestStory.data.scenes.morning.lines[7].begins_with("好的，叶伯，我知道了"),"elder acknowledgement revised")
	plain.free()
	view.free()
	backdrop.free()
	print("MAP_DIALOGUE_TEXT: %d checks; %d failures" % [checks,failures])
	print("OUTPUT: "+directory)
	quit(1 if failures else 0)
