extends SceneTree
const Store=preload("res://scripts/progression/collection_store.gd")
var failures=[]
var checks=0
func _initialize(): call_deferred("run_test")
func check(value,label):
	checks+=1
	if not value:
		failures.append(label)
		printerr("FAIL ",label)
func step(session,n=1):
	for i in n: session._physics_process(1.0/60)
func walk(session,to_x,axis=1.0,jump=false):
	Input.action_press("explore_right" if axis>0 else "explore_left")
	if jump: session._jump=true
	for i in 12000:
		if session.mode!="explore": break
		if (session.world.player.position.x>=to_x if axis>0 else session.world.player.position.x<=to_x): break
		session._physics_process(1.0/60)
	Input.action_release("explore_right")
	Input.action_release("explore_left")
	step(session,1)
func tap(session,key):
	var event=InputEventKey.new()
	event.keycode=key
	event.physical_keycode=key
	event.pressed=true
	session._unhandled_input(event)
func fight(session):
	var elapsed=0.0
	var phases=[]
	var anchors=0
	for i in 36000:
		if session.mode!="battle": break
		if not session.combat.phase in phases: phases.append(session.combat.phase)
		var target=""
		for enemy in session.combat.enemies:
			if enemy.is_anchor: target=enemy.id;break
		if target.is_empty() and not session.combat.enemies.is_empty():target=session.combat.enemies[0].id
		for card in session.combat.get_snapshot().cards:
			if card.type=="fire" and card.playable and target!="":
				session.choose_card(card.id)
				session.confirm_target(target)
				if target.begins_with("anchor"):anchors+=1
				break
		session._physics_process(1.0/60)
		elapsed+=1.0/60
	print("NORMAL_BATTLE elapsed=",elapsed," status=",session.combat.status," hp=",session.combat.hp," phases=",phases," anchor_casts=",anchors)
func run_test():
	var path="user://exploration_session_acceptance_%d.json" % Time.get_ticks_usec()
	var game=load("res://scenes/main.tscn").instantiate()
	game.save_path=path
	root.add_child(game)
	await process_frame
	check(game.screen=="start_menu","default remains approved menu")
	check(game.store.collection.size()==10,"initial ten once")
	game.start_menu.buttons["new"].pressed.emit()
	var s=game.exploration_session
	s.set_physics_process(false)
	check(s.mode=="opening" and s.world==null,"first new enters opening before world")
	s.opening.set_process(false)
	s.opening.advance(30)
	s.opening.advance(0.5)
	s.opening.buttons.yes.pressed.emit()
	await physics_frame
	check(s.mode=="explore" and s.run.tutorial_step==0,"accepted starts physical tutorial")
	if s.world == null:
		print(s.presentation_state())
		quit(1)
		return
	check(game.store.data.visits==1 and game.store.collection.size()==10,"single run and starter accounting")
	walk(s,850)
	check(s.run.tutorial_step==1,"real horizontal movement advances tutorial")
	walk(s,1860,1,true)
	step(s,100)
	check(s.run.tutorial_step==2,"real jump and landing advances tutorial")
	tap(s,KEY_E)
	check(s.mode=="dialog" and s.run.tutorial_step==3,"E at actual lantern advances investigation")
	s.ui_buttons["continue"].pressed.emit()
	walk(s,2760)
	check(s.run.tutorial_step==4 and game.store.data.tutorial_completed,"real fork completes exploration-only tutorial")
	check(s.mode=="loadout" and s.encounter=="tutorial","next physical encounter opens loadout")
	var player=s.world.player
	var camera=s.world.camera
	check(s.confirm_loadout(),"equipped entities start spatial battle")
	check(s.world.player==player and s.world.camera==camera,"same player camera across encounter")
	s.toggle_deck()
	var order=s.card_buttons.keys()
	var fire=s.combat.cards[0].id
	s.choose_card(fire)
	tap(s,KEY_ESCAPE)
	check(s.combat.selected_card_id=="" and s.deck_open,"Esc cancels card first")
	tap(s,KEY_ESCAPE)
	check(not s.deck_open and s.mode=="battle","Esc closes deck second")
	tap(s,KEY_ESCAPE)
	check(s.mode=="pause","Esc pauses third")
	var time=s.combat.time
	step(s,80)
	check(s.combat.time==time,"pause freezes battle and world")
	s.ui_buttons.resume.pressed.emit()
	s.toggle_deck()
	fight(s)
	check(s.combat.status=="won" and "tutorial" in s.run.completed,"complete battle through normal cards and collision")
	check(s.run.coins==10 and s.run.hp>0,"victory accounted once")
	check(order.size()==10,"ten stable physical slots")
	var position=s.world.player.position
	s.leave_to_menu()
	check(game.screen=="start_menu" and not game.start_menu.buttons["continue"].disabled,"menu exposes persistent continue")
	check(root.canvas_transform==Transform2D.IDENTITY,"main menu resets world camera")
	game.start_menu.buttons["continue"].pressed.emit()
	check(s.world.player.position==position and not s.suspended,"same-session continue returns to actual map")
	s.leave_to_menu()
	game.queue_free()
	await process_frame
	var resumed=load("res://scenes/main.tscn").instantiate()
	resumed.save_path=path
	root.add_child(resumed)
	await process_frame
	check(not resumed.start_menu.buttons["continue"].disabled,"new process offers saved exploration")
	resumed.start_menu.buttons["continue"].pressed.emit()
	s=resumed.exploration_session
	s.set_physics_process(false)
	await physics_frame
	check(s.mode=="explore" and s.run.tutorial_step==4 and "tutorial" in s.run.completed,"resume retains tutorial and encounter completion")
	check(s.world.player.position.distance_to(position)<3,"restart restores safe map position")
	# Transaction fixtures are isolated from the normal-input combat proof above.
	var fixture=s.run.duplicate(true)
	fixture.coins=120
	fixture.hp=20
	check(s._commit(fixture),"transaction fixture saved")
	var before=resumed.store.collection.size()
	check(s.buy_card("supply_lamp","fire"),"shop transaction succeeds")
	check(s.run.coins==90 and resumed.store.collection.size()==before+1,"currency and entity commit together")
	check(not s.buy_card("supply_lamp","fire") and s.run.coins==90,"repeat source neither charges nor grants")
	check(not resumed.store.equipped_ids.has(resumed.store.collection[-1].id),"new collection copy not auto-equipped")
	check(s.rest_heal() and s.run.hp==35,"rest heals once")
	check(not s.rest_heal() and s.run.hp==35,"revisited rest cannot farm healing")
	var old=resumed.store.save_path
	resumed.store.save_path="user://directory_that_does_not_exist/save.json"
	var coin_before=s.run.coins
	check(not s.buy_card("supply_lamp","shield") and s.run.coins==coin_before and resumed.store.collection.size()==before+1,"failed write leaves both ledgers untouched")
	resumed.store.save_path=old
	# A pending reward survives reload and adds only one permanent physical entity.
	fixture=s.run.duplicate(true)
	fixture.pending_reward="stairs"
	fixture.completed.append("stairs")
	check(s._commit(fixture),"pending reward persisted")
	check(s.claim_reward("heavy_shield"),"pending reward atomic collection")
	check(not s.claim_reward("heavy_shield"),"repeated pending callback cannot grant again")
	var verifier=Store.new()
	check(verifier.initialize(path) and verifier.collection.size()==before+2,"restart verifies permanent atomic grants")
	check(verifier.data.exploration_run.coins==90 and verifier.data.exploration_run.rest_used,"restart verifies corresponding spend and rest")
	# Simulate quitting after a genuine encounter was opened; no battle-frame serialization.
	s.request_encounter("stairs") # completed fixture is intentionally ignored
	fixture=s.run.duplicate(true)
	fixture.completed.erase("stairs")
	s._commit(fixture)
	s.request_encounter("stairs")
	check(s.confirm_loadout(),"second encounter starts")
	verifier=Store.new()
	verifier.initialize(path)
	check(verifier.data.exploration_run.in_battle and not verifier.data.exploration_checkpoint.in_battle,"combat save keeps safe prebattle checkpoint")
	resumed.queue_free()
	await process_frame
	var restored=load("res://scenes/main.tscn").instantiate()
	restored.save_path=path
	root.add_child(restored)
	await process_frame
	restored.start_menu.buttons["continue"].pressed.emit()
	var final_session=restored.exploration_session
	final_session.set_physics_process(false)
	check(final_session.mode=="explore" and not final_session.run.in_battle,"battle interruption restores checkpoint")
	check(restored.store.collection.size()==before+2,"checkpoint rollback preserves permanent cards")
	restored.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("EXPLORATION_SESSION_ACCEPTANCE checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
