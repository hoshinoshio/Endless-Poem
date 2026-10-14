extends SceneTree
const OUT="res://docs/verification/exploration_live_"
var checks=0
var failures=[]
var clicks=0
var game
var s
func _initialize(): call_deferred("run_test")
func check(value,label):
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func capture(id):
	if s!=null and s.world!=null: s.world.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame=root.get_texture().get_image()
	check(frame!=null and not frame.is_empty(),"GPU "+id)
	frame.save_png(OUT+id+".png")
func click_point(point):
	var motion=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion,true)
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=point
	press.global_position=point
	press.pressed=true
	root.push_input(press,true)
	await process_frame
	press=press.duplicate()
	press.pressed=false
	root.push_input(press,true)
	await process_frame
	clicks+=1
func click(node): await click_point(node.get_global_rect().get_center())
func key(code):
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	root.push_input(event,true)
	await process_frame
	event=event.duplicate()
	event.pressed=false
	root.push_input(event,true)
	await process_frame
func ticks(n):
	for i in n:
		s._physics_process(1.0/60)
		if i%12==0: await physics_frame
func walk(to_x,jump=false):
	Input.action_press("explore_right")
	if jump: await key(KEY_SPACE)
	for i in 2000:
		if s.mode!="explore" or s.world.player.position.x>=to_x: break
		s._physics_process(1.0/60)
		if i%12==0: await physics_frame
	Input.action_release("explore_right")
	await ticks(2)
func run_test():
	if DisplayServer.get_name()=="headless": quit(2);return
	var path="user://exploration_gpu_%d.json" % Time.get_ticks_usec()
	game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	game.save_path=path
	root.add_child(game)
	await process_frame
	await capture("01_menu")
	await click(game.start_menu.buttons.new)
	s=game.exploration_session
	s.set_physics_process(false)
	check(s.mode=="opening","real New button enters opening")
	s.opening.set_process(false)
	s.opening.advance(30)
	s.opening.advance(0.5)
	await capture("02_question")
	await click(s.opening.buttons.yes)
	await physics_frame
	check(s.mode=="explore","real Yes enters rendered world")
	if s.world==null:quit(1);return
	await capture("03_entry")
	await walk(850)
	check(s.run.tutorial_step==1,"physical movement completes walk")
	await key(KEY_SPACE)
	Input.action_press("explore_right")
	await ticks(23)
	await capture("04_jump")
	Input.action_release("explore_right")
	await walk(1860)
	await ticks(90)
	check(s.run.tutorial_step==2,"Space jumps and landing completes tutorial")
	await key(KEY_E)
	check(s.run.tutorial_step==3 and s.mode=="dialog","real E opens nearby investigation")
	await capture("05_lantern")
	await click(s.ui_buttons["continue"])
	await walk(2800)
	check(s.run.tutorial_step==4 and s.mode=="loadout","real fork leads to equipment")
	await capture("06_loadout")
	await click(s.ui_buttons.loadout_confirm)
	check(s.mode=="battle","mouse confirms in-world battle")
	await ticks(2)
	await click(s.authority_button)
	check(s.deck_open,"real clock opens equipped grid")
	await capture("07_cards")
	check(s.hp_bar.size.y<=8 and not s.hp_bar.show_percentage,"player HP remains a thin numberless bar below cards")
	var target=s.combat.enemies[0].id
	var target_rect=s.spatial.get_target_rect(target)
	check(target_rect.end.y<582,"enemy remains above expanded card grid")
	var shield=s.combat.cards[4].id
	await click(s.card_buttons[shield])
	var energy=s.combat.energy
	await key(KEY_SPACE)
	await ticks(2)
	check(s.combat.energy==energy and s.world.player.velocity.y<0,"Space jumps without committing selected self card")
	await click(s.card_buttons[shield])
	await ticks(45)
	check(s.combat.get_snapshot().cards[4].remaining>0,"second click casts self card and starts cooldown")
	var fire=s.combat.cards[0].id
	await click(s.card_buttons[fire])
	await click_point(s.spatial.get_target_rect(target).get_center())
	await ticks(22)
	await capture("08_cast")
	await ticks(55)
	check(s.combat.enemies[0].hp==6,"real card and target mouse click cause one physical hit")
	await click(s.card_buttons[s.combat.cards[1].id])
	await click_point(s.spatial.get_target_rect(target).get_center())
	await ticks(90)
	check(s.combat.status=="won" and "tutorial" in s.run.completed,"real mouse completes battle")
	await capture("09_victory")
	await key(KEY_ESCAPE)
	await click(s.ui_buttons.menu)
	check(game.screen=="start_menu" and not game.start_menu.buttons["continue"].disabled,"pause menu returns with Continue")
	await capture("10_return_menu")
	await click(game.start_menu.buttons["continue"])
	check(not s.suspended,"real Continue resumes session")
	# Layout fixture only: own 14 entities and preview the next genuine equipment UI.
	for i in 4: game.store.claim_reward("gpu:layout:"+str(i),"fire")
	game.store.set_equipped(game.store.collection.map(func(c):return c.id))
	s.request_encounter("stairs")
	await click(s.ui_buttons.loadout_confirm)
	await ticks(2)
	await click(s.authority_button)
	await process_frame
	check(s.card_buttons.size()==14,"fourteen owned entities each have a card")
	var scroll=s.deck_scroll
	scroll.scroll_vertical=132
	await process_frame
	var old_scroll=scroll.scroll_vertical
	var ids=s.card_buttons.keys()
	await click(s.authority_button)
	await click(s.authority_button)
	await ticks(12)
	check(old_scroll>0 and scroll.scroll_vertical==old_scroll and s.card_buttons.keys()==ids,"scroll and slots survive close/open and time changes")
	await capture("11_fourteen_cards")
	s.leave_to_menu()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("EXPLORATION_SESSION_GPU checks=",checks," failures=",failures.size()," mouse_clicks=",clicks)
	quit(0 if failures.is_empty() else 1)
