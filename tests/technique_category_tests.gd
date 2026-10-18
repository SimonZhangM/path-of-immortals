extends "res://tests/map_shop_tests.gd"

const NAMES := [
	["玄金百炼录", "庚金真解", "金煞藏锋经", "玄庚剑诀", "百兵御灵诀"],
	["百兽驭灵录", "青木真解", "枯荣生灭经", "万木生杀诀", "青萝化生诀"],
	["灵墨玄符录", "玄水真解", "寒脉流转经", "寒月凝冰诀", "沧澜燃灵诀"],
	["赤炉丹经", "离火真解", "炎煞流火经", "赤阳真火诀", "离火燎原诀"],
	["坤元地脉录", "厚土真解", "镇岳沉元经", "撼岳裂地诀", "不动玄岳诀"],
	["听风寻迹录", "御风真解", "流风无相经", "青冥破空诀", "听风无影诀"],
	["玄枢阵录", "天雷真解", "雷池引霆经", "九霄霆光诀", "雷罡镇狱诀"]]

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560, 1440)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	await settle()
	check(map.startup_error.is_empty(), "actual map starts")
	map.set_technique_open(true)
	await settle()
	var screen = map.technique_screen
	var before: Dictionary = map.loadout.snapshot().duplicate(true)
	var artwork: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_book_art.json"))
	check(artwork.size()==35, "all 35 books have an explicit cover mapping")
	check(screen.book_cards.size() == 35 and screen.category_buttons.size() == 7, "35 books in seven categories")
	for viewport_size in [Vector2i(1920,1080), Vector2i(2560,1440), Vector2i(2560,1080)]:
		root.size = viewport_size
		await settle()
		var factor: float = screen.stage.scale.x
		check(absf(screen.left_panel.size.x-253.333333)<0.01, "left reduced another twenty design pixels")
		check(absf(screen.middle_panel.get_rect().end.x-screen.right_panel.position.x+19)<0.01, "middle right edge retains original right gap")
		if viewport_size.x*9 == viewport_size.y*16:
			check(absf(screen.middle_panel.size.x-1203.5)<0.01 and absf(screen.middle_panel.position.x-272.333333)<0.01, "middle extends another twenty pixels left with right edge fixed")
		for panel in [screen.left_panel,screen.middle_panel]:
			var art: TextureRect = panel.find_child("ColumnBackground",true,false)
			check(art.get_global_rect().get_center().is_equal_approx(panel.get_global_rect().get_center()), "background follows panel center")
			check(art.size.x>=panel.size.x and art.size.y>=panel.size.y and is_equal_approx(art.size.x/art.texture.get_width(),art.size.y/art.texture.get_height()), "background covers panel uniformly")
		var row: Rect2 = screen.category_row.get_global_rect()
		check(absf(row.get_center().x-screen.left_panel.get_global_rect().get_center().x)<0.1, "category row follows narrower panel center")
		for button: Button in screen.category_buttons:
			check(button.size.is_equal_approx(Vector2(31,31)) and button.get_theme_font_size("font_size")==19 and button.get_theme_font("font").font_names[0]=="KaiTi", "category squares fit narrower panel with smaller Kaiti")
		var visible_cards: Array = screen.book_cards.filter(func(c): return c.visible)
		check(visible_cards.size()==5, "five cards visible")
		for card: Button in visible_cards:
			check(screen.left_panel.get_global_rect().encloses(card.get_global_rect()), "five cards fit left panel")
			check(card.size.is_equal_approx(visible_cards[0].size), "selected and unselected cards same dimensions")
		check(absf(visible_cards[0].get_global_rect().position.y-row.end.y-15*factor)<0.1, "list stays at y204 below resized categories")
		check(absf((row.position.x-screen.left_panel.get_global_rect().position.x)/factor-6.166667)<0.01 and visible_cards[0].size==Vector2(241,94), "category row and cards use tighter side margins")
	root.size = Vector2i(2560,1440)
	await settle()
	var changes: Array[String] = []
	screen.book_selected.connect(func(id: String): changes.append(id))
	for element_index in 7:
		var previous_book: String = screen.selected_book_id
		var previous_changes := changes.size()
		var category: Button = screen.category_buttons[element_index]
		if DisplayServer.get_name() == "headless": await click(category)
		else: category.button_pressed = true
		await settle()
		check(screen.selected_book_id==previous_book and changes.size()==previous_changes, "category browsing keeps selected book without publishing a new selection")
		check(screen.book_cards.filter(func(c): return c.button_pressed).size()==1, "exactly one book remains selected across all categories")
		var cards: Array = screen.book_cards.filter(func(c): return c.visible)
		check(cards.size()==5, "category filters exactly five books")
		var actual: Array[String] = []
		for card: Button in cards:
			var title: Label = card.find_child("BookName",true,false)
			actual.append(title.text)
			var labels := card.find_children("*","Label",true,false)
			check(labels.size()==2 and labels[1].text=="已领悟", "only book name and comprehension badge remain")
			check(absf(labels[1].get_global_rect().position.x-title.get_global_rect().position.x)<0.1 and labels[1].get_theme_stylebox("normal") is StyleBoxFlat, "outlined badge starts flush with book name")
			check(card.preview_art.texture is AtlasTexture and card.preview_art.texture.atlas.resource_path==artwork[card.book_id] and card.preview_art.texture.atlas.get_image().has_mipmaps(), "matching imported simple cover with mipmaps")
			check(card.preview_art.size.x==62 and card.preview_art.get_global_rect().end.x<title.get_global_rect().position.x and card.preview_art.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "left cover preserves aspect and clears text")
			for label: Label in labels:
				check(card.get_global_rect().encloses(label.get_global_rect()), "name and tags contained")
				check(label.get_theme_color("font_color")== (Color.WHITE if label==title else Color("c6dfc8")), "white title and pale green badge text")
			check(title.get_theme_font("font").font_names[0]=="KaiTi", "book names retain Kaiti")
			check(card.get_theme_stylebox("normal") is StyleBoxFlat and card.get_theme_stylebox("normal").corner_radius_top_left==6, "unselected dark rounded frame")
			check(card.get_theme_stylebox("pressed") is StyleBoxTexture and card.get_theme_stylebox("pressed").texture.atlas.get_image().has_mipmaps(), "selected uses imported artwork")
			if DisplayServer.get_name() == "headless":
				var rect := card.get_global_rect()
				await click(card)
				check(screen.selected_book_id==card.book_id and screen.book_cards.filter(func(c): return c.button_pressed).size()==1, "actual card click selects only one globally")
				check(rect.is_equal_approx(card.get_global_rect()), "selection does not shift or resize card")
		check(actual==NAMES[element_index], "exact requested names and order")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(screen.book_list.get_global_rect())).save_png("res://artifacts/technique-covers-%d.png" % element_index)
		if DisplayServer.get_name() != "headless" and element_index in [0,2]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/technique-books-%d.png" % element_index)
	if DisplayServer.get_name() == "headless":
		check(changes.size()==34, "only first selected card is unchanged; all other intentional selections publish once")
		await click(screen.category_buttons[0])
		await settle()
		check(screen.selected_book_id=="base.cultivation_book.thunder_05" and screen.book_cards.filter(func(c): return c.visible and c.button_pressed).is_empty(), "returning to metal keeps the thunder book until a book is clicked")
		await click(screen.book_cards.filter(func(c): return c.visible)[4])
		check(screen.selected_book_id=="base.cultivation_book.metal_05" and changes.size()==35, "explicit metal selection replaces the hidden thunder selection")
		await click(screen.book_cards.filter(func(c): return c.visible)[4])
		check(changes.size()==35, "repeat click keeps selection without extra event")
		await click(screen.category_buttons[1])
		map.set_technique_open(false)
		map.set_technique_open(true)
		check(screen.selected_book_id=="base.cultivation_book.metal_05", "reopening retains selected book")
		screen.configure(map.loadout.registry.library)
		await settle()
		check(screen.selected_book_id=="base.cultivation_book.metal_05" and screen.book_cards.filter(func(c): return c.button_pressed).size()==1, "rebuilding catalogue retains one global selection")
	check(map.loadout.snapshot()==before, "browsing leaves inventory and learning untouched")
	print("TECHNIQUE CATEGORIES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
