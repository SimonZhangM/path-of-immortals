extends "res://tests/technique_metal_overview_preview.gd"

# Run one five-book batch per process to keep render checks within the runner timeout.
# Set TECHNIQUE_PREVIEW_ELEMENT to water/fire/earth/wind/thunder (default: water).
func preview_element() -> String:
	var element := OS.get_environment("TECHNIQUE_PREVIEW_ELEMENT")
	if element.is_empty(): element = "water"
	assert(element in ["water", "fire", "earth", "wind", "thunder"])
	return element

func preview_books() -> Dictionary:
	var covers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_book_art.json"))
	var element := preview_element()
	var books := {}
	for index in range(1, 6):
		var book_id := "base.cultivation_book.%s_%02d" % [element, index]
		books[book_id] = String(covers[book_id]).get_file().trim_prefix("UI-%s-" % element).trim_suffix("-booksimple.webp")
	return books
