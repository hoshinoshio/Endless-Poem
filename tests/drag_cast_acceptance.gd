extends SceneTree
const Session = preload("res://scripts/exploration/exploration_session.gd")
const Store = preload("res://scripts/progression/collection_store.gd")
const Temporal = preload("res://scripts/authority/temporal_controller.gd")
var checks := 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)
func _initialize() -> void: call_deferred("run_test")
func run_test() -> void:
	var path := "user://drag_cast_%d.json" % Time.get_ticks_usec()
	var store := Store.new()
	store.initialize_time_authority(path)
	var fixture := {"active":true,"ruleset":"time_authority_v2","authority_unlocked":true,"authority_tutorial_step":3,"position":[2000,1300],"region":0,"hp":50,"completed":[],"interactions":[]}
	store.unlock_time_authority(fixture,fixture)
	var session := Session.new()
	root.add_child(session)
	session.configure(store,false)
	session.set_physics_process(false)
	await physics_frame
	var world = session.world
	world.set_movement_input(1,false)
	world.player.velocity = Vector2(390,0)
	var hero: Dictionary = world._capture_player()
	var enemy: Dictionary = world._capture_enemy("tutorial")
	var phase: float = world.ambient.objects.cloud_0.phase
	world.advance_simulation(0.1)
	var full := Vector3(world.player.position.x - hero.position.x, world.previews.tutorial.position.x - enemy.position.x, world.ambient.objects.cloud_0.phase - phase)
	world._restore_player(hero)
	world._restore_enemy("tutorial",enemy)
	world.ambient.objects.cloud_0.phase = phase
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = session.hand.faces.stop.get_global_rect().get_center()
	session.hand._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position + Vector2(7,0)
	session.hand._input(motion)
	check(session.drag_card == "stop" and world.world_time_scale == 0.05, "mouse threshold begins drag at 0.05x")
	world.advance_simulation(0.1)
	var slow := Vector3(world.player.position.x - hero.position.x, world.previews.tutorial.position.x - enemy.position.x, world.ambient.objects.cloud_0.phase - phase)
	check((slow - full * 0.05).length() < 0.02 and absf(full.y) > 0.0, "player, enemy and environment all advance proportionally")
	var point: Vector2 = world.temporal.get_presentation().targets.enemy_tutorial.screen_rect.get_center()
	check(session.release_drag(point) and world.temporal.get_target_mode("enemy_tutorial") == "stop" and world.temporal.cooldowns.stop > 0 and world.world_time_scale == 1.0 and world.player.action_animation == "cast", "valid release casts, cools down and restores time")
	check(not session.begin_drag("stop"), "cooling card rejects drag")
	session.begin_drag("fast_forward")
	check(not session.release_drag(Vector2(-100,-100)) and world.temporal.cooldowns.fast_forward == 0 and world.world_time_scale == 1.0, "miss cancels without cooldown")
	session.begin_drag("fast_forward")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	session.hand._input(right)
	check(session.drag_card.is_empty() and world.world_time_scale == 1.0 and world.temporal.cooldowns.fast_forward == 0, "right click cancels")
	session.begin_drag("fast_forward")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	session._unhandled_input(escape)
	check(session.drag_card.is_empty() and session.mode == "explore" and world.world_time_scale == 1.0 and world.temporal.cooldowns.fast_forward == 0, "Escape cancels before pausing")
	session.begin_drag("fast_forward")
	session.show_pause()
	check(session.drag_card.is_empty() and world.paused and world.world_time_scale == 1.0 and world.temporal.cooldowns.fast_forward == 0, "pause forcibly cancels")
	session._resume_dialog()
	var cooldown: float = world.temporal.cooldowns.stop
	session.begin_drag("fast_forward")
	world.advance_simulation(1.0)
	check(is_equal_approx(cooldown - world.temporal.cooldowns.stop, 0.05), "cooldown uses slowed world seconds")
	session.cancel_drag()
	world.advance_simulation(2.0)
	check(world.temporal.get_target_mode("enemy_tutorial") == "normal", "stop automatically expires after two world seconds")
	var priorities := Temporal.new()
	for category in ["scene","item","npc","monster","hero"]:
		priorities.register_target(category,category,func(): return Rect2(0,0,20,20),func(): return {},func(_s): pass,func(_d): pass,category)
	var order := []
	for i in 5:
		var picked: String = priorities.target_at_point(Vector2(10,10))
		order.append(picked)
		priorities.unregister_target(picked)
	check(order == ["hero","monster","npc","item","scene"], "all five overlapping categories respect priority")
	world.set_player_position(Vector2(200,1900))
	world.set_movement_input(1,false)
	world.temporal.reset_target_history("player")
	var past := Vector2.ZERO
	for i in 240:
		world.advance_simulation(1.0/60)
		if i == 59: past = world.player.position
	session.run.hp = 37
	world.temporal.apply_card("reverse","player")
	check(world.player.position.distance_to(past) < 16 and session.run.hp == 37, "instant rewind returns hero about three seconds without healing")
	session.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("DRAG_CAST_CHECKS=",checks," FAILURES=",failures.size())
	quit(0 if failures.is_empty() else 1)
