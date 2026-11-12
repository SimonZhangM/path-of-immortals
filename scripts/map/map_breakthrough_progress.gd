extends Control
## Read-only artwork: a single ratio controls reveal, marker position and opacity.
var artwork: TextureRect
var white_line: ColorRect
var star: TextureRect
var value := 0.0
var source_scale := 1.0
var source_endpoints := Vector2.ZERO
var source_center_y := 0.0
var line_width := 3.0
var inner_profile: Array = []
var reveal_material: ShaderMaterial

func configure(config: Dictionary) -> void:
	name="ActualCultivationFill"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var empty: Texture2D=load(String(config.texture))
	var gold: Texture2D=load(String(config.filled_texture))
	var bounds := Rect2(preload("res://scripts/map/map_texture_metrics.gd").inspect(empty).visible_rect)
	var area := Rect2(config.reference_rect[0],config.reference_rect[1],config.reference_rect[2],config.reference_rect[3])
	source_scale=area.size.x/bounds.size.x
	size=empty.get_size()*source_scale
	position=area.get_center()-bounds.get_center()*source_scale
	source_endpoints=Vector2(config.source_endpoints[0],config.source_endpoints[1])
	source_center_y=float(config.source_center_y)
	line_width=float(config.white_line_width)
	inner_profile=config.inner_half_height_profile.duplicate(true)
	artwork=_texture("CultivationProgressArtwork",empty)
	artwork.size=size
	reveal_material=ShaderMaterial.new()
	reveal_material.shader=preload("res://scripts/map/map_breakthrough_progress.gdshader")
	reveal_material.set_shader_parameter("filled_texture",gold)
	reveal_material.set_shader_parameter("endpoints",source_endpoints/empty.get_width())
	artwork.material=reveal_material
	white_line=ColorRect.new()
	white_line.name="ProgressFrontLine"
	white_line.color=Color.WHITE
	white_line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(white_line)
	star=_texture("ProgressStar",load(String(config.star_texture)))
	star.size=star.texture.get_size()*source_scale
	present(0.0,false)

func _texture(node_name: String, texture: Texture2D) -> TextureRect:
	var view := TextureRect.new()
	view.name=node_name
	view.texture=texture
	view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	view.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(view)
	return view

func present(ratio: float, started: bool) -> void:
	ratio=clampf(ratio,0.0,1.0) if started and is_finite(ratio) else 0.0
	value=ratio*100.0
	reveal_material.set_shader_parameter("progress",ratio)
	var source_x := lerpf(source_endpoints.x,source_endpoints.y,ratio)
	var center := Vector2(source_x,source_center_y)*source_scale
	star.position=center-star.size*0.5
	star.modulate.a=ratio
	star.visible=started
	# Bound the whole 3px strip, not just its center, by the narrowest inner gap.
	var half_width := line_width*0.5/source_scale
	var half_height := minf(_half_height(source_x-half_width),_half_height(source_x+half_width))
	for point: Array in inner_profile:
		if float(point[0])>source_x-half_width and float(point[0])<source_x+half_width:
			half_height=minf(half_height,float(point[1]))
	half_height*=source_scale
	white_line.size=Vector2(line_width,2.0*half_height)
	white_line.position=center-Vector2(line_width*0.5,half_height)
	white_line.visible=started and half_height>0.0

func _half_height(source_x: float) -> float:
	if source_x<=source_endpoints.x or source_x>=source_endpoints.y: return 0.0
	for index in range(1,inner_profile.size()):
		var left: Array=inner_profile[index-1]
		var right: Array=inner_profile[index]
		if source_x<=float(right[0]):
			return lerpf(float(left[1]),float(right[1]),(source_x-float(left[0]))/(float(right[0])-float(left[0])))
	return 0.0
