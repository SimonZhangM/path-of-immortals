extends RefCounted

# All six sources share this ring center; ornaments extend beyond the old crop.
const SOURCE_CENTER := Vector2(271, 300)
const SOURCE_SIZE := Vector2(543, 610)
const RING_REFERENCE_SIZE := 510.0
# All rings have clear inner pixels as far as radius 223. Overlap their inner
# edge uniformly, including antialiasing, instead of fitting only the small rim.
const PORTRAIT_SOURCE_SIZE := 456.0
const PORTRAIT_REGION := Rect2(25, 23, 440, 440)
static var paths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/player_portrait_frames.json"))
static var portrait_paths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/player_portraits.json"))
static var _portraits: Dictionary = {}

static func portrait_for(rank_id: String) -> AtlasTexture:
	var path: String = portrait_paths.get(rank_id, portrait_paths["base.cultivation.mortal"])
	if not _portraits.has(path):
		var source: Texture2D = load(path)
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		# The six 490px sources have the same painted circle at (245,243).
		# Faint alpha specks outside it must not change crop size or face position.
		atlas.region = PORTRAIT_REGION
		_portraits[path] = atlas
	return _portraits[path]

static func path_for(rank_id: String) -> String:
	return paths.get(rank_id, paths["base.cultivation.mortal"])

static func style_for(rank_id: String) -> Dictionary:
	return {
		"portrait_frame": path_for(rank_id),
		"portrait_window": [27.0 / 510, 27.0 / 510, 456.0 / 510, 456.0 / 510]
	}
