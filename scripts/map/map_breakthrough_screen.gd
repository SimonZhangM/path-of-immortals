extends Control
## Reads session state; sends commands without awarding growth or quest success.
signal change_requested
signal close_requested
signal result_confirmed
const BreakthroughBoard = preload("res://scripts/map/map_breakthrough_board.gd")
var background_art: TextureRect
var composition_art: TextureRect
var layout_reference: Dictionary
var stage: Control
var current_realm_art: TextureRect
var target_realm_art: TextureRect
var pause_art: TextureRect
var change_button: Button
var start_button: Button
var pause_button: Button
var exit_button: Button
var session: RefCounted
var assistance_view: VBoxContainer
var board_profiles: Dictionary
var board_reference: Control
var board_art: TextureRect
var character_art: TextureRect
var primary_art: TextureRect
var primary_start_art: TextureRect
var primary_running_art: TextureRect
var primary_complete_art: TextureRect
var result_view: Control
var completion_illustration: MapEventPicture
var completion_illustration_seen := false
var rotation_reference: Control
var circle_art: TextureRect
var loadout: MapLoadoutState
var board_view: BreakthroughBoard
var progress_art: TextureRect
var progress_fill: Control
var progress_value: HBoxContainer
var progress_current: Label
var progress_separator: Label
var progress_required: Label
var chance_value: Label
var remaining_value: Label
var efficiency_value: HBoxContainer
var efficiency_number: Label
var efficiency_unit: Label
var status_value: Label
var left_inscription: TextureRect
var right_inscription: TextureRect
var playback_controls: HBoxContainer
var playback_pause: Button
var speed_buttons: Dictionary = {}
var element_buffs: BattleStatusIcons

func _init() -> void:
	name = "MapBreakthroughScreen"
	z_index = 25
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	hide()
	background_art = TextureRect.new()
	background_art.name = "BackgroundArtwork"
	background_art.texture = load("res://assets/UI-tupo-bg.webp")
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_art)
	background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_reference = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/breakthrough_layout.json"))
	composition_art = TextureRect.new()
	composition_art.name = "CompositionArtwork"
	composition_art.texture = load(String(layout_reference.artwork))
	composition_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	composition_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	composition_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	composition_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(composition_art)
	composition_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scripts/map/map_breakthrough_art.gdshader")
	var area := _rect(layout_reference.bottom_buttons[0].rect)
	paint.set_shader_parameter("change_rect",Vector4(area.position.x/2560.0,area.position.y/1440.0,area.end.x/2560.0,area.end.y/1440.0))
	composition_art.material = paint
	stage = Control.new()
	stage.name = "DesignCanvas"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(2560,1440)
	add_child(stage)
	board_profiles = JSON.parse_string(FileAccess.get_file_as_string(layout_reference.central_board.profiles))
	board_reference = Control.new()
	board_reference.name = "BoardReference"
	board_reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board_layout := board_layout_for(board_profiles.reference_board_id)
	board_reference.position = _rect(board_layout.canvas_rect).position
	board_reference.size = _rect(board_layout.canvas_rect).size
	board_reference.set_meta("board_id",board_profiles.reference_board_id)
	stage.add_child(board_reference)
	character_art = _art("CharacterArtwork",layout_reference.central_character.rect)
	character_art.texture = load(String(layout_reference.central_character.texture))
	element_buffs=BattleStatusIcons.new()
	element_buffs.element_buffs_only=true
	element_buffs.show_all_for_testing=false
	stage.add_child(element_buffs)
	element_buffs.configure()
	element_buffs.name="ElementBuffs"
	element_buffs.hide()
	element_buffs.minimum_size_changed.connect(_layout_element_buffs)
	primary_start_art = _art("PrimaryStartArtwork",layout_reference.primary_action.rect)
	primary_start_art.texture = load(String(layout_reference.primary_action.start_art))
	primary_running_art = _art("PrimaryRunningArtwork",layout_reference.primary_action.rect)
	primary_running_art.texture = load(String(layout_reference.primary_action.running_art))
	primary_running_art.hide()
	primary_complete_art = _art("PrimaryCompleteArtwork",layout_reference.primary_action.rect)
	primary_complete_art.texture = load(String(layout_reference.primary_action.complete_art))
	primary_complete_art.hide()
	primary_art = primary_start_art
	rotation_reference = Control.new()
	rotation_reference.name = "RotatingCircleAnchor"
	rotation_reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotation_reference.position = _rect(layout_reference.primary_action.rotation_slot.rect).position
	rotation_reference.size = _rect(layout_reference.primary_action.rotation_slot.rect).size
	rotation_reference.pivot_offset = rotation_reference.size*0.5
	stage.add_child(rotation_reference)
	_build_circle_art()
	assistance_view = preload("res://scripts/map/map_breakthrough_assistance.gd").new()
	stage.add_child(assistance_view)
	current_realm_art = _art("CurrentRealm",layout_reference.realm_images.current.rect)
	target_realm_art = _art("TargetRealm",layout_reference.realm_images.target.rect)
	_build_inscriptions()
	_build_progress_art()
	pause_art = _art("PauseResumeArtwork",layout_reference.pause_resume.rect)
	change_button = _button("ChangeButton",layout_reference.bottom_buttons[0].rect)
	change_button.pressed.connect(func(): change_requested.emit())
	start_button = _button("StartButton",layout_reference.bottom_buttons[2].rect)
	start_button.pressed.connect(func():
		if session!=null: session.activate_primary())
	pause_button = _button("PauseButton",layout_reference.pause_resume.pause_hit_rect)
	pause_button.pressed.connect(func():
		if session!=null: session.set_paused(session.phase=="running"))
	exit_button = _button("ExitButton",layout_reference.pause_resume.exit_hit_rect)
	exit_button.pressed.connect(func(): close_requested.emit())
	_build_playback_controls()
	result_view=preload("res://scripts/map/map_breakthrough_result.gd").new()
	add_child(result_view)
	result_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_view.review_requested.connect(_hide_result)
	result_view.confirmed.connect(func(): result_confirmed.emit())
	resized.connect(_layout)
	_layout()

static func _rect(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])

func _build_playback_controls() -> void:
	var config: Dictionary=layout_reference.playback_controls
	playback_controls=HBoxContainer.new()
	playback_controls.name="PlaybackControls"
	playback_controls.position=_rect(config.rect).position
	playback_controls.size=_rect(config.rect).size
	playback_controls.add_theme_constant_override("separation",int(config.gap))
	stage.add_child(playback_controls)
	playback_pause=_playback_button("pause","暂停／继续",func():
		if session!=null: session.set_paused(session.phase=="running"))
	speed_buttons[0.5]=_playback_button("half","0.5倍速",func(): session.set_speed(0.5))
	speed_buttons[1.0]=_playback_button("play","正常播放",func(): session.play_normal())
	speed_buttons[2.0]=_playback_button("double","2倍速",func(): session.set_speed(2.0))
	speed_buttons[4.0]=_playback_button("quad","4倍速",func(): session.set_speed(4.0))

func _playback_button(symbol: String, caption: String, action: Callable) -> Button:
	var button := PlaybackButton.new()
	button.symbol=symbol
	button.text="0.5x" if symbol=="half" else ""
	button.tooltip_text=caption
	button.custom_minimum_size=Vector2.ONE*float(layout_reference.playback_controls.side)
	button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	button.focus_mode=Control.FOCUS_NONE
	button.toggle_mode=true
	button.add_theme_font_size_override("font_size",13)
	for style in ["normal","hover","pressed","hover_pressed","disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color=Color("2d261f")
		box.border_color=Color("d7b477") if style in ["hover","pressed","hover_pressed"] else Color("796043")
		box.set_corner_radius_all(6)
		box.set_content_margin_all(0)
		box.set_border_width_all(2 if style in ["pressed","hover_pressed"] else 1)
		button.add_theme_stylebox_override(style,box)
	button.pressed.connect(action)
	playback_controls.add_child(button)
	return button

func _art(node_name: String, values: Array) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.position = _rect(values).position
	art.size = _rect(values).size
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(art)
	return art

func _button(node_name: String, values: Array) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = _rect(values).position
	button.size = _rect(values).size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for kind in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
	stage.add_child(button)
	return button

func _build_progress_art() -> void:
	# Empty/gold artwork, the white front and star share one source-space transform.
	var config: Dictionary = layout_reference.right_column.progress
	progress_fill=preload("res://scripts/map/map_breakthrough_progress.gd").new()
	progress_fill.configure(config)
	stage.add_child(progress_fill)
	progress_art=progress_fill.artwork
	progress_value=HBoxContainer.new()
	progress_value.name="ActualCultivation"
	progress_value.position=_rect(config.value_rect).position
	progress_value.size=_rect(config.value_rect).size
	progress_value.mouse_filter=Control.MOUSE_FILTER_IGNORE
	progress_value.add_theme_constant_override("separation",8)
	stage.add_child(progress_value)
	progress_current=_value_label("CurrentCultivation",[0,0,0,54],40)
	progress_separator=_value_label("ProgressSeparator",[0,0,0,54],40)
	progress_required=_value_label("RequiredCultivation",[0,0,0,54],40)
	for label: Label in [progress_current,progress_separator,progress_required]: label.reparent(progress_value)
	for label: Label in [progress_current,progress_required]:
		label.clip_text=true
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	progress_current.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	progress_required.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	progress_separator.text="/"
	progress_required.add_theme_color_override("font_color",Color(config.required_color))
	progress_value.hide()
	chance_value=_value_label("SuccessChance",config.chance_rect,70)
	_numeric_glow(chance_value)
	remaining_value=_value_label("RemainingDays",config.remaining_rect,40)
	efficiency_value=HBoxContainer.new()
	efficiency_value.name="CultivationRate"
	efficiency_value.position=_rect(config.efficiency_rect).position
	efficiency_value.size=_rect(config.efficiency_rect).size
	efficiency_value.alignment=BoxContainer.ALIGNMENT_CENTER
	efficiency_value.add_theme_constant_override("separation",6)
	efficiency_value.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(efficiency_value)
	efficiency_number=_value_label("RateNumber",[0,0,0,54],40)
	efficiency_number.reparent(efficiency_value)
	_numeric_glow(efficiency_number)
	efficiency_unit=_value_label("RateUnit",[0,0,0,54],40)
	efficiency_unit.text="/天"
	efficiency_unit.reparent(efficiency_value)
	status_value=_value_label("BreakthroughStatus",config.status_rect,24)
	status_value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_value.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	status_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT

func _build_inscriptions() -> void:
	var config: Dictionary=layout_reference.first_breakthrough_inscriptions
	left_inscription=_art("FirstBreakthroughLeftInscription",config.left.rect)
	right_inscription=_art("FirstBreakthroughRightInscription",config.right.rect)
	for view: TextureRect in [left_inscription,right_inscription]:
		view.texture=load(String(config.left.texture if view==left_inscription else config.right.texture))

func _numeric_glow(label: Label) -> void:
	label.add_theme_color_override("font_color",Color("c4ffb7"))
	label.add_theme_color_override("font_outline_color",Color("c4ffb7"))
	label.add_theme_constant_override("outline_size",1)
	label.add_theme_color_override("font_shadow_color",Color(0.35,1.0,0.25,0.42))
	label.add_theme_constant_override("shadow_outline_size",8)
	label.add_theme_constant_override("shadow_offset_x",0)
	label.add_theme_constant_override("shadow_offset_y",0)

func _value_label(node_name: String, values: Array, font_size: int) -> Label:
	var label := Label.new()
	label.name=node_name
	label.position=_rect(values).position
	label.size=_rect(values).size
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf"))
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e8e1d0"))
	label.add_theme_color_override("font_outline_color",Color("061d29"))
	label.add_theme_constant_override("outline_size",4)
	stage.add_child(label)
	return label

func _refresh_progress() -> void:
	var run: RefCounted=session.runtime
	var show_values: bool = run!=null and (int(loadout.growth.realm)==0 or run.phase=="succeeded")
	for control: Control in [progress_value,chance_value,remaining_value,efficiency_value]: control.visible=show_values
	status_value.hide()
	progress_fill.present(float(run.progress())/run.target() if show_values else 0.0,show_values and session.started)
	if run==null: return
	status_value.text=run.status_text()
	# Routine status stays hidden; rejected commands must explain the missing prerequisite.
	status_value.visible=not run.error.is_empty()
	if not show_values: return
	progress_current.text=CultivationGrowth.display(run.progress()/100.0)
	progress_required.text=str(int(run.target()/100))
	chance_value.text=String.num(run.success_chance()*100.0,1).trim_suffix(".0")+"%"
	remaining_value.text="%d天" % run.remaining_days()
	efficiency_number.text=CultivationGrowth.display(run.recent_gain()/100.0)

func _build_circle_art() -> void:
	var config: Dictionary = layout_reference.primary_action.rotation_slot
	var texture: Texture2D = load(String(config.texture))
	var bounds := Rect2(preload("res://scripts/map/map_texture_metrics.gd").inspect(texture).visible_rect)
	var factor: float = float(config.visible_side)/maxf(bounds.size.x,bounds.size.y)
	circle_art = TextureRect.new()
	circle_art.name = "RotatingCircleArtwork"
	circle_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	circle_art.texture = texture
	circle_art.size = texture.get_size()*factor
	circle_art.position = rotation_reference.size*0.5-bounds.get_center()*factor
	circle_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	circle_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotation_reference.add_child(circle_art)
	rotation_reference.hide()

func refresh_rotation() -> void:
	if session==null: return
	if board_view!=null: board_view.refresh_cooldown_animation()
	rotation_reference.visible = session.started and session.phase not in ["succeeded","failed"]
	var degrees_per_second: float = layout_reference.primary_action.rotation_slot.degrees_per_second
	rotation_reference.rotation = deg_to_rad(fposmod(float(session.elapsed_usec)/1000000.0*degrees_per_second,360.0))

func bind_session(value: RefCounted, equipment: MapLoadoutState) -> void:
	session = value
	loadout = equipment
	board_view = BreakthroughBoard.new()
	board_view.name = "PlayerLoadout"
	board_view.configure(loadout)
	board_view.bind_session(session)
	board_reference.add_child(board_view)
	board_art = board_view._board_art
	loadout.changed.connect(_sync_board_layout)
	_sync_board_layout()
	assistance_view.configure(layout_reference.assistance,loadout.registry)
	session.changed.connect(refresh)
	session.result_requested.connect(show_result)
	var sound_view := preload("res://scripts/map/map_breakthrough_audio.gd").new()
	sound_view.name="BreakthroughAudio"
	add_child(sound_view)
	sound_view.configure(session,self,loadout.registry)
	refresh()

func bind_feedback_header(header: Control) -> void:
	var feedback := preload("res://scripts/map/map_breakthrough_feedback.gd").new()
	feedback.name="GainFeedback"
	stage.add_child(feedback)
	feedback.configure(session,board_view,progress_fill,header)

func _sync_board_layout() -> void:
	if loadout==null or board_view==null: return
	var profile := board_layout_for(loadout.board.id)
	var provisional := profile.is_empty()
	var frame := _rect(board_profiles.unconfigured_viewport if provisional else profile.canvas_rect)
	board_reference.position = frame.position
	board_reference.size = frame.size
	board_reference.set_meta("board_id",loadout.board.id)
	board_reference.set_meta("provisional_layout",provisional)
	# BoardLayout's intrinsic scale stays shared with the bag; this view owns
	# only its destination canvas, so artwork and footprints remain aligned.
	board_view.size = frame.size/loadout.board.display_scale
	board_view.position = (frame.size-board_view.size)*0.5
	board_view._layout_items()

func board_layout_for(board_id: String) -> Dictionary:
	# Each stable board ID has its own breakthrough layout; no borrowed fallback.
	return board_profiles.profiles.get(board_id,{}).duplicate(true)

func present_pair(index: int) -> void:
	if index<0 or index>=layout_reference.realm_images.pairs.size(): return
	var pair: Array = layout_reference.realm_images.pairs[index]
	current_realm_art.texture = load(String(layout_reference.realm_images.textures[pair[0]]))
	target_realm_art.texture = load(String(layout_reference.realm_images.textures[pair[1]]))
	assistance_view.visible = index==int(layout_reference.assistance.pair_index)
	left_inscription.visible=index==int(layout_reference.first_breakthrough_inscriptions.pair_index)
	right_inscription.visible=left_inscription.visible

func refresh() -> void:
	if session==null: return
	var completed: bool=session.phase in ["succeeded","failed"]
	if not session.started: completion_illustration_seen=false
	if not completed and result_view.visible: _hide_result()
	present_pair(session.pair_index)
	change_button.disabled = not session.can_adjust()
	change_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if change_button.disabled else Control.CURSOR_POINTING_HAND
	(composition_art.material as ShaderMaterial).set_shader_parameter("change_disabled",change_button.disabled)
	start_button.disabled = session.phase!="ready" and not completed
	primary_start_art.visible = not session.started
	primary_running_art.visible = session.started and not completed
	primary_complete_art.visible = completed
	primary_art = primary_complete_art if completed else (primary_running_art if session.started else primary_start_art)
	refresh_rotation()
	pause_button.disabled = session.phase not in ["running","paused"]
	playback_pause.disabled=pause_button.disabled
	playback_pause.set_pressed_no_signal(session.phase=="paused")
	playback_pause.tooltip_text="继续突破" if session.phase=="paused" else "暂停突破"
	for rate: float in speed_buttons:
		speed_buttons[rate].disabled=session.phase in ["failed","succeeded"]
		speed_buttons[rate].set_pressed_no_signal(is_equal_approx(rate,session.speed))
	pause_art.texture = load(String(layout_reference.pause_resume.resume_art if session.phase=="paused" else layout_reference.pause_resume.pause_art))
	_refresh_progress()
	_refresh_element_buffs()

func show_result() -> void:
	if session==null or session.runtime==null or session.phase not in ["succeeded","failed"]: return
	ItemTooltipHost.for_control(self).dismiss()
	if session.phase=="succeeded" and session.pair_index==0 and not completion_illustration_seen:
		show_completion_illustration()
		return
	present_result(session.phase,session.runtime.result_snapshot())

func present_result(phase: String, result: Dictionary) -> void:
	result_view.present(phase,result)
	composition_art.hide()
	stage.hide()

func _hide_result() -> void:
	result_view.hide()
	composition_art.show()
	stage.show()

func show_completion_illustration() -> void:
	if completion_illustration==null:
		completion_illustration=preload("res://scripts/map/map_breakthrough_illustration.gd").new()
		add_child(completion_illustration)
		completion_illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		completion_illustration.exit_started.connect(func(): present_result(session.phase,session.runtime.result_snapshot()))
		completion_illustration.dismissed.connect(func(): completion_illustration_seen=true)
	completion_illustration.present(load(str(result_view.config.first_qi_illustration)))

func handle_completion_illustration_input(event: InputEvent) -> bool:
	return completion_illustration!=null and completion_illustration.handle_input(event)

func _refresh_element_buffs() -> void:
	var actor: PartyMemberState=session.runtime.status_member() if session.runtime!=null else null
	element_buffs.refresh(actor)
	_layout_element_buffs()

func _layout_element_buffs() -> void:
	if element_buffs==null or not element_buffs.visible: return
	var area := _rect(layout_reference.element_buffs.rect)
	var extent := element_buffs.get_combined_minimum_size()
	var factor := minf(1.0,minf(area.size.x/maxf(1.0,extent.x),area.size.y/maxf(1.0,extent.y)))
	element_buffs.size=extent
	element_buffs.scale=Vector2.ONE*factor
	element_buffs.position=area.position+(area.size-extent*factor)*0.5

func _layout() -> void:
	if stage==null: return
	var factor := minf(size.x/2560.0,size.y/1440.0)
	stage.scale = Vector2.ONE*factor
	stage.position = (size-stage.size*factor)*0.5
