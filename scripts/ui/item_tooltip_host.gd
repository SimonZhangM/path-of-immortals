class_name ItemTooltipHost
extends CanvasLayer
signal technique_requested(book_id: String)
## One interactive item tooltip per viewport; presentation only.
const SOURCE_META := &"item_tooltip_source"
const HOVER_DELAY := 0.45
const LEAVE_DELAY := 0.25
var tooltip: ItemTooltip
var source: Control
var source_key := ""
var selected_card: Control
var pinned := false
var _pointer := Vector2.ZERO
var _candidate: Control
var _candidate_key := ""
var _hover_time := 0.0
var _leave_time := 0.0
var _suppressed: Control
var _anchor := Vector2.ZERO
var _awaiting_layout := false

static func for_control(control: Control) -> ItemTooltipHost:
	var viewport := control.get_viewport()
	var existing: Variant = viewport.get_meta(SOURCE_META) if viewport.has_meta(SOURCE_META) else null
	if is_instance_valid(existing): return existing
	var host := ItemTooltipHost.new()
	host.name = "ItemTooltipHost"
	host.layer = 110
	viewport.set_meta(SOURCE_META, host)
	viewport.add_child.call_deferred(host)
	return host

static func bind(control: Control, key_at: Callable, builder: Callable) -> void:
	# This host owns item tooltips. Do not leave a second native tooltip source.
	control.tooltip_text = ""
	control.set_meta(SOURCE_META, {"key_at":key_at, "builder":builder})
	for_control(control)

func select_card(card: Control) -> void:
	var same_card := selected_card == card
	if is_instance_valid(selected_card) and selected_card != card:
		selected_card.set_selected(false)
	selected_card = card
	card.set_selected(true)
	# Outside-click dismissal runs before the card's GUI input. A second click
	# on the same selected card must not rearm the tooltip immediately.
	if not same_card: _suppressed = null
	if source == card and is_instance_valid(tooltip): pinned = true

func dismiss(suppress_reopen := true) -> void:
	if suppress_reopen: _suppressed = source
	if is_instance_valid(tooltip):
		tooltip.hide()
		tooltip.queue_free()
	tooltip = null
	_awaiting_layout = false
	source = null
	source_key = ""
	pinned = false
	_hover_time = 0.0
	_leave_time = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouse: _pointer = event.position
	if not is_instance_valid(tooltip): return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if not _awaiting_layout and tooltip.get_global_rect().has_point(event.position):
			if event.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(tooltip.details_button) and tooltip.details_button.get_global_rect().has_point(event.position): return
			# Prevent the battle/map outside-right-click handler closing its panel.
			get_viewport().set_input_as_handled()
		elif event.pressed:
			dismiss()
	# Outside dismissal does not replace the clicked control's usual command.

func _hover_source() -> Control:
	var node: Node = get_viewport().gui_get_hovered_control()
	while node != null:
		if node is Control and node.has_meta(SOURCE_META): return node
		node = node.get_parent()
	return null

func _process(delta: float) -> void:
	if get_viewport().gui_is_dragging():
		dismiss()
		_candidate = null
		return
	if is_instance_valid(tooltip):
		if not is_instance_valid(source) or not source.is_visible_in_tree():
			dismiss(false)
		else:
			if _awaiting_layout: return
			_fit()
			if pinned or tooltip.get_global_rect().has_point(_pointer):
				_leave_time = 0.0
				return
	var hovered := _hover_source()
	if hovered != _suppressed: _suppressed = null
	var key := ""
	if is_instance_valid(hovered) and hovered.is_visible_in_tree():
		var local := hovered.get_global_transform_with_canvas().affine_inverse() * _pointer
		key = str(hovered.get_meta(SOURCE_META).key_at.call(local))
	if hovered == source and key == source_key and not key.is_empty():
		_leave_time = 0.0
		return
	if is_instance_valid(tooltip):
		_leave_time += delta
		if _leave_time >= LEAVE_DELAY: dismiss(false)
	if hovered != _candidate or key != _candidate_key:
		_candidate = hovered
		_candidate_key = key
		_hover_time = 0.0
	if not is_instance_valid(hovered) or key.is_empty() or hovered == _suppressed: return
	_hover_time += delta
	if _hover_time >= HOVER_DELAY and not is_instance_valid(tooltip):
		_show(hovered, key)

func _show(control: Control, key: String) -> void:
	var built: Variant = control.get_meta(SOURCE_META).builder.call(key)
	if not built is ItemTooltip: return
	if is_instance_valid(tooltip): dismiss(false)
	# _input runs in reverse tree order. A newly loaded scene must not process
	# a click inside this overlay as an outside click on its storage panel.
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	tooltip = built
	tooltip.technique_requested.connect(func(book_id: String):
		dismiss()
		technique_requested.emit(book_id))
	source = control
	source_key = key
	pinned = selected_card == control and control.get("selected") == true
	# Containers and system fonts settle after entering the tree. Keep the
	# new panel transparent and offscreen (also outside mouse hit testing)
	# until its final size is known; never render its provisional position.
	_awaiting_layout = true
	tooltip.modulate.a = 0.0
	tooltip.position = Vector2(-100000, -100000)
	add_child(tooltip)
	var rect := control.get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	var left := rect.position.x - ItemTooltip.WIDTH - 12.0
	_anchor.x = left if left >= 8.0 else rect.end.x + 12.0
	if _anchor.x + ItemTooltip.WIDTH > screen.x - 8.0: _anchor.x = _pointer.x + 20.0
	_anchor.y = minf(_pointer.y - 20.0, screen.y - tooltip.get_combined_minimum_size().y - 190.0)
	_reveal_after_layout(tooltip)

func _reveal_after_layout(panel: ItemTooltip) -> void:
	var previous := PackedVector2Array()
	var stable_frames := 0
	while is_instance_valid(panel) and tooltip == panel:
		await get_tree().process_frame
		# Closing or changing the source during preparation invalidates this job.
		if not is_instance_valid(panel) or tooltip != panel: return
		if not is_instance_valid(source) or not source.is_visible_in_tree():
			dismiss(false)
			return
		var minimum := panel.get_combined_minimum_size()
		if not panel.size.is_equal_approx(minimum): panel.reset_size()
		var core := panel.find_child("SummaryPanel", true, false) as Control
		var geometry := PackedVector2Array([minimum, panel.size, core.size if core != null else panel.size])
		stable_frames = stable_frames + 1 if geometry == previous else 0
		previous = geometry
		if stable_frames < 2: continue
		_fit()
		_awaiting_layout = false
		panel.modulate.a = 1.0
		return

func _fit() -> void:
	var minimum := tooltip.get_combined_minimum_size()
	if not tooltip.size.is_equal_approx(minimum): tooltip.reset_size()
	var screen := get_viewport().get_visible_rect().size
	if source is MapInventoryItemCard:
		# Use the card's canvas-space bounds and the laid-out core, not the
		# pointer or an initial (pre-container-layout) tooltip height.
		var rect := source.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, source.size)
		var right := rect.end.x + 12.0
		_anchor.x = right if right + tooltip.size.x <= screen.x - 8.0 else rect.position.x - tooltip.size.x - 12.0
		var core := tooltip.find_child("SummaryPanel", true, false) as Control
		var core_height := core.size.y if core != null else tooltip.size.y
		_anchor.y = rect.position.y - core_height * 0.6
	tooltip.position = Vector2(clampf(_anchor.x, 8.0, maxf(8.0, screen.x-tooltip.size.x-8.0)), clampf(_anchor.y, 8.0, maxf(8.0, screen.y-tooltip.size.y-8.0)))
