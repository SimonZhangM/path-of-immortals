extends Control

signal rank_selected(level: int)

# This is browsing state only. Selecting a rank never learns a skill or branch.
class RankButton extends Button:
	var circular := false
	func _has_point(point: Vector2) -> bool:
		if circular:
			return point.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5
		return Rect2(Vector2.ZERO, size).has_point(point)

var rank_buttons: Array[Button] = []
var card_buttons: Array[Button] = []
var geometry: Array[Dictionary] = []
var selected_rank := 0
var _hovered_rank := 0
var _focused_rank := 0
var _crop := Rect2()
var _selected_glow: ColorRect
var _hover_glow: ColorRect
var theme_color := Color.WHITE

func configure(art: TextureRect, level: int) -> void:
	name = "RankSelection"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reference: Dictionary = art.reference
	var crop: Array = reference.display_crop
	_crop = Rect2(crop[0], crop[1], crop[2], crop[3])
	var frames: Dictionary = reference.selection_frames
	var five: bool = reference.get("layout_kind", "") == "five_choices"
	var count := 5 if five else 8
	var element := String(art.content.book_id).get_slice(".", 2).get_slice("_", 0)
	var categories: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_categories.json"))
	for category: Dictionary in categories:
		if category.element_id == "base.element." + element:
			theme_color = Color(category.color)
			break
	_selected_glow = _make_glow(art.texture.atlas, "SelectedRankGlow")
	_hover_glow = _make_glow(art.texture.atlas, "HoveredRankGlow")
	for column in count:
		var ring: Vector2
		var card: Rect2
		var heading_width := 164.0
		var ring_radius := 48.0
		if five:
			var first: Array = reference.first_rank_rect
			ring = Vector2(first[0] + first[2] * 0.5, first[1] + first[3] * 0.5) + art.source_column_offset(column)
			card = _rect(frames.first_card)
			card.position += art.source_column_offset(column)
		else:
			var odd := column % 2 == 0
			heading_width = 100.0 if odd else 148.0
			ring_radius = 44.0 if odd else 39.0
			var offset := Vector2(floori(column / 2.0) * float(reference.group_pitch), 0)
			ring = (Vector2(121, 191) if odd else Vector2(313, 191)) + offset + art.source_column_offset(column, true)
			card = _rect(frames.spell_card if odd else frames.choice_card)
			card.position += offset + art.source_column_offset(column)
		var heading := Rect2(Vector2(card.get_center().x - heading_width * 0.5, card.position.y + 11), Vector2(heading_width, 28))
		geometry.append({"ring": ring, "card": card, "heading": heading, "ring_radius": ring_radius})
		rank_buttons.append(_make_button(column + 1, true))
		card_buttons.append(_make_button(column + 1, false))
	resized.connect(_layout)
	select_rank(level, false)

func _rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])

func _make_glow(source: Texture2D, node_name: String) -> ColorRect:
	var glow := ColorRect.new()
	glow.name = node_name
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_technique_rank_glow.gdshader")
	paint.set_shader_parameter("artwork", source)
	paint.set_shader_parameter("source_size", source.get_size())
	paint.set_shader_parameter("glow_color", theme_color)
	glow.material = paint
	add_child(glow)
	return glow

func _make_button(level: int, circular: bool) -> Button:
	var button := RankButton.new()
	button.name = ("RankButton" if circular else "RankCardButton") + str(level)
	button.circular = circular
	button.toggle_mode = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL if circular else Control.FOCUS_NONE
	button.tooltip_text = "查看第%d重" % level
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(func(): select_rank(level))
	button.mouse_entered.connect(func():
		_hovered_rank = level
		_update_glows())
	button.mouse_exited.connect(func():
		if _hovered_rank == level: _hovered_rank = 0
		_update_glows())
	button.focus_entered.connect(func():
		_focused_rank = level
		_update_glows())
	button.focus_exited.connect(func():
		if _focused_rank == level: _focused_rank = 0
		_update_glows())
	add_child(button)
	return button

func select_rank(level: int, notify := true) -> void:
	if level < 1 or level > geometry.size(): return
	var changed := selected_rank != level
	selected_rank = level
	for index in rank_buttons.size():
		rank_buttons[index].set_pressed_no_signal(index + 1 == level)
		card_buttons[index].set_pressed_no_signal(index + 1 == level)
	_update_glows()
	if changed and notify: rank_selected.emit(level)

func _layout() -> void:
	var factor := size / _crop.size
	for index in geometry.size():
		var ring: Vector2 = geometry[index].ring
		rank_buttons[index].position = (ring - Vector2.ONE * 51.0 - _crop.position) * factor
		rank_buttons[index].size = Vector2.ONE * 102.0 * factor
		var card: Rect2 = geometry[index].card
		card_buttons[index].position = (card.position - _crop.position) * factor
		card_buttons[index].size = card.size * factor
	_update_glows()

func _update_glows() -> void:
	_layout_glow(_selected_glow, selected_rank, 1.0)
	var preview := _hovered_rank if _hovered_rank > 0 else _focused_rank
	_layout_glow(_hover_glow, preview if preview != selected_rank else 0, 0.35)

func _layout_glow(glow: ColorRect, level: int, intensity: float) -> void:
	if glow == null: return
	glow.visible = level > 0 and level <= geometry.size()
	if not glow.visible: return
	var selected: Dictionary = geometry[level - 1]
	var card: Rect2 = selected.card
	var ring: Vector2 = selected.ring
	var region := card.grow(18).merge(Rect2(ring - Vector2(85, 70), Vector2(170, 140)))
	var factor := size / _crop.size
	glow.position = (region.position - _crop.position) * factor
	glow.size = region.size * factor
	var paint := glow.material as ShaderMaterial
	paint.set_shader_parameter("source_region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
	paint.set_shader_parameter("card_rect", Vector4(card.position.x, card.position.y, card.size.x, card.size.y))
	var heading: Rect2 = selected.heading
	paint.set_shader_parameter("heading_rect", Vector4(heading.position.x, heading.position.y, heading.size.x, heading.size.y))
	paint.set_shader_parameter("ring_center", ring)
	paint.set_shader_parameter("ring_radius", selected.ring_radius)
	paint.set_shader_parameter("strength", intensity)
