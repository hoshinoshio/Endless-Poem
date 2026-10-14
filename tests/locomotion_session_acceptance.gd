extends SceneTree
const Store = preload("res://scripts/progression/collection_store.gd")
const Session = preload("res://scripts/exploration/exploration_session.gd")
var session
var checks := 0
var failures: Array = []
func _initialize(): call_deferred("run_test")
func check(ok: bool,label: String):
 checks += 1
 if not ok: failures.append(label)
 print("PASS " if ok else "FAIL ",label)
func key(code: Key,pressed: bool):
 var event := InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 await process_frame
func step(frames: int):
 for i in frames: session._physics_process(1.0/60.0)
func fixture_position(point: Vector2):
 session.world.set_player_position(point)
 session.world.player.landing_remaining = 0
func run_test():
 var path := "user://locomotion_session_%d.json" % Time.get_ticks_usec()
 var store := Store.new()
 check(store.initialize(path),"isolated store initialized")
 store.data.intro_accepted = true
 store.data.tutorial_completed = true
 session = Session.new()
 root.add_child(session)
 session.set_physics_process(false)
 session.configure(store,true)
 await physics_frame
 await physics_frame
 step(20)
 check(session.mode=="explore" and session.world.player.grounded,"exploration fixture on real floor")
 await key(KEY_SHIFT,true)
 check(Input.is_action_pressed("explore_run"),"real Shift event maps to explore_run")
 step(20)
 check(not session.world.player.running and session.world.player.animation=="idle","Shift alone stays idle through session")
 await key(KEY_D,true)
 step(30)
 check(session.world.player.running and absf(session.world.player.velocity.x-624)<1,"exploration Shift+D reaches run")
 await key(KEY_SHIFT,false)
 step(20)
 check(not session.world.player.running and absf(session.world.player.velocity.x-390)<1,"real Shift release restores walk")
 await key(KEY_D,false)
 step(20)
 await key(KEY_A,true)
 await key(KEY_SHIFT,true)
 step(30)
 check(session.world.player.facing==-1 and absf(session.world.player.velocity.x+624)<1,"real Shift+A runs left")
 await key(KEY_A,false)
 step(20)
 await key(KEY_SPACE,true)
 step(8)
 await key(KEY_SPACE,false)
 var rising_velocity: float = session.world.player.velocity.y
 await key(KEY_SPACE,true)
 step(1)
 check(not session.world.player.grounded and session.world.player.velocity.y>rising_velocity,"second Space press cannot reset airborne impulse")
 await key(KEY_SPACE,false)
 step(90)
 # This positioning fixture isolates battle locomotion; chapter traversal is tested separately.
 fixture_position(Vector2(2540,1900))
 step(20)
 session.request_encounter("tutorial")
 check(session.mode=="loadout" and session.confirm_loadout(),"first battle starts through session loadout using isolated fixture")
 await key(KEY_D,true)
 step(15)
 check(session.mode=="battle" and session.world.player.running and absf(session.world.player.velocity.x-624)<1,"same player runs inside battle")
 var player = session.world.player
 var ground_position: Vector2 = player.position
 var ground_phase: float = player.stride_phase
 step(12)
 var ground_distance: float = player.position.x-ground_position.x
 var ground_phase_delta: float = fposmod(player.stride_phase-ground_phase,1.0)
 var selected := str(session.combat.cards[0].id)
 session.choose_card(selected)
 ground_position = player.position
 ground_phase = player.stride_phase
 step(12)
 var slow_ground_distance: float = player.position.x-ground_position.x
 var slow_phase_delta: float = fposmod(player.stride_phase-ground_phase,1.0)
 check(absf(slow_ground_distance/ground_distance-0.2)<0.01,"ground running slows by shared simulation clock")
 check(absf(slow_phase_delta/ground_phase_delta-0.2)<0.015,"ground gait phase scales with actual slow displacement")
 session.combat.cancel_selection()
 var stable_velocity := Vector2(624,0)
 fixture_position(Vector2(2550,1500))
 player.velocity = stable_velocity
 var position_before: Vector2 = player.position
 var phase_before: float = player.stride_phase
 var time_before: float = session.combat.time
 step(12)
 var normal_distance: float = player.position.x-position_before.x
 var normal_gravity: float = player.velocity.y
 check(absf(normal_distance-124.8)<1 and absf(normal_gravity-320)<1,"battle running and gravity share unscaled clock")
 fixture_position(Vector2(2550,1500))
 player.velocity = stable_velocity
 var fire := str(session.combat.cards[0].id)
 session.choose_card(fire)
 check(session.combat.selected_card_id==fire and session.combat.get_snapshot().time_scale==0.2,"card selection activates existing slowdown")
 position_before = player.position
 phase_before = player.stride_phase
 time_before = session.combat.time
 step(12)
 var slow_distance: float = player.position.x-position_before.x
 var slow_gravity: float = player.velocity.y
 check(absf(slow_distance/normal_distance-0.2)<0.01,"card selection scales run displacement to twenty percent")
 check(absf(slow_gravity/normal_gravity-0.2)<0.01,"card selection scales gravity by same clock")
 check(absf(session.combat.time-time_before-0.04)<0.001 and player.stride_phase==phase_before,"shared clock and airborne phase remain coherent")
 session.combat.cancel_selection()
 await key(KEY_ESCAPE,true)
 await key(KEY_ESCAPE,false)
 check(session.mode=="pause","real Escape event opens pause")
 position_before = player.position
 phase_before = player.stride_phase
 var velocity_before: Vector2 = player.velocity
 time_before = session.combat.time
 step(90)
 check(player.position==position_before and player.velocity==velocity_before and player.stride_phase==phase_before and session.combat.time==time_before,"pause freezes run movement gravity gait and combat")
 session.ui_buttons.resume.pressed.emit()
 await key(KEY_SHIFT,false)
 step(20)
 check(session.mode=="battle" and not player.running and absf(player.velocity.x-390)<1,"resume and Shift release restore battle walk")
 await key(KEY_D,false)
 await key(KEY_SHIFT,false)
 await key(KEY_A,false)
 await key(KEY_SPACE,false)
 session.queue_free()
 await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("LOCOMOTION_SESSION checks=",checks," failures=",failures.size()," labels=",failures)
 quit(0 if failures.is_empty() else 1)
