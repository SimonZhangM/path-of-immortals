extends SceneTree

# Explicit maintenance entry: same migration as normal F5/F6 startup, no combat
# and no replacements of an existing formation or owned unit ledger.
func _initialize() -> void:
	var registry := ContentRegistry.new()
	if not registry.load_base_content():
		printerr(registry.errors)
		quit(1)
		return
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	if not created.error.is_empty():
		printerr(created.error)
		quit(1)
		return
	var state: MapLoadoutState = created.state
	var path := MapLoadoutStore.session_path(MapLoadoutStore.DEFAULT_PATH)
	var before: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	var error := MapLoadoutStore.load_into(state,path)
	if not error.is_empty():
		printerr(error)
		quit(1)
		return
	var after := state.snapshot()
	if before is Dictionary and before.get("version",1) == 2:
		for unit_id: String in before.get("owned_units",{}):
			assert(after.owned_units.get(unit_id) == before.owned_units[unit_id],"existing ownership must be preserved")
	var kinds := {}
	for item_id: String in after.owned_units.values(): kinds[item_id] = true
	var report := {"path":ProjectSettings.globalize_path(path),"old_version":before.get("version",0) if before is Dictionary else -1,"version":after.version,"kinds":kinds.size(),"units":after.owned_units.size(),"equipped_stacks":after.placements.size(),"grant":after.content_grants.get("t01.115.v1",false)}
	var file := FileAccess.open("res://artifacts/t01-real-inventory-migration.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0)
