extends Control
signal track_requested(id: String)
signal map_requested(id: String)
## Shared four-frame layout. All geometry is authored in the source canvas.
const HARMONY = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
const GOLD := Color("e8c880")
var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/task_detail_layout.json"))
var canvas: Control
var frames: Dictionary = {}
var heading_diamonds: Array[Control] = []
var objective_rows: VBoxContainer
var objective_scroll: ScrollContainer
var reward_slots: HBoxContainer
var people_slots: HBoxContainer
var location_body: Control
var footer: HBoxContainer
var footer_buttons: Array[TextureButton] = []
var state: MapLoadoutState
var _entry: Dictionary = {}
var _objective_scroll_revision := 0
var _kai := SystemFont.new()
var _song := SystemFont.new()

func _init() -> void:
	name = "TaskDetailBody"
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	oversampling_with_scale = OVERSAMPLING_WITH_SCALE_ENABLED
	_kai.font_names = PackedStringArray(["KaiTi","楷体","serif"])
	_song.font_names = PackedStringArray(["SimSun","宋体","serif"])
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	for key: String in layout.frames:
		var config: Dictionary = layout.frames[key]
		var rect: Array = config.rect
		var frame := Control.new()
		frame.name = key.capitalize()
		frame.mouse_filter = MOUSE_FILTER_IGNORE
		frame.position = Vector2(rect[0],rect[1])
		frame.size = Vector2(rect[2],rect[3])
		frame.clip_contents = true
		canvas.add_child(frame)
		frames[key] = frame
		var art := _image(frame,"res://assets/%s.webp" % config.image)
		art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var title := HBoxContainer.new()
		title.position = Vector2(29,18)
		title.size = Vector2(frame.size.x-58,46)
		title.add_theme_constant_override("separation",17)
		title.mouse_filter = MOUSE_FILTER_IGNORE
		frame.add_child(title)
		var diamond := preload("res://scripts/ui/task_heading_diamond.gd").new(Vector2(19,46),GOLD)
		title.add_child(diamond)
		heading_diamonds.append(diamond)
		title.add_child(_label(config.title,36,GOLD,_kai))
	objective_scroll = ScrollContainer.new()
	objective_scroll.position = Vector2(27,76)
	objective_scroll.size = frames.objectives.size-Vector2(54,100)
	objective_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	objective_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	frames.objectives.add_child(objective_scroll)
	objective_rows = VBoxContainer.new()
	objective_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	objective_rows.add_theme_constant_override("separation",0)
	objective_scroll.add_child(objective_rows)
	location_body = Control.new()
	location_body.mouse_filter = MOUSE_FILTER_IGNORE
	location_body.position = Vector2(26,80)
	location_body.size = frames.locations.size-Vector2(52,108)
	frames.locations.add_child(location_body)
	reward_slots = _slots("rewards")
	people_slots = _slots("people")
	_build_footer()
	resized.connect(_layout)
	hide()

func _build_footer() -> void:
	var config: Dictionary = layout.footer_buttons
	footer = HBoxContainer.new()
	footer.name = "TaskFooter"
	footer.mouse_filter = MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation",int(config.gap))
	canvas.add_child(footer)
	for caption: String in config.labels:
		var button := TextureButton.new()
		button.name = "TrackTask" if footer_buttons.is_empty() else "ViewMap"
		button.texture_normal = load(config.normal)
		button.texture_hover = load(config.hover)
		button.texture_disabled = button.texture_normal
		button.texture_pressed = button.texture_hover
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(config.width,config.height)
		button.focus_mode = FOCUS_NONE
		button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		footer.add_child(button)
		footer_buttons.append(button)
		var label := _label(caption,36,Color("f4e6bd"),_kai)
		label.name = "Caption"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(label)
		label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		button.mouse_entered.connect(func(): label.add_theme_color_override("font_color",Color("241c0e")))
		button.mouse_exited.connect(func(): label.add_theme_color_override("font_color",Color("f4e6bd")))
		if footer_buttons.size()==1:
			button.pressed.connect(func(): track_requested.emit(str(_entry.get("id",""))))
		else:
			button.pressed.connect(func(): map_requested.emit(str(_entry.get("id",""))))

func _slots(key: String) -> HBoxContainer:
	var config: Dictionary = layout.frames[key]
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.position = Vector2(config.slot_origin[0],config.slot_origin[1])
	row.size = Vector2(frames[key].size.x-row.position.x-20,166)
	row.add_theme_constant_override("separation",int(config.slot_step[0])-int(config.slot_size[0]))
	if config.get("alignment","")=="center":
		row.position.x = 0
		row.size.x = frames[key].size.x
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	frames[key].add_child(row)
	return row

func show_entry(entry: Dictionary) -> void:
	_objective_scroll_revision += 1
	_entry = entry.duplicate(true)
	_clear(objective_rows)
	_clear(reward_slots)
	_clear(people_slots)
	_clear(location_body)
	if not entry.has("objectives"):
		hide()
		return
	# Title divider is always present, including an empty objective list.
	_divider(objective_rows)
	for row: Dictionary in entry.objectives:
		_objective(row)
		_divider(objective_rows)
	if entry.get("has_locked_next",false): _locked_row()
	for reward: Dictionary in entry.get("rewards",[]): _tile(reward_slots,reward,false)
	for person: Dictionary in entry.get("people",[]): _tile(people_slots,person,true)
	_location(entry.get("location",{}))
	_refresh_tracking()
	show()
	_layout()
	_scroll_objectives_to_bottom.call_deferred(_objective_scroll_revision)

func _scroll_objectives_to_bottom(revision: int) -> void:
	if not is_inside_tree(): return
	# Container layout must publish its scroll range before choosing the bottom.
	await get_tree().process_frame
	if revision!=_objective_scroll_revision or not is_visible_in_tree(): return
	var bar := objective_scroll.get_v_scroll_bar()
	objective_scroll.scroll_vertical = maxi(0,ceili(bar.max_value-bar.page))

func clear_entry() -> void:
	_objective_scroll_revision += 1
	_entry.clear()
	hide()

func _objective(row: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.name = "Objective_"+str(row.id)
	line.custom_minimum_size.y = 56
	line.add_theme_constant_override("separation",20)
	line.mouse_filter = MOUSE_FILTER_IGNORE
	objective_rows.add_child(line)
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(37,44)
	mark.size_flags_vertical = SIZE_SHRINK_CENTER
	mark.mouse_filter = MOUSE_FILTER_IGNORE
	line.add_child(mark)
	mark.draw.connect(func():
		mark.draw_arc(Vector2(18.5,22),16.5,0,TAU,48,Color("677c89"),2,true)
		if row.completed:
			mark.draw_polyline(PackedVector2Array([Vector2(8,22),Vector2(16,30),Vector2(32,11)]),Color("8acb82"),4,true))
	if row.has("requirements"):
		var requirements := VBoxContainer.new()
		requirements.name = "Requirements"
		requirements.size_flags_horizontal = SIZE_EXPAND_FILL
		requirements.add_theme_constant_override("separation",0)
		line.add_child(requirements)
		for requirement: Dictionary in row.requirements:
			var content := HBoxContainer.new()
			content.name = str(requirement.id)
			content.custom_minimum_size.y = 38
			requirements.add_child(content)
			_objective_content(content,requirement)
	else:
		_objective_content(line,row)

func _objective_content(line: HBoxContainer, row: Dictionary) -> void:
	var caption: String = row.text
	if row.get("inline_count",false): caption += "（%d/%d）" % [row.current,row.required]
	var label := _label(caption,29,Color("d2dbdf"),_kai)
	label.name = "ObjectiveText"
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(label)
	if row.show_count and not row.get("inline_count",false):
		var count := _label("%d/%d" % [row.current,row.required],27,Color("8acb82") if row.completed else Color("b6c6d0"),HARMONY)
		count.name = "ProgressCount"
		count.custom_minimum_size.x = 60
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(count)

func _locked_row() -> void:
	var row := HBoxContainer.new()
	row.name = "LockedNextObjective"
	row.custom_minimum_size.y = 56
	row.add_theme_constant_override("separation",20)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	objective_rows.add_child(row)
	var lock := _image(row,"res://assets/UI-task-right-lock.webp")
	lock.custom_minimum_size = Vector2(37,37)
	lock.size_flags_vertical = SIZE_SHRINK_CENTER
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.self_modulate = Color("8a9ca9")
	row.add_child(_label("???（后续内容待探索）",28,Color("788e9e"),_kai))

func _divider(parent: Node) -> void:
	var line := HSeparator.new()
	line.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxLine.new()
	style.color = Color("334852",0.65)
	style.thickness = 1
	line.add_theme_stylebox_override("separator",style)
	line.add_theme_constant_override("separation",1)
	line.custom_minimum_size.y = 1
	parent.add_child(line)

func _tile(parent: HBoxContainer, data: Dictionary, portrait: bool) -> void:
	var tile := VBoxContainer.new()
	tile.name = "PortraitTile" if portrait else "RewardTile"
	tile.custom_minimum_size.x = 118
	tile.size_flags_horizontal = SIZE_SHRINK_BEGIN
	tile.add_theme_constant_override("separation",7)
	tile.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(tile)
	var square := Control.new()
	square.custom_minimum_size = Vector2(118,118)
	square.clip_contents = true
	square.mouse_filter = MOUSE_FILTER_IGNORE
	tile.add_child(square)
	if portrait:
		var face := _image(square,data.portrait)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var rim := Panel.new()
		rim.name = "PortraitBorder"
		rim.mouse_filter = MOUSE_FILTER_IGNORE
		var border := StyleBoxFlat.new()
		border.draw_center = false
		border.border_color = preload("res://scripts/map/map_inventory_screen.gd").MAIN_PANEL_BORDER_COLOR
		border.set_border_width_all(2)
		rim.add_theme_stylebox_override("panel",border)
		square.add_child(rim)
		rim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	elif data.get("kind","")=="item" and state!=null and state.records.has(data.get("item_id","")):
		MapItemThumbnail.create(square,state.records[data.item_id],118,-1,0.85)
	else:
		preload("res://scripts/map/map_item_small_background.gd").create(square,{},Color("7b8a94"))
		var icon := _image(square,data.get("icon",layout.resource_icons.get(data.get("kind",""),"")))
		icon.position = Vector2(17,17)
		icon.size = Vector2(84,84)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not portrait:
		var quantity := _label("+%d" % int(data.quantity),25,Color.WHITE,HARMONY)
		quantity.name = "RewardQuantity"
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color(0,0,0,0.42)
		badge.set_corner_radius_all(6)
		quantity.add_theme_stylebox_override("normal",badge)
		var width := maxf(35,HARMONY.get_string_size(quantity.text,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x+12)
		quantity.position = Vector2(113-width,83)
		quantity.size = Vector2(width,30)
		square.add_child(quantity)
	var caption := _label(data.name,27,Color("e0e3df"),_song)
	caption.name = "TileName"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tile.add_child(caption)

func _location(data: Dictionary) -> void:
	if data.is_empty(): return
	var art := _image(location_body,data.image)
	art.size = Vector2(location_body.size.x,location_body.size.y-49)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	var pin := _image(location_body,"res://assets/UI-task-right-map-location.webp")
	pin.position = Vector2(2,location_body.size.y-36)
	pin.size = Vector2(23,31)
	pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var parts := str(data.name).split("·")
	for i in parts.size(): parts[i] = parts[i].strip_edges()
	var caption := _label("·".join(parts),28,Color("d2dbdf"),_kai)
	caption.name = "LocationName"
	caption.position = Vector2(38,location_body.size.y-40)
	caption.size = Vector2(location_body.size.x-38,40)
	location_body.add_child(caption)

func _image(parent: Node, path: String) -> TextureRect:
	var art := TextureRect.new()
	art.texture = load(path) if not path.is_empty() else null
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.texture_filter = TEXTURE_FILTER_LINEAR
	label.oversampling_with_scale = OVERSAMPLING_WITH_SCALE_DISABLED
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _layout() -> void:
	if size.x<100: return
	canvas.scale = Vector2.ONE * (size.x / float(layout.source_width))
	canvas.size = size / maxf(canvas.scale.x,0.001)
	for diamond in heading_diamonds:
		diamond.units_per_design_pixel = 1.0 / canvas.scale.x
	var lower_edge := maxf(frames.people.get_rect().end.y,frames.rewards.get_rect().end.y)
	var config: Dictionary = layout.footer_buttons
	footer.size = Vector2(float(config.width)*2+float(config.gap),config.height)
	footer.position = Vector2((canvas.size.x-footer.size.x)*0.5,(lower_edge+canvas.size.y-footer.size.y)*0.5)


func _refresh_tracking() -> void:
	if state==null or footer_buttons.is_empty(): return
	var tracked: bool = _entry.get("id","") in state.quest_tracking.ids
	var complete: bool = _entry.get("stage_id","")=="completed"
	var locked_main: bool = tracked and _entry.get("category","")=="main"
	var button := footer_buttons[0]
	button.get_node("Caption").text = "正在追踪" if locked_main else ("取消追踪" if tracked else "追踪任务")
	button.disabled = complete or locked_main
	button.modulate = Color(0.45,0.45,0.45) if button.disabled else Color.WHITE
	button.tooltip_text = "任务已完成" if complete else ("当前追踪的主线任务不能取消追踪" if locked_main else "")
	footer_buttons[1].disabled = QuestTracking.targets(_entry).is_empty()
	footer_buttons[1].modulate = Color(0.45,0.45,0.45) if footer_buttons[1].disabled else Color.WHITE

func set_tracking_error(error: String) -> void:
	_refresh_tracking()
	if not error.is_empty(): footer_buttons[0].tooltip_text = error
