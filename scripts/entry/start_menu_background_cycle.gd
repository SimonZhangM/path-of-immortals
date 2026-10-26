extends RefCounted
## Presentation preference only; independent of character saves and game time.
static var state_path := "user://start_menu_background.cfg"

static func next_path(paths: Array) -> String:
	if paths.is_empty(): return "res://assets/UI-game-bg1.webp"
	var state := ConfigFile.new()
	var index := 0
	if state.load(state_path) == OK:
		var saved: Variant = state.get_value("background", "next_index", 0)
		if saved is int and saved >= 0: index = saved % paths.size()
	var selected: String = paths[index]
	state.set_value("background", "next_index", (index + 1) % paths.size())
	var error := state.save(state_path)
	if error != OK:
		push_warning("开始界面背景顺序未能保存：%s" % error_string(error))
	return selected
