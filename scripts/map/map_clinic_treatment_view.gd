class_name MapClinicTreatmentView
extends Control

signal confirmed

const ORIGIN := Vector2(674,315)
const METRICS = preload("res://scripts/map/map_texture_metrics.gd")
const INK := Color("f8ecc8")
const RECOVERY := Color("86e79a")
var confirm_button: TextureButton
var confirm_label: Label
var current_label: RichTextLabel
var after_label: RichTextLabel
var gain_label: Label
var fee_label: Label
var message: Label
var tagline: Label
var payment_note: Label
var recovery_note: Label
var payment_notes: VBoxContainer
var description: Label
var motto: Label
var _kai := SystemFont.new()
var _hei := SystemFont.new()
var _harmony := SystemFont.new()
var _state: MapLoadoutState
var _status: MapPlayerStatus
var _config: Dictionary = {}

func _init() -> void:
	name = "TreatmentContent"
	mouse_filter = MOUSE_FILTER_IGNORE
	_kai.font_names = PackedStringArray(["KaiTi","楷体","STKaiti","serif"])
	_hei.font_names = PackedStringArray(["SimHei","黑体","Microsoft YaHei","sans-serif"])
	_harmony.font_names = PackedStringArray(["HarmonyOS Sans SC","鸿蒙简体","sans-serif"])
	_harmony.font_weight = 400
	_label("诊治预览",Rect2(703,319,180,35),27,_hei)
	tagline = _label("",Rect2(960,325,387,25),19,_kai)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for column in [{"name":"当前气血","x":743},{"name":"诊后气血","x":953},{"name":"预计恢复","x":1160}]:
		var heading := _label(column.name,Rect2(column.x,368,160,32),23,_kai)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_label = _value(Rect2(743,471,160,37))
	after_label = _value(Rect2(953,471,160,37))
	gain_label = _label("",Rect2(1160,418,160,52),39,_kai)
	gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gain_label.add_theme_color_override("font_color",RECOVERY)
	_label("诊金",Rect2(703,535,90,36),27,_hei)
	var coin := _image("res://assets/tanchuang-jiaoyi-coin.webp",Rect2(798,535,26,36))
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fee_label = _label("",Rect2(835,533,104,39),32,_kai)
	payment_notes = VBoxContainer.new()
	payment_notes.mouse_filter = MOUSE_FILTER_IGNORE
	payment_notes.alignment = BoxContainer.ALIGNMENT_CENTER
	payment_notes.add_theme_constant_override("separation",1)
	_place(payment_notes,Rect2(978,527,371,51))
	payment_note = _label("",Rect2(),20,_kai)
	recovery_note = _label("",Rect2(),20,_kai)
	payment_note.reparent(payment_notes)
	recovery_note.reparent(payment_notes)
	recovery_note.add_theme_color_override("font_color",Color("f3d58c"))
	var alert := _image("res://assets/tanchuang-baoxiang-alaet.webp",Rect2(701,612,25,25))
	alert.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_label("医馆说明",Rect2(739,608,240,34),27,_hei)
	description = _label("",Rect2(700,646,650,51),19,_kai)
	description.add_theme_constant_override("line_spacing",5)
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	motto = _label("",Rect2(676,735,312,57),20,_kai)
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	motto.add_theme_constant_override("line_spacing",4)
	confirm_button = TextureButton.new()
	confirm_button.texture_normal = preload("res://assets/tanchuang-baoxiang-dakai1.webp")
	confirm_button.texture_hover = preload("res://assets/tanchuang-baoxiang-dakai2.webp")
	confirm_button.texture_pressed = confirm_button.texture_hover
	confirm_button.texture_disabled = confirm_button.texture_normal
	confirm_button.ignore_texture_size = true
	confirm_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	confirm_button.focus_mode = FOCUS_NONE
	confirm_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_place(confirm_button,Rect2(1080,715,300,92))
	confirm_label = _label("确认诊治",Rect2(1080,715,300,92),29,_harmony)
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.add_theme_color_override("font_color",Color.WHITE)
	confirm_button.mouse_entered.connect(func(): _hover(true))
	confirm_button.mouse_exited.connect(func(): _hover(false))
	confirm_button.pressed.connect(func():
		if not confirm_button.disabled: confirmed.emit()
	)
	message = _label("",Rect2(978,527,371,51),20,_kai)
	message.add_theme_color_override("font_color",Color("f3d58c"))

func _place(control: Control, rect: Rect2) -> void:
	add_child(control)
	control.position = rect.position-ORIGIN
	control.size = rect.size

func _label(text: String, rect: Rect2, font_size: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",INK)
	_place(label,rect)
	return label

func _image(path: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = METRICS.inspect(atlas.atlas).visible_rect
	image.texture = atlas
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	_place(image,rect)
	return image

func _value(rect: Rect2) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font",_kai)
	label.add_theme_font_size_override("normal_font_size",29)
	label.add_theme_color_override("default_color",INK)
	_place(label,rect)
	return label

func configure(config: Dictionary, state: MapLoadoutState, status: MapPlayerStatus) -> void:
	if _state!=null and _state.changed.is_connected(refresh): _state.changed.disconnect(refresh)
	if _status!=null and _status.changed.is_connected(refresh): _status.changed.disconnect(refresh)
	_config = config
	_state = state
	_status = status
	if _state!=null: _state.changed.connect(refresh)
	if _status!=null: _status.changed.connect(refresh)
	for field in ["tagline","payment_note","recovery_note","description","motto"]:
		get(field).text = str(config.get(field,""))
	refresh()

func refresh(notice := "") -> void:
	if _state==null or _status==null or _config.is_empty():
		confirm_button.disabled = true
		return
	var preview := MapClinicTreatment.preview(_state,_status,_config)
	if not preview.has("current"):
		message.text = preview.error
		message.show()
		payment_notes.hide()
		confirm_button.disabled = true
		_hover(false)
		return
	var maximum := EffectSystem.number_text(preview.maximum)
	var current_color := "86e79a" if preview.gain<=0 else "ff756b"
	current_label.text = "[center][color=#%s]%s[/color] / %s[/center]" % [current_color,EffectSystem.number_text(preview.current),maximum]
	after_label.text = "[center][color=#86e79a]%s[/color] / %s[/center]" % [maximum,maximum]
	gain_label.text = "+"+EffectSystem.number_text(preview.gain)
	fee_label.text = str(preview.fee)
	confirm_button.disabled = not preview.error.is_empty()
	confirm_label.text = "无需诊治" if preview.gain<=0 else "确认诊治"
	confirm_button.mouse_default_cursor_shape = CURSOR_ARROW if confirm_button.disabled else CURSOR_POINTING_HAND
	message.text = preview.error if not preview.error.is_empty() else notice
	message.visible = not message.text.is_empty()
	payment_notes.visible = message.text.is_empty()
	_hover(confirm_button.is_hovered())

func _hover(hovered: bool) -> void:
	confirm_label.add_theme_color_override("font_color",Color.BLACK if hovered and not confirm_button.disabled else Color.WHITE)
