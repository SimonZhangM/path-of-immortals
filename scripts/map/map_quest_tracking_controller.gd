extends Node
## UI commands persist tracking through the same candidate-save-publish boundary.
var map: Control
var tracker: Control
var markers: Node2D
var _marker_signature := ""
var last_error := ""
var navigation = preload("res://scripts/quests/quest_navigation.gd").new()

func _ready() -> void:
	tracker = preload("res://scripts/map/map_task_tracker.gd").new()
	map.add_child(tracker)
	markers = Node2D.new()
	markers.name = "QuestTargetMarkers"
	markers.z_index = 15
	map.content.add_child(markers)
	tracker.hide_requested.connect(func(): set_shown(false))
	tracker.list_requested.connect(func():
		if available(): map.set_task_open(true))
	tracker.locate_requested.connect(func(entry: Dictionary):
		if available(): locate(entry))
	map.status_header.tasks_button.pressed.connect(toggle_shown)
	map.loadout.changed.connect(refresh)
	map.resized.connect(_layout)
	map.get_node("/root/GameSettings").settings_changed.connect(_hint)
	_hint()
	refresh()
	_layout()

func _hint() -> void:
	map.status_header.tasks_button.tooltip_text = preload("res://scripts/settings/settings_input.gd").caption("任务追踪","map_task_tracker")

func available() -> bool:
	if not map.can_save_timed_checkpoint(): return false
	var focus := map.get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	# Explicit protection also covers view-only dialogs without an event phase.
	for view in [map.dialogue,map.reward_dialog,map.chest_dialog,map.chest_observation_dialog,map.gathering_dialog,map.gathering_result,map.gathering_animation,map.rest_dialog,map.cultivation_dialog,map.cultivation_progress_dialog,map.shop_dialog,map.clinic_dialog,map.inn_dialog,map.encounter_dialog]:
		if is_instance_valid(view) and view.is_visible_in_tree(): return false
	return true

func _sync_visibility() -> void:
	tracker.visible = bool(map.loadout.quest_tracking.shown)

func set_shown(shown: bool) -> void:
	if not available() or map.loadout.quest_tracking.shown==shown: return
	var next: Dictionary = map.loadout.quest_tracking.duplicate(true)
	next.shown = shown
	last_error = QuestTracking.commit(map.loadout,next,map.inventory_save_path)
	if not last_error.is_empty(): push_warning(last_error)
	_sync_visibility()

func toggle_shown() -> void:
	set_shown(not map.loadout.quest_tracking.shown)

func toggle_task(id: String) -> void:
	if not map.is_task_open(): return
	var result := QuestTracking.toggle(map.loadout.quest_tracking,id,QuestTracking.entries(map.loadout))
	last_error = result.error
	if last_error.is_empty(): last_error = QuestTracking.commit(map.loadout,result.tracking,map.inventory_save_path)
	map.task_screen.detail_body.set_tracking_error(last_error)

func refresh() -> void:
	var entries := QuestTracking.ordered(map.loadout.quest_tracking,QuestTracking.entries(map.loadout))
	tracker.display(entries)
	_sync_visibility()
	var targets := []
	for entry: Dictionary in entries: targets.append_array(navigation.markers_for(entry,map.definition.id))
	var signature := JSON.stringify(targets)
	if signature!=_marker_signature:
		_marker_signature = signature
		_refresh_markers(targets)
	_layout.call_deferred()

func _layout() -> void:
	var factor: float = minf(map.size.x/1920.0,map.size.y/1080.0)
	tracker.scale = Vector2.ONE*factor
	tracker.maximum_height = maxf(376,(map.size.y-MapStatusHeader.height_for_width(map.size.x))/factor-32)
	tracker.position = Vector2(map.size.x-(404+16)*factor,MapStatusHeader.height_for_width(map.size.x)+16*factor)

func _refresh_markers(targets: Array) -> void:
	for child in markers.get_children():
		markers.remove_child(child)
		child.queue_free()
	var seen := {}
	for target: Dictionary in targets:
		if target.map_id!=map.definition.id or not map.travel.node_positions.has(target.point_id) or seen.has(target.point_id): continue
		seen[target.point_id] = true
		var anchor := Node2D.new()
		anchor.name = target.point_id.replace(".","_")
		anchor.set_meta("point_id",target.point_id)
		anchor.position = map.travel.node_positions[target.point_id]
		markers.add_child(anchor)
		var art := TextureRect.new()
		var texture: Texture2D = load("res://assets/UI-task-right-map-location.webp")
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = texture.get_image().get_used_rect()
		art.texture = atlas
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.size = Vector2(44,44*atlas.region.size.y/atlas.region.size.x)
		art.position = Vector2(-22,-art.size.y-24)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		anchor.add_child(art)
		var tween := art.create_tween().set_loops()
		tween.tween_property(art,"position:y",art.position.y-7,0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(art,"position:y",art.position.y,0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func point_at_marker(pointer: Vector2) -> String:
	# Forward pointer artwork clicks to the same route-node interaction, including
	# the normal arrival-then-click rule. Include map pan/zoom and UI transforms.
	var canvas_point: Vector2 = map.get_global_transform_with_canvas()*pointer
	for anchor: Node2D in markers.get_children():
		var art := anchor.get_child(0) as Control
		if art.is_visible_in_tree() and Rect2(Vector2.ZERO,art.size).has_point(art.get_global_transform_with_canvas().affine_inverse()*canvas_point):
			return str(anchor.get_meta("point_id"))
	return ""

func locate_selected(id: String) -> void:
	if not map.is_task_open(): return
	for entry: Dictionary in QuestTracking.entries(map.loadout):
		if entry.id==id: locate(entry)

func locate(entry: Dictionary) -> void:
	var targets := QuestTracking.targets(entry)
	if targets.is_empty(): return
	var local := []
	for target: Dictionary in navigation.markers_for(entry,map.definition.id):
		if target.map_id==map.definition.id and map.travel.node_positions.has(target.point_id): local.append(target)
	if map.is_task_open(): map.set_task_open(false)
	if not local.is_empty():
		# Several valid gathering nodes: center on the nearest without walking.
		local.sort_custom(func(a: Dictionary,b: Dictionary):
			return map.player.position.distance_squared_to(map.travel.node_positions[a.point_id])<map.player.position.distance_squared_to(map.travel.node_positions[b.point_id]))
		var point: Vector2 = map.travel.node_positions[local[0].point_id]
		var area: Rect2 = map.map_viewport.get_rect()
		if tracker.visible:
			area.size.x = maxf(1,tracker.position.x-area.position.x-12*tracker.scale.x)
		map.content.position = area.get_center()-map.map_viewport.position-point*map.content.scale
		map._clamp_position()
		map._end_drag()
		return
	# An explicitly suppressed local target must not redirect to the world map.
	for target: Dictionary in targets:
		if target.map_id==map.definition.id: return
	map.set_world_map_open(true)
	if map.is_world_map_open(): map.world_map.show_quest_targets(targets)
