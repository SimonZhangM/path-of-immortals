class_name MapInnFoodView
extends MapShopDialog

# The inn owns the shared backdrop, scene art and three main tabs. Reuse only
# the ordinary shop's catalog, cards, details and atomic purchase controls.
func present_menu(event: Dictionary, catalog: MapShop, loadout: MapLoadoutState) -> void:
	var menu_event := event.duplicate(true)
	menu_event.presentation.background = event.presentation.food_background
	super.present(menu_event,catalog,loadout)
	mouse_filter = MOUSE_FILTER_IGNORE
	for control: CanvasItem in [get_child(0),backing,illustration,picture_frame,title_label,description_label,leave_button,buy_tab,sell_button,craft_tab,conversation_tab]:
		control.hide()
