class_name MapCalendarReadout
extends Control

const TextureMetrics := preload("res://scripts/map/map_texture_metrics.gd")
const BANNER_WIDTH := 390.0
const BANNER_SCALE := 0.9
# Source-image coordinates: open ribbon between the two mountain feet.
const TEXT_AREA := Rect2(250,110,366,64)

var caption: Label
var artwork: TextureRect
var source_region: Rect2

func _init() -> void:
	name = "MapCalendarReadout"
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_STOP
	var texture := load("res://assets/UI-title-time.webp") as Texture2D
	source_region = Rect2(TextureMetrics.inspect(texture).visible_rect)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = source_region
	artwork = TextureRect.new()
	artwork.texture = atlas
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption = Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi","楷体","STKaiti","serif"])
	caption.add_theme_font_override("font",font)
	caption.add_theme_color_override("font_color",Color("e4d8b9"))
	add_child(caption)

func present(record: Dictionary) -> void:
	caption.text = WorldCalendar.date_text(record).trim_prefix(str(WorldCalendar.rules().world_name)+"·")
	tooltip_text = WorldCalendar.date_text(record,true)

func layout_for(view_size: Vector2, header_height: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var factor := view_size.x/1920.0
	var original_size := source_region.size*(BANNER_WIDTH*factor/source_region.size.x)
	var original_position := Vector2(roundf(view_size.x-original_size.x-16*factor),roundf(header_height+factor))
	var art_scale := BANNER_WIDTH*factor/source_region.size.x*BANNER_SCALE
	caption.add_theme_font_size_override("font_size",maxi(1,roundi(17*factor)))
	size = source_region.size*art_scale
	position = original_position+(original_size-size)*0.5
	caption.position = (TEXT_AREA.position-source_region.position)*art_scale
	caption.size = TEXT_AREA.size*art_scale
