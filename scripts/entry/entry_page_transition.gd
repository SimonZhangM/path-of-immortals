extends Control
## Presentation-only page turn. No draft or gameplay state is owned here.
signal finished

const DURATION := 0.4
const DISTANCE := 15.0
var active := false
var direction := 1
var progress := 0.0
var _background: TextureRect
var _shade: ColorRect
var _content: Control
var _reference := Vector2(2560, 1440)
var _old_layer: CanvasGroup
var _old_background: TextureRect
var _old_shade: ColorRect
var _midpoint: Callable
var _switched := false
var _started_usec := 0

func _ready() -> void:
	name = "PageTransition"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	set_process_input(false)
	resized.connect(_resize_layers)

func configure(background: TextureRect, shade: ColorRect, content: Control, reference: Vector2) -> void:
	_background = background
	_shade = shade
	_content = content
	_reference = reference
	# Composite the old background and its shade before fading, so the shade
	# does not darken both backgrounds independently during the dissolve.
	_old_layer = CanvasGroup.new()
	_old_layer.name = "OutgoingBackground"
	get_parent().add_child(_old_layer)
	get_parent().move_child(_old_layer, content.get_index())
	_old_background = TextureRect.new()
	_old_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_old_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_old_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_old_layer.add_child(_old_background)
	_old_shade = ColorRect.new()
	_old_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_old_layer.add_child(_old_shade)
	_old_layer.hide()
	_resize_layers()

func begin(next_background: Texture2D, shade_parameters: Dictionary, shade_visible: bool,
		page_direction: int, switch_page: Callable) -> bool:
	if active: return false
	_old_background.texture = _background.texture
	_old_shade.material = _shade.material.duplicate(true)
	_old_shade.visible = _shade.visible
	_old_layer.modulate = Color.WHITE
	_old_layer.show()
	_background.texture = next_background
	_shade.visible = shade_visible
	for key: String in shade_parameters:
		_shade.material.set_shader_parameter(key, shade_parameters[key])
	direction = 1 if page_direction > 0 else -1
	_midpoint = switch_page
	_switched = false
	progress = 0.0
	active = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()
	_started_usec = Time.get_ticks_usec()
	set_process(true)
	set_process_input(true)
	_apply_pose()
	return true

func _input(event: InputEvent) -> void:
	if active and (event is InputEventMouse or event is InputEventKey
			or event is InputEventScreenTouch or event is InputEventScreenDrag
			or event is InputEventJoypadButton or event is InputEventJoypadMotion
			or event is InputEventAction):
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_advance_elapsed(float(Time.get_ticks_usec() - _started_usec) / 1000000.0)

func _advance_elapsed(seconds: float) -> void:
	if not active: return
	progress = clampf(seconds / DURATION, 0.0, 1.0)
	if progress >= 0.5 and not _switched:
		_content.modulate.a = 0.0
		_switched = true
		_midpoint.call()
	_apply_pose()
	if progress < 1.0: return
	active = false
	set_process(false)
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_old_layer.hide()
	_old_background.texture = null
	_old_shade.material = null
	_midpoint = Callable()
	finished.emit()

func _apply_pose() -> void:
	if _content == null: return
	var incoming := progress >= 0.5
	var phase := (progress - 0.5) * 2.0 if incoming else progress * 2.0
	var eased := smoothstep(0.0, 1.0, phase)
	var factor := minf(size.x / _reference.x, size.y / _reference.y)
	_content.position = Vector2(direction * DISTANCE * factor * (1.0 - eased if incoming else -eased), 0)
	_content.modulate.a = eased if incoming else 1.0 - eased
	_old_layer.modulate.a = 1.0 - smoothstep(0.0, 1.0, progress)

func _resize_layers() -> void:
	if _old_layer == null: return
	_old_background.size = size
	_old_shade.size = size
	if active: _apply_pose()
