extends SceneTree
const Store = preload("res://scripts/progression/collection_store.gd")
const Session = preload("res://scripts/exploration/exploration_session.gd")
var failures: Array = []
var checks = 0
var signals_received: Array = []
func _initialize() -> void: call_deferred("run_test")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL ", label)
func press(session, key: int, echo = false) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	event.echo = echo
	session._unhandled_input(event)
func approach(session, position: Vector2) -> void:
	session.world.set_player_position(position)
	session.world.player.grounded = true
	session.world._update_regions_and_triggers()
func run_test() -> void:
	var path = "user://proximity_interaction_session_%d.json" % Time.get_ticks_usec()
	var store = Store.new()
	check(store.initialize_time_authority(path), "isolated authority store initializes")
	var session = Session.new()
	root.add_child(session)
	session.configure(store, true)
	session._accept_opening()
	session.set_physics_process(false)
	session._tutorial_event("walked", {})
	session._tutorial_event("jump_landed", {})
	session.world.interaction_requested.connect(func(id): signals_received.append(id))
	approach(session, Vector2(200,1900))
	press(session, KEY_E)
	check(session.mode == "explore" and session.dialog == null and signals_received.is_empty(), "out of range E opens no interface")
	approach(session, Vector2(1900,1690))
	session._jump = true
	press(session, KEY_E)
	check(signals_received == ["stalled_device"] and session.mode == "device", "in range native E signal opens device interface")
	check(not session.run.authority_unlocked and store.get_authority_loadout().is_empty(), "opening interface grants no cards")
	check(session.world.paused and not session._jump and not session.tutorial.visible, "modal clears jump and hides tutorial")
	press(session, KEY_E, true)
	press(session, KEY_E)
	press(session, KEY_SPACE)
	check(signals_received.size() == 1 and not session._jump and not session.run.authority_unlocked, "echo repeated E and Space do not activate repair")
	press(session, KEY_ESCAPE)
	check(session.mode == "explore" and not session.world.paused and session.dialog == null, "Escape cancels and resumes")
	press(session, KEY_E)
	session.ui_buttons.continue.pressed.emit()
	check(session.mode == "explore" and not session.run.authority_unlocked, "return cancels without granting")
	press(session, KEY_E)
	session.ui_buttons.repair_device.pressed.emit()
	check(session.mode == "device_complete" and store.get_authority_loadout().size() == 3 and session.run.authority_unlocked, "repair grants exactly three cards and shows completion")
	var saved = store.data.duplicate(true)
	press(session, KEY_E)
	session._confirm_device_repair()
	check(store.data == saved and store.get_authority_loadout().size() == 3, "completion cannot repair or grant twice")
	press(session, KEY_ESCAPE)
	session.toggle_deck()
	session.choose_card("stop")
	press(session, KEY_E)
	check(session.mode == "device" and not session.deck_open and session.world.temporal.selected_card.is_empty(), "revisit closes deck and cancels selected authority")
	check(not session.ui_buttons.has("repair_device") and store.get_authority_loadout().size() == 3, "restored device has no duplicate repair action")
	press(session, KEY_ESCAPE)
	var reload_store = Store.new()
	check(reload_store.initialize_time_authority(path) and reload_store.data.authority_granted and reload_store.get_authority_loadout().size() == 3, "grant and save preserved after reload")
	for id in ["supply_lamp", "supply_tower", "rest", "final_dial", "bridge_before", "bridge_after", "testimony", "anchor_key"]:
		approach(session, session.world._interactions[id])
		var signal_count = signals_received.size()
		press(session, KEY_E)
		check(signals_received.size() == signal_count + 1 and signals_received.back() == id and is_instance_valid(session.dialog), id + " native E opens appropriate interface")
		press(session, KEY_ESCAPE)
	check(not session.buy_card("supply_lamp","fire"), "legacy fire shop remains disabled")
	session.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PROXIMITY_INTERACTION_SESSION_CHECKS=",checks," FAILURES=",failures.size())
	if failures.is_empty(): print("PROXIMITY_INTERACTION_SESSION_PASS")
	quit(0 if failures.is_empty() else 1)

