extends Control

signal chosen
var entry: Dictionary
var model: MapLoadoutState
var selected := false
var busy := false
var portrait: Panel
var artwork: MapItemArtwork
var glow: ColorRect
var title: Label
var tags: HBoxContainer
var description: Label
var _theme_color: Color
var _heading_font := SystemFont.new()
var _body_font := SystemFont.new()

func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme = Theme.new()
	theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	_heading_font.font_names = PackedStringArray(["SimHei", "黑体", "Microsoft YaHei", "sans-serif"])
	_body_font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "serif"])
	resized.connect(_layout)

func configure(record: Dictionary, categories: Dictionary, loadout: MapLoadoutState) -> void:
	entry = record.duplicate(true)
	model = loadout
	_theme_color = MapItemQuality.color(entry.quality)
	portrait = Panel.new()
	portrait.mouse_filter = MOUSE_FILTER_IGNORE
	portrait.clip_contents = true
	var box := StyleBoxFlat.new()
	box.bg_color = Color("171e29")
	box.border_color = _theme_color
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	portrait.add_theme_stylebox_override("panel",box)
	add_child(portrait)
	artwork = MapItemArtwork.new()
	artwork.configure(entry,true)
	portrait.add_child(artwork)
	glow = artwork.get_node("ItemGlow")
	artwork.remove_child(glow)
	portrait.add_child(glow)
	portrait.move_child(glow,0)
	glow.show_behind_parent = false
	glow.set_anchors_preset(PRESET_TOP_LEFT)
	glow.material.set_shader_parameter("glow_color",Color(_theme_color,0.3))
	title = _label(entry.name,_heading_font)
	tags = HBoxContainer.new()
	tags.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(tags)
	var captions: Array = [categories.get(entry.category,entry.category)]
	var subcategory: String = entry.get("subcategory","")
	if entry.category=="armor" and subcategory.begins_with("护具·"): subcategory=ItemTooltip.classification_caption(subcategory)
	if not subcategory.is_empty(): captions.append(subcategory)
	if entry.category=="weapon" and entry.has("damage_type"): captions.append(entry.damage_type)
	if entry.has("armor_type"): captions.append(entry.armor_type)
	captions.append(entry.quality)
	var seen := {}
	for caption: String in captions:
		if seen.has(caption): continue
		seen[caption]=true
		var label := Label.new()
		label.text = caption
		label.mouse_filter = MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",_heading_font)
		label.add_theme_color_override("font_color",_theme_color.lightened(0.25))
		var border := StyleBoxFlat.new()
		border.bg_color = Color(_theme_color,0.12)
		border.border_color = _theme_color
		border.set_border_width_all(1)
		border.set_corner_radius_all(3)
		label.add_theme_stylebox_override("normal",border)
		tags.add_child(label)
	# Dedicated narrative copy; never substitute combat effects into this field.
	description = _label(entry.get("flavor_description",""),_body_font)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Bound the initial minimum height before the card receives its final width.
	description.max_lines_visible = 2
	_layout()

func _label(text: String, font: Font) -> Label:
	var label := Label.new()
	label.text=text
	label.add_theme_font_override("font",font)
	label.add_theme_color_override("font_color",Color("fbf4bf"))
	label.mouse_filter=MOUSE_FILTER_IGNORE
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	return label

func _layout() -> void:
	if portrait==null or size.x<=0: return
	var factor := size.x/562.0
	var portrait_size := Vector2(132,132)*0.9
	portrait.position = (Vector2(78,78)-portrait_size*0.5)*factor
	portrait.size = portrait_size*factor
	artwork.rotation=0
	artwork.scale=Vector2.ONE
	artwork.position=Vector2.ZERO
	artwork.size=portrait.size*0.75
	artwork.pivot_offset=artwork.size*0.5
	artwork.apply_inventory_pose(entry)
	artwork.scale*=0.9
	artwork.center_visible_at(portrait.size*0.5)
	glow.position=portrait.size*0.04
	glow.size=portrait.size*0.92
	title.position=(Vector2(165,12)*factor).round()
	title.size=(Vector2(325,42)*factor).round()
	title.add_theme_font_size_override("font_size",maxi(1,roundi(30*factor)))
	tags.position=(Vector2(165,57)*factor).round()
	tags.size=(Vector2(378,26)*factor).round()
	tags.add_theme_constant_override("separation",roundi(7*factor))
	for tag: Label in tags.get_children():
		tag.add_theme_font_size_override("font_size",maxi(1,roundi(16*factor)))
		var box := tag.get_theme_stylebox("normal") as StyleBoxFlat
		box.content_margin_left=6*factor
		box.content_margin_right=6*factor
		box.content_margin_top=factor
		box.content_margin_bottom=3*factor
	description.position=(Vector2(165,89)*factor).round()
	description.add_theme_font_size_override("font_size",maxi(1,roundi(20*factor)))
	description.size=(Vector2(374,54)*factor).round()
	queue_redraw()

func set_selected(value: bool) -> void:
	selected=value
	queue_redraw()

func _draw() -> void:
	var factor := size.x/562.0
	var tint := Color("ffda69") if selected else Color("8b9295")
	if selected:
		var highlight := StyleBoxFlat.new()
		highlight.bg_color=Color("efc05a",0.07)
		highlight.border_color=tint
		highlight.set_border_width_all(2)
		highlight.set_corner_radius_all(roundi(6*factor))
		# StyleBoxFlat shadows also fill behind its translucent center.
		# Keep the supplied dark row art legible with a faint tint and clear rim.
		highlight.shadow_size=0
		draw_style_box(highlight,Rect2(Vector2.ZERO,size).grow(1))
	var center := Vector2(521,37)*factor
	draw_arc(center,18*factor,0,TAU,64,tint,1.7*factor,true)
	if selected:
		draw_polyline(PackedVector2Array([center+Vector2(-10,0)*factor,center+Vector2(-3,7)*factor,center+Vector2(11,-8)*factor]),tint,3.2*factor,true)

func _gui_input(event: InputEvent) -> void:
	if not busy and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		chosen.emit()
	accept_event()

func _ready() -> void:
	ItemTooltipHost.bind(self, func(_point: Vector2): return entry.get("id", ""), build_item_tooltip)

func _get_tooltip(_point: Vector2) -> String:
	return ""

func build_item_tooltip(_text: String) -> Object:
	if model==null: return null
	var tip := ItemTooltip.new()
	tip.configure(model.registry.get_item(entry.id))
	return tip
