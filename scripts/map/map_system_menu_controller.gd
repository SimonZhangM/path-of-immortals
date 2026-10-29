extends Node
const Menu = preload("res://scripts/map/map_system_menu.gd")
const Metadata = preload("res://scripts/entry/save_metadata.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
const SettingsPanel = preload("res://scripts/settings/settings_panel.gd")
var map
var menu: Control
var settings: Control

func is_open() -> bool:
	return is_instance_valid(menu)

func open() -> void:
	if is_open() or map.loadout==null or not map.startup_error.is_empty() or MapPresentation.transitioning: return
	if map.is_save_browser_open() or map.is_world_map_open() or map.is_inventory_open() or map.is_technique_open() or map.is_task_open() or map.is_exit_open(): return
	if map.event_state!=null and map.event_state.is_active(): return
	menu = Menu.new()
	map.add_child(menu)
	menu.action_requested.connect(_act)
	ItemTooltipHost.for_control(map).dismiss()
	map._end_drag()
	map._clear_hover()
	map.player.pause()
	map._update_optional_view_visibility()

func close() -> void:
	if not is_open() or menu.busy or map.is_save_browser_open() or is_instance_valid(settings): return
	menu.queue_free()
	menu = null
	map.player.play()
	map.status_header.map_title.visible = bool(map.definition.get("show_map_title",true))
	map._update_optional_view_visibility()

func return_from_saves() -> void:
	if not is_open(): return
	menu.show()
	map.player.pause()
	map._update_optional_view_visibility()

func _act(action: String) -> void:
	if not is_open() or menu.busy: return
	match action:
		"resume": close()
		"saves":
			map._open_save_browser()
			if map.is_save_browser_open():
				menu.hide()
		"settings":
			if is_instance_valid(settings): return
			settings = SettingsPanel.new()
			map.add_child(settings)
			settings.closed.connect(_close_settings)
			menu.hide()
		"main_menu", "quit": _leave(action)

func _close_settings() -> void:
	if not is_instance_valid(settings): return
	settings.queue_free()
	settings = null
	menu.show()
	map.player.pause()
	map._update_optional_view_visibility()

func _leave(action: String) -> void:
	menu.busy = true
	var error := MapLoadoutStore.save(map.loadout,map.inventory_save_path)
	if error.is_empty() and Session.remember(map.inventory_save_path)!=OK:
		error = "续玩记录保存失败，请重试。"
	if not error.is_empty():
		menu.message.text = "保存失败，仍留在游戏中。\n"+error
		menu.busy = false
		return
	Metadata.stop()
	map.deactivate_location()
	if action=="quit":
		get_tree().quit()
		return
	await MapPresentation.fade_out(false,0.2)
	var result := get_tree().change_scene_to_file("res://scenes/entry/start_menu.tscn")
	if result!=OK:
		map.activate_location()
		MapPresentation.enter_map(map.definition,0.2)
		menu.busy = false
		menu.message.text = "主菜单打开失败，请重试。"
