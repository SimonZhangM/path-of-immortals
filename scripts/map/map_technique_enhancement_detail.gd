extends "res://scripts/map/map_technique_spell_detail.gd"

# Reuse the spell page's calibrated progress, summary, native text and button.
# Browsing a choice does not send a learning command or mutate the ledger.
var enhancements: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_enhancement_details.json"))
var enhancement_layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_enhancement_detail_layout.json"))
var selected_rank := 0
var selected_branch := ""
var preview_choices: Dictionary = {}
var cards: Array[PanelContainer] = []
var options_scroll: ScrollContainer
var options_list: VBoxContainer
var _page_key := ""
var has_prerequisite := false
var _backgrounds: Dictionary = {}
var progress_condition_icon: TextureRect
var progress_requirement_met := false
var themes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_categories.json"))

func _init() -> void:
	super()
	name = "TechniqueEnhancementDetail"
	_backgrounds[2] = load(enhancement_layout.texture)
	_backgrounds[3] = load(enhancement_layout.three_choice_texture)
	options_scroll = ScrollContainer.new()
	options_scroll.name = "EnhancementChoicesScroll"
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	canvas.add_child(options_scroll)
	options_list = VBoxContainer.new()
	options_list.name = "FullEnhancementCards"
	options_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_scroll.add_child(options_list)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("0b1e2a")
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("507b92")
	grab.set_corner_radius_all(3)
	var bar := options_scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", track)
	for style in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(style, grab)
	var extent := Vector2(layout.condition_icon_size[0], layout.condition_icon_size[1])
	progress_condition_icon = _image("EnhancementProgressCondition", layout.condition_false_texture, Rect2(Vector2.ZERO, extent))
	progress_condition_icon.hide()
	var condition := _label("EnhancementCondition", "", _rect(enhancement_layout.condition_label_rect), int(enhancement_layout.condition_font_size))
	condition.autowrap_mode = TextServer.AUTOWRAP_OFF
	condition.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	condition.hide()

func show_selection(book_id: String, rank: int, learning: MapLoadoutState) -> void:
	if not enhancements.has(book_id) or not enhancements[book_id].ranks.has(str(rank)):
		hide()
		return
	var page: Dictionary = enhancements[book_id].ranks[str(rank)]
	has_prerequisite = not str(page.spell_id).is_empty()
	state = learning
	current_book_id = book_id
	selected_spell_id = str(page.spell_id)
	record = {}
	labels.Poem.text = ""
	summary_extra_height = 0.0
	_refresh_book_progress()
	show()
	selected_rank = rank
	for node in detail_nodes: node.hide()
	if has_prerequisite:
		_set_spell_summary(page.prerequisite, true)
	var source: Texture2D = _backgrounds[page.choices.size()]
	artwork.texture.atlas = source
	canvas.get_node("SpellDetailFrame").texture.atlas = source
	canvas.get_node("SpellDetailFrame").show()
	labels.LearningButtonCaption.show()
	button_art.show()
	learning_button.show()
	_refresh_learning_condition()
	var key := "%s:%d" % [book_id, rank]
	if _page_key != key:
		_page_key = key
		for card in cards:
			options_list.remove_child(card)
			card.queue_free()
		cards.clear()
		var accent := Color("69dcff")
		var element := book_id.get_slice(".", 2).get_slice("_", 0)
		for theme: Dictionary in themes:
			if element != "water" and theme.element_id == "base.element." + element:
				accent = Color(theme.color)
		for entry: Dictionary in page.choices:
			var card := preload("res://scripts/map/map_technique_enhancement_card.gd").new()
			card.configure(entry, enhancement_layout, _font, accent)
			card.choice_requested.connect(_choose_preview)
			options_list.add_child(card)
			cards.append(card)
		options_scroll.scroll_vertical = 0
	if not preview_choices.has(key):
		var learned := learning.knowledge.branch(book_id, rank) if learning != null else ""
		preview_choices[key] = learned if not learned.is_empty() else str(page.choices[0].branch_key)
	_choose_preview(str(preview_choices[key]))
	_layout()

func _choose_preview(branch_key: String) -> void:
	var valid := false
	for card in cards:
		if card.record.branch_key == branch_key: valid = true
	if not valid: return
	selected_branch = branch_key
	preview_choices[_page_key] = branch_key
	for card in cards: card.set_selected(card.record.branch_key == branch_key)

func _refresh_learning_condition() -> void:
	# A stage is earned by the progression system; browsing and preview seeds
	# cannot grant eligibility. Every choice in this rank shares its requirement.
	progress_requirement_met = state != null and state.knowledge.level(current_book_id) >= selected_rank
	progress_condition_icon.visible = not has_prerequisite
	labels.EnhancementCondition.visible = not has_prerequisite
	progress_condition_icon.texture = load(layout.condition_true_texture if progress_requirement_met else layout.condition_false_texture)
	labels.EnhancementCondition.text = "已达到所需的修炼进度。" if progress_requirement_met else "未达到所需的修炼进度。"
	learning_button.disabled = not has_prerequisite and not progress_requirement_met
	learning_button.mouse_default_cursor_shape = CURSOR_ARROW if learning_button.disabled else CURSOR_POINTING_HAND
	labels.LearningButtonCaption.text = "无法强化" if learning_button.disabled else "确认强化"
	_button_hovered = false
	if _button_tween: _button_tween.kill()
	_set_button_scale(1.0)
	_update_button_art()

func _layout() -> void:
	super._layout()
	if not is_inside_tree() or options_scroll == null: return
	var transform := canvas.get_global_transform_with_canvas()
	var factor := transform.get_scale()
	if factor.x <= 0 or factor.y <= 0: return
	var box := _rect(enhancement_layout.options_scroll_rect if has_prerequisite else enhancement_layout.standalone_options_scroll_rect)
	box.position.y += summary_extra_height
	box.size.y -= summary_extra_height
	if has_prerequisite:
		# A longer poem may wrap after the category rows. Keep its last visible
		# line clear while preserving the fixed button and scroll area's bottom.
		var poem: Label = labels.Poem
		var font := poem.get_theme_font("font")
		var font_size := poem.get_theme_font_size("font_size")
		var ink := CooldownRing.ink_vertical_bounds(font, poem.text, font_size)
		var bottom := (transform * poem.position).y + font.get_ascent(font_size) + ink.y + poem.get_minimum_size().y - font.get_height(font_size)
		var extra := maxf(0, (bottom + roundf(12 * factor.y) - (transform * box.position).y) / factor.y)
		box.position.y += extra
		box.size.y -= extra
	options_scroll.scale = Vector2.ONE / factor
	options_scroll.position = transform.affine_inverse() * (transform * box.position).round()
	options_scroll.size = (box.size * factor).round()
	options_list.add_theme_constant_override("separation", roundi(float(enhancement_layout.card_gap) * factor.y))
	for card in cards: card.update_pixels(factor.x)
	if progress_condition_icon == null: return
	var footer_center := (_rect(layout.learning_button_rect).end.y + canvas.size.y) * 0.5
	progress_condition_icon.position = Vector2(float(layout.tick_centers[0][0]), footer_center) - progress_condition_icon.size * 0.5
	var condition: Label = labels.EnhancementCondition
	var font := condition.get_theme_font("font")
	var font_size := condition.get_theme_font_size("font_size")
	var ink := CooldownRing.ink_vertical_bounds(font, condition.text, font_size)
	var origin := transform * condition.position
	origin.y = roundf((transform * Vector2(0, footer_center)).y - font.get_ascent(font_size) - (ink.x + ink.y) * 0.5)
	condition.position = transform.affine_inverse() * origin
