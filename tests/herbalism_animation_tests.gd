extends "res://tests/mining_animation_tests.gd"

func animation_profile_path() -> String:
	return "res://data/ui/gathering_options.json"

func animation_nodes() -> Array[String]:
	return ["n04", "n31", "n36"]

func animation_frame_counts() -> Array[int]:
	return [60, 110, 180]

func animation_label() -> String:
	return "HERBALISM"
