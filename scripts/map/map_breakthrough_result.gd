extends Control
## Presents the committed result. Confirmation and review are commands to the parent.
signal review_requested
signal confirmed

var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/breakthrough_results.json"))
var canvas: Control
var artwork: TextureRect
var title_art: TextureRect
var review_art: TextureRect
var confirm_art: TextureRect
var summary: VBoxContainer
var current_value: Label
var target_value: Label
var completion_value: Label
var chance_value: Label
var progress_bar: ProgressBar
var gains_box: VBoxContainer
var gain_values: Dictionary = {}
var outcome_row: HBoxContainer
var notice: Label
var error_label: Label
var review_button: Button
var confirm_button: Button

func _init() -> void:
	name="BreakthroughResult"
	mouse_filter=Control.MOUSE_FILTER_STOP
	theme=Theme.new()
	theme.default_font=preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
	theme.default_font_size=32
	hide()
	canvas=Control.new()
	canvas.size=Vector2(config.design_size[0],config.design_size[1])
	canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	artwork=TextureRect.new()
	artwork.size=canvas.size
	artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	artwork.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(artwork)
	title_art = _image(canvas)
	summary=VBoxContainer.new()
	summary.add_theme_constant_override("separation",8)
	canvas.add_child(summary)
	var value_row := _row(summary,"当前突破值")
	current_value=_label(value_row,"CurrentValue","",Color("ffd46f"))
	_label(value_row,"Separator","/")
	target_value=_label(value_row,"TargetValue","")
	progress_bar=ProgressBar.new()
	progress_bar.name="CompletionBar"
	progress_bar.show_percentage=false
	progress_bar.custom_minimum_size.y=18
	progress_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for kind: String in ["background","fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color=Color("101f29") if kind=="background" else Color("e8c16b")
		style.border_color=Color("6b654e") if kind=="background" else Color("fff1bb")
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		progress_bar.add_theme_stylebox_override(kind,style)
	summary.add_child(progress_bar)
	completion_value=_label(_row(summary,"完成度"),"Completion","")
	chance_value=_label(_row(summary,"本次成功率"),"TotalChance","",Color("b6f28b"))
	gains_box=VBoxContainer.new()
	gains_box.add_theme_constant_override("separation",12)
	canvas.add_child(gains_box)
	for entry: Dictionary in config.gain_rows:
		var row := _row(gains_box,str(entry.label))
		row.custom_minimum_size.y=54
		var icon := TextureRect.new()
		icon.texture=load(str(entry.icon))
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.custom_minimum_size=Vector2(44,44)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		row.move_child(icon,0)
		gain_values[entry.key]=_label(row,str(entry.key),"",Color("b6f28b"))
	outcome_row=_row(canvas,"突破结果")
	_label(outcome_row,"Outcome","× 未能突破",Color("ff525d"))
	notice=_label(canvas,"FailureNotice","本次突破值已清零。\n下次突破从0开始。")
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	error_label=_label(canvas,"ResultError","",Color("ffb19f"))
	error_label.add_theme_font_size_override("font_size",24)
	error_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_place(error_label,config.error_rect)
	review_button=_button("ReviewResult",func(): review_requested.emit())
	confirm_button=_button("ConfirmResult",func(): confirmed.emit())
	review_art = _image(review_button)
	confirm_art = _image(confirm_button)
	resized.connect(_layout)

func _image(parent: Node) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _place_art(image: TextureRect, definition: Dictionary, origin: Vector2) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = load(str(definition.texture))
	var region: Array = definition.region
	texture.region = Rect2(region[0],region[1],region[2],region[3])
	image.texture = texture
	_place(image,definition.rect)
	image.position -= origin

func _label(parent: Node, node_name: String, text: String, color := Color("e8edf4")) -> Label:
	var label := Label.new()
	label.name=node_name
	label.text=text
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _row(parent: Node, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y=48
	row.add_theme_constant_override("separation",10)
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	_label(row,"Caption",caption).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return row

func _button(node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name=node_name
	button.focus_mode=Control.FOCUS_NONE
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for kind in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
	button.pressed.connect(action)
	canvas.add_child(button)
	return button

func present(phase: String, result: Dictionary) -> void:
	if phase not in ["succeeded","failed"] or result.is_empty(): return
	var succeeded := phase=="succeeded"
	var layout: Dictionary=config.success if succeeded else config.failure
	artwork.texture=load(str(layout.texture))
	_place(summary,layout.summary_rect)
	_place(review_button,layout.review_rect)
	_place(confirm_button,layout.confirm_rect)
	title_art.visible = succeeded
	review_art.visible = succeeded
	confirm_art.visible = succeeded
	if succeeded:
		_place_art(title_art,layout.title_art,Vector2.ZERO)
		_place_art(review_art,layout.review_art,review_button.position)
		_place_art(confirm_art,layout.confirm_art,confirm_button.position)
	var known := int(result.progress)>=0
	current_value.text=String.num(float(result.progress)/100.0,2).trim_suffix(".0") if known else "—"
	target_value.text=String.num(float(result.target)/100.0,2).trim_suffix(".0")
	var completion := 100.0*float(result.progress)/float(result.target) if known else 0.0
	completion_value.text=String.num(completion,1).trim_suffix(".0")+"%" if known else "—"
	progress_bar.value=completion
	chance_value.text=String.num(float(result.chance)*100.0,1).trim_suffix(".0")+"%（合计）"
	gains_box.visible=succeeded
	outcome_row.visible=not succeeded
	notice.visible=not succeeded
	if succeeded:
		_place(gains_box,layout.gains_rect)
		for entry: Dictionary in config.gain_rows:
			gain_values[entry.key].text="+%d%s" % [int(result.gains[entry.key]),str(entry.get("suffix",""))]
	else:
		_place(outcome_row,layout.outcome_rect)
		_place(notice,layout.notice_rect)
		if not known: notice.text="旧记录未保存累计值。\n本次已清零，下次从0开始。"
		else: notice.text="本次突破值已清零。\n下次突破从0开始。"
	error_label.text=""
	show()
	_layout()

func _place(control: Control, rect: Array) -> void:
	control.position=Vector2(rect[0],rect[1])
	control.size=Vector2(rect[2],rect[3])

func _layout() -> void:
	var factor := minf(size.x/canvas.size.x,size.y/canvas.size.y)
	canvas.scale=Vector2.ONE*factor
	canvas.position=(size-canvas.size*factor)*0.5
