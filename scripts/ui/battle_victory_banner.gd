extends Control

signal dismissed

const DURATION := 1.5
const FADE_DURATION := 0.5
var _fade: Tween
var artwork: TextureRect
var timer: Timer
var paths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/victory_banners.json"))

func _init() -> void:
	name = "VictoryBanner"
	z_index = 45
	mouse_filter = MOUSE_FILTER_STOP
	hide()
	var shade := ColorRect.new()
	shade.name = "VictoryShade"
	shade.color = Color(0, 0, 0, 0.5)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	artwork = TextureRect.new()
	artwork.name = "VictoryArtwork"
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	artwork.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(artwork)
	timer = Timer.new()
	timer.one_shot = true
	timer.ignore_time_scale = true
	timer.wait_time = DURATION
	add_child(timer)
	timer.timeout.connect(dismiss)
	resized.connect(_layout)

func present(rank_id: String) -> void:
	reset()
	artwork.texture = BattleActionButton.trimmed_art(paths.get(rank_id, paths["base.cultivation.mortal"]))
	modulate.a = 0.0
	show()
	_layout()
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(self, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_callback(timer.start)

func reset() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
	timer.stop()
	hide()

func _layout() -> void:
	# Enlarge both dimensions by 50%, preserving the previous visual center.
	artwork.size = Vector2(size.x * 0.44, size.y * 0.34) * 1.5
	artwork.position = Vector2(size.x * 0.5, size.y * 0.43) - artwork.size * 0.5

func dismiss() -> void:
	if not visible: return
	reset()
	dismissed.emit()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		get_viewport().set_input_as_handled()
		if event.pressed: dismiss()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()
