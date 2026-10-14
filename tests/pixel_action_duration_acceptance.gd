extends SceneTree
const World = preload("res://scripts/exploration/exploration_world.gd")
var checks := 0
var failures := 0
func check(value: bool,label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.configure({"ruleset":"time_authority_v2","position":[200,1900],"authority_unlocked":true,"authority_tutorial_step":3})
	world.set_paused(true)
	var player = world.player
	var hero = player.continuous_motion
	for i in 20: player.advance(1.0/120)
	check(player.grounded,"actual player stands on world floor")
	player.set_input(1,false,false)
	world.play_player_action("cast")
	check(is_equal_approx(player.action_remaining,.5),"cast uses full eight frame half second duration")
	var initial_x: float = player.position.x
	for i in 54: player.advance(1.0/120)
	check(hero.state=="cast" and hero.frame_index==7 and player.action_remaining>0,"moving cast reaches final frame after legacy cutoff")
	check(player.position.x>initial_x+100,"movement remains responsive during cast")
	for i in 8: player.advance(1.0/120)
	check(player.action_remaining<=0 and hero.state in ["walk","run"],"cast returns to locomotion after full authored duration")
	world.play_player_action("cast")
	player.set_input(1,true,false)
	player.advance(1.0/120)
	check(not player.grounded and player.velocity.y<0 and hero.state=="cast","jump physics remain responsive during cast")
	for i in 53: player.advance(1.0/120)
	check(hero.state=="cast" and hero.frame_index==7,"airborne cast also reaches final frame")
	for i in 8: player.advance(1.0/120)
	check(hero.state in ["jump","fall"],"airborne cast restores airborne presentation")
	world.play_player_action("hurt")
	check(is_equal_approx(player.action_remaining,4.0/12.0),"hurt uses authored third second duration")
	for i in 35: player.advance(1.0/120)
	check(hero.state=="hurt" and hero.frame_index==3,"hurt reaches final authored frame")
	for i in 8: player.advance(1.0/120)
	check(player.action_remaining<=0 and hero.state!="hurt","hurt returns at natural strip duration")
	world.play_player_action("recover")
	check(is_equal_approx(player.action_remaining,2.0/12.0),"recover uses authored duration")
	for i in 15: player.advance(1.0/120)
	check(hero.state=="recover" and hero.frame_index==1,"recover reaches final authored frame")
	for i in 8: player.advance(1.0/120)
	check(player.action_remaining<=0 and hero.state!="recover","recover returns after authored duration")
	world.free()
	print("PIXEL_ACTION_DURATION_ACCEPTANCE ",checks," checks failures=",failures)
	quit(failures)
