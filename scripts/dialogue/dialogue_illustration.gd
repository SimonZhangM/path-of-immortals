extends RefCounted
## Shared frame settings and line-bound, manually advanced picture sequences.
static var defaults: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/dialogue_illustration.json"))

static func art_for(event: Dictionary) -> Dictionary:
	var art: Dictionary = event.get("illustration",event.get("presentation",{}).get("illustration",{}))
	if art.is_empty(): return {}
	var result := defaults.duplicate(true)
	result.merge(art,true)
	return result

static func page_at(art: Dictionary, line: int) -> int:
	var pages: Array = art.get("pages",[])
	if pages.is_empty() or line>=int(art.resume_line): return -1
	for index in range(pages.size()-1,-1,-1):
		if line>=int(pages[index].line): return index
	return -1

static func sequence_error(art: Dictionary, line_count: int) -> String:
	if not art.has("pages"): return ""
	if not art.pages is Array or art.pages.is_empty(): return "剧情插图序列为空。"
	if art.has("page_text") and (not art.page_text is String or art.page_text.strip_edges().is_empty()): return "剧情插图固定对白无效。"
	if not WorldCalendar.integer_between(art.get("resume_line"),1,line_count-1): return "剧情插图续接位置无效。"
	var previous := -1
	for page: Variant in art.pages:
		if not page is Dictionary or not WorldCalendar.integer_between(page.get("line"),previous+1,int(art.resume_line)-1): return "剧情插图页序无效。"
		if not page.get("image") is String or page.image.is_empty(): return "剧情插图缺少图片路径。"
		previous = int(page.line)
	return ""
