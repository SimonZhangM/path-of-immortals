extends SceneTree
var registry := ContentRegistry.new()
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func fixture(item_id: String, initial: float = -1) -> BattleSimulation:
	var raw := registry.get_character("base.character.chen_yu").duplicate(true)
	if initial >= 0: raw.initial_armor = initial
	var player := PartyMemberState.new(raw,registry)
	player.inventory = InventoryState.new(registry,Vector2i(4,4))
	check(player.inventory.add_item("armor",item_id,Vector2i.ZERO),"equip " + item_id)
	check(player.inventory.add_item("sword","base.map_item.qingshi_short_sword",Vector2i(3,0)),"weapon keeps battle active")
	var enemy_raw := registry.get_enemy("base.enemy.wild_dog").duplicate(true)
	enemy_raw.max_hp = 100000
	var enemy := PartyMemberState.new(enemy_raw,registry)
	return BattleSimulation.new([player],[enemy],registry)
func run() -> void:
	check(registry.load_base_content(),"base content")
	var loaded := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(loaded.error.is_empty(),"catalog loaded without save")
	var armor_count := 0
	for item: ItemData in registry._items.values():
		if not item.id.begins_with("base.map_item.") or item.category != "armor": continue
		var sim := fixture(item.id)
		var owner: PartyMemberState = sim.state.teams[0][0]
		var capacity := owner.maximum("armor")
		check(sim.start(),"starts: " + item.display_name)
		check(owner.armor == 0 and owner.maximum("armor") == capacity,"capacity never grants starting armor: " + item.display_name)
		armor_count += 1
	var sim := fixture("base.map_item.t01_0011")
	var owner: PartyMemberState = sim.state.teams[0][0]
	check(owner.maximum("armor") == 10 and sim.start() and owner.armor == 0,"iron starts 0/10")
	sim.advance(8.999999)
	check(owner.armor == 0,"iron before9seconds has0")
	sim.advance(0.000001)
	check(owner.armor == 5,"iron exact9seconds restores5")
	sim.advance(9)
	check(owner.armor == 10,"iron secondCD reaches10")
	sim.advance(9)
	check(owner.armor == 10,"restoration capped at10")
	var restarted := BattleSimulation.new([owner],sim.state.teams[1],registry)
	check(restarted.start() and owner.armor == 0 and owner.maximum("armor") == 10,"next battle discards prior current armor but keeps capacity")
	var granted := fixture("base.map_item.t01_0011",3.5)
	check(granted.start() and granted.state.teams[0][0].armor == 3.5,"explicit initial grant preserved exactly, not full")
	var capped := fixture("base.map_item.t01_0011",50)
	check(capped.start() and capped.state.teams[0][0].armor == 10,"explicit grant capped at capacity")
	var linked := fixture("base.map_item.t01_0011")
	var linked_owner: PartyMemberState = linked.state.teams[0][0]
	check(linked_owner.inventory.add_item("arm","base.map_item.t01_0016",Vector2i(1,0)) and linked_owner.inventory.add_item("leg","base.map_item.t01_0017",Vector2i(1,1)),"iron set fits")
	linked.attach(linked_owner,0,"arm",false)
	linked.attach(linked_owner,0,"leg",false)
	check(linked.start() and linked_owner.armor == 0 and linked_owner.maximum("armor") == 18,"full iron set starts0/18")
	# Real entry smoke: no formal save, actual equip and start commands.
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	root.add_child(scene)
	game.set_process(false)
	for frame in 8: await process_frame
	check(game.startup_error.is_empty(),"actual scene loads")
	var entries := game.storage.entries().filter(func(e): return e.item_id == "base.map_item.t01_0011")
	check(not entries.is_empty() and game.equip(entries[0].instance_id,0,Vector2i.ZERO),"actual iron equip")
	game.start_battle()
	game.pause_battle()
	for frame in 8: await process_frame
	var card: PartyMemberCard = scene.get_node("MainUI").ally_panel.cards[0]
	check(game.simulation.state.phase == GameState.Phase.BATTLE and game.party[0].armor == 0,"actual start zero armor")
	check(card.armor_status.visible and card.armor_status.current_label.text == "0" and card.armor_status.maximum_label.text == "10","UI shows0/10 after actual start")
	scene.queue_free()
	for frame in 4: await process_frame
	print("ARMOR START: %d checks, %d failures; %d catalog armors" % [checks,failures,armor_count])
	quit(1 if failures else 0)
