extends SceneTree
var world
var checks := 0
var failures: Array = []
func _initialize(): call_deferred("run_test")
func check(value: bool,label: String):
	checks += 1
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func snap(label: String):
	world.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/authority_motion_"+label+".png")
func ticks(count: int):
	for i in count:
		world.advance_simulation(1.0/60.0)
		if i%12==0: await physics_frame
func run_test():
	if DisplayServer.get_name()=="headless": quit(2); return
	world = load("res://scripts/exploration/exploration_world.gd").new()
	root.add_child(world)
	# Isolated visual fixture after acquisition; actual acquisition is covered by playthrough.
	world.configure({"ruleset":"time_authority_v2","authority_unlocked":true,"authority_tutorial_step":3,"position":[2480,1900],"completed":[],"interactions":[]})
	await physics_frame
	await ticks(20)
	var rig = world.player.continuous_motion
	var clock: float = rig.clock
	var enemy = world.previews.tutorial
	var before: Vector2 = enemy.position
	await ticks(30)
	check(enemy.position!=before and enemy.continuous_motion!=null,"nearby creature patrols with continuous rig")
	check(rig.clock>clock and world.player.animation=="idle","idle advances with straight ready source")
	await snap("01_ready_idle")
	world.set_movement_input(1,false)
	await ticks(28)
	check(absf(world.player.velocity.x-390)<1,"walk reaches configured speed")
	await snap("02_walk")
	world.set_movement_input(1,false,true)
	await ticks(22)
	check(absf(world.player.velocity.x-624)<1,"run reaches configured speed")
	await snap("03_run")
	var future: Vector2 = world.player.position
	var mesh_before = rig.mesh_view.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	var phase: float = rig.phase
	world.temporal.apply_card("reverse","player")
	await ticks(19)
	check(world.player.position.x < future.x,"player reverses actual prior travel")
	check(not is_equal_approx(rig.phase,phase),"reverse restores gait phase")
	check(rig.mesh_view.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]!=mesh_before,"reverse refreshes GPU mesh instead of only position")
	await snap("04_reversed_pose")
	world.temporal.reset_target("player")
	world.set_movement_input(0,false)
	await ticks(30)
	check(world.player.animation=="idle" and rig.movement_blend==0,"stopping returns to straight-leg ready stance")
	before = enemy.position
	world.temporal.apply_card("stop","enemy_tutorial")
	await ticks(30)
	check(enemy.position==before,"time card stops creature independently")
	world.temporal.apply_card("fast_forward","enemy_tutorial")
	await ticks(20)
	check(enemy.position!=before,"time card fast forwards creature independently")
	before = enemy.position
	world.temporal.apply_card("reverse","enemy_tutorial")
	await ticks(10)
	check(enemy.position!=before,"time card reverses creature history")
	world.temporal.reset_target("enemy_tutorial")
	var max_pulse := 0.0
	var min_pulse := 1.0
	for i in 240:
		world.advance_simulation(1.0/60.0)
		max_pulse = maxf(max_pulse,world.player.idle_authority_pulse)
		min_pulse = minf(min_pulse,world.player.idle_authority_pulse)
	check(max_pulse>0.9 and min_pulse<0.01,"idle authority response rises and subsides")
	await snap("05_ready_return")
	var phase_before: float = world.ambient.objects.cloud_1.phase
	var rig_before: float = rig.clock
	world.set_paused(true)
	await ticks(30)
	check(world.ambient.objects.cloud_1.phase==phase_before and rig.clock==rig_before,"pause freezes environment and rig together")
	world.set_paused(false)
	# Actual Godot-rendered continuous-motion video source, 30 fps.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/verification/motion_frames"))
	for frame in 180:
		world.set_movement_input(1.0 if frame>=60 and frame<135 else 0.0,false,frame>=95 and frame<135)
		world.advance_simulation(1.0/30.0)
		world.camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("res://docs/verification/motion_frames/frame_%03d.jpg"%frame,0.88)
	print("AUTHORITY_MOTION_GPU checks=",checks," failures=",failures.size()," frames=180 labels=",failures)
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
