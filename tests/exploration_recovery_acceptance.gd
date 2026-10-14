extends SceneTree
const Store = preload("res://scripts/progression/collection_store.gd")
var checks = 0
var failures = []
var path = ""
func _initialize(): call_deferred("run_test")
func check(value, label):
	checks += 1
	print("PASS " if value else "FAIL ", label)
	if not value: failures.append(label)
func step(s, count = 1):
	for i in count: s._physics_process(1.0 / 60)
func walk(s, target, jump = false):
	Input.action_press("explore_right")
	if jump:
		var e = InputEventKey.new()
		e.keycode = KEY_SPACE
		e.physical_keycode = KEY_SPACE
		e.pressed = true
		s._unhandled_input(e)
	for i in 12000:
		if s.mode != "explore" or s.world.player.position.x >= target: break
		step(s)
	Input.action_release("explore_right")
	step(s)
func game_new():
	var g = load("res://scenes/main.tscn").instantiate()
	g.save_path = path
	root.add_child(g)
	return g
func run_test():
	path = "user://exploration_recovery_%d.json" % Time.get_ticks_usec()
	var g = game_new()
	await process_frame
	var starter = g.store.collection
	check(starter.size() == 10, "isolated initial ten entities")
	g.start_menu.buttons.new.pressed.emit()
	var s = g.exploration_session
	s.set_physics_process(false)
	s.opening.set_process(false)
	s.opening.advance(30)
	s.opening.advance(0.5)
	g.store.save_path = "user://exploration_recovery_absent_%d/save.json" % Time.get_ticks_usec()
	s.opening.buttons.yes.pressed.emit()
	check(s.world == null and s.mode == "opening", "failed opening does not enter unsaved world")
	check(is_instance_valid(s.boot_error) and s.boot_error.visible and s.ui_buttons.has("retry_opening") and s.ui_buttons.retry_opening.visible and not s.ui_buttons.retry_opening.disabled, "failed opening has visible enabled save retry")
	check(not s.last_error.is_empty() and is_instance_valid(s.save_notice), "failed opening exposes write error")
	check(g.store.collection == starter and not g.store.data.get("intro_accepted", false), "failed opening leaves starter and acceptance unchanged")
	g.store.save_path = path
	s.ui_buttons.retry_opening.pressed.emit()
	await process_frame
	check(s.mode == "explore" and s.run.tutorial_step == 0 and s.boot_error == null, "visible retry successfully enters saved tutorial")
	check(g.store.collection == starter and g.store.data.visits == 1, "retry adds no starter entities or duplicate visit")
	walk(s, 850)
	check(s.run.tutorial_step == 1, "real horizontal input reaches tutorial step one")
	s.leave_to_menu()
	g.queue_free()
	await process_frame
	g = game_new()
	await process_frame
	g.start_menu.buttons["continue"].pressed.emit()
	s = g.exploration_session
	s.set_physics_process(false)
	check(s.run.tutorial_step == 1 and s.tutorial.presentation_state().step == 1, "recreated game continues saved step one")
	walk(s, 1860, true)
	step(s, 100)
	check(s.run.tutorial_step == 2, "real jump landing after restart advances step two")
	s.leave_to_menu()
	g.queue_free()
	await process_frame
	g = game_new()
	await process_frame
	g.start_menu.buttons["continue"].pressed.emit()
	s = g.exploration_session
	s.set_physics_process(false)
	check(s.run.tutorial_step == 2 and s.tutorial.presentation_state().step == 2, "recreated game continues saved step two")
	step(s, 2) # Rebuild proximity from the restored physical position before E.
	var e = InputEventKey.new()
	e.keycode = KEY_E
	e.physical_keycode = KEY_E
	e.pressed = true
	s._unhandled_input(e)
	check(s.mode == "dialog" and s.run.tutorial_step == 3, "actual lantern input after restart advances investigation")
	if s.ui_buttons.has("continue"): s.ui_buttons["continue"].pressed.emit()
	walk(s, 2760)
	check(s.run.tutorial_step == 4 and s.mode == "loadout" and s.encounter == "tutorial", "real route opens first encounter normally")
	var checkpoint = s.checkpoint.duplicate(true)
	var coins = s.run.coins
	check(s.confirm_loadout(), "actual loadout opens first battle")
	# Approach via movement input only; no HP mutation, teleport, or card use.
	Input.action_press("explore_right")
	for i in 1800:
		if s.mode != "battle": break
		var enemy = s.spatial.entities.values()[0]
		if absf(s.world.player.position.x - enemy.position.x) <= 100: break
		step(s)
	Input.action_release("explore_right")
	print("REAL_DEFEAT_APPROACH player=", s.world.player.position, " enemy=", s.spatial.entities.values()[0].position)
	for i in 36000:
		if s.mode != "battle": break
		step(s)
	print("REAL_DEFEAT status=", s.combat.status, " hp=", s.combat.hp, " elapsed=", s.combat.time, " hits=", s.spatial.resolved_hits, " misses=", s.spatial.missed_attacks)
	check(s.mode == "defeat" and s.combat.status == "lost" and s.combat.hp == 0 and s.spatial.resolved_hits > 0, "real enemy collision damage defeats idle player")
	if s.mode == "defeat": s.ui_buttons.retry.pressed.emit()
	check(s.mode == "explore" and s.run.hp == checkpoint.hp and not s.run.in_battle, "defeat retry restores prebattle HP and exploration")
	check(s.world.player.position.distance_to(Vector2(checkpoint.position[0], checkpoint.position[1])) < 1, "defeat retry restores actual safe checkpoint position")
	check(g.store.collection == starter and s.run.coins == coins, "real defeat and retry duplicate neither starters nor coins")
	# Explicit transaction fixture: persistence and idempotency, not a combat victory claim.
	var fixture = s.run.duplicate(true)
	fixture.pending_reward = "stairs"
	fixture.completed.append("stairs")
	check(s._commit(fixture), "FIXTURE pending reward persisted before restart")
	g.queue_free()
	await process_frame
	g = game_new()
	await process_frame
	g.start_menu.buttons["continue"].pressed.emit()
	s = g.exploration_session
	s.set_physics_process(false)
	check(s.mode == "reward" and s.run.pending_reward == "stairs", "FIXTURE restart reopens pending reward")
	check(s.claim_reward("heavy_shield"), "FIXTURE pending reward claim succeeds")
	check(not s.claim_reward("heavy_shield") and g.store.collection.size() == 11 and s.run.coins == coins, "FIXTURE repeated claim cannot duplicate card or coins")
	var verifier = Store.new()
	check(verifier.initialize(path) and verifier.collection.size() == 11 and verifier.claimed_rewards.count("initial:starter_v1") == 1 and verifier.claimed_rewards.count("chapter1:battle:stairs") == 1, "disk reload confirms starter and reward exactly once")
	g.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("EXPLORATION_RECOVERY_ACCEPTANCE checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
