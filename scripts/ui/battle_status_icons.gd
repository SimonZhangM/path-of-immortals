class_name BattleStatusIcons
extends GridContainer

const COLUMNS := 8
const ICON_SIDE := 32.0
# The battle layout is scaled by 4/3 at native 2K: 0.375 becomes 0.5px.
const OUTLINE_RADIUS := 0.375
var show_all_for_testing := true
var slots: Dictionary = {}
var counts: Dictionary = {}
static var _textures: Dictionary = {}
var member: PartyMemberState
var manager: GameManager
var _display_order: Array[String] = []

class StatusSlot extends Control:
	var word: String
	var owner_grid: WeakRef
	func _make_custom_tooltip(_text: String) -> Object:
		var grid = owner_grid.get_ref()
		var tip := BattleStatusTooltip.new()
		tip.configure(word,grid.member,grid.manager)
		return tip

func configure() -> void:
	name = "BattleStatusIcons"
	columns = COLUMNS
	add_theme_constant_override("h_separation",2)
	add_theme_constant_override("v_separation",3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paths := ItemTooltip.status_keyword_icons()
	var kinds := ItemTooltip.status_keyword_kinds()
	var ordered: Array[String] = []
	for kind in ["buff", "debuff"]:
		for word: String in paths:
			if kinds[word] == kind: ordered.append(word)
	for word: String in ordered:
		var slot := StatusSlot.new()
		slot.word = word
		slot.owner_grid = weakref(self)
		slot.tooltip_text = word
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.name = word
		slot.custom_minimum_size = Vector2(ICON_SIDE,ICON_SIDE+2)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(slot)
		var icon := TextureRect.new()
		icon.name = "Icon"
		if not _textures.has(paths[word]):
			var source := load(paths[word]) as Texture2D
			var texture := AtlasTexture.new()
			texture.atlas = source
			texture.region = source.get_image().get_used_rect()
			_textures[paths[word]] = texture
		icon.texture = _textures[paths[word]]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.size = Vector2.ONE * ICON_SIDE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		# Trace the existing alpha silhouette without changing the source artwork.
		for step in 8:
			var outline := TextureRect.new()
			outline.name = "Outline%d" % step
			outline.texture = icon.texture
			outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			outline.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			outline.self_modulate = Color.BLACK
			outline.show_behind_parent = true
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(outline)
			outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			outline.position += Vector2.from_angle(TAU * step / 8.0) * OUTLINE_RADIUS
		var number := Label.new()
		number.name = "Layers"
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		number.add_theme_font_size_override("font_size",CooldownRing.FONT_SIZE)
		number.add_theme_color_override("font_color",Color("fff9e9"))
		number.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		number.add_theme_constant_override("outline_size",0)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(number)
		number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for step in 8:
			var edge := Label.new()
			edge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			edge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			edge.add_theme_font_size_override("font_size",CooldownRing.FONT_SIZE)
			edge.add_theme_color_override("font_color",Color.BLACK)
			edge.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
			edge.add_theme_constant_override("outline_size",0)
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			edge.show_behind_parent = true
			number.add_child(edge)
			edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			edge.position += Vector2.from_angle(TAU * step / 8.0) * OUTLINE_RADIUS
		slots[word] = slot
		counts[word] = number
		_display_order.append(word)

func refresh(current_member: PartyMemberState) -> void:
	member = current_member
	var any_visible := false
	for word: String in slots:
		var layers := T01CombatRules.layers(member,word)
		if word == "毒蚀" and layers == 0: layers = member.toxin_stacks
		var shown := show_all_for_testing or layers > 0
		slots[word].visible = shown
		counts[word].visible = layers > 0
		var text := str(layers) if layers > 0 else ""
		if counts[word].text != text:
			counts[word].text = text
			for edge: Label in counts[word].get_children(): edge.text = text
		any_visible = any_visible or shown
	# The simulation inserts a status once, keeps its key when stacking, and
	# erases it at zero. Reapplication therefore naturally returns at the end.
	var desired: Array[String] = []
	if not show_all_for_testing:
		for word: String in member.combat_statuses:
			if slots.has(word) and slots[word].visible: desired.append(word)
		if member.toxin_stacks > 0 and not desired.has("毒蚀"): desired.append("毒蚀")
	for word: String in slots:
		if not desired.has(word): desired.append(word)
	if desired != _display_order:
		for index in desired.size(): move_child(slots[desired[index]],index)
		_display_order = desired
	visible = any_visible
