extends SceneTree
## Static rendering + native registration smoke check; never moves the OS mouse.
var checks := 0
var failures := 0
const DIRECTORY := "res://artifacts/cursors-20261113/"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CURSOR VISUAL: " + note)

func settle() -> void:
	for i in 5: await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(DIRECTORY+name+".png")==OK,"capture "+name)

func label(parent: Control, text: String, rect: Rect2) -> void:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size",20)
	parent.add_child(node)

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	if DisplayServer.get_name()=="headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1080,680)
	AudioServer.set_bus_mute(0,true)
	var cursors: GameCursorManager = root.get_node("CursorManager")
	cursors.set_process(false)
	# Exercise the real Windows native API for all ten texture/hotspot pairs.
	for size_key: String in ["normal","large"]:
		cursors.set_cursor_size(size_key)
		for state in 5:
			cursors.current_state = state as GameCursorManager.State
			cursors._apply_state()
			check(cursors._registered_state == state,"native state %s/%d" % [size_key,state])
	cursors.set_custom_cursor_enabled(false)
	check(cursors._registered_state==-1,"native system reset")
	cursors.set_custom_cursor_enabled(true)
	check(cursors._registered_state>=0,"native custom restore")
	var sheet := Control.new()
	sheet.size = Vector2(root.size)
	root.add_child(sheet)
	label(sheet,"Five states / actual 40px + 56px / no extra effects",Rect2(30,15,1000,40))
	var names := ["NORMAL","INTERACT","DRAG_READY","DRAGGING","FORBIDDEN"]
	var colors := [Color("a7ba70"),Color("182a20"),Color("1c3c59")]
	for row in 3:
		var background := ColorRect.new()
		background.color = colors[row]
		background.position = Vector2(20,70+row*195)
		background.size = Vector2(1040,185)
		sheet.add_child(background)
		for column in 5:
			label(background,names[column],Rect2(25+column*205,10,200,30))
			for index in 2:
				var image := TextureRect.new()
				image.texture = cursors.texture_for(column,"normal" if index==0 else "large")
				image.position = Vector2(50+column*205+index*65,60)
				image.size = image.texture.get_size()
				background.add_child(image)
	await capture("five-states-contact-sheet")
	sheet.queue_free()
	await settle()
	var panel = load("res://scripts/settings/settings_panel.gd").new()
	root.add_child(panel)
	panel.select_page("other")
	for dimensions: Vector2i in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = dimensions
		await settle()
		check(panel.canvas.get_global_rect().get_center().is_equal_approx(Vector2(dimensions)*0.5),"centered settings")
		check(panel.widgets.custom_cursor.get_global_rect().end.y < panel.widgets.cursor_size.get_global_rect().position.y,"cursor controls do not overlap")
		check(panel.widgets.cursor_size.get_global_rect().end.y < panel.apply_button.get_global_rect().position.y,"size control above footer")
		await capture("settings-other-%d" % dimensions.x)
	panel.queue_free()
	await settle()
	cursors.set_cursor_size("normal")
	cursors.set_process(true)
	print("CURSOR VISUAL CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
