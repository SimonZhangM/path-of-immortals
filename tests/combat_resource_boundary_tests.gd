extends "res://tests/cultivation_combat_tests.gd"

# Reuse the real combat cases without unrelated historical presentation checks.
func run() -> void:
	check(registry.load_base_content(), "registry loads")
	if not registry.errors.is_empty(): finish(); return
	var catalog := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(catalog.error.is_empty(), "current inventory loads")
	if not catalog.error.is_empty(): finish(); return
	test_prepared()
	test_boundaries()
	finish()
