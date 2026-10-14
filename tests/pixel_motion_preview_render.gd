extends SceneTree
var preview
var world
var checks := 0
var failures: Array = []
var output := "res://docs/verification/pixel_motion_frames"
func _initialize() -> void: call_deferred("run_test")
func check(value: bool,label: String) -> void:
	checks += 1
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func tick(axis: float,jump := false,running := false) -> void:
	world.set_movement_input(axis,jump,running)
	world.advance_simulation(1.0/60.0)
func snap(label: String) -> void:
	world.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")
func run_test() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	# Never overwrite evidence from an earlier run.
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):
		output += "_"+str(Time.get_unix_time_from_system()).replace(".","_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preview = load("res://scenes/previews/pixel_motion_preview.tscn").instantiate()
	root.add_child(preview)
	preview.set_physics_process(false)
	await physics_frame
	if not preview.ready_for_preview: quit(1); return
	world = preview.world
	var rig = world.player.continuous_motion
	for i in 90: tick(0)
	check(world.player.grounded and world.player.animation=="idle","real collision settles idle")
	check(not rig.authority_unlocked and not world.temporal.is_unlocked,"new-game authority stays locked")
	await snap("01_idle")
	var start: Vector2 = world.player.position
	for i in 45: tick(1)
	check(world.player.position.x>start.x and absf(world.player.velocity.x-390)<1,"actual walk physics reaches 390")
	await snap("02_walk")
	var phase: float = rig.phase
	tick(1,false,true)
	var phase_delta: float = fposmod(rig.phase-phase,1.0)
	check(phase_delta>0 and phase_delta<0.2,"Shift preserves shared gait phase")
	for i in 25: tick(1,false,true)
	check(absf(world.player.velocity.x-624)<1,"actual run physics reaches 624")
	await snap("03_run")
	for i in 35: tick(0)
	check(world.player.animation=="idle" and world.player.velocity.x==0,"stop decelerates into idle")
	await snap("04_stop")
	var landings: int = world.player.landed_count
	tick(0,true)
	check(world.player.velocity.y<0 and not world.player.grounded,"jump uses real launch impulse")
	for i in 20: tick(0)
	await snap("05_jump")
	for i in 100: tick(0)
	check(world.player.grounded and world.player.landed_count>landings,"jump returns through collision landing")
	await snap("06_landing")
	for i in 15: tick(-1)
	check(world.player.facing<0 and rig.facing<0,"turn follows left movement")
	await snap("07_turn")
	world.set_paused(true)
	world.camera.enabled = true
	var clock: float = rig.clock
	var pos: Vector2 = world.player.position
	for i in 30: tick(1)
	check(rig.clock==clock and world.player.position==pos,"pause freezes actor and simulation")
	await snap("08_pause")
	world.set_paused(false)
	# Twelve seconds at 30 fps; all motion below comes from real input/physics.
	for frame in 360:
		var axis := 0.0
		if frame>=45 and frame<180: axis = 1.0
		if frame>=240 and frame<300: axis = -1.0
		var running := frame>=105 and frame<180
		if frame==315: world.set_paused(true); world.camera.enabled = true
		if frame==345: world.set_paused(false)
		world.set_movement_input(axis,frame==210,running)
		world.advance_simulation(1.0/30.0)
		world.camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/frame_%03d.jpg"%frame,0.91)
	print("PIXEL_PREVIEW checks=",checks," failures=",failures," frames=360 output=",output)
	quit(0 if failures.is_empty() else 1)
