extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 8: await process_frame

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.enemy_id = "base.enemy.chisong_liaozhu"
	game.loadout_save_path = ""
	root.add_child(scene)
	game.set_process(false)
	await settle()
	check(game.startup_error.is_empty(), "actual battle UI starts")
	var ui = scene.get_node("MainUI")
	var card: PartyMemberCard = ui.ally_panel.cards[0]
	var original: Vector2 = card.stat_icons.hp.global_position
	game.party[0].armor_capacity_sources.test = 10
	game.party[0].armor = 3.5
	game.party[0].barrier = 25
	card.refresh(game.party[0])
	check(not card.barrier_status.visible and not card.armor_status.visible, "rank/capacity alone never shows defense rows")
	check(game.party[0].inventory.add_item("test.shield", "base.map_item.t01_0096", Vector2i(0,0)), "equip actual shield source")
	check(game.party[0].inventory.add_item("test.hide", "base.organ.cslz_hide", Vector2i(1,0)), "equip actual armor source")
	card.refresh(game.party[0])
	await settle()
	check(card.stat_icons.hp.global_position == original, "extra rows preserve original resource positions")
	check(card.barrier_status.visible and card.armor_status.visible, "capacity shows both defense rows")
	check(card.barrier_status.current_label.text == "25" and card.barrier_status.maximum_label.text == "50", "shield reads actual value and capacity")
	check(card.armor_status.current_label.text == "3.5" and card.armor_status.maximum_label.text == "10", "armor retains fractional actual value")
	check(is_equal_approx(card.armor_status.bar.ratio,.35) and is_equal_approx(card.barrier_status.bar.ratio,.5), "defense fills reflect authoritative values")
	game.party[0].inventory.take("test.shield")
	card.refresh(game.party[0])
	check(not card.barrier_status.visible, "removing shield source refreshes visibility despite remaining value and capacity")
	game.party[0].inventory.add_item("test.shield", "base.map_item.t01_0096", Vector2i(0,0))
	card.refresh(game.party[0])
	var pitch: float = card.stat_icons.spirit.global_position.y-card.stat_icons.stamina.global_position.y
	check(is_equal_approx(card.stat_icons.hp.global_position.y-card.armor_status.global_position.y,pitch), "armor-to-health spacing equals resource rows")
	check(is_equal_approx(card.armor_status.global_position.y-card.barrier_status.global_position.y,pitch), "shield-to-armor spacing equals upper rows")
	for row: DefenseResourceRow in [card.barrier_status,card.armor_status]:
		check(row.bar.position.x == row.icon.size.x, "bar left meets icon boundary")
		check(is_equal_approx(row.slash_label.get_global_rect().get_center().x,row.bar.get_global_rect().get_center().x), "slash centers equal-width halves")
		check(is_equal_approx(row.bar.get_global_rect().get_center().x,card.stat_bars.spirit.get_global_rect().get_center().x), "defense center shares upper bar axis")
		check(row.bar.size.y == 26 and row.bar.get_global_rect().end.x < card.stat_bars.spirit.get_global_rect().end.x, "rounded right end exposed in shorter bar")
	game.party[0].armor = 0
	card.refresh(game.party[0])
	check(card.armor_status.visible, "zero current armor remains visible with capacity")
	game.party[0].armor_capacity_sources.erase("test")
	card.refresh(game.party[0])
	await settle()
	check(not card.armor_status.visible and card.stat_icons.hp.global_position == original, "no armor capacity hides only armor row")
	for path in ["zhuangtai-qx","zhuangtai-tl","zhuangtai-ll","player-status-sheild","player-status-armor","button-battle-fightlog"]:
		check((load("res://assets/"+path+".webp") as Texture2D).get_image().has_mipmaps(), "actual imported mipmaps: " + path)
	for icon: TextureRect in card.stat_icons.values():
		check(icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "resource icon uses mipmap sampler")
	var button: BattleActionButton = ui._battle_button
	button.caption = "战斗继续"
	button.action_icon = ui._battle_icon
	var origin := button.caption_origin()
	button.caption = "战斗暂停"
	button.action_icon = ui._wait_icon
	check(button.caption_origin() == origin, "pause caption remains at continue position")
	for number in [4,5]:
		var texture: Texture2D = load("res://assets/item-enemy-cslz-%d.webp"%number)
		var center := MapItemArtwork.TextureMetrics.alignment_center(texture)
		var footprint := Rect2(0,0,140,128)
		var rect := ItemDragPreview.fitted_icon_rect(texture,footprint)
		var used := Rect2(MapItemArtwork.TextureMetrics.inspect(texture).used_rect)
		check((rect.position + (center-used.position) * rect.size.x / used.size.x).is_equal_approx(footprint.get_center()), "optical item center aligns with cell %d"%number)
		var bounds: Rect2 = MapItemArtwork.TextureMetrics.inspect(texture).visible_rect
		check(center.x < bounds.get_center().x - 30 if number == 4 else center.is_equal_approx(bounds.get_center()), "mane keeps optical correction; heart uses visible geometric center %d"%number)
	var log_button: BattleActionButton = ui.find_child("BattleLogButton",true,false)
	check(log_button.artwork.atlas.resource_path == "res://assets/button-battle-fightlog.webp", "log button uses requested image")
	log_button.pressed.emit()
	check(ui._log_panel.visible, "replacement button retains log callback")
	ui._log_panel.hide()
	game.start_battle()
	game.pause_battle()
	game.party[0].armor_capacity_sources.test = 10
	game.party[0].armor = 3.5
	game.party[0].barrier = 25
	game.enemies[0].armor = 2
	game.enemies[0].barrier = 4
	ui._refresh()
	await settle()
	check(not ui.ally_panel.combat_status.text.contains("灵盾"), "no duplicate plain shield text")
	var left: float = ui.ally_panel.bags[0].get_global_rect().get_center().x
	var right: float = ui.enemy_panel.bags[0].get_global_rect().get_center().x
	check(is_equal_approx(root.size.x * .5 - left, right - root.size.x * .5), "boards equidistant from screen center")
	check(is_equal_approx(card.get_global_rect().get_center().x, left), "solo status group centers over board")
	check(is_equal_approx(card.nameplate.global_position.y, ui.enemy_panel.cards[0].nameplate.global_position.y), "enemy portrait plaque lowered to player baseline")
	check(is_equal_approx(ui.enemy_panel.cards[0].portrait.position.y, -18 + ui.enemy_panel.cards[0].portrait_vertical_offset), "enemy's baked-frame portrait moves down with plaque")
	check(is_equal_approx(card.armor_status.icon.position.x,0.375), "player armor shares enemy optical alignment")
	check(CooldownRing.FONT_SIZE == 10, "board timer font increased again by one")
	check(not ui.enemy_panel.cards[0].barrier_status.visible and ui.enemy_panel.cards[0].armor_status.visible, "boar shows hide armor but not innate shield capacity")
	print("BOARD CENTERS ",left," / ",right,"; center distance ",root.size.x*.5-left)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-status-polish.png")
	scene.queue_free()
	await settle()
	print("BATTLE STATUS POLISH: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
