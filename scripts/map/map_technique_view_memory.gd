extends RefCounted

# Per-save UI preference, separate from inventory/learning transactions.
const SUFFIX := ".technique-view.cfg"

static func read_book(save_path: String, library: CultivationLibrary) -> String:
	if save_path.is_empty(): return ""
	var config := ConfigFile.new()
	if config.load(save_path + SUFFIX) != OK: return ""
	var value: Variant = config.get_value("technique", "last_book_id", "")
	if not value is String or not library.books.has(value): return ""
	return value

static func save_book(save_path: String, library: CultivationLibrary, book_id: String) -> Error:
	if save_path.is_empty(): return OK
	if not library.books.has(book_id): return ERR_INVALID_PARAMETER
	if read_book(save_path, library) == book_id: return OK
	var config := ConfigFile.new()
	config.set_value("technique", "last_book_id", book_id)
	return config.save(save_path + SUFFIX)
