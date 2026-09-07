class_name BoardLayout
extends RefCounted

var id: String
var texture_path: String
var source_size: Vector2
var x_lines: Array
var y_lines: Array

func _init(raw: Dictionary) -> void:
	id = raw["id"]
	texture_path = raw.get("texture", "")
	source_size = Vector2(raw["source_size"][0], raw["source_size"][1])
	x_lines = raw["x_lines"].duplicate()
	y_lines = raw["y_lines"].duplicate()

static func validate(raw: Dictionary) -> bool:
	var dimensions: Variant = raw.get("source_size")
	if not dimensions is Array or dimensions.size() != 2:
		return false
	for value in dimensions:
		if not ContentRegistry._positive_integer(value):
			return false
	if not raw.get("texture", "") is String:
		return false
	for axis in 2:
		var lines: Variant = raw.get("x_lines" if axis == 0 else "y_lines")
		if not lines is Array or lines.size() != 5:
			return false
		var previous := -1.0
		for value in lines:
			if not ContentRegistry._nonnegative_integer(value) or float(value) <= previous or float(value) > float(dimensions[axis]):
				return false
			previous = float(value)
	return true

static func plain() -> BoardLayout:
	return BoardLayout.new({"id": "base.board.plain", "source_size": [1000, 1000], "x_lines": [16, 258, 500, 742, 984], "y_lines": [16, 258, 500, 742, 984]})

func scale_for(view_size: Vector2) -> float:
	return minf(view_size.x / source_size.x, view_size.y / source_size.y)

func art_rect(view_size: Vector2) -> Rect2:
	var dimensions := source_size * scale_for(view_size)
	return Rect2((view_size - dimensions) * 0.5, dimensions)

func source_to_view(point: Vector2, view_size: Vector2) -> Vector2:
	return art_rect(view_size).position + point * scale_for(view_size)

func footprint_rect(cell: Vector2i, dimensions: Vector2i, view_size: Vector2) -> Rect2:
	var begin := Vector2(_line(x_lines, cell.x), _line(y_lines, cell.y))
	var end := Vector2(_line(x_lines, cell.x + dimensions.x), _line(y_lines, cell.y + dimensions.y))
	return Rect2(source_to_view(begin, view_size), (end - begin) * scale_for(view_size))

func cell_at(point: Vector2, view_size: Vector2) -> Vector2i:
	var factor := scale_for(view_size)
	if factor <= 0:
		return Vector2i(-100, -100)
	var source := (point - art_rect(view_size).position) / factor
	var x := _interval(x_lines, source.x)
	var y := _interval(y_lines, source.y)
	return Vector2i(x, y) if x >= 0 and y >= 0 else Vector2i(-100, -100)

func _interval(lines: Array, value: float) -> int:
	for index in 4:
		if value >= float(lines[index]) and value < float(lines[index + 1]):
			return index
	return -1

func _line(lines: Array, index: int) -> float:
	if index < 0:
		return float(lines[0]) + index * (float(lines[1]) - float(lines[0]))
	if index > 4:
		return float(lines[4]) + (index - 4) * (float(lines[4]) - float(lines[3]))
	return float(lines[index])
