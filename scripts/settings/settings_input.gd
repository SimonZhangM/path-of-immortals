extends RefCounted
## Presentation/input helpers read the effective mapping; gameplay state stays elsewhere.
const Settings = preload("res://scripts/settings/game_settings.gd")

static func action_label(action: StringName) -> String:
	if not InputMap.has_action(action): return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if code == KEY_SPACE: return "空格"
			if code == KEY_ESCAPE: return "Esc"
			return OS.get_keycode_string(code)
	return ""

static func caption(text: String, action: StringName) -> String:
	if not bool(Settings.value("shortcut_hints", true)): return text
	var key := action_label(action)
	return text if key.is_empty() else "%s（%s）" % [text, key]

static func wheel_step(button: MouseButton) -> int:
	if button not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return 0
	var direction := 1 if button == MOUSE_BUTTON_WHEEL_UP else -1
	return -direction if bool(Settings.value("invert_zoom", false)) else direction
