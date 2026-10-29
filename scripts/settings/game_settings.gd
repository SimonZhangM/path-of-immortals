extends Node
## Session-only preferences. UI edits a draft; only Apply changes gameplay.
## No user:// settings file is written, and renderer settings never alter the
## simulation clock. Display mode/size defaults come from the current window.
signal settings_changed

const DEFAULTS_PATH := "res://data/settings/defaults.json"
const AUDIO_BUSES := {"volume_master": "Master", "volume_music": "Music", "volume_effects": "Effects"}
const PAGE_KEYS := {
	"game": ["dialogue_speed", "dialogue_auto", "battle_speed", "background_pause", "auto_save", "auto_save_minutes", "quick_save"],
	"controls": ["bindings", "invert_zoom", "shortcut_hints"],
	"display": ["display_mode", "resolution", "fps_limit"],
	"audio": ["volume_master", "volume_music", "volume_effects", "background_mute"],
	"other": []
}
const BINDING_CONTEXTS := [
	["map_inventory", "map_techniques", "map_world_map", "map_tasks"],
	["dialogue_continue"],
	# The inventory shortcut is also handled before battle pause/speed input.
	["map_inventory", "battle_pause", "speed_half", "speed_normal", "speed_double"]
]
const ACTION_NAMES := {
	"map_tasks": "打开任务",
	"map_inventory": "打开储物袋", "map_techniques": "打开功法", "map_world_map": "打开世界地图",
	"dialogue_continue": "继续对话", "battle_pause": "战斗暂停／继续", "speed_half": "战斗0.5倍速",
	"speed_normal": "战斗1倍速", "speed_double": "战斗2倍速"
}
static var _defaults: Dictionary = {}
static var _values: Dictionary = {}
static var _window_defaults_captured := false
var _base_gain: Dictionary = {}
var _focused := true
var _owns_pause := false
var _owns_mute := false
var _preview_active := false

static func _ensure_defaults() -> void:
	if not _defaults.is_empty(): return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS_PATH))
	_defaults = raw if raw is Dictionary else {}
	_defaults["display_mode"] = "borderless"
	_defaults["resolution"] = Vector2i(2560, 1440)
	for action: String in _defaults.get("bindings", {}):
		_defaults.bindings[action] = int(_defaults.bindings[action])
	_defaults["auto_save_minutes"] = int(_defaults.get("auto_save_minutes", 10))
	_defaults["fps_limit"] = int(_defaults.get("fps_limit", 60))
	_values = _defaults.duplicate(true)

static func value(key: String, fallback: Variant = null) -> Variant:
	_ensure_defaults()
	var result: Variant = _values.get(key, fallback)
	return result.duplicate(true) if result is Dictionary or result is Array else result

static func values_snapshot() -> Dictionary:
	_ensure_defaults()
	return _values.duplicate(true)

static func ensure_audio_buses() -> void:
	for bus_name: String in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus_name) >= 0: continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_defaults()
	ensure_audio_buses()
	if not _window_defaults_captured:
		var window := get_window()
		var mode := "windowed" if window.mode in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED, Window.MODE_MINIMIZED] else "borderless"
		var dimensions := window.size
		if DisplayServer.get_name() == "headless":
			dimensions = Vector2i(int(ProjectSettings.get_setting("display/window/size/window_width_override", 2560)), int(ProjectSettings.get_setting("display/window/size/window_height_override", 1440)))
			mode = "borderless" if int(ProjectSettings.get_setting("display/window/size/mode", 3)) >= 3 else "windowed"
		_defaults.display_mode = mode
		_defaults.resolution = dimensions
		_values.display_mode = mode
		_values.resolution = dimensions
		_window_defaults_captured = true
	for key: String in AUDIO_BUSES:
		_base_gain[key] = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(AUDIO_BUSES[key]))
	_apply_bindings(_values.bindings)
	Engine.max_fps = int(_values.fps_limit)
	_apply_audio(_values)

func defaults_for_page(page: String) -> Dictionary:
	_ensure_defaults()
	var result := {}
	for key: String in PAGE_KEYS.get(page, []):
		var item: Variant = _defaults[key]
		result[key] = item.duplicate(true) if item is Dictionary or item is Array else item
	return result

func available_resolutions() -> Array:
	var maximum := Vector2i(2560, 1440)
	if DisplayServer.get_name() != "headless":
		maximum = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
		# Leave room for the OS title bar and border in windowed mode.
		maximum -= Vector2i(24, 56)
	var result: Array = []
	for candidate: Vector2i in [Vector2i(1280,720), Vector2i(1366,768), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440), Vector2i(3840,2160)]:
		if candidate.x <= maximum.x and candidate.y <= maximum.y: result.append(candidate)
	var current := get_window().size
	var current_windowed := get_window().mode in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED, Window.MODE_MINIMIZED]
	if current.x >= 1280 and current.y >= 720 and (current_windowed or (current.x <= maximum.x and current.y <= maximum.y)) and not result.has(current):
		result.append(current)
	# Very small desktops still get the project's established minimum size.
	if result.is_empty(): result.append(Vector2i(1280,720))
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return result

func native_resolution() -> Vector2i:
	if DisplayServer.get_name() == "headless": return Vector2i(_defaults.resolution)
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())

func validate_values(draft: Dictionary) -> String:
	var combined := values_snapshot()
	for key: Variant in draft:
		if not combined.has(key): return "未知设置项。"
		combined[key] = draft[key]
	for key: String in ["dialogue_auto", "background_pause", "auto_save", "quick_save", "invert_zoom", "shortcut_hints", "background_mute"]:
		if not combined[key] is bool: return "设置开关值无效。"
	if combined.dialogue_speed not in ["slow", "medium", "fast", "instant"]: return "对话速度无效。"
	if not _number(combined.battle_speed) or float(combined.battle_speed) not in [0.5, 1.0, 2.0]: return "战斗倍速无效。"
	if not _number(combined.auto_save_minutes) or float(combined.auto_save_minutes) not in [5.0, 10.0, 15.0, 30.0]: return "自动保存间隔无效。"
	if not _number(combined.fps_limit) or float(combined.fps_limit) not in [30.0, 60.0]: return "帧率上限只支持30或60帧。"
	for key: String in AUDIO_BUSES:
		if not _number(combined[key]) or not is_finite(float(combined[key])) or float(combined[key]) < 0.0 or float(combined[key]) > 1.0:
			return "音量必须在0%至100%之间。"
	if combined.display_mode not in ["windowed", "borderless"]: return "显示模式无效。"
	if not combined.resolution is Vector2i or combined.resolution.x < 1280 or combined.resolution.y < 720: return "分辨率无效。"
	if combined.display_mode == "windowed" and not available_resolutions().has(combined.resolution): return "该窗口分辨率超出当前显示器可用范围。"
	return validate_bindings(combined.bindings)

static func _number(item: Variant) -> bool:
	return item is int or item is float

static func validate_bindings(bindings: Variant) -> String:
	if not bindings is Dictionary or bindings.size() != ACTION_NAMES.size(): return "按键列表不完整。"
	for action: String in ACTION_NAMES:
		if not bindings.has(action) or not _number(bindings[action]): return "按键值无效。"
		var key := int(bindings[action])
		if float(bindings[action]) != float(key) or key <= 0 or key == KEY_ESCAPE or key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META] or OS.get_keycode_string(key).is_empty():
			return "请选择一个有效按键，Esc保留用于返回。"
	for context: Array in BINDING_CONTEXTS:
		var used := {}
		for action: String in context:
			var key := int(bindings[action])
			if used.has(key): return "按键冲突：%s与%s使用同一个键。" % [ACTION_NAMES[used[key]], ACTION_NAMES[action]]
			used[key] = action
	return ""

func apply_values(draft: Dictionary) -> String:
	var error := validate_values(draft)
	if not error.is_empty(): return error
	var updated := values_snapshot()
	for key: Variant in draft: updated[key] = draft[key].duplicate(true) if draft[key] is Dictionary or draft[key] is Array else draft[key]
	updated.auto_save_minutes = int(updated.auto_save_minutes)
	updated.fps_limit = int(updated.fps_limit)
	if updated.display_mode == "borderless": updated.resolution = native_resolution()
	var display_changed: bool = updated.display_mode != _values.display_mode or updated.resolution != _values.resolution
	_values = updated
	_apply_bindings(_values.bindings)
	Engine.max_fps = int(_values.fps_limit)
	if display_changed: _apply_display()
	_preview_active = false
	_apply_audio(_values)
	_update_focus_effects()
	settings_changed.emit()
	return ""

func _apply_bindings(bindings: Dictionary) -> void:
	for action: String in ACTION_NAMES:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = int(bindings[action])
		InputMap.action_add_event(action, event)

func _apply_display() -> void:
	if DisplayServer.get_name() == "headless": return
	var window := get_window()
	if _values.display_mode == "borderless":
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.borderless = false
		window.size = _values.resolution
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		window.position = usable.position + (usable.size - window.size) / 2

func preview_audio(draft: Dictionary) -> void:
	var preview := values_snapshot()
	for key: String in AUDIO_BUSES:
		if draft.has(key) and _number(draft[key]) and is_finite(float(draft[key])):
			preview[key] = clampf(float(draft[key]), 0.0, 1.0)
	_preview_active = true
	_apply_audio(preview)

func cancel_preview() -> void:
	if not _preview_active: return
	_preview_active = false
	_apply_audio(_values)

func _apply_audio(values: Dictionary) -> void:
	ensure_audio_buses()
	for key: String in AUDIO_BUSES:
		var index := AudioServer.get_bus_index(AUDIO_BUSES[key])
		AudioServer.set_bus_volume_linear(index, float(_base_gain.get(key, 1.0)) * float(values[key]))

func _notification(what: int) -> void:
	if not is_inside_tree() or _base_gain.is_empty(): return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: set_application_focus(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: set_application_focus(true)

func set_application_focus(focused: bool) -> void:
	_focused = focused
	_update_focus_effects()

func _update_focus_effects() -> void:
	var should_pause: bool = not _focused and bool(value("background_pause", true))
	if should_pause and not _owns_pause and not get_tree().paused:
		_owns_pause = true
		get_tree().paused = true
	elif not should_pause and _owns_pause:
		_owns_pause = false
		get_tree().paused = false
	var should_mute: bool = not _focused and bool(value("background_mute", true))
	if should_mute and not _owns_mute and not AudioServer.is_bus_mute(0):
		_owns_mute = true
		AudioServer.set_bus_mute(0, true)
	elif not should_mute and _owns_mute:
		_owns_mute = false
		AudioServer.set_bus_mute(0, false)

func _exit_tree() -> void:
	if _owns_pause and get_tree() != null: get_tree().paused = false
	if _owns_mute: AudioServer.set_bus_mute(0, false)
