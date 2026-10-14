extends SceneTree
var failures: Array = []
var checks := 0
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	call_deferred("test_world")
func test_world() -> void:
	var below = load("res://scripts/exploration/exploration_world.gd").new()
	root.add_child(below)
	below.configure({"ruleset":"time_authority_v2","position":[200,1900],"authority_unlocked":false,"authority_tutorial_step":2})
	await physics_frame
	var below_events := []
	var below_repairs := []
	below.tutorial_event.connect(func(event,_data): below_events.append(event))
	below.interaction_requested.connect(func(id): below_repairs.append(id))
	for i in 270:
		below.set_movement_input(1.0,i == 80)
		below.advance_simulation(1.0/60.0)
		await physics_frame
	check(not "jump_landed" in below_events,"jump landing below terrace does not finish tutorial")
	check(below.player.position.y>1800,"negative route remains below terrace")
	below.nearest_interaction = "stalled_device"
	below.interact()
	check(below_repairs.is_empty(),"E repair rejected from below even with saved step 2")
	below.queue_free()
	var world = load("res://scripts/exploration/exploration_world.gd").new()
	root.add_child(world)
	world.configure({"ruleset":"time_authority_v2","position":[200,1900],"authority_unlocked":false,"authority_tutorial_step":0})
	await physics_frame
	var tutorial_events := []
	world.tutorial_event.connect(func(event,_data): tutorial_events.append(event))
	for i in 255:
		world.set_movement_input(1.0,i == 185,i>=185 and i<225)
		if i in [185,190,200,210,220,230,240,250]: print("ROUTE_FRAME ",i," ",world.player.position," grounded=",world.player.grounded)
		world.advance_simulation(1.0/60.0)
		await physics_frame
	print("REPAIR_ROUTE position=",world.player.position," grounded=",world.player.grounded," tutorial=",tutorial_events)
	check("walked" in tutorial_events,"actual walking emits walked")
	check("jump_landed" in tutorial_events,"actual jumping lands on authored terrain")
	check(world.player.position.x>1700 and world.player.position.x<2050,"walk and jump reach repair area")
	world.set_movement_input(0,false)
	for i in 20:
		world.advance_simulation(1.0/60.0)
		await physics_frame
	var repair_events := []
	world.interaction_requested.connect(func(id): repair_events.append(id))
	world.interact()
	check(repair_events.is_empty(),"repair blocked before movement tutorial complete")
	world.apply_run({"ruleset":"time_authority_v2","authority_unlocked":false,"authority_tutorial_step":2})
	world.interact()
	check("stalled_device" in repair_events,"actual walk and jump reach E repair")
	check(not world.temporal.is_unlocked,"new game starts locked")
	check(not world.temporal.select_card("stop"),"locked cards rejected")
	check(world.temporal.get_presentation().targets.has("player"),"player target registered")
	check(world.temporal.get_presentation().targets.has("enemy_tutorial"),"enemy target registered")
	check(world.temporal.get_presentation().targets.has("cloud_0"),"cloud target registered")
	check(world.temporal.get_presentation().targets.has("lamp_bridge"),"lamp target registered")
	check(world.temporal.get_presentation().targets.has("stalled_device"),"device target registered")
	var phase: float = world.ambient.objects.cloud_0.phase
	world.advance_simulation(0.1)
	check(world.ambient.objects.cloud_0.phase>phase,"clouds move before unlock")
	check(world.ambient.objects.stalled_device.phase == 0.0,"unrepaired device stationary")
	world.apply_run({"ruleset":"time_authority_v2","authority_unlocked":true,"authority_tutorial_step":3})
	check(world.temporal.is_unlocked,"run unlock reaches controller")
	check(world.temporal.apply_card("stop","cloud_0"),"cloud stop accepted")
	phase = world.ambient.objects.cloud_0.phase
	world.advance_simulation(0.1)
	check(world.ambient.objects.cloud_0.phase == phase,"cloud stop freezes phase")
	world.temporal.reset_target("cloud_0")
	world.advance_simulation(0.1)
	phase = world.ambient.objects.cloud_0.phase
	world.temporal.apply_card("reverse","cloud_0")
	world.advance_simulation(0.1)
	check(world.ambient.objects.cloud_0.phase<phase,"cloud reverses captured history")
	world.temporal.reset_target("cloud_0")
	world.set_paused(true)
	phase = world.ambient.objects.cloud_0.phase
	world.advance_simulation(0.1)
	check(world.ambient.objects.cloud_0.phase == phase,"global pause freezes local objects")
	world.set_paused(false)
	world.set_player_position(Vector2(1900,1690))
	world.set_movement_input(0,false)
	var max_pulse := 0.0
	for i in 360:
		world.advance_simulation(1.0/60.0)
		max_pulse = maxf(max_pulse,world.player.idle_authority_pulse)
	check(max_pulse>0.1,"unlocked idle hand gesture produces pulse")
	var point: Vector2 = world.temporal.get_presentation().targets.player.screen_rect.get_center()
	check(world.temporal.target_at_point(point) == "player","canvas transformed player picking")
	world.apply_run({"ruleset":"time_authority_v2","authority_unlocked":false})
	check(not world.temporal.is_unlocked,"relock removes powers")
	check(world.temporal.get_presentation().targets.cloud_0.mode == "normal","relock resets modes")
	print("AUTHORITY_WORLD_ACCEPTANCE checks=",checks," failures=",failures.size()," ",failures)
	world.queue_free()
	quit(0 if failures.is_empty() else 1)

