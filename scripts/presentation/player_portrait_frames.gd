extends RefCounted

# All six sources share this ring center; ornaments extend beyond the old crop.
const SOURCE_CENTER := Vector2(271, 300)
const SOURCE_SIZE := Vector2(543, 610)
const RING_REFERENCE_SIZE := 510.0
const PORTRAIT_SOURCE_SIZE := 432.0
static var paths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/player_portrait_frames.json"))

static func path_for(rank_id: String) -> String:
	return paths.get(rank_id, paths["base.cultivation.mortal"])

static func style_for(rank_id: String) -> Dictionary:
	return {
		"portrait_frame": path_for(rank_id),
		"portrait_window": [0.076470588, 0.076470588, 0.847058824, 0.847058824]
	}
