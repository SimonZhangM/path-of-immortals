extends RefCounted
## Literal text only: player names and brackets never become BBCode commands.
static var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/dialogue_locations.json"))

static func apply(label: RichTextLabel, text: String) -> void:
	label.clear()
	var cursor := 0
	while cursor<text.length():
		var start := text.length()
		var match_term := ""
		for term: String in config.terms:
			var found := text.find(term,cursor)
			if found>=0 and (found<start or (found==start and term.length()>match_term.length())):
				start = found
				match_term = term
		label.add_text(text.substr(cursor,start-cursor))
		if match_term.is_empty(): break
		label.push_color(Color(config.color))
		label.push_bold()
		label.add_text(match_term)
		label.pop()
		label.pop()
		cursor = start+match_term.length()
