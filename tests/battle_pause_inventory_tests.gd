extends SceneTree

var checks := 0
var failures := 0
var game: GameManager

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for i in 8: await process_frame

func stock(item: String) -> String:
	for entry: Dictionary in game.storage.entries():
		if entry.item_id == item: return entry.instance_id
	return ""

func key_i() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_I
	event.physical_keycode = KEY_I
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func right_click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	game = scene.get_node("GameManager")
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	await settle()
	var ui = scene.get_node("MainUI")
	check(game.startup_error.is_empty(), "actual battle starts")
	var hammer := stock("base.map_item.short_iron_hammer")
	check(game.equip(hammer,0,Vector2i.ZERO), "original weapon equipped before combat")
	game.start_battle()
	game.simulation.advance(1.2)
	game.pause_battle()
	if DisplayServer.get_name() == "headless":
		key_i()
		await settle()
		check(game.adjustment_open and ui.storage_panel.visible, "paused I opens actual storage")
		right_click(ui.storage_panel.get_global_rect().position+Vector2(6,6))
		check(game.adjustment_open, "inside right click does not dismiss storage")
		right_click(Vector2(20,600))
		check(not game.adjustment_open and not ui.storage_panel.visible, "outside right click dismisses storage")
		key_i()
		check(game.adjustment_open, "I reopens during same pause")
		key_i()
		check(not game.adjustment_open, "I toggles closed")
	game.set_adjustment(true)
	var sim := game.simulation
	var before := sim.timeline.remaining(hammer)
	var count: int = sim.state.item_runtime[hammer].activation_count
	sim.timeline.set_mode(hammer,false)
	check(game.unequip(0,hammer), "original item returned to storage")
	check(game.equip(stock("base.map_item.short_iron_hammer"),0,Vector2i(1,0)), "original item returns to another cell")
	check(sim.cooling_remaining_usec(hammer)==0, "normal item does not acquire a new insertion CD")
	check(sim.timeline.remaining(hammer)==before and sim.state.item_runtime[hammer].activation_count==count, "cycle progress and activation count preserved")
	check(not sim.timeline.timers[hammer].auto, "manual mode preserved")
	sim.timeline.set_mode(hammer,true)
	var dagger := stock("base.map_item.t01_0005")
	check(game.equip(dagger,0,Vector2i.ZERO), "genuinely new item placed")
	check(sim.cooling_remaining_usec(dagger)==3000000, "new item retains 3s insertion CD")
	game.toggle_pause()
	check(sim._paused_returns.is_empty(), "resuming clears same-pause cache")
	sim.advance(.8)
	game.pause_battle()
	game.set_adjustment(true)
	var entry_left := sim.cooling_remaining_usec(dagger)
	check(entry_left > 0 and entry_left < 3000000, "new item partially through entry CD")
	check(game.unequip(0,dagger) and game.equip(stock("base.map_item.t01_0005"),0,Vector2i.ZERO), "partially cooling item round trip")
	check(sim.cooling_remaining_usec(dagger)==entry_left, "remaining entry CD preserved rather than reset or waived")
	for i in 3:
		game.unequip(0,dagger)
		game.equip(stock("base.map_item.t01_0005"),0,Vector2i.ZERO)
	check(sim.cooling_remaining_usec(dagger)==entry_left, "repeated swaps cannot shorten entry CD")
	game.unequip(0,dagger)
	game.toggle_pause()
	game.pause_battle()
	game.set_adjustment(true)
	game.equip(stock("base.map_item.t01_0005"),0,Vector2i.ZERO)
	check(sim.cooling_remaining_usec(dagger)==3000000, "new pause is new insertion even without elapsed combat time")
	game.set_adjustment(false)
	game.toggle_pause()
	sim.advance(sim.timeline.remaining(hammer)/1000000.0+.01)
	check(sim.state.item_runtime[hammer].activation_count==count+1, "original deadline fires once without stale queued duplicate")
	if DisplayServer.get_name() == "headless":
		key_i()
		check(not game.adjustment_open, "I cannot open storage while battle runs")
	game.pause_battle()
	for path in ["bt-button","bt-zhihuan","bt-chetui","icon-battle","icon-wait","button-battle-fightlog"]:
		check((load("res://assets/"+path+".webp") as Texture2D).get_image().has_mipmaps(), "actual mipmaps " + path)
	check(CooldownRing.FONT_SIZE==10 and CooldownRing.countdown_text(4.4)=="4.4", "timer no s and one size larger")
	var card: PartyMemberCard = ui.ally_panel.cards[0]
	check(card.armor_status.icon.position.x==1.5, "armor moved left one px")
	for row: DefenseResourceRow in [card.armor_status, card.barrier_status]:
		check(row.icon.get_child_count()==16, "smooth outline samples")
		for outline: TextureRect in row.icon.get_children():
			check(outline.self_modulate==Color.BLACK and is_equal_approx(outline.position.length(),1), "one px black silhouette")
	var font: Font = ui._time.get_theme_font("font")
	var baseline: float = (ui._time.size.y-font.get_height(39))*.5+font.get_ascent(39)
	var small_font: Font = ui._time_seconds.get_theme_font("font")
	check(is_equal_approx(ui._time_seconds.position.y+small_font.get_ascent(20)+CooldownRing.ink_vertical_bounds(small_font,"秒",20).y,baseline+CooldownRing.ink_vertical_bounds(font,ui._time.text,39).y), "seconds and digits share visible bottom edge")
	game.set_adjustment(true)
	game.unequip(0,hammer)
	check(game.party[0].inventory.add_item("test.shield","base.map_item.t01_0096",Vector2i(2,0)), "shield render fixture")
	check(game.party[0].inventory.add_item("test.hide","base.organ.cslz_hide",Vector2i(0,1)), "armor render fixture")
	game.unequip(0,dagger)
	sim.clear_paused_returns()
	game.equip(stock("base.map_item.t01_0005"),0,Vector2i.ZERO)
	game.set_adjustment(false)
	game.party[0].armor_capacity_sources.test=6
	game.party[0].armor=3
	game.party[0].barrier=25
	ui._refresh()
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-pause-inventory.png")
	scene.queue_free()
	await settle()
	print("BATTLE PAUSE INVENTORY: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
