class_name MapClinicDialog
extends Control

signal cancelled
signal dialogue_requested(action: String, topic: String)
signal treatment_requested

# Clinic uses the shop-sized authored canvas, without a trading catalog or wallet.
const FRAME := Rect2(32,32,1474,840)
const METRICS = preload("res://scripts/map/map_texture_metrics.gd")
# Preserve the three topic slots when the baked-in frames leave the background.
const TOPIC_ROW_RECT := Rect2(624,745,806,44)
const TOPIC_SEPARATION := 29
const TOPIC_WIDTH := (TOPIC_ROW_RECT.size.x-TOPIC_SEPARATION*2.0)/3.0
const TOPIC_ICON_RIGHT := [62.0,63.0,62.0]
var canvas: Control
var backing: TextureRect
var illustration: TextureRect
var picture_frame: TextureRect
var title_label: Label
var description_label: Label
var leave_button: Button
var treatment_tab: Button
var conversation_tab: Button
var treatment_content: MapClinicTreatmentView
var conversation_content: VBoxContainer
var conversation_options: HBoxContainer
var library: NpcDialogueLibrary
var dialogue_scroll: ScrollContainer
var dialogue_rows: VBoxContainer
var continue_button: Button
var topic_continue_hint: Label
var dialogue_note: Label
var topic_buttons: Dictionary = {}
var _loadout: MapLoadoutState
var _status: MapPlayerStatus
var _view: Dictionary = {}
var _render_version := 0
var mode := "conversation"
var _presentation: Dictionary = {}
var _kai := SystemFont.new()
var _hei := SystemFont.new()
var _topic_font := SystemFont.new()
var _continue_pointer_down := false
var _continue_press_position := Vector2.ZERO
# Presentation only: reading the last greeting line does not reveal topic cards.
var _greeting_id := ""
var _topics_opened := false

func _init() -> void:
	name = "MapClinicDialog"
	z_index = 42
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	oversampling_with_scale = OVERSAMPLING_WITH_SCALE_ENABLED
	hide()
	_kai.font_names = PackedStringArray(["KaiTi","楷体","STKaiti","serif"])
	_hei.font_names = PackedStringArray(["SimHei","黑体","Microsoft YaHei","sans-serif"])
	_topic_font.font_names = PackedStringArray(["HarmonyOS Sans SC","鸿蒙简体","sans-serif"])
	_topic_font.font_weight = 400
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.02,0.03,0.65)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	backing = _image(FRAME,null)
	title_label = _label(Rect2(704,107,465,70),52,_hei)
	title_label.add_theme_color_override("font_color",MapGatheringDialog.INK)
	description_label = _label(Rect2(624,181,792,40),23,_kai)
	leave_button = _button("离开医馆",Rect2(1218,107,171,57),27)
	leave_button.pressed.connect(func(): cancelled.emit())
	conversation_tab = _button("交谈",Rect2(624,233,192,49),28)
	treatment_tab = _button("诊治",Rect2(828,233,185,49),28)
	treatment_tab.pressed.connect(func(): set_mode("treatment"))
	conversation_tab.pressed.connect(func(): set_mode("conversation"))
	treatment_content = MapClinicTreatmentView.new()
	_place(treatment_content,Rect2(674,315,706,504))
	treatment_content.confirmed.connect(func(): treatment_requested.emit())
	conversation_content = _content_area("ConversationContent")
	conversation_options = HBoxContainer.new()
	conversation_options.name = "ConversationOptions"
	conversation_options.mouse_filter = MOUSE_FILTER_IGNORE
	conversation_options.add_theme_constant_override("separation",TOPIC_SEPARATION)
	_place(conversation_options,TOPIC_ROW_RECT)
	dialogue_scroll = ScrollContainer.new()
	dialogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogue_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	dialogue_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	conversation_content.add_child(dialogue_scroll)
	dialogue_rows = VBoxContainer.new()
	dialogue_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	dialogue_rows.add_theme_constant_override("separation",5)
	dialogue_scroll.add_child(dialogue_rows)
	dialogue_note = _label(Rect2(624,714,624,26),18,_kai)
	continue_button = _button("点击继续 ▸",Rect2(1217,790,177,26),21)
	continue_button.add_theme_font_override("font",_kai)
	continue_button.pressed.connect(request_continue)
	topic_continue_hint = _label(Rect2(1217,790,177,26),21,_kai)
	topic_continue_hint.text = "点击话题继续"
	topic_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	topic_continue_hint.hide()
	for index in 3:
		var slot := Control.new()
		slot.size_flags_horizontal = SIZE_EXPAND_FILL
		conversation_options.add_child(slot)
		var button := _button("",Rect2(),21)
		button.reparent(slot)
		button.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		button.add_theme_font_override("font",_topic_font)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.add_theme_constant_override("outline_size",1)
		# Frame and icon share the button's visibility, including the greeting gate.
		var topic_frame := TextureRect.new()
		topic_frame.name = "TopicFrame"
		topic_frame.texture = load("res://assets/UI-dialo-topic.webp")
		topic_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		topic_frame.mouse_filter = MOUSE_FILTER_IGNORE
		topic_frame.show_behind_parent = true
		button.add_child(topic_frame)
		topic_frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		button.hide()
		# Leave the frame's speech icon clear on the left.
		button.add_theme_stylebox_override("normal",_topic_style(false))
		button.add_theme_stylebox_override("hover",_topic_style(true))
		button.pressed.connect(func():
			if index>=_view.get("topics",[]).size(): return
			var topic_id: String = _view.topics[index].id
			if topic_id==_view.get("selected","") and _view.get("can_continue",false):
				request_continue()
			else:
				dialogue_requested.emit("select",topic_id)
		)
		topic_buttons[index] = button
	resized.connect(_layout)

func _place(control: Control, rect: Rect2) -> void:
	canvas.add_child(control)
	control.position = rect.position-FRAME.position
	control.size = rect.size

func _content_area(node_name: String) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.name = node_name
	content.mouse_filter = MOUSE_FILTER_IGNORE
	_place(content,Rect2(624,308,806,399))
	return content

func _image(rect: Rect2, texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	_place(image,rect)
	return image

func _label(rect: Rect2, font_size: int, font: Font) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("f8ecc8"))
	_place(label,rect)
	return label

func _button(text: String, rect: Rect2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = FOCUS_NONE
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_override("font",_hei)
	button.add_theme_font_size_override("font_size",font_size)
	for state_name in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state_name,Color("f8ecc8"))
	for kind in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
	_place(button,rect)
	return button

func _style_tab(button: Button, selected: bool) -> void:
	button.add_theme_color_override("font_color",Color("fff4c9") if selected else Color("e5dcc5"))
	button.add_theme_color_override("font_hover_color",Color("fffbea"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92,0.73,0.35,0.28)
	style.border_color = Color("ffe4a1")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(1.0,0.78,0.35,0.17)
	style.shadow_size = 5
	button.add_theme_stylebox_override("normal",style if selected else StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover",style)

func present(event: Dictionary, loadout: MapLoadoutState = null, status: MapPlayerStatus = null) -> void:
	_continue_pointer_down = false
	_greeting_id = ""
	_topics_opened = false
	_loadout = loadout
	_status = status
	treatment_content.configure(event.get("treatment",{}),loadout,status)
	_view = {"rows":[],"topics":[],"can_continue":false,"selected":"welcome"}
	for child: Node in dialogue_rows.get_children(): child.free()
	for button: Button in topic_buttons.values(): button.hide()
	dialogue_note.text = ""
	library = null
	if event.has("dialogue"):
		library = NpcDialogueLibrary.new()
		var error := library.load_file(event.dialogue)
		if not error.is_empty():
			dialogue_note.text = error
			library = null
	_presentation = event.presentation.duplicate(true)
	if library!=null and _presentation.has("conversation_portrait"):
		library.definition.portrait = _presentation.conversation_portrait
		library.definition.erase("portrait_region")
	if is_instance_valid(illustration): illustration.free()
	if is_instance_valid(picture_frame): picture_frame.free()
	var frame_texture := AtlasTexture.new()
	frame_texture.atlas = load(_presentation.frame)
	frame_texture.region = METRICS.inspect(frame_texture.atlas).visible_rect
	var rect := Rect2(Vector2(349,451)-frame_texture.get_size()*0.5,frame_texture.get_size())
	illustration = _image(rect.grow(-5),load(_presentation.illustration))
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration.clip_contents = true
	picture_frame = _image(rect,frame_texture)
	title_label.text = event.title
	title_label.position.y = float(_presentation.get("title_center_y",133.0))+1.0-title_label.size.y*0.5-FRAME.position.y
	description_label.text = event.description
	# Keep the full introduction on the authored single line, fitting long copy.
	var font_size := 23
	while font_size>16 and _kai.get_string_size(event.description,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>792:
		font_size -= 1
	description_label.add_theme_font_size_override("font_size",font_size)
	leave_button.text = event.leave_label
	set_mode("conversation")
	show()
	_layout()
	refresh_dialogue()

func set_mode(value: String) -> void:
	if value not in ["conversation","treatment"]: return
	_continue_pointer_down = false
	mode = value
	treatment_content.visible = mode=="treatment"
	if mode=="treatment": treatment_content.refresh()
	conversation_content.visible = mode=="conversation"
	conversation_options.visible = mode=="conversation"
	dialogue_note.visible = mode=="conversation"
	_refresh_continue_hint()
	_style_tab(treatment_tab,mode=="treatment")
	_style_tab(conversation_tab,mode=="conversation")
	var atlas := AtlasTexture.new()
	var path: String = _presentation.get("treatment_background",_presentation.get("background","")) if mode=="treatment" else _presentation.get("background","")
	if not path.is_empty():
		atlas.atlas = load(path)
		atlas.region = FRAME
		backing.texture = atlas
	if mode=="conversation" and visible: dialogue_requested.emit("after_treatment","")

func _topic_style(selected: bool, left_margin: float = 72.5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9,0.72,0.32,0.16 if selected else 0)
	style.border_color = Color("ffe4a1")
	style.set_border_width_all(1 if selected else 0)
	style.set_corner_radius_all(5)
	style.content_margin_left = left_margin
	style.content_margin_right = 4
	return style

func refresh_dialogue(error := "") -> void:
	if library==null or _loadout==null or _status==null: return
	var journal_error := ""
	if _loadout.narrative.npcs.has(library.definition.id): journal_error = library.journal_error(_loadout.narrative.npcs[library.definition.id])
	_view = DialogueJournal.view(_loadout.narrative,library,_loadout.map_visited) if journal_error.is_empty() else {"rows":[],"topics":[],"can_continue":false,"selected":"welcome"}
	var greeting_id := ""
	if _view.selected in ["welcome","greeting"] and not _view.rows.is_empty():
		greeting_id = _view.rows[0].segment_id
	if greeting_id!=_greeting_id or _view.can_continue: _topics_opened = false
	_greeting_id = greeting_id
	for child: Node in dialogue_rows.get_children(): child.free()
	for row: Dictionary in _view.rows:
		var lines := DialogueBubble.wrap(row.text)
		for start in range(0,lines.size(),3):
			var bubble := DialogueBubble.new()
			bubble.configure(row.speaker,lines.slice(start,start+3),library,_status,DialogueJournal.full_name(_loadout.narrative))
			dialogue_rows.add_child(bubble)
	for index: int in topic_buttons:
		var button: Button = topic_buttons[index]
		button.visible = index<_view.topics.size() and not _waiting_to_open_topics()
		if not button.visible: continue
		var topic: Dictionary = _view.topics[index]
		button.text = topic.label
		var font_size := 21
		var left_margin := float(TOPIC_ICON_RIGHT[index])+_topic_font.get_string_size("汉",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5
		while font_size>16 and _topic_font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>TOPIC_WIDTH-left_margin-4:
			font_size -= 1
			left_margin = float(TOPIC_ICON_RIGHT[index])+_topic_font.get_string_size("汉",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5
		button.add_theme_font_size_override("font_size",font_size)
		button.add_theme_stylebox_override("normal",_topic_style(topic.id==_view.selected,left_margin))
		for state_name in ["hover","pressed","hover_pressed"]:
			button.add_theme_stylebox_override(state_name,_topic_style(true,left_margin))
		var badge := button.get_node_or_null("Unread") as Label
		if badge==null:
			badge = Label.new()
			badge.name = "Unread"
			badge.text = "新"
			badge.mouse_filter = MOUSE_FILTER_IGNORE
			badge.add_theme_font_override("font",_kai)
			badge.add_theme_font_size_override("font_size",15)
			badge.add_theme_color_override("font_color",Color.WHITE)
			button.add_child(badge)
			badge.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
			badge.position = Vector2(26,4)
		badge.visible = topic.new
	_refresh_continue_hint()
	dialogue_note.text = ""
	var npc: Dictionary = _loadout.narrative.npcs.get(library.definition.id,{})
	for id: String in npc.get("done",[]):
		var segment: Dictionary = library.segments.get(id,{})
		if segment.get("topic","")!=_view.selected: continue
		for clue: String in segment.get("clues",[]):
			if _loadout.narrative.clues.has(clue): dialogue_note.text = "已记下线索："+_loadout.narrative.clues[clue]
	if not error.is_empty(): dialogue_note.text = error
	if not journal_error.is_empty(): dialogue_note.text = journal_error
	_render_version += 1
	_scroll_to_latest.call_deferred(_render_version)

func _scroll_to_latest(version: int) -> void:
	await get_tree().process_frame
	if version==_render_version: dialogue_scroll.scroll_vertical = int(dialogue_scroll.get_v_scroll_bar().max_value)

func _refresh_continue_hint() -> void:
	var reading: bool = _view.get("can_continue",false)
	var opening := _waiting_to_open_topics()
	continue_button.text = "点击开启话题" if opening else "点击继续 ▸"
	continue_button.visible = mode=="conversation" and (reading or opening)
	var pending_topic := false
	for topic: Dictionary in _view.get("topics",[]):
		if topic.id==_view.get("selected","") and not topic.get("history",true):
			pending_topic = true
	topic_continue_hint.visible = mode=="conversation" and not reading and not opening and pending_topic

func _waiting_to_open_topics() -> bool:
	return not _greeting_id.is_empty() and not _topics_opened and not _view.get("can_continue",false) and not _view.get("topics",[]).is_empty()

func _layout() -> void:
	var factor := minf(size.x/1920.0,size.y/1080.0)*0.9
	canvas.size = FRAME.size
	canvas.scale = Vector2.ONE*factor
	canvas.position = ((size-FRAME.size*factor)*0.5).round()

func _gui_input(_event: InputEvent) -> void:
	accept_event()

func request_continue() -> void:
	if not is_visible_in_tree() or mode!="conversation": return
	if _waiting_to_open_topics():
		_topics_opened = true
		refresh_dialogue()
	elif _view.get("can_continue",false):
		dialogue_requested.emit("advance","")

# Called by the modal controller before GUI delivery, so even the scroll area
# and illustrations can advance. Native buttons retain their own input path.
func handle_continue_input(event: InputEvent) -> bool:
	if not is_visible_in_tree() or mode!="conversation": return false
	if event is InputEventKey:
		if event.pressed and not event.echo and (event.keycode==KEY_SPACE or event.physical_keycode==KEY_SPACE):
			request_continue()
			return true
		return false
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT: return false
	var eligible := canvas.get_global_rect().has_point(event.position) and not _over_button(canvas,event.position)
	if event.pressed:
		_continue_pointer_down = eligible and (_view.get("can_continue",false) or _waiting_to_open_topics())
		_continue_press_position = event.position
		return _continue_pointer_down
	var was_down := _continue_pointer_down
	_continue_pointer_down = false
	if was_down and eligible and event.position.distance_to(_continue_press_position)<=6.0:
		request_continue()
	return was_down

func _over_button(node: Node, point: Vector2) -> bool:
	if node is Control and not node.is_visible_in_tree(): return false
	if node is BaseButton and node.get_global_rect().has_point(point): return true
	for child: Node in node.get_children():
		if _over_button(child,point): return true
	return false
