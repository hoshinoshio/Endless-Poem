extends SceneTree
const Model = preload("res://scripts/combat/combat_model.gd")
const Runtime = preload("res://scripts/exploration/spatial_combat.gd")
const Pixel = preload("res://scripts/visuals/pixel_actor.gd")
const World = preload("res://scripts/exploration/exploration_world.gd")
const Store = preload("res://scripts/progression/collection_store.gd")
class TestSession extends "res://scripts/exploration/exploration_session.gd":
	func _update_hud() -> void: pass
class TestWorld extends Node2D:
	var paused := false
	var point := Vector2(100,600)
	func get_encounter_spec(_id): return {"rect":Rect2(0,0,1600,600),"floor_y":600.0,"spawns":[Vector2(600,600),Vector2(900,600),Vector2(1100,600)]}
	func set_encounter_active(_id,_value): pass
	func set_paused(value): paused=value
	func finish_encounter(_id): pass
	func leave_encounter(_id): pass
	func advance_simulation(_delta): pass
	func get_player_position(): return point
	func get_player_hitbox(): return Rect2(point-Vector2(24,96),Vector2(48,96))
	func play_player_action(_action): pass
var failures := 0
var checks := 0
func check(value,label):
	checks += 1
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func _initialize(): call_deferred("run")
func run():
	var world = TestWorld.new()
	root.add_child(world)
	var runtime = Runtime.new()
	root.add_child(runtime)
	var model = Model.new()
	runtime.configure(model,world)
	check(runtime.start("corridor"),"real spatial model starts support encounter")
	var instrument = {}
	for enemy in model.enemies:
		if enemy.kind == "instrument": instrument=enemy
	check(not instrument.is_empty(),"encounter contains instrument")
	if instrument.is_empty(): quit(1); return
	var actor = runtime.entities[instrument.id].actor
	check(actor.continuous_motion is Pixel,"support uses authored pixel actor")
	var health = model.hp
	var energy = model.energy
	model._enemy_action(instrument)
	runtime._sync_entities()
	check(actor.animation_state=="cast","real support action_index plays cast without melee commit")
	check(model.hp==health and model.energy==energy and model.drain_spatial_actions().is_empty(),"support feedback adds no damage cost or spatial action")
	check(model.enemies.any(func(enemy): return enemy.is_anchor),"existing support action still creates anchor")
	var observer = {}
	for enemy in model.enemies:
		if enemy.kind == "observer": observer=enemy
	model._enemy_action(observer)
	runtime._sync_entities()
	check(runtime.entities[observer.id].actor.animation_state=="cast","real observer mark action plays cast")
	check(model.enemies[0].echo_mark and model.drain_spatial_actions().is_empty(),"observer marking remains unchanged and creates no melee attack")
	var target = model.enemies[0]
	var target_actor = runtime.entities[target.id].actor
	model.take_events()
	var original_hp = int(target.hp)
	model._hurt_enemy(target.id,1,"feedback probe")
	for event in model.take_events(): runtime.present_event(event)
	check(target_actor.animation_state=="hurt" and target.hp==original_hp-1,"actual model hit triggers hurt with exact damage")
	var pose = target_actor.continuous_motion.presentation_state()
	runtime.set_paused(true)
	runtime.advance(.25)
	runtime.advance_feedback(.25)
	check(target_actor.continuous_motion.presentation_state()==pose,"pause holds hurt pose exactly")
	runtime.set_paused(false)
	model._hurt_enemy(target.id,999,"defeat probe")
	runtime._sync_entities()
	check(not runtime.entities.has(target.id),"dead target immediately leaves live spatial membership")
	check(runtime.retiring_actors.any(func(entry): return entry.actor==target_actor) and target_actor.animation_state=="defeat","actual removal retains authored defeat presentation")
	check(not target_actor.pick_area.input_pickable,"defeated actor immediately disables targeting")
	var defeated_pose = target_actor.continuous_motion.presentation_state()
	runtime.set_paused(true)
	runtime.advance_feedback(.3)
	check(target_actor.continuous_motion.presentation_state()==defeated_pose,"pause freezes retained defeat pose")
	runtime.set_paused(false)
	runtime.finish(true)
	var clock_before = model.time
	runtime.advance_feedback(.2)
	check(target_actor.continuous_motion.presentation_state()!=defeated_pose,"defeat progresses after mechanical encounter finishes")
	check(model.time==clock_before,"retirement presentation never advances model time")
	runtime.advance_feedback(2)
	check(runtime.retiring_actors.is_empty(),"completed defeat presentation is released")
	runtime.free()
	world.free()
	var path = "user://pixel_spatial_feedback_%s.json" % Time.get_ticks_usec()
	var store = Store.new()
	check(store.initialize_time_authority(path),"default authority store initializes")
	var actual_world = World.new()
	root.add_child(actual_world)
	actual_world.configure({"ruleset":"time_authority_v2","position":[200,1900],"authority_unlocked":true,"authority_tutorial_step":3})
	var session = TestSession.new()
	session.store=store
	session.world=actual_world
	session.mode="explore"
	actual_world.temporal.set_unlocked(true)
	check(actual_world.temporal.select_card("stop"),"real controller selects time card")
	session.confirm_target("player")
	check(actual_world.player.continuous_motion.state=="cast","successful real temporal target application plays hero cast")
	actual_world.player.action_remaining=0
	actual_world.player.continuous_motion.set_motion_state("idle",Vector2.ZERO,1)
	session.confirm_target("nonexistent_target")
	check(actual_world.player.action_remaining==0,"failed target application adds no cosmetic action")
	check(session.spatial==null and store.collection.is_empty(),"default authority path creates no automatic combat or fire cards")
	actual_world.set_paused(true)
	session.world=null
	session.free()
	actual_world.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PIXEL_SPATIAL_FEEDBACK ",checks," checks failures=",failures)
	quit(failures)
