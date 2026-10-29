extends Node
const Browser = preload("res://scripts/entry/save_browser.gd")
const Operations = preload("res://scripts/entry/save_operations.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
const Metadata = preload("res://scripts/entry/save_metadata.gd")
const Loading = preload("res://scripts/entry/game_loading_overlay.gd")
var map
var browser: Control
var catalog_override: RefCounted

func is_open() -> bool:
	return is_instance_valid(browser) and browser.visible

func open() -> void:
	if is_open() or map.loadout==null or not map.startup_error.is_empty() or MapPresentation.transitioning: return
	if map.is_world_map_open() or map.is_inventory_open() or map.is_technique_open() or map.is_task_open() or map.is_exit_open(): return
	if map.event_state!=null and map.event_state.is_active(): return
	browser = Browser.new()
	browser.in_game = true
	if catalog_override!=null: browser.catalog = catalog_override
	browser.z_index = 80
	map.add_child(browser)
	var shade := ColorRect.new()
	shade.name = "SaveBrowserShade"
	shade.color = Color(0,0,0,0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	browser.add_child(shade)
	browser.move_child(shade,0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	browser.closed.connect(close)
	browser.action_requested.connect(store)
	browser.slot_requested.connect(load_slot)
	ItemTooltipHost.for_control(map).dismiss()
	map._end_drag()
	map._clear_hover()
	map.player.pause()
	map._update_optional_view_visibility()

func close() -> void:
	if not is_instance_valid(browser) or browser.busy: return
	browser.queue_free()
	browser = null
	map.player.play()
	map.status_header.map_title.visible = bool(map.definition.get("show_map_title",true))
	map._update_optional_view_visibility()
	if map.is_system_menu_open(): map.system_menu_controller.return_from_saves()

func store(path: String) -> void:
	if not is_open() or browser.busy: return
	var error: String = Operations.store_manual(browser.catalog,map.loadout,map.inventory_save_path,path)
	browser.refresh()
	if not error.is_empty(): browser.show_error(error)

func load_slot(path: String) -> void:
	if not is_open() or browser.busy: return
	if not Session.has_save(path):
		browser.refresh()
		browser.show_error("该存档已不可读取，当前游戏保持。")
		return
	# Never overwrite the selected autosave with the state the player is leaving.
	if path!=map.inventory_save_path:
		var error: String = MapLoadoutStore.save(map.loadout,map.inventory_save_path)
		if not error.is_empty():
			browser.show_error(error)
			return
	Metadata.stop()
	if not Session.begin_resume(path):
		Metadata.start(map.inventory_save_path)
		browser.show_error("该存档已不可读取，当前游戏保持。")
		return
	browser.busy = true
	map.deactivate_location()
	var tree := get_tree()
	var overlay := Loading.show_for(tree,load(map.definition.background))
	await MapPresentation.fade_out(false,0.0)
	await RenderingServer.frame_post_draw
	var result := tree.change_scene_to_file("res://scenes/maps/session_start.tscn")
	if result!=OK:
		overlay.queue_free()
		Session.clear_selection()
		map.activate_location()
		MapPresentation.enter_map(map.definition,0.0)
		browser.busy = false
		browser.show_error("读取页面打开失败，当前游戏保持。")
