extends SceneTree
const Model=preload("res://scripts/combat/combat_model.gd")
const Runtime=preload("res://scripts/exploration/spatial_combat.gd")
const World=preload("res://scripts/exploration/exploration_world.gd")
var failures: Array=[]
var checks:=0
func _initialize(): call_deferred("run")
func check(value,label):
	checks+=1
	if not value:
		failures.append(label)
		printerr("FAIL ",label)
func run():
	var world=World.new()
	root.add_child(world)
	world.configure({"position":[2550,1900],"tutorial_step":4,"completed":[],"interactions":[]})
	var player=world.player
	var camera=world.camera
	await physics_frame
	var model=Model.new()
	var runtime=Runtime.new()
	root.add_child(runtime)
	runtime.configure(model,world)
	check(runtime.start("tutorial"),"real world start")
	check(world.player==player and world.camera==camera,"same player and camera")
	var target=model.enemies[0].id
	check(runtime.get_target_rect(target).size.x>0,"screen picking ready at start")
	var fire=model.cards[0]
	model.select_card(fire.id)
	model.play_selected(target)
	runtime.advance(0.7)
	check(model.enemies[0].hp==12,"world-space travel before impact")
	runtime.advance(0.4)
	check(model.enemies[0].hp==6,"real world-space arrival")
	model.select_card(model.cards[1].id)
	var before=world.get_player_position()
	world.set_movement_input(1,false)
	runtime.advance(0.5)
	check(world.get_player_position().x>before.x,"real character movement during combat")
	check(abs(world.get_player_position().x-before.x)<100,"real character slows")
	model.cancel_selection()
	runtime.set_paused(true)
	before=world.get_player_position()
	var clock=model.time
	runtime.advance(1)
	check(world.get_player_position()==before and clock==model.time,"real world freezes paused")
	runtime.set_paused(false)
	world.set_movement_input(0,false)
	model.select_card(model.cards[1].id)
	model.play_selected(target)
	runtime.advance(1.5)
	check(model.status=="won","actual world tutorial complete")
	runtime.finish()
	check(world.active_encounter=="" and runtime.entities.is_empty(),"world boundary and enemies cleanup")
	print("SPATIAL_COMBAT_WORLD_ACCEPTANCE checks=",checks," failures=",failures.size())
	world.queue_free()
	runtime.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
