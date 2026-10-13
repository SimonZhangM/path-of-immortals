extends Control

var dialog: MapGatheringDialog
var result_dialog: Control
var reopen: Button
var model: MapLoadoutState

func _ready() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/gamemap-qingshihewan.webp")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	reopen = Button.new()
	reopen.text = "打开采集弹窗"
	reopen.custom_minimum_size = Vector2(250,58)
	reopen.add_theme_font_size_override("font_size", 26)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.add_child(reopen)
	dialog = MapGatheringDialog.new()
	add_child(dialog)
	dialog.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	result_dialog = load("res://scripts/map/map_gathering_result_dialog.gd").new()
	add_child(result_dialog)
	result_dialog.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var registry := ContentRegistry.new()
	if not registry.load_base_content():
		push_error("采集预览物品注册失败。")
		return
	var built := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	if not built.error.is_empty():
		push_error(built.error)
		return
	model = built.state
	dialog.bind_herb(model.records["base.material.zhixuecao"],model)
	dialog.gathering_requested.connect(func(forecast: Dictionary):
		dialog.hide()
		var record: Dictionary = model.records["base.material.zhixuecao"].duplicate(true)
		record.quantity = forecast.total_min
		result_dialog.present_herb(record,model)
	)
	result_dialog.cancelled.connect(func(): result_dialog.hide())
	result_dialog.accept_requested.connect(func(): result_dialog.hide())
	reopen.pressed.connect(func(): dialog.present("林间草坡"))
	dialog.present("林间草坡")
