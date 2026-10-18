extends "res://tests/map_shop_tests.gd"

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	var map=load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path=""
	map.defer_map_music=true
	root.add_child(map)
	map.set_process(false)
	await settle()
	if not map.startup_error.is_empty(): push_error(map.startup_error); quit(1); return
	var header: MapStatusHeader=map.status_header
	var centers: Array[float]=[]
	for number: Label in [header.spirit_stones_value,header.experience_value]:
		number.text="0"
		await settle()
		centers.append(number.get_global_rect().get_center().x)
	check(is_equal_approx(centers[0],centers[1]),"both counters share zero axis")
	for value in [100,999999999,0,10,100]:
		for index in 2:
			var number: Label=header.spirit_stones_value if index==0 else header.experience_value
			number.text=str(value)
			await settle()
			check(is_equal_approx(number.get_global_rect().get_center().x,centers[index]),"fixed center after text growth/shrink: "+str(value))
			check(number.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,"centered text")
	header.spirit_stones.text="灵石"
	header.experience.text="历练"
	header.experience_value.text="0"
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/header-counter-alignment.png")
	print("HEADER COUNTERS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
