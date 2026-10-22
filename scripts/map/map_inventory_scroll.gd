extends ScrollContainer
## Two wheel notches advance one card row, independent of viewport scaling.
var _wheel_target := 0.0
var _last_scroll := -1

func row_pitch() -> float:
	if get_child_count() == 0: return 0.0
	var grid := get_child(0) as Container
	if grid == null or grid.get_child_count() == 0: return 0.0
	var card := grid.get_child(0) as Control
	return card.size.y + grid.get_theme_constant("v_separation")

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventMouseButton or not event.pressed: return
	if event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return
	# Do not capture wheel input from a tooltip/modal laid over this area.
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null or (hovered != self and not is_ancestor_of(hovered)): return
	if not get_global_rect().has_point(event.position): return
	var pitch := row_pitch()
	if pitch <= 0: return
	if _last_scroll != scroll_vertical: _wheel_target = scroll_vertical
	var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0
	var factor: float = event.factor if event.factor > 0 else 1.0
	var bar := get_v_scroll_bar()
	var limit := maxf(0, bar.max_value - bar.page)
	_wheel_target = clampf(_wheel_target + direction * pitch * 0.5 * factor, 0, limit)
	scroll_vertical = roundi(_wheel_target)
	_last_scroll = scroll_vertical
	# Stop native ScrollContainer handling from applying a second, fixed step.
	get_viewport().set_input_as_handled()
