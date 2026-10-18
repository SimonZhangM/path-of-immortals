extends PanelContainer
## Reports a displayed tooltip, not merely a pointer entering the badge.
signal tooltip_shown

func _make_custom_tooltip(for_text: String) -> Object:
	var label := Label.new()
	label.text = for_text
	label.theme_type_variation = "TooltipLabel"
	label.theme = theme
	var reference: WeakRef = weakref(label)
	label.visibility_changed.connect(func(): _report_visible.call_deferred(reference,for_text))
	label.ready.connect(func(): _report_visible.call_deferred(reference,for_text))
	return label

func _report_visible(reference: WeakRef, for_text: String) -> void:
	var label: Label = reference.get_ref()
	if label==null or not label.is_inside_tree() or not label.is_visible_in_tree(): return
	if not label.get_window().visible or not is_visible_in_tree() or tooltip_text!=for_text: return
	if label.has_meta("reported"): return
	label.set_meta("reported",true)
	tooltip_shown.emit()
