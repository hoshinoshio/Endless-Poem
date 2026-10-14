extends SceneTree
const Brain = preload("res://scripts/exploration/enemy_brain.gd")
const Model = preload("res://scripts/combat/combat_model.gd")
const Runtime = preload("res://scripts/exploration/spatial_combat.gd")
var failures: Array = []
var checks := 0
class TestWorld extends Node2D:
	var point := Vector2(100,1750)
	var terrain := [{"points":PackedVector2Array([Vector2(0,1850),Vector2(400,1750),Vector2(1200,1750),Vector2(1500,1900)])}]
	func get_encounter_spec(_id): return {"rect":Rect2(0,1100,1600,660),"floor_y":1750.0,"spawns":[Vector2(600,1750),Vector2(900,1750),Vector2(1100,1750)]}
	func set_encounter_active(_id,_value): pass
	func set_paused(_value): pass
	func finish_encounter(_id): pass
	func leave_encounter(_id): pass
	func advance_simulation(_delta): pass
	func get_player_position(): return point
	func get_player_hitbox(): return Rect2(point-Vector2(24,96),Vector2(48,96))
	func play_player_action(_action): pass
func _initialize(): call_deferred("run")
func check(value,label):
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL ",label)
func run():
	var guard=Brain.new()
	guard.configure("guard",0)
	var elite=Brain.new()
	elite.configure("elite",1)
	var bounds=Vector2(0,1600)
	var start=Vector2(600,1750)
	var player=Vector2(100,1750)
	var g=guard.advance(0.1,start,player,bounds,false)
	var e=elite.advance(0.1,start,player,bounds,false)
	check(g.x<e.x and e.x<start.x,"guard closes faster than heavy elite")
	guard.prepare(g,player,0.7,false)
	var aim=guard.facing
	guard.prepare(g,Vector2(1000,1750),0.6,false)
	check(guard.state=="telegraph" and guard.facing==aim,"telegraph locks aim despite crossing player")
	check(guard.advance(0.2,g,player,bounds,false)==g,"telegraph holds spatial origin")
	guard.commit()
	check(guard.state=="strike" and guard.motion_state()=="attack","model commitment enters strike")
	check(guard.advance(0.33,g,player,bounds,false)==g and guard.state=="recovery","strike completes before recovery")
	check(guard.advance(0.2,g,player,bounds,false)==g and guard.state=="recovery","recovery prevents immediate chase")
	guard.advance(0.3,g,player,bounds,false)
	check(guard.state=="approach" and not guard.locked,"recovery releases aim")
	var instrument=Brain.new()
	instrument.configure("instrument",0)
	check(instrument.advance(0.1,Vector2(350,1750),player,bounds,false).x!=350,"hover support repositions at preferred range")
	check(instrument.preferred_distance>guard.preferred_distance,"support retains longer spacing")
	var world=TestWorld.new()
	root.add_child(world)
	var runtime=Runtime.new()
	root.add_child(runtime)
	var model=Model.new()
	runtime.configure(model,world)
	check(runtime.start("tutorial"),"runtime starts")
	var id=model.enemies[0].id
	check(runtime.entities[id].bounds==Vector2(424,1176),"middle arena constrained to flat platform after left slope")
	runtime.advance(1.0)
	var before=runtime.presentation_state().entities.duplicate(true)
	var clock=model.time
	runtime.set_paused(true)
	runtime.advance(3.0)
	check(runtime.presentation_state().entities==before and model.time==clock,"pause freezes state clocks movement and facing")
	runtime.set_paused(false)
	model.select_card(model.cards[0].id)
	var brain_time=runtime.entities[id].brain.state_time
	clock=model.time
	runtime.advance(0.1)
	check(absf(model.time-clock-0.02)<0.0001 and absf(runtime.entities[id].brain.state_time-brain_time-0.02)<0.0001,"brain uses slowed model delta")
	model.cancel_selection()
	world.point=Vector2(0,1750)
	runtime.advance(7.0)
	check(runtime.entities[id].position.x>=424 and runtime.entities[id].position.y==1750,"enemy never walks over sloped edge or floats off platform")
	var diagnostic=runtime.presentation_state().entities[0]
	check(diagnostic.has("ai_state") and diagnostic.has("velocity") and diagnostic.has("motion_state"),"presentation exposes behavior and continuous motion")
	print("ENEMY_BEHAVIOR_ACCEPTANCE checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
