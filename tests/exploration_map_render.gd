extends SceneTree
## Layout-only fixtures. Traversability is verified separately by the physical journey.
const World=preload("res://scripts/exploration/exploration_world.gd")
var world
var checks=0
var failures=[]
func _initialize(): call_deferred("run_test")
func check(value,label):
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func capture(name):
	world.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame=root.get_texture().get_image()
	check(frame!=null and not frame.is_empty(),"GPU map fixture "+name)
	frame.save_png("res://docs/verification/map_current_"+name+".png")
func at(point):
	world.set_player_position(point)
	world.set_movement_input(0,false)
	for i in 30: world.advance_simulation(1.0/60)
func run_test():
	if DisplayServer.get_name()=="headless": quit(2);return
	var state={"position":[200,1900],"region":0,"tutorial_step":4,"completed":["tutorial","stairs","patrol","lamp","elite","corridor","boss"],"interactions":["tutorial_lantern","bridge_before","bridge_after","testimony","anchor_key"],"lamp_lit":false}
	world=World.new()
	root.add_child(world)
	world.configure(state)
	await physics_frame
	at(Vector2(3650,1800))
	await capture("stairs")
	at(Vector2(7100,2100))
	await capture("bridge_service")
	at(Vector2(10620,2100))
	await capture("three_lanes_unlit")
	state.lamp_lit=true
	world.apply_run(state)
	await capture("three_lanes_lit")
	at(Vector2(13130,1900))
	await capture("observer_ring")
	at(Vector2(18850,1900))
	await capture("tower_gallery")
	check(world.presentation_state().missing_resources.is_empty(),"all map resources load")
	print("EXPLORATION_MAP_RENDER checks=",checks," failures=",failures.size()," fixture_positions=true")
	quit(0 if failures.is_empty() else 1)
