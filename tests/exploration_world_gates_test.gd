extends SceneTree
const World = preload("res://scripts/exploration/exploration_world.gd")
var world
var encounters: Array = []
var interactions: Array = []
var checkpoints: Array = []
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run_test")
func step(axis: float, count: int, jump := false) -> void:
	world.set_movement_input(axis,jump)
	for _i in count:
		world.advance_simulation(1.0/60.0)
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("EXPLORATION_GATE_PASS "+label)
	else:
		failures += 1
		push_error("EXPLORATION_GATE_FAIL "+label+str(world.presentation_state()))
func run_test() -> void:
	world = World.new()
	root.add_child(world)
	world.configure({"position":[200,1900],"tutorial_step":0,"completed":[],"interactions":[]})
	world.encounter_requested.connect(func(id): encounters.append(id))
	world.interaction_requested.connect(func(id): interactions.append(id))
	world.checkpoint_requested.connect(func(_pos,region): checkpoints.append(region))
	await physics_frame
	await physics_frame
	step(0,20)
	step(1,265)
	check(world.presentation_state().nearest_interaction == "tutorial_lantern","lantern reached with real input")
	world.interact()
	check(interactions.has("tutorial_lantern"),"investigation signal")
	step(1,500)
	check(encounters.is_empty(),"no forced combat during four safe tutorial steps")
	check(world.get_player_position().x<3290,"physical story gate blocks unresolved run")
	world.run.tutorial_step = 4
	world.run.interactions = ["tutorial_lantern"]
	world.apply_run(world.run)
	step(-1,87)
	check(encounters.has("tutorial"),"encounter accessible after safe fork tutorial")
	world.set_encounter_active("tutorial",true)
	step(-1,250)
	var rect: Rect2 = world.get_encounter_spec("tutorial").rect
	check(world.get_player_position().x>=rect.position.x+27,"active combat left boundary")
	step(1,300)
	check(world.get_player_position().x<=rect.end.x-27,"active combat right boundary")
	check(absf(world.get_player_position().y-world.camera.position.y-100.0)<1.0,"combat feet at screen550 above card library")
	check(absf(world.camera.position.x-rect.get_center().x)<1.0,"combat camera includes arena enemies and anchors")
	world.finish_encounter("tutorial")
	step(1,80)
	check(world.get_player_position().x>3400,"finished encounter opens physical story gate")
	check(checkpoints.has(1),"region boundary checkpoint")
	world.leave_encounter("tutorial")
	check(world.presentation_state().active_encounter=="","leave clears combat boundary")
	var previous_position: Vector2 = world.get_player_position()
	world.set_time_slice("after")
	check(world.presentation_state().time_slice=="after" and world.get_player_position()==previous_position,"bridge visual slice preserves safe standing collision")
	world.queue_free()
	world = World.new()
	root.add_child(world)
	world.configure({"position":[2800,1900],"tutorial_step":3,"completed":[],"interactions":["tutorial_lantern"]})
	var fork_events: Array = []
	world.tutorial_event.connect(func(event,_data): fork_events.append(event))
	await physics_frame
	await physics_frame
	step(0,20)
	check(not fork_events.has("fork_completed"),"threshold alone cannot complete safe fork tutorial")
	step(-1,80)
	step(1,80)
	check(fork_events.has("fork_completed") and world.branch_visits.has("tutorial_lower"),"actual fork traversal completes tutorial")
	world.set_movement_input(0,false)
	world.set_chapter_night()
	world.advance_simulation(1.5)
	check(absf(world.night_mix-0.5)<0.01,"night uses supplied clock for smooth midpoint")
	world.set_paused(true)
	world.advance_simulation(1.0)
	check(absf(world.night_mix-0.5)<0.01,"night transition freezes on pause")
	world.set_paused(false)
	world.advance_simulation(1.5)
	check(is_equal_approx(world.night_mix,1.0),"night completes supplied three seconds")
	var restored = World.new()
	root.add_child(restored)
	restored.configure({"position":[2800,1900],"tutorial_step":4,"completed":[],"interactions":[],"chapter_night":true})
	check(restored.chapter_night and is_equal_approx(restored.night_mix,1.0),"saved chapter_night restores immediately")
	check(not world.run.get("lamp_lit",false),"unlit lamp remains unlit during night transition")
	restored.apply_run({"lamp_lit":true})
	check(restored.run.get("lamp_lit",false),"saved lamp state is applied to world rendering source")
	print("EXPLORATION_GATES checks=",checks," failures=",failures)
	restored.queue_free()
	quit(1 if failures>0 else 0)



