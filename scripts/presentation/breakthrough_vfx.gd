extends Control
## Presentation-only clock. Never advances a session or writes gameplay/save state.
const CONFIG_PATH = "res://data/ui/breakthrough_vfx.json"
const SHADERS = "res://scripts/presentation/breakthrough_vfx/"
const MOVING_SOURCE_IDS = [1,5,8,9,16,17]
const CORNERS = [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
var session: RefCounted
var visual_time := 0.0
var light_material: ShaderMaterial
var particle_materials: Array[ShaderMaterial] = []
var star_material: ShaderMaterial
var green_tracks: Array[PackedVector2Array] = []
var green_sources: Array[float] = []
var fixed_stars: Array = []
var moving_stars: Array[Dictionary] = []
var small_motif_count := 0

func _init() -> void:
	name = "BreakthroughVFX"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1600,900)
	scale = Vector2.ONE*1.6
	_build_tracks()
	_build_stars()
	var capture := BackBufferCopy.new()
	capture.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(capture)
	var light := ColorRect.new()
	light.name = "FixedOrbitsAndLightRibbons"
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.position = Vector2(230,145)
	light.size = Vector2(1350,680)
	light_material = _material("light")
	light_material.set_shader_parameter("composition",load("res://assets/UI-tupo-zonghebuzhi.webp"))
	light.material = light_material
	add_child(light)
	var sparks: Array[Color] = []
	for i in range(64):
		for tail in range(7): sparks.append(Color(float(i)/128.0,float(tail)/8.0,0,1))
	_add_particles("BlueRibbonParticles","sparks",sparks)
	var gold: Array[Color] = []
	small_motif_count = int(config.small_motifs_per_eighth)*8
	for i in range(small_motif_count): gold.append(_particle(i,1 if i%3==0 else 0,6.4))
	for i in range(4): gold.append(_particle(i,2,26,1.5))
	for i in range(4): gold.append(_particle(i,4,10.5,460.0/307.0))
	for i in range(32): gold.append(_particle(i,3,4+i%3))
	var orbit_texture := _orbit_texture()
	var gold_material := _add_particles("VerticalGoldMotifs","gold",gold)
	gold_material.set_shader_parameter("orbit_angles",orbit_texture)
	gold_material.set_shader_parameter("small_per_eighth",float(config.small_motifs_per_eighth))
	var floor_particles: Array[Color] = []
	for i in range(32):
		if i%4!=0: floor_particles.append(_particle(i,1 if i%3==0 else 0,8.5))
	for i in range(4): floor_particles.append(_particle(i,2,22,1.5))
	for i in range(4): floor_particles.append(_particle(i,4,10.5,460.0/307.0))
	for i in range(32): floor_particles.append(_particle(i,3,4))
	var floor_material := _add_particles("FlattenedFloorMotifs","floor",floor_particles)
	floor_material.set_shader_parameter("floor_mode",true)
	floor_material.set_shader_parameter("orbit_angles",orbit_texture)
	var stars: Array[Color] = []
	for i in range(40): stars.append(Color(float(i)/128.0,0,0,1))
	star_material = _add_particles("FloorGlints","stars",stars)
	_update_frame()

func _material(shader_name: String) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load(SHADERS+shader_name+".gdshader")
	return result

func _particle(id: int,kind: int,radius: float,aspect := 1.0) -> Color:
	return Color(float(id)/128.0,float(kind)/4.0,radius/32.0,aspect/2.0)

func _add_particles(node_name: String,shader_name: String,parameters: Array[Color]) -> ShaderMaterial:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for parameter: Color in parameters:
		for corner: Vector2 in CORNERS:
			# Static, non-degenerate local quads; shader computes all final positions.
			vertices.append(corner)
			uvs.append(corner)
			colors.append(parameter)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3(0,0,-1),Vector3(1600,900,2))
	var view := MeshInstance2D.new()
	view.name = node_name
	view.mesh = mesh
	var paint := _material(shader_name)
	paint.set_shader_parameter("starArt",load("res://assets/UI-tupo-star.webp"))
	paint.set_shader_parameter("flowerArt",load("res://assets/UI-tupo-flower.webp"))
	paint.set_shader_parameter("blue_speed_scale",float(config.blue_speed_scale))
	view.material = paint
	add_child(view)
	particle_materials.append(paint)
	return paint

static func _inverse_lengths(points: PackedVector2Array) -> PackedFloat32Array:
	var lengths := PackedFloat64Array([0.0])
	for i in range(1,points.size()): lengths.append(lengths[-1]+points[i].distance_to(points[i-1]))
	var result := PackedFloat32Array([0.0])
	var cursor := 0
	for i in range(1,4097):
		var distance := lengths[-1]*float(i)/4096.0
		while cursor<points.size()-2 and lengths[cursor+1]<distance: cursor+=1
		var fraction := (distance-lengths[cursor])/(lengths[cursor+1]-lengths[cursor])
		result.append((float(cursor)+fraction)/float(points.size()-1)*TAU)
	return result

func _orbit_texture() -> ImageTexture:
	var pixels := PackedFloat32Array()
	for offset: float in [0.0,-9.0,9.0]:
		var points := PackedVector2Array()
		for i in range(8193):
			var angle := float(i)/8192.0*TAU
			points.append(Vector2((296.18142026+offset)*cos(angle),(251.62583951+offset)*sin(angle)))
		pixels.append_array(_inverse_lengths(points))
	return ImageTexture.create_from_image(Image.create_from_data(4097,3,false,Image.FORMAT_RF,pixels.to_byte_array()))

static func _green_point(angle: float,lane: float) -> Vector2:
	return Vector2(1387+lane*2+(152-lane*13)*cos(angle)+3*sin(2*angle+lane),471-lane+(29-lane*4)*sin(angle)+(2+lane*2)*sin(2*angle+lane*.5)+1.4*cos(3*angle-lane*.7))

func _build_tracks() -> void:
	for lane in range(4):
		var points := PackedVector2Array()
		for i in range(4097): points.append(_green_point(float(i)/4096.0*TAU,lane))
		var lengths := 0.0
		var quarter := 0.0
		for i in range(1,4097):
			lengths+=points[i].distance_to(points[i-1])
			if i==1024: quarter=lengths
		green_sources.append(quarter/lengths)
		var track := PackedVector2Array()
		for angle: float in _inverse_lengths(points): track.append(_green_point(angle,lane))
		green_tracks.append(track)

func _green_at(progress: float,lane: int) -> Vector2:
	var at := fposmod(progress,1.0)*4096.0
	var index := int(at)
	return green_tracks[lane][index].lerp(green_tracks[lane][index+1],at-index)

func _build_stars() -> void:
	var source: Array = config.fixed_floor_stars.duplicate(true)
	for change: Array in [[0,30],[16,40],[17,34],[19,32],[21,34]]: source[change[0]].size=change[1]
	for id in range(source.size()):
		var star: Dictionary = source[id]
		if MOVING_SOURCE_IDS.has(id):
			var relative := (Vector2(star.x,star.y)-Vector2(802,724))/Vector2(1,.164)
			moving_stars.append({"center":Vector2(802,724),"radii":Vector2(relative.length(),relative.length()*.164),"period":64,"phase":relative.angle(),"size":star.size,"source":star,"kind":1})
		else: fixed_stars.append(star)
	for row: Array in [[343,755,18,.7,16],[1260,754,20,2.8,16],[802,808,44,1.6,16],[526,794,24,4.7,8]]:
		fixed_stars.append({"x":row[0],"y":row[1],"size":row[2],"phase":row[3],"period":row[4]})
	for row: Array in [[727,492,78,128,.44,48],[727,492,78,64,2.3,38],[727,492,78,128,4.5,32],[724,430,69,64,1.1,26],[724,430,69,32,3.8,16],[724,360,57,128,2.6,36],[724,360,57,32,5.7,12],[724,474,75,64,5.1,22]]:
		moving_stars.append({"center":Vector2(802,row[0]),"radii":Vector2(row[1],row[2]),"period":row[3],"phase":row[4],"size":row[5],"kind":2})
	for row: Array in [[733,471,77,64,.23,19],[714,385,59,64,1.36,16],[702,270,43,32,2.19,13]]:
		for i in range(2): moving_stars.append({"center":Vector2(802,row[0]),"radii":Vector2(row[1],row[2]),"period":row[3],"phase":row[4]+i*PI,"size":row[5],"kind":3})

func visual_rate(speed: float) -> float:
	return float(config.visual_speed.get(String.num(speed,1).trim_suffix(".0"),1.0))

func advance_visual(delta: float) -> void:
	if not is_visible_in_tree() or session==null or session.phase!="running": return
	# Accumulate deltas at the chosen visual rate; changing speed never changes phase.
	visual_time=fposmod(visual_time+maxf(0.0,delta)*visual_rate(session.speed),256.0)
	_update_frame()

func _breathe(star: Dictionary) -> float:
	return .35+.65*pow(.5+.5*sin(visual_time/float(star.period)*TAU+float(star.phase)),2)

func _update_frame() -> void:
	light_material.set_shader_parameter("phase",fposmod(visual_time,16.0)/16.0*TAU)
	light_material.set_shader_parameter("blue_phase",fposmod(visual_time*float(config.blue_speed_scale),16.0)/16.0*TAU)
	for paint: ShaderMaterial in particle_materials: paint.set_shader_parameter("visual_time",visual_time)
	var greens := PackedVector3Array()
	for i in range(24):
		var emitted := i>=16
		var lane := 0 if emitted else i%4
		var age := fposmod(float(i%4)/4.0+visual_time/8.0,1.0)
		var progress := green_sources[0]+(1.0 if i<20 else -1.0)*age*.22 if emitted else i*.618034+(1.0 if i%2==0 else -1.0)*visual_time/16.0+.25
		var p := _green_at(progress,lane)
		var life := pow(sin(PI*age),2) if emitted else .35+.65*pow(sin(TAU*(i*.173+visual_time/16.0)),2)
		greens.append(Vector3(p.x,p.y,life*(.16+.65*clampf((p.y-449)/50.0,.05,1))))
	light_material.set_shader_parameter("greenLights",greens)
	var stars := PackedVector4Array()
	for star: Dictionary in fixed_stars: stars.append(Vector4(star.x,star.y,star.size,.45+.65*_breathe(star)))
	for star: Dictionary in moving_stars:
		var angle := float(star.phase)+visual_time/float(star.period)*TAU
		var p: Vector2 = star.center+star.radii*Vector2(cos(angle),sin(angle))
		var gain: float = .72+.38*_breathe(star.source) if star.kind==1 else (.88+.16*cos(visual_time/16*TAU+star.phase) if star.kind==2 else .60+.30*(.5+.5*sin(angle)))
		stars.append(Vector4(p.x,p.y,star.size,gain))
	star_material.set_shader_parameter("star_data",stars)
