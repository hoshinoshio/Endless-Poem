extends SceneTree
## Isolated placed fixtures, settled through real simulation; this is not a full-map walk.
const Store = preload("res://scripts/progression/collection_store.gd")
const Session = preload("res://scripts/exploration/exploration_session.gd")
var session
var store
var checks = 0
var failures: Array = []
var received: Array = []
var path = ""
func _initialize(): call_deferred("run_test")
func check(value: bool, label: String):
	checks += 1
	print("PASS " if value else "FAIL ", label)
	if not value: failures.append(label)
func key(code: int, down: bool, echo = false):
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
func tap(code: int):
	await key(code,true)
	await key(code,false)
func click(node):
	var point = node.get_global_rect().get_center()
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
func settle(position: Vector2):
	session.world.set_player_position(position)
	for frame in 90:
		session._physics_process(1.0/60.0)
		if frame % 6 == 0: await physics_frame
	session.world.camera.force_update_scroll()
	await process_frame
	print("PLACED_FIXTURE position=",session.world.player.position," grounded=",session.world.player.grounded)
func snapshot(label: String):
	session.world.queue_redraw()
	session.world.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	check(frame != null and frame.get_size() == Vector2i(1440,900),"1440x900 GPU frame " + label)
	check(frame.save_png("res://docs/verification/proximity_"+label+".png") == OK,"saved screenshot " + label)
func text_contents(node) -> String:
	var result = ""
	if node is Label or node is Button: result += node.text + "\n"
	for child in node.get_children(): result += text_contents(child)
	return result
func run_test():
	if DisplayServer.get_name() == "headless": quit(2); return
	path = "user://proximity_gpu_%d.json" % Time.get_ticks_usec()
	store = Store.new()
	check(store.initialize_time_authority(path),"isolated authority store")
	session = Session.new()
	root.add_child(session)
	session.configure(store,true)
	session._accept_opening()
	session.set_physics_process(false)
	session._tutorial_event("walked",{})
	session._tutorial_event("jump_landed",{})
	session.world.interaction_requested.connect(func(id): received.append(id))
	await settle(Vector2(200,1850))
	check(not session.world.proximity_interaction().visible,"far fixture has no E badge")
	await tap(KEY_E)
	check(received.is_empty() and session.mode == "explore","far actual E emits no interaction")
	await snapshot("01_far")
	await settle(Vector2(1830,1640))
	var prompt = session.world.proximity_interaction()
	check(session.world.player.grounded and absf(session.world.player.position.y-1690)<4,"device fixture settles on real low platform")
	check(prompt.visible and prompt.id == "stalled_device" and prompt.key == "E" and prompt.world_position.y < 1690,"near valid device badge above object")
	await snapshot("02_near")
	await key(KEY_E,true)
	check(received == ["stalled_device"] and session.mode == "device","actual E emits exactly one native signal and opens device")
	await key(KEY_E,true,true)
	await key(KEY_E,false)
	check(received.size() == 1,"held E echo emits no extra signal")
	check(session.world.paused and not session.world.proximity_interaction().visible,"device dialog pauses and hides badge")
	check(store.get_authority_loadout().is_empty(),"opening device grants zero cards")
	await snapshot("03_device_panel")
	var panel_text = text_contents(session.dialog)
	check(not "按" in panel_text and not "E" in panel_text and not "Esc" in panel_text,"device UI has no key tutorial instructions")
	await tap(KEY_ESCAPE)
	check(session.mode == "explore" and not session.world.paused and session.dialog == null,"actual Escape cancels and resumes")
	await tap(KEY_E)
	check(received.size() == 2,"second actual E emits exactly once")
	await click(session.ui_buttons.repair_device)
	check(session.mode == "device_complete" and store.get_authority_loadout().size() == 3 and session.run.authority_unlocked,"real mouse repair grants exactly three cards")
	var saved = store.data.duplicate(true)
	await tap(KEY_E)
	check(store.data == saved and received.size() == 2,"completion E grants nothing twice")
	await click(session.ui_buttons.continue)
	check(session.mode == "explore" and not session.world.paused,"real Continue click resumes")
	await snapshot("04_repaired_continue")
	await tap(KEY_E)
	check(received.size() == 3 and session.mode == "device" and not session.ui_buttons.has("repair_device") and store.get_authority_loadout().size() == 3,"revisit emits once and offers no repeat repair")
	await tap(KEY_ESCAPE)
	await tap(KEY_ESCAPE)
	check(session.mode == "pause" and not session.world.proximity_interaction().visible,"pause hides proximity badge")
	await tap(KEY_ESCAPE)
	await settle(session.world.observer_npc.position-Vector2(65,45))
	check(session.world.player.grounded and session.world.proximity_interaction().id == "testimony","NPC fixture settles and presents valid badge")
	await tap(KEY_E)
	check(received.size() == 4 and received.back() == "testimony" and is_instance_valid(session.dialog),"NPC actual E emits exactly once and opens interface")
	check(not session.world.proximity_interaction().visible,"NPC dialog hides badge")
	await snapshot("05_npc_panel")
	await tap(KEY_ESCAPE)
	check(session.mode == "explore" and not session.world.paused,"NPC Escape resumes")
	session.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PROXIMITY_INTERACTION_GPU checks=",checks," failures=",failures.size()," labels=",failures)
	quit(0 if failures.is_empty() else 1)
