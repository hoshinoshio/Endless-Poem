extends SceneTree

const Scene = preload("res://scenes/main.tscn")
const Policy = preload("res://tests/battle_policy.gd")
const SAVE = "user://_world_ui_acceptance.json"
var app
var failures: Array = []
var checks := 0
var sprite_clicks := 0

func _initialize():
	call_deferred("run")

func check(condition: bool, message: String):
	checks += 1
	print(("PASS " if condition else "FAIL ") + message)
	if not condition: failures.append(message)

func texture_fixture(first: Color, second: Color, width: int, height: int) -> GradientTexture2D:
	# Purely isolated test resources. Never written into the production assets.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([first, second])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = width
	texture.height = height
	return texture

func manifest_fixture() -> Dictionary:
	var actors := {}
	for kind in ["tutorial", "guard", "instrument", "observer", "elite", "boss", "anchor"]:
		actors[kind] = {"texture": texture_fixture(Color.DARK_RED, Color.ORANGE, 64, 128)}
	var encounters := {}
	for encounter in ["tutorial", "stairs", "patrol", "lamp", "elite", "corridor", "boss"]:
		encounters[encounter] = {"layers": [{"texture": texture_fixture(Color.DARK_BLUE, Color.BLACK, 1440, 488)}]}
	return {"player": {"texture": texture_fixture(Color.LIGHT_BLUE, Color.WHITE, 80, 160)}, "enemies": actors, "encounters": encounters}

func click_point(position: Vector2):
	await physics_frame
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = position
	down.global_position = position
	down.pressed = true
	root.push_input(down, true)
	await physics_frame
	await process_frame
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up, true)
	await physics_frame
	await process_frame
	app._process(0.0)

func click_target(id: String):
	var rect: Rect2 = app.get_battle_target_rect(id)
	if rect.size.x <= 0 or rect.size.y <= 0:
		check(false, "target has real sprite bounds: " + id)
		return
	await click_point(rect.get_center())
	sprite_clicks += 1

func start(encounter: String):
	app.start_encounter(encounter)
	app.confirm_loadout()
	await process_frame
	app._process(0.0)

func verify_world_layout():
	check(app.target_buttons.is_empty(), "world mode contains no enemy target Buttons")
	check(app.mouse_filter == Control.MOUSE_FILTER_IGNORE and app.page.mouse_filter == Control.MOUSE_FILTER_IGNORE, "UI root and page pass battlefield mouse events")
	check(app.deck_scroll.get_child(0).columns == 6 and app.deck_scroll.size == Vector2(1097, 270), "six-column two-row viewport is unchanged")
	check(app.authority_button.position == Vector2(172, 643), "clock authority position is unchanged")
	check(app.resources_label.position.y >= app.deck_scroll.get_rect().end.y and app.focus_label.position.y >= app.deck_scroll.get_rect().end.y, "HP shield energy and focus remain below the deck")
	var field := Rect2(0, 80, 1440, 488)
	for enemy in app.snapshot.enemies:
		var rect: Rect2 = app.get_battle_target_rect(str(enemy.id))
		check(rect.has_area() and field.encloses(rect), "sprite target fits battlefield: " + str(enemy.id))
		if enemy.kind == "boss":
			check(app.target_hp_bars[enemy.id].get_rect() == Rect2(430, 90, 580, 8), "Boss HP bar stays at x430 y90 width580")
		else:
			check(app.target_hp_bars[enemy.id].get_rect().end.y < rect.position.y, "ordinary HP bar follows above sprite: " + str(enemy.id))
		check(app.target_hp_bars[enemy.id].mouse_filter == Control.MOUSE_FILTER_IGNORE, "status bars do not block Area2D input")

func fight_with_sprite_clicks():
	var phases: Array = []
	var anchors_clicked := 0
	var iterations := 0
	while app.screen == "battle" and app.snapshot.status == "active" and iterations < 9000:
		iterations += 1
		if not phases.has(app.snapshot.phase):
			phases.append(app.snapshot.phase)
			verify_world_layout()
		var decision: Dictionary = Policy.choose(app.snapshot)
		if not decision.is_empty():
			if not app.deck_open: app.toggle_deck()
			app.choose_card(str(decision.card_id))
			var target := str(decision.get("target_id", ""))
			if target.is_empty():
				app.confirm_selected()
			else:
				for enemy in app.snapshot.enemies:
					if enemy.id == target and enemy.is_anchor: anchors_clicked += 1
				await click_target(target)
		app._process(0.1)
		if iterations % 20 == 0: await process_frame
	check(app.snapshot.status == "won", "three-phase Boss is won using sprite Area2D target clicks")
	check(phases == [1, 2, 3], "snapshot and stage visit all three Boss phases")
	check(anchors_clicked > 0, "spawned time anchors are clicked through viewport input")
	check(app.screen == "practice_result" and not app.chapter_completed, "world presentation preserves quick-trial progression rules")
	print("WORLD_UI_BOSS iterations=%d phases=%s anchor_clicks=%d" % [iterations, phases, anchors_clicked])

func run():
	for suffix in ["", ".tmp", ".bak"]:
		var path := ProjectSettings.globalize_path(SAVE + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	app = Scene.instantiate()
	# Explicit isolated legacy baseline exercises fallback before the fixture is supplied.
	app.battle_visual_assets = {}
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	app.set_process(false)
	await start("tutorial")
	check(not is_instance_valid(app.battle_world) and app.target_buttons.size() == 1, "explicit empty test manifest uses legacy mode until fixture is supplied")
	var state_before: Dictionary = app.snapshot.duplicate(true)
	check(not app.set_battle_visual_assets({"player": {}}), "incomplete manifest is rejected")
	check(not is_instance_valid(app.battle_world) and app.target_buttons.size() == 1, "incomplete manifest cannot create an empty official battlefield")
	check(app.snapshot == state_before, "rejecting assets does not change combat state")
	var assets := manifest_fixture()
	app.toggle_deck()
	check(app.set_battle_visual_assets(assets), "complete isolated fixture enables 2D stage")
	check(app.deck_open and app.snapshot == state_before, "asset switching keeps deck visibility and combat snapshot")
	verify_world_layout()
	check(not app.scenery.visible, "world scene replaces legacy scenery")
	var legacy_portraits: Array = app.page.get_children().filter(func(child): return child is TextureRect)
	check(legacy_portraits.is_empty(), "world mode removes legacy player TextureRect")
	check(app.battle_world.stage.actors.player.has_art, "player is rendered as an actual stage actor")
	var fire: Dictionary = {}
	for card in app.snapshot.cards:
		if card.type == "fire":
			fire = card
			break
	var enemy_id := str(app.snapshot.enemies[0].id)
	var hp_before := int(app.snapshot.enemies[0].hp)
	var energy_before := int(app.snapshot.energy)
	check(app.choose_card(str(fire.id)), "existing card selection still drives world mode")
	await click_target(enemy_id)
	check(int(app.snapshot.energy) == energy_before - int(fire.cost) and app.snapshot.pending.size() == 1 and app.snapshot.selected_card_id == "", "real viewport sprite click registers chosen card exactly once")
	check(app.battle_world.last_snapshot == app.snapshot, "presenter snapshot matches combat exactly")
	var stage = app.battle_world.stage
	var real_before: float = stage.real_elapsed
	var battle_before: float = stage.battle_elapsed
	app._process(0.5)
	check(is_equal_approx(stage.real_elapsed - real_before, 0.5) and is_equal_approx(stage.battle_elapsed - battle_before, 0.1), "world feedback advances by actual slowed battle delta")
	app.show_pause()
	var animation_before: float = stage.actors.player.animation_elapsed
	battle_before = stage.battle_elapsed
	app._process(1.0)
	check(is_equal_approx(stage.battle_elapsed, battle_before) and is_equal_approx(stage.actors.player.animation_elapsed, animation_before), "pause freezes sprite feedback and battle animation")
	check(app.overlay.is_visible_in_tree(), "pause GUI remains visible while world feedback freezes")
	app.close_overlay()
	app._process(0.11)
	check(int(app.snapshot.enemies[0].hp) == hp_before - 6, "sprite-targeted cast resolves normal delayed combat damage")
	await start("stairs")
	verify_world_layout()
	var incomplete := assets.duplicate(true)
	incomplete.enemies.erase("anchor")
	check(not app.set_battle_visual_assets(incomplete), "future instrument anchors must have art before stage activation")
	check(not is_instance_valid(app.battle_world), "missing future targets preserve legacy battlefield")
	check(app.set_battle_visual_assets(assets), "complete manifest re-enables world mode")
	app.quick_mode = true
	await start("boss")
	await fight_with_sprite_clicks()
	check(not is_instance_valid(app.battle_world) and app.scenery.visible, "leaving battle releases stage and restores nonbattle scenery")
	print("WORLD_UI_ACCEPTANCE checks=%d failures=%d sprite_clicks=%d" % [checks, failures.size(), sprite_clicks])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
