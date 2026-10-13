class_name MapEncounterOptions
extends RefCounted

var background := ""
var illustration_frame := ""
var actions: Array[Dictionary] = []

func load_options(path := "res://data/ui/encounter_options.json") -> String:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary: return "遭遇弹窗配置格式错误。"
	for key in ["background", "illustration_frame"]:
		if not value.get(key) is String or not ResourceLoader.exists(value[key], "Texture2D"):
			return "遭遇弹窗图片不存在：" + key
	if not value.get("actions") is Array or value.actions.size() != 3:
		return "遭遇弹窗需要三种操作。"
	for index in 3:
		var action: Variant = value.actions[index]
		if not action is Dictionary or action.get("id") != ["retreat", "fight", "intimidate"][index]:
			return "遭遇弹窗操作标识错误。"
		if not action.get("description") is String or action.description.is_empty():
			return "遭遇弹窗操作说明缺失。"
		if not action.get("color") is String or not Color.html_is_valid(action.color):
			return "遭遇弹窗操作颜色错误。"
		if not action.get("enabled", true) is bool or not action.get("unavailable_reason", "") is String:
			return "遭遇弹窗操作可用性配置错误。"
		for key in ["button_idle", "button_selected"]:
			if not action.get(key) is String or not ResourceLoader.exists(action[key], "Texture2D"):
				return "遭遇弹窗按钮图片不存在。"
	background = value.background
	illustration_frame = value.illustration_frame
	actions.assign(value.actions)
	return ""
