extends SceneTree
const World = preload("res://scripts/exploration/exploration_world.gd")
var world
func _initialize() -> void:
	call_deferred("render_preview")
func render_preview() -> void:
	root.size = Vector2i(1440,900)
	world = World.new()
	root.add_child(world)
	world.configure({"position":[200,1900],"tutorial_step":4,"completed":["tutorial","stairs"],"interactions":["tutorial_lantern","bridge_before","bridge_after"]})
	await physics_frame
	await physics_frame
	for i in 120:
		world.set_movement_input(1,false)
		world.advance_simulation(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/exploration_world_slope.png")
	print("EXPLORATION_RENDER "+str(world.presentation_state()))
	world.set_movement_input(1,true)
	var captured_land := false
	for i in 100:
		world.advance_simulation(1.0/60.0)
		await process_frame
		if world.player.side_frame == 7 and not captured_land:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/verification/exploration_world_land.png")
			captured_land = true
			print("EXPLORATION_LAND_RENDER frame=7 position="+str(world.get_player_position()))
		if i in [2,20,50,74]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/verification/exploration_world_jump_"+str(i)+".png")
			print("EXPLORATION_JUMP_RENDER frame="+str(world.player.side_frame)+" position="+str(world.get_player_position()))
	# Continuous input travel to the first arena and both historical bridge slices.
	world.set_movement_input(1,false)
	while world.get_player_position().x<2710:
		world.advance_simulation(1.0/60.0)
	world.set_movement_input(0,false)
	world.set_encounter_active("tutorial",true)
	world.advance_simulation(1.0/60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/exploration_world_combat_camera.png")
	print("EXPLORATION_COMBAT_CAMERA "+str(world.presentation_state()))
	world.leave_encounter("tutorial")
	world.set_movement_input(1,false)
	while world.get_player_position().x<7000:
		world.advance_simulation(1.0/60.0)
	world.set_movement_input(0,false)
	world.set_time_slice("before")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/exploration_world_bridge_before.png")
	world.set_time_slice("after")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/exploration_world_bridge_after.png")
	world.set_movement_input(1,false)
	while world.get_player_position().x<8730:
		world.advance_simulation(1.0/60.0)
	world.set_movement_input(1,true)
	for i in 200:
		world.advance_simulation(1.0/60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/exploration_world_upper_fork.png")
	print("EXPLORATION_UPPER_RENDER "+str(world.presentation_state()))
	world.set_movement_input(1,false)
	while world.get_player_position().x<13130:
		world.advance_simulation(1.0/60.0)
	world.set_movement_input(0,false)
	world.advance_simulation(1.0/60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/exploration_world_testimony_npc.png")
	print("EXPLORATION_NPC_RENDER "+str(world.presentation_state()))
	world.set_chapter_night()
	for i in 181:
		world.advance_simulation(1.0/60.0)
		if i in [89,180]:
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://docs/verification/exploration_world_night_transition.png" if i==89 else "res://docs/verification/exploration_world_chapter_night.png"
			root.get_texture().get_image().save_png(path)
			print("EXPLORATION_NIGHT_RENDER night_mix="+str(world.night_mix)+" position="+str(world.get_player_position()))
	quit(0)






