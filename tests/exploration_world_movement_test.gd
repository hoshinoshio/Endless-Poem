extends SceneTree
const World=preload("res://scripts/exploration/exploration_world.gd")
var world
var events=[]
var failures=0
var checks=0
func _initialize():call_deferred("run_test")
func step(axis,frames,jump=false):
 world.set_movement_input(axis,jump)
 for i in frames:world.advance_simulation(1.0/60)
func check(ok,label):
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label," position=",world.player.position)
func walk(target,axis=1):
 world.set_movement_input(axis,false)
 for i in 12000:
  if (world.player.position.x>=target if axis>0 else world.player.position.x<=target):break
  world.advance_simulation(1.0/60)
 step(0,30)
func run_test():
 world=World.new()
 root.add_child(world)
 world.configure({"position":[200,1900],"tutorial_step":4,"completed":["tutorial","stairs","patrol","lamp","elite","corridor","boss"],"interactions":["tutorial_lantern","bridge_before","bridge_after","testimony","anchor_key"]})
 world.tutorial_event.connect(func(e,_d):events.append(e))
 await physics_frame
 await physics_frame
 step(0,20)
 check(world.player.grounded,"spawn real floor")
 walk(1300)
 check(world.player.position.y<1810,"walked up slope")
 step(1,90,true)
 check(world.player.grounded,"real jump landing")
 walk(2780)
 check(events.has("walked") and events.has("jump_landed") and events.has("fork_completed"),"safe tutorial physical signals")
 walk(7110)
 check(world.player.grounded and world.player.position.y>2000,"actual bridge-under maintenance path")
 walk(7400)
 check(world.player.grounded and absf(world.player.position.y-1900)<5,"far bridge stable footing")
 walk(10600)
 check(world.branch_visits.has("lamp_lower"),"grounded lower lamp route")
 world.set_encounter_active("lamp",true)
 step(0,80,true)
 check(world.player.grounded and absf(world.player.position.y-2100)<5,"lower battle jump cannot land on middle bridge")
 world.leave_encounter("lamp")
 walk(11550)
 check(world.player.grounded and absf(world.player.position.y-1900)<5,"lower route exits to shared floor")
 walk(17100)
 check(world.branch_visits.has("tower_lower"),"tower lower physical visit")
 walk(23300)
 check(world.current_region==7,"all regions continuous to final dial")
 var before=world.player.position
 world.set_paused(true)
 step(1,120,true)
 check(world.player.position==before,"pause freezes collision clock")
 print("EXPLORATION_MOVEMENT checks=",checks," failures=",failures," branches=",world.branch_visits)
 quit(1 if failures else 0)
