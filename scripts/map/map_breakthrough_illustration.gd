extends MapEventPicture
## The story-picture component owns both fades; this view only adds fullscreen input.
signal exit_started

func _init() -> void:
	super._init()
	name="BreakthroughIllustration"
	z_index=20
	mouse_filter=Control.MOUSE_FILTER_STOP
	fade_in_seconds=1.0
	fade_out_seconds=1.0
	frame.hide()

func present(texture: Texture2D) -> void:
	window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	previous_illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	configure(null,texture,[0,0,texture.get_width(),texture.get_height()])

func dismiss() -> void:
	if not requested_visible: return
	exit_started.emit()
	super.dismiss()

func handle_input(event: InputEvent) -> bool:
	if not is_visible_in_tree(): return false
	var advance: bool=event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		advance=event.pressed and not event.echo and (event.keycode==KEY_SPACE or event.physical_keycode==KEY_SPACE)
	if advance and requested_visible and _group_tween==null: dismiss()
	get_viewport().set_input_as_handled()
	return true
