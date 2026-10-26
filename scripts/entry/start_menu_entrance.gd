extends Control
## Presentation timing only; final anchors remain the configured menu layout.
const DURATION := 0.85
var active := true
var _page: Control
var _veil: ColorRect
var _titles: Array[Control] = []
var _buttons: Array[BaseButton] = []
var _started := 0
var _elapsed := 0.0

func configure(page: Control) -> void:
	_page = page
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titles.assign([page.logo, page.tagline])
	_buttons.assign([page.continue_button, page.primary_button])
	_buttons.append_array(page.menu_buttons)
	_veil = ColorRect.new()
	_veil.name = "EntranceBlack"
	_veil.color = Color.BLACK
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_veil)
	page.move_child(_veil, page.logo.get_index())
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_started = Time.get_ticks_usec()
	page.resized.connect(_refresh_pose)
	_advance_elapsed(0.0)

func _process(_delta: float) -> void:
	if _page != null and active:
		_advance_elapsed(float(Time.get_ticks_usec() - _started) / 1000000.0)

func _advance_elapsed(seconds: float) -> void:
	_elapsed = clampf(seconds, 0.0, DURATION)
	_refresh_pose()
	if _elapsed >= DURATION:
		active = false
		set_process(false)
		_veil.hide()

func _refresh_pose() -> void:
	var title_alpha := smoothstep(0.15, 0.70, _elapsed)
	var button_alpha := smoothstep(0.35, DURATION, _elapsed)
	var distance := 8.0 * minf(_page.size.x / 2560.0, _page.size.y / 1440.0)
	_veil.modulate.a = 1.0 - smoothstep(0.0, 0.6, _elapsed)
	for title: Control in _titles:
		title.modulate.a = title_alpha
		title.offset_top = distance * (1.0 - title_alpha)
		title.offset_bottom = distance * (1.0 - title_alpha)
	for button: BaseButton in _buttons:
		button.modulate.a = button_alpha
		button.disabled = _elapsed < DURATION
	_page.version_label.modulate.a = button_alpha
	_page.error_label.modulate.a = button_alpha

func allows_input() -> bool:
	return not active
