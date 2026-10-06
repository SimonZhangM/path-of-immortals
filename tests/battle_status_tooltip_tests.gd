extends SceneTree

var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for frame in 8: await process_frame
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	var ui = scene.get_node("MainUI")
	ui.battle_background_path = "res://assets/battle-qingshihewan-zhu.webp"
	root.add_child(scene)
	game.set_process(false)
	await settle()
	check(game.startup_error.is_empty(),"isolated scene loads")
	var owner: PartyMemberState = game.party[0]
	var enemy: PartyMemberState = game.enemies[0]
	enemy.definition = enemy.definition.duplicate(true)
	enemy.definition.status_capacity = 10 # Isolated source-capacity fixture.
	check(game.simulation.t01.apply_status(owner,"生机",5,owner,0),"apply real buff")
	check(game.simulation.t01.apply_status(owner,"灼烧",3,enemy,0),"apply real debuff")
	await settle()
	var grid := ui.ally_panel.status_icons as BattleStatusIcons
	for word: String in grid.slots:
		var slot: Control = grid.slots[word]
		var tip := slot._make_custom_tooltip(word) as BattleStatusTooltip
		check(tip.word == word and tip.member == owner,"tooltip bound to actual status: " + word)
		if word == "生机":
			check(tip._sources.text.contains(owner.definition.name) and tip._sources.text.contains("5层"),"buff actual source and layers")
			check(tip._capacity.text.contains(owner.cultivation.name),"buff capacity realm source")
			game.simulation.t01.consume(owner,"生机",2)
			tip._refresh()
			check(tip._sources.text.contains("3层"),"tooltip live layer consumption")
		elif word == "灼烧":
			check(tip._sources.text.contains(enemy.definition.name),"debuff actual enemy source")
			check(tip._current.text.ends_with(str(T01CombatRules.capacity(enemy))),"debuff uses source capacity")
		elif word == "流血":
			check(tip._sources.text == "当前未生效","preview status has no invented source")
		tip.free()
		if DisplayServer.get_name() == "headless":
			var motion := InputEventMouseMotion.new()
			motion.position = slot.get_global_rect().get_center()
			root.push_input(motion,true)
			await process_frame
			check(root.gui_get_hovered_control() == slot,"hover routes to icon including right overflow: " + word)
	for panel: TeamPanel in [ui.ally_panel,ui.enemy_panel]:
		for row: DefenseResourceRow in [panel.cards[0].armor_status,panel.cards[0].barrier_status]:
			check(is_equal_approx(row.icon.get_child(0).position.length()*4.0/3.0,0.25),"defense outline0.25 native px")
		var number: Label = panel.status_icons.counts["生机"]
		check(number.get_theme_color("font_shadow_color").a == 0,"no numeric shadow")
		check(is_equal_approx(number.get_child(0).position.length()*4.0/3.0,0.5),"numeric outline0.5 native px")
	await settle()
	if DisplayServer.get_name() != "headless":
		var a := grid.slots["生机"]._make_custom_tooltip("") as BattleStatusTooltip
		var b := grid.slots["灼烧"]._make_custom_tooltip("") as BattleStatusTooltip
		root.add_child(a)
		root.add_child(b)
		a.position = Vector2(920,350)
		b.position = Vector2(1390,540)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-status-tooltips-2k.png")
		a.queue_free()
		b.queue_free()
	scene.queue_free()
	await settle()
	print("BATTLE STATUS TOOLTIPS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
