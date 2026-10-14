extends SceneTree
const Store = preload("res://scripts/progression/collection_store.gd")
const Session = preload("res://scripts/exploration/exploration_session.gd")
class FailingStore extends "res://scripts/progression/collection_store.gd":
	var deny_unlock = false
	func unlock_time_authority(run: Dictionary, checkpoint: Dictionary) -> bool:
		if deny_unlock:
			last_error = "simulated write failure"
			return false
		return super.unlock_time_authority(run,checkpoint)
var failures: Array = []
var checks = 0
func _initialize() -> void: call_deferred("run_test")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL ",label)
func make_session(store, fresh: bool):
	var session = Session.new()
	root.add_child(session)
	session.configure(store,fresh)
	session.set_physics_process(false)
	return session
func run_test() -> void:
	var path = "user://authority_session_%d.json" % Time.get_ticks_usec()
	var store = FailingStore.new()
	check(store.initialize_time_authority(path),"new authority save initializes")
	var session = make_session(store,true)
	check(session.mode == "opening","new player sees opening")
	session._accept_opening()
	check(session.run.ruleset == "time_authority_v2","new run marks ruleset")
	check(not session.run.authority_unlocked and not session.authority_button.visible and session.card_buttons.is_empty(),"no ability, clock or cards before repair")
	check(session.spatial == null,"new rules do not construct old combat adapter")
	session.request_encounter("tutorial")
	session.show_loadout()
	check(session.mode == "explore" and not session.confirm_loadout(),"encounters and loadout cannot enter legacy combat")
	check(not session.buy_card("supply_lamp","fire") and not session.claim_reward("fire"),"old reward and shop mutations disabled")
	check(not session._repair_device(),"repair requires completed approach and jump stages")
	session._tutorial_event("walked",{})
	session._tutorial_event("jump_landed",{})
	check(session.run.authority_tutorial_step == 2,"real world tutorial events persist stages")
	var mid_store = Store.new()
	check(mid_store.initialize_time_authority(path),"incomplete tutorial reloads")
	var mid_session = make_session(mid_store,false)
	check(mid_session.run.authority_tutorial_step == 2 and not mid_session.run.authority_unlocked and not mid_session.authority_button.visible,"resume incomplete tutorial without granting powers")
	mid_session.queue_free()
	await process_frame
	store.deny_unlock = true
	check(not session._repair_device() and not session.run.authority_unlocked and not session.authority_button.visible and not session.world.temporal.is_unlocked,"failed atomic save leaves world and UI locked")
	store.deny_unlock = false
	check(session._repair_device(),"repair atomically grants authority")
	check(store.data.authority_granted and session.run.authority_unlocked and session.world.temporal.is_unlocked,"saved grant applies to world")
	check(session.authority_button.visible and session.card_buttons.size() == 3,"exact three time cards exposed after repair")
	check(session.card_buttons.has("stop") and session.card_buttons.has("fast_forward") and session.card_buttons.has("reverse"),"time card types map to catalog")
	check(not session._repair_device() and store.get_authority_loadout().size() == 3,"repair is one time")
	session.toggle_deck()
	session.choose_card("stop")
	check(session.world.temporal.selected_card == "stop","clock grid card selects temporal controller")
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	session._unhandled_input(escape)
	check(session.deck_open and session.world.temporal.selected_card.is_empty(),"first Escape cancels selected card")
	session._unhandled_input(escape)
	check(not session.deck_open and session.mode == "explore","second Escape closes grid")
	session._unhandled_input(escape)
	check(session.mode == "pause","third Escape pauses")
	session._resume_dialog()
	var saved_position = session.run.position.duplicate()
	session.queue_free()
	await process_frame
	var resumed_store = Store.new()
	check(resumed_store.initialize_time_authority(path),"saved authority reloads")
	var resumed = make_session(resumed_store,false)
	check(resumed.run.authority_tutorial_step == 3 and resumed.run.position == saved_position and resumed.authority_button.visible,"resume retains stage, position and authority")
	resumed.queue_free()
	await process_frame
	var fresh = make_session(resumed_store,true)
	check(fresh.run.authority_unlocked and fresh.run.authority_tutorial_step == 3 and fresh.card_buttons.size() == 3,"later new exploration inherits granted authority")
	fresh.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("AUTHORITY_SESSION_CHECKS=",checks," FAILURES=",failures.size())
	quit(0 if failures.is_empty() else 1)
