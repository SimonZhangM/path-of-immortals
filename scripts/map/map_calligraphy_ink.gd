extends RefCounted

# Build once per source texture, never per frame. The source pixels stay intact.
static var _distance_masks: Dictionary = {}

static func material_for(source: Texture2D) -> ShaderMaterial:
	if not _distance_masks.has(source):
		_distance_masks[source] = _build_distance_mask(source)
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/map/map_calligraphy_ink.gdshader")
	material.set_shader_parameter("glyph_distance", _distance_masks[source])
	return material

static func _build_distance_mask(source: Texture2D) -> ImageTexture:
	var sample := source.get_image()
	var height := 512
	var width := maxi(1, roundi(sample.get_width() * float(height) / sample.get_height()))
	sample.resize(width, height, Image.INTERPOLATE_BILINEAR)
	var distance := PackedFloat32Array()
	distance.resize(width * height)
	distance.fill(float(width + height))
	for y in height:
		for x in width:
			var color := sample.get_pixel(x, y)
			var bright_stroke := minf(color.r, color.g) > 0.55
			var red_seal := color.r > 0.5 and color.r > maxf(color.g, color.b) * 1.8
			if color.a > 0.1 and (bright_stroke or red_seal): distance[y * width + x] = 0.0
	# Two-pass chamfer distance to the actual strokes and seal, not the image edge.
	for y in height:
		for x in width:
			var i := y * width + x
			if x > 0: distance[i] = minf(distance[i], distance[i - 1] + 1.0)
			if y > 0:
				distance[i] = minf(distance[i], distance[i - width] + 1.0)
				if x > 0: distance[i] = minf(distance[i], distance[i - width - 1] + 1.414214)
				if x + 1 < width: distance[i] = minf(distance[i], distance[i - width + 1] + 1.414214)
	for y in range(height - 1, -1, -1):
		for x in range(width - 1, -1, -1):
			var i := y * width + x
			if x + 1 < width: distance[i] = minf(distance[i], distance[i + 1] + 1.0)
			if y + 1 < height:
				distance[i] = minf(distance[i], distance[i + width] + 1.0)
				if x > 0: distance[i] = minf(distance[i], distance[i + width - 1] + 1.414214)
				if x + 1 < width: distance[i] = minf(distance[i], distance[i + width + 1] + 1.414214)
	for i in distance.size(): distance[i] /= float(height)
	var mask := Image.create_from_data(width, height, false, Image.FORMAT_RF, distance.to_byte_array())
	return ImageTexture.create_from_image(mask)
