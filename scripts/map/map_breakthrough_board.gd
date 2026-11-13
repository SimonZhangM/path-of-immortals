extends MapLoadoutBoard
## Shared item rendering and hover descriptions; all equipment edits stay disabled.
var session: RefCounted
var cooldown_overlay: Control
var _cooldowns: Dictionary = {}
var _cooldown_at_usec := 0
const CD_DESIGN_SCALE := 2560.0 / 1920.0

func configure(model: MapLoadoutState) -> void:
	super.configure(model)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	cooldown_overlay = Control.new()
	cooldown_overlay.name = "CooldownOverlay"
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.z_index = 2
	add_child(cooldown_overlay)
	cooldown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown_overlay.draw.connect(_draw_cooldowns)

func bind_session(value: RefCounted) -> void:
	session = value
	session.changed.connect(_refresh_cooldowns)
	_refresh_cooldowns()

func _refresh_cooldowns() -> void:
	var run: RefCounted = session.runtime
	_cooldowns = run.cooldown_snapshot() if run!=null else {}
	_cooldown_at_usec = run.elapsed_usec() if run!=null else 0
	refresh_cooldown_animation()

func refresh_cooldown_animation() -> void:
	if cooldown_overlay!=null: cooldown_overlay.queue_redraw()

func cooldown_state(id: String) -> Dictionary:
	var entry := state.inventory.get_instance(id)
	if entry.is_empty(): return {}
	var item := state.registry.get_item(entry.item_id)
	if not _cooldowns.has(id):
		return {"entry":0.0,"remaining":float(0 if item.combat.get("first_ready",false) else item.cooldown_usec),"duration":item.cooldown_usec}
	var current: Dictionary = _cooldowns[id].duplicate()
	var offset := 0.0
	if session!=null and session.runtime!=null:
		offset=maxf(0.0,float(session.runtime.presentation_usec()-_cooldown_at_usec))
	var work := offset*float(current.speed)
	var entry_work := minf(float(current.entry),work)
	current.entry=maxf(0.0,float(current.entry)-entry_work)
	current.remaining=maxf(0.0,float(current.remaining)-(work-entry_work))
	return current

func _draw_cooldowns() -> void:
	if state==null: return
	# Battle is authored at 1080p; this screen uses a 1440p design canvas.
	cooldown_overlay.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*CD_DESIGN_SCALE)
	for entry: Dictionary in state.inventory.get_instances():
		var item := state.registry.get_item(entry.item_id)
		var cd := cooldown_state(entry.instance_id)
		var footprint := layout.footprint_rect(entry.cell,item.grid_size,size)
		var rect := Rect2(footprint.position/CD_DESIGN_SCALE,footprint.size/CD_DESIGN_SCALE).grow(-4)
		var center := InventoryView.rotation_ring_center(rect,item)
		if float(cd.entry)>0:
			CooldownRing.paint_text(cooldown_overlay,center,str(ceili(float(cd.entry)/1000000.0)),32)
		elif float(cd.duration)>0:
			CooldownRing.paint(cooldown_overlay,center,23,float(cd.remaining)/1000000.0,float(cd.duration)/1000000.0,CooldownRing.tint(state.registry,item.element))
	cooldown_overlay.draw_set_transform(Vector2.ZERO)

func _ready() -> void:
	super()

func recovery_origin(event: Dictionary) -> Vector2:
	var entry := state.inventory.get_instance(str(event.get("instance_id","")))
	if entry.is_empty(): entry=event.get("entry",{})
	if entry.is_empty(): return Vector2.INF
	var item := state.registry.get_item(str(entry.get("item_id","")))
	if item==null: return Vector2.INF
	var center := layout.footprint_rect(entry.cell,item.grid_size,size).get_center()
	return get_global_transform_with_canvas()*center

func _gui_input(_event: InputEvent) -> void:
	pass

func cursor_hover_state(_point: Vector2) -> int:
	return GameCursorManager.State.NORMAL

func _begin_drag(_data: Dictionary) -> void:
	pass

func _can_drop_data(_point: Vector2, _data: Variant) -> bool:
	return false

func _drop_data(_point: Vector2, _data: Variant) -> void:
	pass

func can_request_board_change(_data: Variant) -> bool:
	return false
