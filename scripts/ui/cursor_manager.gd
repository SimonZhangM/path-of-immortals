class_name GameCursorManager
extends Node
## Presentation only. Hit testing and drop permissions belong to the controls.
enum State { NORMAL, INTERACT, DRAG_READY, DRAGGING, FORBIDDEN }
const Settings = preload("res://scripts/settings/game_settings.gd")
const SHAPES := [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_CAN_DROP,
	Input.CURSOR_DRAG, Input.CURSOR_FORBIDDEN, Input.CURSOR_MOVE]
const CONFIG_PATH := "res://data/ui/cursors.json"
var current_state: State = State.NORMAL
var custom_enabled := true
var size_name := "normal"
var registration_count := 0
var _textures: Dictionary = {}
var _hotspots: Dictionary = {}
var _registered_state := -1
var _drag_owner: WeakRef
var _native_drag := false
var _focused := true
var _popups: Array[WeakRef] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	_build_resources()
	get_node("/root/GameSettings").settings_changed.connect(_settings_changed)
	get_tree().node_added.connect(_bind_control)
	_bind_tree(get_tree().root)
	_settings_changed()

func _build_resources() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	for label: String in config.sizes:
		var textures: Array[Texture2D] = []
		var hotspots: Array[Vector2] = []
		var side := int(config.sizes[label])
		for entry: Dictionary in config.states:
			var texture := load(str(entry.texture)) as Texture2D
			if texture == null:
				push_warning("Cursor texture unavailable: " + str(entry.texture))
				return
			var image := texture.get_image()
			if image.is_compressed(): image.decompress()
			var scale_factor := float(side) / image.get_width()
			image.resize(side, side, Image.INTERPOLATE_LANCZOS)
			textures.append(ImageTexture.create_from_image(image))
			hotspots.append((Vector2(entry.hotspot[0], entry.hotspot[1]) * scale_factor).round())
		_textures[label] = textures
		_hotspots[label] = hotspots

func texture_for(state: State, size_key := "normal") -> Texture2D:
	return _textures[size_key][state] if _textures.has(size_key) else null

func hotspot_for(state: State, size_key := "normal") -> Vector2:
	return _hotspots[size_key][state] if _hotspots.has(size_key) else Vector2.ZERO

func _bind_tree(node: Node) -> void:
	_bind_control(node)
	for child in node.get_children(): _bind_tree(child)

func _bind_control(node: Node) -> void:
	if node is PopupMenu:
		_popups.append(weakref(node))
		node.about_to_popup.connect(cancel_drag)
	elif node is Slider:
		node.drag_started.connect(func(): begin_drag(node, false))
		node.drag_ended.connect(func(_changed: bool): end_drag(node))

func _settings_changed() -> void:
	set_cursor_size(str(Settings.value("cursor_size", "normal")))
	set_custom_cursor_enabled(bool(Settings.value("custom_cursor", true)))

func set_cursor_size(value: String) -> void:
	if value not in ["normal", "large"] or size_name == value: return
	size_name = value
	_registered_state = -1
	refresh_state()

func set_custom_cursor_enabled(value: bool) -> void:
	custom_enabled = value
	if not value:
		_restore_system()
	else:
		refresh_state()

func begin_drag(owner: Control, native := true) -> void:
	_drag_owner = weakref(owner)
	_native_drag = native
	# force_drag / _get_drag_data may still be returning to Godot's dispatcher.
	refresh_state.call_deferred()

func end_drag(owner: Control) -> void:
	if _drag_owner != null and _drag_owner.get_ref() == owner:
		_drag_owner = null
		_native_drag = false
	refresh_state.call_deferred()

func cancel_drag() -> void:
	var owner: Object = _drag_owner.get_ref() if _drag_owner != null else null
	if _native_drag and get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
	elif is_instance_valid(owner) and owner.has_method("cursor_cancel_drag"):
		owner.call("cursor_cancel_drag")
	_drag_owner = null
	_native_drag = false
	refresh_state.call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_drag()
	if event is InputEventMouse or event is InputEventKey:
		refresh_state.call_deferred()

func _notification(what: int) -> void:
	if not is_inside_tree(): return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		cancel_drag()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		refresh_state.call_deferred()

func _process(_delta: float) -> void:
	# Only query the actual topmost hovered control. This also refreshes business
	# permissions beneath a stationary pointer, without scanning scene items.
	refresh_state()

func refresh_state() -> void:
	if not is_inside_tree(): return
	var hovered := get_viewport().gui_get_hovered_control()
	var next := State.NORMAL
	if _focused:
		if _drag_owner != null:
			var owner := _drag_owner.get_ref() as Control
			var valid := is_instance_valid(owner) and owner.is_inside_tree() and owner.is_visible_in_tree()
			if valid and _native_drag and owner.has_method("cursor_drag_is_valid"):
				valid = bool(owner.call("cursor_drag_is_valid", get_viewport().gui_get_drag_data()))
			if not valid:
				cancel_drag()
			elif _native_drag and not get_viewport().gui_is_dragging():
				_drag_owner = null
				_native_drag = false
		if _drag_owner != null:
			next = State.DRAGGING
			if _native_drag and drop_state_for(hovered, get_viewport().gui_get_drag_data()) == 0:
				next = State.FORBIDDEN
		else:
			next = hover_state_for(hovered)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and press_feedback_for(hovered):
				next = State.DRAGGING
			var popup_state := _popup_state()
			if popup_state >= 0: next = popup_state as State
	current_state = next
	_apply_state()

func press_feedback_for(control: Control) -> bool:
	var node: Node = control
	while node is Control:
		if node.has_method("cursor_press_feedback_enabled"):
			return bool(node.call("cursor_press_feedback_enabled", node.get_local_mouse_position()))
		node = node.get_parent()
	return false

func hover_state_for(control: Control) -> State:
	var node: Node = control
	while node is Control:
		if not node.is_visible_in_tree(): return State.NORMAL
		if node.has_meta("cursor_hover"):
			var provider: Callable = node.get_meta("cursor_hover")
			if provider.is_valid(): return int(provider.call(node.get_local_mouse_position())) as State
		if node.has_method("cursor_hover_state"):
			return int(node.call("cursor_hover_state", node.get_local_mouse_position())) as State
		if node is BaseButton:
			return State.FORBIDDEN if node.disabled else State.INTERACT
		if node is LineEdit or node is TextEdit: return State.NORMAL
		if node is Slider: return State.DRAG_READY if node.editable else State.FORBIDDEN
		match node.mouse_default_cursor_shape:
			Control.CURSOR_POINTING_HAND: return State.INTERACT
			Control.CURSOR_CAN_DROP: return State.DRAG_READY
			Control.CURSOR_FORBIDDEN: return State.FORBIDDEN
		if node.mouse_filter == Control.MOUSE_FILTER_STOP: return State.NORMAL
		node = node.get_parent()
	return State.NORMAL

func drop_state_for(control: Control, data: Variant) -> int:
	var node: Node = control
	while node is Control:
		if node.has_meta("cursor_drop_allowed"):
			var provider: Callable = node.get_meta("cursor_drop_allowed")
			if provider.is_valid(): return int(bool(provider.call(node.get_local_mouse_position(), data)))
		if node.has_method("cursor_drop_state"):
			return int(node.call("cursor_drop_state", node.get_local_mouse_position(), data))
		if node.mouse_filter == Control.MOUSE_FILTER_STOP: break
		node = node.get_parent()
	# A background is not a declared drop target; Godot still owns actual drops.
	return -1

func _popup_state() -> int:
	for index in range(_popups.size()-1, -1, -1):
		var popup := _popups[index].get_ref() as PopupMenu
		if not is_instance_valid(popup):
			_popups.remove_at(index)
			continue
		if not popup.visible or not Rect2(Vector2.ZERO, popup.size).has_point(popup.get_mouse_position()): continue
		var item := popup.get_focused_item()
		if item < 0 or popup.is_item_separator(item): return State.NORMAL
		return State.FORBIDDEN if popup.is_item_disabled(item) else State.INTERACT
	return -1

func _apply_state() -> void:
	if not custom_enabled or _registered_state == current_state: return
	var texture := texture_for(current_state, size_name)
	if texture == null:
		_restore_system()
		return
	if DisplayServer.get_name() != "headless":
		for shape in SHAPES:
			Input.set_custom_mouse_cursor(texture, shape, hotspot_for(current_state, size_name))
	_registered_state = current_state
	registration_count += 1

func _restore_system() -> void:
	if _registered_state < 0: return
	if DisplayServer.get_name() != "headless":
		for shape in SHAPES: Input.set_custom_mouse_cursor(null, shape)
	_registered_state = -1

func _exit_tree() -> void:
	_restore_system()
