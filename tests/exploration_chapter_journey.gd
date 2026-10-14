extends SceneTree
## Isolated full chapter journey: all progress comes from movement, interactions and cards.
const Session=preload("res://scripts/exploration/exploration_session.gd")
const Store=preload("res://scripts/progression/collection_store.gd")
var session
var store
var checks:=0
var failures: Array=[]
var regions: Array=[]
var battles: Dictionary={}
var sim_seconds:=0.0
var started:=0
var save_path:=""
func _initialize(): call_deferred("run")
func check(value,label):
	checks+=1
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures.append(label)
func axis(value):
	Input.action_release("explore_left")
	Input.action_release("explore_right")
	if value<0: Input.action_press("explore_left")
	elif value>0: Input.action_press("explore_right")
func tap(key):
	var event=InputEventKey.new()
	event.keycode=key
	event.physical_keycode=key
	event.pressed=true
	session._unhandled_input(event)
func step():
	session._physics_process(1.0/60)
	sim_seconds+=1.0/60
	if not session.world.current_region in regions: regions.append(session.world.current_region)
func ready(type):
	for card in session.combat.get_snapshot().cards:
		if card.type==type and card.playable: return card
	return {}
func cast(type,target=""):
	var card=ready(type)
	if card.is_empty(): return false
	session.choose_card(card.id)
	if target.is_empty(): session.choose_card(card.id)
	else: session.confirm_target(target)
	return true
func fight():
	axis(0)
	var id=session.encounter
	# Equipment changes use the same visible loadout action as the production UI.
	session.ui_buttons.equip_all.pressed.emit()
	if not session.confirm_loadout():
		check(false,"start "+id)
		return false
	var phases: Array=[]
	var casts:=0
	var anchor_casts:=0
	var start_hp=session.combat.hp
	var jumps:=0
	var direction:=-1.0
	var start_time=sim_seconds
	for frame in 18000:
		if session.mode!="battle": break
		var model=session.combat
		if not model.phase in phases: phases.append(model.phase)
		var victim={}
		for enemy in model.enemies:
			if enemy.is_anchor: victim=enemy; break
		if victim.is_empty() and not model.enemies.is_empty(): victim=model.enemies[0]
		var imminent:=false
		var nearest:=100000.0
		var nearest_x:=0.0
		for enemy in model.enemies:
			if enemy.kind in ["tutorial","guard","elite","boss"]:
				var pos: Vector2=session.spatial.entities[enemy.id].position
				var distance: float=absf(pos.x-session.world.player.position.x)
				if distance<nearest: nearest=distance; nearest_x=pos.x
				if enemy.duration-enemy.charge<0.7 and distance<360: imminent=true
		var spec=session.world.get_encounter_spec(id)
		var p: Vector2=session.world.player.position
		if p.x<spec.rect.position.x+75: direction=1
		elif p.x>spec.rect.end.x-75: direction=-1
		elif nearest<260 and absf(p.x-nearest_x)>40:
			direction=-1 if p.x<nearest_x else 1
		axis(direction)
		if imminent and session.world.player.grounded:
			tap(KEY_SPACE)
			jumps+=1
		var shield=model.get_snapshot().shield
		if imminent and shield<3 and model.energy>=2 and not ready("heavy_shield").is_empty():
			if cast("heavy_shield"): casts+=1
		elif imminent and shield<3 and model.energy>=1 and not ready("shield").is_empty():
			if cast("shield"): casts+=1
		elif model.energy<=1 and not ready("charge").is_empty():
			if cast("charge"): casts+=1
		elif not victim.is_empty():
			var kind="delay" if not ready("delay").is_empty() and not model._has_pending("delay",victim.id) else "fire"
			if cast(kind,victim.id):
				casts+=1
				if victim.is_anchor: anchor_casts+=1
		step()
	axis(0)
	battles[id]={"status":session.combat.status,"phases":phases,"start_hp":start_hp,"hp":session.combat.hp,"casts":casts,"anchor_casts":anchor_casts,"jumps":jumps,"seconds":sim_seconds-start_time,"position":session.world.get_player_position()}
	print("JOURNEY_BATTLE ",id," ",JSON.stringify(battles[id]))
	if not session.combat.status=="won":
		check(false,"natural battle victory "+id)
		return false
	check(id in session.run.completed,"natural battle complete "+id)
	if session.mode=="reward":
		var kind={"stairs":"heavy_shield","patrol":"ignite","lamp":"delay","elite":"delay","corridor":"fire"}.get(id,"ember")
		session.ui_buttons["reward_"+kind].pressed.emit()
		check("chapter1:battle:"+id in store.claimed_rewards,"actual reward source "+id)
	if session.mode=="upgrade":
		var target=""
		for card in store.collection:
			if card.type=="fire" and not session.run.upgrades.has(card.id): target=card.id; break
		if target!="": session.ui_buttons["upgrade_"+target].pressed.emit()
	check(session.mode=="explore","battle returns to exploration "+id)
	return true
func walk(to_x,value=1.0,jump=false):
	if jump:
		axis(0)
		for settle in 120:
			if session.world.player.grounded: break
			step()
	axis(value)
	if jump: tap(KEY_SPACE)
	var stationary:=0
	var before_x: float=session.world.player.position.x
	for frame in 12000:
		if session.mode=="loadout":
			if not fight(): return false
			axis(value)
		if session.mode!="explore":
			check(false,"unexpected movement mode "+session.mode)
			axis(0)
			return false
		var x: float=session.world.player.position.x
		if (x>=to_x if value>0 else x<=to_x):
			axis(0)
			step()
			print("JOURNEY_WALK target=",to_x," actual=",session.world.get_player_position()," branches=",session.world.branch_visits)
			return true
		step()
		if absf(session.world.player.position.x-before_x)<0.01: stationary+=1
		else: stationary=0
		before_x=session.world.player.position.x
		if stationary>180:
			check(false,"blocked movement target=%s at=%s mode=%s gates=%s"%[to_x,session.world.get_player_position(),session.mode,session.world.get_gate_state()])
			axis(0)
			return false
	axis(0)
	check(false,"movement bounded timeout "+str(to_x))
	return false
func interact(id):
	axis(0)
	for i in 8: step()
	check(session.world.nearest_interaction==id,"physical proximity "+id)
	if session.world.nearest_interaction!=id: return false
	tap(KEY_E)
	print("JOURNEY_INTERACT ",id," mode=",session.mode," position=",session.world.get_player_position())
	if id in ["supply_lamp","supply_tower"]:
		check(session.mode=="shop","actual shop "+id)
		if id=="supply_lamp" and not session.ui_buttons.buy_fire.disabled:
			session.ui_buttons.buy_fire.pressed.emit()
			check("chapter1:shop:3:fire" in store.claimed_rewards,"earned currency buys lamp fire")
		if id=="supply_tower" and int(session.run.coins)>=20:
			var coins_before: int=session.run.coins
			session.ui_buttons.upgrade.pressed.emit()
			var card_id=""
			for card in store.collection:
				if card.type=="fire" and not session.run.upgrades.has(card.id): card_id=card.id; break
			if card_id!="": session.ui_buttons["upgrade_"+card_id].pressed.emit()
			check(session.run.coins==coins_before-20 and session.run.upgrades.has(card_id),"tower earned currency pays actual shop upgrade")
		if session.ui_buttons.has("continue"): session.ui_buttons["continue"].pressed.emit()
	elif id=="rest":
		check(session.mode=="rest","actual rest")
		if session.ui_buttons.has("heal"):
			session.ui_buttons.heal.pressed.emit()
			check(session.run.rest_used,"actual once-per-run rest consumed")
			var hp_after: int=session.run.hp
			check(not session.rest_heal() and session.run.hp==hp_after,"rest cannot be repeated")
		else: session.ui_buttons["continue"].pressed.emit()
	elif session.ui_buttons.has("continue"): session.ui_buttons["continue"].pressed.emit()
	return true
func report():
	axis(0)
	var result={"checks":checks,"failures":failures,"sim_seconds":sim_seconds,"wall_ms":Time.get_ticks_msec()-started,"world_position":session.world.get_player_position(),"regions":regions,"branches":session.world.branch_visits,"battles":battles,"mode":session.mode,"run":session.run,"sources":store.claimed_rewards,"collection":store.collection,"evidence":store.data.get("evidence",[]),"record_choice":store.data.get("record_choice",""),"chapter_completed":store.data.get("chapter_completed",false),"save_path":save_path,"renderer":"headless; input actions and actual collision simulation"}
	print("JOURNEY_FINAL ",JSON.stringify(result))
	var file=FileAccess.open("res://docs/verification/exploration_three_route_finish_journey.json",FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
func run():
	started=Time.get_ticks_msec()
	save_path="user://exploration_chapter_journey_%d.json"%Time.get_ticks_usec()
	store=Store.new()
	store.initialize(save_path)
	# Only permitted fixture: previously accepted opening and completed movement tutorial.
	store.data.intro_accepted=true
	store.data.tutorial_completed=true
	session=Session.new()
	root.add_child(session)
	session.configure(store,true)
	session.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(store.collection.size()==10 and session.run.completed.is_empty(),"fresh ten cards; no completed encounter fixture")
	if not walk(3300): report(); return
	if not walk(5900): report(); return
	if not walk(6800) or not interact("bridge_before"): report();return
	if not walk(7400) or not interact("bridge_after"): report();return
	if not walk(10900): report();return
	# Return to the shared entrance; a later jump selects the middle bridge.
	if not walk(9140,-1): report();return
	if not walk(10600,1,true): report();return
	check(session.world.branch_visits.has("lamp_middle"),"grounded middle patrol bridge through actual input")
	if not walk(8724,-1): report();return
	if not walk(10650,1,true) or not interact("supply_lamp"): report();return
	if not walk(13200) or not interact("testimony"): report();return
	if not walk(17100): report();return
	if not walk(14807,-1): report();return
	if not walk(15900,1,true) or not interact("supply_tower"): report();return
	if not walk(16600) or not interact("rest"): report();return
	if not walk(21500) or not interact("anchor_key"): report();return
	if not walk(23300) or not interact("final_dial"): report();return
	check(session.mode=="ending","actual final dial unlocked")
	if session.ui_buttons.has("dial"): session.ui_buttons.dial.pressed.emit()
	for i in 190: step()
	check(session.world.night_mix > 0.99,"night transition completes while record selection remains open")
	var pending_store=Store.new()
	check(pending_store.initialize(save_path) and pending_store.data.exploration_run.get("pending_ending","")=="record","record choice is durable before player chooses")
	check(absf(float(pending_store.data.exploration_run.position[0])-session.world.player.position.x)<1.0,"final dial saves actual world position")
	if session.ui_buttons.has("record_observatory"): session.ui_buttons.record_observatory.pressed.emit()
	check(session.mode=="complete" and store.data.get("chapter_completed",false),"chapter completed through actual record UI")
	var original=store.data.get("record_choice","")
	session.select_record("暮笙手记")
	check(store.data.get("record_choice","")==original and original=="观测环刻录","original record cannot be rewritten")
	for id in ["tutorial","stairs","patrol","lamp","elite","corridor","boss"]: check(id in session.run.completed,"completed ledger "+id)
	check(regions.size()==8,"all eight regions visited physically")
	for fork in ["lamp_lower","lamp_middle","lamp_upper","tower_lower","tower_upper"]: check(session.world.branch_visits.has(fork),"actual branch visit "+fork)
	check(battles.get("boss",{}).get("phases",[])==[1,2,3],"natural boss three phases")
	for evidence in ["断桥刻痕","值守名单","锚的钥匙"]: check(evidence in store.data.get("evidence",[]),"actual evidence "+evidence)
	check(store.collection.size()==16,"ten starter plus five earned rewards and one paid shop entity")
	check(store.claimed_rewards.size()==7,"all permanent reward sources unique")
	check(session.run.coins==0 and session.run.upgrades.size()==2,"earned fifty spent thirty plus twenty; two legitimate upgrades")
	check(session.run.rest_used and session.run.elite_upgrade_used,"actual rest and elite upgrade ledger")
	var reload=Store.new()
	check(reload.initialize(save_path) and reload.data.get("record_choice","")==original and reload.data.get("chapter_completed",false),"durable final record and chapter completion")
	check(absf(float(reload.data.exploration_run.position[0])-session.world.player.position.x)<1.0,"chapter completion saves actual world position")
	check(session.run.get("lamp_lit",false) and reload.data.exploration_run.get("lamp_lit",false) and reload.data.get("lamp_lit",false),"lamp victory lights and durably saves lamp")
	report()
