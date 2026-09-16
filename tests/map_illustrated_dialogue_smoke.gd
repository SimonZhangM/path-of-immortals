extends SceneTree

var checks := 0
var failures := 0
var screen: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920,1080)
	MapEventState.session_completed.clear()
	await _load_map()
	_check(screen.startup_error.is_empty(), "illustrated event loads with map")
	_walk_to("N20")
	_click(_point("N20"))
	_check(not screen.dialogue.visible and screen.content.get_node("Points/N20/Sign").visible, "N20 remains locked before N37")
	_walk_to("N37")
	_click(_point("N37"))
	_check(screen.event_state.is_active() and not screen.dialogue.picture.visible, "N37 still has no illustration")
	for i in 5:
		_click(Vector2(80,80))
	_check(not screen.dialogue.visible, "N37 completes normally")
	_walk_to("N20")
	_check(not screen.dialogue.visible, "arrival at unlocked N20 still does not auto trigger")
	_click(_point("N20"))
	var dialogue: MapDialogue = screen.dialogue
	var picture: MapEventPicture = dialogue.picture
	_check(screen.event_state.phase == "illustration" and picture.is_visible_in_tree(), "second N20 click opens illustration stage")
	_check(not dialogue.background.visible and not dialogue.portrait.visible and not dialogue.text_label.visible, "opening click does not open text prematurely")
	_check(picture.frame.texture.resource_path == "res://assets/map-event-frame.webp" and picture.illustration.texture.resource_path == "res://assets/map-event-1-1.webp", "correct frame and illustration appear together")
	await _settle()
	await _capture("illustration_intro")
	var map_position: Vector2 = screen.travel.map_position
	var camera: Vector2 = screen.content.position
	var zoom: float = screen.zoom_factor
	_button(MOUSE_BUTTON_WHEEL_UP,true,Vector2(80,80))
	_button(MOUSE_BUTTON_RIGHT,true,Vector2(80,80))
	_button(MOUSE_BUTTON_RIGHT,false,Vector2(80,80))
	_check(screen.event_state.phase == "illustration" and screen.zoom_factor == zoom, "non-left input cannot advance illustration or zoom")
	_button(MOUSE_BUTTON_LEFT,true,Vector2(80,80))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(160,110)
	motion.relative = Vector2(80,30)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true)
	_button(MOUSE_BUTTON_LEFT,false,motion.position)
	_check(screen.event_state.phase == "illustration" and screen.content.position == camera, "illustration blocks map drag without advancing")
	_click(picture.get_rect().get_center())
	_check(screen.event_state.phase == "dialogue" and screen.event_state.line_index == 0 and dialogue.background.visible and picture.visible, "next click opens first line and retains illustration")
	var event: Dictionary = screen.event_state.active_event()
	for dimensions in [Vector2i(1920,1080),Vector2i(1280,800)]:
		root.size = dimensions
		await _settle()
		var panel := dialogue.background.get_rect()
		_check(panel.get_center().is_equal_approx(Vector2(screen.size.x*0.5,screen.size.y*0.75)), "dialogue centered at 75 percent")
		var old_height: float = minf(panel.size.x * 900.0 / 1448.0, panel.position.y - 16.0 * screen.size.x / 1920.0 - screen.size.y * 0.3)
		_check(is_equal_approx(picture.get_rect().end.y, screen.size.y * 0.3 + old_height) and is_equal_approx(picture.size.y, old_height * 5.0 / 3.0) and is_equal_approx(picture.get_rect().get_center().x,screen.size.x*0.5), "illustration grows another quarter upward with bottom center fixed")
		_check(not picture.get_rect().intersects(panel) and picture.get_rect().end.y <= panel.position.y - 15.9 * screen.size.x/1920.0, "illustration leaves gap above dialogue")
		_check(picture.size.x <= panel.size.x and Rect2(Vector2.ZERO,screen.size).encloses(picture.get_rect()), "smaller illustration fits screen")
		_check(is_equal_approx(picture.size.x/picture.size.y,1448.0/900.0), "event frame keeps source aspect")
		_check(picture.window.clip_contents and picture.illustration.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "artwork fills clipped window without stretching")
		await _capture("illustration_dialogue_%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1920,1080)
	await _settle()
	for i in 20:
		await _settle()
		_check(dialogue.text_label.text == event.lines[i] and screen.event_state.line_index == i, "paragraph text %d" % (i+1))
		var portrait_texture := dialogue.portrait.texture as AtlasTexture
		var expected_path := "res://assets/npc-qlzdz-1.webp" if i % 2 == 0 else "res://assets/player-1-1.webp"
		_check(portrait_texture.atlas.resource_path == expected_path, "matching speaker portrait %d" % (i+1))
		if i < 2:
			_check(_portrait_covers_aperture(portrait_texture), "speaker has opaque coverage to the circular rim")
			_check(dialogue.portrait.get_index() < dialogue.background.get_index() and dialogue.portrait.material is ShaderMaterial, "portrait is circle masked beneath the decorative rim")
		var panel := dialogue.background.get_rect()
		_check(panel.encloses(dialogue.text_label.get_rect()) and dialogue.text_label.size.y >= dialogue.text_label.get_minimum_size().y, "whole paragraph fits at preserved font size %d" % (i+1))
		_check(dialogue.text_label.get_theme_font_size("font_size") == 31, "1080p text reduced by one to 31")
		var factor := panel.size.x/1807.0
		var slot := Rect2(panel.position+Vector2(62,20.5)*factor,Vector2(368,368)*factor)
		_check(slot.grow(0.01).encloses(dialogue.portrait.get_rect()) and dialogue.portrait.get_rect().get_center().is_equal_approx(slot.get_center()), "changing portraits remain centered inside circular aperture")
		if i in [1,8,16,19]:
			await _capture("illustration_paragraph_%02d" % (i+1))
		_click(Vector2(80,80))
	_check(not dialogue.visible and not screen.event_state.is_active(), "last click closes both panels")
	_check(not screen.content.get_node("Points/N20/Sign").is_visible_in_tree() and not screen.content.get_node("Points/N20/Sign/StoryIcon").is_visible_in_tree(), "N20 sign and icon removed")
	_check(screen.content.get_node("Points/N20").visible and screen.content.get_node("Points/N03/Sign").visible and screen.content.get_node("Points").get_child_count()==38 and screen.content.get_node("Routes").get_child_count()==41, "node graph and unrelated signs unchanged")
	_check(screen.travel.map_position == map_position and screen.travel.mode == "idle", "dialogue never moves player")
	_click(_point("N20"))
	_check(not dialogue.visible, "completed event cannot replay")
	screen.queue_free()
	await process_frame
	await _load_map()
	_check(not screen.content.get_node("Points/N20/Sign").visible and not screen.content.get_node("Points/N37/Sign").visible, "both completions survive scene reload")
	screen.queue_free()
	await process_frame
	MapEventState.session_completed.clear()
	await _load_map()
	_check(screen.content.get_node("Points/N20/Sign").visible and screen.content.get_node("Points/N37/Sign").visible, "new run restores both signs")
	_walk_to("N20")
	_click(_point("N20"))
	_check(not screen.dialogue.visible, "new run also restores prerequisite lock")
	screen.queue_free()
	await process_frame
	print("MAP ILLUSTRATED DIALOGUE RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _walk_to(node_name: String) -> void:
	_click(_point(node_name))
	screen.travel.advance(1000)
	screen.player.present(screen.travel)

func _capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://artifacts/"+label+".png")==OK,"render "+label)

func _load_map() -> void:
	screen = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	root.add_child(screen)
	await _settle()
	screen.set_process(false)

func _settle() -> void:
	for i in 4:
		await process_frame

func _point(node_name: String) -> Vector2:
	return screen.content.position + screen.content.get_node("Points/"+node_name).position * screen.content.scale

func _click(position: Vector2) -> void:
	_button(MOUSE_BUTTON_LEFT,true,position)
	_button(MOUSE_BUTTON_LEFT,false,position)

func _button(index: MouseButton,pressed: bool,position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if index==MOUSE_BUTTON_LEFT and pressed else 0
	root.push_input(event,true)

func _check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)

func _portrait_covers_aperture(texture: AtlasTexture) -> bool:
	var pixels := texture.atlas.get_image()
	var center := texture.region.get_center()
	# Aperture radius is at most181 source px; portrait radius184 overlaps its rim.
	var radius := texture.region.size.x * 0.5 * 181.0 / 184.0
	for degrees in 360:
		var sample := center + Vector2.from_angle(deg_to_rad(degrees)) * radius
		if pixels.get_pixel(roundi(sample.x), roundi(sample.y)).a < 0.95:
			return false
	return true
