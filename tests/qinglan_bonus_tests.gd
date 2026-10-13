extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func raw(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
func actor(registry: ContentRegistry, id: String, board_id: String, order: int = 5) -> PartyMemberState:
	return PartyMemberState.new({"id":id,"name":id,"board_layout":board_id,"max_hp":50,"max_stamina":50,"max_spirit":50,"combat_rank":order,"cultivation_rank":"base.cultivation.spirit_transformation" if order == 5 else "base.cultivation.mortal"},registry)
func run() -> void:
	var registry := ContentRegistry.new()
	var loaded := registry.load_base_content()
	print("FULL CONTENT STARTUP: ", loaded)
	if not loaded:
		print("CONTENT ERRORS: ", registry.errors)
		quit(2)
		return
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "map item/board catalog loads")
	if not created.error.is_empty():
		print(created.error)
		quit(1)
		return
	var rows := [[10,10,0,4,4,0,0],[20,15,10,8,4,2,2],[30,20,30,12,8,4,4],[40,25,40,16,8,6,6],[50,30,50,20,12,8,6],[60,40,60,24,12,10,8]]
	var statuses := ["生机","轻灵","坚韧","失衡","驱散"]
	var config := raw("res://data/maps/status_header.json")
	var map_status := MapPlayerStatus.new()
	check(map_status.configure(registry, config).is_empty(), "map status fixture loads")
	for n in 6:
		var row: Array = rows[n]
		var id := "base.board.qinglan_%d" % (n+1)
		var board := registry.get_board(id)
		check(BoardLayout.validate(raw("res://data/boards/qinglan_%d.json"%(n+1))), "valid doubled board data")
		var member := actor(registry,"test.player",id)
		var enemy := actor(registry,"test.enemy","base.board.bag",0)
		var sim := BattleSimulation.new([member],[enemy],registry)
		check(sim.t01 != null and sim.configuration_error.is_empty(), "simulation initialized")
		map_status.apply_board(board)
		for i in 3:
			var resource: String = ["hp","stamina","spirit"][i]
			check(board.resource_bonus(resource) == row[i] and member.maximum(resource) == 50+row[i], "doubled resource cap")
			check(map_status.maxima[resource] == int(map_status.character_definition["max_"+resource])+row[i], "map resource maximum agrees")
		for i in statuses.size():
			var status: String = statuses[i]
			var bonus: int = row[3+i] if i < 3 else row[6]
			check(T01CombatRules.capacity(member,status) == 50+bonus, "per-status capacity")
			var target := member if i < 3 else enemy
			check(sim.t01.apply_status(target,status,999,member,0), "status applies")
			check(T01CombatRules.layers(target,status) == 50+bonus, "actual buff self/debuff source cap")
			check(not sim.t01.apply_status(target,status,1,member,0), "over-cap new layers discarded")
		check(member.combat_statuses.size()==3, "capacity bonus itself grants no extra buffs")
		check(T01CombatRules.capacity(member,"附炎")==50 and T01CombatRules.resonance_cap(member)==30, "unlisted statuses and resonance unchanged")
		check(board.buff_bonuses.is_empty(), "capacity is not current layers")
	# Rank zero still gains board-specific capacity; it does not gain resonance.
	var mortal := actor(registry,"test.mortal","base.board.qinglan_1",0)
	check(T01CombatRules.capacity(mortal,"生机")==4 and T01CombatRules.capacity(mortal,"轻灵")==4 and T01CombatRules.capacity(mortal,"坚韧")==0 and T01CombatRules.resonance_cap(mortal)==0, "mortal actual capacities")
	var owner := actor(registry,"test.owner","base.board.qinglan_6")
	check(owner.inventory.add_item("test.weapon", "base.map_item.qingshi_short_sword", Vector2i.ZERO), "active weapon prevents empty-board instant draw")
	var target := actor(registry,"test.target","base.board.bag",0)
	var game := GameManager.new()
	game.registry = registry
	game.party = [owner]
	game.enemies = [target]
	game._durable_loadout = created.state
	game.storage = created.state.storage
	game.simulation = BattleSimulation.new([owner],[target],registry)
	game.simulation.start()
	game.simulation.clock.paused = true
	game.set_adjustment(true)
	for status: String in statuses:
		game.simulation.t01.apply_status(owner if T01Definition.is_buff(status) else target,status,999,owner,0)
	owner.hp = 40.5
	owner.stamina = 21.5
	owner.spirit = 11.5
	var stored := ""
	for entry: Dictionary in game.storage.entries():
		if entry.item_id == "base.map_item.qinglan_board_1": stored=entry.instance_id
	check(game.change_board(stored), "actual paused board command works")
	for status: String in ["生机","轻灵","坚韧"]:
		check(T01CombatRules.layers(owner,status)==T01CombatRules.capacity(owner,status), "own existing buff clamped on downgrade")
	for status: String in ["失衡","驱散"]:
		check(T01CombatRules.layers(target,status)==58, "existing enemy debuff retained")
		check(not game.simulation.t01.apply_status(target,status,1,owner,0), "new enemy layers blocked above new source cap")
		game.simulation.t01.consume(target,status,20)
		game.simulation.t01.apply_status(target,status,99,owner,0)
		check(T01CombatRules.layers(target,status)==50, "later additions stop at new cap")
	check(owner.hp==40.5 and owner.stamina==21.5 and owner.spirit==11.5, "no resource refill on swap")
	var tooltip := BattleStatusTooltip.new()
	tooltip.configure("生机",owner,game)
	check(tooltip._current.text == "54 / 54" and tooltip._capacity.text.contains("晓岚") and tooltip._capacity.text.contains("+4层上限"), "buff tooltip uses board-aware capacity/source")
	tooltip.free()
	tooltip = BattleStatusTooltip.new()
	tooltip.configure("失衡",target,game)
	check(tooltip._current.text == "50 / 50", "debuff tooltip reads source capacity")
	tooltip.free()
	var invalid := raw("res://data/boards/qinglan_1.json")
	for capacities in [{"未知":1},{"生机":-1},{"生机":1.5},[]]:
		invalid.status_capacity_bonuses = capacities
		check(not BoardLayout.validate(invalid), "invalid capacity config rejected")
	game.free()
	print("QINGLAN BONUSES: %d checks; %d failures; full content startup=%s" % [checks,failures,loaded])
	quit(1 if failures else 0)
