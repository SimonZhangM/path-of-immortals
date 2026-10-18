extends TextureRect

signal layout_changed

# Source coordinates survive a replacement that removes the baked-in icons.
var books: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_progress_books.json"))
var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_progress_art.json"))
var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_progress_qingluo.json"))
var icons: Array[TextureRect] = []
var status_icons: Array[TextureRect] = []
var status_backplates: Array[TextureRect] = []
var captions: Array[Label] = []
var _font: SystemFont
var _name_font: SystemFont

func _init() -> void:
	name = "TechniqueProgressArtwork"
	var art := AtlasTexture.new()
	art.atlas = load(reference.texture)
	var crop: Array = reference.display_crop
	art.region = Rect2(crop[0], crop[1], crop[2], crop[3])
	texture = art
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	_name_font = SystemFont.new()
	_name_font.font_names = PackedStringArray(["HarmonyOS Sans SC", "鸿蒙简体", "sans-serif"])
	_name_font.font_weight = 400
	_build_contents()
	resized.connect(_layout_contents)
	set_notify_transform(true)
	hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		_layout_contents()

func show_book(book_id: String) -> void:
	visible = books.has(book_id)
	if not visible or book_id == content.book_id: return
	var book: Dictionary = books[book_id]
	reference = JSON.parse_string(FileAccess.get_file_as_string(book.layout))
	# Elements share measured geometry while retaining their own frame artwork.
	reference.merge(book.get("layout_overrides", {}), true)
	content = {"book_id": book_id, "stages": []} if book.get("frame_only", false) else JSON.parse_string(FileAccess.get_file_as_string(book.content))
	var art := AtlasTexture.new()
	art.atlas = load(reference.texture)
	var crop: Array = reference.display_crop
	art.region = Rect2(crop[0], crop[1], crop[2], crop[3])
	texture = art
	for child in get_children():
		remove_child(child)
		child.queue_free()
	icons.clear()
	status_icons.clear()
	status_backplates.clear()
	captions.clear()
	_build_contents()
	_layout_contents()
	layout_changed.emit()

func _build_contents() -> void:
	if reference.get("layout_kind", "") == "five_choices":
		_build_five_column_contents()
		return
	for group_index in content.stages.size():
		var stage: Dictionary = content.stages[group_index]
		var level := int(stage.level)
		var offset := float(group_index * reference.group_pitch)
		var spell_offset := source_column_offset(group_index * 2)
		var choice_offset := source_column_offset(group_index * 2 + 1)
		_add_caption(str(level), Rect2(Vector2(88 + offset, 158) + source_column_offset(group_index * 2, true), Vector2(66, 66)), 36, "Rank" + str(level))
		_add_caption(str(level + 1), Rect2(Vector2(282 + offset, 160) + source_column_offset(group_index * 2 + 1, true), Vector2(62, 62)), 32, "Rank" + str(level + 1))
		_add_icon(stage.spell, group_index, -1)
		var spell_name := String(stage.spell.name)
		var name_rect := Rect2(Vector2(58 + offset, 413) + spell_offset, Vector2(126, 26))
		if spell_name.length() > 4:
			spell_name = spell_name.substr(0, 2) + "\n" + spell_name.substr(2)
			name_rect.position.y -= 13
			name_rect.size.y = 52
		_add_caption(spell_name, name_rect, 25, "SpellName")
		for option_index in 2:
			var choice: Dictionary = stage.choices[option_index]
			var x := 212.0 + offset + option_index * 100
			_add_icon(choice, group_index, option_index)
			_add_caption(choice.name, Rect2(Vector2(x, 394) + choice_offset, Vector2(100, 28)), 22, "ChoiceName")
			var effect := "（" + String(choice.effect) + "）"
			var effect_rect := Rect2(Vector2(x, 418) + choice_offset, Vector2(100, 24))
			_add_caption(effect, effect_rect, 16, "ChoiceEffect", Color("c8d6d2"))

func _build_five_column_contents() -> void:
	for column in content.stages.size():
		var stage: Dictionary = content.stages[column]
		var offset := source_column_offset(column)
		for option in stage.choices.size():
			var choice: Dictionary = stage.choices[option]
			var slot: Array = reference.first_column_icon_rects[option]
			_add_icon(choice, column, option)
			# Match the first spell's centered name and 22 source-pixel gap.
			# Three-choice slots need two lines for four characters at that same size.
			var title := String(choice.name)
			var narrow: bool = int(reference.choices_per_column) == 3
			var two_lines := narrow and title.length() > 3
			if two_lines: title = title.substr(0, 2) + "\n" + title.substr(2)
			var width := 94.0 if narrow else 112.0
			var position := Vector2(slot[0] + slot[2] * 0.5 - width * 0.5, slot[1] + slot[3] + 22) + offset
			if choice.has("status_icons") or content.get("reserve_status_space", false):
				position.y += float(reference.status_name_offset_y)
			if choice.has("status_icons"):
				_add_status_icons(choice.status_icons, slot, offset, column)
			_add_caption(title, Rect2(position, Vector2(width, 58 if two_lines else 26)), 25, "SpellName")
	# Keep rank markers anchored to their rings, independently of skill offsets.
	for column in content.stages.size():
		var source: Array = reference.first_rank_rect
		var rect := Rect2(Vector2(source[0], source[1]) + source_column_offset(column), Vector2(source[2], source[3]))
		var level := int(content.stages[column].level)
		_add_caption(str(level), rect, int(reference.rank_font_size), "Rank" + str(level))

func _add_status_icons(statuses: Array, slot: Array, offset: Vector2, column: int) -> void:
	var original_side := float(reference.status_icon_size)
	var paired := statuses.size() > 1
	var side := original_side * float(reference.get("paired_status_icon_scale", 1.0)) if paired else original_side
	var gap := float(reference.get("paired_status_icon_gap", reference.status_icon_gap)) if paired else float(reference.status_icon_gap)
	var width := statuses.size() * side + (statuses.size() - 1) * gap
	var center := Vector2(slot[0] + slot[2] * 0.5, slot[1] + slot[3] + float(reference.status_icon_top_gap) + original_side * 0.5) + offset
	var origin := center - Vector2(width, side) * 0.5
	var backing: Dictionary = reference.get("status_backplate", {})
	if column in PackedInt32Array(backing.get("columns", [])):
		_add_status_backplate(backing, center, column, paired)
	for index in statuses.size():
		var status: Dictionary = statuses[index]
		var rect := Rect2(origin + Vector2(index * (side + gap), 0), Vector2.ONE * side)
		var icon := TextureRect.new()
		icon.name = "Status_%02d" % (status_icons.size() + 1)
		var source := load(status.icon) as Texture2D
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = source.get_image().get_used_rect()
		icon.texture = atlas
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_meta("status_name", status.name)
		icon.set_meta("screen_offset_x", float(status.get("screen_offset_x", 0)))
		icon.set_meta("column", column)
		icon.set_meta("source_rect", rect)
		add_child(icon)
		status_icons.append(icon)

func _add_status_backplate(definition: Dictionary, center: Vector2, column: int, paired: bool) -> void:
	var backing := TextureRect.new()
	backing.name = "StatusBackplate_%02d" % (status_backplates.size() + 1)
	backing.texture = load(definition.texture)
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.stretch_mode = TextureRect.STRETCH_SCALE
	backing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := float(definition.get("paired_width", definition.display_width)) if paired else float(definition.display_width)
	var factor := Vector2(width, float(definition.display_width)) / backing.texture.get_width()
	var ring_center := Vector2(definition.circle_center[0], definition.circle_center[1]) * factor
	backing.set_meta("source_rect", Rect2(center - ring_center, backing.texture.get_size() * factor))
	backing.set_meta("column", column)
	backing.set_meta("screen_offset_y", float(definition.get("screen_offset_y", 0)))
	# Added before its status icon, so the existing symbol stays above the ring.
	add_child(backing)
	status_backplates.append(backing)

func _add_icon(record: Dictionary, group_index: int, option_index: int) -> void:
	# Text-only entries retain the measured slot for a later artwork update.
	if String(record.get("icon", "")).is_empty(): return
	var icon := TextureRect.new()
	icon.name = "Effect_%02d" % (icons.size() + 1)
	icon.texture = load(record.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta("group", group_index)
	icon.set_meta("option", option_index)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_technique_icon.gdshader")
	paint.set_shader_parameter("line_width", 1.0)
	paint.set_shader_parameter("corner_radius", 3.0)
	paint.set_shader_parameter("line_color", Color("d9bb72"))
	icon.material = paint
	add_child(icon)
	icons.append(icon)

func _add_caption(text: String, rect: Rect2, font_size: int, node_name: String, color := Color("f3f0dc")) -> void:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Text uses native pixels; artwork keeps its own mipmapped filtering.
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	label.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_DISABLED
	label.add_theme_font_override("font", _name_font if node_name in ["SpellName", "ChoiceName"] else _font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("08121ce6"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.set_meta("source_rect", rect)
	label.set_meta("kind", node_name)
	label.set_meta("source_font_size", font_size)
	label.add_theme_constant_override("line_spacing", -2)
	add_child(label)
	captions.append(label)

func _layout_contents() -> void:
	var screen_scale := get_global_transform_with_canvas().get_scale()
	var overlay_offset := Vector2(0, float(reference.get("overlay_offset_screen_y", 0))) / screen_scale
	for icon in icons:
		var rect := choice_icon_rect(icon.get_meta("group"), icon.get_meta("option")) if reference.get("layout_kind", "") == "five_choices" else icon_rect(icon.get_meta("group"), icon.get_meta("option"))
		icon.position = rect.position + overlay_offset
		icon.size = rect.size
		icon.material.set_shader_parameter("icon_size", rect.size)
	var crop: Array = reference.display_crop
	var factor := size / Vector2(crop[2], crop[3])
	for icon in status_backplates + status_icons:
		var rect: Rect2 = icon.get_meta("source_rect")
		icon.position = (rect.position - Vector2(crop[0], crop[1])) * factor
		icon.position.x += float(icon.get_meta("screen_offset_x", 0)) / screen_scale.x
		icon.position.y += float(icon.get_meta("screen_offset_y", 0)) / screen_scale.y
		icon.size = rect.size * factor
	_layout_captions()

func _layout_captions() -> void:
	if not is_inside_tree(): return
	var crop: Array = reference.display_crop
	var factor := size / Vector2(crop[2], crop[3])
	var screen_transform := get_global_transform_with_canvas()
	var screen_scale := screen_transform.get_scale()
	if screen_scale.x <= 0.0 or screen_scale.y <= 0.0: return
	var to_local := screen_transform.affine_inverse()
	var font_size_changed := false
	for label in captions:
		var rect: Rect2 = label.get_meta("source_rect")
		var design_font_size := maxi(1, roundi(float(label.get_meta("source_font_size")) * factor.x))
		# Cancel only the text's inherited scale, then rasterize its displayed
		# integer font size once, like the inventory tooltip's native text.
		label.scale = Vector2.ONE / screen_scale
		var native_font_size := maxi(1, roundi(design_font_size * screen_scale.x))
		# Add one native font-size step without double-rounding it through stage scale.
		if label.get_meta("kind") in ["SpellName", "ChoiceEffect"]: native_font_size += 1
		if label.get_theme_font_size("font_size") != native_font_size:
			label.add_theme_font_size_override("font_size", native_font_size)
			font_size_changed = true
		var source_position := (rect.position - Vector2(crop[0], crop[1])) * factor
		var screen_position := (screen_transform * source_position).round()
		if not String(label.get_meta("kind")).begins_with("Rank"):
			screen_position.y += float(reference.get("overlay_offset_screen_y", 0))
		if label.get_meta("kind") == "ChoiceEffect": screen_position.y += 2
		label.position = to_local * screen_position
		label.size = (rect.size * factor * screen_scale).round()
	# Font changes invalidate Label's minimum width asynchronously. Reapply
	# bounds once it has reshaped, so shrinking a window cannot retain old widths.
	if font_size_changed: _layout_captions.call_deferred()

# Card frames and rank rings can move independently in replacement artwork.
func source_column_offset(column_index: int, rank := false) -> Vector2:
	var offsets: Array = reference.rank_offsets if rank else reference.column_offsets
	var offset: Array = offsets[column_index]
	# A replacement canvas may translate every frame without resizing its contents.
	var origin: Array = reference.get("source_origin_offset", [0, 0])
	return Vector2(offset[0] + origin[0], offset[1] + origin[1])

# group_index0..3; option_index=-1 means spell,0/1 means enhancement choices.
# Returns the local rect used by the independent effect TextureRects.
func icon_rect(group_index: int, option_index := -1) -> Rect2:
	if reference.get("layout_kind", "") == "five_choices": return Rect2()
	if group_index < 0 or group_index > 3 or option_index < -1 or option_index > 1:
		return Rect2()
	var key := "spell" if option_index == -1 else "choice_left" if option_index == 0 else "choice_right"
	var source: Array = reference.icon_templates[key]
	var crop: Array = reference.display_crop
	var factor := size / Vector2(crop[2], crop[3])
	var offset := source_column_offset(group_index * 2 + (0 if option_index == -1 else 1))
	return Rect2((Vector2(source[0] + group_index * reference.group_pitch, source[1]) + offset - Vector2(crop[0], crop[1])) * factor, Vector2(source[2], source[3]) * factor)

# Five-column templates: zero-based column and choice, shared by all skill overlays.
func choice_icon_rect(column_index: int, option_index: int) -> Rect2:
	if reference.get("layout_kind", "") != "five_choices": return Rect2()
	if column_index < 0 or column_index >= reference.column_offsets.size() or option_index < 0 or option_index >= reference.first_column_icon_rects.size(): return Rect2()
	var source: Array = reference.first_column_icon_rects[option_index]
	var offset: Array = reference.column_offsets[column_index]
	var crop: Array = reference.display_crop
	var factor := size / Vector2(crop[2], crop[3])
	return Rect2((Vector2(source[0] + offset[0], source[1] + offset[1]) - Vector2(crop[0], crop[1])) * factor, Vector2(source[2], source[3]) * factor)
