extends SceneTree

var checks := 0
var failures := 0
var heard: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 5: await process_frame

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1920, 1080)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = false
	game.loadout_save_path = ""
	root.add_child(scene)
	game.set_process(false)
	check(game.startup_error.is_empty(), "real scene starts")
	var created := MapLoadoutStore.create_state(game.registry, game.registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "map catalog registered")
	game.companions.clear()
	game.enemy_companions.clear()
	var owner: PartyMemberState = game.party[0]
	owner.inventory = InventoryState.new(game.registry, Vector2i(3, 3))
	check(owner.inventory.add_item("restore.heart", "base.organ.cslz_heart", Vector2i(2, 0)), "heart source")
	check(owner.inventory.add_item("restore.pill", "base.map_item.hemostatic_pill", Vector2i.ZERO), "pill source")
	check(owner.inventory.add_item("restore.shell", "base.organ.heyuan_shell", Vector2i(1, 1)), "armor source")
	owner.definition.max_hp = 10000
	game.enemies[0].definition.max_hp = 10000
	game.restart()
	game.start_battle()
	var ui = scene.get_node("MainUI")
	ui.set_process(false)
	await settle()
	var sim: BattleSimulation = game.simulation
	var bag: InventoryView = ui.ally_panel.bags[0]
	var card: PartyMemberCard = ui.ally_panel.cards[0]
	ui.game_audio.sound_played.connect(func(kind: String): heard.append(kind))
	check(ui.game_audio.players.restore.stream.get_length() > 0, "new sound imported and decodable")
	sim.drain_events()
	owner.stamina = owner.maximum("stamina")
	sim.t01.activate("restore.heart", 0)
	game.presentation_events.emit(sim.drain_events())
	check(heard.is_empty() and ui._restore_flights.is_empty(), "capped recovery silent with no flight")
	owner.stamina -= 1
	sim.t01.activate("restore.heart", 1)
	var events := sim.drain_events()
	var recovery: Dictionary = events.filter(func(e): return e.kind == "restore")[0]
	check(recovery.value == 1 and recovery.target_id == owner.id and recovery.instance_id == "restore.heart", "actual partial recovery and exact attribution")
	game.presentation_events.emit(events)
	check(heard == ["restore"] and ui._restore_flights.size() == 1, "one sound and stamina icon")
	var flight = ui._restore_flights[0]
	var origin: Vector2 = ui.get_global_transform_with_canvas().affine_inverse() * bag.recovery_origin(recovery)
	check(flight.origin.is_equal_approx(origin), "origin is source board footprint center")
	check(flight.texture == card.stat_icons.stamina.texture and flight.destination == card.stat_bars.stamina, "matching icon and resource bar")
	sim.clock.speed_multiplier = 5
	sim.clock.paused = true
	ui._advance_restore_flights(0.75)
	check(is_equal_approx(flight.elapsed, 0.75) and sim.state.time_usec == 0, "presentation timing ignores pause and speed")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/restore-feedback-flight.png")
	flight.advance(0.75)
	var destination: Vector2 = ui.get_global_transform_with_canvas().affine_inverse() * (card.stat_bars.stamina.get_global_transform_with_canvas() * (card.stat_bars.stamina.size * 0.5))
	check((flight.position + flight.size * 0.5).is_equal_approx(destination) and flight.modulate.a == 0, "lands exactly at bar center at 1.5s")
	ui._advance_restore_flights(0)
	check(ui._restore_flights.is_empty(), "finished flight removed")
	# Resize while in flight: global canvas transforms still land at the bar center.
	ui._show_restore(recovery)
	root.size = Vector2i(2560, 1440)
	await settle()
	flight = ui._restore_flights[0]
	flight.advance(1.5)
	destination = ui.get_global_transform_with_canvas().affine_inverse() * (card.stat_bars.stamina.get_global_transform_with_canvas() * (card.stat_bars.stamina.size * 0.5))
	check((flight.position + flight.size * 0.5).is_equal_approx(destination), "2K transform and live destination")
	ui._clear_restore_flights()
	# All restorative resources and a single dual-resource action.
	heard.clear()
	var source := sim.t01.item_source("restore.heart")
	owner.hp -= 20
	owner.spirit -= 10
	owner.stamina -= 10
	owner.armor = 0
	card.refresh(owner)
	for resource in ["hp", "spirit", "stamina", "armor"]:
		check(sim.t01.restore(owner, resource, 1, 2, -1, source) > 0, "actual " + resource + " recovery")
	game.presentation_events.emit(sim.drain_events())
	check(heard == ["restore"] and ui._restore_flights.size() == 4, "one sound per action, one icon per recovered resource")
	for fx in ui._restore_flights:
		check(fx.destination != null, "valid resource destination")
	game.adjustment_changed.emit()
	check(ui._restore_flights.is_empty(), "adjustment clears flights")
	# Consumed pills retain their original source cell through queued ticks.
	sim.t01.activate("restore.pill", 10)
	sim.drain_events()
	check(owner.inventory.get_instance("restore.pill").is_empty(), "pill consumed")
	sim.clock.paused = false
	sim.clock.speed_multiplier = 1
	sim.advance(2.01)
	events = sim.drain_events()
	var ticks := events.filter(func(e): return e.kind == "restore" and e.get("instance_id") == "restore.pill")
	check(ticks.size() == 1 and ticks[0].value > 0 and ticks[0].entry.cell == Vector2i.ZERO, "scheduled tick preserves consumed source")
	game.presentation_events.emit(ticks)
	check(ui._restore_flights.size() == 1, "consumed item still emits flight")
	check(ui._restore_flights[0].origin.is_equal_approx(ui.get_global_transform_with_canvas().affine_inverse() * bag.recovery_origin(ticks[0])), "tick origin uses saved cell")
	ui._clear_restore_flights()
	# Enemy resource recovery routes to the enemy bar, never the ally.
	var enemy: PartyMemberState = game.enemies[0]
	var enemy_entry: Dictionary = enemy.inventory.get_instances()[0]
	source = sim.t01.item_source(enemy_entry.instance_id)
	enemy.hp -= 10
	sim.t01.restore(enemy, "hp", 1, 3, -1, source)
	game.presentation_events.emit(sim.drain_events())
	check(ui._restore_flights[0].destination == ui.enemy_panel.cards[0].stat_bars.hp, "enemy target routing")
	ui._clear_restore_flights()
	# Periodic status recovery retains source attribution and reports actual deltas.
	source = sim.t01.item_source("restore.heart")
	owner.combat_statuses.clear()
	owner.spirit -= 5
	owner.stamina -= 5
	sim.t01.apply_status(owner, "润脉", 2, owner, 3, false, -1, source)
	var pool: Dictionary = owner.combat_statuses["润脉"]
	sim.cultivation.resource_tick(owner, "润脉", pool, 2, owner, 1000003)
	var status_events := sim.drain_events().filter(func(e): return e.kind == "restore")
	check(status_events.size() == 2 and status_events.all(func(e): return e.value > 0 and e.instance_id == "restore.heart"), "status resource ticks publish exact source and gains")
	game.presentation_events.emit(status_events)
	ui.victory_view = ui.VictoryView.REVIEW
	ui._advance_restore_flights(0)
	check(ui._restore_flights.is_empty(), "review clears flights")
	ui.victory_view = ui.VictoryView.NONE
	game.presentation_events.emit(status_events)
	game.restart()
	check(ui._restore_flights.is_empty(), "restart clears flights")
	# Real healing spell, including its subsequent life status, uses the caster instance.
	owner.test_spell_access = true
	owner.inventory = InventoryState.new(game.registry, Vector2i(3, 3))
	check(owner.inventory.add_item("restore.heal", "base.spell.wood_07", Vector2i.ZERO), "healing spell fixture")
	game.restart()
	game.start_battle()
	sim = game.simulation
	owner.hp -= 100
	sim.drain_events()
	sim.cultivation.cast("restore.heal", 0)
	var heals := sim.drain_events().filter(func(e): return e.kind == "restore")
	check(heals.size() == 1 and heals[0].value > 0 and heals[0].instance_id == "restore.heal", "healing spell publishes caster")
	check(owner.combat_statuses["生机"].feedback_source.instance_id == "restore.heal", "spell status carries same source")
	# Complete prevention is not an actual recovery.
	owner.combat_statuses.clear()
	sim.t01.apply_status(owner, "重伤", 10, owner, 0)
	heard.clear()
	sim.drain_events()
	check(sim.t01.restore(owner, "hp", 1, 1000000, -1, sim.t01.item_source("restore.heal")) == 0, "injury prevents all healing")
	game.presentation_events.emit(sim.drain_events())
	check(heard.is_empty() and ui._restore_flights.is_empty(), "prevented healing silent")
	# Legacy settlement supplies the same stable target ID.
	owner.hp -= 10
	var legacy := EffectSystem.new().restore(owner, "hp", 2, 0, {})
	check(legacy.target_id == owner.id and legacy.value == 2, "legacy recovery compatible")
	scene.queue_free()
	await settle()
	print("Restore feedback: ", checks, " checks, ", failures, " failures; no mouse or real save")
	quit(1 if failures > 0 else 0)
