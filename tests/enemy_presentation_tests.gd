extends SceneTree

const ENEMY := "base.enemy.chisong_liaozhu"
const BACKGROUND := "res://assets/battle-qingshihewan-chisongliaozhu.webp"
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for i in 8: await process_frame

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "all content loads")
	var definition := registry.get_enemy(ENEMY)
	check(definition.presentation.rank_label == "凡人级·首领", "rank in enemy master")
	check(definition.presentation.category_label == "野兽类", "category in enemy master")
	check(EnemyPresentation.background_path(definition) == BACKGROUND, "enemy-specific background")
	check(not FileAccess.file_exists("res://assets/test1.webp") and not FileAccess.file_exists("res://assets/test1.webp.import"), "temporary source and import removed")
	check((load(BACKGROUND) as Texture2D).get_image().has_mipmaps(), "replacement keeps mipmaps")
	for key in ["rank_label", "category_label", "description", "battle_background", "summary"]:
		var bad: Dictionary = definition.presentation.duplicate(true)
		bad.erase(key)
		check(not EnemyPresentation.validation_error(bad).is_empty(), "missing presentation field rejected: " + key)
	for edit in [{"value": "96"}, {"stat": "unknown"}]:
		var bad: Dictionary = definition.presentation.duplicate(true)
		bad.summary[0].merge(edit, true)
		check(not EnemyPresentation.validation_error(bad).is_empty(), "duplicate or unknown stat rejected")
	var bad_art: Dictionary = definition.presentation.duplicate(true)
	bad_art.battle_background = "res://assets/does-not-exist.webp"
	check(not EnemyPresentation.validation_error(bad_art).is_empty(), "missing background rejected")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
	raw.erase("enemy_sequence")
	raw.erase("respawn_days")
	var other := raw.duplicate(true)
	other.id = "base.map_event.test.second_pig"
	other.point_id = "base.map.test.point.second_pig"
	var events := MapEventRegistry.new()
	check(events.configure([raw, other], [raw.point_id, other.point_id]).is_empty(), "two instances share one enemy master")
	for field in ["enemy_rank", "enemy_category", "enemy_description"]:
		check(not raw.has(field), "event has no duplicated " + field)
	var misplaced := raw.duplicate(true)
	misplaced.presentation.enemy_summary = []
	check(not MapEventRegistry.new().configure([misplaced], [raw.point_id]).is_empty(), "misplaced enemy presentation rejected")
	var state := MapEventState.new(events, {})
	check(state.resolve_encounter(raw.id, "victory"), "first encounter defeated")
	check(not state.try_start(raw.point_id, raw.point_id, true, "arrival"), "first stays defeated")
	check(state.try_start(other.point_id, other.point_id, true, "arrival"), "same species at second node stays alive")
	state.cancel_encounter()
	state.resolve_encounter(other.id, "victory")
	check(state.respawn_encounter(raw.id) and not state.completed.has(raw.id) and state.completed.has(other.id), "respawn affects only selected instance")
	var changed := definition.duplicate(true)
	changed.max_hp = 117
	changed.presentation.rank_label = "测试等级"
	var enemy := PartyMemberState.new(changed, registry)
	enemy.equip_definition_loadout()
	var rows := EnemyPresentation.summary_rows(enemy)
	check(rows[0].value == "117", "summary follows actual changed HP")
	check(rows[2].value == enemy.armor_type, "summary follows actual armor type")
	check(not changed.presentation.summary[0].has("value"), "summary rendering does not mutate definition")
	var modal := MapEncounterDialog.new()
	root.add_child(modal)
	modal.size = Vector2(2560,1440)
	modal.present(raw, enemy)
	await settle()
	check(modal.rank_label.text == "测试等级" and modal.enemy_description.text == changed.presentation.description, "dialog reads master fields")
	check(modal.location_illustration.texture.resource_path == raw.presentation.illustration, "popup uses location illustration")
	var original_enemy := PartyMemberState.new(definition, registry)
	original_enemy.equip_definition_loadout()
	modal.present(raw, original_enemy)
	if DisplayServer.get_name() != "headless":
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/enemy-master-encounter.png")
	modal.queue_free()
	await settle()
	# Actual main scene, no saved loadout and no system input.
	var player := MapPlayerStatus.new()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json"))
	check(player.configure(registry, config).is_empty(), "actual map player snapshot configured")
	for index in 3:
		var id: String = ENEMY if index == 0 else "base.enemy.wild_dog"
		var scene = load("res://scenes/main/main.tscn").instantiate()
		var manager: GameManager = scene.get_node("GameManager")
		manager.enemy_id = id
		manager.use_saved_loadout = false
		manager.player_snapshot = player.battle_snapshot()
		# Third scene supplies a second enemy's distinct background in memory only.
		var custom_background := index == 2
		if custom_background:
			manager.ready.connect(func():
				var dog := manager.registry.get_enemy(id).duplicate(true)
				dog.id = "base.enemy.test_background"
				dog.presentation = definition.presentation.duplicate(true)
				dog.presentation.battle_background = "res://assets/inv-background.webp"
				check(manager.registry.register_enemy(dog), "second enemy background accepted")
				manager.enemy_id = dog.id
				manager.enemies[0].definition = dog
			)
		root.add_child(scene)
		await settle()
		var ui = scene.get_node("MainUI")
		check(manager.startup_error.is_empty(), "actual battle starts: " + id)
		if id == ENEMY:
			check(ui._backdrop.texture.resource_path == BACKGROUND, "direct pig battle reads master background")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/enemy-master-battle.png")
		elif custom_background:
			check(ui._backdrop.texture.resource_path == "res://assets/inv-background.webp", "second enemy gets its own configured background")
		else:
			check(ui.battle_background_path.is_empty() and ui._backdrop.texture is GradientTexture2D, "unconfigured test enemy never inherits pig background")
		scene.queue_free()
		await settle()
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = "res://artifacts/enemy-master-map.json"
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "actual map accepts enemy master presentation")
	var map_enemy: PartyMemberState = map._encounter_enemies[raw.id]
	map.encounter_dialog.present(raw, map_enemy)
	check(map.encounter_dialog.rank_label.text == definition.presentation.rank_label, "actual map dialog uses enemy metadata")
	check(map.encounter_dialog.location_illustration.texture.resource_path == raw.presentation.illustration, "actual map uses location illustration")
	map.queue_free()
	await settle()
	print("Enemy presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
