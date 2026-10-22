extends Container

# Always reserve six equal columns, including columns with no visible item.
# Fractional widths preserve equal side insets without redistributing spare pixels.
var columns := 6

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		update_minimum_size()
		queue_sort()
	elif what == NOTIFICATION_SORT_CHILDREN:
		var cards := _cards()
		var gap := get_theme_constant("h_separation")
		var width := maxf(0.0, (size.x - gap * (columns - 1)) / columns)
		var heights := _row_heights(cards)
		var y := 0.0
		for index in cards.size():
			var row := index / columns
			if index > 0 and index % columns == 0:
				y += heights[row - 1] + get_theme_constant("v_separation")
			fit_child_in_rect(cards[index], Rect2(Vector2((index % columns) * (width + gap), y), Vector2(width, heights[row])))

func _get_minimum_size() -> Vector2:
	var heights := _row_heights(_cards())
	var height := 0.0
	for value in heights:
		height += value
	height += maxi(0, heights.size() - 1) * get_theme_constant("v_separation")
	return Vector2(0, height)

func _cards() -> Array[Control]:
	var cards: Array[Control] = []
	for child in get_children():
		if child is Control and child.visible:
			cards.append(child)
	return cards

func _row_heights(cards: Array[Control]) -> Array[float]:
	var heights: Array[float] = []
	for index in cards.size():
		if index % columns == 0:
			heights.append(0.0)
		var row := index / columns
		heights[row] = maxf(heights[row], cards[index].get_combined_minimum_size().y)
	return heights
