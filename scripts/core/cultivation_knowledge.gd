class_name CultivationKnowledge
extends RefCounted

# Records achieved stages only. Earning cultivation and reset-pill economics are
# deliberately owned by the future progression module, not by this ledger.
var learned: Dictionary = {}
var error := ""

func level(book_id: String) -> int:
	return int(learned.get(book_id, {}).get("level", 0))

func branch(book_id: String, stage: int) -> String:
	return str(learned.get(book_id, {}).get("branches", {}).get(str(stage), ""))

func acquire(library: CultivationLibrary, book_id: String) -> bool:
	error = ""
	if not library.books.has(book_id): return _reject("未知功法：" + book_id)
	if not learned.has(book_id): learned[book_id] = {"level":0, "branches":{}}
	return true

func record_achievement(library: CultivationLibrary, book_id: String, stage: int, realm: int) -> bool:
	error = ""
	if not library.books.has(book_id): return _reject("未知功法：" + book_id)
	var book: Dictionary = library.books[book_id]
	if stage != level(book_id) + 1 or stage > int(book.max_level): return _reject("功法必须逐重达到，不能跳重或降重")
	var required := ceili(stage / 2.0) if book.max_level == 8 else stage
	if realm < required: return _reject("当前境界不能达到这一重")
	if not learned.has(book_id): learned[book_id] = {"level": 0, "branches": {}}
	learned[book_id].level = stage
	return true

func choose(library: CultivationLibrary, book_id: String, stage: int, choice: String) -> bool:
	error = ""
	if not library.books.has(book_id) or stage > level(book_id) or stage < 1: return _reject("尚未达到该功法重数")
	if choice not in library.books[book_id].branches.get(str(stage), []): return _reject("该重没有此分支")
	var previous := branch(book_id, stage)
	if not previous.is_empty() and previous != choice: return _reject("已选分支不能直接重选；重置丹药模块尚未开放")
	learned[book_id].branches[str(stage)] = choice
	return true

func snapshot() -> Dictionary:
	return {"version": 1, "learned": learned.duplicate(true)}

func restore(data: Dictionary, library: CultivationLibrary, realm: int) -> bool:
	if data.get("version") != 1 or not data.get("learned") is Dictionary: return _reject("学习存档格式无效")
	var candidate := CultivationKnowledge.new()
	for id: String in data.learned:
		if not library.books.has(id): return _reject("学习存档包含未知功法：" + id)
		var entry: Variant = data.learned[id]
		if not entry is Dictionary or not ContentRegistry._nonnegative_integer(entry.get("level")) or not entry.get("branches") is Dictionary: return _reject("学习存档条目无效")
		if entry.level > library.books[id].max_level: return _reject("学习存档功法重数越界")
		candidate.acquire(library, id)
		for stage in range(1, int(entry.level) + 1):
			if not candidate.record_achievement(library, id, stage, realm): return _reject(candidate.error)
		for stage: String in entry.branches:
			if not stage.is_valid_int() or str(int(stage)) != stage or not entry.branches[stage] is String or not candidate.choose(library, id, int(stage), entry.branches[stage]): return _reject("学习分支存档无效")
	learned = candidate.learned
	return true

func _reject(message: String) -> bool:
	error = message
	return false
