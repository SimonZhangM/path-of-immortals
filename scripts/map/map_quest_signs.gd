extends RefCounted
## Temporary story overlays leave each authored sign and its animation intact.
var entries := {}
var motion: MapSignMotion

func configure(points: Node, sign_motion: MapSignMotion) -> void:
	motion = sign_motion
	for point: MapRoutePoint in points.get_children():
		entries[point.point_id] = {"point":point,"original":point.get_node_or_null("Sign"),"overlay":null,"was_visible":true}

func show_at(point_ids: Array[String], optional_point_ids: Array[String] = []) -> void:
	for id: String in entries:
		var entry: Dictionary = entries[id]
		var show_story := id in point_ids
		var optional := id in optional_point_ids
		if show_story and entry.overlay!=null and entry.overlay.get_meta("optional",false)!=optional:
			motion.unregister_story_sign(id,entry.overlay)
			entry.point.remove_child(entry.overlay)
			entry.overlay.queue_free()
			entry.overlay = null
			if entry.original!=null: entry.original.visible = entry.was_visible
		if show_story and entry.overlay==null:
			entry.overlay = _make_sign(optional)
			entry.point.add_child(entry.overlay)
			entry.overlay.hide()
			motion.register_story_sign(id, entry.overlay)
		if entry.overlay==null: continue
		if show_story and not entry.overlay.visible:
			if entry.original!=null:
				entry.was_visible = entry.original.visible
				entry.original.hide()
			entry.overlay.show()
		elif not show_story and entry.overlay.visible:
			entry.overlay.hide()
			if entry.original!=null: entry.original.visible = entry.was_visible

func _make_sign(optional := false) -> Sprite2D:
	# Preserve the shared task sign geometry and icon pivot with the new frame.
	var sign := Sprite2D.new()
	sign.name = "QuestSign"
	sign.set_meta("optional",optional)
	sign.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var frame := AtlasTexture.new()
	frame.atlas = load("res://assets/mapdot4o.webp")
	frame.region = Rect2(31,28,313,317)
	sign.texture = frame
	sign.position = Vector2(0,-223.928571)
	sign.scale = Vector2.ONE*0.84497521
	var icon := Sprite2D.new()
	icon.name = "StoryIcon"
	var art := AtlasTexture.new()
	art.atlas = load("res://assets/map-juqingo.webp" if optional else "res://assets/map-juqing.webp")
	art.region = Rect2(56,8,190,284) if optional else Rect2(62,8,182,284)
	icon.texture = art
	icon.scale = Vector2.ONE*0.715186134
	sign.add_child(icon)
	return sign
