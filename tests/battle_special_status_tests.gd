extends SceneTree
const Special = preload("res://scripts/presentation/battle_special_status_view.gd")
const Details = preload("res://scripts/presentation/battle_replay_details.gd")
const ReplayFormat = preload("res://scripts/presentation/battle_replay_format.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for frame in 8: await process_frame
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = false
	game.loadout_save_path = ""
	game.battle_seed_override = BattleSimulation.DEFAULT_RANDOM_SEED
	root.add_child(scene)
	game.set_process(false)
	await settle()
	check(game.startup_error.is_empty(), "isolated battle loads")
	var owner: PartyMemberState = game.party[0]
	var enemy: PartyMemberState = game.enemies[0]
	enemy.definition = enemy.definition.duplicate(true)
	enemy.definition.status_capacity = 40
	var sim: BattleSimulation = game.simulation
	var ui = scene.get_node("MainUI")
	var grid: BattleStatusIcons = ui.ally_panel.status_icons
	var enemy_grid: BattleStatusIcons = ui.enemy_panel.status_icons
	for word: String in Special.definitions():
		check(grid.slots.has(word) and enemy_grid.slots.has(word), "both sides have " + word)
		check(not grid.slots[word].visible and not enemy_grid.slots[word].visible, "inactive status hidden: " + word)
	for number in range(14, 25):
		var path := "res://assets/UI-battle-icon-%02d.webp" % number
		var texture: Texture2D = load(path)
		var side := 320 if number < 20 else 315
		check(texture != null and texture.get_size() == Vector2(side, side), "asset size " + str(number))
		check(FileAccess.get_file_as_string(path + ".import").contains("mipmaps/generate=true"), "mipmap import " + str(number))
		if DisplayServer.get_name() != "headless": check(texture.get_image().has_mipmaps(), "runtime mipmaps " + str(number))
	for key: String in ["hp_spent", "stamina_spent", "spirit_spent"]:
		check(ReplayFormat.icon(key) != null, "resource cost art loaded: " + key)
	for key: String in ["attack_hits", "attack_crits", "attack_misses", "attack_immune", "generated_thunder_shield", "absorbed_thunder_shield"]:
		check(ResourceLoader.exists(Details.icon_path(key)), "replay path loaded: " + key)
	# Use existing simulation authorities, without manufacturing combat-status pools.
	owner.cleanse_toxin(0, 4_000_000)
	sim.t01.paralyze(owner, 0)
	sim.t01.freeze(owner, 3_000_000, 0)
	check(sim.timeline.apply_control(owner, "root", "weapons", 2_000_000, enemy.id, 0), "root applies")
	check(sim.t01.apply_status(owner, "雷蕴", 10, owner, 0), "thunder buff produces a real shield")
	grid.refresh(owner)
	for word: String in Special.definitions():
		check(grid.slots[word].visible, "actual status appears: " + word)
		check(not enemy_grid.slots[word].visible, "no cross-team leak: " + word)
	check(grid.counts["雷盾"].text == str(owner.thunder_shields.size()), "shield badge is actual layer count")
	for word: String in ["免疫", "麻痹", "冻结", "定身"]:
		check(not grid.counts[word].visible, "timed controls do not invent layers: " + word)
	for word: String in Special.definitions():
		var tip: BattleStatusTooltip = grid.slots[word]._make_custom_tooltip("")
		check(not tip._current.text.contains("未生效") and not tip._capacity.visible, "special tooltip uses actual state without false capacity: " + word)
		if word == "免疫": check(tip._current.text.contains("毒蚀"), "immunity scope is explicit")
		if word == "雷盾": check(tip._current.text.contains("盾量"), "shield tooltip includes remaining values")
		if word == "定身": check(tip._sources.text.contains(enemy.definition.name), "root preserves actual caster")
		tip.free()
	var frozen_state := Special.snapshot(owner, sim)
	await settle()
	check(Special.snapshot(owner, sim) == frozen_state, "paused wall time does not expire status")
	sim.state.time_usec = 1_000_000
	grid.refresh(owner)
	check(not grid.slots["麻痹"].visible and grid.slots["冻结"].visible, "paralysis expires at simulation deadline")
	sim.t01.paralyze(owner, 1_000_000)
	grid.refresh(owner)
	check(grid.slots["麻痹"].visible, "reapplied paralysis reappears")
	sim.timeline.cleanse(owner, 1_000_000)
	sim.timeline.clear_control(owner, "all", ["root", "freeze"], 1_000_000)
	sim.t01.discard_special(owner, "thunder_shield", 1_000_000)
	grid.refresh(owner)
	for word: String in ["麻痹", "冻结", "定身", "雷盾"]:
		check(not grid.slots[word].visible, "removed state hides immediately: " + word)
	sim.state.time_usec = 4_000_000
	grid.refresh(owner)
	check(not grid.slots["免疫"].visible, "immunity expires at simulation deadline")
	# Real shield damage removes the defender's icon and applies paralysis to its attacker.
	sim.t01.apply_status(owner, "雷蕴", 10, owner, 4_000_000)
	var shield_total := 0.0
	for value: float in owner.thunder_shields: shield_total += value
	var hit := shield_total / sim.cultivation.absorption(owner) + 1.0
	owner.hp = maxf(owner.hp, hit + 10.0)
	sim.t01.damage(enemy, owner, hit, "钝击", "base.element.none", 4_000_000, {"adjusted": true}, false, {"special": true})
	grid.refresh(owner)
	enemy_grid.refresh(enemy)
	check(owner.thunder_shields.is_empty() and not grid.slots["雷盾"].visible, "real damage depletes shield icon")
	check(enemy_grid.slots["麻痹"].visible, "shield break shows attacker paralysis")
	# Stale control entries do not outlive their authoritative deadline.
	sim.timeline.apply_control(owner, "root", "weapons", 1_000_000, enemy.id, 4_000_000)
	sim.t01.freeze(owner, 1_000_000, 4_000_000)
	sim.state.time_usec = 5_000_000
	grid.refresh(owner)
	check(not grid.slots["定身"].visible and not grid.slots["冻结"].visible, "root and freeze expire at exact deadline")
	# Persistent map/breakthrough users keep the original seven elemental buff slots.
	var elements := BattleStatusIcons.new()
	elements.element_buffs_only = true
	elements.configure()
	check(elements.slots.size() == 7 and not elements.slots.has("雷盾"), "element-only view unchanged")
	elements.free()
	# Reapply on both sides for native-size static previews and reset checks.
	for actor: PartyMemberState in [owner, enemy]:
		actor.cleanse_toxin(5_000_000, 4_000_000)
		sim.t01.paralyze(actor, 5_000_000)
		sim.t01.freeze(actor, 3_000_000, 5_000_000)
		sim.timeline.apply_control(actor, "root", "weapons", 2_000_000, owner.id, 5_000_000)
		sim.t01.apply_status(actor, "雷蕴", 10, actor, 5_000_000)
	await settle()
	if DisplayServer.get_name() != "headless":
		for resolution in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
			root.size = resolution
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/battle-special-status-20261113/status-%d.png" % resolution.y)
	game.restart()
	await settle()
	for word: String in Special.definitions():
		check(not ui.ally_panel.status_icons.slots[word].visible and not ui.enemy_panel.status_icons.slots[word].visible, "new battle clears status: " + word)
	scene.queue_free()
	await settle()
	print("SPECIAL STATUS ICONS: %d checks, %d failures; no mouse checks" % [checks, failures])
	quit(1 if failures else 0)
