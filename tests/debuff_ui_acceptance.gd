extends SceneTree
const Scene = preload("res://scenes/main.tscn")
var app
var failures := 0
var checks := 0
var passed_click := false
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1
func start(encounter: String):
	app.start_encounter(encounter)
	app.confirm_loadout()
	await process_frame
	app._process(0.0)
func click_point(point: Vector2):
	await physics_frame
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.position = point
	down.global_position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	await physics_frame
	await process_frame
	var up = down.duplicate()
	up.pressed = false
	root.push_input(up, true)
	await physics_frame
	await process_frame
func run():
	app = Scene.instantiate()
	app.save_path = "user://_debuff_ui_acceptance.json"
	root.add_child(app)
	await process_frame
	app.set_process(false)
	for encounter in ["tutorial", "stairs", "patrol", "lamp", "elite", "corridor", "boss"]:
		await start(encounter)
		check(is_instance_valid(app.battle_world), "default production world enabled: " + encounter)
		if not is_instance_valid(app.battle_world): continue
		check(app.battle_world.z_index == 50 and app.page.z_index == 100, "world background and actors render below HUD")
		var enemy: Dictionary = app.snapshot.enemies[0]
		var id: String = enemy.id
		if encounter == "tutorial":
			app.toggle_deck()
			var fire: Dictionary = {}
			for card in app.snapshot.cards:
				if card.type == "fire": fire = card; break
			var energy_before := int(app.snapshot.energy)
			check(not fire.is_empty() and app.choose_card(str(fire.id)), "world HUD selects existing fire card")
			await click_point(app.get_battle_target_rect(id).get_center())
			check(app.snapshot.selected_card_id == "" and app.snapshot.pending.size() == 1 and int(app.snapshot.energy) == energy_before - int(fire.cost), "official sprite Area2D click through HUD casts exactly once")
			enemy = app.snapshot.enemies[0]
		enemy.burn = 3
		enemy.echo_mark = true
		app.snapshot.pending = [{"kind": "delay", "target": id, "remaining": 4.2, "label": "延时爆发"}, {"kind": "enemy_echo", "target": id, "remaining": 2.0, "label": "敌方残响"}]
		app.update_battle()
		var icons = app.target_debuffs[id]
		check(not icons.visible, "health-only HUD keeps debuffs hidden after refresh")
		check(icons.entries.size() == 2 and icons.entries[0].value == "3" and icons.entries[1].value == "4.2", "burn and real delay remain synchronized; friendly echo excluded")
		check(icons.mouse_filter == Control.MOUSE_FILTER_IGNORE and app.target_hp_bars[id].mouse_filter == Control.MOUSE_FILTER_IGNORE, "icons and HP bars pass mouse events")
		if encounter == "tutorial":
			var probe := Button.new()
			probe.position = icons.position
			probe.size = icons.size
			probe.pressed.connect(func(): passed_click = true)
			app.page.add_child(probe)
			app.page.move_child(probe, icons.get_index())
			await process_frame
			var motion := InputEventMouseMotion.new()
			motion.position = icons.position + Vector2(12,12)
			motion.global_position = motion.position
			root.push_input(motion, true)
			var down := InputEventMouseButton.new()
			down.position = motion.position
			down.global_position = motion.position
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			root.push_input(down, true)
			await process_frame
			var up = down.duplicate()
			up.pressed = false
			root.push_input(up, true)
			await process_frame
			check(passed_click, "viewport click passes through native debuff canvas")
			probe.queue_free()
		var health: Rect2 = app.target_hp_bars[id].get_rect()
		if enemy.kind == "boss":
			check(health == Rect2(430,90,580,8) and icons.icon_size == 36 and icons.position.y == 103, "Boss fixed bar and enlarged icons below bar")
			check(icons.get_rect().end.y <= app.target_labels[id].position.y, "Boss icons clear name phase and intent")
		else:
			check(icons.icon_size == 24 and icons.get_rect().end.y < health.position.y, "ordinary icons are above actual HP bar")
		if DisplayServer.get_name() != "headless" and encounter in ["tutorial", "boss"]:
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png("res://docs/verification/debuff_%s.png" % encounter)
		app.snapshot.pending[0].remaining = 1.6
		app.update_battle()
		check(icons.entries[1].value == "1.6", "countdown follows snapshot")
		enemy.burn = 0
		app.snapshot.pending = []
		app.update_battle()
		check(icons.entries.is_empty() and not icons.visible, "cleared states remove icons")
		enemy.burn = 2
		enemy.hp = 0
		app.update_battle()
		check(icons.entries.is_empty(), "dead enemy has no icons")
		enemy.hp = 1
		app.update_battle()
		var before: Dictionary = app.snapshot.duplicate(true)
		icons.sync_state(enemy, app.snapshot.pending)
		check(app.snapshot == before, "decorations do not mutate combat state")
		app.snapshot.enemies.remove_at(0)
		app.update_battle()
		check(not app.target_debuffs.has(id), "removed enemies release icon nodes")
	app.show_pause()
	check(app.overlay.z_index == 200, "modal UI remains over world and HUD")
	print("DEBUFF_UI_ACCEPTANCE checks=%d failures=%d" % [checks, failures])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
