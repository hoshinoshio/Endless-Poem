extends SceneTree
const Player = preload("res://scripts/exploration/exploration_player.gd")
var player: CharacterBody2D
var checks := 0
var failures := 0
func _initialize(): call_deferred("run_test")
func check(ok: bool,label: String):
 checks += 1
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label," velocity=",player.velocity," animation=",player.animation," run=",player.running," blend=",player.run_blend)
func step(axis: float,frames: int,running: bool=false,jump: bool=false):
 player.set_input(axis,jump,running)
 for i in frames: player.advance(1.0/60.0)
func obstacle(position: Vector2,size: Vector2):
 var body := StaticBody2D.new()
 body.position = position
 var collider := CollisionShape2D.new()
 var rectangle := RectangleShape2D.new()
 rectangle.size = size
 collider.shape = rectangle
 body.add_child(collider)
 root.add_child(body)
func run_test():
 obstacle(Vector2(0,20),Vector2(20000,40))
 obstacle(Vector2(1400,-200),Vector2(40,400))
 player = Player.new()
 root.add_child(player)
 await physics_frame
 await physics_frame
 step(0,20)
 check(player.grounded,"real floor adhesion")
 step(1,1)
 check(player.velocity.x>0 and player.velocity.x<Player.SPEED,"finite acceleration")
 step(1,30)
 check(absf(player.velocity.x-390)<1.0 and player.animation=="walk","walk steady speed")
 var walk_phase = player.stride_phase
 step(1,1,true)
 check(player.velocity.x>390 and player.velocity.x<624,"run accelerates continuously")
 step(1,20,true)
 check(absf(player.velocity.x-624)<1.0 and player.animation=="run","run steady speed")
 check(player.stride_phase!=walk_phase,"actual motion advances gait")
 step(1,1,false)
 check(player.velocity.x>390 and player.velocity.x<624,"Shift release decelerates")
 step(1,20,false)
 check(absf(player.velocity.x-390)<1.0 and player.animation=="walk","Shift release returns to walk")
 var stop_start = player.position.x
 step(0,20,true)
 check(player.animation=="idle" and absf(player.velocity.x)<0.1 and not player.running,"Shift without direction remains idle")
 check(player.position.x-stop_start<20,"stopping distance bounded")
 var paused_position = player.position
 var paused_phase = player.stride_phase
 player.advance(0)
 check(player.position==paused_position and player.stride_phase==paused_phase,"zero delta freezes clock and phase")
 step(0,30)
 check(player.stride_phase==paused_phase,"idle freezes phase")
 step(-1,20,true)
 check(player.facing==-1 and absf(player.velocity.x+624)<1.0,"turning reaches left run")
 step(1,20,true,true)
 check(not player.grounded and player.velocity.y<0 and player.running,"running jump retains input and impulse")
 step(0,100)
 check(player.grounded,"single running jump lands")
 player.position = Vector2(1300,0)
 player.velocity = Vector2.ZERO
 step(1,100,true)
 var wall_phase = player.stride_phase
 var wall_position = player.position
 step(1,40,true)
 check(player.position.distance_to(wall_position)<0.1,"real wall blocks movement")
 check(player.stride_phase==wall_phase and player.animation=="idle","wall does not animate empty run")
 if FileAccess.file_exists("res://assets/exploration/locomotion_frames.json"):
  check(player.locomotion_ready and player.locomotion_frames.walk.size()==8 and player.locomotion_frames.run.size()==8,"authored eight frame walk and run loaded")
  var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/exploration/locomotion_frames.json"))
  if data.has("idle"):
   check(not player.locomotion_idle.is_empty(),"optional authored idle loads")
   step(0,30)
   check(player.side_sprite.texture==player.locomotion_idle.frame,"idle uses shared authored body and foot anchor")
  var all_textures_match := true
  for gait in ["walk","run"]:
   for i in 8:
    var expected := str(data[gait][i].get("texture",data.get("texture","")))
    if player.locomotion_ready:
     all_textures_match = all_textures_match and player.locomotion_frames[gait][i].atlas.resource_path==expected
    else:
     all_textures_match = false
  check(all_textures_match,"per frame texture overrides match authored sheets")
 print("LOCOMOTION checks=",checks," failures=",failures," authored=",player.locomotion_ready)
 quit(1 if failures else 0)



