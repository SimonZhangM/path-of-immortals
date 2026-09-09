class_name PartyMemberCard
extends Control

signal clicked(index: int)

const BAR_WIDTH := 200.0
const BASE_SIZE := Vector2(410, 236)
const COMPACT_SCALE := 0.66
var member_index: int = -1
var stat_bars: Dictionary = {}
var stat_values: Dictionary = {}
var stat_icons: Dictionary = {}
var resources: VBoxContainer
var _title: Label
var portrait: TextureRect
var portrait_frame: TextureRect
var _portrait_slot: Control
var _portrait_window := Rect2(0, 0, 1, 1)
var _content: HBoxContainer
var _last_values: Array = []
var _last_cultivation_id: String = "uninitialized"
var _frame_override: Dictionary = {}
var nameplate: TextureRect
var name_label: Label
var hit_effects: Array[HitFeedback] = []

func configure(index: int, member: RefCounted, frame_override: Dictionary = {}) -> void:
	_frame_override = frame_override.duplicate(true)
	member_index = index
	name = "PartyMember%d" % (index + 1)
	custom_minimum_size = BASE_SIZE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	_content = HBoxContainer.new()
	_content.custom_minimum_size = BASE_SIZE
	_content.size = BASE_SIZE
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)
	portrait = TextureRect.new()
	portrait.texture = load(member.definition["portrait"])
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cultivation: Dictionary = member.cultivation if _frame_override.is_empty() else _frame_override
	if not cultivation.is_empty():
		_portrait_slot = Control.new()
		_portrait_slot.custom_minimum_size = Vector2(236, 236)
		_portrait_slot.clip_contents = true
		_content.add_child(_portrait_slot)
		_portrait_slot.add_child(portrait)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var mask := ShaderMaterial.new()
		mask.shader = preload("res://scripts/ui/portrait_mask.gdshader")
		portrait.material = mask
		portrait_frame = TextureRect.new()
		portrait_frame.texture = load(cultivation["portrait_frame"])
		portrait_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_portrait_slot.add_child(portrait_frame)
		var window: Array = cultivation["portrait_window"]
		_portrait_window = Rect2(window[0], window[1], window[2], window[3])
		_portrait_slot.resized.connect(_layout_portrait)
		_layout_portrait.call_deferred()
	else:
		var image_slot := Control.new()
		image_slot.custom_minimum_size = Vector2(236, 236)
		_content.add_child(image_slot)
		image_slot.add_child(portrait)
		portrait.position = Vector2(-18, -18)
		portrait.size = Vector2(272, 272)
	var details := VBoxContainer.new()
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(details)
	var title := Label.new()
	_title = title
	title.text = str(member.definition["name"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 19)
	details.add_child(title)
	title.hide()
	nameplate = TextureRect.new()
	var plaque_source: Texture2D = load("res://assets/name-bg.webp")
	var plaque_texture := AtlasTexture.new()
	plaque_texture.atlas = plaque_source
	plaque_texture.region = plaque_source.get_image().get_used_rect()
	nameplate.texture = plaque_texture
	nameplate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nameplate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nameplate)
	name_label = Label.new()
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16 if member is CompanionState else 19)
	name_label.add_theme_color_override("font_color", Color("f1dca6"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.add_child(name_label)
	_layout_nameplate.call_deferred()
	if member is CompanionState:
		details.hide()
		custom_minimum_size = Vector2.ONE * (BASE_SIZE.y * 2.0 / 3.0)
		_content.custom_minimum_size = Vector2(236, 236)
		_content.size = Vector2(236, 236)
		_content.scale = Vector2.ONE * (2.0 / 3.0)
		_ignore_mouse(_content)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		refresh(member)
		return
	resources = VBoxContainer.new()
	resources.add_theme_constant_override("separation", 3)
	details.add_child(resources)
	var keys := ["hp", "stamina", "spirit"]
	var icons := ["res://assets/zhuangtai-qx.webp", "res://assets/zhuangtai-tl.webp", "res://assets/zhuangtai-ll.webp"]
	var colors := [Color("af3549"), Color("8cd259"), Color("5598eb")]
	for stat_index in keys.size():
		var key: String = keys[stat_index]
		var row := Control.new()
		row.custom_minimum_size = Vector2(154, 32)
		resources.add_child(row)
		var bar := ResourceBar.new()
		bar.anchor_right = 1
		bar.offset_left = 17
		bar.offset_top = 3
		bar.offset_bottom = 29
		bar.tint = colors[stat_index]
		row.add_child(bar)
		var icon := TextureRect.new()
		var source: Texture2D = load(icons[stat_index])
		var trimmed := AtlasTexture.new()
		trimmed.atlas = source
		trimmed.region = source.get_image().get_used_rect()
		icon.texture = trimmed
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(32, 32)
		icon.z_index = 1
		row.add_child(icon)
		stat_icons[key] = icon
		var value := Label.new()
		value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 16)
		value.add_theme_color_override("font_color", Color("fff9e9"))
		value.add_theme_color_override("font_shadow_color", Color("000000", 0.9))
		value.add_theme_constant_override("shadow_offset_y", 1)
		bar.add_child(value)
		stat_bars[key] = bar
		stat_values[key] = value
	_ignore_mouse(_content)
	refresh(member)

func _layout_portrait() -> void:
	var source := portrait_frame.texture.get_size()
	var frame_size := source * minf(_portrait_slot.size.x / source.x, _portrait_slot.size.y / source.y)
	var origin := (_portrait_slot.size - frame_size) * 0.5
	portrait.position = origin + _portrait_window.position * frame_size
	portrait.size = _portrait_window.size * frame_size
	portrait.material.set_shader_parameter("portrait_size", portrait.size)
	_layout_nameplate()

func _layout_nameplate() -> void:
	if nameplate != null:
		var display_scale := _content.scale.x
		nameplate.size = Vector2(210, 48) * display_scale
		nameplate.position = Vector2(portrait.position.x + portrait.size.x * 0.5, portrait.position.y + portrait.size.y - 7) * display_scale - Vector2(nameplate.size.x * 0.5, 0)
		if _frame_override.is_empty():
			nameplate.position.y = 200

func _draw() -> void:
	if resources != null:
		draw_texture_rect(preload("res://scripts/ui/portrait_backdrop.tres"), Rect2(110, 16, _content.size.x - 78, 204), false)

func set_primary(primary: bool) -> void:
	var display_scale := 1.0 if primary else COMPACT_SCALE
	var content_size := BASE_SIZE if primary else Vector2(424, BASE_SIZE.y)
	custom_minimum_size = content_size * display_scale
	_content.custom_minimum_size = content_size
	_content.size = content_size
	_content.set_deferred("size", content_size)
	_content.scale = Vector2.ONE * display_scale
	size_flags_horizontal = Control.SIZE_SHRINK_END if primary else Control.SIZE_SHRINK_BEGIN
	_title.add_theme_color_override("font_color", Color("f4d48e") if primary else Color("ece4cd"))

func refresh(member: RefCounted) -> void:
	name_label.text = "队友 · %s" % member.definition["name"] if member is CompanionState else str(member.definition["name"])
	if member is not CompanionState and not member.cultivation.is_empty():
		name_label.text += " · %s" % member.cultivation["name"]
	if member.cultivation_rank_id != _last_cultivation_id:
		_last_cultivation_id = member.cultivation_rank_id
		var cultivation: Dictionary = member.cultivation
		_title.text = str(member.definition["name"])
		if not cultivation.is_empty():
			_title.text += "（%s）" % cultivation["name"]
			if portrait_frame != null:
				var frame_style: Dictionary = cultivation if _frame_override.is_empty() else _frame_override
				portrait_frame.texture = load(frame_style["portrait_frame"])
				var window: Array = frame_style["portrait_window"]
				_portrait_window = Rect2(window[0], window[1], window[2], window[3])
				_layout_portrait()
	if member is CompanionState:
		return
	var values := [member.hp, member.stamina, member.spirit, member.maximum("hp")]
	if values == _last_values:
		return
	_last_values = values
	portrait.modulate = Color(0.45, 0.45, 0.45) if member.hp <= 0 else Color.WHITE
	var keys := ["hp", "stamina", "spirit"]
	for index in keys.size():
		var key: String = keys[index]
		var maximum: int = member.maximum(key)
		stat_bars[key].max_value = maxi(maximum, 1)
		stat_bars[key].value = values[index]
		stat_values[key].text = "%d / %d" % [values[index], maximum]

func fit_primary_width(width: float) -> void:
	custom_minimum_size.x = width
	_content.custom_minimum_size.x = width
	_content.set_deferred("size", Vector2(width, BASE_SIZE.y))

func show_hit(amount: int) -> void:
	hit_effects = hit_effects.filter(func(effect): return is_instance_valid(effect) and not effect.is_queued_for_deletion())
	var effect := HitFeedback.new()
	# Keep damage text independent of portrait clipping and the death tint.
	add_child(effect)
	effect.position = get_global_transform().affine_inverse() * portrait.global_position
	effect.scale = portrait.get_global_transform().get_scale() / get_global_transform().get_scale()
	effect.size = portrait.size
	effect.configure(amount, hit_effects.size())
	hit_effects.append(effect)

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(member_index)
		accept_event()
