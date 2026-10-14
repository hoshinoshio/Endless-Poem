extends SceneTree
## Production default scene; isolated save; all traversal uses normal inputs.
var game
var session
var checks := 0
var failures: Array = []
var clicks := 0
var path := ""
func _initialize(): call_deferred("run_test")
func check(value: bool, message: String):
	checks += 1
	print("PASS " if value else "FAIL ",message)
	if not value: failures.append(message)
func snapshot(label: String):
	if is_instance_valid(session) and session.world != null: session.world.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	check(frame != null and not frame.is_empty(),"Godot rendered "+label)
	frame.save_png("res://docs/verification/authority_entry_"+label+".png")
func click_point(point: Vector2):
	var move = InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move,true)
	var event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await process_frame
	clicks += 1
func click(node): await click_point(node.get_global_rect().get_center())
func key(code: Key, down: bool):
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
func tap(code: Key):
	await key(code,true)
	await key(code,false)
func ticks(count: int):
	for frame in count:
		session._physics_process(1.0/60.0)
		if frame % 12 == 0: await physics_frame
func walk_to(x: float):
	await key(KEY_D,true)
	for frame in 600:
		if session.world.player.position.x >= x: break
		session._physics_process(1.0/60.0)
		if frame % 12 == 0: await physics_frame
	await key(KEY_D,false)
	await ticks(14)
func run_test():
	if DisplayServer.get_name() == "headless": quit(2); return
	path = "user://authority_entry_%d.json" % Time.get_ticks_usec()
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	game.save_path = path
	root.add_child(game)
	await process_frame
	check(game.screen == "start_menu" and game.start_menu.theme_mode == "A","default Godot entry retains approved A menu")
	check(game.store.collection.is_empty() and game.store.get_authority_loadout().is_empty(),"fresh production entry grants no legacy or time cards")
	await snapshot("01_menu")
	await click(game.start_menu.buttons.new)
	session = game.exploration_session
	session.set_physics_process(false)
	check(session.mode == "opening","normal New opens story")
	session.opening.set_process(false)
	session.opening.advance(30)
	session.opening.advance(0.5)
	await click(session.opening.buttons.no)
	for i in 3:
		session.opening.advance(0.6)
		await click(session.opening.buttons.refuse_again)
	session.opening.advance(0.6)
	check(not session.opening.buttons.refuse_again.visible and session.opening.buttons.accept_refusal.visible,"third refusal leaves a real accept button")
	await snapshot("02_refusal")
	await click(session.opening.buttons.accept_refusal)
	await physics_frame
	await ticks(20)
	check(session.mode == "explore" and not session.run.authority_unlocked,"accepted story enters powerless exploration")
	check(session.card_buttons.is_empty() and not is_instance_valid(session.authority_button),"no clock/card controls before acquisition")
	await snapshot("03_powerless")
	await walk_to(900)
	check(session.run.authority_tutorial_step == 1,"real movement finds device problem")
	# Jump on flat ground must not solve the elevated-device problem.
	await tap(KEY_SPACE)
	await ticks(90)
	check(session.run.authority_tutorial_step == 1,"jumping away from device cannot bypass platform problem")
	await walk_to(1500)
	await key(KEY_D,true)
	await tap(KEY_SPACE)
	await ticks(22)
	await snapshot("04_jump")
	for frame in 100:
		if session.world.player.position.x >= 1875: break
		session._physics_process(1.0/60.0)
		if frame % 12 == 0: await physics_frame
	await key(KEY_D,false)
	await ticks(90)
	print("ACTUAL_PLATFORM ",session.world.player.position," grounded=",session.world.player.grounded," step=",session.run.authority_tutorial_step)
	check(session.world.player.grounded and absf(session.world.player.position.y-1690)<4 and session.run.authority_tutorial_step == 2,"walk+jump lands on real repair platform")
	await snapshot("05_device")
	await tap(KEY_E)
	check(session.run.authority_unlocked and game.store.get_authority_loadout().size() == 3,"real E repairs and atomically grants exactly three cards")
	check(game.store.collection.is_empty(),"no old fire entities introduced by repair")
	await ticks(60)
	if not session.run.authority_unlocked:
		finish(); return
	await click(session.authority_button)
	check(session.deck_open and session.card_buttons.keys() == ["stop","fast_forward","reverse"],"clock opens only the three requested cards")
	await snapshot("06_three_cards")
	await click(session.card_buttons.stop)
	var target = session.world.temporal.get_presentation().targets.stalled_device.screen_rect
	await click_point(target.get_center())
	check(session.world.temporal.get_presentation().targets.stalled_device.mode == "stop","normal card and scenery click applies stop")
	var phase: float = session.world.ambient.objects.stalled_device.phase
	await ticks(24)
	check(session.world.ambient.objects.stalled_device.phase == phase,"stopped device actually stops while world runs")
	await click(session.card_buttons.fast_forward)
	await click_point(target.get_center())
	await ticks(30)
	check(session.world.ambient.objects.stalled_device.phase > phase,"fast forward resumes and advances scenery")
	phase = session.world.ambient.objects.stalled_device.phase
	await click(session.card_buttons.reverse)
	await click_point(target.get_center())
	await ticks(15)
	check(session.world.ambient.objects.stalled_device.phase < phase,"reverse restores recorded scenery states")
	await click(session.card_buttons.stop)
	await click_point(session.world.temporal.get_presentation().targets.player.screen_rect.get_center())
	check(session.world.temporal.get_presentation().targets.player.mode == "stop","player is also a valid target")
	await click(session.card_buttons.fast_forward)
	await click_point(session.world.temporal.get_presentation().targets.player.screen_rect.get_center())
	await tap(KEY_ESCAPE)
	check(session.world.temporal.selected_card.is_empty() and session.deck_open,"Escape first cancels target selection")
	await tap(KEY_ESCAPE)
	check(not session.deck_open,"Escape next closes cards")
	await tap(KEY_ESCAPE)
	check(session.mode == "pause","Escape then opens pause")
	var before: Vector2 = session.world.player.position
	await ticks(30)
	check(session.world.player.position == before,"pause freezes world")
	await click(session.ui_buttons.menu)
	check(game.screen == "start_menu","normal pause menu returns to approved menu")
	await click(game.start_menu.buttons.authority)
	check(game.screen == "collection","main authority page uses new collection")
	await snapshot("07_collection")
	game.show_start_menu()
	await click(game.start_menu.buttons["continue"])
	check(session.run.authority_unlocked and session.card_buttons.size()==3,"Continue retains exactly three acquired cards")
	await snapshot("08_continue")
	var Store = load("res://scripts/progression/collection_store.gd")
	var reload = Store.new()
	check(reload.initialize_time_authority(path) and reload.get_authority_loadout().size()==3 and reload.data.exploration_run.authority_unlocked,"disk reopen retains completed acquisition")
	finish()
func finish():
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("AUTHORITY_ENTRY_GPU checks=",checks," failures=",failures.size()," clicks=",clicks," labels=",failures)
	quit(0 if failures.is_empty() else 1)
