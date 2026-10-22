extends SceneTree
## Explicit maintenance command. Dry-run by default; --apply updates this save once.
const RECEIPT := "test.combat_spells.20261019"

static func prepare(state: MapLoadoutState) -> Dictionary:
	var next := state.snapshot()
	var added := 0
	if not next.content_grants.get(RECEIPT, false):
		for id: String in state.registry.library.spells:
			if id in next.owned_units.values(): continue
			var unit_id := "grant.%s.%s" % [RECEIPT, id]
			if next.owned_units.has(unit_id): return {"error": "法术补发单位ID冲突。"}
			next.owned_units[unit_id] = id
			added += 1
		next.content_grants[RECEIPT] = true
	return {"error": "", "snapshot": next, "added": added}

func _initialize() -> void: run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func run() -> void:
	var path := MapLoadoutStore.session_path(MapLoadoutStore.DEFAULT_PATH)
	if not FileAccess.file_exists(path): fail("需已有玩家存档，未创建或覆盖新档。"); return
	var original := FileAccess.get_file_as_string(path)
	var registry := ContentRegistry.new()
	if not registry.load_base_content(): fail(str(registry.errors)); return
	var made := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	if not made.error.is_empty(): fail(made.error); return
	var state: MapLoadoutState = made.state
	var error := state.restore(JSON.parse_string(original))
	if not error.is_empty(): fail(error); return
	var prepared := prepare(state)
	if not prepared.error.is_empty(): fail(prepared.error); return
	error = state.restore(prepared.snapshot)
	if not error.is_empty(): fail(error); return
	var books := state.storage_records().filter(func(record): return record.category == "spell")
	print("SPELL GRANT: add %d, bag spells %d, capacity %d/%d" % [prepared.added, books.size(), state.storage_used_slots(), state.storage_capacity_limit()])
	if "--apply" not in OS.get_cmdline_user_args(): print("DRY RUN: save unchanged"); quit(); return
	if prepared.added == 0 and JSON.parse_string(original).get("content_grants", {}).get(RECEIPT, false):
		print("Already applied; save unchanged"); quit(); return
	# Refuse to overwrite a save changed during preparation; preserve an archival backup.
	if FileAccess.get_file_as_string(path) != original: fail("存档在操作期间有更新，请重试。"); return
	var backup := ProjectSettings.globalize_path(path) + ".before-spell-grant-%d.bak" % int(Time.get_unix_time_from_system())
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), backup) != OK: fail("无法备份存档。"); return
	error = MapLoadoutStore.save(state, path)
	if not error.is_empty(): fail(error); return
	# JSON stores untyped numbers; compare both sides after the same encoding.
	if JSON.parse_string(FileAccess.get_file_as_string(path)) != JSON.parse_string(JSON.stringify(state.snapshot())): fail("保存后核对失败。"); return
	print("APPLIED; backup: " + backup)
	quit()
