extends Control
## Data-driven vertical entry rail; its anchor never follows the map camera.
signal entry_requested(action: String)
signal collapsed_changed(collapsed: bool)
const State = preload("res://scripts/map/map_shortcut_state.gd")
const RoundButton = preload("res://scripts/map/map_shortcut_button.gd")
var buttons: Dictionary = {}
var toggle_button: Button
var tooltip: Control
var hover_timer: Timer
var collapsed := false
var _hovered := ""
var _visible_ids: Array = []
var _motion: Tween
var _animating := false

func _ready() -> void:
	name="MapShortcutBar"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for entry: Dictionary in State.config.entries: add_entry(entry)
	toggle_button=RoundButton.new()
	toggle_button.toggle=true
	toggle_button.size=Vector2.ONE*float(State.config.toggle_diameter)
	add_child(toggle_button)
	toggle_button.pressed.connect(func():
		set_collapsed(not collapsed,true)
		collapsed_changed.emit(collapsed))
	hover_timer=Timer.new()
	hover_timer.one_shot=true
	hover_timer.wait_time=float(State.config.tooltip_delay)
	add_child(hover_timer)
	hover_timer.timeout.connect(_show_hint)
	tooltip=preload("res://scripts/map/map_shortcut_tooltip.gd").new()
	add_child(tooltip)
	resized.connect(_layout)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): dismiss_hint())
	_layout()

func add_entry(entry: Dictionary) -> void:
	if buttons.has(entry.id): return
	var button := RoundButton.new()
	button.name=entry.id.get_slice(".",2)
	button.art=load(entry.icon)
	button.red_dot=load(State.config.red_dot)
	button.size=Vector2.ONE*float(State.config.icon_diameter)
	button.set_meta("entry",entry.duplicate(true))
	add_child(button)
	buttons[entry.id]=button
	button.pressed.connect(func():
		if _animating: return
		dismiss_hint()
		entry_requested.emit(entry.action))
	button.mouse_entered.connect(func():
		if _animating or collapsed: return
		dismiss_hint()
		_hovered=entry.id
		hover_timer.start())
	button.mouse_exited.connect(func():
		if _hovered==entry.id: dismiss_hint())

func refresh(record: Dictionary) -> void:
	var ids: Array = []
	for id: String in buttons:
		var button: Button=buttons[id]
		if id in record.get("unlocked",[]): ids.append(id)
		button.unread=id in record.get("unread",[])
		button.queue_redraw()
	if ids!=_visible_ids:
		_visible_ids=ids
		dismiss_hint()
		_layout()
	if collapsed!=bool(record.get("collapsed",false)): set_collapsed(record.collapsed,false)

func set_collapsed(value: bool, animate: bool) -> void:
	collapsed=value
	dismiss_hint()
	if _motion!=null: _motion.kill()
	_animating=animate and is_visible_in_tree()
	toggle_button.collapsed=value
	toggle_button.queue_redraw()
	if not _animating:
		_layout()
		return
	_motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var factor := _factor()
	var anchor := _anchor()
	for id: String in buttons:
		var button: Control=buttons[id]
		if id not in _visible_ids:
			button.hide()
			continue
		button.show()
		button.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var index := _visible_ids.find(id)
		var center := anchor if value else _entry_center(index)
		_motion.tween_property(button,"position",center-button.size*factor*0.5,0.24)
		_motion.tween_property(button,"modulate:a",0.0 if value else 1.0,0.24)
	_motion.tween_property(toggle_button,"position",_toggle_center()-toggle_button.size*factor*0.5,0.24)
	_motion.finished.connect(func():
		_animating=false
		_layout())

func _factor() -> float:
	return minf(size.x/1920.0,size.y/1080.0)

func _anchor() -> Vector2:
	var factor := _factor()
	return Vector2(float(State.config.left_center)*factor,size.y-float(State.config.bottom_center)*factor)

func _entry_center(index: int) -> Vector2:
	return _anchor()-Vector2(0,(_visible_ids.size()-1-index)*float(State.config.icon_step)*_factor())

func _toggle_center() -> Vector2:
	if collapsed: return _anchor()
	return _entry_center(0)-Vector2(0,58*_factor())

func _layout() -> void:
	if toggle_button==null: return
	if _motion!=null: _motion.kill()
	_animating=false
	var factor := _factor()
	for id: String in buttons:
		var button: Control=buttons[id]
		button.scale=Vector2.ONE*factor
		button.visible=id in _visible_ids and not collapsed
		button.modulate.a=0.0 if collapsed else 1.0
		button.mouse_filter=Control.MOUSE_FILTER_STOP
		button.position=(_anchor() if collapsed else _entry_center(_visible_ids.find(id)))-button.size*factor*0.5
	toggle_button.scale=Vector2.ONE*factor
	toggle_button.position=_toggle_center()-toggle_button.size*factor*0.5
	toggle_button.visible=not _visible_ids.is_empty()
	if tooltip!=null:
		tooltip.scale=Vector2.ONE*factor
		dismiss_hint()

func dismiss_hint() -> void:
	_hovered=""
	if hover_timer!=null: hover_timer.stop()
	if tooltip!=null: tooltip.hide()

func _show_hint() -> void:
	if _hovered.is_empty() or collapsed or _animating or not is_visible_in_tree(): return
	var button: Control=buttons[_hovered]
	if not button.is_visible_in_tree(): return
	tooltip.present(button.get_meta("entry"))
	var center := button.position+button.size*button.scale*0.5
	var factor := _factor()
	tooltip.position = Vector2(
		center.x + (float(State.config.icon_diameter) * 0.5 + 10) * factor,
		center.y - tooltip.POINTER_CENTER.y * factor)
	tooltip.position.y = clampf(tooltip.position.y, 4 * factor, size.y - (tooltip.size.y + 4) * factor)
