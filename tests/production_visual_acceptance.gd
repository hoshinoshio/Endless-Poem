extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const Policy = preload("res://tests/battle_policy.gd")
const SAVE := "user://_production_visual_acceptance.json"
const OUTPUT := "res://docs/verification/"
var app
var checks := 0
var failures := 0
var clicks := 0
var anchors := 0
var phases: Array = []
var captured := {}

func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1

func click_at(point: Vector2):
	await physics_frame
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = point
	down.global_position = point
	down.pressed = true
	root.push_input(down, true)
	await physics_frame
	await process_frame
	var up = down.duplicate()
	up.pressed = false
	root.push_input(up, true)
	await physics_frame
	await process_frame
	app._process(0.0)
	clicks += 1

func space():
	var down := InputEventKey.new()
	down.keycode = KEY_SPACE
	down.physical_keycode = KEY_SPACE
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up = down.duplicate()
	up.pressed = false
	root.push_input(up, true)
	app._process(0.0)

func capture(id: String):
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	check(image != null and not image.is_empty(), "real rendered viewport: " + id)
	if image != null: image.save_png(OUTPUT + "production_" + id + ".png")
	captured[id] = true

func start(encounter: String):
	app.run_hp = 50
	app.start_encounter(encounter)
	app.confirm_loadout()
	await process_frame
	app._process(0.0)
	check(is_instance_valid(app.battle_world) and app.battle_visual_missing_assets.is_empty(), "production art and animation complete: " + encounter)

func cast_card(id: String, target: String):
	if not app.deck_open: await click_at(app.authority_button.get_global_rect().get_center())
	await click_at(app.card_buttons[id].get_global_rect().get_center())
	if target.is_empty(): await space()
	else:
		for enemy in app.snapshot.enemies:
			if enemy.id == target and enemy.is_anchor: anchors += 1
		await click_at(app.get_battle_target_rect(target).get_center())

func run():
	for suffix in ["", ".tmp", ".bak"]:
		var file := ProjectSettings.globalize_path(SAVE + suffix)
		if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	app = Scene.instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.quick_mode = true
	await start("boss")
	check(app.snapshot.cards.size() == 10, "complete battle starts with ordinary ten-card collection")
	var stage = app.battle_world.stage
	check(is_equal_approx(stage.actors.player.get_visual_height(), 217.0), "player frame height is 310 * 0.70 = 217")
	check(stage.actors.player.animated_sprite.visible and stage.actors.player.has_animation("cast"), "real player pose resources are active")
	check(stage.authority_fx.source.x < stage.actors.player.position.x and stage.authority_fx.z_index < stage.actors.player.z_index, "authority is behind player; no book origin")
	check(stage.actors.values().all(func(actor): return not actor.uses_static_seed), "all current units use production pose resources")
	await capture("boss_ready")
	var loops := 0
	var fx_checked := false
	while app.screen == "battle" and app.snapshot.status == "active" and loops < 9000:
		loops += 1
		if not phases.has(app.snapshot.phase):
			phases.append(app.snapshot.phase)
			await capture("boss_phase_" + str(app.snapshot.phase))
		var decision: Dictionary = Policy.choose(app.snapshot)
		if not decision.is_empty():
			await cast_card(str(decision.card_id),str(decision.target_id))
			if not fx_checked and not str(decision.target_id).is_empty():
				app._process(0.70)
				app._process(0.06)
				var effects: Dictionary = stage.authority_fx.presentation_state()
				check(effects.beam_count == 8 and effects.targets.has(str(decision.target_id)), "eight live radial time streams aim at the selected enemy")
				await capture("authority_cast")
				app.show_pause()
				var saved_fx: Dictionary = stage.authority_fx.presentation_state().duplicate(true)
				app._process(1.0)
				check(stage.authority_fx.presentation_state() == saved_fx, "real production FX freeze in pause")
				app.close_overlay()
				fx_checked = true
		app._process(0.1)
		if loops % 25 == 0: await process_frame
	check(app.snapshot.status == "won", "normal mouse card / sprite target battle wins")
	check(phases == [1,2,3] and anchors > 0, "full three-phase Boss and real anchor targets completed")
	check(app.screen == "practice_result" and not app.chapter_completed, "practice completion does not award story completion")
	print("PRODUCTION_BATTLE seconds=%.2f hp=%d phases=%s anchor_clicks=%d clicks=%d" % [app.snapshot.time,app.snapshot.hp,phases,anchors,clicks])
	await capture("boss_victory")
	# Separate isolated save rewards let real spells demonstrate debuffs, with no
	# direct HP, energy, cooldown or enemy-state assignment in these captures.
	check(app.store.claim_reward("visual_test:ember", "ember") and app.store.claim_reward("visual_test:delay", "delay"), "isolated test collection accepts two distinct exploration rewards")
	var equipped: Array = []
	var ember := ""
	var delay := ""
	for card in app.collection:
		equipped.append(card.id)
		if card.type == "ember": ember = card.id
		if card.type == "delay": delay = card.id
	app.store.set_equipped(equipped)
	for encounter in ["patrol","boss"]:
		await start(encounter)
		var id: String = app.snapshot.enemies[0].id
		await cast_card(ember,id)
		app._process(0.7)
		await cast_card(delay,id)
		app._process(0.7)
		app.update_battle()
		var icons = app.target_debuffs[id]
		check(icons.entries.size() == 2 and not icons.visible, "real casts retain burn and delay while health-only HUD omits their readouts: " + encounter)
		var health: Rect2 = app.target_hp_bars[id].get_rect()
		check(app.target_hp_bars[id].visible and not app.target_hp_bars[id].show_percentage and not app.target_labels[id].visible and not app.target_bars[id].visible, "only the unlabeled health bar is visible: " + encounter)
		await capture(encounter + "_health_only")
	# Natural loss and fresh combat reset, without modifying model health.
	var limit := 0
	while app.screen == "battle" and limit < 1600:
		app._process(0.25)
		limit += 1
	check(app.snapshot.status == "lost", "natural enemy actions can still defeat player")
	await start("boss")
	check(app.snapshot.cards.all(func(card): return is_zero_approx(card.remaining)), "new attempt resets all card cooldowns")
	check(app.collection.size() == 12, "loss and retry retain collection without duplicate starter grants")
	print("PRODUCTION_VISUAL_ACCEPTANCE checks=%d failures=%d" % [checks,failures])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
