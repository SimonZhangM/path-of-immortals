extends Control

const Settings = preload("res://scripts/settings/game_settings.gd")
const SettingsInput = preload("res://scripts/settings/settings_input.gd")

# Geometry is in the unmodified frame's 2560x1440 source coordinates.
const FRAME_BOUNDS := Rect2(150, 0, 2260, 1440)
const MAP_RECT := Rect2(202, 104, 1674, 1279)
const ZOOM_STEP := 0.05
const MAX_SOURCE_ZOOM := 1.5
const TITLE_CENTER := Vector2(1280,80)
const TITLE_OFFSET := Vector2(-9,4)
# Center of the visible gold lettering in the source, excluding its faint shadow.
const TITLE_INK_CENTER := Vector2(538.5,153)
const SLIDER_SIZE := Vector2(75,348.6)
const TRACK_TOP := 85.2
const TRACK_BOTTOM := 265.2
const LOCATION_MARKER_WIDTH := 48.0
const LOCATION_MARKER_GAP := 2.0
const SELECTION_MARKER_WIDTH := 52.0
const CLICK_SLOP_PIXELS := 6.0
var stage: Control
var map_window: Control
var map_image: TextureRect
var location_marker: TextureRect
var landmark_markers: Dictionary = {}
var frame: TextureRect
var title: TextureRect
var zoom_control: Control
var scroll_art: TextureRect
var scroll_star: TextureRect
var plus_button: Button
var minus_button: Button
var footer: CenterContainer
var close_keys: Label
var shade: ColorRect
var zoom_index := 0
var zoom_levels: Array[float] = []
var dragging := false
var _pointer_down := false
var _press_pointer := Vector2.ZERO
var _pressed_location := ""
var _last_pointer := Vector2.ZERO
var _star_dragging := false
var _star_grab_offset := 0.0
var player_world_position := Vector2.ZERO
var player_location_id := ""
var catalog = preload("res://scripts/map/world_map_catalog.gd").new()
var locations: Dictionary = catalog.locations
var selected_location_id := ""
var _visited: Dictionary = {}
var sidebar: Control
var selection_ring: TextureRect

func _init() -> void:
	name = "WorldMap"
	z_index = 45
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage = Control.new()
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.size = Vector2(2560,1440)
	map_window = Control.new()
	map_window.name = "MapWindow"
	map_window.position = MAP_RECT.position
	map_window.size = MAP_RECT.size
	map_window.clip_contents = true
	map_window.mouse_filter = MOUSE_FILTER_STOP
	stage.add_child(map_window)
	map_window.gui_input.connect(_map_input)
	map_image = _image("res://assets/map-worldmap.webp", map_window)
	var source := map_image.texture.get_size()
	var minimum := maxf(map_window.size.x/source.x,map_window.size.y/source.y)
	zoom_levels.append(minimum)
	# Add five percentage points of the source image per notch. The final
	# shortened step lands exactly at 120%; every reverse step is symmetric.
	for step in range(1,ceili((MAX_SOURCE_ZOOM-minimum)/ZOOM_STEP)+1):
		zoom_levels.append(minf(minimum+step*ZOOM_STEP,MAX_SOURCE_ZOOM))
	for location_id: String in locations:
		var location: Dictionary = locations[location_id]
		var marker := _trimmed_image(location.marker_texture,map_window,float(location.marker_width))
		marker.name = location.name
		landmark_markers[location_id] = marker
	selection_ring = _trimmed_image("res://assets/UI-map-selected.webp",map_window,SELECTION_MARKER_WIDTH)
	selection_ring.name = "SelectedLocation"
	selection_ring.modulate.a = 0.75
	selection_ring.hide()
	location_marker = _trimmed_image("res://assets/UI-map-location.webp",map_window,LOCATION_MARKER_WIDTH)
	location_marker.name = "PlayerLocation"
	location_marker.hide()
	frame = _image("res://assets/map-worldmap-frame.webp", stage)
	frame.size = Vector2(2560,1440)
	title = _trimmed_image("res://assets/map-worldmap-title.webp",stage,400)
	var title_region: Rect2 = title.texture.region
	title.position = TITLE_CENTER+TITLE_OFFSET-(TITLE_INK_CENTER-title_region.position)*(title.size.x/title_region.size.x)
	sidebar = preload("res://scripts/map/world_map_sidebar.gd").new()
	stage.add_child(sidebar)
	_build_zoom_control()
	_build_footer()
	resized.connect(_layout)
	visibility_changed.connect(_end_drag)

func _ready() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null: settings.settings_changed.connect(_refresh_shortcut_hints)
	_refresh_shortcut_hints()

func _refresh_shortcut_hints() -> void:
	if not is_instance_valid(close_keys): return
	var current := SettingsInput.action_label("map_world_map")
	close_keys.text = "Esc" if current.is_empty() else current + "/Esc"
	close_keys.visible = bool(Settings.value("shortcut_hints", true))

func _image(path: String, parent: Control) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _trimmed_image(path: String, parent: Control, width: float) -> TextureRect:
	var image := _image(path,parent)
	var atlas := AtlasTexture.new()
	atlas.atlas = image.texture
	atlas.region = atlas.atlas.get_image().get_used_rect()
	image.texture = atlas
	image.size = Vector2(width,width*atlas.region.size.y/atlas.region.size.x)
	return image

func _build_zoom_control() -> void:
	zoom_control = Control.new()
	zoom_control.name = "ZoomControl"
	zoom_control.position = Vector2(MAP_RECT.end.x-18-SLIDER_SIZE.x,MAP_RECT.get_center().y-SLIDER_SIZE.y*0.5)
	zoom_control.size = SLIDER_SIZE
	zoom_control.mouse_filter = MOUSE_FILTER_STOP
	stage.add_child(zoom_control)
	scroll_art = _trimmed_image("res://assets/UI-map-scroll.webp",zoom_control,SLIDER_SIZE.x)
	scroll_star = _trimmed_image("res://assets/UI-map-scrollstar.webp",zoom_control,42)
	zoom_control.gui_input.connect(_slider_input)
	plus_button = _slider_button("MaximumZoom",Rect2(0,0,75,74))
	minus_button = _slider_button("MinimumZoom",Rect2(0,276,75,72.6))
	plus_button.pressed.connect(func(): _apply_zoom(map_window.size*0.5,zoom_levels.size()-1))
	minus_button.pressed.connect(func(): _apply_zoom(map_window.size*0.5,0))

func _slider_button(node_name: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = FOCUS_NONE
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	zoom_control.add_child(button)
	return button

func _build_footer() -> void:
	footer = CenterContainer.new()
	footer.name = "MapHelp"
	footer.position = Vector2(780,1353)
	footer.size = Vector2(1000,68)
	footer.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(footer)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(1000,44)
	row.add_theme_constant_override("separation",0)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	footer.add_child(row)
	var font: Font = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
	var hints := [
		["UI-map-mouse1","拖拽移动"],
		["UI-map-mouse2","滚动缩放"],
		["UI-map-mapicon","开关标识"],
		["","关闭"]
	]
	for index in hints.size():
		if index > 0:
			var separator := ColorRect.new()
			separator.color = Color("bba97b",0.8)
			separator.custom_minimum_size = Vector2(2,28)
			separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			separator.mouse_filter = MOUSE_FILTER_IGNORE
			row.add_child(separator)
		var cell := CenterContainer.new()
		cell.name = "HintCell%d" % (index+1)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(cell)
		var group := HBoxContainer.new()
		group.name = "Hint%d" % (index+1)
		group.add_theme_constant_override("separation",12)
		group.mouse_filter = MOUSE_FILTER_IGNORE
		cell.add_child(group)
		if index < 3:
			var icon := _trimmed_image("res://assets/%s.webp" % hints[index][0],group,44)
			icon.size *= 44.0/icon.size.y
			icon.custom_minimum_size = icon.size
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			close_keys = _footer_label("",font,25)
			group.add_child(close_keys)
		group.add_child(_footer_label(hints[index][1],font,27))

func _footer_label(text: String, font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e2dac6"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label

func world_position_for(map_id: String) -> Vector2:
	for location: Dictionary in locations.values():
		if not map_id.is_empty() and location.map_id == map_id:
			return Vector2(location.position[0],location.position[1])
	return map_image.texture.get_size()*0.5

func present(map_id: String = "", visited: Dictionary = {}) -> void:
	_end_drag()
	_refresh_shortcut_hints()
	_visited = visited.duplicate(true)
	show()
	_layout()
	_apply_zoom(map_window.size*0.5,maxi(0,zoom_levels.size()-3))
	player_world_position = world_position_for(map_id)
	player_location_id = catalog.location_for_map(map_id)
	location_marker.hide()
	for location: Dictionary in locations.values():
		if not map_id.is_empty() and location.map_id == map_id:
			location_marker.show()
			break
	map_image.position = map_window.size*0.5-player_world_position*zoom_levels[zoom_index]
	var current_location: String = catalog.location_for_map(map_id)
	select_location(current_location if not current_location.is_empty() else str(locations.keys()[0]))
	_clamp_map()

func select_location(location_id: String) -> void:
	if not locations.has(location_id): return
	selected_location_id = location_id
	var location: Dictionary = locations[location_id]
	sidebar.display(location,catalog.regions[location.region_id],catalog.region_progress(location.region_id,_visited))
	_sync_selection()

func _sync_selection() -> void:
	selection_ring.visible = landmark_markers.has(selected_location_id)
	if selection_ring.visible:
		selection_ring.position = landmark_markers[selected_location_id].get_rect().get_center()-selection_ring.size*0.5+Vector2(0.5,0.5)

func location_at(point: Vector2) -> String:
	if not Rect2(Vector2.ZERO,map_window.size).has_point(point): return ""
	var closest := ""
	var distance := INF
	for location_id: String in landmark_markers:
		var marker: TextureRect = landmark_markers[location_id]
		var delta := point.distance_to(marker.get_rect().get_center())
		if delta <= maxf(24,marker.size.x*0.5) and delta < distance:
			closest = location_id
			distance = delta
	return closest

func _hover_location(point: Vector2) -> void:
	var location_id := location_at(point)
	map_window.mouse_default_cursor_shape = CURSOR_POINTING_HAND if not location_id.is_empty() else CURSOR_ARROW
	map_window.tooltip_text = locations[location_id].name if not location_id.is_empty() else ""

func _layout() -> void:
	if size.x <= 0 or size.y <= 0: return
	var margin := 24.0 * minf(size.x/1920.0,size.y/1080.0)
	var header := MapStatusHeader.height_for_width(size.x)
	var area := Rect2(margin,header+4,size.x-margin*2,maxf(1,size.y-header-margin-4))
	var factor := minf(area.size.x/FRAME_BOUNDS.size.x,area.size.y/FRAME_BOUNDS.size.y)
	stage.scale = Vector2.ONE*factor
	stage.position = area.get_center()-FRAME_BOUNDS.get_center()*factor

func _apply_zoom(anchor: Vector2, next_index: int) -> void:
	if zoom_levels.is_empty(): return
	var old_size := map_image.size
	var point := (anchor-map_image.position)/old_size if old_size.x > 0 and old_size.y > 0 else Vector2(0.5,0.5)
	zoom_index = clampi(next_index,0,zoom_levels.size()-1)
	var source := map_image.texture.get_size()
	map_image.size = source*zoom_levels[zoom_index]
	map_image.position = anchor-point*map_image.size
	_clamp_map()
	_sync_star()

func _sync_star() -> void:
	var weight := float(zoom_index)/maxi(1,zoom_levels.size()-1)
	var center := Vector2(SLIDER_SIZE.x*0.5,lerpf(TRACK_BOTTOM,TRACK_TOP,weight))
	scroll_star.position = center-scroll_star.size*0.5

func _set_slider_y(y: float) -> void:
	var weight := clampf((TRACK_BOTTOM-y)/(TRACK_BOTTOM-TRACK_TOP),0.0,1.0)
	_apply_zoom(map_window.size*0.5,roundi(weight*(zoom_levels.size()-1)))

func _slider_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_star_dragging = event.pressed
			if event.pressed:
				_star_grab_offset = event.position.y-scroll_star.get_rect().get_center().y if scroll_star.get_rect().grow(5).has_point(event.position) else 0.0
				_set_slider_y(event.position.y-_star_grab_offset)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_apply_zoom(map_window.size*0.5,zoom_index+SettingsInput.wheel_step(event.button_index))
		zoom_control.accept_event()
	elif event is InputEventMouseMotion and _star_dragging:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_end_drag()
			return
		_set_slider_y(event.position.y-_star_grab_offset)
		zoom_control.accept_event()

func _clamp_map() -> void:
	for axis in 2:
		map_image.position[axis] = clampf(map_image.position[axis],minf(0,map_window.size[axis]-map_image.size[axis]),0)
	for location_id: String in landmark_markers:
		var location: Dictionary = locations[location_id]
		var marker: TextureRect = landmark_markers[location_id]
		var point := Vector2(location.position[0],location.position[1])
		marker.position = map_image.position+point*zoom_levels[zoom_index]-marker.size*0.5
	# Fixed UI size: the pointer sits above the actual location, not the browsed one.
	if landmark_markers.has(player_location_id):
		var current_marker: TextureRect = landmark_markers[player_location_id]
		location_marker.position = Vector2(current_marker.get_rect().get_center().x-location_marker.size.x*0.5+0.5,current_marker.position.y-LOCATION_MARKER_GAP-location_marker.size.y)
	_sync_selection()

func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pointer_down = true
				dragging = false
				_press_pointer = event.position
				_last_pointer = event.position
				_pressed_location = location_at(event.position)
			else:
				if _pointer_down and not dragging and not _pressed_location.is_empty() and location_at(event.position) == _pressed_location:
					select_location(_pressed_location)
				_end_drag()
				_hover_location(event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_pressed_location = ""
			if Rect2(Vector2.ZERO,map_window.size).has_point(event.position):
				_apply_zoom(event.position,zoom_index+SettingsInput.wheel_step(event.button_index))
				_hover_location(event.position)
		map_window.accept_event()
	elif event is InputEventMouseMotion and _pointer_down:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_end_drag()
			return
		if not dragging:
			if event.position.distance_to(_press_pointer)*stage.scale.x <= CLICK_SLOP_PIXELS: return
			dragging = true
			map_window.mouse_default_cursor_shape = CURSOR_DRAG
			map_window.tooltip_text = ""
		map_image.position += event.position-_last_pointer
		_last_pointer = event.position
		_clamp_map()
		map_window.accept_event()
	elif event is InputEventMouseMotion:
		_hover_location(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_end_drag()

func _end_drag() -> void:
	dragging = false
	_pointer_down = false
	_pressed_location = ""
	_star_dragging = false
	if map_window != null:
		map_window.mouse_default_cursor_shape = CURSOR_ARROW
		map_window.tooltip_text = ""
