class_name MapRewardDialog
extends Control

signal accept_requested

const DESIGN_SIZE := Vector2(540, 540)
var canvas: Control
var heading: Label
var card: MapInventoryItemCard
var accept_button: TextureButton
var error_label: Label
var pick_sound: AudioStreamPlayer

func _init() -> void:
	name = "MapRewardDialog"
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.65)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = DESIGN_SIZE
	add_child(canvas)
	var backing := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/UI-jiaohu-xiao.webp")
	# Crop only the large transparent canvas surrounding the authored frame.
	atlas.region = Rect2(200, 88, 512, 512)
	backing.texture = atlas
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.size = DESIGN_SIZE
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(backing)
	heading = _label("获得物品", Rect2(100, 54, 340, 62), 32, Color("f9f8c8"))
	heading.name = "RewardHeading"
	accept_button = TextureButton.new()
	accept_button.name = "AcceptReward"
	accept_button.texture_normal = load("res://assets/button-queren.webp")
	accept_button.ignore_texture_size = true
	accept_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	accept_button.position = Vector2(164, 423)
	accept_button.size = Vector2(212, 64)
	accept_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	accept_button.focus_mode = Control.FOCUS_NONE
	accept_button.pressed.connect(func(): accept_requested.emit())
	canvas.add_child(accept_button)
	var caption := _label("收下", Rect2(0, 0, 212, 64), 26, Color.WHITE, accept_button)
	caption.name = "AcceptCaption"
	error_label = _label("", Rect2(50, 388, 440, 32), 17, Color("ffb9a8"))
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pick_sound = AudioStreamPlayer.new()
	pick_sound.stream = GameAudio.STREAMS.pick
	pick_sound.volume_db = -4
	add_child(pick_sound)
	resized.connect(_layout)

func _label(text: String, rect: Rect2, font_size: int, color: Color, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimHei", "黑体", "Microsoft YaHei", "sans-serif"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	(canvas if parent == null else parent).add_child(label)
	return label

func present(record: Dictionary, category_name: String) -> void:
	if card != null:
		canvas.remove_child(card)
		card.queue_free()
	card = MapInventoryItemCard.new()
	card.configure(record, category_name)
	card.tooltip_text = ""
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_card_width(168)
	card.size = card.custom_minimum_size
	card.position = Vector2((DESIGN_SIZE.x - card.size.x) * 0.5, 151)
	canvas.add_child(card)
	card._layout()
	error_label.text = ""
	accept_button.disabled = false
	show()
	_layout()

func _layout() -> void:
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - DESIGN_SIZE * factor) * 0.5

func _gui_input(_event: InputEvent) -> void:
	# Only the explicit accept button advances this modal.
	accept_event()
