extends PanelContainer
signal hide_requested
signal list_requested
signal locate_requested(entry: Dictionary)
const Inventory = preload("res://scripts/map/map_inventory_screen.gd")
const HARMONY = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
class CenteredChevron extends Control:
	var facing_right := false
	func _init(right := false) -> void:
		facing_right = right
	func _draw() -> void:
		# Two crisp strokes with round ends, centered by their actual geometry.
		var center := size*0.5
		var points := PackedVector2Array([center+Vector2(-7,3.5),center+Vector2(0,-3.5),center+Vector2(7,3.5)])
		if facing_right:
			points = PackedVector2Array([center+Vector2(-3.5,-7),center+Vector2(3.5,0),center+Vector2(-3.5,7)])
		var gold := Color("e8d59b")
		draw_polyline(points,Color(gold,0.14),4.0,true)
		draw_polyline(points,gold,2.0,true)
		for point: Vector2 in points: draw_circle(point,1.0,gold,true,-1,true)

class TaskTitleRow extends Container:
	# Keep the tag next to the actual name; reserve its space before ellipsizing.
	func _get_minimum_size() -> Vector2:
		if get_child_count()!=2: return Vector2.ZERO
		return Vector2(get_child(1).get_combined_minimum_size().x+8,
			maxf(get_child(0).get_combined_minimum_size().y,get_child(1).get_combined_minimum_size().y))
	func _notification(what: int) -> void:
		if what!=NOTIFICATION_SORT_CHILDREN or get_child_count()!=2: return
		var caption: Label = get_child(0)
		var tag: Control = get_child(1)
		var tag_size := tag.get_combined_minimum_size()
		var name_width := caption.get_theme_font("font").get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,caption.get_theme_font_size("font_size")).x
		name_width = minf(name_width,maxf(0,size.x-tag_size.x-8))
		fit_child_in_rect(caption,Rect2(0,0,name_width,size.y))
		fit_child_in_rect(tag,Rect2(Vector2(name_width+8,(size.y-tag_size.y)*0.5),tag_size))

var column: VBoxContainer
var heading: HBoxContainer
var rows: VBoxContainer
var scroll: ScrollContainer
var close_button: Button
var list_button: Button
var cards: Array[Button] = []
var maximum_height := 650.0:
	set(value):
		if is_equal_approx(maximum_height,value): return
		maximum_height = value
		if is_instance_valid(rows): _fit_height.call_deferred()

func _init() -> void:
	name = "TaskTracker"
	z_index = 19
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size.x = 404
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("061725",0.94)
	fill.set_corner_radius_all(int(Inventory.BOARD_PANEL_RADIUS))
	fill.corner_detail = 16
	fill.content_margin_left = 16
	fill.content_margin_right = 16
	fill.content_margin_top = 12
	fill.content_margin_bottom = 12
	add_theme_stylebox_override("panel",fill)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	add_child(column)
	heading = HBoxContainer.new()
	heading.add_theme_constant_override("separation",12)
	column.add_child(heading)
	var diamond := preload("res://scripts/ui/task_heading_diamond.gd").new()
	heading.add_child(diamond)
	var title := _label("任务追踪",28,Color("e8c880"))
	var kai := SystemFont.new()
	kai.font_names = PackedStringArray(["KaiTi","楷体","serif"])
	title.add_theme_font_override("font",kai)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button = _button("",Vector2(36,36))
	close_button.size_flags_vertical = SIZE_SHRINK_CENTER
	heading.add_child(close_button)
	var chevron := CenteredChevron.new()
	chevron.name = "CenteredChevron"
	chevron.mouse_filter = MOUSE_FILTER_IGNORE
	close_button.add_child(chevron)
	chevron.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	chevron.resized.connect(chevron.queue_redraw)
	close_button.pressed.connect(func(): hide_requested.emit())
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",8)
	scroll.add_child(rows)
	rows.minimum_size_changed.connect(func(): _fit_height.call_deferred())
	list_button = _button("",Vector2(0,44))
	list_button.add_theme_font_size_override("font_size",18)
	column.add_child(list_button)
	var footer_center := CenterContainer.new()
	footer_center.mouse_filter = MOUSE_FILTER_IGNORE
	list_button.add_child(footer_center)
	footer_center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var footer_content := HBoxContainer.new()
	footer_content.mouse_filter = MOUSE_FILTER_IGNORE
	footer_content.add_theme_constant_override("separation",8)
	footer_center.add_child(footer_content)
	var footer_caption := _label("打开任务列表",18)
	footer_caption.name = "ListCaption"
	footer_content.add_child(footer_caption)
	footer_content.add_child(_right_chevron("ListChevron"))
	list_button.pressed.connect(func(): list_requested.emit())
	var border_layer := Node2D.new()
	add_child(border_layer)
	var rim := ColorRect.new()
	rim.mouse_filter = MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_panel_border.gdshader")
	paint.set_shader_parameter("corner_radius",Inventory.BOARD_PANEL_RADIUS)
	paint.set_shader_parameter("line_width",Inventory.BOARD_PANEL_BORDER_WIDTH)
	paint.set_shader_parameter("line_color",Inventory.MAIN_PANEL_BORDER_COLOR)
	rim.material = paint
	border_layer.add_child(rim)
	resized.connect(func():
		rim.position = -Vector2.ONE*2
		rim.size = size+Vector2.ONE*4
		paint.set_shader_parameter("panel_size",size))

func _label(text: String, font_size: int, color := Color("dce0dc")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",HARMONY)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label

func _button(text: String, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = dimensions
	button.focus_mode = FOCUS_NONE
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_override("font",HARMONY)
	button.add_theme_font_size_override("font_size",20)
	for kind in ["normal","hover","pressed","disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("102532",0.94) if kind=="normal" else Color("1d3440",0.96)
		box.border_color = Color("52616a") if kind=="normal" else Inventory.MAIN_PANEL_BORDER_COLOR
		box.set_border_width_all(1)
		box.set_corner_radius_all(5)
		button.add_theme_stylebox_override(kind,box)
	return button

func _icon(path: String, dimensions: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.custom_minimum_size = dimensions
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	return icon

func _right_chevron(node_name: String) -> Control:
	var chevron := CenteredChevron.new(true)
	chevron.name = node_name
	chevron.custom_minimum_size = Vector2(18,20)
	chevron.size_flags_vertical = SIZE_SHRINK_CENTER
	chevron.mouse_filter = MOUSE_FILTER_IGNORE
	chevron.resized.connect(chevron.queue_redraw)
	return chevron

func display(entries: Array) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	cards.clear()
	if entries.is_empty():
		var empty := _label("尚未追踪任务",20,Color("98a6b0"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(empty)
	for entry: Dictionary in entries.slice(0,QuestTracking.LIMIT):
		var card := _button("",Vector2.ZERO)
		card.name = entry.id.replace(".","_")
		rows.add_child(card)
		cards.append(card)
		card.pressed.connect(func(): locate_requested.emit(entry))
		var margin := MarginContainer.new()
		margin.mouse_filter = MOUSE_FILTER_IGNORE
		for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,10)
		card.add_child(margin)
		margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var content := HBoxContainer.new()
		content.mouse_filter = MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation",10)
		margin.add_child(content)
		for category: Dictionary in QuestTracking.sidebar.categories:
			if category.id==entry.category:
				var category_icon := _icon(category.icon,Vector2(40.8,40.8))
				category_icon.name = "CategoryIcon"
				category_icon.size_flags_vertical = SIZE_SHRINK_CENTER
				content.add_child(category_icon)
		var column := VBoxContainer.new()
		column.name = "TaskTextRows"
		column.mouse_filter = MOUSE_FILTER_IGNORE
		column.size_flags_horizontal = SIZE_EXPAND_FILL
		# Font line boxes add their own leading: 7px makes the visible row gap
		# match the last line's visible bottom inset (10px container padding).
		column.add_theme_constant_override("separation",7)
		content.add_child(column)
		content.add_child(_right_chevron("LocateChevron"))
		var title := TaskTitleRow.new()
		title.name = "TaskTitleRow"
		title.mouse_filter = MOUSE_FILTER_IGNORE
		column.add_child(title)
		var tag := preload("res://scripts/map/map_task_category_tag.gd").new(QuestTracking.presentation.category_tags[entry.category])
		tag.custom_minimum_size = Vector2(52,26)
		tag.caption.add_theme_font_size_override("font_size",16)
		tag.size_flags_vertical = SIZE_SHRINK_CENTER
		var caption := _label(entry.title,21)
		caption.name = "TaskName"
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_child(caption)
		tag.name = "CategoryTag"
		title.add_child(tag)
		var objective_line := HBoxContainer.new()
		objective_line.name = "TaskObjectiveRow"
		objective_line.mouse_filter = MOUSE_FILTER_IGNORE
		objective_line.add_theme_constant_override("separation",8)
		column.add_child(objective_line)
		var icon := _icon("res://assets/UI-task-topright-location.webp",Vector2(18,24))
		icon.name = "ObjectiveLocation"
		icon.size_flags_vertical = SIZE_SHRINK_BEGIN
		objective_line.add_child(icon)
		var text_lines: Array[String] = []
		for objective: Dictionary in QuestTracking.objectives(entry):
			var line: String = objective.text
			if objective.get("show_count",false):
				line += ("（%d/%d）" if objective.get("inline_count",false) else " %d/%d") % [objective.current,objective.required]
			text_lines.append(line)
		var objectives := _label("\n".join(text_lines),18,Color("b7c4cc"))
		objectives.name = "CurrentObjectives"
		objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objectives.size_flags_horizontal = SIZE_EXPAND_FILL
		objective_line.add_child(objectives)
		# Fit the content's symmetric padding instead of leaving a minimum-height
		# surplus underneath the final objective line.
		margin.minimum_size_changed.connect(func(): card.custom_minimum_size.y = margin.get_combined_minimum_size().y)
	_fit_height.call_deferred()

func _fit_height() -> void:
	if list_button==null: return
	var separation := 8 if cards.is_empty() else 10
	column.add_theme_constant_override("separation",separation)
	var heading_height := heading.get_combined_minimum_size().y
	var button_height := list_button.get_combined_minimum_size().y
	var panel := get_theme_stylebox("panel")
	var chrome_height := panel.get_content_margin(SIDE_TOP)+panel.get_content_margin(SIDE_BOTTOM)+heading_height+button_height+separation*2
	var content_height := rows.get_combined_minimum_size().y
	if cards.is_empty():
		# The gap from the centered close button's bottom to the footer's top
		# equals one footer height, including both container separations.
		var close_inset := (heading_height-close_button.get_combined_minimum_size().y)*0.5
		content_height = maxf(0,button_height-close_inset-separation*2)
	content_height = minf(content_height,maxf(0,maximum_height-chrome_height))
	scroll.custom_minimum_size.y = content_height
	set_deferred("size",Vector2(404,content_height+chrome_height))
