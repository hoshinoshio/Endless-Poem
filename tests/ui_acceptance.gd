extends SceneTree

const Scene = preload("res://scenes/main.tscn")
const Store = preload("res://scripts/progression/collection_store.gd")
const Policy = preload("res://tests/battle_policy.gd")
const SAVE = "user://_ui_acceptance_v2.json"
const OUTPUT = "res://docs/verification/"
var app
var failures: Array = []
var checks = 0
var actions = 0
var phase_seen: Array = []
var anchors_clicked = 0

func _initialize():
	call_deferred("run")

func check(condition: bool, message: String):
	checks += 1
	print(("PASS " if condition else "FAIL ") + message)
	if not condition: failures.append(message)

func fresh_test_save():
	# Only this test's explicitly named isolated save and transaction files are removed.
	for suffix in ["", ".tmp", ".bak"]:
		var path = ProjectSettings.globalize_path(SAVE + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func create_app():
	app = Scene.instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app._process(0.0)
	await process_frame

func refresh():
	app._process(0.0)
	await process_frame

func click(control: Control):
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		check(false, "GUI click requires a visible control")
		return
	await process_frame
	var position = control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = position
	down.global_position = position
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = position
	up.global_position = position
	up.pressed = false
	root.push_input(up, true)
	await refresh()
	actions += 1

func click_target(id: String):
	var rect: Rect2 = app.get_battle_target_rect(id)
	if not rect.has_area():
		check(false, "target has valid battlefield bounds: " + id)
		return
	await physics_frame
	await process_frame
	var point := rect.get_center()
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
	await refresh()
	actions += 1

func key(code: Key):
	var down = InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up = InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	root.push_input(up, true)
	await refresh()
	actions += 1

func wheel_down():
	var position = app.deck_scroll.get_global_rect().get_center()
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.position = position
	event.global_position = position
	event.pressed = true
	root.push_input(event, true)
	var release = event.duplicate()
	release.pressed = false
	root.push_input(release, true)
	await refresh()

func capture(name: String):
	if DisplayServer.get_name() == "headless":
		print("SKIP screenshot in headless regression: " + name)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png(OUTPUT + name + ".png")
	check(result == OK, "rendered screenshot " + name)

func card_of_type(type: String, ready_only: bool = true) -> Dictionary:
	for card in app.snapshot.get("cards", []):
		if card.type == type and (not ready_only or card.playable): return card
	return {}

func reveal_card(id: String):
	if not app.deck_scroll.is_visible_in_tree(): await click(app.authority_button)
	app.deck_scroll.ensure_control_visible(app.card_buttons[id])
	await process_frame
	await process_frame

func fight_to_end(label: String, capture_phases: bool = false):
	var iterations = 0
	while app.snapshot.get("status", "") == "active" and iterations < 9000:
		iterations += 1
		var state: Dictionary = app.snapshot
		if capture_phases and not phase_seen.has(state.phase):
			phase_seen.append(state.phase)
			verify_layout()
			await capture("boss_phase_" + str(state.phase))
		var decision: Dictionary = Policy.choose(state)
		if not decision.is_empty():
			var id = str(decision.card_id)
			if not app.card_buttons.has(id):
				check(false, "policy card exists in UI")
				break
			await reveal_card(id)
			await click(app.card_buttons[id])
			if app.snapshot.selected_card_id != id:
				print("SELECT_DEBUG id=%s selected=%s card_rect=%s scroll=%s disabled=%s screen=%s open=%s" % [id, app.snapshot.selected_card_id, app.card_buttons[id].get_global_rect(), app.deck_scroll.scroll_vertical, app.card_buttons[id].disabled, app.screen, app.deck_open])
				check(false, "mouse selects entity " + id)
				break
			var target_id = str(decision.get("target_id", ""))
			if target_id.is_empty():
				await key(KEY_SPACE)
			else:
				if not app.get_battle_target_rect(target_id).has_area():
					check(false, "target has clickable battlefield bounds " + target_id)
					break
				for enemy in state.enemies:
					if enemy.id == target_id and enemy.is_anchor: anchors_clicked += 1
				await click_target(target_id)
		app._process(0.1)
		if iterations % 10 == 0: await process_frame
	check(app.snapshot.get("status", "") == "won", label + " won through GUI card and target clicks")
	print("BATTLE_RESULT %s status=%s hp=%s time=%s actions=%d iterations=%d" % [label, app.snapshot.get("status"), app.snapshot.get("hp"), app.snapshot.get("time"), actions, iterations])

func verify_layout():
	var canvas = Rect2(0, 0, 1440, 900)
	check(app.authority_button.get_global_rect().end.x < app.deck_scroll.get_global_rect().position.x, "clock authority is left of the grid")
	check(app.resources_label.position.y >= app.deck_scroll.get_global_rect().end.y, "player HP shield and energy sit below the card grid")
	check(app.focus_label.position.y >= app.deck_scroll.get_global_rect().end.y, "player focus sits below the card grid")
	for control in [app.resources_label, app.focus_label, app.hp_bar, app.energy_bar, app.focus_bar]:
		check(canvas.encloses(control.get_global_rect()), "player status fits inside the 1440x900 canvas")
	for child in app.page.get_children():
		if child is TextureRect:
			check(canvas.encloses(child.get_global_rect()) and child.size.x <= 350 and child.size.y <= 400, "v1 portrait is contained in its battlefield area")
	var grid = app.deck_scroll.get_child(0)
	check(grid is GridContainer and grid.columns == 6, "card grid has six columns")
	for enemy in app.snapshot.enemies:
		var target: Rect2 = app.get_battle_target_rect(str(enemy.id))
		check(target.end.y <= app.deck_scroll.position.y, "enemy and anchor target stay above expanded card grid")
		check(canvas.encloses(target), "battlefield target fits canvas")
		check(app.target_hp_bars[enemy.id].get_global_rect().end.y <= target.position.y, "enemy HP bar stays above its click target")
		if enemy.kind == "boss":
			var label_rect: Rect2 = app.target_hp_bars[enemy.id].get_global_rect()
			check(is_equal_approx(label_rect.get_center().x, 720.0) and is_equal_approx(label_rect.position.y, 90.0), "boss information is centered with ninety-pixel top margin")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	fresh_test_save()
	await create_app()
	check(app.collection.size() == 10 and app.equipped_ids.size() == 10, "first launch has exactly ten equipped starter entities")
	await capture("intro")
	app.begin_expedition(false)
	app.start_encounter("tutorial")
	await refresh()
	await capture("loadout")
	app.confirm_loadout()
	await refresh()
	check(app.snapshot.cards.size() == 10, "battle contains only ten equipped entities")
	check(not app.deck_scroll.is_visible_in_tree(), "battle starts with authority card grid collapsed")
	await capture("tutorial_collapsed")
	await click(app.authority_button)
	check(app.deck_scroll.is_visible_in_tree(), "clock icon opens authority card grid")
	check(is_equal_approx(float(app.snapshot.time_scale), 1.0), "opening grid does not apply slow time")
	var time_before: float = app.snapshot.time
	app._process(0.5)
	check(is_equal_approx(float(app.snapshot.time) - time_before, 0.5), "enemies continue while viewing the grid")
	verify_layout()
	await capture("tutorial_grid")
	var fire = card_of_type("fire")
	var energy_before: int = app.snapshot.energy
	await click(app.card_buttons[fire.id])
	check(app.snapshot.selected_card_id == fire.id, "mouse selects physical card")
	await key(KEY_ESCAPE)
	check(app.snapshot.selected_card_id == "" and app.deck_scroll.is_visible_in_tree(), "first Esc cancels selection and leaves grid open")
	check(app.snapshot.energy == energy_before, "cancel does not pay energy")
	await click(app.card_buttons[fire.id])
	await click(app.authority_button)
	check(app.snapshot.selected_card_id == "" and not app.deck_scroll.is_visible_in_tree(), "clock collapse cancels selection")
	check(app.snapshot.energy == energy_before, "collapse does not pay energy")
	await click(app.authority_button)
	await key(KEY_ESCAPE)
	check(not app.deck_scroll.is_visible_in_tree(), "Esc without selection collapses grid")
	await key(KEY_ESCAPE)
	check(app.snapshot.paused, "Esc with collapsed grid opens pause menu")
	time_before = app.snapshot.time
	app._process(1.0)
	check(is_equal_approx(float(app.snapshot.time), time_before), "pause freezes combat clock")
	await key(KEY_ESCAPE)
	check(not app.snapshot.paused, "Esc resumes from pause")
	await click(app.authority_button)
	await fight_to_end("tutorial")
	await capture("tutorial_victory")
	app.queue_free()
	await process_frame
	var store = Store.new()
	check(store.initialize(SAVE), "reload isolated collection")
	check(store.collection.size() == 10, "victory and reload do not duplicate starters")
	for i in 4: check(store.claim_reward("ui_fixture_source_" + str(i), "fire"), "separate fixture source grants owned duplicate " + str(i))
	check(store.equipped_ids.size() == 10, "new rewards do not automatically equip")
	check(store.set_equipped(store.collection.map(func(card): return card.id)), "equip fourteen distinct owned entities")
	await create_app()
	check(app.collection.size() == 14 and app.equipped_ids.size() == 14, "collection and equipment survive reload")
	app.begin_expedition(true)
	app.start_encounter("boss")
	app.confirm_loadout()
	await refresh()
	await click(app.authority_button)
	check(app.snapshot.cards.size() == 14, "boss uses all fourteen equipped entities")
	check(app.evidence.is_empty(), "quick trial does not grant narrative evidence")
	var ids_before = app.snapshot.cards.map(func(card): return card.id)
	var first_position: Vector2 = app.card_buttons[ids_before[0]].position
	for i in 8: await wheel_down()
	check(app.deck_scroll.scroll_vertical > 0, "mouse wheel reaches rows beyond twelve cards")
	await capture("authority_scroll")
	var scroll_before: int = app.deck_scroll.scroll_vertical
	await click(app.authority_button)
	await click(app.authority_button)
	check(app.deck_scroll.scroll_vertical == scroll_before, "collapse and reopen retain scroll position")
	app._process(0.5)
	check(app.snapshot.cards.map(func(card): return card.id) == ids_before, "updates retain physical card order")
	check(app.card_buttons[ids_before[0]].position == first_position, "updates retain card grid cells")
	var first_fire = card_of_type("fire")
	await reveal_card(first_fire.id)
	await click(app.card_buttons[first_fire.id])
	await click_target(str(app.snapshot.enemies[0].id))
	var remaining_by_id = {}
	for card in app.snapshot.cards: remaining_by_id[card.id] = card.remaining
	check(remaining_by_id[first_fire.id] > 0.0, "successful card enters cooldown in the original cell")
	var another_fire = card_of_type("fire")
	check(not another_fire.is_empty() and another_fire.id != first_fire.id and another_fire.remaining == 0.0, "another same-name entity remains independently ready")
	await fight_to_end("three_phase_boss", true)
	check(phase_seen.has(1) and phase_seen.has(2) and phase_seen.has(3), "GUI fight visits all three boss phases")
	check(anchors_clicked > 0, "GUI fight targets and destroys time anchors")
	check(app.screen == "practice_result" and not app.chapter_completed and app.record_choice == "", "quick victory does not bypass the chapter route or record choice")
	await capture("boss_victory")
	print("UI_ACCEPTANCE checks=%d failures=%d actions=%d phases=%s anchor_clicks=%d" % [checks, failures.size(), actions, phase_seen, anchors_clicked])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)






