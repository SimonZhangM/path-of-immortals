extends SceneTree
const FRAMES = preload("res://scripts/presentation/player_portrait_frames.gd")
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 6: await process_frame
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(2560,1440)
	var scene: Node=load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager=scene.get_node("GameManager")
	game.loadout_save_path=""
	root.add_child(scene);game.set_process(false)
	await settle()
	assert(game.startup_error.is_empty(),game.startup_error)
	var ui=scene.get_node("MainUI")
	var card: PartyMemberCard=ui.ally_panel.cards[0]
	var enemy_texture: Texture2D=ui.enemy_panel.cards[0].portrait.texture
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json"))
	var state:=MapPlayerStatus.new();assert(state.configure(game.registry,config).is_empty())
	var header:=MapStatusHeader.new();header.size=Vector2(2560,1440)
	root.add_child(header);assert(header.configure(state,config).is_empty());header.map_title.hide()
	var ranks: Array[String]=["mortal","qi_refining","foundation","golden_core","nascent_soul","spirit_transformation"]
	var gallery:=Image.create(1800,1000,false,Image.FORMAT_RGBA8);gallery.fill(Color("101821"))
	var first_portrait:=Rect2()
	for i in ranks.size():
		var id: String="base.cultivation."+ranks[i]
		state.cultivation_rank_id=id;state.rank_name=game.registry.get_cultivation(id).name;state.changed.emit()
		assert(game.party[0].set_cultivation_rank(id));card.refresh(game.party[0])
		await settle()
		var expected: String="res://assets/player-level-%d.webp"%(i+1)
		assert(FRAMES.path_for(id)==expected)
		assert(header.portrait_frame.texture.atlas.resource_path==expected)
		assert(card.portrait_frame.texture.resource_path==expected)
		assert(card.portrait_frame.texture.get_image().has_mipmaps())
		assert(not card._portrait_slot.clip_contents)
		var top: float=header.portrait_frame.get_global_rect().position.y + header.portrait_frame.texture.atlas.get_image().get_used_rect().position.y * header.portrait_frame.get_global_rect().size.y/610.0
		assert(top>=1.9, "map ornament stays below screen top")
		assert(header.portrait_frame.texture.region==Rect2(0,0,543,610))
		if i==0: first_portrait=card.portrait.get_rect()
		else: assert(card.portrait.get_rect().is_equal_approx(first_portrait))
		var source_scale: float=card._portrait_slot.size.x/510.0
		assert((card.portrait_frame.position+FRAMES.SOURCE_CENTER*source_scale).is_equal_approx(card.portrait.get_rect().get_center()))
		assert(ui.enemy_panel.cards[0].portrait.texture==enemy_texture)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var shot:=root.get_texture().get_image()
			var tile:=Vector2i((i%3)*600,(i/3)*500)
			var map_rect:=Rect2i(header.portrait_frame.get_global_rect().grow(5))
			var battle_rect:=Rect2i(card._portrait_slot.get_global_rect().grow(45))
			gallery.blit_rect(shot,map_rect,tile+Vector2i(10,10))
			gallery.blit_rect(shot,battle_rect,tile+Vector2i(180,10))
			if i==5: shot.save_png("res://artifacts/player-level-6-screen.png")
	if DisplayServer.get_name()!="headless": gallery.save_png("res://artifacts/player-level-six-preview.png")
	header.queue_free();scene.queue_free();await settle()
	for node in root.find_children("*","AudioStreamPlayer",true,false): node.stop();node.stream=null
	await settle()
	print("PASS: six realm mappings, actual battle startup, map/battle rank refresh, full ornament bounds, fixed portrait geometry, mipmaps and unchanged enemy art. No mouse or durable save.")
	quit()
