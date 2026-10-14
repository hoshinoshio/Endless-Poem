extends SceneTree

const Scene = preload("res://scenes/main.tscn")
var app
var failures := 0
var checks := 0

func _initialize(): call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1

func verify_hud():
	check(app.hp_bar.visible and app.hp_bar.value == app.snapshot.hp and app.hp_bar.size.y == 8, "player health stays visible without percentage")
	for control in [app.resources_label, app.energy_bar, app.focus_label, app.focus_bar, app.time_label, app.pending_label, app.recovery_label, app.message_label, app.log_label, app.pause_button]:
		check(not control.visible, "auxiliary status remains hidden: " + control.get_class())
	for enemy in app.snapshot.enemies:
		var id: String = enemy.id
		check(app.target_hp_bars[id].visible and app.target_hp_bars[id].value == enemy.hp, "target exposes actual health: " + id)
		check(not app.target_labels[id].visible and not app.target_bars[id].visible and not app.target_debuffs[id].visible, "target hides name numbers action and debuffs: " + id)
		if enemy.kind == "boss": check(app.target_hp_bars[id].get_rect() == Rect2(430, 90, 580, 8), "Boss health remains centered at y90")
	for child in app.page.get_children():
		check(not (child is Panel and child.visible), "battle has no placeholder panel")
		if child is Label: check(not child.visible, "battle root labels are hidden")
	check(app.deck_scroll.get_child(0).columns == 6 and app.deck_scroll.size == Vector2(1097, 270), "card six-column two-row grid unchanged")
	check(app.card_buttons.size() == app.snapshot.cards.size(), "all illustrated cards retained")

func escape():
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	app._unhandled_input(event)

func run():
	app = Scene.instantiate()
	app.save_path = "user://_health_only_hud_acceptance.json"
	root.add_child(app)
	await process_frame
	app.set_process(false)
	for encounter in ["tutorial", "boss", "tutorial"]:
		app.start_encounter(encounter)
		app.confirm_loadout()
		await process_frame
		verify_hud()
		app.snapshot.last_message = "hidden damage message"
		app.snapshot.recovery = {"remaining": 10, "living_anchors": 2, "total_anchors": 2, "recorded_hp": 30}
		var spawned: Dictionary = app.snapshot.enemies[0].duplicate(true)
		spawned.id = "health_probe"
		spawned.kind = "anchor"
		spawned.is_anchor = true
		spawned.burn = 3
		app.snapshot.enemies.append(spawned)
		app.update_battle()
		verify_hud()
		app.snapshot = app.combat.get_snapshot()
		app.update_battle()
		app.toggle_deck()
		var self_card: Dictionary = {}
		for card in app.snapshot.cards:
			if card.target == "self" and card.playable: self_card = card; break
		check(not self_card.is_empty() and app.choose_card(str(self_card.id)), "self card selection works")
		check(app.confirm_button.visible, "self card confirm remains visible")
		escape()
		check(app.snapshot.selected_card_id == "" and app.deck_open and not app.confirm_button.visible, "first Esc cancels card")
		escape()
		check(not app.deck_open and not is_instance_valid(app.overlay), "second Esc closes deck")
		escape()
		check(is_instance_valid(app.overlay) and app.overlay_pauses, "third Esc opens pause")
		app.show_settings()
		check(is_instance_valid(app.overlay) and app.overlay_pauses, "settings remains reachable while paused")
		escape()
		check(not is_instance_valid(app.overlay) and not app.overlay_pauses, "Esc closes modal and resumes")
		verify_hud()
	print("HEALTH_ONLY_HUD checks=%d failures=%d" % [checks, failures])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
