extends SceneTree

class GridPreview extends Control:
	var layout: BoardLayout
	var texture: Texture2D
	func _draw() -> void:
		draw_texture_rect(texture,layout.art_rect(size),false)
		for x in layout.x_lines:
			draw_line(layout.source_to_view(Vector2(x,layout.y_lines[0]),size),layout.source_to_view(Vector2(x,layout.y_lines[-1]),size),Color(0.2,1,0.8,.7),1.5)
		for y in layout.y_lines:
			draw_line(layout.source_to_view(Vector2(layout.x_lines[0],y),size),layout.source_to_view(Vector2(layout.x_lines[-1],y),size),Color(0.2,1,0.8,.7),1.5)
		for y in layout.grid_size.y:
			for x in layout.grid_size.x:
				var center := layout.footprint_rect(Vector2i(x,y),Vector2i.ONE,size).get_center()
				draw_line(center-Vector2(5,0),center+Vector2(5,0),Color.CYAN,1)
				draw_line(center-Vector2(0,5),center+Vector2(0,5),Color.CYAN,1)

var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func panel(layout: BoardLayout, at: Vector2, dimensions: Vector2) -> GridPreview:
	var node := GridPreview.new()
	node.layout = layout
	node.texture = load(layout.texture_path)
	node.position = at
	node.size = dimensions
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(node)
	return node

func run() -> void:
	root.size = Vector2i(2560,1440)
	var background := ColorRect.new()
	background.color = Color("19212b")
	background.size = Vector2(2560,1440)
	root.add_child(background)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry loads")
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "isolated item catalog loads")
	var model: MapLoadoutState = created.state
	var board := registry.get_board("base.board.qingshihewan_chisong_liaozhu")
	check(registry.get_enemy("base.enemy.chisong_liaozhu").board_layout == board.id, "pig references independent layout")
	var large := panel(board,Vector2(30,20),Vector2(900,900))
	var heart: MapItemArtwork
	for row: Dictionary in registry.get_enemy("base.enemy.chisong_liaozhu").loadout:
		var item := registry.get_item(row.item_id)
		var art := MapItemArtwork.new()
		art.configure({"icon":item.icon_path,"name":item.display_name,"art_outline_px":1})
		large.add_child(art)
		var footprint := board.footprint_rect(Vector2i(row.cell[0],row.cell[1]),item.grid_size,large.size)
		art.place_on_board(footprint)
		if row.item_id == "base.organ.cslz_heart":
			heart = art
			check((art.get_transform()*art._visible_local_center(false)).is_equal_approx(footprint.get_center()), "heart visible center equals its cell center")
	var metrics := MapItemArtwork.TextureMetrics.inspect(heart.texture.atlas)
	check(MapItemArtwork.TextureMetrics.alignment_center(heart.texture.atlas).is_equal_approx(Rect2(metrics.visible_rect).get_center()), "no heart optical/manual offset")
	var tooltip := ItemTooltip.new()
	tooltip.configure(registry.get_item("base.material.cslz_heart"))
	root.add_child(tooltip)
	tooltip.position = Vector2(1020,80)
	var card := MapInventoryItemCard.new()
	card.configure(model.records["base.material.cslz_heart"],"兽材")
	root.add_child(card)
	card.position = Vector2(1850,80)
	card.size = Vector2(285,380)
	var gallery := 0
	for id: String in registry._boards:
		var layout := registry.get_board(id)
		var texture: Texture2D = load(layout.texture_path)
		check(texture.get_size() == layout.source_size, "source dimensions match %s: texture=%s, config=%s" % [id,texture.get_size(),layout.source_size])
		var view_size := Vector2(440,370)
		for y in layout.grid_size.y:
			for x in layout.grid_size.x:
				var cell := Vector2i(x,y)
				check(layout.cell_at(layout.footprint_rect(cell,Vector2i.ONE,view_size).get_center(),view_size) == cell, "same mapping for display and cell lookup " + id)
		if id == board.id: continue
		panel(layout,Vector2(30+gallery*495,1010),view_size)
		var label := Label.new()
		label.text = layout.display_name + "  " + str(layout.grid_size)
		label.position = Vector2(30+gallery*495,970)
		label.add_theme_font_size_override("font_size",25)
		root.add_child(label)
		gallery += 1
	for i in 8: await process_frame
	var portrait: MapItemArtwork = tooltip.find_child("PortraitArtwork",true,false)
	check((portrait.get_transform()*portrait._visible_local_center(false)).is_equal_approx(portrait.get_parent().size*.5), "tooltip heart centered in square")
	var card_art: MapItemArtwork = card.canvas.get_node("ItemArtwork")
	check(absf((card_art.get_transform()*card_art._visible_local_center(false)).x-MapInventoryItemCard.DESIGN_WIDTH*.5) < 1, "card heart stays horizontally centered")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/board-alignment-heart.png")
	for node in root.get_children():
		if node is Control: node.queue_free()
	for i in 3: await process_frame
	print("BOARD ALIGNMENT: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
