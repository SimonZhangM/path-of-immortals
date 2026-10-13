extends Control
## Presentation-only controls. Inventory commands are saved by MapScreen.
signal requested(withdraw: bool, all_items: bool)
const BUTTON_VISIBLE_WIDTH := 140.0
const TextureMetrics := preload("res://scripts/map/map_texture_metrics.gd")
const SimpleTooltip := preload("res://scripts/ui/simple_tooltip.gd")
const PAIR_GAP := 40.0
const NEAR_EDGE_GAP := 50.0
const TOP_GAP := 8.0
const SIGN_SIDE_GAP := 8.0
var withdraw_button: TextureButton
var withdraw_all_button: TextureButton
var deposit_button: TextureButton
var deposit_all_button: TextureButton
var left_group: HBoxContainer
var right_group: HBoxContainer
var direction_art: TextureRect

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	name = "WarehouseActions"
	left_group = _group("WithdrawalActions")
	right_group = _group("DepositActions")
	withdraw_button = _button(left_group,"quchu","取出选中物品（整叠）",true,false)
	withdraw_all_button = _button(left_group,"quanbuquchu","全部取出（不受筛选影响）",true,true)
	deposit_button = _button(right_group,"cunru","存入选中物品（整叠）",false,false)
	deposit_all_button = _button(right_group,"quanbucunru","全部存入（保留正在使用的阵盘；不受筛选影响）",false,true)
	direction_art = TextureRect.new()
	direction_art.name = "WarehouseDirectionArtwork"
	direction_art.texture = _visible_art("res://assets/UI-title-cangku-shuangxiang.webp")
	direction_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	direction_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	direction_art.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	direction_art.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(direction_art)

func _visible_art(path: String) -> AtlasTexture:
	var source: Texture2D = load(path)
	var art := AtlasTexture.new()
	art.atlas = source
	# Ignore near-transparent export specks; keep the visible ornament/glow.
	art.region = TextureMetrics.inspect(source).visible_rect
	return art

func _group(node_name: String) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.name = node_name
	group.mouse_filter = MOUSE_FILTER_IGNORE
	group.add_theme_constant_override("separation", int(PAIR_GAP))
	add_child(group)
	return group

func _button(group: HBoxContainer, suffix: String, caption: String, withdraw: bool, all_items: bool) -> TextureButton:
	var button := TextureButton.new()
	button.name = suffix
	button.texture_normal = _visible_art("res://assets/UI-title-cangku-%s.webp" % suffix)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = button.texture_normal.get_size() * (BUTTON_VISIBLE_WIDTH / button.texture_normal.get_width())
	button.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.focus_mode = FOCUS_NONE
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.tooltip_text = caption
	SimpleTooltip.apply(button)
	group.add_child(button)
	button.pressed.connect(func(): requested.emit(withdraw,all_items))
	button.mouse_entered.connect(func(): _paint(button))
	button.mouse_exited.connect(func(): _paint(button))
	button.button_down.connect(func(): _paint(button,true))
	button.button_up.connect(func(): _paint(button))
	return button

func _paint(button: TextureButton, pressed: bool = false) -> void:
	button.modulate = Color(0.45,0.45,0.45,1) if button.disabled else (Color(0.8,0.8,0.8,1) if pressed else (Color(1.12,1.12,1.12,1) if button.is_hovered() else Color.WHITE))

func set_available(withdraw: bool, withdraw_all: bool, deposit: bool, deposit_all: bool) -> void:
	var buttons := [withdraw_button,withdraw_all_button,deposit_button,deposit_all_button]
	var values := [withdraw,withdraw_all,deposit,deposit_all]
	for index in buttons.size():
		buttons[index].disabled = not values[index]
		_paint(buttons[index])

func place_between(left: Rect2, right: Rect2) -> void:
	left_group.size = left_group.get_combined_minimum_size()
	right_group.size = right_group.get_combined_minimum_size()
	left_group.position = Vector2(left.end.x - NEAR_EDGE_GAP - left_group.size.x,left.position.y - TOP_GAP - left_group.size.y)
	right_group.position = Vector2(right.position.x + NEAR_EDGE_GAP,right.position.y - TOP_GAP - right_group.size.y)
	var gap_width := maxf(0,right.position.x - left.end.x)
	var art_size := direction_art.texture.get_size()
	# Keep its previous display scale; only correct the visible center.
	var prior_size := Vector2(TextureMetrics.inspect((direction_art.texture as AtlasTexture).atlas).used_rect.size)
	var factor := minf(maxf(0,gap_width - SIGN_SIDE_GAP * 2) / prior_size.x,minf(left.size.y,right.size.y) * 0.8 / prior_size.y)
	direction_art.size = art_size * factor
	direction_art.position = Vector2((left.end.x + right.position.x) * 0.5,left.get_center().y) - direction_art.size * 0.5
