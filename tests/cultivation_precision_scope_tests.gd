extends "res://tests/map_shop_tests.gd"

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"isolated map startup")
	var status: MapPlayerStatus=map.player_status
	for key: String in ["hp","stamina","spirit"]:
		var limit: int=status.maxima[key]
		status.set_resource(key,limit)
		check(map.status_header.values[key].text=="%d/%d" % [limit,limit],"whole resources omit .0: "+key)
	check(map.status_header.values.cultivation.text=="0/1000000","whole cultivation omits .0")
	status.set_resource("stamina",18.25)
	check(map.status_header.values.stamina.text=="18.25/%d" % status.maxima.stamina,"map retains original fractional format")
	check(CultivationGrowth.display(18.25)=="18.3","training display still rounds half up")
	check(is_equal_approx(status.cultivation_gain(1.24),1.2),"battle reward retains original precision with growth")
	var member:=PartyMemberState.new(status.character_definition,map.loadout.registry)
	check(is_equal_approx(T01CombatRules.resource_q(member,1.24),1.2),"combat resource precision remains tenths")
	var training:=CultivationTraining.new(member,map.loadout.registry)
	check(is_equal_approx(T01CombatRules.resource_q(member,1.24),1.24),"training resource precision remains hundredths")
	var fresh:=PartyMemberState.new(status.character_definition,map.loadout.registry)
	check(is_equal_approx(T01CombatRules.resource_q(fresh,1.24),1.2),"training flag does not leak into next battle")
	training=null
	status.set_resource("stamina",status.maxima.stamina)
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/cultivation-precision-scope.png")
	print("Precision scope checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
