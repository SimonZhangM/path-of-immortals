extends SceneTree
const Cycle = preload("res://scripts/entry/start_menu_background_cycle.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
const DIR := "res://artifacts/start-menu/background-cycle/"
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(DIR)
	Cycle.state_path = DIR + "isolated-cycle.cfg"
	Session.index_path = DIR + "no-session.json"
	Session.clear_selection()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	var second_process := "--second-process" in OS.get_cmdline_user_args()
	if not second_process:
		var initial := ConfigFile.new()
		initial.set_value("background", "next_index", 0)
		check(initial.save(Cycle.state_path) == OK, "create isolated sequence")
	var first := 3 if second_process else 0
	for index in range(first, first + 3):
		var page = load("res://scenes/entry/start_menu.tscn").instantiate()
		page.continue_fallback_path = ""
		root.add_child(page)
		current_scene = page
		var number := index % 5 + 1
		var selected: Texture2D = page.background.texture
		check(selected.resource_path == "res://assets/UI-game-bg%d.webp" % number, "ordered entry %d" % index)
		check(selected.get_image().has_mipmaps(), "background has mipmaps")
		while page.entrance.active: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR + "bg%d.png" % number)
		await create_timer(0.15).timeout
		check(page.background.texture == selected, "background stays fixed after entrance")
		var persisted := ConfigFile.new()
		check(persisted.load(Cycle.state_path) == OK and persisted.get_value("background", "next_index") == (index + 1) % 5,
			"advance exactly once per visit and persist next entry")
		page.queue_free()
		await process_frame
		await process_frame
	print("BACKGROUND_CYCLE: %d checks; %d failures; second_process=%s" % [checks, failures, second_process])
	quit(1 if failures else 0)
