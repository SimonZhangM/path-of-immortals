extends "res://tests/map_shop_tests.gd"

const Memory := preload("res://scripts/map/map_technique_view_memory.gd")
const BOOK := "base.cultivation_book.wood_03"

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func create_map(path: String):
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = path
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	return map

func selected_visible(screen) -> bool:
	var selected: Array = screen.book_cards.filter(func(card): return card.visible and card.button_pressed)
	return selected.size() == 1 and selected[0].book_id == BOOK

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var path := "res://artifacts/technique-memory-%d.json" % Time.get_ticks_usec()
	var map = create_map(path)
	await settle()
	check(map.startup_error.is_empty(), "isolated map starts")
	if not map.startup_error.is_empty(): quit(1); return
	var library: CultivationLibrary = map.loadout.registry.library
	check(Memory.read_book(path, library).is_empty(), "missing preference safely uses existing default")
	check(Memory.save_book("", library, BOOK) == OK and Memory.read_book("", library).is_empty(), "save-disabled previews never persist UI preferences")
	await key(KEY_G)
	var screen = map.technique_screen
	check(screen.selected_book_id == "base.cultivation_book.metal_01", "first visit retains default book")
	var before: Dictionary = map.loadout.snapshot().duplicate(true)
	await click(screen.category_buttons[1])
	var card = screen.book_cards.filter(func(item): return item.book_id == BOOK)[0]
	await click(card)
	check(screen.selected_book_id == BOOK and selected_visible(screen), "real book click selects target")
	check(Memory.read_book(path, library) == BOOK, "click immediately persists validated book ID")
	await click(screen.category_buttons[0])
	check(screen.selected_book_id == BOOK and Memory.read_book(path, library) == BOOK, "category browsing does not replace remembered book")
	await key(KEY_G)
	await key(KEY_G)
	check(map.is_technique_open() and screen.selected_element_id == "base.element.wood" and selected_visible(screen), "G reopen restores book and matching element")
	check(screen.overview.selected_book_id == BOOK and screen.overview.visible, "reopen displays the last book overview")
	await click(screen.category_buttons[0])
	await key(KEY_I)
	check(map.is_inventory_open(), "direct switch to inventory succeeds")
	await key(KEY_G)
	check(map.is_technique_open() and selected_visible(screen), "inventory-to-technique switch also reveals remembered book")
	check(map.loadout.snapshot() == before, "view preference never mutates gameplay snapshot")
	map.queue_free()
	await settle()
	map = create_map(path)
	await settle()
	check(map.startup_error.is_empty(), "fresh map instance loads isolated save")
	await key(KEY_G)
	screen = map.technique_screen
	check(screen.selected_book_id == BOOK and selected_visible(screen), "fresh instance restores persisted book and element")
	check(screen.overview.selected_book_id == BOOK and screen.overview.visible, "fresh instance restores matching overview")
	check(Memory.read_book(path + ".different-slot", library).is_empty(), "separate save paths do not share view preference")
	check(Memory.save_book(path, library, "base.cultivation_book.missing") == ERR_INVALID_PARAMETER and Memory.read_book(path, library) == BOOK, "invalid ID cannot replace valid preference")
	map.queue_free()
	await settle()
	var stale := ConfigFile.new()
	stale.set_value("technique", "last_book_id", "base.cultivation_book.removed")
	check(stale.save(path + Memory.SUFFIX) == OK, "write isolated stale-content fixture")
	check(Memory.read_book(path, library).is_empty(), "removed book safely falls back")
	stale.set_value("technique", "last_book_id", 123)
	stale.save(path + Memory.SUFFIX)
	check(Memory.read_book(path, library).is_empty(), "malformed preference type safely falls back")
	# Delete only this test's unique fixtures; no real user files are touched.
	for suffix in ["", ".bak", ".tmp", Memory.SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix)) == OK, "remove isolated fixture " + suffix)
	print("TECHNIQUE VIEW MEMORY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
