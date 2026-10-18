extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "load catalog")
	var library := registry.library
	var renamed := 0
	for id: String in library.books:
		var book: Dictionary = library.books[id]
		if not book.has("branch_display_names"): continue
		var names: Dictionary = book.branch_display_names
		renamed += names.size()
		for key: String in names:
			check(library.branch_display_name(id, key) == names[key], "current name resolves")
			check(library.branch_key(id, names[key]) == key, "current name maps to legacy key")
		# Craft mechanics remain deferred; display metadata must not enable learning.
		if book.branches.is_empty():
			var craft := CultivationKnowledge.new()
			for level in range(1, 6): craft.record_achievement(library, id, level, 5)
			for key: String in names:
				check(not craft.choose(library, id, 5, names[key]), "craft naming does not enable deferred mechanics")
		for stage: String in book.branches:
			for key: String in book.branches[stage]:
				if not names.has(key): continue
				var current: String = names[key]
				check(library.branch_display_name(id, key) == current, "display " + current)
				var knowledge := CultivationKnowledge.new()
				for level in range(1, 6):
					check(knowledge.record_achievement(library, id, level, 5), "reach stage")
				var before := knowledge.snapshot()
				if book.get("deferred_branches", {}).has(key):
					check(not knowledge.choose(library, id, int(stage), current), "new name stays deferred")
					check(knowledge.snapshot() == before, "deferred choice does not mutate")
					continue
				check(knowledge.choose(library, id, int(stage), current), "choose current name")
				check(knowledge.branch(id, int(stage)) == key, "persist legacy key")
				check(knowledge.choose(library, id, int(stage), key), "old alias same choice")
				var saved := knowledge.snapshot()
				var restored := CultivationKnowledge.new()
				check(restored.restore(saved, library, 5) and restored.snapshot() == saved, "old save compatible")
				saved.learned[id].branches[stage] = current
				check(restored.restore(saved, library, 5) and restored.branch(id, int(stage)) == key, "new name normalizes on restore")
				for other: String in book.branches[stage]:
					if other != key:
						check(not knowledge.choose(library, id, int(stage), library.branch_display_name(id, other)), "rename cannot enable respec")
	check(library.branch_key("base.cultivation_book.water_02", "青木启式") == "青木启式", "aliases scoped to wood book")
	check(renamed == 112, "95 new and 17 existing display names")
	check(library.branch_display_name("base.cultivation_book.water_02", "启式") == "玄水启式", "water uses its own name")
	check(library.branch_display_name("base.cultivation_book.water_04", "回流") == "回流", "existing water spell branch unchanged")
	check(library.spells["base.spell.thunder_05"].name == "雷罡护体", "existing thunder spell unchanged")
	var description := CultivationDescription.book(library.books["base.cultivation_book.wood_02"])
	check(description.contains("青木启式／青木承式"), "tooltip uses current names")
	print("Cultivation branch names: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
