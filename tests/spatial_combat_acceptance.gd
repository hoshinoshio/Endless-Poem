extends SceneTree
const Model = preload("res://scripts/combat/combat_model.gd")
const Runtime = preload("res://scripts/exploration/spatial_combat.gd")
var failures: Array = []
var checks := 0
class TestWorld extends Node2D:
	var point := Vector2(100,600)
	var axis := 0.0
	var frozen := false
	var elapsed := 0.0
	func get_encounter_spec(_id): return {"rect":Rect2(0,0,1600,600),"floor_y":600.0,"spawns":[Vector2(600,600),Vector2(900,600),Vector2(1100,600)]}
	func set_encounter_active(_id,_value): pass
	func set_paused(value): frozen=value
	func finish_encounter(_id): pass
	func leave_encounter(_id): pass
	func advance_simulation(delta):
		if not frozen:
			elapsed+=delta
			point.x+=axis*250*delta
	func get_player_position(): return point
	func get_player_hitbox(): return Rect2(point-Vector2(24,96),Vector2(48,96))
	func play_player_action(_action): pass
func _initialize(): call_deferred("run")
func check(value,label):
	checks+=1
	if not value:
		failures.append(label)
		printerr("FAIL ",label)
func setup(id="tutorial"):
	var world=TestWorld.new()
	root.add_child(world)
	var runtime=Runtime.new()
	root.add_child(runtime)
	var model=Model.new()
	runtime.configure(model,world)
	check(runtime.start(id),"start "+id)
	return [model,runtime,world]
func cast(model,target):
	for card in model.get_snapshot().cards:
		if card.type=="fire" and card.playable:
			return model.select_card(card.id) and model.play_selected(target)
	return false
func run():
	var trio=setup()
	var model=trio[0]
	var runtime=trio[1]
	var world=trio[2]
	check(model.cards.size()==10,"10 physical cards")
	var target=model.enemies[0].id
	check(cast(model,target),"commit fire")
	check(model.energy==2 and model.enemies[0].hp==12,"commit costs exactly once without damage")
	check(model.cards[1].ready_at==0 and model.cards[0].ready_at==4,"same-name independent cooldown")
	runtime.advance(0.61)
	check(model.enemies[0].hp==12,"cast slow and travel delay")
	runtime.advance(0.55)
	check(model.enemies[0].hp==6 and runtime.resolved_hits==1,"real arrival single damage despite 8 visual streams")
	runtime.advance(0.5)
	check(model.enemies[0].hp==6,"no duplicate hit")
	world.axis=1
	var before=world.point
	model.select_card(model.cards[1].id)
	var focus_before=model.focus
	var time_before=model.time
	runtime.advance(0.5)
	check(abs(model.time-time_before-0.1)<0.0001,"world and gravity/attack shared 0.2 clock")
	check(abs(world.point.x-before.x-25)<0.001,"movement slows proportionately")
	check(abs(focus_before-model.focus-0.5)<0.001,"focus consumes real seconds")
	runtime.set_paused(true)
	before=world.point
	time_before=model.time
	var attack_before=runtime.attacks.duplicate(true)
	runtime.advance(3)
	check(world.point==before and model.time==time_before and runtime.attacks==attack_before,"pause freezes whole simulation")
	runtime.set_paused(false)
	model.cancel_selection()
	# Enemy miss: player stays far away; model no longer applies unconditional damage.
	world.axis=0
	world.point=Vector2(1450,600)
	var hp=model.hp
	runtime.advance(5)
	check(model.hp==hp and runtime.missed_attacks>0,"locked melee can miss")
	# A spell committed to its original position can miss a displaced target, without refund.
	var missed=setup()
	var mm=missed[0]
	var mr=missed[1]
	var mt=mm.enemies[0].id
	cast(mm,mt)
	mr.advance(0.61)
	mr.entities[mt].position.x+=600
	mr.advance(0.7)
	check(mm.enemies[0].hp==12 and mm.energy==2 and mr.missed_attacks==1,"fire miss keeps cost without damage")
	# Selection slow window remains finite even when still selected.
	var limited=setup()
	var lm=limited[0]
	var lr=limited[1]
	lm.select_card(lm.cards[0].id)
	lr.advance(3)
	check(abs(lm.time-1.4)<0.001 and lm.get_snapshot().time_scale==1.0,"finite focus slowdown allowance")
	# Isolated spatial action resolution rejects duplicates and records echoes only on actual hits.
	var isolated=Model.new()
	isolated.start_battle("boss",{"spatial_mode":true})
	isolated.phase=3
	isolated.tick(5)
	var actions=isolated.drain_spatial_actions()
	check(actions.size()==1 and isolated.hp==50 and isolated.pending.is_empty(),"boss release does not damage or record echo")
	var aid=actions[0].action_id
	check(isolated.resolve_spatial_hit(aid,{"origin":Vector2(10,600),"direction":1.0,"bell":false}),"collision accepted")
	check(not isolated.resolve_spatial_hit(aid) and isolated.hp==47,"collision token dedup")
	check(isolated.pending.size()==1,"actual hit records echo path")
	isolated.tick(3)
	actions=isolated.drain_spatial_actions()
	check(actions.size()==1 and actions[0].geometry.origin==Vector2(10,600),"echo replays original locked path")
	# All encounters including three boss phases are finished through real spatial arrivals.
	for id in ["tutorial","stairs","patrol","lamp","elite","corridor","boss"]:
		var group=setup(id)
		var m=group[0]
		var r=group[1]
		var w=group[2]
		w.point=Vector2(0,300)
		var phases: Array=[]
		var anchor_hits:=0
		for frame in 2400:
			if m.status!="active": break
			if not phases.has(m.phase): phases.append(m.phase)
			var enemies=m.enemies.duplicate()
			var victim={}
			for enemy in enemies:
				if enemy.is_anchor: victim=enemy; break
			if victim.is_empty() and not enemies.is_empty(): victim=enemies[0]
			if not victim.is_empty() and cast(m,victim.id) and victim.is_anchor: anchor_hits+=1
			r.advance(0.1)
		check(m.status=="won","spatial complete "+id)
		if id=="boss":
			check(phases.has(1) and phases.has(2) and phases.has(3),"boss three phases")
			check(anchor_hits>=3,"anchors targeted and broken spatially")
		r.finish()
		r.queue_free()
		w.queue_free()
	# Every delayed visual lane reaches the impact at the same collision instant.
	var fx=runtime.authority_fx
	fx.beams.clear()
	fx.cast("sync",Vector2(800,400))
	fx.advance(0.47)
	check(fx.presentation_state().streams.all(func(stream): return not stream.arrived),"all fire lanes still travelling before collision")
	fx.advance(0.011)
	check(fx.presentation_state().streams.all(func(stream): return stream.arrived),"all fire lanes arrive by collision instant")
	# Close-range sweep is jumpable and bell stays on floor.
	var contact=setup("boss")
	var cm=contact[0]
	var cr=contact[1]
	var cw=contact[2]
	var boss_id=cm.enemies[0].id
	cw.point=Vector2(730,600)
	cr.entities[boss_id].position=Vector2(600,600)
	cm.enemies[0].charge=4.99
	cr.advance(0.03)
	check(cm.hp==47,"actual close melee collision")
	cm.enemies[0].action_index=2
	cm._set_intent(cm.enemies[0])
	cm.enemies[0].charge=7.99
	cw.point=Vector2(730,430)
	cr.advance(2)
	check(cm.hp==47,"jump avoids floor bell")
	print("SPATIAL_COMBAT_ACCEPTANCE checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

