extends CanvasLayer
## Rendering/input only. The router owns loading and authoritative save validation.
const FADE_SECONDS := 0.4
var cover: ColorRect
var cover_image: Texture2D
var backdrop: TextureRect
var caption: Label
var ellipsis: Label
var row: HBoxContainer
var elapsed := 0.0
var ticks := 0
var max_frame_ms := 0.0
var _last_tick := 0
var _fading := false

static func show_for(tree: SceneTree, image: Texture2D = null) -> CanvasLayer:
	var existing := tree.root.get_node_or_null("GameLoadingOverlay")
	if existing != null: return existing
	var overlay = load("res://scripts/entry/game_loading_overlay.gd").new()
	overlay.name = "GameLoadingOverlay"
	overlay.cover_image = image
	tree.root.add_child(overlay)
	return overlay

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	cover = ColorRect.new()
	cover.color = Color.BLACK
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if cover_image != null:
		backdrop = TextureRect.new()
		backdrop.texture = cover_image
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(backdrop)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimSun", "宋体", "Noto Serif CJK SC", "serif"])
	for text in ["正在进入苍澜界", "…"]:
		var label := Label.new()
		label.text = text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", font)
		label.add_theme_color_override("font_color", Color("e6d5aa"))
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.add_theme_constant_override("shadow_outline_size", 3)
		row.add_child(label)
	caption = row.get_child(0)
	ellipsis = row.get_child(1)
	cover.resized.connect(_layout)
	_layout()
	_last_tick = Time.get_ticks_usec()

func _layout() -> void:
	var font_size := maxi(18, roundi(36.0 * minf(cover.size.x/2560.0, cover.size.y/1440.0)))
	caption.add_theme_font_size_override("font_size", font_size)
	ellipsis.add_theme_font_size_override("font_size", font_size)

func _process(delta: float) -> void:
	elapsed += delta
	ticks += 1
	var now := Time.get_ticks_usec()
	if not _fading: max_frame_ms = maxf(max_frame_ms, (now-_last_tick)/1000.0)
	_last_tick = now
	ellipsis.modulate.a = 0.3 + 0.7 * (0.5 + 0.5 * sin(elapsed * TAU / 1.2))

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func reveal() -> void:
	_fading = true
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(cover, "modulate:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	queue_free()
