extends RefCounted

# All browsed ranks read the same book ledger. Explicit UI preview seeds never
# modify that ledger and yield to any real progress already recorded for a book.
static var previews: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_progress_preview.json"))

static func read(state: MapLoadoutState, book_id: String) -> Dictionary:
	var maximum := int(state.registry.library.books[book_id].max_level) if state != null else 8
	var achieved := state.knowledge.level(book_id) if state != null else 0
	var practice := state.knowledge.practice_value(book_id) if state != null else 0.0
	var preview: Dictionary = previews.get(book_id, {})
	if not preview.is_empty() and (not preview.get("only_when_unstarted", true) or (achieved == 0 and practice == 0.0)):
		achieved = int(preview.completed_level)
		practice = float(preview.practice)
	var complete := achieved >= maximum
	var costs: Array = CultivationGrowth.rules()["book_costs_%d" % maximum]
	var target := float(costs[mini(achieved, maximum - 1)])
	return {"achieved": achieved, "maximum": maximum, "complete": complete,
		"target": target, "practice": target if complete else practice}
