extends Control
## Task workspace shell. Content and quest state are deliberately not invented.
signal category_changed(category_id: String)
const Inventory = preload("res://scripts/map/map_inventory_screen.gd")
const Technique = preload("res://scripts/map/map_technique_screen.gd")
const Sidebar = preload("res://scripts/map/map_task_sidebar.gd")
const TaskList = preload("res://scripts/map/map_task_list.gd")
const DetailHeader = preload("res://scripts/map/map_task_detail_header.gd")
var stage: Control
var body: Control
var left_panel: PanelContainer
var middle_panel: PanelContainer
var right_panel: PanelContainer
var background_art: TextureRect
var left_background_art: TextureRect
var middle_background_art: TextureRect
var right_background_art: TextureRect
var stamina_bar: Control
var sidebar: Control
var task_list: Control
var detail_header: Control

func _has_point(point: Vector2) -> bool:
	# The shared header is drawn above this screen and retains its task toggle.
	return Rect2(Vector2(0,MapStatusHeader.height_for_width(size.x)),Vector2(size.x,size.y-MapStatusHeader.height_for_width(size.x))).has_point(point)

func _init() -> void:
	name = "MapTaskScreen"
	z_index = 25
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var backing := ColorRect.new()
	backing.color = Color("08121c")
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art = TextureRect.new()
	background_art.texture = preload("res://assets/inv-background.webp")
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.self_modulate.a = 0.5
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_art)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	body = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(body)
	left_panel = _panel("TaskLeftPanel",18.0)
	middle_panel = _panel("TaskMiddlePanel",Inventory.BOARD_PANEL_RADIUS)
	right_panel = _panel("TaskRightPanel",Inventory.BOARD_PANEL_RADIUS)
	for panel in [left_panel,middle_panel,right_panel]:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.anchor_right = 0.0
	right_panel.anchor_right = 1.0
	_build_sidebar_background()
	middle_background_art = _build_column_background(middle_panel, "res://assets/UI-task-mid-bg.webp")
	right_background_art = _build_column_background(right_panel, "res://assets/UI-task-right-bg.webp")
	right_background_art.self_modulate = Color.WHITE
	_build_sidebar()
	_build_task_list()
	_build_task_detail()
	resized.connect(_queue_layout)
	visibility_changed.connect(_queue_layout)

func _build_sidebar_background() -> void:
	var layer := Node2D.new()
	layer.name = "BackdropLayer"
	left_panel.add_child(layer)
	left_background_art = TextureRect.new()
	left_background_art.name = "ColumnBackground"
	left_background_art.texture = load("res://assets/UI-task-left-bg.webp")
	left_background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left_background_art.stretch_mode = TextureRect.STRETCH_SCALE
	left_background_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	left_background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://scripts/map/map_inventory_panel_art.gdshader")
	mask.set_shader_parameter("corner_radius", 18.0)
	mask.set_shader_parameter("top_fade_fraction", 0.2)
	left_background_art.material = mask
	layer.add_child(left_background_art)
	left_panel.resized.connect(_layout_sidebar_background)

func _layout_sidebar_background() -> void:
	var source := left_background_art.texture.get_size()
	# Width-fit, then shift 30 design pixels below bottom alignment; clip at the rim.
	left_background_art.size = source * (left_panel.size.x / source.x)
	left_background_art.position = Vector2(0, left_panel.size.y - left_background_art.size.y + 30.0)
	var mask := left_background_art.material as ShaderMaterial
	mask.set_shader_parameter("panel_size", left_panel.size)
	mask.set_shader_parameter("art_size", left_background_art.size)
	mask.set_shader_parameter("art_position", left_background_art.position)

func _build_sidebar() -> void:
	# The content follows the existing frame without altering its minimum size.
	var layer := Node2D.new()
	layer.name = "SidebarLayer"
	layer.z_index = 2
	left_panel.add_child(layer)
	sidebar = Sidebar.new()
	layer.add_child(sidebar)
	left_panel.resized.connect(func(): sidebar.size = left_panel.size)
	sidebar.category_changed.connect(func(id: String): category_changed.emit(id))

func _build_column_background(panel: PanelContainer, texture_path: String) -> TextureRect:
	var layer := Node2D.new()
	layer.name = "BackdropLayer"
	panel.add_child(layer)
	var art := TextureRect.new()
	art.name = "ColumnBackground"
	art.texture = load(texture_path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://scripts/map/map_inventory_panel_art.gdshader")
	mask.set_shader_parameter("corner_radius", Inventory.BOARD_PANEL_RADIUS)
	mask.set_shader_parameter("top_fade_fraction", 0.0)
	art.material = mask
	layer.add_child(art)
	panel.resized.connect(_layout_column_background.bind(panel, art))
	return art

func _layout_column_background(panel: PanelContainer, art: TextureRect) -> void:
	var source := art.texture.get_size()
	art.size = source * maxf(panel.size.x / source.x, panel.size.y / source.y)
	art.position = (panel.size - art.size) * 0.5
	var mask := art.material as ShaderMaterial
	mask.set_shader_parameter("panel_size", panel.size)
	mask.set_shader_parameter("art_size", art.size)
	mask.set_shader_parameter("art_position", art.position)

func bind_header(header: MapStatusHeader) -> void:
	stamina_bar = header.bars.stamina
	header.resized.connect(_queue_layout)
	stamina_bar.resized.connect(_queue_layout)
	_queue_layout()

func _build_task_list() -> void:
	var layer := Node2D.new()
	layer.name = "TaskListLayer"
	layer.z_index = 2
	middle_panel.add_child(layer)
	task_list = TaskList.new()
	layer.add_child(task_list)
	middle_panel.resized.connect(func(): task_list.size = middle_panel.size)
	sidebar.category_changed.connect(task_list.set_category)

func _queue_layout() -> void:
	_layout.call_deferred()

func _build_task_detail() -> void:
	# Keep artwork above the column background but below the existing gold rim.
	var layer := Node2D.new()
	layer.name = "TaskDetailLayer"
	right_panel.add_child(layer)
	detail_header = DetailHeader.new()
	layer.add_child(detail_header)
	right_panel.resized.connect(func(): detail_header.size = right_panel.size)
	task_list.task_selected.connect(func(_id: String): _refresh_task_detail())
	task_list.entries_changed.connect(_refresh_task_detail)
	_refresh_task_detail()

func _refresh_task_detail() -> void:
	for entry: Dictionary in task_list.ordered_entries():
		if str(entry.id) == task_list.selected_task_id:
			detail_header.show_entry(entry, sidebar.icons[entry.category].texture, task_list.definitions.category_tags)
			return
	detail_header.clear_entry()

func _panel(node_name: String, radius: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	var fill := StyleBoxFlat.new()
	fill.bg_color = Inventory.MAIN_PANEL_BACKGROUND_COLOR
	fill.set_corner_radius_all(int(radius))
	fill.corner_detail = 16
	panel.add_theme_stylebox_override("panel",fill)
	body.add_child(panel)
	var border_layer := Node2D.new()
	border_layer.z_index = 1
	panel.add_child(border_layer)
	var rim := ColorRect.new()
	rim.name = "Border"
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_panel_border.gdshader")
	paint.set_shader_parameter("corner_radius",radius)
	paint.set_shader_parameter("line_width",Inventory.BOARD_PANEL_BORDER_WIDTH)
	paint.set_shader_parameter("line_color",Inventory.MAIN_PANEL_BORDER_COLOR)
	rim.material = paint
	border_layer.add_child(rim)
	panel.resized.connect(func():
		rim.position = -Vector2.ONE*2.0
		rim.size = panel.size+Vector2.ONE*4.0
		paint.set_shader_parameter("panel_size",panel.size))
	return panel

func _layout() -> void:
	if size.x<=0 or size.y<=0 or not is_instance_valid(stamina_bar): return
	var base_head := MapStatusHeader.height_for_width(1920.0)
	var head := MapStatusHeader.height_for_width(size.x)
	background_art.position = Vector2(0,head)
	background_art.size = Vector2(size.x,maxf(0,size.y-head))
	var factor := minf(size.x/1920.0,(size.y-head)/(1080.0-base_head))
	if factor<=0: return
	stage.scale = Vector2.ONE*factor
	stage.size = Vector2(1920,1080)
	stage.position = Vector2((size.x-1920.0*factor)*0.5,head-base_head*factor+(size.y-head-(1080.0-base_head)*factor)*0.5)
	var extra_width := maxf(0,size.x/factor-1920.0)
	body.position = Vector2(Inventory.BODY_SIDE_MARGIN-extra_width*0.5,146)
	body.size = Vector2(Inventory.BODY_WIDTH+extra_width,Inventory.BODY_HEIGHT)
	# Align with the full bar's midpoint, never its changing filled portion.
	var midpoint := body.get_global_transform().affine_inverse()*stamina_bar.get_global_rect().get_center()
	left_panel.offset_right = Technique.LEFT_WIDTH
	middle_panel.offset_left = Technique.LEFT_WIDTH+Inventory.BODY_COLUMN_GAP+extra_width*0.5
	middle_panel.offset_right = midpoint.x
	right_panel.offset_left = midpoint.x+Inventory.BODY_COLUMN_GAP
	right_panel.offset_right = 0
