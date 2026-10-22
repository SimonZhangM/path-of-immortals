extends SceneTree

var checks := 0
var heard: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	assert(ok, message)
func settle() -> void:
	for i in 5: await process_frame
func capture(label: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/weapon-feedback-" + label + ".png")

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1920,1080)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = false
	root.add_child(scene)
	game.set_process(false)
	check(game.startup_error.is_empty(), "real battle startup")
	var created := MapLoadoutStore.create_state(game.registry, game.registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "register current map item catalog")
	var ui = scene.get_node("MainUI")
	var bag: InventoryView = ui.ally_panel.bags[0]
	for board in ui.ally_panel.bags + ui.enemy_panel.bags: board.set_process(false)
	game.companions.clear()
	game.enemy_companions.clear()
	var owner: PartyMemberState = game.party[0]
	owner.inventory = InventoryState.new(game.registry, Vector2i(3,3))
	check(owner.inventory.add_item("test.hammer", "base.map_item.short_iron_hammer", Vector2i.ZERO), "hammer fixture")
	owner.definition.max_stamina = 500
	owner.definition.max_hp = 10000
	game.enemies[0].definition.max_hp = 10000
	game.restart()
	game.start_battle()
	await settle()
	bag = ui.ally_panel.bags[0]
	for board in ui.ally_panel.bags + ui.enemy_panel.bags: board.set_process(false)
	var sim: BattleSimulation = game.simulation
	check(sim.state.phase == GameState.Phase.BATTLE, "battle starts")
	ui.game_audio.sound_played.connect(func(kind: String): heard.append(kind))
	for kind in ["pierce","throwable","blunt","magic"]:
		check(ui.game_audio.players[kind].stream.get_length() > 0, "audio decodes: " + kind)
	for row in [["base.map_item.hunting_bow","pierce"],["base.map_item.short_iron_hammer","blunt"],["base.map_item.t01_0111","throwable"],["base.map_item.qingshi_short_sword","hit"]]:
		check(GameAudio.impact_kind({"item_id":row[0],"damage_type":"穿刺"},game.registry) == row[1], "routing " + row[0])
	check(GameAudio.impact_kind({"damage_type":"法术型"},game.registry) == "magic", "magic damage routing")
	# Real activation produces the afterimage even if its hit is subsequently dodged.
	sim.drain_events()
	sim.t01.activate("test.hammer", 0)
	game.presentation_events.emit(sim.drain_events())
	bag._process(0)
	check(bag._weapon_feedback.has("test.hammer") and not bag._pulses.has("test.hammer"), "weapon replaces old white pulse")
	var fx = bag._weapon_feedback["test.hammer"]
	var base_rect: Rect2 = bag._artworks["test.hammer"].get_rect()
	check(fx.ghost.modulate.a == 0.5 and fx.ghost.scale == Vector2.ONE, "starts at full size, half alpha")
	await capture("success-start")
	bag._process(0.4)
	check(fx.ghost.scale == Vector2(1.5,1.5) and fx.ghost.modulate.a == 0.25, "halfway scale and opacity")
	check(bag._artworks["test.hammer"].get_rect().is_equal_approx(base_rect), "weapon itself stays fixed")
	await capture("success-half")
	bag._process(0.399)
	check(fx.ghost.scale.x > 1.99 and fx.ghost.modulate.a < 0.001, "finishes near double size and transparent")
	bag._process(0.002)
	check(bag._weapon_feedback.is_empty() and sim.state.time_usec == 0, "0.8 presentation seconds; no simulation advancement")
	# Ordinary exhausted CD is one discrete failure, with no hit/activation or payment.
	sim.drain_events()
	owner.stamina = 0
	sim.timeline.timers["test.hammer"].cd = 0.0
	sim.timeline.wake(0)
	var failed := sim.drain_events()
	check(failed.filter(func(e): return e.kind == "item_activation_failed").size() == 1, "insufficient resource failure once")
	check(not failed.any(func(e): return e.kind in ["item_activated","damage"]), "no false activation or hit")
	check(owner.stamina == 0 and sim.timeline.timers["test.hammer"].cd > 0, "failed cycle mechanics unchanged")
	heard.clear()
	game.presentation_events.emit(failed)
	bag._process(0)
	check(heard.is_empty(), "failure is silent")
	fx = bag._weapon_feedback["test.hammer"]
	check(fx.failed and not fx.ghost.visible, "failure selects red rim instead of ghost")
	bag._process(0.0666667)
	check(bag._artworks["test.hammer"].position.x > base_rect.position.x, "shake right")
	await capture("failed")
	check(is_equal_approx(fx.rim.border_color.a,0.5), "red rim is half transparent")
	bag._process(0.1333333)
	check(bag._artworks["test.hammer"].position.x < base_rect.position.x, "shake left")
	sim.timeline.wake(0)
	check(not sim.drain_events().any(func(e): return e.kind == "item_activation_failed"), "no frame polling duplicates")
	bag._process(0.61)
	check(bag._weapon_feedback.is_empty() and bag._artworks["test.hammer"].get_rect().is_equal_approx(base_rect), "failure ends and original position restored")
	# Next-round blocking and paralysis emit the same explicit failed-cycle event.
	owner.stamina = 500
	check(sim.timeline.block_next_round("test.hammer",0), "block token")
	sim.timeline.timers["test.hammer"].cd = 0.0
	sim.timeline.wake(0)
	check(sim.drain_events().any(func(e): return e.kind == "item_activation_failed" and e.reason == "round_blocked"), "blocked cycle feedback")
	owner.paralyzed_until = 1000000
	sim.timeline.timers["test.hammer"].cd = 0.0
	sim.timeline.event({"id":"test.hammer","token":sim.timeline.timers["test.hammer"].token},0)
	check(sim.drain_events().any(func(e): return e.kind == "item_activation_failed" and e.reason == "paralyzed"), "paralysis feedback")
	owner.paralyzed_until = 0
	# Multiple packets from one physical hit play one correctly classified impact.
	var source := {"item_id":"base.map_item.hunting_bow","instance_id":"test.bow","owner_id":owner.id,"side":0}
	sim.t01.damage(owner, game.enemies[0], 3, "法术型", "base.element.none", 0, source, true, {})
	sim.t01.damage(owner, game.enemies[0], 3, "穿刺", "base.element.none", 0, source, true, {})
	heard.clear()
	game.presentation_events.emit(sim.drain_events())
	check(heard == ["pierce"], "actual damage dispatch deduplicates attached packets")
	for row in [["base.map_item.t01_0111","穿刺","throwable"],["base.map_item.short_iron_hammer","钝击","blunt"],["base.spell.metal_01","法术型","magic"]]:
		source.item_id = row[0]
		sim.t01.damage(owner,game.enemies[0],3,row[1],"base.element.none",0,source,true,{})
		heard.clear()
		game.presentation_events.emit(sim.drain_events())
		check(heard == [row[2]], "actual impact dispatch " + row[2])
	# Miss and UI reset must not produce failure/lingering effects.
	sim._definitions["test.hammer"].combat.hit_chance = -100.0
	sim.t01.activate("test.hammer",0)
	var missed := sim.drain_events()
	check(missed.any(func(e): return e.kind == "miss") and not missed.any(func(e): return e.kind == "item_activation_failed"), "miss is not failure")
	heard.clear()
	game.presentation_events.emit(missed)
	check(heard.is_empty() and not bag._weapon_feedback["test.hammer"].failed, "miss has activation ghost but no hit sound")
	bag.show_cooldown_badges = false
	check(bag._weapon_feedback.is_empty(), "review removes effect")
	bag.show_cooldown_badges = true
	game.presentation_events.emit(missed)
	game.restart()
	check(bag._weapon_feedback.is_empty(), "restart removes effect")
	scene.queue_free()
	await settle()
	print("PASS: ", checks, " weapon audio/effect checks; static renders, no mouse or saves")
	quit()
