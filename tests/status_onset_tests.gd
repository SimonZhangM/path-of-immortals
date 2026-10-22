extends SceneTree

var checks := 0
var failures: Array[String] = []
var registry := ContentRegistry.new()
const EARLY := {
	"生机": ["wood", "早春"], "毒蚀": ["wood", "潜毒"],
	"润脉": ["water", "活泉"], "枯脉": ["water", "潜枯"],
	"重伤": ["earth", "催伤"], "驱散": ["wind", "疾散"],
}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func _init() -> void: call_deferred("run")

func actor(id: String) -> PartyMemberState:
	var raw := registry.get_character("base.character.chen_yu")
	raw.id = id
	raw.max_hp = 1000; raw.max_spirit = 1000; raw.max_stamina = 1000
	raw.cultivation_rank = "base.cultivation.huashen"
	# Neutral SPELL matrix coefficient, so burn assertions isolate its clock.
	raw.innate_armor_type = "轻甲"
	var member := PartyMemberState.new(raw, registry)
	if member.cultivation.is_empty(): member.cultivation_rank_id = ""; member.definition.combat_rank = 5
	member.inventory = InventoryState.new(registry, Vector2i(10,10))
	member.inventory.add_item(id + ".weapon", "base.map_item.qingshi_short_sword", Vector2i.ZERO)
	return member

func fixture(status := "", early := false) -> BattleSimulation:
	var p := actor("test.onset.source")
	var e := actor("test.onset.target")
	if early:
		var branch: Array = EARLY[status]
		var book := "base.cultivation_book.%s_03" % branch[0]
		check(p.knowledge.record_achievement(registry.library, book, 1, 5), "learn " + str(branch[1]))
		check(p.knowledge.choose(registry.library, book, 1, branch[1]), "choose " + str(branch[1]))
	var sim := BattleSimulation.new([p], [e], registry)
	check(sim.start(), "start isolated battle")
	sim.timeline.set_all(p, false); sim.timeline.set_all(e, false)
	e.hp = 100; e.spirit = 100; e.stamina = 100
	return sim

func value(member: PartyMemberState, status: String) -> float:
	return member.spirit if status in ["润脉", "枯脉"] else member.hp

func test_periodic(status: String, early: bool) -> void:
	var sim := fixture(status, early)
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	var sign_value := 1 if status in ["生机", "润脉"] else -1
	var decays := status in ["生机", "毒蚀", "润脉", "枯脉"]
	sim.t01.apply_status(e, status, 5, p, 0)
	if not early:
		sim.advance(0.5)
		sim.t01.apply_status(e, status, 2, p, sim.state.time_usec)
		sim.advance(0.499999)
		check(value(e,status) == 100, status + " no early tick; addition preserves initial wait")
		sim.advance(0.000001)
	else:
		sim.advance(0)
	var initial := 5 if early else 7
	check(value(e,status) == 100 + initial * sign_value, status + " first effect at exact onset " + str(early))
	check(sim.t01.layers(e,status) == initial - (1 if decays else 0), status + " initial decay policy")
	sim.advance(0.25)
	sim.t01.apply_status(e,status,2,p,sim.state.time_usec)
	sim.advance(0)
	check(value(e,status) == 100 + initial * sign_value, status + " active-pool addition never repeats immediate tick")
	sim.advance(0.749999)
	check(value(e,status) == 100 + initial * sign_value, status + " no extra tick before next second")
	sim.advance(0.000001)
	check(value(e,status) == 100 + (initial * 2 + 2 - (1 if decays else 0)) * sign_value, status + " unchanged one-second cadence")
	# Remove and reapply before a pending old-generation event.
	sim.advance(0.25)
	sim.t01.consume(e,status,sim.t01.layers(e,status))
	var before := value(e,status)
	sim.t01.apply_status(e,status,3,p,sim.state.time_usec)
	if early:
		sim.advance(0)
		check(value(e,status) == before + 3 * sign_value, status + " rebuilt pool settles immediately")
	else:
		sim.advance(0.75)
		check(value(e,status) == before, status + " stale generation cannot settle new pool")
		sim.advance(0.25)
		check(value(e,status) == before + 3 * sign_value, status + " rebuilt pool waits full one second")
	if status in ["润脉", "枯脉"]:
		check(e.spirit == e.stamina, status + " both resources settle together")

func test_injury(early: bool) -> void:
	var sim := fixture("重伤", early)
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	sim.t01.apply_status(e,"重伤",5,p,0)
	if not early:
		sim.advance(0.999999)
		check(sim.t01.active_injury(e,sim.state.time_usec) == 0,"injury inactive before1s")
		sim.advance(0.000001)
	else: sim.advance(0)
	check(sim.t01.active_injury(e,sim.state.time_usec)==5,"injury activates without decay " + str(early))
	check(sim.t01.restore(e,"hp",8,sim.state.time_usec)==3,"injury healing reduction at activation")
	check(sim.t01.costs(e,registry.get_item("base.map_item.qingshi_short_sword"),sim.state.time_usec).x==8,"injury cost surcharge at activation")
	sim.advance(0.999999)
	check(sim.t01.layers(e,"重伤")==5,"injury retains full layers during first effective second")
	sim.advance(0.000001)
	check(sim.t01.layers(e,"重伤")==4,"injury decays exactly one second after activation")
	sim.advance(0.25)
	sim.t01.apply_status(e,"重伤",2,p,sim.state.time_usec)
	sim.advance(0.75)
	check(sim.t01.layers(e,"重伤")==5,"injury addition preserves decay cadence")

func test_dispel(early: bool) -> void:
	var sim := fixture("驱散", early)
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	sim.t01.apply_status(e,"反锋",3,e,0)
	sim.t01.apply_status(e,"驱散",5,p,0)
	if not early:
		sim.advance(0.999999)
		check(sim.t01.layers(e,"反锋")==3,"dispel waits full1s")
		sim.advance(0.000001)
	else: sim.advance(0)
	check(sim.t01.layers(e,"反锋")==0 and sim.t01.layers(e,"驱散")==2,"dispel first resolution " + str(early))
	sim.advance(0.25)
	sim.t01.apply_status(e,"反锋",3,e,sim.state.time_usec)
	sim.advance(0.999999)
	check(sim.t01.layers(e,"反锋")==3,"stored dispel always waits1s even with 疾散")
	sim.advance(0.000001)
	check(sim.t01.layers(e,"反锋")==1 and sim.t01.layers(e,"驱散")==0,"stored dispel consumes remaining units")
	var empty := fixture("驱散", early)
	p = empty.state.teams[0][0]; e = empty.state.teams[1][0]
	empty.t01.apply_status(e,"驱散",2,p,0)
	empty.advance(0 if early else 1)
	empty.advance(4.999999)
	check(empty.t01.layers(e,"驱散")==2,"untargeted dispel stays5s")
	empty.advance(0.000001)
	check(empty.t01.layers(e,"驱散")==0,"untargeted dispel expires")

func test_decay_and_expiry() -> void:
	for status in ["流血","灼烧"]:
		var sim := fixture()
		var p: PartyMemberState = sim.state.teams[0][0]
		var e: PartyMemberState = sim.state.teams[1][0]
		var duration := 5 if status=="流血" else 10
		sim.t01.apply_status(e,status,2,p,0)
		sim.advance(duration)
		check(e.hp==100-duration*2 and sim.t01.layers(e,status)==2,status+" correct total ticks, no per-tick decay")
		sim.advance(1)
		check(e.hp==100-duration*2 and sim.t01.layers(e,status)==0,status+" expires before endpoint tick")
	var sim := fixture()
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	sim.t01.apply_status(e,"破甲",5,p,0)
	sim.advance(9.999999)
	check(sim.t01.layers(e,"破甲")==5,"armor break keeps10s wait")
	sim.advance(0.000001)
	check(sim.t01.layers(e,"破甲")==4,"armor break decays at10s")
	sim.advance(0.5)
	sim.t01.apply_status(e,"破甲",1,p,sim.state.time_usec)
	sim.advance(9.999999)
	check(sim.t01.layers(e,"破甲")==5,"armor break refresh resets10s wait")
	sim.advance(0.000001)
	check(sim.t01.layers(e,"破甲")==4,"armor break refreshed decay")

func test_immediate_cancellation_and_pause() -> void:
	var sim := fixture("生机",true)
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	sim.t01.apply_status(e,"毒蚀",3,p,0)
	sim.t01.apply_status(e,"生机",3,p,0)
	sim.advance(0)
	check(e.hp==100 and sim.t01.layers(e,"生机")==0,"canceled new pool does not heal immediately")
	sim.advance(1)
	check(e.hp==100,"canceled poison has no stale tick")
	sim.t01.apply_status(e,"生机",5,p,sim.state.time_usec)
	sim.advance(0)
	check(e.hp==105,"fresh early state heals at current timestamp")
	sim.clock.paused=true
	sim.advance(10)
	check(e.hp==105,"pause halts later ticks")
	sim.clock.paused=false
	sim.clock.set_speed(2)
	sim.advance(0.5)
	check(e.hp==109,"later ticks use simulation time at2x")

func run() -> void:
	check(registry.load_base_content(), "load registry " + str(registry.errors))
	if not registry.errors.is_empty(): quit(1); return
	MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	for status in ["生机","毒蚀","润脉","枯脉","流血","灼烧"]:
		test_periodic(status,false)
		if EARLY.has(status): test_periodic(status,true)
	for early in [false,true]:
		test_injury(early)
		test_dispel(early)
	test_decay_and_expiry()
	test_immediate_cancellation_and_pause()
	print("STATUS ONSET: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
