extends CanvasLayer
## Snapshot of the outgoing page over the live incoming page; no character state.
const DURATION := 0.4
var active := true
var progress := 0.0
var snapshot: TextureRect
var _started := 0
var _fading := false

func begin(destination: String, source: Control) -> void:
	layer = 100
	var packed := load(destination) as PackedScene
	if packed == null:
		_fail(source)
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()
	await RenderingServer.frame_post_draw
	var texture := ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	snapshot = TextureRect.new()
	snapshot.texture = texture
	snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	snapshot.stretch_mode = TextureRect.STRETCH_SCALE
	snapshot.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(snapshot)
	snapshot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var result := get_tree().change_scene_to_packed(packed)
	if result != OK:
		_fail(source)
		return
	await get_tree().scene_changed
	_started = Time.get_ticks_usec()
	_fading = true

func _fail(source: Control) -> void:
	if is_instance_valid(source):
		source._navigating = false
		source.error_label.text = "页面打开失败，请检查场景文件。"
		source.error_label.show()
	active = false
	queue_free()

func _input(event: InputEvent) -> void:
	if active and (event is InputEventMouse or event is InputEventKey
			or event is InputEventScreenTouch or event is InputEventScreenDrag
			or event is InputEventJoypadButton or event is InputEventJoypadMotion
			or event is InputEventAction):
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _fading:
		_advance_elapsed(float(Time.get_ticks_usec() - _started) / 1000000.0)

func _advance_elapsed(seconds: float) -> void:
	progress = clampf(seconds / DURATION, 0.0, 1.0)
	snapshot.modulate.a = 1.0 - smoothstep(0.0, 1.0, progress)
	if progress >= 1.0:
		active = false
		_fading = false
		queue_free()
