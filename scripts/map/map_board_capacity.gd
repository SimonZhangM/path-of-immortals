extends TextureRect
## Artwork and numeric slot share original-image coordinates.
const ART_PATH := "res://assets/UI-title-rongliang-zhange.webp"
const NUMBER_AREA := Rect2(610, 128, 236, 70)
const NUMBER_SIZE := 86
const USED_COLOR := Color("b18b43")
const TOTAL_COLOR := Color("1f3f3b")
var occupied := 0
var total := 0
var text: String:
	get: return "%d/%d" % [occupied, total]
var number_font := SystemFont.new()
var number_area := Rect2(640,128,260,70)
var preview_capacity := Vector2i(-1,-1)
var font_size_adjustment := 0
var number_offset := Vector2.ZERO
var storage_banner := false

func displayed_capacity() -> Vector2i:
	return preview_capacity if preview_capacity.x >= 0 and preview_capacity.y >= 0 else Vector2i(occupied,total)

func set_art(path: String) -> void:
	var source: Texture2D = load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = preload("res://scripts/map/map_texture_metrics.gd").inspect(source).visible_rect
	texture = atlas
	storage_banner = path.ends_with("chuwudai.webp") or path.ends_with("kucun.webp")
	# Updated bag/warehouse artwork shares the same blank numeric well. Keep
	# the slash centered here, independent of digit count; board art is unchanged.
	number_area = Rect2(580,106,330,100) if storage_banner else Rect2(640,128,260,70)
	number_offset = Vector2.ZERO
	queue_redraw()

func align_storage_heading() -> void:
	size = texture.get_size() * (50.0 / texture.get_height())
	# The new pendant extends below the banner. Align the banner body rather
	# than the entire texture bounding box with the adjacent title (center y18).
	position.y = 18.0 - number_center().y

func _init() -> void:
	name = "BoardCapacityArtwork"
	texture = BattleActionButton.trimmed_art(ART_PATH)
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_SCALE
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = MOUSE_FILTER_IGNORE
	number_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	number_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	number_font.hinting = TextServer.HINTING_LIGHT
	number_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	set_notify_transform(true)
	resized.connect(queue_redraw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED: queue_redraw()

func set_capacity(used: int, maximum: int) -> void:
	occupied = used
	total = maximum
	queue_redraw()

func number_center() -> Vector2:
	return (number_area.get_center() - (texture as AtlasTexture).region.position) * (size.x / texture.get_width())

func display_font_size() -> int:
	return maxi(1, roundi((14.0 + font_size_adjustment) * size.y / 50.0 * get_global_transform_with_canvas().get_scale().abs().y))

func _draw() -> void:
	if texture == null: return
	var factor := size.x / texture.get_width()
	# Rasterize at the final display size instead of shrinking an 86px glyph
	# with the source artwork. Cancel ancestor scaling for this text only.
	var transform := get_global_transform_with_canvas()
	var pixel_scale := transform.get_scale().abs()
	var font_size := display_font_size()
	var displayed := displayed_capacity()
	var gap := maxf(1.0, roundf(6.0 * factor * pixel_scale.x))
	var center := transform * number_center()
	var slash_width := number_font.get_string_size("/", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var used_width := number_font.get_string_size(str(displayed.x), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if displayed.x > 99 and not storage_banner:
		# Three testing digits use the same font as the board, not a reduced one.
		# Shift the group just enough to clear the painted "容量" caption.
		var safe_start := transform * ((Vector2(number_area.position.x, number_area.get_center().y) - (texture as AtlasTexture).region.position) * factor)
		center.x = maxf(center.x, safe_start.x + used_width + gap + slash_width * 0.5)
	center += number_offset * pixel_scale
	var baseline := roundf(center.y + (number_font.get_ascent(font_size) - number_font.get_descent(font_size)) * 0.5)
	var slash_x := roundf(center.x - slash_width * 0.5)
	draw_set_transform_matrix(transform.affine_inverse())
	draw_string(number_font, Vector2(roundf(slash_x-gap-used_width), baseline), str(displayed.x), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, USED_COLOR)
	draw_string(number_font, Vector2(slash_x, baseline), "/", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TOTAL_COLOR)
	draw_string(number_font, Vector2(roundf(slash_x+slash_width+gap), baseline), str(displayed.y), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TOTAL_COLOR)
	draw_set_transform_matrix(Transform2D.IDENTITY)
