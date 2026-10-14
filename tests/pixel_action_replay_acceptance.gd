extends SceneTree
const World = preload("res://scripts/exploration/exploration_world.gd")
const Runtime = preload("res://scripts/exploration/spatial_combat.gd")
const Model = preload("res://scripts/combat/combat_model.gd")
class LegacyWorld extends Node2D:
	func get_player_position(): return Vector2(100,600)
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
	var hero = world.player.continuous_motion
	for action in ["cast","attack","hurt"]:
		world.play_player_action(action)
		hero.advance(.2)
		check(hero.frame_index>0,action+" advances before replay")
		world.play_player_action(action)
		check(hero.state_time==0 and hero.frame_index==0 and hero.sampled_animation==action,action+" replay immediately restarts frame zero")
		hero.advance(.01)
		world.play_player_action(action)
		check(hero.state_time==0 and hero.frame_index==0,action+" rapid reapplication restarts frame zero")
	var model := Model.new()
	var runtime := Runtime.new()
	root.add_child(runtime)
	runtime.configure(model,world)
	check(runtime.start("tutorial"),"real spatial encounter starts")
	world.set_paused(true)
	var target: String = model.enemies[0].id
	var hp: int = model.hp
	var energy: int = model.energy
	var time: float = model.time
	runtime._spawn_attack({"kind":"fire","target":target,"action_id":"visual_origin_probe"})
	var source: Dictionary = world.player.casting_presentation()
	var used: Rect2i = hero.sprite.texture.get_image().get_used_rect()
	var top: float = world.player.global_position.y+(hero.sprite.position.y+used.position.y)*hero.display_scale
	var bottom: float = world.player.global_position.y+(hero.sprite.position.y+used.end.y)*hero.display_scale
	check(is_equal_approx(source.height,bottom-top) and source.origin.y>top and source.origin.y<bottom,"casting origin sits inside actual visible cast frame height")
	check(source.height<180 and source.origin.y>world.get_player_position().y-180,"compact hero source follows raster dimensions instead of legacy height")
	check(runtime.attacks[0].origin==source.origin and runtime.authority_fx.source==source.origin.round(),"fire and authority FX share current presentation origin")
	check(runtime.attacks[0].travel==.48 and model.hp==hp and model.energy==energy and model.time==time,"origin presentation preserves fire travel model health energy and time")
	world.player.position += Vector2(20,-35)
	var moved: Dictionary = runtime._player_casting_presentation()
	check(moved.origin==source.origin+Vector2(20,-35),"casting origin tracks actual player position")
	var legacy := LegacyWorld.new()
	runtime.world=legacy
	var fallback: Dictionary = runtime._player_casting_presentation()
	check(fallback.origin==Vector2(100,420) and fallback.height==217,"world without player presentation retains exact legacy fallback")
	runtime.world=world
	runtime.finish()
	runtime.free()
	legacy.free()
	world.free()
	print("PIXEL_ACTION_REPLAY_ACCEPTANCE ",checks," checks failures=",failures)
	quit(failures)
