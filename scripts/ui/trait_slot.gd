class_name TraitSlot
extends Control

var manager: GameManager
var trait_data: Dictionary = {}
var runtime_key: String = ""
var pulse: float = 0.0
# Presentation-only slot reserved for a future skill icon.
var icon_texture: Texture2D
var circle_offset_y: float = 0.0

func configure(game: GameManager, definition: Dictionary, key: String) -> void:
	manager = game
	trait_data = definition
	runtime_key = key
	custom_minimum_size = Vector2(76, 88)
	tooltip_text = str(trait_data.get("name", "空特质槽"))
	if not trait_data.is_empty():
		tooltip_text += " · %s · %s\n%s" % ["主动" if trait_data["kind"] == "active" else "被动", manager.registry.get_element(trait_data["element"])["name"], trait_data.get("description", "")]
	manager.presentation_events.connect(_on_events)

func _on_events(events: Array[Dictionary]) -> void:
	for event in events:
		if event["kind"] == "trait_activated" and event["key"] == runtime_key:
			pulse = 0.24

func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0d1520", 0.99)
	box.border_color = CooldownRing.tint(manager.registry, trait_data.get("element", "base.element.none"))
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = 360
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel

func _process(delta: float) -> void:
	pulse = maxf(0, pulse - delta)
	queue_redraw()

func _draw() -> void:
	var color := CooldownRing.tint(manager.registry, trait_data.get("element", "base.element.none"))
	var center := Vector2(size.x / 2, size.y / 2 + circle_offset_y)
	draw_circle(center, 34, Color("080f13", 0.92))
	draw_arc(center, 33, 0, TAU, 64, Color("b7985b"), 2, true)
	draw_arc(center, 29, 0, TAU, 64, Color(color, 0.24), 1, true)
	if icon_texture != null:
		var icon_size := icon_texture.get_size() * (52.0 / maxf(icon_texture.get_width(), icon_texture.get_height()))
		draw_texture_rect(icon_texture, Rect2(center - icon_size / 2, icon_size), false)
	else:
		# Keep authored name as a temporary readable icon placeholder; no invented skill art.
		draw_string(get_theme_default_font(), center + Vector2(-34, 5), trait_data.get("name", "—"), HORIZONTAL_ALIGNMENT_CENTER, 68, 17, color)
	if not trait_data.is_empty() and trait_data["kind"] == "active":
		var remaining := manager.simulation.trait_remaining_usec(runtime_key) / 1_000_000.0
		var text := "%.1fs" % remaining
		var font := get_theme_default_font()
		var width := maxf(42, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 10)
		var badge := Rect2(Vector2((size.x - width) / 2, center.y + 29), Vector2(width, 22))
		var box := StyleBoxFlat.new()
		box.bg_color = Color("060a0d", 0.92)
		box.set_corner_radius_all(6)
		draw_style_box(box, badge)
		draw_string(font, badge.position + Vector2(0, 17), text, HORIZONTAL_ALIGNMENT_CENTER, width, 16, Color.WHITE)
	if pulse > 0:
		draw_circle(center, 31, Color(1, 1, 1, 0.17 * sin(pulse / 0.24 * PI)))
