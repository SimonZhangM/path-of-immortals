extends SceneTree

const VERTICAL := ["base.spell.metal_04", "base.spell.water_04", "base.spell.fire_04", "base.spell.fire_08", "base.spell.wind_04", "base.spell.thunder_04"]
var checks := 0
var failures: Array[String] = []
var registry := ContentRegistry.new()

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func run() -> void:
	check(registry.load_base_content(), "registry loads with fixed spell footprints: " + str(registry.errors))
	if registry.errors.is_empty():
		test_placement()
		test_validation()
	print("Spell board footprints: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_placement() -> void:
	var counts := {"single": 0, "vertical": 0, "horizontal": 0}
	for id: String in registry.library.spells:
		var definition: Dictionary = registry.library.spells[id]
		var expected := Vector2i.ONE
		if int(definition.cells) == 2:
			expected = Vector2i(1, 2) if id in VERTICAL else Vector2i(2, 1)
			counts["vertical" if id in VERTICAL else "horizontal"] += 1
		else:
			counts.single += 1
		check(registry.get_item(id).grid_size == expected, id + " registered shape")
		var board := InventoryState.new(registry, Vector2i(3, 3))
		check(board.available_cells(id).size() == (4 - expected.x) * (4 - expected.y), id + " exact fitting positions")
		check(not board.add_item("rotated", id, Vector2i.ZERO, true), id + " cannot use book rotation flag")
		var last := Vector2i(3, 3) - expected
		check(not board.add_item("right", id, Vector2i(last.x + 1, 0)), id + " right overflow denied")
		check(not board.add_item("bottom", id, Vector2i(0, last.y + 1)), id + " bottom overflow denied")
		check(board.add_item("spell", id, last), id + " fits at last legal anchor")
		check(board.occupied_cells() == int(definition.cells), id + " correct occupied area")
		var second := last + expected - Vector2i.ONE
		check(board.item_at(second) == "spell", id + " final occupied cell belongs to spell")
		var other := "base.spell.wood_01" if id != "base.spell.wood_01" else "base.spell.metal_01"
		check(not board.add_item("overlap", other, second), id + " occupied cell blocks another spell")
		check(not board.move_item("spell", Vector2i(last.x + 1, last.y)), id + " move cannot cross edge")
		var entry := board.take("spell")
		check(not board.put(entry, Vector2i.ZERO).is_empty(), id + " take and put preserves fixed shape")
		check(board.instance_size("spell") == expected, id + " instance shape preserved")
	check(counts == {"single": 42, "vertical": 6, "horizontal": 8}, "42 square / 6 portrait / 8 landscape")
	for book_id: String in registry.library.books:
		var board := InventoryState.new(registry, Vector2i(3, 3))
		check(not board.add_item("book", book_id, Vector2i.ZERO), book_id + " original book remains forbidden")

func test_validation() -> void:
	var spell: Dictionary = registry.library.spells["base.spell.metal_04"].duplicate(true)
	for invalid: Variant in [[2, 2], [0, 2], [-1, -2], [1.5, 2], ["1", 2], [true, 2], [1], [1, 2, 1], "1x2", null, [INF, 1], [NAN, 2]]:
		spell.size = invalid
		check(not CultivationLibrary.validate_spell(spell), "reject invalid footprint " + str(invalid))
	for valid: Array in [[1, 2], [2, 1]]:
		spell.size = valid
		check(CultivationLibrary.validate_spell(spell), "accept valid two-cell shape " + str(valid))
	spell.erase("size")
	check(CultivationLibrary.validate_spell(spell), "legacy definitions fall back to horizontal")
	check(CultivationLibrary.item_record(spell, true).size == [2, 1], "legacy horizontal record")
	spell.cells = 1.5
	check(not CultivationLibrary.validate_spell(spell), "reject fractional cell count")
	check(not CultivationLibrary.validate_spell({"size": [1, 2]}, true), "branch cannot change footprint")
	check(not CultivationLibrary.validate_spell({"cells": 2}, true), "branch cannot change area")
	var single: Dictionary = registry.library.spells["base.spell.metal_01"].duplicate(true)
	single.size = [1, 2]
	check(not CultivationLibrary.validate_spell(single), "one-cell spell cannot acquire two-cell shape")
	single.size = [1, 1]
	check(CultivationLibrary.validate_spell(single), "explicit square shape accepted")
