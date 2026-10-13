class_name DialogueBubble
extends Control

const PLAYER_FRAMES = preload("res://scripts/presentation/player_portrait_frames.gd")
const SPECS := {
	"npc":[[Rect2(19,11,1239,122),71.17],[Rect2(19,11,1239,196),96.6],[Rect2(19,11,1239,265),96.6]],
	"player":[[Rect2(43,6,1249,137),79.5],[Rect2(43,6,1250,222),102.0],[Rect2(43,6,1250,292),102.0]]
}
const FONT_SIZE := 23
const MULTILINE_SPACING := 7
# Optical corrections for 23px KaiTi, measured against the visible inner paper
# rather than the font's line box or the artwork's transparent/shadow bounds.
# Rows are the one-, two- and three-line variants for each side.
const TEXT_OPTICAL_OFFSET_Y := {
	"npc":[2.0,2.5,3.0],
	"player":[5.0,0.5,-0.5]
}
const TEXT_WIDTH := 560.0
const BUBBLE_WIDTH := 610.0
var line_count := 0
var arrow_y := 0.0
var portrait_target_y := 0.0
var bubble: TextureRect
var portrait: TextureRect
var rim: TextureRect
var text_label: Label

static func font() -> SystemFont:
	var result := SystemFont.new()
	result.font_names = PackedStringArray(["KaiTi","楷体","STKaiti","Segoe UI Emoji","serif"])
	return result

# Measure the exact font used for rendering. Long speeches split into consecutive
# three-line bubbles, so neither long names nor fallback emoji can overflow.
static func wrap(text: String) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	var face := font()
	for character in text:
		if character=="\n":
			result.append(current)
			current = ""
			continue
		if not current.is_empty() and face.get_string_size(current+character,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x>TEXT_WIDTH:
			if character in "，。！？、；：）】”’…" and current.length()>1:
				result.append(current.left(-1))
				current = current.right(1)
			else:
				result.append(current)
				current = ""
		current += character
	if not current.is_empty(): result.append(current)
	return result

func configure(speaker: String, lines: Array, library: NpcDialogueLibrary, status: MapPlayerStatus, player_name: String) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size_flags_horizontal = SIZE_EXPAND_FILL
	line_count = lines.size()
	var is_player := speaker=="player"
	var spec: Array = SPECS[speaker][line_count-1]
	var region: Rect2 = spec[0]
	var factor := BUBBLE_WIDTH/region.size.x
	var portrait_x := 700.0 if is_player else 5.0
	portrait_target_y = 20.0+88.0/3.0
	var bubble_top := portrait_target_y-(float(spec[1])-region.position.y)*factor
	var source := "res://assets/UI-dialo-%s%d.webp" % ["you" if is_player else "zuo",line_count]
	var texture := AtlasTexture.new()
	texture.atlas = load(source)
	texture.region = region
	bubble = _image(texture,Rect2(70 if is_player else 119,bubble_top,BUBBLE_WIDTH,region.size.y*factor))
	arrow_y = bubble.position.y+(float(spec[1])-region.position.y)*factor
	text_label = Label.new()
	text_label.text = "\n".join(lines)
	text_label.add_theme_font_override("font",font())
	text_label.add_theme_font_size_override("font_size",FONT_SIZE)
	if line_count>1:
		text_label.add_theme_constant_override("line_spacing",MULTILINE_SPACING)
	text_label.add_theme_color_override("font_color",Color("17212a"))
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(text_label)
	# Center the line block, then compensate for visible ink/artwork asymmetry.
	text_label.position = bubble.position+Vector2(29 if not is_player else 20,TEXT_OPTICAL_OFFSET_Y[speaker][line_count-1])
	text_label.size = Vector2(TEXT_WIDTH,bubble.size.y)
	var face: Texture2D
	if is_player:
		var atlas := AtlasTexture.new()
		atlas.atlas = load(status.character_definition.portrait)
		var crop: Array = status.character_definition.get("portrait_region",[])
		atlas.region = Rect2(crop[0],crop[1],crop[2],crop[3]) if crop.size()==4 else Rect2(Vector2.ZERO,atlas.atlas.get_size())
		face = atlas
	else: face = load(library.definition.portrait)
	portrait = _image(face,Rect2(portrait_x+8,20,88,88))
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://scripts/ui/portrait_mask.gdshader")
	mask.set_shader_parameter("portrait_size",portrait.size)
	portrait.material = mask
	var center := portrait.position+portrait.size*0.5
	if is_player:
		var scale_factor := 88.0/PLAYER_FRAMES.PORTRAIT_SOURCE_SIZE
		rim = _image(load(PLAYER_FRAMES.path_for(status.cultivation_rank_id)),Rect2(center-PLAYER_FRAMES.SOURCE_CENTER*scale_factor,PLAYER_FRAMES.SOURCE_SIZE*scale_factor))
	else:
		# Original ring is centered near (318,313) in its 627px source.
		var scale_factor := 102.0/627.0
		rim = _image(load(library.definition.portrait_frame),Rect2(center-Vector2(318,313)*scale_factor,Vector2.ONE*102))
	var name_texture := AtlasTexture.new()
	name_texture.atlas = load("res://assets/name-bg.webp")
	name_texture.region = Rect2(14,35,612,136)
	var name_back := _image(name_texture,Rect2(portrait_x,110,104,24))
	var label := Label.new()
	label.text = player_name if is_player else library.definition.name
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_override("font",font())
	var name_size := 17
	while name_size>10 and font().get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x>100: name_size -= 1
	label.add_theme_font_size_override("font_size",name_size)
	label.add_theme_color_override("font_color",Color("fbf4bf"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	name_back.add_child(label)
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# KaiTi ink sits above the center of its line box; center it in the nameplate.
	label.offset_top = 1.0
	label.offset_bottom = 1.0
	custom_minimum_size = Vector2(806,maxf(136,bubble.position.y+bubble.size.y+4))

func _image(texture: Texture2D, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	image.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(image)
	image.position = rect.position
	image.size = rect.size
	return image
